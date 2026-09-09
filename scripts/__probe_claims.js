// __probe_claims.js — inspecte iss/aud d'un jeton Firebase du projet (temporaire)
const path = require('path');
const { initializeApp, getApps, cert } = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');

const API_KEY = 'AIzaSyDvSY8rOv-VyLycD2DZjeB7BM4CmDKsfZQ';
const sa = require(path.join(__dirname, '..', 'serviceAccountKey.json'));
if (!getApps().length) initializeApp({ credential: cert(sa) });
const auth = getAuth();

async function main() {
  const email = `claims${Date.now()}@example.com`;
  const sign = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: 'ProbePass123!', returnSecureToken: true }),
    }
  );
  const b = await sign.json();
  if (!sign.ok) { console.log('SIGNUP', sign.status, JSON.stringify(b)); return; }
  const parts = b.idToken.split('.');
  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
  console.log('ISS', payload.iss);
  console.log('AUD', payload.aud);
  console.log('EXP', payload.exp, 'now', Math.floor(Date.now() / 1000));
  try { await auth.deleteUser(b.localId); console.log('CLEANUP', b.localId); }
  catch (e) { console.log('CLEANUP_ERR', e.message); }
}
main().catch((e) => { console.error('FATAL', e); process.exit(1); });
