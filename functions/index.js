// ============================================================
//  Cloud Functions — Callback NotchPay (NOI OHADA Invoice Pro)
//
//  Reçoit le callback / webhook NotchPay, vérifie la signature
//  HMAC-SHA256 (header `x-notch-signature`) puis active
//  l'abonnement de l'utilisateur dans Firestore (idempotent).
//
//  Fonctions :
//    paymentCallback  POST  (webhook NotchPay)
//    paymentVerify    GET   ?reference=...  (statut d'activation)
//    paymentHealth    GET   (santé du service)
//
//  URLs après déploiement (région africa-south1) :
//    https://africa-south1-facture-ohada.cloudfunctions.net/paymentCallback
//    https://africa-south1-facture-ohada.cloudfunctions.net/paymentVerify
//    https://africa-south1-facture-ohada.cloudfunctions.net/paymentHealth
//
//  Secret requis : NOCHPAY_WEBHOOK_SECRET
//    firebase functions:config:set notchpay.webhook_secret="<valeur>"
// ============================================================
const { onRequest } = require('firebase-functions/v2/https');
const functions = require('firebase-functions');
const crypto = require('crypto');
const admin = require('firebase-admin');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

// Initialisation (utilise les identifiants par défaut de l'environnement).
admin.initializeApp();
const db = getFirestore();
const serverTimestamp = () => FieldValue.serverTimestamp();

const REGION = 'africa-south1';

/// Secret du webhook (via functions.config() — gratuit, pas de billing).
/// Config : firebase functions:config:set notchpay.webhook_secret="..."
function webhookSecret() {
  try {
    return (functions.config().notchpay?.webhook_secret || '').toString();
  } catch (_) {
    return '';
  }
}

// ============================================================
//  HELPERS
// ============================================================
function isPaymentSuccessful(status) {
  const s = (status || '').toLowerCase();
  return ['complete', 'paid', 'success', 'successful'].includes(s);
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  return crypto.timingSafeEqual(bufA, bufB);
}

/// Vérifie la signature HMAC-SHA256 du webhook NotchPay.
/// Header attendu : `x-notch-signature: sha256=<hex digest>`.
function verifySignature(rawBody, signatureHeader, secret) {
  if (!secret) {
    console.warn('⚠️ NOCHPAY_WEBHOOK_SECRET absent — signature non vérifiée');
    return false;
  }
  const clean = (signatureHeader || '').trim().replace(/^sha256=/i, '');
  if (!clean) return false;
  const digest = crypto
    .createHmac('sha256', secret)
    .update(rawBody, 'utf8')
    .digest('hex');
  return timingSafeEqual(digest, clean);
}

function extractTransaction(data) {
  if (data && data.transaction && typeof data.transaction === 'object') {
    return data.transaction;
  }
  if (data && typeof data === 'object') return data;
  return {};
}

function extractMeta(txn, data) {
  return (
    txn.metadata ||
    txn.customer_meta ||
    txn.meta ||
    data.metadata ||
    data.customer_meta ||
    {}
  );
}

// ============================================================
//  ACTIVATION DE L'ABONNEMENT (idempotente)
// ============================================================
async function activateSubscription({
  userId,
  planId,
  reference,
  amount,
  currency,
  paymentMethod,
}) {
  if (!userId || !planId) {
    console.warn('⚠️ metadata sans user_id/plan_id — activation impossible');
    return false;
  }

  // Intervalle selon le plan (Business = annuel, sinon mensuel).
  let interval = 'month';
  try {
    const planDoc = await db.collection('plans').doc(planId).get();
    if (planDoc.exists && planDoc.data() && planDoc.data().interval) {
      interval = planDoc.data().interval;
    }
  } catch (e) {
    console.warn('⚠️ plan introuvable, interval défaut month', e.message);
  }

  return db.runTransaction(async (tx) => {
    // Idempotence : si un abonnement existe déjà avec ce paymentId, on le
    // réactive sans en créer un doublon.
    const existing = await tx.get(
      db.collection('subscriptions').where('paymentId', '==', reference).limit(1)
    );
    if (!existing.empty) {
      const doc = existing.docs[0];
      tx.update(doc.ref, {
        status: 'active',
        isActive: true,
        updatedAt: serverTimestamp(),
      });
      return true;
    }

    const subRef = db.collection('subscriptions').doc();
    const start = new Date();
    const days = interval === 'year' ? 365 : 30;
    const end = new Date(start.getTime() + days * 86400000);

    tx.set(subRef, {
      id: subRef.id,
      userId,
      planId,
      status: 'active',
      paymentMethod: paymentMethod || 'notchpay',
      paymentId: reference,
      amount: amount || 0,
      currency: currency || 'XAF',
      autoRenew: true,
      canceledAt: null,
      metadata: { notchpay_reference: reference, confirmed_by: 'cloud_function' },
      isActive: true,
      createdAt: serverTimestamp(),
      startDate: start,
      endDate: end,
      interval,
    });

    // Lie l'abonnement à l'utilisateur.
    const userRef = db.collection('users').doc(userId);
    tx.update(userRef, { subscriptionId: subRef.id });
    return true;
  });
}

// ============================================================
//  FONCTIONS
// ============================================================

/// Endpoint de callback appelé par NotchPay après un paiement.
exports.paymentCallback = onRequest(
  {
    region: REGION,
    memory: '256MiB',
    timeoutSeconds: 60,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Method not allowed' });
    }

    const signature =
      req.headers['x-notch-signature'] ||
      req.headers['x-notchpay-signature'] ||
      '';

    // `req.rawBody` = corps brut (Buffer) fourni par firebase-functions v2.
    const rawBody = req.rawBody || Buffer.from(JSON.stringify(req.body || {}));

    if (!verifySignature(rawBody, signature, webhookSecret())) {
      console.warn('❌ Signature invalide pour le callback');
      return res.status(401).json({ error: 'Invalid signature' });
    }

    const data = req.body || {};
    const txn = extractTransaction(data);
    const status = txn.status || data.status || '';

    if (!isPaymentSuccessful(status)) {
      console.log(`ℹ️ Paiement non finalisé (${status}) — ignoré`);
      return res.status(200).json({ received: true, status: 'not-complete' });
    }

    const reference = txn.reference || data.reference || '';
    const meta = extractMeta(txn, data);
    const userId = meta.user_id || meta.userId || '';
    const planId = meta.plan_id || meta.planId || '';

    try {
      const activated = await activateSubscription({
        userId,
        planId,
        reference,
        amount: txn.amount || data.amount || 0,
        currency: txn.currency || data.currency || 'XAF',
        paymentMethod: txn.payment_method || meta.payment_method || 'notchpay',
      });
      console.log(
        `✅ Callback traité — ref=${reference} user=${userId} plan=${planId} activated=${activated}`
      );
      return res.status(200).json({ received: true, activated });
    } catch (e) {
      console.error('❌ Erreur activation:', e);
      return res.status(500).json({ error: e.message });
    }
  }
);

/// Statut d'activation d'un paiement (polling) : GET ?reference=...
exports.paymentVerify = onRequest(
  { region: REGION, memory: '256MiB', timeoutSeconds: 30 },
  async (req, res) => {
    const ref = (req.query.reference || '').toString();
    if (!ref) {
      return res.status(400).json({ error: 'Paramètre reference manquant' });
    }
    try {
      const snap = await db
        .collection('subscriptions')
        .where('paymentId', '==', ref)
        .limit(1)
        .get();
      if (snap.empty) {
        return res.json({ reference: ref, status: 'pending', activated: false });
      }
      const s = snap.docs[0].data();
      return res.json({
        reference: ref,
        status: s.status,
        activated: s.status === 'active',
        subscriptionId: snap.docs[0].id,
      });
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  }
);

/// Santé du service.
exports.paymentHealth = onRequest({ region: REGION }, (req, res) =>
  res.json({
    ok: true,
    service: 'noi-ohada-payment-callback (cloud function)',
    time: new Date().toISOString(),
  })
);
