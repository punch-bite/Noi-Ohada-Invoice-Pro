// ============================================================
//  NOI OHADA Invoice Pro — Serveur de callbacks (ENKAP)
//
//  Reçoit les callbacks de confirmation ENKAP (Orange Money / MTN / Carte)
//  puis active l'abonnement de l'utilisateur dans Firestore (idempotent).
//
//  Endpoints :
//    POST /enkap/register       ← intention d'abonnement (app)
//    PUT  /enkap/callback/:ref  ← confirmation instantanée ENKAP (ITN)
//    GET  /enkap/return/:ref    ← page de retour après paiement
//    POST/GET /enkap/order[/status] ← proxy web → API E-nkap
//    GET  /health
//
//  Connexion Firestore : clé de compte de service Firebase
//    - FIREBASE_SERVICE_ACCOUNT (base64 du JSON) OU
//    - GOOGLE_APPLICATION_CREDENTIALS (chemin) OU
//    - serviceAccountKey.json à la racine du projet
// ============================================================
require('dotenv').config();
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
      paymentMethod: paymentMethod || 'enkap',
      paymentId: reference,
      amount: amount || 0,
      currency: currency || 'XAF',
      autoRenew: true,
      canceledAt: null,
      metadata: { enkap_reference: reference, confirmed_by: 'server_callback' },
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
//  MIDDLEWARE (SÉCURISÉ)
// ============================================================
app.disable('x-powered-by');
app.use(express.json({ limit: '100kb' }));

// ====== En-têtes de sécurité (protection navigateur) ======
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  next();
});

// ====== CORS RESTREINT (allowlist) — anti-falsification cross-origin ======
// L'ancien `Access-Control-Allow-Origin: *` permettait à n'importe quel site
// d'appeler ces endpoints depuis un navigateur. On n'autorise que les origines
// connues (domaine public + localhost de dev + notre propre serveur).
const ALLOWED_ORIGINS = new Set(
  (process.env.ALLOWED_ORIGINS ||
    'https://ohada-invoice-pro.com,http://localhost:3000,http://localhost:5000,http://localhost:8080,http://localhost:61860')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
);
app.use((req, res, next) => {
  const origin = req.headers.origin;
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

// ====== Limiteur de débit (anti-DoS / brute-force) ======
const rateBuckets = new Map();
function rateLimit({ windowMs = 60000, max = 30, keyPrefix = 'rl' }) {
  return (req, res, next) => {
    const ip =
      (req.headers['x-forwarded-for'] || '').split(',')[0].trim() ||
      req.socket.remoteAddress ||
      'unknown';
    const now = Date.now();
    const key = `${keyPrefix}:${ip}`;
    let bucket = rateBuckets.get(key);
    if (!bucket || bucket.resetAt <= now) {
      bucket = { count: 0, resetAt: now + windowMs };
    }
    bucket.count++;
    if (bucket.count > max) {
      return res.status(429).json({
        error: 'Trop de requêtes. Veuillez réessayer dans quelques instants.',
      });
    }
    rateBuckets.set(key, bucket);
    // Purge périodique pour éviter la fuite mémoire.
    if (rateBuckets.size > 5000) {
      for (const [k, b] of rateBuckets) if (b.resetAt <= now) rateBuckets.delete(k);
    }
    next();
  };
}

// ====== Validation des entrées ======
/// Échappe le HTML pour empêcher les attaques XSS (reflected).
function escapeHtml(value) {
  return String(value == null ? '' : value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/// Email simple valide.
function isValidEmail(value) {
  return typeof value === 'string' &&
    value.length <= 254 &&
    /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value);
}

// ============================================================
//  ROUTES
// ============================================================

// ============================================================
//  ENKAP (Maviance e-nkap) — callback de confirmation
// ============================================================

/// Enregistre l'intention d'un abonnement (appelé par l'app avant le
/// paiement ENKAP). Permet au callback ENKAP d'activer l'abonnement même si
/// l'app est fermée.
app.post(
  '/enkap/register',
  rateLimit({ windowMs: 60 * 1000, max: 30, keyPrefix: 'register' }),
  async (req, res) => {
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
/// 🔒 Les paramètres sont ÉCHAPPÉS (anti-XSS reflétée).
app.get('/enkap/return/:reference', (req, res) => {
  const reference = escapeHtml(req.params.reference || '');
  const status = escapeHtml((req.query.status || '').toString());
  const ok = (req.query.status || '').toString().toUpperCase() === 'CONFIRMED';
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

/// URL de base publique du serveur (utilisée pour returnUrl / notificationUrl).
const PUBLIC_BASE_URL = () =>
  (process.env.PUBLIC_BASE_URL || '').trim() || 'https://server-xi-two-23.vercel.app';

/// POST /enkap/order — crée une commande ENKAP (relais web/mobile).
///
/// Après création, on configure les URL de retour :
///   - returnUrl        → <base>/enkap/return   (page de confirmation, l'app
///                                               détecte le redirect pour finir)
///   - notificationUrl  → <base>/enkap/callback (ITN instantané, active même
///                                               si l'app est fermée)
/// Sans ces URL, E-nkap ne redirige pas le client et n'envoie pas l'ITN →
/// le paiement « tourne indéfiniment » puis expire côté client.
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

    // Configure returnUrl + notificationUrl (best-effort : si le setup échoue,
    // la commande est quand même valide, la confirmation se fera par polling).
    const base = PUBLIC_BASE_URL();
    try {
      await enkapFetch('/api/order/setup', {
        method: 'PUT',
        body: {
          returnUrl: `${base}/enkap/return`,
          notificationUrl: `${base}/enkap/callback`,
        },
      });
    } catch (setupErr) {
      console.warn('⚠️ ENKAP /order/setup échoué (best-effort):', setupErr.message);
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

/// PUT /enkap/order/setup — configure returnUrl + notificationUrl (relais
/// mobile/web). Utilisé par l'app en relais serveur (best-effort).
app.put('/enkap/order/setup', async (req, res) => {
  try {
    const b = req.body || {};
    const base = PUBLIC_BASE_URL();
    const returnUrl = (b.returnUrl || '').trim() || `${base}/enkap/return`;
    const notificationUrl =
      (b.notificationUrl || '').trim() || `${base}/enkap/callback`;
    const { status, data, text } = await enkapFetch('/api/order/setup', {
      method: 'PUT',
      body: { returnUrl, notificationUrl },
    });
    if (status !== 200) {
      return res
        .status(status)
        .json({ success: false, error: data.message || text });
    }
    res.json({ success: true, returnUrl, notificationUrl });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
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

// ============================================================
//  ENVOI D'EMAIL (SMTP côté serveur)
//
//  Les secrets SMTP restent dans les variables d'environnement Vercel.
//  Le client mobile n'a donc pas besoin d'embarquer les identifiants
//  (impossible de façon sûre) ni d'ouvrir un port SMTP depuis le téléphone
//  (souvent bloqué par les opérateurs → les mails « ne marchent pas » sur
//  mobile). Le client POSTe ici, le serveur envoie via nodemailer.
// ============================================================
const nodemailer = require('nodemailer');

// POST /email/send — limité en débit (anti-spam/brute-force) + validation.
app.post(
  '/email/send',
  rateLimit({ windowMs: 60 * 1000, max: 15, keyPrefix: 'email' }),
  async (req, res) => {
    try {
      const { to, subject, body, html, cc, bcc } = req.body || {};
      if (!to || (!body && !html)) {
        return res.status(400).json({ error: 'to et (body|html) requis' });
      }

      // 🔒 Validation stricte : emails valides, tailles bornées, pas
      // d'injection d'en-têtes (retours à la ligne dans le sujet).
      const recipients = Array.isArray(to) ? to : [to];
      if (recipients.length > 10 || recipients.some((r) => !isValidEmail(r))) {
        return res.status(400).json({ error: 'Destinataire(s) invalide(s)' });
      }
      const subjectStr = String(subject || 'NOI OHADA Invoice Pro');
      if (subjectStr.length > 200 || /[\r\n]/.test(subjectStr)) {
        return res
          .status(400)
          .json({ error: 'Sujet invalide (trop long ou caractères interdits)' });
      }
      const bodyStr = String(html || body || '');
      if (bodyStr.length > 50000) {
        return res.status(400).json({ error: 'Corps du message trop long' });
      }

      const host = process.env.SMTP_HOST || 'smtp.gmail.com';
      const port = Number(process.env.SMTP_PORT || 587);
      const user = (process.env.SMTP_USERNAME || '').trim();
      const pass = (process.env.SMTP_PASSWORD || '').trim();
      const fromEmail = (process.env.SMTP_FROM_EMAIL || user).trim();
      const fromName = (process.env.SMTP_FROM_NAME || 'Noi OHADA Invoice Pro').trim();

      if (!user || !pass) {
        return res
          .status(500)
          .json({ error: 'SMTP non configuré côté serveur (SMTP_USERNAME/SMTP_PASSWORD)' });
      }

      const transporter = nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        auth: { user, pass },
      });

      await transporter.sendMail({
        from: `"${fromName.replace(/[\r\n"]/g, '')}" <${fromEmail}>`,
        to: recipients.join(','),
        cc: cc ? (Array.isArray(cc) ? cc.join(',') : String(cc)) : undefined,
        bcc: bcc ? (Array.isArray(bcc) ? bcc.join(',') : String(bcc)) : undefined,
        subject: subjectStr,
        text: html ? undefined : bodyStr,
        html: html ? bodyStr : undefined,
      });

      res.json({ ok: true });
    } catch (e) {
      console.error('❌ /email/send error:', e.message);
      res.status(500).json({ error: e.message });
    }
  }
);

// ============================================================
//  CRÉDIT SÉCURISÉ DU PORTEFEUILLE (intégrité du solde)
//
//  🔴 Avant, le client créditait son propre portefeuille en écrivant
//  directement dans Firestore → un utilisateur malveillant pouvait s'auto-
//  attribuer un solde arbitraire. Désormais :
//    1. Le client POSTe ici (userId + reference + montant).
//    2. Le serveur VÉRIFIE avec E-nkap que la commande est bien CONFIRMÉE.
//    3. Le serveur crédite via le SDK admin (contourne les règles, qui
//       n'autorisent désormais que l'admin à écrire le solde).
//  Idempotent : si la référence a déjà crédité, on ne crédite pas 2 fois.
// ============================================================
app.post(
  '/wallet/credit',
  rateLimit({ windowMs: 60 * 1000, max: 20, keyPrefix: 'wallet' }),
  async (req, res) => {
    try {
      const { userId, amount, reference, description } = req.body || {};
      if (!userId || !reference) {
        return res.status(400).json({ error: 'userId/reference requis' });
      }
      const amt = Number(amount);
      if (!Number.isFinite(amt) || amt <= 0 || amt > 100000000) {
        return res.status(400).json({ error: 'Montant invalide' });
      }

      // 1) Vérifie auprès d'E-nkap que la commande est confirmée.
      let status = '';
      try {
        const r = await enkapFetch(
          `/api/order/status?orderMerchantId=${encodeURIComponent(reference)}`
        );
        status = (r.data && r.data.status) || '';
      } catch (_) {
        /* réseau/ENKAP : traité plus bas */
      }
      if (!['CONFIRMED', 'COMPLETED'].includes(status.toUpperCase())) {
        return res
          .status(400)
          .json({ error: `Paiement non confirmé par ENKAP (${status || 'inconnu'})` });
      }

      // 2) Idempotence : pas de double crédit pour la même référence
      //    (requête mono-champ `reference` = auto-indexée).
      const existing = await db
        .collection('wallet_transactions')
        .where('reference', '==', reference)
        .limit(1)
        .get();
      if (!existing.empty) {
        const existingType = existing.docs[0].data().type;
        if (existingType === 'credit') {
          return res.json({ ok: true, alreadyCredited: true });
        }
      }

      // 3) Crédit atomique + journalisation.
      const walletRef = db.collection('wallets').doc(userId);
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(walletRef);
        const current = (snap.data() && snap.data().balance) || 0;
        tx.set(
          walletRef,
          {
            userId,
            balance: (Number(current) || 0) + amt,
            currency: 'XAF',
            updatedAt: serverTimestamp(),
          },
          { merge: true }
        );
      });
      await db.collection('wallet_transactions').add({
        userId,
        type: 'credit',
        amount: amt,
        currency: 'XAF',
        reference,
        description: String(description || 'Encaissement en ligne'),
        createdAt: serverTimestamp(),
      });

      res.json({ ok: true });
    } catch (e) {
      console.error('❌ /wallet/credit error:', e.message);
      res.status(500).json({ error: e.message });
    }
  }
);

app.get('/', (req, res) =>
  res.json({
    service: 'NOI OHADA — callbacks paiement (ENKAP) + email',
    endpoints: [
      'POST /enkap/register',
      'PUT /enkap/callback/:reference',
      'GET /enkap/return/:reference',
      'POST /enkap/order (proxy web/mobile)',
      'GET /enkap/order/status (proxy web/mobile)',
      'PUT /enkap/order/setup (proxy web/mobile)',
      'GET /enkap/order (proxy web/mobile)',
      'POST /email/send (SMTP côté serveur)',
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
