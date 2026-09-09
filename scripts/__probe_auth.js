// __probe_auth.js — diagnostic TEMPORAIRE (à supprimer)
const path = require('path');
const { initializeApp, getApps, cert } = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');

const API_KEY = 'AIzaSyDvSY8rOv-VyLycD2DZjeB7BM4CmDKsfZQ';
const BASE = 'https://server-xi-two-23.vercel.app';
const email = `probe${Date.now()}@example.com`;
const password = 'ProbePass123!';

const sa = require(path.join(__dirname, '..', 'serviceAccountKey.json'));
if (!getApps().length) initializeApp({ credential: cert(sa) });
const auth = getAuth();

// UIDs jetables des tests précédents à nettoyer aussi.
const LEFTOVER_UIDS = [
  'qVcNDJ2F1kO1oMf4QvW8A2MOaIo1',
  'XhlmmXX9boglQWLAv1Pwozh0DVJ3',
];

async function main() {
  const sign = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    }
  );
  const signBody = await sign.json();
  console.log('SIGNUP_HTTP', sign.status);
  if (!sign.ok) {
    console.log('SIGNUP_BODY', JSON.stringify(signBody));
    return;
  }
  const { idToken, localId } = signBody;
  console.log('UID', localId);

  // Vérif locale
  try {
    const decoded = await auth.verifyIdToken(idToken);
    console.log('LOCAL_VERIFY_OK uid=', decoded.uid);
  } catch (e) {
    console.log('LOCAL_VERIFY_ERR', e.code || '', e.message);
  }

  // Sonde serveur
  try {
    const r = await fetch(`${BASE}/__token_probe__`, {
      headers: { Authorization: `Bearer ${idToken}` },
    });
    console.log('SERVER_WITH_BEARER', r.status, (await r.text()).slice(0, 160));
  } catch (e) {
    console.log('SERVER_ERR', e.message);
  }

  // Nettoyage
  for (const uid of [localId, ...LEFTOVER_UIDS]) {
    try {
      await auth.deleteUser(uid);
      console.log('CLEANUP_DELETED', uid);
    } catch (e) {
      console.log('CLEANUP_ERR', uid, e.code || e.message);
    }
  }
}

main().catch((e) => {
  console.error('FATAL', e);
  process.exit(1);
});
