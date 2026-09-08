// ============================================================
//  server/landing.js — Vitrine publique (refonte « soft »)
//
//  Page d'accueil raffinée, minimaliste, très douce :
//    • fond sombre très doux avec une LUMIÈRE qui suit la souris
//    • icônes monochromes hautes couture (SVG fin, trait 1.5)
//    • aucune info technique (les API restent derrière l'auth)
// ============================================================
const fs = require('fs');
const path = require('path');

// Petites icônes SVG monochromes — trait fin, « currentColor ».
const ICON = {
  down:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3.5v11.5"/><path d="M7.6 11 12 15.4 16.4 11"/><path d="M4.5 19.5h15"/></svg>',
  arr:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12h15"/><path d="M13 6.5 18.5 12 13 17.5"/></svg>',
  receipt:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2.5h12v19l-2.3-1.7L13.4 21.5l-1.9-1.7-1.9 1.7-2.3-1.7L6 21.5v-19z"/><path d="M9 8.5h6M9 12h6M9 15.5h3"/></svg>',
  client:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.2"/><path d="M2.8 20c0-3.3 2.8-5.2 6.2-5.2s6.2 1.9 6.2 5.2"/><path d="M17 9.2a2.6 2.6 0 1 0 0-5.2M21.2 20c0-2.7-1.6-4.6-4.2-5"/></svg>',
  stock:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 7.5 12 3l8.5 4.5v9L12 21l-8.5-4.5v-9z"/><path d="M3.5 7.5 12 12l8.5-4.5M12 12v9"/><path d="M8 5.2 16.5 9.8"/></svg>',
  chart:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20.5v-8M10 20.5v-14M16 20.5v-5M21.5 20.5H2.5"/></svg>',
  team:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="3.2"/><path d="M5 20c0-3.7 3.1-5.8 7-5.8s7 2.1 7 5.8"/><path d="M18.5 4.6a2.9 2.9 0 1 1 0 5.8M2.5 20"/></svg>',
  template:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M4 5.5A1.5 1.5 0 0 1 5.5 4h13A1.5 1.5 0 0 1 20 5.5v13a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 18.5v-13z"/><path d="M4 9h16M9.5 4v5"/><path d="M9.5 14.5 11.5 16l3-3.5"/></svg>',
  shield:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2.8 19 5.6v6c0 4.4-3 7.6-7 9-4-1.4-7-4.6-7-9v-6l7-2.8z"/><path d="m8.6 11.8 2.3 2.4 4.5-5"/></svg>',
  globe:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.6 2.4 3.9 5.3 3.9 8.5S14.6 18.1 12 20.5C9.4 18.1 8.1 15.2 8.1 12S9.4 5.9 12 3.5z"/></svg>',
  phone:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="6.5" y="2.8" width="11" height="18.4" rx="2.6"/><path d="M10.5 18.2h3"/></svg>',
  check:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12.6 4.4 4.4L19 7.4"/></svg>',
};

const CSS = `
*{margin:0;padding:0;box-sizing:border-box}
:root{
  --bg:#0e0d12;            /* encre très douce */
  --panel:rgba(255,255,255,.032);
  --panel2:rgba(255,255,255,.05);
  --line:rgba(255,255,255,.075);
  --ink:#f3efe8;           /* texte chaud très doux */
  --mut:#9b948a;           /* texte atténué */
  --faint:rgba(255,255,255,.38);
  --acc:#8b7cff;           /* indigo doux */
  --acc2:#c9b8ff;
  --gold:#e6c886;
  --r:22px;
}
html{scroll-behavior:smooth}
body{
  font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;
  background:var(--bg);color:var(--ink);
  min-height:100vh;-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility;
  overflow-x:hidden;
}
/* Fond : halos très doux fixes + LUMIÈRE QUI SUIT LA SOURIS */
.bg{position:fixed;inset:0;z-index:0;pointer-events:none;overflow:hidden}
.bg .halo{position:absolute;border-radius:50%;filter:blur(80px);opacity:.5}
.bg .h1{width:560px;height:560px;left:-180px;top:-160px;background:radial-gradient(circle,#6d5cff33,transparent 70%)}
.bg .h2{width:620px;height:620px;right:-220px;bottom:-240px;background:radial-gradient(circle,#e6c8861f,transparent 70%)}
.bg .h3{width:420px;height:420px;left:44%;top:46%;background:radial-gradient(circle,#9a8cff0f,transparent 70%)}
.aura{
  position:fixed;inset:0;z-index:1;pointer-events:none;
  background:radial-gradient(620px circle at var(--mx,50%) var(--my,35%),rgba(139,124,255,.16),rgba(139,124,255,.05) 38%,transparent 72%);
  transition:opacity .4s ease;will-change:background
}
.wrap{position:relative;z-index:2;max-width:1080px;margin:0 auto;padding:0 22px}
header{display:flex;align-items:center;justify-content:space-between;padding:26px 0}
.brand{display:flex;align-items:center;gap:12px;font-weight:600;font-size:15px;letter-spacing:-.01em}
.brand .logo{width:38px;height:38px;border-radius:11px;display:grid;place-items:center;background:var(--panel2);border:1px solid var(--line);overflow:hidden}
.brand .logo img{width:100%;height:100%;object-fit:cover;display:block}
.hnav{display:flex;align-items:center;gap:6px}
.hnav a{color:var(--mut);text-decoration:none;font-size:13.5px;padding:8px 13px;border-radius:999px;transition:.2s}
.hnav a:hover{color:var(--ink);background:var(--panel)}
.btn{display:inline-flex;align-items:center;gap:9px;text-decoration:none;font-weight:600;border-radius:999px;border:1px solid var(--line);padding:11px 18px;font-size:14px;transition:.2s;cursor:pointer}
.btn svg{width:17px;height:17px}
.btn.primary{background:linear-gradient(135deg,#6a58f0,#4f46e5);border-color:transparent;color:#fff;box-shadow:0 8px 28px rgba(99,84,240,.30)}
.btn.primary:hover{transform:translateY(-1px);box-shadow:0 12px 34px rgba(99,84,240,.42)}
.btn.ghost{color:var(--ink);background:var(--panel)}
.btn.ghost:hover{background:var(--panel2)}
.btn.small{padding:8px 14px;font-size:13px}
/* Hero */
.hero{text-align:center;padding:64px 0 30px}
.eyebrow{display:inline-flex;align-items:center;gap:8px;color:var(--mut);font-size:12px;letter-spacing:.14em;text-transform:uppercase;border:1px solid var(--line);background:var(--panel);padding:7px 14px;border-radius:999px;margin-bottom:26px}
.eyebrow .dot{width:6px;height:6px;border-radius:50%;background:var(--gold);box-shadow:0 0 0 4px rgba(230,200,134,.12)}
.hero h1{font-size:clamp(2.1rem,5.6vw,3.5rem);line-height:1.06;font-weight:650;letter-spacing:-.03em;max-width:820px;margin:0 auto}
.hero h1 .grad{background:linear-gradient(100deg,#c3b6ff 0%,#8b7cff 52%,#e6c886 120%);-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.hero .lead{color:var(--mut);font-size:clamp(1rem,1.6vw,1.14rem);line-height:1.7;max-width:600px;margin:20px auto 0}
.cta{display:flex;gap:12px;justify-content:center;flex-wrap:wrap;margin-top:32px}
.trust{display:flex;flex-wrap:wrap;justify-content:center;gap:26px;margin-top:44px;color:var(--faint);font-size:12.5px;letter-spacing:.02em}
.trust span{display:inline-flex;align-items:center;gap:7px}
.trust svg{width:15px;height:15px;color:var(--gold)}
/* Sections */
section{padding:54px 0 8px}
.kicker{font-size:12px;letter-spacing:.16em;text-transform:uppercase;color:var(--acc2);text-align:center;margin-bottom:12px}
h2.st{font-size:clamp(1.4rem,3vw,1.9rem);font-weight:600;letter-spacing:-.02em;text-align:center}
p.sts{color:var(--mut);text-align:center;font-size:14.5px;max-width:520px;margin:12px auto 34px;line-height:1.7}
/* Grille fonctionnalités */
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}
.feat{background:var(--panel);border:1px solid var(--line);border-radius:18px;padding:22px;display:flex;flex-direction:column;gap:12px;transition:.25s}
.feat:hover{background:var(--panel2);transform:translateY(-2px)}
.feat .fi{width:40px;height:40px;border-radius:12px;display:grid;place-items:center;color:var(--acc2);background:rgba(139,124,255,.10);border:1px solid rgba(139,124,255,.16)}
.feat .fi svg{width:20px;height:20px}
.feat b{font-weight:600;font-size:14.5px;letter-spacing:-.01em}
.feat p{color:var(--mut);font-size:13px;line-height:1.6}
/* Bandeau final */
.cta-band{margin-top:46px;border-radius:26px;overflow:hidden;position:relative;text-align:center;padding:52px 28px;border:1px solid var(--line);background:linear-gradient(140deg,rgba(105,88,240,.16),rgba(139,124,255,.05) 42%,rgba(230,200,134,.07))}
.cta-band h2{font-size:clamp(1.3rem,2.6vw,1.7rem);font-weight:600;letter-spacing:-.02em}
.cta-band p{color:var(--mut);font-size:14px;max-width:460px;margin:12px auto 24px;line-height:1.7}
footer{border-top:1px solid var(--line);margin-top:56px;padding:30px 0 42px;display:flex;flex-direction:column;gap:16px;align-items:center}
.flinks{display:flex;flex-wrap:wrap;gap:8px 26px;justify-content:center}
.flinks a{color:var(--mut);text-decoration:none;font-size:13px;transition:.2s}
.flinks a:hover{color:var(--ink)}
.fcopy{color:var(--faint);font-size:12px}
@media(max-width:860px){.grid{grid-template-columns:1fr 1fr}}
@media(max-width:620px){.grid{grid-template-columns:1fr}.hnav a:not(.btn){display:none}}
`;

function renderLanding() {
  const year = new Date().getFullYear();
  return `<!DOCTYPE html>
<html lang="fr"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<link rel="icon" type="image/png" href="/favicon.png">
<title>Noi OHADA Invoice Pro — Facturation conforme OHADA</title>
<meta name="description" content="Factures et devis conformes SYSCOHADA révisé, gestion des stocks et équipes — facturation professionnelle en ligne comme hors connexion.">
<style>${CSS}</style>
</head><body>
<div class="bg"><div class="halo h1"></div><div class="halo h2"></div><div class="halo h3"></div></div>
<div class="aura" aria-hidden="true"></div>

<div class="wrap">
  <header>
    <a class="brand" href="/"><span class="logo text-decoration-none"><img src="/logo.png" alt="Noi OHADA Invoice Pro"></span>Noi OHADA</a>
    <nav class="hnav">
      <a href="#fonctionnalites">Fonctionnalités</a>
      <a class="btn small primary" href="/download">${ICON.down} Télécharger</a>
    </nav>
  </header>

  <section class="hero">
    <span class="eyebrow"><span class="dot"></span> Conforme SYSCOHADA révisé</span>
    <h1>Une facturation <span class="grad">professionnelle</span>, pensée pour votre commerce.</h1>
    <p class="lead">Créez des factures et devis élégants en quelques secondes, suivez vos stocks — en ligne comme hors connexion.</p>
    <div class="cta">
      <a class="btn primary" href="/download">${ICON.down} Télécharger l'application</a>
      <a class="btn ghost" href="https://app.noi-ohada-invoice-pro.com" target="_blank" rel="noopener">${ICON.globe} Version web</a>
    </div>
    <div class="trust">
      <span>${ICON.check} Conforme OHADA</span>
      <span>${ICON.check} Hors-ligne inclus</span>
    </div>
  </section>

  <section id="fonctionnalites">
    <div class="kicker">Tout-en-un</div>
    <h2 class="st">L'essentiel, réuni</h2>
    <p class="sts">Des outils simples et complets, conçus pour le terrain et les réalités des entreprises OHADA.</p>
    <div class="grid">
      <div class="feat"><span class="fi">${ICON.receipt}</span><b>Factures &amp; devis</b><p>Factures conformes SYSCOHADA, TVA, remises et PDF à vos couleurs.</p></div>
      <div class="feat"><span class="fi">${ICON.client}</span><b>Clients &amp; historique</b><p>Fiches clients, historique et créances suivies automatiquement.</p></div>
      <div class="feat"><span class="fi">${ICON.stock}</span><b>Stocks &amp; livraisons</b><p>Alertes de rupture, livraisons et inventaire valorisé en temps réel.</p></div>
      <div class="feat"><span class="fi">${ICON.chart}</span><b>Tableau de bord</b><p>Chiffre d'affaires, bénéfices et dettes clients à jour.</p></div>
      <div class="feat"><span class="fi">${ICON.team}</span><b>Équipe</b><p>Invitez vos collaborateurs et partagez factures et clients.</p></div>
      <div class="feat"><span class="fi">${ICON.template}</span><b>Modèles personnalisés</b><p>Logo, couleurs et mise en page à votre image.</p></div>
    </div>
  </section>

  <section class="cta-band">
    <h2>Prêt à facturer comme un professionnel ?</h2>
    <p>Téléchargez Noi OHADA Invoice Pro et émettez votre première facture conforme en moins de deux minutes.</p>
    <a class="btn primary" href="/download">${ICON.down} Télécharger maintenant</a>
  </section>

  <footer>
    <div class="flinks">
      <a href="/download">Télécharger</a>
      <a href="https://app.noi-ohada-invoice-pro.com" target="_blank" rel="noopener">Version web</a>
      <a href="mailto:support@noi-ohada-invoice-pro.com">Support</a>
    </div>
    <div class="fcopy">© ${year} Noi OHADA Invoice Pro — Tous droits réservés.</div>
  </footer>
</div>

<script>
(function () {
  var r = document.documentElement;
  function track(e) {
    var x = (e.clientX || window.innerWidth / 2);
    var y = (e.clientY || window.innerHeight / 2);
    r.style.setProperty('--mx', x + 'px');
    r.style.setProperty('--my', y + 'px');
  }
  window.addEventListener('pointermove', track, { passive: true });
  track({ clientX: window.innerWidth * 0.5, clientY: window.innerHeight * 0.34 });
})();
</script>
</body></html>`;
}

module.exports = { renderLanding, CSS };
