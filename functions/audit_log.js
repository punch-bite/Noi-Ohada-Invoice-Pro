// functions/audit_log.js
//
// 📝 AUDIT LOG — Enregistre TOUTES les écritures sur les collections
//    métier dans `admin_audit_log`.
//
// Ce fichier ajoute un trigger `onWrite` sur chaque collection sensible.
// À chaque création / mise à jour / suppression, un document de log est
// ajouté à `admin_audit_log` avec :
//   • collection, docId, action
//   • actorUid (qui a fait l'action)
//   • ownerUidBefore / ownerUidAfter (détection d'écrasement)
//   • ownershipChanged (flag d'alerte)
//   • diff résumé (champs modifiés)
//
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();

const REGION = 'europe-west1';

/// Collections surveillées par l'audit log.
const MONITORED = [
  'clients',
  'invoices',
  'products',
  'suppliers',
  'reminders',
  'companies',
  'users',
];

/// Calcule un résumé compact des changements entre deux Maps.
/// Limite à 20 champs pour éviter les documents géants.
function summarizeDiff(before, after) {
  const changes = {};
  const allKeys = new Set([
    ...Object.keys(before || {}),
    ...Object.keys(after || {}),
  ]);

  let count = 0;
  for (const key of allKeys) {
    if (count >= 20) break;
    const b = before ? before[key] : undefined;
    const a = after ? after[key] : undefined;

    // Compare par JSON.stringify (approximation robuste pour audit).
    const bStr = JSON.stringify(b);
    const aStr = JSON.stringify(a);

    if (bStr !== aStr) {
      changes[key] = { before: b, after: a };
      count++;
    }
  }
  return changes;
}

/// Enregistre un log d'audit.
async function writeAuditLog({
  collection,
  docId,
  action,
  actorUid,
  before,
  after,
}) {
  const ownerBefore = before ? before.userId : null;
  const ownerAfter = after ? after.userId : null;

  const ownershipChanged =
    ownerBefore != null &&
    ownerAfter != null &&
    ownerBefore !== ownerAfter;

  const docRef = db.collection('admin_audit_log').doc();

  await docRef.set({
    id: docRef.id,
    collection,
    docId,
    action,
    actorUid: actorUid || null,
    ownerUidBefore: ownerBefore,
    ownerUidAfter: ownerAfter,
    ownershipChanged,
    companyId: after ? after.companyId || null : null,
    diff: summarizeDiff(before, after),
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/// Déclencheur générique pour une collection donnée.
function buildTrigger(collectionName) {
  return functions
    .region(REGION)
    .firestore.document(`${collectionName}/{docId}`)
    .onWrite(async (change, context) => {
      try {
        const before = change.before.exists ? change.before.data() : null;
        const after = change.after.exists ? change.after.data() : null;

        // Détection de l'action.
        let action = 'update';
        if (!before && after) action = 'create';
        else if (before && !after) action = 'delete';

        // Récupération de l'actor depuis les métadonnées (si dispo).
        // Firestore n'expose pas directement l'utilisateur qui a écrit ;
        // on se base sur `lastEditedBy` (ajouté par DatabaseService v5)
        // OU sur `userId` en fallback.
        const actorUid =
          (after && (after.lastEditedBy || after.userId)) ||
          (before && (before.lastEditedBy || before.userId)) ||
          null;

        await writeAuditLog({
          collection: collectionName,
          docId: context.params.docId,
          action,
          actorUid,
          before,
          after,
        });

        // ⚠️ Si un écrasement de propriétaire est détecté, on log un
        //    WARNING explicite pour faciliter le diagnostic.
        if (
          before &&
          after &&
          before.userId &&
          after.userId &&
          before.userId !== after.userId
        ) {
          console.error(
            `🚨 OWNERSHIP OVERWRITE dans ${collectionName}/${context.params.docId} : ` +
              `${before.userId} → ${after.userId} (par ${actorUid})`
          );
        }
      } catch (e) {
        console.error('❌ audit_log error:', e);
      }
    });
}

// ─────────────────────────────────────────────────────────────────────
//  Exports
// ─────────────────────────────────────────────────────────────────────
exports.auditClients = buildTrigger('clients');
exports.auditInvoices = buildTrigger('invoices');
exports.auditProducts = buildTrigger('products');
exports.auditSuppliers = buildTrigger('suppliers');
exports.auditReminders = buildTrigger('reminders');
exports.auditCompanies = buildTrigger('companies');
// ⚠️ Décommenter si tu veux aussi surveiller `users` :
// exports.auditUsers = buildTrigger('users');