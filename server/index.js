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
const { getMessaging } = require('firebase-admin/messaging');
const logger = require('./logger');
const crypto = require('crypto');

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
    logger.warn('⚠️ metadata sans user_id/plan_id — activation impossible');
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
    logger.warn('⚠️ plan introuvable, interval défaut month', { error: e.message });
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
// d'appeler ces endpoints depuis un navigateur. On autorise :
//   - les origines explicitement listées (domaine public de production),
//   - TOUT `localhost` / `127.0.0.1` quel que soit le port (Flutter web en
//     dev utilise un port aléatoire à chaque lancement → sans ça, le
//     paiement échoue en dev par CORS),
//   - les aperçus Vercel (`*.vercel.app`).
const ALLOWED_ORIGINS = new Set(
  (process.env.ALLOWED_ORIGINS || 'https://ohada-invoice-pro.com')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
);

function isAllowedOrigin(origin) {
  if (!origin) return false;
  try {
    const u = new URL(origin);
    const host = u.hostname.toLowerCase();
    if (host === 'localhost' || host === '127.0.0.1' || host === '[::1]') {
      return true; // développement local (port quelconque)
    }
    if (host.endsWith('.vercel.app')) return true; // aperçus Vercel
    return ALLOWED_ORIGINS.has(origin);
  } catch (_) {
    return false;
  }
}

app.use((req, res, next) => {
  const origin = req.headers.origin;
  if (origin && isAllowedOrigin(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept, X-API-Key');
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
//  🔐 PROTECTION API — clé secrète obligatoire (entête `x-api-key`)
//
//  L'application Flutter envoie la clé dans chaque appel (injectée au
//  build via `--dart-define=API_SECRET_KEY=...` → ConfigService
//  .serverHeaders()). Les endpoints publiés ci-dessous restent PUBLICS :
//    • / et /health        : sonde de disponibilité
//    • /download           : lien public de téléchargement de l'app
//    • /enkap/callback/:r  : webhook ITN du PSP E-nkap (serveur→serveur,
//                            il ne peut pas envoyer notre clé)
//    • /enkap/return/:r    : page de retour après paiement (navigateur)
//    • /enkap/order/status : statut de commande consulté par la page web
//  Si API_SECRET_KEY n'est pas configurée → fail-open (rétro-compatibilité
//  avec les déploiements existants) ; configurez-la pour verrouiller.
// ============================================================
const PUBLIC_PATHS = new Set(['/', '/health', '/download']);

function requestIsPublic(req) {
  const p = String(req.path || '');
  if (PUBLIC_PATHS.has(p)) return true;
  if (p.startsWith('/enkap/callback/')) return true;
  if (p.startsWith('/enkap/return/')) return true;
  if (p === '/enkap/order/status') return true;
  return false;
}

/// Comparaison à temps constant (anti timing-attack) : on compare les
/// SHA-256 pour égaliser les longueurs avant timingSafeEqual.
function safeEqual(a, b) {
  const ha = crypto.createHash('sha256').update(String(a)).digest();
  const hb = crypto.createHash('sha256').update(String(b)).digest();
  return crypto.timingSafeEqual(ha, hb);
}

function requireApiKey(req, res, next) {
  const configured = String(process.env.API_SECRET_KEY || '').trim();
  if (!configured || requestIsPublic(req)) return next();
  const provided = String(req.headers['x-api-key'] || '').trim();
  if (provided && safeEqual(provided, configured)) return next();
  logger.warn('⛔ clé API invalide', { path: req.path, ip: (req.headers['x-forwarded-for'] || '').split(',')[0].trim() });
  return res
    .status(401)
    .json({ error: 'Accès non autorisé (clé API manquante ou invalide)' });
}

// Enregistrement AVANT toutes les routes (le CORS/OPTIONS ci-dessus reste
// prioritaire pour que les preflight navigateur ne soient pas bloqués).
app.use(requireApiKey);

// 🔗 Lien public de téléchargement de l'application : redirige vers l'URL
// courante de l'APK / de la boutique (variable APP_DOWNLOAD_URL) — le lien
// distribué aux utilisateurs reste STABLE même si l'APK change d'hébergeur.
app.get('/download', (req, res) => {
  const target = String(process.env.APP_DOWNLOAD_URL || '').trim();
  if (!target) {
    return res
      .status(404)
      .json({ error: 'Lien de téléchargement non configuré (APP_DOWNLOAD_URL)' });
  }
  return res.redirect(302, target);
});

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
    logger.error('❌ /enkap/register error:', { error: e.message });
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

    logger.info(
      `✅ ENKAP callback — ref=${reference} status=${status || 'N/A'} confirmed=${confirmed} activated=${activated}`
    );
    res.status(200).json({ received: true, confirmed, activated });
  } catch (e) {
    logger.error('❌ /enkap/callback error:', { error: e.message });
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
      logger.warn('⚠️ ENKAP /order/setup échoué (best-effort):', { error: setupErr.message });
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
        // 🔧 Timeouts pour ne pas bloquer la fonction Vercel (>10s = 504).
        connectionTimeout: SMTP_CONNECT_TIMEOUT,
        socketTimeout: SMTP_SOCKET_TIMEOUT,
        greetingTimeout: SMTP_CONNECT_TIMEOUT,
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
      logger.error('❌ /email/send error:', { error: e.message });
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
      logger.error('❌ /wallet/credit error:', { error: e.message });
      res.status(500).json({ error: e.message });
    }
  }
);

// ============================================================
//  ACHAT DE MODÈLES DE FACTURE (déblocage sécurisé)
//
//  🔒 Le client ne peut PLUS marquer lui-même un modèle comme acheté
//  (règles : écriture templates = admin uniquement). Ici :
//    1. Si le panier contient un modèle PAYANT → une `reference` ENKAP
//       confirmée est requise (le serveur vérifie auprès d'E-nkap).
//    2. Les modèles GRATUITS (prix 0 défini par l'admin) sont débloqués
//       SANS paiement.
//    3. Le serveur ajoute l'userId à `purchasedBy` (idempotent) via le
//       SDK admin (contourne les règles → seule vraie autorité).
// ============================================================
app.post(
  '/template/purchase',
  rateLimit({ windowMs: 60 * 1000, max: 20, keyPrefix: 'tpl' }),
  async (req, res) => {
    try {
      const { userId, templateIds, reference } = req.body || {};
      if (
        !userId ||
        !Array.isArray(templateIds) ||
        templateIds.length === 0 ||
        templateIds.length > 50
      ) {
        return res.status(400).json({ error: 'userId/templateIds requis' });
      }

      // Charge les modèles (doc id = id du modèle). Les id inconnus (ex.
      // modèles "par défaut" définis en code, toujours gratuits) sont
      // ignorés : ils sont disponibles sans déblocage serveur.
      const templates = [];
      for (const id of templateIds) {
        const doc = await db.collection('templates').doc(String(id)).get();
        if (doc.exists) templates.push({ id: doc.id, data: doc.data() });
      }
      if (templates.length === 0) {
        // Rien à persister (modèles par défaut) → succès sans action.
        return res.json({ ok: true, unlocked: 0, total: templateIds.length, paid: 0 });
      }

      // Y a-t-il des modèles PAYANTS dans le panier ?
      const paidTemplates = templates.filter((t) => (t.data.price || 0) > 0);
      if (paidTemplates.length > 0) {
        if (!reference) {
          return res
            .status(400)
            .json({ error: 'Paiement requis (référence manquante)' });
        }
        // Vérifie auprès d'E-nkap que la commande est bien confirmée.
        let status = '';
        try {
          const r = await enkapFetch(
            `/api/order/status?orderMerchantId=${encodeURIComponent(reference)}`
          );
          status = (r.data && r.data.status) || '';
        } catch (_) {
          /* traité plus bas */
        }
        if (!['CONFIRMED', 'COMPLETED'].includes(status.toUpperCase())) {
          return res.status(400).json({
            error: `Paiement non confirmé par ENKAP (${status || 'inconnu'})`,
          });
        }
      }

      // Déblocage idempotent : ajoute l'userId à `purchasedBy`.
      let unlocked = 0;
      for (const t of templates) {
        const pb = Array.isArray(t.data.purchasedBy) ? t.data.purchasedBy : [];
        if (!pb.includes(userId)) {
          await db.collection('templates').doc(t.id).update({
            purchasedBy: [...pb, userId],
            updatedAt: serverTimestamp(),
          });
          unlocked++;
        }
      }

      res.json({
        ok: true,
        unlocked,
        total: templates.length,
        paid: paidTemplates.length,
      });
    } catch (e) {
      logger.error('❌ /template/purchase error:', { error: e.message });
      res.status(500).json({ error: e.message });
    }
  }
);

// ============================================================
//  HELPERS ÉQUIPES : EMAIL (nodemailer) + NOTIFICATION Firestore
// ============================================================
// NB : `nodemailer` est déjà requis plus haut (endpoint /email/send).

// Envoi d'email via SMTP serveur (best-effort, ne lève pas).
// Timeout par défaut (ms) pour éviter de bloquer la fonction Vercel si le
// serveur SMTP est injoignable ou lent.
const SMTP_CONNECT_TIMEOUT = Number(process.env.SMTP_CONNECT_TIMEOUT || 5000);
const SMTP_SOCKET_TIMEOUT = Number(process.env.SMTP_SOCKET_TIMEOUT || 5000);

async function sendMail({ to, subject, text, html }) {
  const host = process.env.SMTP_HOST || 'smtp.gmail.com';
  const port = Number(process.env.SMTP_PORT || 587);
  const user = (process.env.SMTP_USERNAME || '').trim();
  const pass = (process.env.SMTP_PASSWORD || '').trim();
  const fromEmail = (process.env.SMTP_FROM_EMAIL || user).trim();
  const fromName = (process.env.SMTP_FROM_NAME || 'Noi OHADA Invoice Pro').trim();
  if (!user || !pass) {
    logger.warn('⚠️ sendMail: SMTP non configuré côté serveur');
    return false;
  }
  try {
    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
      // 🔧 Timeouts pour ne pas bloquer la fonction Vercel (>10s = 504).
      connectionTimeout: SMTP_CONNECT_TIMEOUT,
      socketTimeout: SMTP_SOCKET_TIMEOUT,
      greetingTimeout: SMTP_CONNECT_TIMEOUT,
    });
    await transporter.sendMail({
      from: `"${fromName.replace(/[\r\n"]/g, '')}" <${fromEmail}>`,
      to: String(to || '').trim(),
      subject: String(subject || '').slice(0, 200),
      text: html ? undefined : text,
      html: html || undefined,
    });
    return true;
  } catch (e) {
    logger.warn('⚠️ sendMail échec:', { error: e.message });
    return false;
  }
}

// Version avec timeout global : enveloppe sendMail dans une course contre
// une promesse de timeout. Garantit que l'appel ne bloque jamais plus de
// `maxMs` millisecondes (utile pour les endpoints critiques comme l'invite).
function sendMailWithTimeout(mailOptions, maxMs = 8000) {
  return Promise.race([
    sendMail(mailOptions),
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error('sendMail timeout')), maxMs),
    ),
  ]);
}

// Écrit une notification Firestore pour un utilisateur (SDK admin →
// contourne les règles). `userId` = destinataire, `createdBy` = émetteur.
// ============================================================
//  PUSH (FCM) — notification système vers tous les appareils d'un user
//
//  Les tokens sont enregistrés par l'app Flutter dans `fcm_tokens/{token}`
//  (PushNotificationService) : { uid, platform, updatedAt }. Le serveur
//  (SDK admin) lit cette collection pour délivrer la push.
// ============================================================
const PUSH_MAX_TOKENS_PER_USER = 20;

async function sendPushToUser(userId, { title, body, refId, refType, data } = {}) {
  try {
    if (!userId) return;
    const tokensSnap = await db
      .collection('fcm_tokens')
      .where('uid', '==', userId)
      .limit(PUSH_MAX_TOKENS_PER_USER)
      .get();
    const tokens = tokensSnap.docs.map((d) => d.id).filter(Boolean);
    if (!tokens.length) return;

    // Le champ `data` FCM n'accepte que des chaînes (app → deep link).
    const payloadData = {};
    if (refId) payloadData.referenceId = String(refId);
    if (refType) payloadData.referenceType = String(refType);
    if (data && typeof data === 'object') {
      for (const [k, v] of Object.entries(data)) {
        if (v == null) continue;
        payloadData[String(k).slice(0, 64)] = String(v).slice(0, 256);
      }
    }

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: String(title || '').slice(0, 150),
        body: String(body || '').slice(0, 300),
      },
      data: payloadData,
      android: {
        priority: 'high',
        notification: { channelId: 'noi_notifications' },
      },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });

    // Purge des tokens morts (app désinstallée / token révoqué).
    const deadTokens = [];
    response.responses.forEach((r, i) => {
      if (r.success) return;
      const code = String(r.error?.code || '');
      if (
        code.includes('registration-token-not-registered') ||
        code.includes('invalid-registration-token') ||
        code.includes('invalid-argument')
      ) {
        deadTokens.push(tokens[i]);
      }
    });
    await Promise.all(
      deadTokens.map((t) =>
        db.collection('fcm_tokens').doc(t).delete().catch(() => {}),
      ),
    );

    logger.info('push sent', {
      userId,
      ok: response.successCount,
      fail: response.failureCount,
      purged: deadTokens.length,
    });
  } catch (e) {
    logger.warn('⚠️ sendPushToUser échec:', { error: e.message });
  }
}

async function createNotification({
  userId,
  type,
  title,
  body,
  createdBy,
  refId,
  refType,
  data,
}) {
  try {
    const ref = db.collection('notifications').doc();
    await ref.set({
      id: ref.id,
      title: String(title || ''),
      body: String(body || ''),
      type: String(type || 'system_update'),
      timestamp: new Date(),
      createdAt: serverTimestamp(),
      isRead: false,
      referenceId: refId || null,
      referenceType: refType || null,
      data: data || null,
      userId,
      recipients: [userId],
      createdBy: createdBy || '',
    });

    // 🔔 Push FCM (non-bloquant) : bannière système sur les appareils du
    // destinataire. L'échec d'une push ne doit JAMAIS faire échouer la
    // notification Firestore (source de vérité de l'app).
    sendPushToUser(userId, { title, body, refId, refType, data }).catch(
      (e) => logger.warn('⚠️ push createNotification:', { error: e.message }),
    );
  } catch (e) {
    logger.warn('⚠️ createNotification échec:', { error: e.message });
  }
}

// ============================================================
//  GESTION DES MEMBRES D'ÉQUIPE (via SDK admin)
//
//  🔒 Le client ne peut PAS écrire sur `teams` (règles : seul le
//  propriétaire / admin global), ni résoudre un email → UID (lecture
//  `users` restreinte), ni révoquer l'accès d'un membre sur les ressources
//  des autres. Cet endpoint centralise ces opérations (SDK admin) :
//    invite          : invite un membre par EMAIL (notif + mail envoyés)
//    accept / decline: l'invité répond (le propriétaire est prévenu)
//    get-invitations  : liste les invitations en attente d'un utilisateur
//    remove   : retire un membre + révoque son accès aux partages
//    promote / demote : change le rôle (admin), utilisable par un admin
//    leave    : un membre quitte + perd l'accès aux partages
// ============================================================
app.post(
  '/team/manage-member',
  rateLimit({ windowMs: 60 * 1000, max: 30, keyPrefix: 'team' }),
  async (req, res) => {
    try {
      const { action, teamId, userId, email, role, requestedBy, invitationId } =
        req.body || {};
      if (!action || !requestedBy) {
        return res.status(400).json({ error: 'action/requestedBy requis' });
      }

      // Les actions centrées sur l'INVITATION n'exigent pas de teamId :
      // l'invité liste et répond sans connaître l'équipe (l'invitation porte
      // son propre teamId). Les autres actions (invite/remove/leave/promote/
      // demote) opèrent sur une équipe et l'exigent.
      const invitationActions = ['accept', 'decline', 'get-invitations'];
      if (!invitationActions.includes(action) && !teamId) {
        return res.status(400).json({ error: 'teamId requis' });
      }

      // Contexte équipe (résolu uniquement pour les actions liées à une équipe).
      let team = {};
      let teamRef = null;
      let admins = [];
      let members = [];
      let isManager = false;
      if (teamId) {
        teamRef = db.collection('teams').doc(teamId);
        const teamSnap = await teamRef.get();
        if (!teamSnap.exists) {
          return res.status(404).json({ error: 'Équipe non trouvée' });
        }
        team = teamSnap.data() || {};
        if (team.isActive === false) {
          return res.status(400).json({ error: 'Équipe désactivée' });
        }
        admins = Array.isArray(team.adminIds) ? team.adminIds : [];
        members = Array.isArray(team.memberIds) ? team.memberIds : [];
        isManager =
          team.ownerId === requestedBy || admins.includes(requestedBy);
      }

      // ===== INVITE : inviter un membre par email =====
      // Crée une invitation EN ATTENTE, envoie une NOTIFICATION (toast) à
      // l'invité et un EMAIL. L'invité devra accepter pour rejoindre l'équipe.
      if (action === 'invite') {
        if (!isManager) {
          return res.status(403).json({ error: 'Non autorisé' });
        }
        if (!email || !isValidEmail(email)) {
          return res.status(400).json({ error: 'Email invalide' });
        }
        const memberRole = role === 'admin' ? 'admin' : 'member';
        // Résout l'email → UID via la collection `users` (le module Auth
        // firebase-admin tire `jose`, un paquet ESM incompatible avec le
        // runtime Vercel → on l'évite ici). Firebase Auth normalise les
        // emails en minuscules, on compare donc en minuscules.
        const emailKey = String(email).trim().toLowerCase();
        const userSnap = await db
          .collection('users')
          .where('email', '==', emailKey)
          .limit(1)
          .get();
        if (userSnap.empty) {
          return res
            .status(404)
            .json({ error: 'Aucun compte NOI OHADA avec cet email' });
        }
        const inviteeUid = userSnap.docs[0].id;
        const userData = userSnap.docs[0].data() || {};
        if (members.includes(inviteeUid) || admins.includes(inviteeUid)) {
          return res.json({ ok: true, alreadyMember: true, uid: inviteeUid });
        }
        // Invitation déjà en attente pour ce membre / cette équipe ?
        const pending = await db
          .collection('team_invitations')
          .where('teamId', '==', teamId)
          .where('inviteeUid', '==', inviteeUid)
          .where('status', '==', 'pending')
          .limit(1)
          .get();
        if (!pending.empty) {
          return res.json({ ok: true, alreadyInvited: true, uid: inviteeUid });
        }

        const inviterData =
          (await db.collection('users').doc(requestedBy).get()).data() || {};
        const inviterName =
          inviterData.displayName || inviterData.name || 'Un propriétaire';
        const teamName = team.name || 'votre équipe';

        const invRef = db.collection('team_invitations').doc();
        await invRef.set({
          id: invRef.id,
          teamId,
          teamName,
          inviterUid: requestedBy,
          inviterName,
          inviteeUid,
          email: emailKey,
          role: memberRole,
          status: 'pending',
          createdAt: serverTimestamp(),
          respondedAt: null,
        });

        // 📢 Notification (toast) à l'invité.
        await createNotification({
          userId: inviteeUid,
          createdBy: requestedBy,
          type: 'team_invite',
          title: '🤝 Invitation à rejoindre une équipe',
          body: `${inviterName} vous invite à rejoindre « ${teamName} ».`,
          refId: invRef.id,
          refType: 'team_invite',
          data: { teamId, teamName, inviterName, role: memberRole },
        });

        // ✉️ Email à l'invité (non-bloquant avec timeout — l'invitation est
        // déjà créée et la notification envoyée, l'email est secondaire).
        sendMailWithTimeout({
          to: emailKey,
          subject: `Invitation à rejoindre « ${teamName} » sur NOI OHADA Invoice Pro`,
          text:
            `Bonjour,\n\n` +
            `${inviterName} vous invite à rejoindre l'équipe « ${teamName} » ` +
            `sur NOI OHADA Invoice Pro.\n\n` +
            `Connectez-vous à votre compte : dans l'onglet Équipes, ouvrez ` +
            `« Mes invitations » et acceptez l'invitation.\n\n` +
            `À très bientôt,\nL'équipe NOI OHADA Invoice Pro`,
        }).catch((e) =>
          logger.warn('⚠️ sendMail invite échec/timeout:', { error: e.message }),
        );

        logger.info('team invite-member', {
          teamId,
          uid: inviteeUid,
          by: requestedBy,
        });
        return res.json({
          ok: true,
          uid: inviteeUid,
          name: userData.displayName || userData.name || '',
          email: userData.email || emailKey,
        });
      }

      // ===== ACCEPT / DECLINE : réponse de l'invité =====
      // L'invité accepte (→ devient membre) ou refuse. Le propriétaire est
      // prévenu par notification (+ email à l'acceptation).
      if (action === 'accept' || action === 'decline') {
        if (!invitationId) {
          return res.status(400).json({ error: 'invitationId requis' });
        }
        const invSnap = await db
          .collection('team_invitations')
          .doc(invitationId)
          .get();
        if (!invSnap.exists) {
          return res.status(404).json({ error: 'Invitation introuvable' });
        }
        const inv = invSnap.data() || {};
        // Seul l'invité peut répondre.
        if (inv.inviteeUid !== requestedBy) {
          return res.status(403).json({ error: 'Non autorisé' });
        }
        if (inv.status !== 'pending') {
          return res.status(400).json({ error: 'Invitation déjà traitée' });
        }
        // ⚠️ SDK Node : arrayUnion/arrayRemove sont VARIADIQUES — passer un
        // tableau créerait un tableau IMBRIQUÉ, refusé par Firestore
        // (« Nested arrays are not supported ») → c'était le bug de
        // l'acceptation d'invitation.
        const invTeamId = String(inv.teamId || '');
        const teamSnap = invTeamId
          ? await db.collection('teams').doc(invTeamId).get()
          : null;

        // 🔒 Écriture ATOMIQUE : statut de l'invitation + ajout du membre
        // dans le MÊME batch — impossible de finir avec une invitation
        // « accepted » mais un membre non ajouté (état incohérent).
        const batch = db.batch();
        batch.update(invSnap.ref, {
          status: action === 'accept' ? 'accepted' : 'declined',
          respondedAt: serverTimestamp(),
        });
        if (
          action === 'accept' &&
          teamSnap &&
          teamSnap.exists &&
          teamSnap.data() &&
          teamSnap.data().isActive !== false
        ) {
          batch.update(teamSnap.ref, {
            memberIds: FieldValue.arrayUnion(requestedBy),
            adminIds:
              inv.role === 'admin'
                ? FieldValue.arrayUnion(requestedBy)
                : FieldValue.arrayRemove(requestedBy),
            updatedAt: serverTimestamp(),
          });
        }
        await batch.commit();

        // 📢 Message (notification) au propriétaire.
        const inviteeData =
          (await db.collection('users').doc(requestedBy).get()).data() || {};
        const inviteeName =
          inviteeData.displayName || inviteeData.name || 'Un membre';
        const teamData =
          teamSnap && teamSnap.exists ? teamSnap.data() || {} : {};
        const ownerId = teamData.ownerId || inv.inviterUid;
        const teamDisplay = inv.teamName || 'votre équipe';
        await createNotification({
          userId: ownerId,
          createdBy: requestedBy,
          type: 'team_invite_accepted',
          title:
            action === 'accept'
              ? '✅ Invitation acceptée'
              : '❌ Invitation refusée',
          body:
            action === 'accept'
              ? `${inviteeName} a accepté votre invitation à rejoindre « ${teamDisplay} ».`
              : `${inviteeName} a refusé votre invitation à rejoindre « ${teamDisplay} ».`,
          refId: String(inv.teamId || ''),
          refType: 'team',
          data: {
            teamId: inv.teamId,
            memberName: inviteeName,
            memberUid: requestedBy,
          },
        });

        // ✉️ Email au propriétaire (à l'acceptation).
        if (action === 'accept') {
          const ownerData =
            (await db.collection('users').doc(ownerId).get()).data() || {};
          if (ownerData.email) {
            sendMailWithTimeout({
              to: ownerData.email,
              subject: `« ${teamDisplay} » : ${inviteeName} a accepté l'invitation`,
              text:
                `Bonjour,\n\n${inviteeName} a accepté votre invitation et rejoint ` +
                `l'équipe « ${teamDisplay} » sur NOI OHADA Invoice Pro.\n\n` +
                `À très bientôt,\nL'équipe NOI OHADA Invoice Pro`,
            }).catch((e) =>
              logger.warn('⚠️ sendMail accept échec/timeout:', { error: e.message }),
            );
          }
        }

        logger.info('team invitation respond', {
          invitationId,
          action,
          by: requestedBy,
        });
        return res.json({ ok: true });
      }

      // ===== GET-INVITATIONS : invitations en attente d'un utilisateur =====
      if (action === 'get-invitations') {
        const target = userId || requestedBy;
        if (!target) {
          return res.status(400).json({ error: 'userId requis' });
        }
        const snap = await db
          .collection('team_invitations')
          .where('inviteeUid', '==', target)
          .get();
        // NB : on évite un index composite Firestore (inutile et souvent non
        // créé en production) en filtrant sur `status` et en triant ici.
        const invitations = snap.docs
          .map((d) => {
            const raw = d.data() || {};
            return { id: d.id, raw };
          })
          .filter((e) => (e.raw.status || 'pending') === 'pending')
          .sort((a, b) => {
            const ta = a.raw.createdAt;
            const tb = b.raw.createdAt;
            return (tb ? tb.toDate().getTime() : 0) -
                (ta ? ta.toDate().getTime() : 0);
          })
          .map((e) => {
            const data = e.raw;
            return {
              id: e.id,
              teamId: data.teamId,
              teamName: data.teamName || '',
              inviterName: data.inviterName || '',
              inviterUid: data.inviterUid,
              role: data.role || 'member',
              createdAt: data.createdAt
                  ? data.createdAt.toDate().toISOString()
                  : null,
            };
          });
        return res.json({ ok: true, invitations });
      }

      // ===== REMOVE / LEAVE : retirer un membre + révoquer l'accès =====
      if (action === 'remove' || action === 'leave') {
        if (!userId) {
          return res.status(400).json({ error: 'userId requis' });
        }
        if (action === 'remove') {
          if (!isManager) {
            return res.status(403).json({ error: 'Non autorisé' });
          }
        } else if (userId !== requestedBy) {
          // leave : on ne peut quitter que soi-même.
          return res.status(403).json({ error: 'Non autorisé' });
        }
        if (team.ownerId === userId) {
          return res
            .status(400)
            .json({ error: 'Le propriétaire ne peut pas être retiré' });
        }
        await teamRef.update({
          memberIds: FieldValue.arrayRemove(userId),
          adminIds: FieldValue.arrayRemove(userId),
          updatedAt: serverTimestamp(),
        });
        // Révocation : désactive les partages qui mentionnaient ce membre et
        // le retire des ressources partagées (il perd l'accès).
        const shares = await db
          .collection('shared_invoices')
          .where('teamId', '==', teamId)
          .where('isActive', '==', true)
          .get();
        for (const s of shares.docs) {
          const d = s.data() || {};
          if (!Array.isArray(d.sharedWith) || !d.sharedWith.includes(userId)) {
            continue;
          }
          await s.ref.update({ isActive: false, expiresAt: serverTimestamp() });
          if (d.resourceType && d.invoiceId) {
            const coll =
              d.resourceType === 'product'
                ? 'products'
                : d.resourceType === 'client'
                ? 'clients'
                : 'invoices';
            try {
              await db
                .collection(coll)
                .doc(d.invoiceId)
                .update({ sharedWithUsers: FieldValue.arrayRemove(userId) });
            } catch (_) {
              /* doc introuvable / déjà retiré */
            }
          }
        }
        logger.info('team remove/leave', {
          teamId,
          userId,
          action,
          by: requestedBy,
        });
        return res.json({ ok: true });
      }

      // ===== PROMOTE / DEMOTE : changement de rôle =====
      if (action === 'promote' || action === 'demote') {
        if (!isManager) {
          return res.status(403).json({ error: 'Non autorisé' });
        }
        if (!userId) {
          return res.status(400).json({ error: 'userId requis' });
        }
        if (team.ownerId === userId && action === 'demote') {
          return res
            .status(400)
            .json({ error: 'Le propriétaire ne peut pas être rétrogradé' });
        }
        await teamRef.update({
          adminIds:
            action === 'promote'
              ? FieldValue.arrayUnion(userId)
              : FieldValue.arrayRemove(userId),
          updatedAt: serverTimestamp(),
        });
        logger.info('team promote/demote', {
          teamId,
          userId,
          action,
          by: requestedBy,
        });
        return res.json({ ok: true });
      }

      return res.status(400).json({ error: 'Action inconnue' });
    } catch (e) {
      logger.error('❌ /team/manage-member error:', { error: e.message });
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
      'POST /wallet/credit (vérifié ENKAP)',
      'POST /template/purchase (vérifié ENKAP)',
      'POST /team/manage-member (invitations + membres équipe)',
      'GET /health',
    ],
  })
);

// ============================================================
//  MIDDLEWARE D'ERREURS GLOBAL (journalisation)
// ============================================================
// Toute erreur non capturée est journalisée (console + fichier) avant de
// répondre 500. NB : les handlers utilisent déjà try/catch ; celui-ci est
// un filet de sécurité pour les erreurs inattendues.
app.use((err, req, res, next) => {
  logger.error(
    `Unhandled error on ${req.method} ${req.originalUrl}`,
    { error: err && err.message, stack: err && err.stack }
  );
  if (res.headersSent) return next(err);
  res.status(500).json({ error: 'Erreur interne du serveur' });
});

// ============================================================
//  EXPORT POUR VERCEL / EXÉCUTION DIRECTE
// ============================================================
// Vercel (serverless) : exporter l'app Express — pas de listen.
module.exports = app;

// Exécution directe (node index.js / npm start) : on écoute.
if (require.main === module) {
  app.listen(PORT, () => {
    logger.info(`🚀 Serveur prêt sur le port ${PORT}`);
    logger.info(`Webhook secret configuré : ${getWebhookSecret() ? 'oui' : 'NON (⚠️)'}`);
  });
}
