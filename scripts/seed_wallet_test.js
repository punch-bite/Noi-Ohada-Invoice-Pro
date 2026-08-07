// scripts/seed_wallet_test.js
//
// 🧪 Injecte des DONNÉES DE TEST pour le portefeuille marchand :
//   - un solde crédité (wallets/{uid})
//   - des transactions de crédit (wallet_transactions)
//   - une demande de retrait en attente (wallet_withdrawals)
//
// Usage :
//   node scripts/seed_wallet_test.js <userId> [montant]
// Exemple :
//   node scripts/seed_wallet_test.js BPJKOyA8exZwAjXTU21QON60AP43 25000
//
const { initializeApp, getApps, cert } = require('firebase-admin');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', 'serviceAccountKey.json'));

if (!getApps().length) {
  initializeApp({ credential: cert(serviceAccount) });
}
const db = getFirestore();

async function seed() {
  const userId = process.argv[2];
  const amount = Number(process.argv[3] || 25000);
  if (!userId) {
    console.error('Usage : node scripts/seed_wallet_test.js <userId> [montant]');
    process.exit(1);
  }

  const ts = FieldValue.serverTimestamp();

  // 1) Portefeuille crédité
  await db.collection('wallets').doc(userId).set(
    {
      userId,
      balance: amount,
      currency: 'XAF',
      updatedAt: ts,
    },
    { merge: true }
  );
  console.log(`✅ wallets/${userId} → solde ${amount} FCFA`);

  // 2) Deux transactions de crédit (historique)
  const half = Math.round(amount / 2);
  await db.collection('wallet_transactions').add({
    userId,
    type: 'credit',
    amount: half,
    currency: 'XAF',
    reference: 'TEST-FAC-001',
    description: '[TEST] Paiement facture FA-2026-001',
    createdAt: ts,
  });
  await db.collection('wallet_transactions').add({
    userId,
    type: 'credit',
    amount: amount - half,
    currency: 'XAF',
    reference: 'TEST-FAC-002',
    description: '[TEST] Paiement facture FA-2026-002',
    createdAt: ts,
  });
  console.log('✅ wallet_transactions → 2 crédits [TEST]');

  // 3) Une demande de retrait en attente
  const withdrawal = {
    userId,
    amount: Math.min(5000, amount),
    phone: '690193310',
    currency: 'XAF',
    status: 'pending',
    createdAt: ts,
  };
  await db.collection('wallet_withdrawals').add(withdrawal);
  console.log('✅ wallet_withdrawals → 1 demande pending (5000 FCFA)');

  console.log('\n🎉 Données de test prêtes. Voir :');
  console.log('  - Marchand : Paramètres → Portefeuille');
  console.log('  - Admin    : Espace admin → Traiter les retraits');
  process.exit(0);
}

seed().catch((e) => {
  console.error('❌ Erreur seed :', e.message);
  process.exit(1);
});
