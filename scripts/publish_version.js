#!/usr/bin/env node
// ============================================================
//  scripts/publish_version.js
//
//  🚀 PUBLIE UNE NOUVELLE VERSION DE L'APPLICATION EN UNE COMMANDE
//
//  Met à jour les variables d'environnement du projet Vercel « server »
//  qui pilotent l'option « Mise à jour » de l'app (GET /app/version) :
//    APP_LATEST_VERSION  → déclenche la proposition de mise à jour
//    APP_UPDATE_URL      → lien STABLE de téléchargement de l'APK (optionnel)
//    APP_UPDATE_NOTES    → notes de version (optionnel)
//    APP_UPDATE_AT       → date de publication (automatique)
//  puis REDÉPLOIE le serveur (les variables ne s'appliquent qu'au
//  redéploiement).
//
//  Prérequis :
//    - être connecté à Vercel (`vercel login`) OU avoir VERCEL_TOKEN
//    - l'APK doit déjà être buildé (CodeMagic) et uploadé (voir
//      scripts/upload_apk_storage.js) — ce script ne build PAS l'APK.
//
//  Usage :
//    node scripts/publish_version.js --version 1.0.1
//    node scripts/publish_version.js --version 1.0.1 ^
//         --url "https://.../noi-ohada-1.0.1.apk" ^
//         --notes "Corrections et améliorations" --no-deploy
//
//  Options :
//    --version V    Nouvelle version (obligatoire, ex. "1.0.1")
//    --url U        Lien stable de téléchargement (défaut : inchangé)
//    --notes N      Notes de version (défaut : inchangé)
//    --no-deploy    Ne pas redéployer après la mise à jour des variables
//    --env X        Cibles : production | preview | all (défaut: all)
// ============================================================
const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SERVER_DIR = path.join(ROOT, 'server');
const PROJECT_FILE = path.join(SERVER_DIR, '.vercel', 'project.json');
const API = 'https://api.vercel.com';

// ---------- Arguments ----------
const argv = process.argv.slice(2);
function argVal(name, def) {
  const i = argv.indexOf(name);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : def;
}
const version = (argVal('--version') || '').trim();
const downloadUrl = (argVal('--url') || '').trim();
const notes = (argVal('--notes') || '').trim();
const doDeploy = !argv.includes('--no-deploy');
const envChoice = (argVal('--env') || 'all').trim().toLowerCase();

function targets() {
  if (envChoice === 'production') return ['production'];
  if (envChoice === 'preview') return ['preview'];
  return ['production', 'preview'];
}

if (!version) {
  console.error(
    '❌ Usage : node scripts/publish_version.js --version 1.0.1 [--url <lien>] [--notes \"...\"] [--no-deploy]'
  );
  process.exit(1);
}

// ---------- Connexion Vercel ----------
function getToken() {
  if (process.env.VERCEL_TOKEN) return process.env.VERCEL_TOKEN.trim();
  // Emplacements du fichier auth de la CLI Vercel (Windows / mac / Linux).
  const candidates = [
    path.join(os.homedir(), '.vercel', 'auth.json'),
    path.join(
      process.env.APPDATA || path.join(os.homedir(), '.config'),
      'xdg.data',
      'com.vercel.cli',
      'auth.json'
    ),
    path.join(os.homedir(), '.config', 'com.vercel.cli', 'auth.json'),
    path.join(os.homedir(), '.local', 'share', 'com.vercel.cli', 'auth.json'),
  ];
  for (const file of candidates) {
    try {
      const auth = JSON.parse(fs.readFileSync(file, 'utf8'));
      if (auth && auth.token) return auth.token;
    } catch (_) {
      /* fichier absent ou illisible → candidat suivant */
    }
  }
  return null;
}

function loadProject() {
  const raw = fs.readFileSync(PROJECT_FILE, 'utf8');
  const p = JSON.parse(raw);
  return { projectId: p.projectId, teamId: p.orgId, name: p.projectName || 'server' };
}

const TOKEN = getToken();
if (!TOKEN) {
  console.error('❌ Non connecté à Vercel. Lancez `vercel login` ou définissez VERCEL_TOKEN.');
  process.exit(1);
}

let PROJECT;
try {
  PROJECT = loadProject();
} catch (e) {
  console.error('❌ Impossible de lire la liaison Vercel :', PROJECT_FILE, '\n', e.message);
  process.exit(1);
}

async function api(method, urlPath, body) {
  const res = await fetch(`${API}${urlPath}`, {
    method,
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch (_) { /* non JSON */ }
  if (!res.ok) {
    const msg = (data && (data.error && data.error.message)) || data && data.message || text;
    throw new Error(`API Vercel ${res.status} — ${msg || res.statusText}`);
  }
  return data;
}

// ---------- Upsert d'une variable ----------
async function upsertEnv(key, value, targetsList) {
  const team = `teamId=${encodeURIComponent(PROJECT.teamId)}`;
  // 1) liste
  const list = await api('GET', `/v9/projects/${PROJECT.projectId}/env?${team}`);
  const existing = (list.env || []).filter(
    (e) => e.key === key && (e.target || []).some((t) => targetsList.includes(t))
  );
  // 2) suppression des anciennes valeurs sur les mêmes cibles
  for (const e of existing) {
    await api('DELETE', `/v9/projects/${PROJECT.projectId}/env/${e.id}?${team}`);
    console.log(`  ↺ supprimé ${key} (${(e.target || []).join(',')})`);
  }
  // 3) création
  const created = await api('POST', `/v10/projects/${PROJECT.projectId}/env?${team}`, {
    key,
    value,
    type: 'encrypted',
    target: targetsList,
    comment: `publish_version.js — ${new Date().toISOString()}`,
  });
  const ok = created && (created.id || created.key);
  console.log(`  ✅ ${key} = ${value} → [${targetsList.join(', ')}]${ok ? '' : ' (à vérifier)'}`);
}

// ---------- Main ----------
(async () => {
  console.log('🚀 Publication d\'une version…');
  console.log(`   version   : ${version}`);
  console.log(`   download  : ${downloadUrl || '(inchangé)'}`);
  console.log(`   notes     : ${notes || '(inchangé)'}`);
  console.log(`   cibles    : ${targets().join(', ')}`);
  console.log(`   projet    : ${PROJECT.name} (${PROJECT.projectId})`);
  console.log('');

  const varsToSet = [
    { key: 'APP_LATEST_VERSION', value: version, required: true },
  ];
  if (downloadUrl) varsToSet.push({ key: 'APP_UPDATE_URL', value: downloadUrl });
  if (notes) varsToSet.push({ key: 'APP_UPDATE_NOTES', value: notes });
  varsToSet.push({
    key: 'APP_UPDATE_AT',
    value: new Date().toISOString(),
  });

  for (const v of varsToSet) {
    try {
      await upsertEnv(v.key, v.value, targets());
    } catch (e) {
      console.error(`❌ ${v.key} : ${e.message}`);
      process.exit(1);
    }
  }

  console.log('\n✔ Variables mises à jour.');

  // ---------- Redéploiement ----------
  if (doDeploy) {
    console.log('\n⏳ Redéploiement du serveur…');
    const r = spawnSync('vercel', ['--cwd', SERVER_DIR, '--prod', '--yes'], {
      stdio: 'inherit',
      shell: process.platform === 'win32',
    });
    if (r.status !== 0) {
      console.error('❌ Redéploiement échoué (vercel --cwd server --prod --yes).');
      process.exit(1);
    }
  } else {
    console.log('\n⏭ Redéploiement ignoré (--no-deploy). Pensez à lancer :');
    console.log('   vercel --cwd server --prod --yes');
  }

  // Vérification finale
  try {
    const res = await fetch('https://server-xi-two-23.vercel.app/app/version');
    const body = await res.json();
    console.log('\n🔎 Vérification GET /app/version :');
    console.log('   ' + JSON.stringify(body));
  } catch (_) {
    console.log('\n⚠️ Vérification impossible (le déploiement met ~20 s).');
  }
})();
