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

async function getBuilds() {
  try {
    const bucket = getStorage().bucket();
    const [files] = await bucket.getFiles({ prefix: 'builds/' });
    const builds = { ios: null, android: null, web: null };
    for (const file of files) {
      const name = file.name.toLowerCase();
      const md = file.metadata || {};
      if (name.endsWith('.ipa') && !builds.ios) {
        builds.ios = { name: file.name.split('/').pop(), size: md.size || 0 };
      } else if (name.endsWith('.apk') && !builds.android) {
        builds.android = { name: file.name.split('/').pop(), size: md.size || 0 };
      } else if (name.includes('web') && name.endsWith('.zip') && !builds.web) {
        builds.web = { name: file.name.split('/').pop(), size: md.size || 0 };
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
  const iosUrl = '#';
  const androidUrl = '#';
  return `<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Noi OHADA — Telecharger</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
background:linear-gradient(135deg,#0B0D17 0%,#1E2433 50%,#0B0D17 100%);
min-height:100vh;color:#E2E8F0;display:flex;flex-direction:column;
align-items:center;justify-content:center;padding:2rem}
.container{max-width:560px;width:100%;text-align:center}
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
.ft{margin-top:1.5rem;font-size:.78rem;color:#64748B}
.ft a{color:#818CF8;text-decoration:none}
.badge{display:inline-block;background:rgba(129,140,248,.15);color:#818CF8;
padding:.2rem .6rem;border-radius:999px;font-size:.65rem;font-weight:600;margin-left:.4rem}
</style></head><body><div class="container">
<div class="logo">📄</div>
<h1>Noi OHADA Invoice Pro</h1>
<p class="sub">Telechargez l'application sur votre appareil</p>
<div class="user">Connecte en tant que <strong>${user.email || user.uid}</strong></div>
<div class="card"><div class="info"><div class="icon">🍎</div><div>
<div class="bld">iOS <span class="badge">IPA</span></div>
<div class="meta">${builds.ios ? formatSize(builds.ios.size) + ' • iPhone/iPad' : 'Bientot disponible'}</div>
</div></div><a href="${iosUrl}" class="btn ${builds.ios ? '' : 'dis'}">${builds.ios ? '⬇ Telecharger' : '⏳ Indisponible'}</a></div>
<div class="card"><div class="info"><div class="icon">🤖</div><div>
<div class="bld">Android <span class="badge">APK</span></div>
<div class="meta">${builds.android ? formatSize(builds.android.size) + ' • Android 6+' : 'Bientot disponible'}</div>
</div></div><a href="${androidUrl}" class="btn ${builds.android ? '' : 'dis'}">${builds.android ? '⬇ Telecharger' : '⏳ Indisponible'}</a></div>
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