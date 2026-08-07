// ============================================================
//  NOI OHADA Invoice Pro — Serveur de callback NotchPay
//
//  Reçoit le callback / webhook NotchPay, vérifie la signature
//  HMAC-SHA256 (header `x-notch-signature`) puis active
//  l'abonnement de l'utilisateur dans Firestore (idempotent).
//
//  Endpoints :
//    POST /payment/callback   ← appelé par NotchPay (webhook)
//    GET  /verify/:reference  ← statut d'activation (polling)
//    GET  /health
//
//  Variable d'environnement requise :
//    NOCHPAY_WEBHOOK_SECRET    (secret du webhook NotchPay)
//
//  Connexion Firestore : clé de compte de service Firebase
//    - FIREBASE_SERVICE_ACCOUNT (base64 du JSON) OU
//    - GOOGLE_APPLICATION_CREDENTIALS (chemin) OU
//    - serviceAccountKey.json à la racine du projet
// ============================================================
require('dotenv').config();
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const express = require('express');
const {
  initializeApp,
  getApps,
  getApp,
  cert,
  applicationDefault,
} = require('firebase-admin');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const app = express();
const PORT = process.env.PORT || 8080;

// Secret lu À LA DEMANDE (robuste sur les fonctions serverless où les
// variables d'environnement sont injectées à chaque requête).
function getWebhookSecret() {
  return process.env.NOCHPAY_WEBHOOK_SECRET || '';
}

// ============================================================
//  FIREBASE ADMIN (contourne les règles, compte de service)
// ============================================================
function initFirebase() {
  if (getApps().length) return getApp();
  let credential;
  const saBase64 = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (saBase64 && saBase64.trim().length > 10) {
    const json = Buffer.from(saBase64, 'base64').toString('utf8');
    credential = cert(JSON.parse(json));
  } else {
    const saPath =
      process.env.GOOGLE_APPLICATION_CREDENTIALS ||
      path.join(__dirname, '..', 'serviceAccountKey.json');
    if (fs.existsSync(saPath)) {
      credential = cert(saPath);
    } else {
      credential = applicationDefault();
    }
  }
  return initializeApp({ credential });
}
initFirebase();
const db = getFirestore();
const serverTimestamp = () => FieldValue.serverTimestamp();

// ============================================================
//  HELPERS
// ============================================================
function isPaymentSuccessful(status) {
  const s = (status || '').toLowerCase();
  return ['complete', 'paid', 'success', 'successful'].includes(s);
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  return crypto.timingSafeEqual(bufA, bufB);
}

/// Vérifie la signature HMAC-SHA256 du webhook NotchPay.
/// Header attendu : `x-notch-signature: sha256=<hex digest>`.
function verifySignature(rawBody, signatureHeader) {
  const webhookSecret = getWebhookSecret();
  if (!webhookSecret) {
    console.warn('⚠️ NOCHPAY_WEBHOOK_SECRET absent — signature non vérifiée');
    return false;
  }
  const clean = (signatureHeader || '')
    .trim()
    .replace(/^sha256=/i, '');
  if (!clean) return false;
  const digest = crypto
    .createHmac('sha256', webhookSecret)
    .update(rawBody, 'utf8')
    .digest('hex');
  return timingSafeEqual(digest, clean);
}

function extractTransaction(data) {
  if (data && data.transaction && typeof data.transaction === 'object') {
    return data.transaction;
  }
  if (data && typeof data === 'object') return data;
  return {};
}

function extractMeta(txn, data) {
  return (
    txn.metadata ||
    txn.customer_meta ||
    txn.meta ||
    data.metadata ||
    data.customer_meta ||
    {}
  );
}

// ============================================================
//  ACTIVATION DE L'ABONNEMENT (idempotente)
// ============================================================
async function activateSubscription({
  userId,
  planId,
  reference,
  amount,
  currency,
  paymentMethod,
}) {
  if (!userId || !planId) {
    console.warn('⚠️ metadata sans user_id/plan_id — activation impossible');
    return false;
  }

  // Intervalle selon le plan (Business = annuel, sinon mensuel)
  let interval = 'month';
  try {
    const planDoc = await db.collection('plans').doc(planId).get();
    if (planDoc.exists && planDoc.data() && planDoc.data().interval) {
      interval = planDoc.data().interval;
    }
  } catch (e) {
    console.warn('⚠️ plan introuvable, interval défaut month', e.message);
  }

  return db.runTransaction(async (tx) => {
    // Idempotence : si un abonnement existe déjà avec ce paymentId, on
    // le réactive sans en créer un doublon.
    const existing = await tx.get(
      db.collection('subscriptions').where('paymentId', '==', reference).limit(1)
    );
    if (!existing.empty) {
      const doc = existing.docs[0];
      tx.update(doc.ref, {
        status: 'active',
        isActive: true,
        updatedAt: serverTimestamp(),
      });
      return true;
    }

    const subRef = db.collection('subscriptions').doc();
    const start = new Date();
    const days = interval === 'year' ? 365 : 30;
    const end = new Date(start.getTime() + days * 86400000);

    tx.set(subRef, {
      id: subRef.id,
      userId,
      planId,
      status: 'active',
      paymentMethod: paymentMethod || 'notchpay',
      paymentId: reference,
      amount: amount || 0,
      currency: currency || 'XAF',
      autoRenew: true,
      canceledAt: null,
      metadata: { notchpay_reference: reference, confirmed_by: 'server_callback' },
      isActive: true,
      createdAt: serverTimestamp(),
      startDate: start,
      endDate: end,
      interval,
    });

    // Lie l'abonnement à l'utilisateur.
    const userRef = db.collection('users').doc(userId);
    tx.update(userRef, { subscriptionId: subRef.id });
    return true;
  });
}

// ============================================================
//  MIDDLEWARE : capture du corps brut (pour la signature)
// ============================================================
app.use(
  express.json({
    verify: (req, res, buf) => {
      req.rawBody = buf;
    },
  })
);

// CORS pour le client web Flutter (le web relaie les appels ENKAP via ce
// serveur, qui détient les secrets — l'API E-nkap refuse le CORS navigateur).
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

// ============================================================
//  ROUTES
// ============================================================

/// Endpoint de callback appelé par NotchPay après un paiement.
app.post('/payment/callback', async (req, res) => {
  const signature =
    req.headers['x-notch-signature'] ||
    req.headers['x-notchpay-signature'] ||
    '';

  if (!verifySignature(req.rawBody, signature)) {
    console.warn('❌ Signature invalide pour le callback');
    return res.status(401).json({ error: 'Invalid signature' });
  }

  const data = req.body || {};
  const txn = extractTransaction(data);
  const status = txn.status || data.status || '';

  if (!isPaymentSuccessful(status)) {
    console.log(`ℹ️ Paiement non finalisé (${status}) — ignoré`);
    return res.status(200).json({ received: true, status: 'not-complete' });
  }

  const reference = txn.reference || data.reference || '';
  const meta = extractMeta(txn, data);
  const userId = meta.user_id || meta.userId || '';
  const planId = meta.plan_id || meta.planId || '';

  try {
    const activated = await activateSubscription({
      userId,
      planId,
      reference,
      amount: txn.amount || data.amount || 0,
      currency: txn.currency || data.currency || 'XAF',
      paymentMethod: txn.payment_method || meta.payment_method || 'notchpay',
    });
    console.log(
      `✅ Callback traité — ref=${reference} user=${userId} plan=${planId} activated=${activated}`
    );
    res.status(200).json({ received: true, activated });
  } catch (e) {
    console.error('❌ Erreur activation:', e);
    res.status(500).json({ error: e.message });
  }
});

/// Statut d'activation d'un paiement (pour le polling client).
app.get('/verify/:reference', async (req, res) => {
  const ref = req.params.reference;
  try {
    const snap = await db
      .collection('subscriptions')
      .where('paymentId', '==', ref)
      .limit(1)
      .get();
    if (snap.empty) {
      return res.json({ reference: ref, status: 'pending', activated: false });
    }
    const s = snap.docs[0].data();
    return res.json({
      reference: ref,
      status: s.status,
      activated: s.status === 'active',
      subscriptionId: snap.docs[0].id,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ============================================================
//  ENKAP (Maviance e-nkap) — callback de confirmation
// ============================================================

/// Enregistre l'intention d'un abonnement (appelé par l'app avant le
/// paiement ENKAP). Permet au callback ENKAP d'activer l'abonnement même si
/// l'app est fermée.
app.post('/enkap/register', async (req, res) => {
  const { reference, user_id, plan_id, amount, currency, payment_method } =
    req.body || {};
  if (!reference || !user_id || !plan_id) {
    return res.status(400).json({ error: 'reference/user_id/plan_id requis' });
  }
  try {
    await db
      .collection('pending_enkap_orders')
      .doc(reference)
      .set({
        reference,
        user_id,
        plan_id,
        amount: amount || 0,
        currency: currency || 'XAF',
        payment_method: payment_method || 'enkap',
        createdAt: serverTimestamp(),
      });
    res.status(201).json({ ok: true, reference });
  } catch (e) {
    console.error('❌ /enkap/register error:', e);
    res.status(500).json({ error: e.message });
  }
});

/// Page de retour ENKAP : après paiement, ENKAP redirige le client vers
/// `<returnUrl>/<reference>?status=<status>`. On affiche une confirmation.
app.get('/enkap/return/:reference', (req, res) => {
  const reference = req.params.reference || '';
  const status = req.query.status || '';
  const ok = (status || '').toUpperCase() === 'CONFIRMED';
  res.status(200).type('html').send(`<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Paiement E-nkap</title>
<style>body{font-family:system-ui,sans-serif;background:#f5f6fa;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0}
.card{background:#fff;border-radius:16px;padding:32px;max-width:420px;text-align:center;box-shadow:0 8px 30px rgba(0,0,0,.08)}
.icon{font-size:56px} h1{font-size:20px;margin:12px 0 6px} p{color:#666;margin:4px 0;font-size:14px}
.btn{display:inline-block;margin-top:18px;padding:12px 22px;border-radius:10px;background:#4338ca;color:#fff;text-decoration:none;font-weight:600}</style>
</head><body><div class="card">
<div class="icon">${ok ? '✅' : 'ℹ️'}</div>
<h1>${ok ? 'Paiement confirmé' : 'Retour de paiement'}</h1>
<p>Référence : <b>${reference}</b></p>
<p>Statut : <b>${status || 'N/A'}</b></p>
<p>Vous pouvez fermer cette page et revenir à l'application.</p>
</div></body></html>`);
});

/// Callback instantané ENKAP (ITN) : ENKAP appelle
/// `PUT <notificationUrl>/<merchantReference>` avec `{"status":"CONFIRMED"}`.
/// On active l'abonnement correspondant si une intention a été enregistrée.
app.put('/enkap/callback/:reference', async (req, res) => {
  const reference = req.params.reference || '';
  const status = (req.body && req.body.status) || '';
  const confirmed =
    (status || '').toUpperCase() === 'CONFIRMED' ||
    (status || '').toUpperCase() === 'COMPLETED';

  if (!reference) {
    return res.status(400).json({ error: 'missing reference' });
  }

  try {
    const ref = db.collection('pending_enkap_orders').doc(reference);
    const snap = await ref.get();
    const data = snap.exists ? snap.data() : {};

    await ref.set(
      { status: (status || '').toUpperCase(), confirmed, updatedAt: serverTimestamp() },
      { merge: true }
    );

    let activated = false;
    if (confirmed && data && data.user_id && data.plan_id) {
      activated = await activateSubscription({
        userId: data.user_id,
        planId: data.plan_id,
        reference,
        amount: data.amount || 0,
        currency: data.currency || 'XAF',
        paymentMethod: data.payment_method || 'enkap',
      });
      // L'activation a eu lieu : on peut retirer l'intention.
      if (activated) await ref.delete();
    }

    console.log(
      `✅ ENKAP callback — ref=${reference} status=${status || 'N/A'} confirmed=${confirmed} activated=${activated}`
    );
    res.status(200).json({ received: true, confirmed, activated });
  } catch (e) {
    console.error('❌ /enkap/callback error:', e);
    res.status(500).json({ error: e.message });
  }
});

// ============================================================
//  PROXY ENKAP (relais serveur → ENKAP, utilisé par le WEB)
//
//  L'API E-nkap refuse les appels depuis le navigateur (CORS :
//  « Invalid CORS request » → 403). Les secrets ENKAP restent ici en
//  variables d'environnement ; le client web ne parle qu'à ce serveur.
// ============================================================
const ENKAP_BASE = () =>
  process.env.ENKAP_BASE_URL || 'https://api-v2.enkap.cm/purchase/v1.2';
const ENKAP_TOKEN_URL = () =>
  process.env.ENKAP_TOKEN_URL || 'https://api-v2.enkap.cm/token';

let cachedEnkapToken = null;
let cachedEnkapTokenExp = 0;

async function getEnkapToken() {
  const accessToken = (process.env.ENKAP_ACCESS_TOKEN || '').trim();
  if (accessToken) return accessToken;
  if (cachedEnkapToken && cachedEnkapTokenExp > Date.now()) {
    return cachedEnkapToken;
  }
  const key = (process.env.ENKAP_CONSUMER_KEY || '').trim();
  const secret = (process.env.ENKAP_CONSUMER_SECRET || '').trim();
  if (!key || !secret) {
    throw new Error('ENKAP_CONSUMER_KEY/SECRET non configurés côté serveur');
  }
  const resp = await fetch(ENKAP_TOKEN_URL(), {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: key,
      client_secret: secret,
    }).toString(),
  });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    throw new Error(
      data.error_description || data.error || `token ${resp.status}`
    );
  }
  cachedEnkapToken = data.access_token;
  const expires = Number(data.expires_in) || 259200;
  cachedEnkapTokenExp = Date.now() + (expires - 60) * 1000;
  return cachedEnkapToken;
}

async function enkapFetch(path, { method = 'GET', body } = {}) {
  const token = await getEnkapToken();
  const headers = {
    Accept: 'application/json',
    Authorization: `Bearer ${token}`,
  };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const resp = await fetch(`${ENKAP_BASE()}${path}`, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await resp.text();
  let data = {};
  try {
    data = JSON.parse(text);
  } catch (_) {
    /* corps non JSON */
  }
  return { status: resp.status, data, text };
}

/// POST /enkap/order — crée une commande ENKAP (relais web).
app.post('/enkap/order', async (req, res) => {
  try {
    const b = req.body || {};
    const payload = {
      currency: b.currency || 'XAF',
      totalAmount: b.totalAmount,
      description: b.description || '',
      merchantReference: b.merchantReference || '',
      langKey: b.langKey || 'fr',
    };
    if (b.customerName) payload.customerName = b.customerName;
    if (b.email) payload.email = b.email;
    if (b.phoneNumber) payload.phoneNumber = b.phoneNumber;
    if (Array.isArray(b.items) && b.items.length) payload.items = b.items;

    const { status, data, text } = await enkapFetch('/api/order', {
      method: 'POST',
      body: payload,
    });
    if (status !== 201 && status !== 200) {
      return res.status(status).json({
        success: false,
        error: data.message || data.error || text || `ENKAP ${status}`,
      });
    }
    res.json({
      success: true,
      orderTransactionId: data.orderTransactionId,
      merchantReferenceId: data.merchantReferenceId,
      redirectUrl: data.redirectUrl,
    });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

/// GET /enkap/order/status?orderMerchantId=... — statut d'une commande.
app.get('/enkap/order/status', async (req, res) => {
  try {
    const params = new URLSearchParams();
    if (req.query.orderMerchantId) {
      params.set('orderMerchantId', String(req.query.orderMerchantId));
    }
    if (req.query.txid) params.set('txid', String(req.query.txid));
    const qs = params.toString();
    const { status, data, text } = await enkapFetch(
      `/api/order/status${qs ? `?${qs}` : ''}`
    );
    if (status !== 200) {
      return res
        .status(status)
        .json({ status: '', error: data.message || text });
    }
    res.json({ status: data.status || '' });
  } catch (e) {
    res.status(500).json({ status: '', error: e.message });
  }
});

/// GET /enkap/order?orderMerchantId=... — détails d'une commande.
app.get('/enkap/order', async (req, res) => {
  try {
    const params = new URLSearchParams();
    if (req.query.orderMerchantId) {
      params.set('orderMerchantId', String(req.query.orderMerchantId));
    }
    if (req.query.txid) params.set('txid', String(req.query.txid));
    const qs = params.toString();
    const { status, data, text } = await enkapFetch(`/api/order${qs ? `?${qs}` : ''}`);
    if (status !== 200) {
      return res.status(status).json(data.message || data.error || text);
    }
    res.json(data);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/health', (req, res) =>
  res.json({ ok: true, service: 'noi-ohada-payment-callback', time: new Date().toISOString() })
);

app.get('/', (req, res) =>
  res.json({
    service: 'NOI OHADA — callbacks paiement (NotchPay + ENKAP)',
    endpoints: [
      'POST /payment/callback',
      'GET /verify/:reference',
      'POST /enkap/register',
      'PUT /enkap/callback/:reference',
      'POST /enkap/order (proxy web)',
      'GET /enkap/order/status (proxy web)',
      'GET /enkap/order (proxy web)',
      'GET /health',
    ],
  })
);

// ============================================================
//  EXPORT POUR VERCEL / EXÉCUTION DIRECTE
// ============================================================
// Vercel (serverless) : exporter l'app Express — pas de listen.
module.exports = app;

// Exécution directe (node index.js / npm start) : on écoute.
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`🚀 Callback NotchPay écoute sur le port ${PORT}`);
    console.log(`   Webhook secret configuré : ${getWebhookSecret() ? 'oui' : 'NON (⚠️)'}`);
  });
}
