// functions/index.js
//
// ☁️ Cloud Functions NOI OHADA Invoice Pro
// Met à jour les CUSTOM CLAIMS + AUDIT LOG + RESTAURATION D'OWNERSHIP.
//
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();
const REGION = 'europe-west1';

// ─────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────
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

    const teamsSnap = await db
        .collection('teams')
        .where('memberIds', 'array-contains', uid)
        .where('isActive', '==', true)
        .get();
    const teamIds = teamsSnap.docs.map(d => d.id);

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

// ─────────────────────────────────────────────────────────────────────
// 1. users/{uid} → admin + companyId
// ─────────────────────────────────────────────────────────────────────
exports.syncUserClaims = functions
    .region(REGION)
    .firestore.document('users/{uid}')
    .onWrite(async (change, ctx) => {
        const uid = ctx.params.uid;
        if (!change.after.exists) {
            try {
                await admin.auth().setCustomUserClaims(uid, null);
            } catch (_) {
                // Utilisateur déjà supprimé côté Auth : on ignore.
            }
            return;
        }
        await applyClaims(uid);
    });

// ─────────────────────────────────────────────────────────────────────
// 2. teams/{teamId} → teamIds pour tous les membres impactés
// ─────────────────────────────────────────────────────────────────────
exports.syncTeamClaims = functions
    .region(REGION)
    .firestore.document('teams/{teamId}')
    .onWrite(async (change, _ctx) => {
        const before = change.before.exists ? change.before.data() : null;
        const after = change.after.exists ? change.after.data() : null;

        const affected = new Set();
        [before, after].forEach(t => {
            if (!t) return;
            if (t.ownerId) affected.add(t.ownerId);
            (t.adminIds || []).forEach(u => affected.add(u));
            (t.memberIds || []).forEach(u => affected.add(u));
        });

        await Promise.all([...affected].map(applyClaims));
    });

// ─────────────────────────────────────────────────────────────────────
// 3. subscriptions → planId
// ─────────────────────────────────────────────────────────────────────
exports.syncSubscriptionClaims = functions
    .region(REGION)
    .firestore.document('subscriptions/{subId}')
    .onWrite(async (change, _ctx) => {
        const after = change.after.exists ? change.after.data() : null;
        const before = change.before.exists ? change.before.data() : null;
        const uid = (after && after.userId) || (before && before.userId);
        if (uid) await applyClaims(uid);
    });

// ─────────────────────────────────────────────────────────────────────
// 4. Callable : refreshMyClaims
// ─────────────────────────────────────────────────────────────────────
exports.refreshMyClaims = functions
    .region(REGION)
    .https.onCall(async (_data, context) => {
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'Auth requise.');
        }
        await applyClaims(context.auth.uid);
        return { ok: true };
    });

// ─────────────────────────────────────────────────────────────────────
// Charge les modules externes (migrations, audit, restauration).
// ⚠️ DOIT être en dernier : dépend de l'app Firebase déjà initialisée.
// ─────────────────────────────────────────────────────────────────────
require('./migrations');
require('./audit_log');
require('./restore_ownership');