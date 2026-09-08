// scripts/update_plans_drive_free.js
//
// 🆓 Met à jour la collection Firestore « plans » pour refléter la décision :
//    la « Sauvegarde Google Drive » est désormais GRATUITE pour tous.
//
// Effet (sur free / pro / business uniquement — les autres champs/plans ne
// sont pas touchés) :
//   - hasGoogleDriveSync → true
//   - les anciennes mentions Drive (« Synchronisation Google Drive »,
//     « Google Drive ») sont remplacées par « Sauvegarde Google Drive »,
//     ajoutée si absente.
//
// Usage :
//   node scripts/update_plans_drive_free.js
//
const { initializeApp, getApps, cert } = require('firebase-admin');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', 'serviceAccountKey.json'));
if (!getApps().length) {
  initializeApp({ credential: cert(serviceAccount) });
}
const db = getFirestore();

const DRIVE = 'Sauvegarde Google Drive';
const LEGACY = ['Synchronisation Google Drive', 'Google Drive'];

/** Nettoie la liste et garantit « Sauvegarde Google Drive » présente une fois. */
function withDrive(features) {
  const out = [];
  for (const f of features || []) {
    const t = String(f).trim();
    if (!t) continue;
    if (LEGACY.includes(t) || t === DRIVE) continue;
    if (!out.includes(t)) out.push(t);
  }
  out.push(DRIVE);
  return out;
}

async function updatePlan(id) {
  const ref = db.collection('plans').doc(id);
  const snap = await ref.get();
  if (!snap.exists) {
    console.log(`⚠️  plans/${id} introuvable — ignoré.`);
    return false;
  }
  const data = snap.data();
  const before = Array.isArray(data.features) ? data.features : [];
  const features = withDrive(before);

  await ref.update({
    hasGoogleDriveSync: true,
    features,
    updatedAt: FieldValue.serverTimestamp(),
  });

  console.log(`✅ plans/${id} mis à jour`);
  console.log(`   hasGoogleDriveSync : ${data.hasGoogleDriveSync ?? '?'} → true`);
  console.log(`   features (${before.length} → ${features.length}) :`);
  features.forEach((f) => console.log(`     • ${f}`));
  return true;
}

async function main() {
  console.log('🔄 Mise à jour des plans : « Sauvegarde Google Drive » gratuite…');
  await updatePlan('free');
  await updatePlan('pro');
  await updatePlan('business');
  console.log('✔ Terminé.');
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ Erreur :', e);
  process.exit(1);
});
