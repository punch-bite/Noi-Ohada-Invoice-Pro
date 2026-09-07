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
const PUBLIC_PATHS = new Set(['/', '/health', '/download', '/logo.png', '/favicon.png']);

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
///
/// NB : le handler ci-dessous (SANS segment) gère aussi le cas où E-nkap
/// appelle le `returnUrl` EXACT sans apposer la référence (setup ignoré,
/// anciennes commandes…) — sinon le WebView intégré affiche le 404 brut
/// « Cannot GET /enkap/return » (HTML illisible).
app.get('/enkap/return', (req, res) => {
  const reference = escapeHtml(
    (req.query.orderMerchantId ||
      req.query.merchantReferenceId ||
      req.query.reference ||
      '').toString(),
  );
  const status = escapeHtml(
    (req.query.status || req.query.orderStatus || '').toString(),
  );
  sendReturnPage(res, reference, status);
});

app.get('/enkap/return/:reference', (req, res) => {
  const reference = escapeHtml(req.params.reference || '');
  const status = escapeHtml((req.query.status || '').toString());
  sendReturnPage(res, reference, status);
});

/// Construit et envoie la page de confirmation de paiement. Utilisée par les
/// deux variantes de la route de retour (avec/sans référence).
function sendReturnPage(res, reference, status) {
  const ok = (status || '').toUpperCase() === 'CONFIRMED';
  const failed = ['FAILED', 'CANCELED', 'CANCELLED'].includes(
    (status || '').toUpperCase(),
  );
  const icon = ok ? '✅' : failed ? '❌' : 'ℹ️';
  const title = ok
    ? 'Paiement confirmé'
    : failed
    ? 'Paiement non abouti'
    : 'Retour de paiement';
  // Auto-retour dans la WebView : tente window.close() (fonctionne dans le
  // WebView intégré de l'app), sinon l'utilisateur utilise le bouton.
  res.status(200).type('html').send(`<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Paiement E-nkap</title>
<style>body{font-family:system-ui,sans-serif;background:#f5f6fa;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0}
.card{background:#fff;border-radius:16px;padding:32px;max-width:420px;text-align:center;box-shadow:0 8px 30px rgba(0,0,0,.08)}
.icon{font-size:56px} h1{font-size:20px;margin:12px 0 6px} p{color:#666;margin:4px 0;font-size:14px}
.btn{display:inline-block;margin-top:18px;padding:12px 22px;border-radius:10px;background:#4338ca;color:#fff;text-decoration:none;font-weight:600;border:none;font-size:14px}
.btn:active{opacity:.85}</style>
</head><body><div class="card">
<div class="icon">${icon}</div>
<h1>${title}</h1>
${reference ? `<p>Référence : <b>${reference}</b></p>` : ''}
<p>Statut : <b>${status || 'N/A'}</b></p>
<p>Vous pouvez fermer cette page et revenir à l'application.</p>
<button class="btn" onclick="window.close();history.length>1?history.back():null">← Revenir à l'application</button>
<script>
// Fermeture automatique dans le WebView intégré (window.close y est autorisé
// quand la page a été ouverte par l'app) ; sans effet dans un onglet externe.
setTimeout(function(){ try { window.close(); } catch (_) {} }, 1500);
</script>
</div></body></html>`);
}

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

// 🔒 Sonde de disponibilité — réponse MINIMALE : ne révèle ni le service,
// ni le nom du projet, ni les endpoints (les détails internes ne concernent
// pas le public).
app.get('/health', (req, res) => res.json({ ok: true }));

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

// ============================================================
//  🖼️ LOGO & FAVICON — servis depuis le bundle (server/public/)
//  Le vrai logo de l'application (mêmes fichiers que la PWA).
// ============================================================
app.get('/logo.png', (req, res) => {
  res.setHeader('Cache-Control', 'public, max-age=86400');
  res.sendFile(path.join(__dirname, 'public', 'logo.png'));
});
app.get('/favicon.png', (req, res) => {
  res.setHeader('Cache-Control', 'public, max-age=86400');
  res.sendFile(path.join(__dirname, 'public', 'favicon.png'));
});

// ── Icônes monochromes (SVG inline, style line-icons) ────────────────────────
// stroke=currentColor : héritent de la couleur du texte parent.
const ICON = {
  receipt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2h12v20l-2.5-1.8L13 22l-2.5-1.8L8 22l-2-1.5V2z"/><path d="M9 7.5h6M9 11.5h6M9 15.5h3.5"/></svg>',
  file: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6z"/><path d="M14 2v6h6M9 13h6M9 17h6"/></svg>',
  box: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8l9-5 9 5v8l-9 5-9-5V8z"/><path d="M3 8l9 5 9-5M12 13v8"/></svg>',
  chart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 21V11M12 21V4M19 21v-6M2.5 21h19"/></svg>',
  users: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c0-3.5 2.9-5.5 6.5-5.5s6.5 2 6.5 5.5"/><circle cx="17.5" cy="9" r="2.5"/><path d="M16.5 14.6c2.7.4 5 2.1 5 4.9"/></svg>',
  brush: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M15.5 3.5l5 5L9.5 19.5c-.9.9-2.7 1.4-4.9 1.4-.2-2.2.4-4 1.4-5L15.5 3.5z"/><path d="M13.5 5.5l5 5"/></svg>',
  bell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M18 9a6 6 0 1 0-12 0c0 6-2.2 7.2-2.2 7.2h16.4S18 15 18 9z"/><path d="M10.3 20a2 2 0 0 0 3.4 0"/></svg>',
  shield: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2l8 3.4v6.8c0 4.9-3.4 8.4-8 9.8-4.6-1.4-8-4.9-8-9.8V5.4L12 2z"/><path d="M8.8 12l2.2 2.2 4.2-4.2"/></svg>',
  card: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="5" width="20" height="14" rx="2.5"/><path d="M2 10h20M6 15h4"/></svg>',
  download: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v11M7.5 10L12 14.5 16.5 10M4 20.5h16"/></svg>',
  globe: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.8 3.2 2.8 14.8 0 18M12 3c-2.8 3.2-2.8 14.8 0 18"/></svg>',
  store: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9.5L5.5 4h13L20 9.5M4 9.5a2.4 2.4 0 0 0 4.8 0 2.4 2.4 0 0 0 4.8 0 2.4 2.4 0 0 0 4.8 0M5.5 12.5V21h13v-8.5M9.5 21v-5h5v5"/></svg>',
  briefcase: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="7.5" width="18" height="13" rx="2"/><path d="M8.5 7.5V5.5a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v2M3 12.5h18"/></svg>',
  factory: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2.5 21V10.5L9 14v-3.5l6 3.5V4.5h6.5V21h-19z"/><path d="M6 17.5h2.5M12 17.5h2.5M17.5 17.5H20"/></svg>',
  truck: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M1.5 7h12.5v10H1.5zM14 10.5h4.5l3.5 3.5v3h-8"/><circle cx="6" cy="19.5" r="1.8"/><circle cx="17.5" cy="19.5" r="1.8"/></svg>',
  scale: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3.5v17M8 20.5h8M12 5.5l6.5 2.5M12 5.5L5.5 8"/><path d="M5.5 8l-2.5 5.5a2.8 2.8 0 0 0 5 0L5.5 8zM18.5 8L16 13.5a2.8 2.8 0 0 0 5 0L18.5 8z"/></svg>',
  // Logos de paiement
  momo: '<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/MoMo_Logo.png/320px-MoMo_Logo.png" alt="MoMo" style="height:32px;vertical-align:middle">',
  card: '<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Visa_Inc._logo.svg/320px-Visa_Inc._logo.svg.png" alt="Carte bancaire" style="height:32px;vertical-align:middle">',
};

// ============================================================
//  PAGE D'ACCUEIL — vitrine publique NEUTRE
//  🔒 Aucune info technique : pas d'endpoints, pas de stack.
//  Les API restent derrière requireApiKey (x-api-key).
// ============================================================
const LANDING_CSS = `
*{margin:0;padding:0;box-sizing:border-box}
html{scroll-behavior:smooth}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:linear-gradient(135deg,#0B0D17 0%,#1E2433 50%,#0B0D17 100%);min-height:100vh;color:#E2E8F0;padding:0}
.wrap{max-width:1060px;margin:0 auto;padding:0 1.4rem}
header{display:flex;align-items:center;justify-content:space-between;padding:1.2rem 0}
.brand{display:flex;align-items:center;gap:.7rem;font-weight:800;font-size:1rem}
.brand .bl{width:42px;height:42px;border-radius:11px;display:flex;align-items:center;justify-content:center;overflow:hidden;background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1)}
.brand .bl img{width:34px;height:34px;object-fit:contain;max-width:100%;max-height:100%}
.hero-logo{width:92px;height:92px;object-fit:contain;display:block;margin:0 auto 1.3rem;filter:drop-shadow(0 14px 28px rgba(124,58,237,.35));max-width:100%;max-height:100%}
.navcta{background:linear-gradient(135deg,#4338CA,#7C3AED);color:#fff;padding:.55rem 1.1rem;border-radius:10px;text-decoration:none;font-weight:700;font-size:.82rem;box-shadow:0 4px 12px rgba(124,58,237,.25);transition:all .2s;display:inline-flex;align-items:center;gap:.4rem}
.navcta svg{width:15px;height:15px}
.navcta:hover{transform:translateY(-2px)}
.hero{text-align:center;padding:3.2rem 0 2.2rem}
.tag{display:inline-block;background:rgba(52,211,153,.12);color:#34D399;padding:.3rem .8rem;border-radius:999px;font-size:.7rem;font-weight:700;letter-spacing:.05em;margin-bottom:1.1rem}
.hero h1{font-size:clamp(1.8rem,5vw,2.7rem);font-weight:800;line-height:1.18;margin-bottom:.9rem}
.hero h1 em{font-style:normal;background:linear-gradient(135deg,#818CF8,#C084FC);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}
.hero .lead{color:#94A3B8;font-size:1rem;line-height:1.65;max-width:620px;margin:0 auto 1.7rem}
.ctas{display:flex;gap:.8rem;justify-content:center;flex-wrap:wrap}
.btn{display:inline-flex;align-items:center;gap:.45rem;padding:.85rem 1.5rem;border-radius:12px;background:linear-gradient(135deg,#4338CA,#7C3AED);color:#fff;text-decoration:none;font-weight:700;font-size:.9rem;box-shadow:0 4px 14px rgba(124,58,237,.3);transition:all .2s}
.btn:hover{transform:translateY(-2px);box-shadow:0 10px 24px rgba(124,58,237,.45)}
.btn svg{width:16px;height:16px}
.btn.ghost{background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.14);box-shadow:none;color:#E2E8F0}
.btn.ghost:hover{background:rgba(255,255,255,.1);box-shadow:none}
.stats{display:flex;flex-wrap:wrap;justify-content:center;gap:.6rem;margin-top:2.2rem}
.stat{background:rgba(129,140,248,.1);border:1px solid rgba(129,140,248,.25);color:#C7D2FE;border-radius:999px;padding:.4rem .95rem;font-size:.74rem;font-weight:600}
section{padding:3rem 0 .8rem}
h2.st{font-size:clamp(1.3rem,3.4vw,1.7rem);font-weight:800;text-align:center;margin-bottom:.5rem}
p.sts{color:#94A3B8;text-align:center;font-size:.9rem;max-width:560px;margin:0 auto 1.8rem;line-height:1.6}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:.9rem}
.feat{background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.08);border-radius:16px;padding:1.15rem;transition:all .25s;text-align:left}
.feat:hover{transform:translateY(-4px);border-color:rgba(129,140,248,.35);background:rgba(255,255,255,.06)}
.feat .fi{width:44px;height:44px;background:linear-gradient(135deg,#4338CA,#7C3AED);border-radius:11px;display:flex;align-items:center;justify-content:center;margin-bottom:.8rem;color:#fff}
.feat .fi svg{width:22px;height:22px}
.feat .ft2{font-weight:800;font-size:.92rem;margin-bottom:.35rem}
.feat .fd{font-size:.8rem;color:#94A3B8;line-height:1.55}
.pay{display:grid;grid-template-columns:1.1fr 1fr;gap:1.2rem;align-items:center;background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.08);border-radius:20px;padding:1.6rem}
.pay h3{font-size:1.12rem;font-weight:800;margin-bottom:.6rem}
.pay p{color:#94A3B8;font-size:.85rem;line-height:1.6;margin-bottom:.9rem}
.chips{display:flex;flex-wrap:wrap;gap:.5rem}
.chip{background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.12);border-radius:999px;padding:.4rem .85rem;font-size:.75rem;font-weight:600}
.pay-logos{display:flex;gap:1.5rem;margin:1.5rem 0;flex-wrap:wrap;justify-content:center}
.pay-logo-item{position:relative;display:flex;flex-direction:column;align-items:center;justify-content:center;width:110px;height:110px;cursor:pointer}
.pay-logo-bg{position:absolute;width:100%;height:100%;display:flex;align-items:center;justify-content:center}
.pay-logo-bg img{max-width:60px;max-height:40px;object-fit:contain;z-index:2;position:relative}
.pay-logo-item span{font-size:.7rem;color:#94A3B8;font-weight:600;margin-top:.5rem;z-index:2}
.rose-petals{position:absolute;width:100%;height:100%;top:0;left:0;pointer-events:none}
.petal{position:absolute;width:50%;height:50%;background:linear-gradient(135deg,rgba(124,58,237,.9),rgba(67,56,202,.9));border-radius:0 50% 50% 50%;transform-origin:100% 100%;top:50%;left:50%;margin:-50% 0 0 -50%;opacity:0;transition:all .6s cubic-bezier(.4,0,.2,1);box-shadow:0 4px 15px rgba(124,58,237,.3)}
.petal:nth-child(1){transform:rotate(0deg)}
.petal:nth-child(2){transform:rotate(72deg)}
.petal:nth-child(3){transform:rotate(144deg)}
.petal:nth-child(4){transform:rotate(216deg)}
.petal:nth-child(5){transform:rotate(288deg)}
.pay-logo-item:hover .petal{opacity:1}
.pay-logo-item:hover .petal:nth-child(1){transform:rotate(0deg) translate(5px,-15px)}
.pay-logo-item:hover .petal:nth-child(2){transform:rotate(72deg) translate(15px,-5px)}
.pay-logo-item:hover .petal:nth-child(3){transform:rotate(144deg) translate(10px,10px)}
.pay-logo-item:hover .petal:nth-child(4){transform:rotate(216deg) translate(-10px,10px)}
.pay-logo-item:hover .petal:nth-child(5){transform:rotate(288deg) translate(-15px,-5px)}
.pay-logo-item:hover .pay-logo-bg img{transform:scale(1.1);transition:transform .3s ease}
@keyframes roseBloom{0%{opacity:0;transform:scale(.5) rotate(-10deg)}50%{opacity:1;transform:scale(1.1) rotate(5deg)}100%{opacity:1;transform:scale(1) rotate(0deg)}}
.pay-logo-item{animation:roseBloom .8s ease-out forwards}
.pay-logo-item:nth-child(1){animation-delay:.1s}
.pay-logo-item:nth-child(2){animation-delay:.2s}
.pay-logo-item:nth-child(3){animation-delay:.3s}
.paycard{background:linear-gradient(135deg,#4338CA,#7C3AED);border-radius:18px;padding:1.5rem;box-shadow:0 16px 36px rgba(124,58,237,.35);text-align:left}
.paycard .pc1{font-size:.7rem;letter-spacing:.08em;opacity:.85;font-weight:700}
.paycard .pc2{font-size:1.02rem;font-weight:800;margin:.5rem 0 .8rem}
.paycard .pcr{display:flex;justify-content:space-between;font-size:.79rem;padding:.45rem 0;border-top:1px solid rgba(255,255,255,.22)}
.who{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:.9rem}
.who .w{background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.08);border-radius:14px;padding:1.05rem;text-align:left}
.who .wi{width:40px;height:40px;background:rgba(129,140,248,.14);border-radius:10px;display:flex;align-items:center;justify-content:center;margin-bottom:.55rem;color:#818CF8}
.who .wi svg{width:20px;height:20px}
.who .wt{font-weight:800;font-size:.88rem;margin-bottom:.3rem}
.who .wd{font-size:.76rem;color:#94A3B8;line-height:1.5}
.sec{display:grid;grid-template-columns:1fr 1fr;gap:1rem}
.sec .sc{background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.08);border-radius:16px;padding:1.3rem;text-align:left}
.sec .sc h3{font-size:1rem;font-weight:800;margin-bottom:.8rem;display:flex;align-items:center;gap:.5rem;color:#E2E8F0}
.sec .sc h3 svg{width:20px;height:20px;color:#818CF8;flex:none}
.sec .sc ul{list-style:none}
.sec .sc li{font-size:.82rem;color:#94A3B8;padding:.32rem 0;line-height:1.5;display:flex;gap:.55rem}
.sec .sc li b{color:#34D399}
.cta{background:linear-gradient(135deg,#4338CA,#7C3AED);border-radius:22px;padding:2.4rem 1.6rem;text-align:center;box-shadow:0 18px 40px rgba(124,58,237,.35);margin-top:1rem}
.cta h2{font-size:clamp(1.25rem,3.4vw,1.6rem);font-weight:800;margin-bottom:.6rem}
.cta p{color:rgba(255,255,255,.85);font-size:.9rem;margin-bottom:1.4rem}
.cta .btn{background:#0B0D17;box-shadow:0 8px 20px rgba(0,0,0,.35)}
footer{padding:2.2rem 0 2.6rem;text-align:center;font-size:.78rem;color:#64748B}
footer .fl{display:flex;gap:1.2rem;justify-content:center;margin-bottom:.9rem;flex-wrap:wrap}
footer a{color:#818CF8;text-decoration:none}
@media (max-width:720px){.pay{grid-template-columns:1fr}.sec{grid-template-columns:1fr}header .navcta{padding:.45rem .8rem;font-size:.75rem}}
`;
const LANDING_TOP = `<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<link rel="icon" type="image/png" href="/favicon.png">
<title>Noi OHADA Invoice Pro — Facturation conforme OHADA</title>
<meta name="description" content="Factures et devis conformes SYSCOHADA révisé, stocks, équipes, paiements Mobile Money sécurisés. L'application de gestion commerciale des entrepreneurs OHADA.">
<style>${LANDING_CSS}</style></head><body><div class="wrap">
<header>
  <div class="brand"><span class="bl"><img src="/logo.png" alt="Noi OHADA Invoice Pro"></span> Noi OHADA Invoice Pro</div>
  <a class="navcta" href="/download">${ICON.download} Télécharger</a>
</header>

<section class="hero">
  <img class="hero-logo" src="/logo.png" alt="Logo Noi OHADA Invoice Pro">
  <span class="tag">✓ CONFORME SYSCOHADA RÉVISÉ</span>
  <h1>Gérez votre business avec des factures <em>conformes OHADA</em></h1>
  <p class="lead">Créez des factures et devis professionnels en quelques secondes,
  suivez vos stocks en temps réel, encaissez par Mobile Money et travaillez en
  équipe — en ligne comme hors connexion, en FCFA comme en multi-devises.</p>
  <div class="ctas">
    <a class="btn" href="/download">${ICON.download} Télécharger l'application</a>
    <a class="btn ghost" href="https://app.noi-ohada-invoice-pro.com" target="_blank" rel="noopener">${ICON.globe} Ouvrir la version web</a>
  </div>
  <div class="stats">
    <span class="stat">Factures conformes</span>
    <span class="stat">FCFA multi-devises</span>
    <span class="stat">hors-ligne</span>
    <span class="stat">Données chiffrées</span>
    <span class="stat">Relances auto</span>
  </div>
</section>

<section>
  <h2 class="st">Tout votre commerce dans une seule application</h2>
  <p class="sts">Des outils complets, pensés pour le terrain et les réalités
  des entreprises de l'espace OHADA.</p>
  <div class="grid">
    <div class="feat"><div class="fi">${ICON.receipt}</div><div class="ft2">Factures &amp; devis professionnels</div>
    <div class="fd">Factures conformes SYSCOHADA (TVA, IRC, remises, mentions légales),
    devis convertibles en un geste, PDF aux couleurs de votre entreprise.</div></div>
    <div class="feat"><div class="fi">${ICON.file}</div><div class="ft2">Clients &amp; historique</div>
    <div class="fd">Fiches clients complètes, historique d'achats, soldes et
    créances suivis automatiquement pour un recouvrement sans effort.</div></div>
    <div class="feat"><div class="fi">${ICON.box}</div><div class="ft2">Stocks &amp; livraisons</div>
    <div class="fd">Alertes de rupture et stock faible, suivi des livraisons et
    valorisation automatique de l'inventaire à chaque vente.</div></div>
    <div class="feat"><div class="fi">${ICON.chart}</div><div class="ft2">Tableau de bord</div>
    <div class="fd">Chiffre d'affaires, bénéfices, dettes clients et meilleures
    ventes — vos indicateurs clés mis à jour en temps réel.</div></div>
    <div class="feat"><div class="fi">${ICON.users}</div><div class="ft2">Travail en équipe</div>
    <div class="fd">Invitez vos collaborateurs par e-mail, partagez factures et
    clients, avec des rôles administrateur ou membre et des notifications.</div></div>
    <div class="feat"><div class="fi">${ICON.brush}</div><div class="ft2">Modèles personnalisés</div>
    <div class="fd">Boutique de modèles de factures : logo, couleurs et mise en
    page personnalisés pour une image professionnelle à chaque envoi.</div></div>
    <div class="feat"><div class="fi">${ICON.bell}</div><div class="ft2">Relances automatiques</div>
    <div class="fd">Rappels de paiement planifiés (1er rappel, 2e rappel, dernier
    avertissement) pour réduire vos impayés sans lever le petit doigt.</div></div>
    <div class="feat"><div class="fi">${ICON.shield}</div><div class="ft2">Sécurité avancée</div>
    <div class="fd">Authentification Firebase, vérification biométrique,
    verrouillage d'application et données chiffrées en transit et au repos.</div></div>
  </div>
</section>
`;

const LANDING_BOTTOM = `
<section>
  <h2 class="st">Encaissez par Mobile Money, en toute sécurité</h2>
  <p class="sts">Le proxy de paiement intégré E-nkap connecte votre application
  aux opérateurs de Mobile Money — sans manipulation, sans risque.</p>
  <div class="pay">
    <div>
      <h3>Paiements intégrés &amp; portefeuille</h3>
      <p>Vos clients règlent leurs factures ou vos abonnements par Mobile Money
      ou carte bancaire. La confirmation est instantanée : votre abonnement ou
      votre transaction est activé automatiquement, avec preuve de paiement.</p>
      <div class="pay-logos">
        <div class="pay-logo-item">
          <div class="rose-petals">
            <div class="petal"></div>
            <div class="petal"></div>
            <div class="petal"></div>
            <div class="petal"></div>
            <div class="petal"></div>
          </div>
          <div class="pay-logo-bg">${ICON.momo}</div>
          <span>MoMo</span>
        </div>
        <div class="pay-logo-item">
          <div class="rose-petals">
            <div class="petal"></div>
            <div class="petal"></div>
            <div class="petal"></div>
            <div class="petal"></div>
            <div class="petal"></div>
          </div>
          <div class="pay-logo-bg"><img src="https://upload.wikimedia.org/wikipedia/commons/thumb/4/4f/Orange_Money_logo.svg/320px-Orange_Money_logo.svg.png" alt="Orange Money" style="height:32px;vertical-align:middle"></div>
          <span>Orange Money</span>
        </div>
        <div class="pay-logo-item">
          <div class="rose-petals">
            <div class="petal"></div>
            <div class="petal"></div>
            <div class="petal"></div>
            <div class="petal"></div>
            <div class="petal"></div>
          </div>
          <div class="pay-logo-bg">${ICON.card}</div>
          <span>Carte bancaire</span>
        </div>
      </div>
      <div class="chips">
        <span class="chip">Orange Money</span>
        <span class="chip">MTN Mobile Money</span>
        <span class="chip">Carte bancaire</span>
        <span class="chip">Portefeuille intégré</span>
      </div>
    </div>
    <div class="paycard">
      <div class="pc1">PAIEMENT SÉCURISÉ E-NKAP</div>
      <div class="pc2">Confirmation instantanée 🔒</div>
      <div class="pcr"><span>Création de commande</span><span>✓ Immédiate</span></div>
      <div class="pcr"><span>Notification de paiement</span><span>✓ Temps réel</span></div>
      <div class="pcr"><span>Activation d'abonnement</span><span>✓ Automatique</span></div>
      <div class="pcr"><span>Reçu de paiement</span><span>✓ Conservé</span></div>
    </div>
  </div>
</section>

<section>
  <h2 class="st">Conçu pour les acteurs de l'espace OHADA</h2>
  <p class="sts">Quelle que soit votre activité, l'application s'adapte à
  votre façon de vendre et de facturer.</p>
  <div class="who">
    <div class="w"><div class="wi">${ICON.store}</div><div class="wt">Commerçants &amp; boutiques</div>
    <div class="wd">Ventes au comptant, gestion du stock et reçus instantanés.</div></div>
    <div class="w"><div class="wi">${ICON.briefcase}</div><div class="wt">Prestataires &amp; freelances</div>
    <div class="wd">Devis, factures d'honoraires et suivi des règlements clients.</div></div>
    <div class="w"><div class="wi">${ICON.factory}</div><div class="wt">PME &amp; grossistes</div>
    <div class="wd">Catalogue produits, prix de revient, marges et équipes de vente.</div></div>
    <div class="w"><div class="wi">${ICON.truck}</div><div class="wt">Distributeurs &amp; livreurs</div>
    <div class="wd">Bons de livraison liés aux factures et suivi des tournées.</div></div>
  </div>
</section>

<section>
  <div class="sec">
    <div class="sc">
      <h3>${ICON.shield} Sécurité &amp; confidentialité</h3>
      <ul>
        <li><b>✓</b> Authentification sécurisée (Firebase Auth, vérification e-mail)</li>
        <li><b>✓</b> Déverrouillage biométrique et code PIN de l'application</li>
        <li><b>✓</b> Données chiffrées en transit (TLS) et isolées par utilisateur</li>
        <li><b>✓</b> API verrouillées par clé — aucune manipulation externe</li>
        <li><b>✓</b> Sauvegarde et restauration Google Drive</li>
      </ul>
    </div>
    <div class="sc">
      <h3>${ICON.scale} Conformité OHADA</h3>
      <ul>
        <li><b>✓</b> Actes de commerce conformes au SYSCOHADA révisé</li>
        <li><b>✓</b> TVA (18% et taux spéciaux), IRC, remises et escomptes</li>
        <li><b>✓</b> Mentions obligatoires : NCC, RCCM, capital social…</li>
        <li><b>✓</b> Devise XAF/XOF et monnaies locales gérées</li>
        <li><b>✓</b> Numérotation et archivage conformes aux exigences</li>
      </ul>
    </div>
  </div>
</section>

<section>
  <div class="cta">
    <h2>Prêt à facturer comme un professionnel ?</h2>
    <p>Téléchargez Noi OHADA Invoice Pro et émettez votre première facture
    conforme en moins de deux minutes.</p>
    <a class="btn" href="/download">${ICON.download} Télécharger maintenant</a>
  </div>
</section>

<footer>
  <div class="fl">
    <a href="/download">Télécharger</a>
    <a href="https://app.noi-ohada-invoice-pro.com" target="_blank" rel="noopener">Version web</a>
    <a href="mailto:support@noi-ohada-invoice-pro.com">Support</a>
  </div>
  © ${new Date().getFullYear()} Noi OHADA Invoice Pro — Tous droits réservés.
</footer>
</div></body></html>`;

app.get('/', (req, res) => {
  res.status(200).type('html').send(LANDING_TOP + LANDING_BOTTOM);
});

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
