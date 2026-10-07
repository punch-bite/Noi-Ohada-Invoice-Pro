// functions/restore_ownership.js
//
// 🔄 RESTAURATION D'OWNERSHIP — Analyse `admin_audit_log` et restaure
//    les `userId` écrasés par un admin.
//
// À appeler UNE FOIS par un admin depuis la console Firebase.
// Idempotent : on peut le relancer sans risque.
//
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();

const REGION = 'europe-west1';

/// Analyse un docId donné : trouve le premier `ownerUidBefore` fiable
/// dans l'historique d'audit et le restaure si différent de l'actuel.
async function restoreOneDoc(collection, docId, dryRun = false) {
  // 1. Récupère l'historique des logs pour ce doc, trié chronologiquement.
  const logsSnap = await db
    .collection('admin_audit_log')
    .where('collection', '==', collection)
    .where('docId', '==', docId)
    .orderBy('timestamp', 'asc')
    .get();

  if (logsSnap.empty) {
    return { docId, status: 'no-audit-history' };
  }

  // 2. Cherche le PREMIER `ownerUidBefore` non nul.
  let originalOwner = null;
  let overwriteLog = null;

  for (const logDoc of logsSnap.docs) {
    const log = logDoc.data();

    // Le premier log (create) expose l'owner d'origine dans `ownerUidAfter`.
    if (log.action === 'create' && log.ownerUidAfter) {
      originalOwner = log.ownerUidAfter;
    }

    // Détecte un écrasement.
    if (log.ownershipChanged) {
      overwriteLog = log;
      break;
    }
  }

  if (!originalOwner) {
    return { docId, status: 'no-original-owner-detected' };
  }

  // 3. Compare avec l'actuel.
  const docRef = db.collection(collection).doc(docId);
  const docSnap = await docRef.get();
  if (!docSnap.exists) {
    return { docId, status: 'doc-deleted' };
  }

  const current = docSnap.data();
  if (current.userId === originalOwner) {
    return { docId, status: 'already-correct' };
  }

  // 4. Restaure (sauf en dryRun).
  if (!dryRun) {
    await docRef.update({
      userId: originalOwner,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      restoredAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`✅ Restauré ${collection}/${docId} → ${originalOwner}`);
  }

  return {
    docId,
    status: dryRun ? 'would-restore' : 'restored',
    from: current.userId,
    to: originalOwner,
    overwriteLog: overwriteLog
      ? { actorUid: overwriteLog.actorUid, at: overwriteLog.timestamp }
      : null,
  };
}

/// Callable principal.
exports.restoreOwnership = functions
  .region(REGION)
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .https.onCall(async (data, context) => {
    if (!context.auth || context.auth.token.admin !== true) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Admin requis.'
      );
    }

    const dryRun = data?.dryRun === true;
    const collectionFilter = data?.collection || null;
    const limit = typeof data?.limit === 'number' ? data.limit : 500;

    // 1. Récupère tous les logs marqués "ownershipChanged".
    let query = db
      .collection('admin_audit_log')
      .where('ownershipChanged', '==', true);

    if (collectionFilter) {
      query = query.where('collection', '==', collectionFilter);
    }

    const snap = await query.limit(limit).get();

    if (snap.empty) {
      return {
        ok: true,
        dryRun,
        processed: 0,
        message: 'Aucun écrasement détecté.',
      };
    }

    // 2. Dédoublonne par (collection, docId).
    const unique = new Map();
    for (const logDoc of snap.docs) {
      const log = logDoc.data();
      const key = `${log.collection}::${log.docId}`;
      if (!unique.has(key)) {
        unique.set(key, { collection: log.collection, docId: log.docId });
      }
    }

    // 3. Traite chaque document.
    const results = [];
    for (const { collection, docId } of unique.values()) {
      try {
        const r = await restoreOneDoc(collection, docId, dryRun);
        results.push(r);
      } catch (e) {
        results.push({ collection, docId, status: 'error', error: e.message });
      }
    }

    return {
      ok: true,
      dryRun,
      processed: results.length,
      restored: results.filter((r) => r.status === 'restored').length,
      wouldRestore: results.filter((r) => r.status === 'would-restore').length,
      alreadyCorrect: results.filter((r) => r.status === 'already-correct')
        .length,
      errors: results.filter((r) => r.status === 'error').length,
      details: results,
    };
  });