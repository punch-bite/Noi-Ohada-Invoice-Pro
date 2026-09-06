// ============================================================
//  NOI OHADA Invoice Pro — Page de telechargement securisee
//  Endpoint : GET /download | GET /api/builds
//  Auth Firebase (token Bearer) + Rate limiting + Storage
// ============================================================
require('dotenv').config();
const path = require('path');
const fs = require('fs');
const express = require('express');
const { initializeApp, getApps, getApp, cert } = require('firebase-admin/app');
const { getStorage } = require('firebase-admin/storage');
const logger = require('./logger');

const app = express();

function initFirebase() {
  if (getApps().length) return getApp();
  let credential;
  const saBase64 = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (saBase64 && saBase64.trim().length > 10) {
    const json = Buffer.from(saBase64, 'base64').toString('utf8');
    credential = cert(JSON.parse(json));
  } else {
    const saPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
      path.join(__dirname, '..', 'serviceAccountKey.json');
    if (fs.existsSync(saPath)) {
      credential = cert(require(saPath));
    } else {
      throw new Error('Cle Firebase introuvable (FIREBASE_SERVICE_ACCOUNT ou serviceAccountKey.json).');
    }
  }
  return initializeApp({ credential, storageBucket: process.env.FIREBASE_STORAGE_BUCKET }, 'download-app');
}

let firebaseApp;
try { firebaseApp = initFirebase(); }
catch (e) { logger.error('Firebase init echoue:', { error: e.message }); }

const rateLimit = new Map();
function checkRateLimit(ip, max = 30, windowMs = 60000) {
  const now = Date.now();
  const entry = rateLimit.get(ip);
  if (!entry || now - entry.start > windowMs) {
    rateLimit.set(ip, { start: now, count: 1 });
    return true;
  }
  if (entry.count >= max) return false;
  entry.count++;
  return true;
}

// ── Résolution du bucket Storage ─────────────────────────────────────────────
// 1) FIREBASE_STORAGE_BUCKET (variable Vercel — recommandé)
// 2) candidats usuels du projet `facture-ohada` (nouveau / ancien format),
//    testés une fois puis mis en cache.
let _resolvedBucket = null;

// Tente de lister les builds sur chaque bucket candidat et mémorise celui
// qui répond. Retourne le bucket opérationnel ou null.
async function resolveWorkingBucket() {
  if (_resolvedBucket) return getStorage(firebaseApp).bucket(_resolvedBucket);
  const candidates = [
    (process.env.FIREBASE_STORAGE_BUCKET || '').trim(),
    'facture-ohada.firebasestorage.app',
    'facture-ohada.appspot.com',
  ].filter(Boolean);
  const storage = getStorage(firebaseApp);
  for (const name of [...new Set(candidates)]) {
    const bucket = storage.bucket(name);
    try {
      await bucket.getFiles({ prefix: 'builds/', maxResults: 1 });
      _resolvedBucket = name;
      logger.info(`Bucket Storage resolu : ${name}`);
      return bucket;
    } catch (_) { /* candidat suivant */ }
  }
  return null;
}

async function getBuilds() {
  try {
    const bucket = await resolveWorkingBucket();
    if (!bucket) {
      logger.warn('Aucun bucket Storage exploitable (FIREBASE_STORAGE_BUCKET absent ?)');
      return { ios: null, android: null, web: null };
    }
    const [files] = await bucket.getFiles({ prefix: 'builds/' });
    const builds = { ios: null, android: null, web: null };
    for (const file of files) {
      const name = file.name.toLowerCase();
      const md = file.metadata || {};
      if (name.endsWith('.ipa') && !builds.ios) {
        builds.ios = { name: file.name.split('/').pop(), size: md.size || 0, updated: md.updated, url: null };
      } else if (name.endsWith('.apk') && !builds.android) {
        builds.android = { name: file.name.split('/').pop(), size: md.size || 0, updated: md.updated, url: null };
      } else if (name.includes('web') && name.endsWith('.zip') && !builds.web) {
        builds.web = { name: file.name.split('/').pop(), size: md.size || 0, updated: md.updated, url: null };
      }
    }
    // URLs signées (lecture directe, valables 7 jours) pour les builds trouvés.
    for (const key of ['ios', 'android', 'web']) {
      if (!builds[key]) continue;
      try {
        const file = bucket.file(`builds/${builds[key].name}`);
        const [url] = await file.getSignedUrl({
          action: 'read',
          expires: Date.now() + 7 * 24 * 3600 * 1000,
        });
        builds[key].url = url;
      } catch (e) {
        logger.warn(`URL signée impossible pour ${builds[key].name}:`, { error: e.message });
        // Fallback : mediaLink si le fichier est public, sinon le bouton reste désactivé.
        const [meta] = await bucket.file(`builds/${builds[key].name}`)
          .getMetadata().catch(() => [null]);
        builds[key].url = (meta && meta.mediaLink) || '#';
      }
    }
    return builds;
  } catch (e) {
    logger.warn('Impossible de recuperer les builds:', { error: e.message });
    return { ios: null, android: null, web: null };
  }
}

function formatSize(bytes) {
  if (!bytes || bytes === 0) return '—';
  const units = ['o', 'Ko', 'Mo', 'Go'];
  let i = 0; let size = bytes;
  while (size >= 1024 && i < units.length - 1) { size /= 1024; i++; }
  return `${size.toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
}

function renderDownloadPage(user, builds) {
  const iosUrl = builds.ios?.url || '#';
  const androidUrl = builds.android?.url || '#';
  const iosReady = !!builds.ios && iosUrl !== '#';
  const androidReady = !!builds.android && androidUrl !== '#';
  return `<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Noi OHADA — Telecharger</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
background:linear-gradient(135deg,#0B0D17 0%,#1E2433 50%,#0B0D17 100%);
min-height:100vh;color:#E2E8F0;display:flex;flex-direction:column;
align-items:center;justify-content:center;padding:2rem}
.container{max-width:820px;width:100%;text-align:center}
.logo{width:72px;height:72px;background:linear-gradient(135deg,#4338CA,#7C3AED);
border-radius:18px;display:flex;align-items:center;justify-content:center;
margin:0 auto 1.2rem;font-size:1.8rem;box-shadow:0 20px 40px rgba(124,58,237,.3)}
h1{font-size:1.6rem;font-weight:800;margin-bottom:.4rem;
background:linear-gradient(135deg,#818CF8,#C084FC);-webkit-background-clip:text;
-webkit-text-fill-color:transparent;background-clip:text}
.sub{color:#94A3B8;margin-bottom:1.5rem;font-size:.9rem}
.user{background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.1);
border-radius:12px;padding:.6rem 1rem;margin-bottom:1.5rem;font-size:.85rem;color:#94A3B8}
.user strong{color:#E2E8F0}
.hero{background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.08);
border-radius:20px;padding:1.6rem 1.4rem;margin-bottom:1rem;text-align:left}
.hero .tag{display:inline-block;background:rgba(52,211,153,.12);color:#34D399;
padding:.25rem .7rem;border-radius:999px;font-size:.7rem;font-weight:700;
letter-spacing:.04em;margin-bottom:.7rem}
.hero h2{font-size:1.15rem;font-weight:800;line-height:1.35;margin-bottom:.5rem}
.hero h2 em{font-style:normal;background:linear-gradient(135deg,#818CF8,#C084FC);
-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}
.hero p{color:#94A3B8;font-size:.85rem;line-height:1.55}
.features{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));
gap:.7rem;margin:1rem 0 1.2rem;text-align:left}
.feat{background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.08);
border-radius:14px;padding:.9rem}
.feat .fi{font-size:1.25rem;margin-bottom:.45rem}
.feat .ft2{font-weight:700;font-size:.85rem;margin-bottom:.25rem}
.feat .fd{font-size:.76rem;color:#94A3B8;line-height:1.45}
.stats{display:flex;flex-wrap:wrap;justify-content:center;gap:.6rem;margin-bottom:1.5rem}
.stat{background:rgba(129,140,248,.1);border:1px solid rgba(129,140,248,.25);
color:#C7D2FE;border-radius:999px;padding:.35rem .85rem;font-size:.72rem;font-weight:600}
.card{background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.1);
border-radius:16px;padding:1.2rem;margin-bottom:.8rem;display:flex;align-items:center;
justify-content:space-between;transition:all .2s}
.card:hover{background:rgba(255,255,255,.08);border-color:rgba(129,140,248,.3)}
.info{display:flex;align-items:center;gap:.8rem;text-align:left}
.icon{width:44px;height:44px;background:linear-gradient(135deg,#4338CA,#7C3AED);
border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:1.3rem}
.bld{font-weight:700;font-size:.95rem}
.meta{font-size:.78rem;color:#94A3B8;margin-top:2px}
.btn{background:linear-gradient(135deg,#4338CA,#7C3AED);color:#fff;border:none;
padding:.65rem 1.2rem;border-radius:10px;font-weight:600;font-size:.85rem;
cursor:pointer;text-decoration:none;display:inline-flex;align-items:center;gap:.4rem;
box-shadow:0 4px 12px rgba(124,58,237,.25);transition:all .2s}
.btn:hover{transform:translateY(-2px);box-shadow:0 8px 20px rgba(124,58,237,.4)}
.btn.dis{background:rgba(255,255,255,.1);color:#64748B;cursor:not-allowed;box-shadow:none}
.btn.dis:hover{transform:none}
.dlhead{margin:1.8rem 0 1rem;font-size:1.05rem;font-weight:800;text-align:left}
.dlhead small{display:block;font-weight:400;color:#94A3B8;font-size:.78rem;margin-top:.25rem}
.ft{margin-top:1.5rem;font-size:.78rem;color:#64748B}
.ft a{color:#818CF8;text-decoration:none}
.badge{display:inline-block;background:rgba(129,140,248,.15);color:#818CF8;
padding:.2rem .6rem;border-radius:999px;font-size:.65rem;font-weight:600;margin-left:.4rem}
</style></head><body><div class="container">
<div class="logo">📄</div>
<h1>Noi OHADA Invoice Pro</h1>
<p class="sub">Telechargez l'application sur votre appareil</p>
<div class="user">Connecte en tant que <strong>${user.email || user.uid}</strong></div>

<div class="hero">
  <span class="tag">✓ CONFORME SYSCOHADA RÉVISÉ</span>
  <h2>La facturation professionnelle <em>conforme OHADA</em>, dans votre poche.</h2>
  <p>Noi OHADA Invoice Pro est la solution de gestion commerciale conçue pour les
  entrepreneurs, PME et indépendants de l'espace OHADA : créez des factures et devis
  aux normes SYSCOHADA révisé, suivez vos stocks, encaissez via le paiement mobile
  et gardez vos données à l'abri dans le cloud — même hors connexion.</p>
</div>

<div class="features">
  <div class="feat"><div class="fi">🧾</div><div class="ft2">Factures &amp; devis</div>
  <div class="fd">Factures conformes (TVA, IRC, remises), devis convertibles
  et PDF professionnels aux couleurs de votre entreprise.</div></div>
  <div class="feat"><div class="fi">📦</div><div class="ft2">Stocks &amp; livraisons</div>
  <div class="fd">Alertes de rupture et stock faible, gestion des livraisons
  et valorisation automatique de l'inventaire.</div></div>
  <div class="feat"><div class="fi">👥</div><div class="ft2">Équipes</div>
  <div class="fd">Invitez vos collaborateurs par e-mail, partagez factures
  et clients, avec des rôles administrateur ou membre.</div></div>
  <div class="feat"><div class="fi">💳</div><div class="ft2">Paiements ENKAP</div>
  <div class="fd">Encaissez par Mobile Money (MTN, Orange…) via le proxy
  sécurisé ENKAP et suivez votre portefeuille intégré.</div></div>
  <div class="feat"><div class="fi">☁️</div><div class="ft2">Cloud &amp; hors-ligne</div>
  <div class="fd">Synchronisation Firestore temps réel, sauvegarde Google
  Drive, fonctionnement hors-ligne avec reprise automatique.</div></div>
  <div class="feat"><div class="fi">📊</div><div class="ft2">Tableau de bord</div>
  <div class="fd">Chiffre d'affaires, créances, top clients et relances de
  paiement automatiques — tout visible d'un coup d'œil.</div></div>
</div>

<div class="stats">
  <span class="stat">💱 FCFA multi-devises</span>
  <span class="stat">🔐 Données chiffrées</span>
  <span class="stat">📴 Mode hors-ligne</span>
  <span class="stat">🔔 Relances automatiques</span>
</div>

<div class="dlhead">📥 Téléchargements<small>Choisissez votre plateforme — l'application s'installe comme n'importe quelle application.</small></div>
<div class="card"><div class="info"><div class="icon">🍎</div><div>
<div class="bld">iOS <span class="badge">IPA</span></div>
<div class="meta">${builds.ios ? formatSize(builds.ios.size) + ' • iPhone/iPad' : 'Bientôt disponible'}</div>
</div></div><a href="${iosUrl}" ${iosReady ? 'download rel="noopener"' : ''} class="btn ${iosReady ? '' : 'dis'}">${iosReady ? '⬇ Telecharger' : '⏳ Indisponible'}</a></div>
<div class="card"><div class="info"><div class="icon">🤖</div><div>
<div class="bld">Android <span class="badge">APK</span></div>
<div class="meta">${builds.android ? formatSize(builds.android.size) + ' • Android 6+' : 'Bientôt disponible'}</div>
</div></div><a href="${androidUrl}" ${androidReady ? 'download rel="noopener"' : ''} class="btn ${androidReady ? '' : 'dis'}">${androidReady ? '⬇ Telecharger' : '⏳ Indisponible'}</a></div>
<div class="card"><div class="info"><div class="icon">🌐</div><div>
<div class="bld">Web <span class="badge">PWA</span></div>
<div class="meta">Accessible en ligne</div>
</div></div><a href="https://app.noi-ohada-invoice-pro.com" class="btn" target="_blank">🌍 Ouvrir</a></div>
<div class="ft"><p>Besoin d'aide ? <a href="mailto:support@noi-ohada-invoice-pro.com">Support</a></p>
<p style="margin-top:.4rem">© ${new Date().getFullYear()} Noi OHADA Invoice Pro</p></div>
</div></body></html>`;
}

app.get('/download', async (req, res) => {
  const ip = req.ip || req.connection.remoteAddress;
  if (!checkRateLimit(ip, 20, 60000)) return res.status(429).json({ error: 'Trop de tentatives' });
  const tokenFromQuery = req.query.token;
  const authHeader = req.headers.authorization;
  let user = null;
  if (tokenFromQuery && firebaseApp) {
    try { user = await firebaseApp.auth().verifyIdToken(tokenFromQuery); } catch (e) {}
  } else if (authHeader && authHeader.startsWith('Bearer ') && firebaseApp) {
    try { user = await firebaseApp.auth().verifyIdToken(authHeader.slice(7)); } catch (e) {}
  }
  if (!user && process.env.REQUIRE_AUTH === 'true') {
    return res.status(401).json({ error: 'Authentification requise' });
  }
  const builds = await getBuilds();
  const html = renderDownloadPage(user || { email: 'Visiteur', uid: 'anonymous' }, builds);
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.send(html);
});

app.get('/api/builds', async (req, res) => {
  const ip = req.ip || req.connection.remoteAddress;
  if (!checkRateLimit(ip, 30, 60000)) return res.status(429).json({ error: 'Trop de tentatives' });
  if (!firebaseApp) return res.status(503).json({ error: 'Service non disponible' });
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Token Bearer requis' });
  }
  try { await firebaseApp.auth().verifyIdToken(authHeader.slice(7)); }
  catch (e) { return res.status(401).json({ error: 'Token invalide' }); }
  const builds = await getBuilds();
  res.json({ ok: true, builds });
});

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'download', firebase: !!firebaseApp });
});

module.exports = app;
if (require.main === module) {
  const PORT = process.env.PORT || 3001;
  app.listen(PORT, () => logger.info(`📦 Serveur telechargement pret sur port ${PORT}`));
}