// scripts/set_admin_claim.js
//
// 🔐 Ajoute le custom claim `admin: true` à un utilisateur Firebase Auth.
// Usage :
//   node scripts/set_admin_claim.js <email>
// Exemple :
//   node scripts/set_admin_claim.js ilionsdigitale@gmail.com
//
const admin = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');
const path = require('path');

// Clé du service account (à NE PAS committer — gitignoré).
const serviceAccount = require(path.join(__dirname, '..', 'serviceAccountKey.json'));

admin.initializeApp({
  // firebase-admin v14 : `cert` est exposé à la racine.
  credential: admin.cert(serviceAccount),
});

async function setAdminClaim(email) {
  try {
    const auth = getAuth();
    const user = await auth.getUserByEmail(email);
    await auth.setCustomUserClaims(user.uid, { admin: true });
    console.log(`✅ Claim admin ajouté à ${email} (uid: ${user.uid})`);
    console.log('ℹ️ L\'utilisateur devra se reconnecter pour rafraîchir son token.');
  } catch (e) {
    console.error('❌ Erreur :', e.message);
    process.exit(1);
  }
}

const email = process.argv[2];
if (!email) {
  console.error('Usage : node scripts/set_admin_claim.js <email>');
  process.exit(1);
}
setAdminClaim(email);
