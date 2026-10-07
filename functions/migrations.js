// functions/migrations.js
//
// 🔄 Migration one-shot pour rétro-compatibiliser les utilisateurs et
//    documents existants avec le modèle SaaS (companyId + custom claims).
//
// À APPELER UNE SEULE FOIS, par un admin, depuis la console Firebase
// (Functions → migrateExistingData → Tester) ou via HTTPS.
//
// ACTIONS RÉALISÉES :
//   1. Pose `companyId` sur users/{uid} si absent.
//   2. Crée la company `company_{uid}` si elle n'existe pas.
//   3. Rattache chaque invoice/product/client/supplier/reminder existant
//      à la company de son propriétaire.
//   4. Ré-applique les claims admin/companyId/teamIds via `applyClaims`
//      (déjà branché sur `users/{uid}` onWrite).
//
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();

const REGION = 'europe-west1';

// ═══════════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════════

/**
 * Calcule les claims pour un utilisateur donné.
 * Source unique : cohérent avec syncUserClaims de index.js.
 */
async function computeClaimsForUser(uid) {
  const userSnap = await db.collection('users').doc(uid).get();
  const u = userSnap.exists ? userSnap.data() : {};

  const isAdmin = u.isAdmin === true
    || (Array.isArray(u.roles) &&
        u.roles.some(r => r === 'admin' || r === 'super-admin'));

  const companyId =
    (typeof u.companyId === 'string' && u.companyId.length > 0)
      ? u.companyId
      : null;

  // Équipes actives
  let teamIds = [];
  try {
    const teamsSnap = await db
      .collection('teams')
      .where('memberIds', 'array-contains', uid)
      .where('isActive', '==', true)
      .get();
    teamIds = teamsSnap.docs.map(d => d.id);
  } catch (_) {
    // Index composite manquant ou collection vide : on ignore.
  }

  // Plan actif
  let planId = null;
  try {
    const subSnap = await db
      .collection('subscriptions')
      .where('userId', '==', uid)
      .where('status', '==', 'active')
      .where('isActive', '==', true)
      .limit(1)
      .get();
    if (!subSnap.empty) planId = subSnap.docs[0].data().planId || null;
  } catch (_) {
    // Index composite manquant ou collection vide : on ignore.
  }

  return { admin: isAdmin, companyId, teamIds, planId };
}

/**
 * Applique les claims à un utilisateur (via Firebase Auth admin SDK).
 * Idempotent : ne réécrit pas si les claims sont identiques.
 */
async function applyClaims(uid) {
  if (!uid) return;
  try {
    const claims = await computeClaimsForUser(uid);
    const user = await admin.auth().getUser(uid);
    const current = user.customClaims || {};

    const same =
      current.admin === claims.admin &&
      (current.companyId || null) === claims.companyId &&
      JSON.stringify(current.teamIds || []) === JSON.stringify(claims.teamIds) &&
      (current.planId || null) === claims.planId;

    if (same) return;

    await admin.auth().setCustomUserClaims(uid, claims);
    console.log(`✅ Claims synchronisés pour ${uid}`, claims);
  } catch (e) {
    console.error(`❌ applyClaims(${uid})`, e);
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  MIGRATION PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════

/**
 * Crée (si absente) la company `company_{uid}` et retourne son ID.
 * Idempotent : ne recrée pas si une company existe déjà pour cet uid.
 */
async function ensureCompanyForUser(uid, userData) {
  // 1. La company existe déjà ?
  const existing = await db
    .collection('companies')
    .where('userId', '==', uid)
    .limit(1)
    .get();

  if (!existing.empty) return existing.docs[0].id;

  // 2. Création déterministe
  const companyId = `company_${uid}`;
  await db.collection('companies').doc(companyId).set({
    id: companyId,
    userId: uid,
    name: userData.companyName || userData.displayName || 'Mon entreprise',
    address: userData.companyAddress || '',
    taxId: userData.taxId || '',
    phone: userData.phone || '',
    email: userData.email || '',
    logoPath: '',
    currency: 'XAF',
    defaultTaxRate: 18,
    legalText: 'Conforme aux normes OHADA et SYSCOHADA',
    website: '',
    rccm: '',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    isActive: true,
    isSynced: true,
    memberIds: [uid],
    adminIds: [uid],
    sharedWithUsers: [],
  });
  console.log(`🏢 Company créée pour ${uid} → ${companyId}`);
  return companyId;
}

/**
 * Backfill d'une collection : pose `companyId` + initialise les arrays
 * de partage (sharedWithUsers, sharedTeams, editableByUsers, editableTeams)
 * sur tous les documents de cet utilisateur.
 */
async function backfillCollection(collectionName, uid, companyId) {
  const snapshot = await db
    .collection(collectionName)
    .where('userId', '==', uid)
    .get();

  if (snapshot.empty) return 0;

  const updates = [];
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const patch = {};
    if (!data.companyId || data.companyId === '') patch.companyId = companyId;
    if (!Array.isArray(data.sharedWithUsers)) patch.sharedWithUsers = [];
    if (!Array.isArray(data.sharedTeams)) patch.sharedTeams = [];
    if (!Array.isArray(data.editableByUsers)) patch.editableByUsers = [];
    if (!Array.isArray(data.editableTeams)) patch.editableTeams = [];
    if (Object.keys(patch).length > 0) {
      updates.push(doc.ref.update(patch));
    }
  }
  await Promise.all(updates);
  return updates.length;
}

/**
 * Migre un utilisateur donné :
 *   • ensureCompany
 *   • rattache le user à sa company
 *   • backfill de toutes les collections métier
 */
async function migrateOneUser(uid) {
  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) return { uid, skipped: 'no-user-doc' };

  const userData = userSnap.data();
  const companyId = await ensureCompanyForUser(uid, userData);

  // Rattache le user à sa company
  if (userData.companyId !== companyId) {
    await userRef.set(
      { companyId, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );
  }

  // Backfill sur les collections métier
  const stats = {};
  for (const col of [
    'invoices',
    'products',
    'clients',
    'suppliers',
    'deliveries',
    'reminders',
  ]) {
    stats[col] = await backfillCollection(col, uid, companyId);
  }

  // Pose les claims immédiatement
  await applyClaims(uid);

  return { uid, companyId, stats };
}

// ═══════════════════════════════════════════════════════════════════════
//  ENDPOINTS CALLABLE
// ═══════════════════════════════════════════════════════════════════════

/**
 * 🚀 migrateExistingData
 * Lance la migration sur les N premiers utilisateurs (par défaut 500).
 * Réservé aux admins (custom claim `admin: true`).
 *
 * Usage :
 *   - Console Firebase → Functions → migrateExistingData → Tester avec {}
 *   - Ou : `{ "limit": 1000 }` pour traiter plus d'users en un appel.
 */
exports.migrateExistingData = functions
  .region(REGION)
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Auth requise.');
    }
    if (context.auth.token.admin !== true) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Réservé aux administrateurs.'
      );
    }

    const limit = typeof data?.limit === 'number' ? data.limit : 500;
    const usersSnap = await db.collection('users').limit(limit).get();

    const results = [];
    for (const doc of usersSnap.docs) {
      try {
        const r = await migrateOneUser(doc.id);
        results.push(r);
      } catch (e) {
        console.error(`❌ migration ${doc.id}:`, e);
        results.push({ uid: doc.id, error: e.message });
      }
    }

    return {
      ok: true,
      processed: results.length,
      details: results,
    };
  });

/**
 * 🚀 backfillEditableUsers
 * Initialise `editableByUsers` / `editableTeams` sur les documents
 * partagés qui ne les ont pas encore (fail-safe : lecture seule).
 *
 * Réservé aux admins.
 */
exports.backfillEditableUsers = functions
  .region(REGION)
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .https.onCall(async (_data, context) => {
    if (!context.auth || context.auth.token.admin !== true) {
      throw new functions.https.HttpsError('permission-denied', 'Admin requis.');
    }

    let total = 0;
    for (const col of ['invoices', 'products', 'clients', 'suppliers']) {
      // Récupère les docs qui ont sharedWithUsers non vide
      const snap = await db
        .collection(col)
        .where('sharedWithUsers', '!=', [])
        .get();

      for (const doc of snap.docs) {
        const data = doc.data();
        const users = Array.isArray(data.sharedWithUsers)
          ? data.sharedWithUsers
          : [];
        const teams = Array.isArray(data.sharedTeams) ? data.sharedTeams : [];
        if (users.length === 0 && teams.length === 0) continue;

        const patch = {};
        if (!Array.isArray(data.editableByUsers)) {
          // Politique par défaut : les partages "write" hérités ne sont pas
          // détectables ; on laisse vide (fail-safe lecture seule).
          patch.editableByUsers = [];
        }
        if (!Array.isArray(data.editableTeams)) {
          patch.editableTeams = [];
        }
        if (Object.keys(patch).length) {
          await doc.ref.update(patch);
          total++;
        }
      }
    }
    return { ok: true, updated: total };
  });

/**
 * 🚀 refreshMyClaims
 * Callable de secours pour forcer un refresh des claims de l'appelant.
 * Utile après une mise à jour sensible du profil (changement de companyId).
 */
exports.refreshMyClaims = functions
  .region(REGION)
  .https.onCall(async (_data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Auth requise.');
    }
    await applyClaims(context.auth.uid);
    return { ok: true };
  });