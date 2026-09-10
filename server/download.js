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
const { CSS: LANDING_CSS } = require('./landing');

// ── Icônes monochromes (SVG inline, style line-icons) ────────────────────────
// stroke=currentColor : héritent de la couleur du texte parent.
const ICONS = {
  download: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v11M7.5 10L12 14.5 16.5 10M4 20.5h16"/></svg>',
  clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7.5V12l3 2"/></svg>',
  globe: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.8 3.2 2.8 14.8 0 18M12 3c-2.8 3.2-2.8 14.8 0 18"/></svg>',
  apple: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20.94c1.5 0 2.75 1.06 4 1.06 3 0 6-8 6-12.22A4.91 4.91 0 0 0 17 5c-2.22 0-4 1.44-5 2-1-.56-2.78-2-5-2a4.9 4.9 0 0 0-5 4.78C2 14 5 22 8 22c1.25 0 2.5-1.06 4-1.06Z"/><path d="M10 2c1 .5 2 2 2 5"/></svg>',
  android: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 9.5a7 7 0 0 1 14 0v8a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 5 17.5v-8z"/><path d="M12 5.5V3M8 6L6.5 3.5M16 6l1.5-2.5"/><circle cx="9" cy="13.5" r=".5" fill="currentColor"/><circle cx="15" cy="13.5" r=".5" fill="currentColor"/></svg>',
  receipt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2h12v20l-2.5-1.8L13 22l-2.5-1.8L8 22l-2-1.5V2z"/><path d="M9 7.5h6M9 11.5h6M9 15.5h3.5"/></svg>',
  box: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8l9-5 9 5v8l-9 5-9-5V8z"/><path d="M3 8l9 5 9-5M12 13v8"/></svg>',
  users: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c0-3.5 2.9-5.5 6.5-5.5s6.5 2 6.5 5.5"/><circle cx="17.5" cy="9" r="2.5"/><path d="M16.5 14.6c2.7.4 5 2.1 5 4.9"/></svg>',
  card: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="5" width="20" height="14" rx="2.5"/><path d="M2 10h20M6 15h4"/></svg>',
  cloud: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z"/></svg>',
  chart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 21V11M12 21V4M19 21v-6M2.5 21h19"/></svg>',
};

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
  // Source 1 (préférée) : la dernière GitHub Release publique du dépôt.
  // Les assets sont hébergés sur le CDN de GitHub (public pour un dépôt public).
  const gh = await getGitHubBuilds();

  // Source 2 (fallback) : Firebase Storage (bucket `builds/`).
  const fb = await getFirebaseBuilds();

  // Priorité GitHub, au champ près.
  return {
    ios: gh.ios || fb.ios,
    android: gh.android || fb.android,
    web: gh.web || fb.web,
  };
}

const GH_REPO = process.env.GITHUB_REPO || 'punch-bite/Noi-Ohada-Invoice-Pro';
const GH_LATEST_URL = `https://api.github.com/repos/${GH_REPO}/releases/latest`;

// Récupère la dernière release publique et expose l'URL de téléchargement
// des assets (.apk, .aab — ici .apk). Aucun token requis (dépôt public).
// Cache en mémoire 5 min pour ne pas saturer le rate-limit GitHub (60 req/h).
let _ghCache = null;
let _ghCacheAt = 0;
const GH_CACHE_TTL = 5 * 60 * 1000;

async function getGitHubBuilds() {
  const out = { ios: null, android: null, web: null };
  if (_ghCache && Date.now() - _ghCacheAt < GH_CACHE_TTL) return _ghCache;
  try {
    const res = await fetch(GH_LATEST_URL, {
      headers: { 'Accept': 'application/vnd.github+json', 'User-Agent': 'noi-ohada-download' },
    });
    if (!res.ok) {
      logger.warn(`GitHub releases/latest HTTP ${res.status} — fallback Storage`);
      return out;
    }
    const release = await res.json();
    const assets = (release.assets || []).filter((a) => a.size > 0);
    const find = (ext) => {
      const a = assets.find((x) => x.name.toLowerCase().endsWith(ext));
      return a ? { name: a.name, size: a.size, updated: release.published_at, url: a.browser_download_url } : null;
    };
    out.android = find('.apk');
    out.ios = find('.ipa') || find('ios-release.zip');
    if (out.android || out.ios) {
      logger.info(`Release GitHub "${release.tag_name}": ` +
        (out.android ? 'APK ' + out.android.name : '') +
        (out.ios ? ' IPA/zip' : ''));
    }
    _ghCache = out;
    _ghCacheAt = Date.now();
  } catch (e) {
    logger.warn('Erreur lecture GitHub Release:', { error: e.message });
  }
  return out;
}

// (ancienne source) — lecture des builds depuis Firebase Storage.
async function getFirebaseBuilds() {
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
  const iosUrl = builds.ios && builds.ios.url && builds.ios.url !== '#' ? builds.ios.url : '#';
  const androidUrl = builds.android && builds.android.url && builds.android.url !== '#' ? builds.android.url : '#';
  const iosReady = iosUrl !== '#';
  const androidReady = androidUrl !== '#';
  const androidName = builds.android ? String(builds.android.name || '') : '';
  const androidMeta = builds.android
    ? (formatSize(Number(builds.android.size) || 0) + ' · APK')
    : 'Aucune version publiée';
  const webUrl = process.env.WEB_APP_URL || 'https://noi-ohada-web.vercel.app';
  const year = new Date().getFullYear();
  const extra = `
.dwrap{max-width:920px;margin:0 auto;padding:0 22px;position:relative;z-index:2}
.dhero{text-align:center;padding:52px 0 16px}
.dgrid{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin:38px auto 0}
.dcard{background:var(--panel);border:1px solid var(--line);border-radius:var(--r);padding:26px 24px;display:flex;flex-direction:column;gap:15px;align-items:flex-start;transition:.25s}
.dcard:hover{transform:translateY(-3px);background:var(--panel2);border-color:rgba(255,255,255,.14)}
.dcard .di{width:46px;height:46px;border-radius:13px;display:grid;place-items:center;background:rgba(139,124,255,.10);border:1px solid rgba(139,124,255,.16);color:var(--acc2)}
.dcard .di svg{width:23px;height:23px}
.dcard h3{font-weight:600;font-size:16px;letter-spacing:-.01em}
.dcard .dsub{color:var(--mut);font-size:13px;line-height:1.6;min-height:44px}
.dcard .meta{display:inline-flex;align-items:center;gap:7px;color:var(--faint);font-size:12px}
.dcard .meta svg{width:14px;height:14px;color:var(--gold)}
.dcard .btn{width:100%;justify-content:center}
a.btn.dis{opacity:.5;pointer-events:none}
.dtrust{display:flex;flex-wrap:wrap;justify-content:center;gap:26px;margin-top:40px;color:var(--faint);font-size:12.5px}
.dtrust span{display:inline-flex;align-items:center;gap:7px}
.dtrust svg{width:15px;height:15px;color:var(--gold)}
@media(max-width:760px){.dgrid{grid-template-columns:1fr}}
`;
  return `<!DOCTYPE html>
<html lang="fr"><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<meta name="robots" content="noindex, nofollow">
<link rel="icon" type="image/png" href="/favicon.png">
<title>Noi OHADA — Téléchargement</title>
<style>${LANDING_CSS}${extra}</style>
</head><body>
<div class="bg"><div class="halo h1"></div><div class="halo h2"></div><div class="halo h3"></div></div>
<div class="aura" aria-hidden="true"></div>

<div class="dwrap">
  <header>
    <a class="brand" href="/"><span class="logo"><img src="/logo.png" alt="Noi OHADA Invoice Pro"></span>Noi OHADA</a>
    <nav class="hnav">
      <a class="btn small ghost" href="/">← Accueil</a>
    </nav>
  </header>

  <section class="dhero">
    <span class="eyebrow"><span class="dot"></span> Téléchargement</span>
    <h1 class="st" style="font-size:clamp(1.7rem,4vw,2.4rem)">Obtenez <span style="background:linear-gradient(100deg,#c3b6ff,#8b7cff 60%,#e6c886 130%);-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent">Noi OHADA</span></h1>
    <p class="sts">Installez l'application sur votre téléphone ou utilisez la version web — sans Play Store requis.</p>
  </section>

  <div class="dgrid">
    <div class="dcard">
      <span class="di">${ICONS.android}</span>
      <h3>Android</h3>
      <p class="dsub">${androidReady ? 'Dernière version prête à installer. Autorisez simplement l\'installation depuis des sources inconnues.' : 'La version Android sera disponible ici dès sa publication.'}</p>
      <span class="meta">${ICONS.check ? ICONS.check : ''}${androidMeta}</span>
      ${androidReady
        ? `<a class="btn primary" href="${androidUrl}" download>${ICONS.download} Télécharger l'APK</a>`
        : `<a class="btn primary dis" aria-disabled="true">${ICONS.clock} Indisponible</a>`}
    </div>
    <div class="dcard">
      <span class="di">${ICONS.apple}</span>
      <h3>iPhone</h3>
      <p class="dsub">${iosReady ? 'Dernière version prête à installer sur votre iPhone.' : 'La version iPhone arrive bientôt.'}</p>
      <span class="meta">${ICONS.check ? ICONS.check : ''}${builds.ios ? formatSize(Number(builds.ios.size) || 0) + ' · IPA' : 'Bientôt disponible'}</span>
      ${iosReady
        ? `<a class="btn primary" href="${iosUrl}" download>${ICONS.download} Télécharger l'IPA</a>`
        : `<a class="btn primary dis" aria-disabled="true">${ICONS.clock} Bientôt</a>`}
    </div>
    <div class="dcard">
      <span class="di">${ICONS.globe}</span>
      <h3>Version web</h3>
      <p class="dsub">Accessible depuis n'importe quel navigateur, aucune installation. Vos données restent synchronisées.</p>
      <span class="meta">${ICONS.check ? ICONS.check : ''}PWA · En ligne</span>
      <a class="btn ghost" href="${webUrl}" target="_blank" rel="noopener">${ICONS.globe} Ouvrir la version web</a>
    </div>
  </div>

  <div class="dtrust">
    <span>${ICONS.check ? ICONS.check : ''} Fichier signé</span>
    <span>${ICONS.check ? ICONS.check : ''} Mises à jour faciles</span>
    <span>${ICONS.check ? ICONS.check : ''} Support réactif</span>
  </div>

  <footer style="margin-top:52px">
    <div class="flinks">
      <a href="/">Accueil</a>
      <a href="${webUrl}" target="_blank" rel="noopener">Version web</a>
      <a href="mailto:support@noi-ohada-invoice-pro.com">Support</a>
    </div>
    <div class="fcopy">© ${year} Noi OHADA Invoice Pro — Tous droits réservés.</div>
  </footer>
</div>

<script>
(function () {
  var r = document.documentElement;
  function track(e) {
    r.style.setProperty('--mx', (e.clientX || window.innerWidth / 2) + 'px');
    r.style.setProperty('--my', (e.clientY || window.innerHeight / 2) + 'px');
  }
  window.addEventListener('pointermove', track, { passive: true });
  track({ clientX: window.innerWidth * 0.5, clientY: window.innerHeight * 0.34 });
})();
</script>
</body></html>`;
}

function renderDownloadPageLegacy(user, builds) {
  const iosUrl = builds.ios?.url || '#';
  const androidUrl = builds.android?.url || '#';
  const iosReady = !!builds.ios && iosUrl !== '#';
  const androidReady = !!builds.android && androidUrl !== '#';
  return `<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<link rel="icon" type="image/png" href="/favicon.png"><title>Noi OHADA — Telecharger</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
background:linear-gradient(135deg,#0B0D17 0%,#1E2433 50%,#0B0D17 100%);
min-height:100vh;color:#E2E8F0;display:flex;flex-direction:column;
align-items:center;justify-content:center;padding:2rem}
.container{max-width:820px;width:100%;text-align:center}
.logo{width:72px;height:72px;background:linear-gradient(135deg,#4338CA,#7C3AED);
border-radius:18px;display:flex;align-items:center;justify-content:center;
margin:0 auto 1.2rem;font-size:1.8rem;box-shadow:0 20px 40px rgba(124,58,237,.3);
overflow:hidden;padding:0}
.logo img{width:100%;height:100%;object-fit:cover;border-radius:18px;display:block}
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
.feat .fi{width:40px;height:40px;background:linear-gradient(135deg,#4338CA,#7C3AED);border-radius:10px;display:flex;align-items:center;justify-content:center;margin-bottom:.45rem;color:#fff}
.feat .fi svg{width:22px;height:22px}
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
.btn svg{width:14px;height:14px;flex:none}
.dlhead{margin:1.8rem 0 1rem;font-size:1.05rem;font-weight:800;text-align:left}
.dlhead small{display:block;font-weight:400;color:#94A3B8;font-size:.78rem;margin-top:.25rem}
.ft{margin-top:1.5rem;font-size:.78rem;color:#64748B}
.ft a{color:#818CF8;text-decoration:none}
.badge{display:inline-block;background:rgba(129,140,248,.15);color:#818CF8;
padding:.2rem .6rem;border-radius:999px;font-size:.65rem;font-weight:600;margin-left:.4rem}
</style></head><body><div class="container">
<div class="logo"><img src="/logo.png" alt="Noi OHADA Invoice Pro"></div>
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
  <div class="feat"><div class="fi">${ICONS.receipt}</div><div class="ft2">Factures &amp; devis</div>
  <div class="fd">Factures conformes (TVA, IRC, remises), devis convertibles
  et PDF professionnels aux couleurs de votre entreprise.</div></div>
  <div class="feat"><div class="fi">${ICONS.box}</div><div class="ft2">Stocks &amp; livraisons</div>
  <div class="fd">Alertes de rupture et stock faible, gestion des livraisons
  et valorisation automatique de l'inventaire.</div></div>
  <div class="feat"><div class="fi">${ICONS.users}</div><div class="ft2">Équipes</div>
  <div class="fd">Invitez vos collaborateurs par e-mail, partagez factures
  et clients, avec des rôles administrateur ou membre.</div></div>
  <div class="feat"><div class="fi">${ICONS.card}</div><div class="ft2">Paiements ENKAP</div>
  <div class="fd">Encaissez par Mobile Money (MTN, Orange…) via le proxy
  sécurisé ENKAP et suivez votre portefeuille intégré.</div></div>
  <div class="feat"><div class="fi">${ICONS.cloud}</div><div class="ft2">Cloud &amp; hors-ligne</div>
  <div class="fd">Synchronisation Firestore temps réel, sauvegarde Google
  Drive, fonctionnement hors-ligne avec reprise automatique.</div></div>
  <div class="feat"><div class="fi">${ICONS.chart}</div><div class="ft2">Tableau de bord</div>
  <div class="fd">Chiffre d'affaires, créances, top clients et relances de
  paiement automatiques — tout visible d'un coup d'œil.</div></div>
</div>

<div class="stats">
  <span class="stat">FCFA multi-devises</span>
  <span class="stat">Données chiffrées</span>
  <span class="stat">Mode hors-ligne</span>
  <span class="stat">Relances automatiques</span>
</div>

<div class="dlhead">Téléchargements<small>Choisissez votre plateforme — l'application s'installe comme n'importe quelle application.</small></div>
<div class="card"><div class="info"><div class="icon">${ICONS.apple}</div><div>
<div class="bld">iOS <span class="badge">IPA</span></div>
<div class="meta">${builds.ios ? formatSize(builds.ios.size) + ' • iPhone/iPad' : 'Bientôt disponible'}</div>
</div></div><a href="${iosUrl}" ${iosReady ? 'download rel="noopener"' : ''} class="btn ${iosReady ? '' : 'dis'}">${iosReady ? ICONS.download + ' Telecharger' : ICONS.clock + ' Indisponible'}</a></div>
<div class="card"><div class="info"><div class="icon">${ICONS.android}</div><div>
<div class="bld">Android <span class="badge">APK</span></div>
<div class="meta">${builds.android ? formatSize(builds.android.size) + ' • Android 6+' : 'Bientôt disponible'}</div>
</div></div><a href="${androidUrl}" ${androidReady ? 'download rel="noopener"' : ''} class="btn ${androidReady ? '' : 'dis'}">${androidReady ? ICONS.download + ' Telecharger' : ICONS.clock + ' Indisponible'}</a></div>
<div class="card"><div class="info"><div class="icon">${ICONS.globe}</div><div>
<div class="bld">Web <span class="badge">PWA</span></div>
<div class="meta">Accessible en ligne</div>
</div></div><a href="${process.env.WEB_APP_URL || 'https://noi-ohada-web.vercel.app'}" class="btn" target="_blank">${ICONS.globe} Ouvrir</a></div>
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

/// 🎯 LIEN DIRECT STABLE vers le dernier APK Android — idéal à partager
/// (WhatsApp, e-mail, QR…) et à utiliser comme APP_UPDATE_URL. PUBLIC :
/// redirige (302) vers l'URL actuelle du build Android (URL signée régénérée
/// à chaque requête → le lien ne « périme » jamais).
app.get('/app/latest.apk', async (req, res) => {
  const ip = req.ip || req.connection.remoteAddress;
  if (!checkRateLimit(ip, 40, 60000)) return res.status(429).json({ error: 'Trop de tentatives' });
  if (!firebaseApp) return res.status(503).json({ error: 'Service non disponible' });
  const builds = await getBuilds();
  if (!builds.android || !builds.android.url || builds.android.url === '#') {
    return res.status(404).json({ error: 'Aucune version Android publiée pour le moment.' });
  }
  res.redirect(302, builds.android.url);
});

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'download', firebase: !!firebaseApp });
});

module.exports = app;
if (require.main === module) {
  const PORT = process.env.PORT || 3001;
  app.listen(PORT, () => logger.info(`📦 Serveur telechargement pret sur port ${PORT}`));
}