// scripts/upload_apk_storage.js
//
// 📦 Envoie un build (APK/AAB/IPA/ZIP) vers Firebase Storage, dossier `builds/`,
// pour qu'il apparaisse sur la page de téléchargement servie par Vercel
// (GET https://<serveur>.vercel.app/download — cf. server/download.js).
//
// Usage :
//   node scripts/upload_apk_storage.js "build/app/outputs/flutter-apk/app-release.apk"
//   node scripts/upload_apk_storage.js "mon.apk" --name=noi-ohada-1.0.apk --public
//
// Options :
//   --name=<fichier.apk>  nom de destination dans `builds/` (défaut : nom local)
//   --bucket=<nom>        bucket Storage explicite (défaut : auto-détection)
//   --public              rend le fichier public et affiche son URL permanente
//
// Pré-requis : `serviceAccountKey.json` à la racine (ou FIREBASE_SERVICE_ACCOUNT
// en base64) et le paquet `firebase-admin` installé (déjà présent).

const fs = require('fs');
const path = require('path');

// ── Arguments ────────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const filePath = args.find((a) => !a.startsWith('--'));
const opts = Object.fromEntries(
  args.filter((a) => a.startsWith('--')).map((a) => {
    const [k, ...v] = a.slice(2).split('=');
    return [k, v.join('=') === '' ? true : v.join('=')];
  }),
);
const defaultApk = path.join(
  __dirname, '..', 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk',
);
const source = filePath || defaultApk;

if (!fs.existsSync(source)) {
  console.error(`❌ Fichier introuvable : ${source}`);
  console.error('   Construisez d\'abord l\'APK : flutter build apk --release');
  process.exit(1);
}

// ── Clé de service (racine du projet) ────────────────────────────────────────
let serviceAccount;
const b64 = process.env.FIREBASE_SERVICE_ACCOUNT;
if (b64 && b64.trim().length > 10) {
  serviceAccount = JSON.parse(Buffer.from(b64, 'base64').toString('utf8'));
} else {
  const keyPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  if (!fs.existsSync(keyPath)) {
    console.error(`❌ Clé de service introuvable : ${keyPath}`);
    process.exit(1);
  }
  serviceAccount = require(keyPath);
}

const { initializeApp, cert } = require('firebase-admin/app');
const { getStorage } = require('firebase-admin/storage');

const app = initializeApp({
  credential: cert(serviceAccount),
  storageBucket: opts.bucket || undefined,
});

const BUCKET_CANDIDATES = [
  opts.bucket,
  serviceAccount.project_id && `${serviceAccount.project_id}.firebasestorage.app`,
  serviceAccount.project_id && `${serviceAccount.project_id}.appspot.com`,
].filter(Boolean);

async function resolveBucket() {
  const storage = getStorage(app);
  for (const name of [...new Set(BUCKET_CANDIDATES)]) {
    const bucket = storage.bucket(name);
    try {
      await bucket.getFiles({ maxResults: 1 });
      return bucket;
    } catch (e) {
      console.log(`   … bucket ${name} indisponible (${e.message.slice(0, 60)})`);
    }
  }
  return null;
}

(async () => {
  const bucket = await resolveBucket();
  if (!bucket) {
    console.error('❌ Aucun bucket Storage accessible.');
    console.error('   → Vérifiez que Firebase Storage est activé pour le projet');
    console.error(`     « ${serviceAccount.project_id} » (console.firebase.google.com).`);
    process.exit(1);
  }
  console.log(`✅ Bucket : ${bucket.name}`);

  const destName = opts.name || path.basename(source);
  const dest = `builds/${destName}`;
  const size = fs.statSync(source).size;

  process.stdout.write(`⏳ Upload de ${path.basename(source)} (${(size / 1048576).toFixed(1)} Mo) → ${dest} …\n`);
  await bucket.upload(path.resolve(source), {
    destination: dest,
    metadata: { contentType: 'application/vnd.android.package-archive' },
  });

  const file = bucket.file(dest);
  if (opts.public) {
    await file.makePublic();
    const publicUrl =
      `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
      `${encodeURIComponent(dest)}?alt=media`;
    console.log(`🌐 URL publique (permanente) :\n   ${publicUrl}`);
  } else {
    const [signedUrl] = await file.getSignedUrl({
      action: 'read',
      expires: Date.now() + 7 * 24 * 3600 * 1000,
    });
    console.log(`🔗 URL signée (7 jours) :\n   ${signedUrl}`);
  }

  console.log('');
  console.log('🎉 Terminé ! Le fichier apparaît maintenant sur :');
  console.log('   https://server-xi-two-23.vercel.app/download');
  console.log('   (redéployez le serveur si la page était ouverte : npm run deploy)');
})().catch((e) => {
  console.error(`❌ Échec de l'upload : ${e.message}`);
  process.exit(1);
});