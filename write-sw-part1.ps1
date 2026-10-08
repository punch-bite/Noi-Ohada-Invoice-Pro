# Script: write-sw.ps1
# Écrit le contenu du service worker dans web/sw.js

$content = @'
// ============================================================
//  service-worker - NOI Invoice Pro (version web / PWA)
//  - Cache des assets statiques (cache-first)
//  - Cache pour l'installation et la navigation
//  - DÃ©tecte l'installation PWA et dÃ©clenche une notification
//  - Respecte prefers-reduced-motion
// ============================================================

const CACHE_NAME = 'noi-invoice-pro-v1';
const PRECACHE_URLS = [
  './',
  './index.html',
  './manifest.json',
  './contact_picker.js',
  './favicon.png',
  './icons/splash_logo.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-192.png',
  './icons/Icon-maskable-512.png',
  './light-1x.png',
  './light-2x.png',
  './light-3x.png',
  './light-4x.png',
  './dark-1x.png',
  './dark-2x.png',
  './dark-3x.png',
  './dark-4x.png',
  './splash_logo.png',
];
'@

$content | Set-Content -Path "G:\futter_projets\noi_ohada_invoice_pro\web\sw.js" -Force -Encoding UTF8
Write-Host "Partie 1 Ã©crite."
