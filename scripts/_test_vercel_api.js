// test jetable : vérifie l'accès à l'API Vercel (create + delete d'une var test)
const fs = require('fs'); const os = require('os'); const path = require('path');
const ROOT = path.resolve(__dirname, '..');
const pj = JSON.parse(fs.readFileSync(path.join(ROOT, 'server', '.vercel', 'project.json'), 'utf8'));
function findToken() {
  if (process.env.VERCEL_TOKEN) return process.env.VERCEL_TOKEN.trim();
  const candidates = [
    path.join(os.homedir(), '.vercel', 'auth.json'),
    path.join(process.env.APPDATA || path.join(os.homedir(), '.config'), 'xdg.data', 'com.vercel.cli', 'auth.json'),
    path.join(os.homedir(), '.config', 'com.vercel.cli', 'auth.json'),
  ];
  for (const f of candidates) { try { const a = JSON.parse(fs.readFileSync(f, 'utf8')); if (a && a.token) return a.token; } catch (_) {} }
  return null;
}
const token = findToken();
const API = 'https://api.vercel.com';
const team = `teamId=${encodeURIComponent(pj.orgId)}`;
async function req(method, urlPath, body) {
  const r = await fetch(`${API}${urlPath}`, { method, headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
  const t = await r.text(); let d = null; try { d = JSON.parse(t); } catch (_) {}
  console.log('\n' + method, urlPath, '→', r.status);
  console.log('BODY:', t);
  return { status: r.status, data: d };
}
(async () => {
  const key = 'APP_TEST_PUBLISH';
  const created = await req('POST', `/v10/projects/${pj.projectId}/env?${team}`, { key, value: 'ok', type: 'encrypted', target: ['production'] });
  if (created.status >= 400) process.exit(1);
  const list = await req('GET', `/v9/projects/${pj.projectId}/env?${team}`);
  const found = (list.data.env || []).find((e) => e.key === key);
  if (found) await req('DELETE', `/v9/projects/${pj.projectId}/env/${found.id}?${team}`);
  console.log('\nOK API Vercel accessible ✅');
})().catch((e) => { console.error('FAIL', e.message); process.exit(1); });
