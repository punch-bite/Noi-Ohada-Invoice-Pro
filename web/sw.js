// ============================================================
//  service-worker - NOI Invoice Pro (PWA)
//  - Cache-first pour statiques, network-first pour /api/ et navigation
//  - Notification d'installation depuis le SW
// ============================================================

const CACHE_NAME = 'noi-invoice-pro-v2';

const PRECACHE_URLS = [
  './',
  './index.html',
  './manifest.json',
  './contact_picker.js',
  './flutter_bootstrap.js',

  './favicon.png',
  './icons/splash_logo.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-192.png',
  './icons/Icon-maskable-512.png',

  './splash/img/light-1x.png',
  './splash/img/light-2x.png',
  './splash/img/light-3x.png',
  './splash/img/light-4x.png',
  './splash/img/dark-1x.png',
  './splash/img/dark-2x.png',
  './splash/img/dark-3x.png',
  './splash/img/dark-4x.png',
];

// ---------- INSTALL ----------
self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      // add() un par un : un 404 ne fait pas échouer tout le pré-cache
      await Promise.all(
        PRECACHE_URLS.map((url) =>
          cache.add(url).catch((err) =>
            console.warn(`⚠️ Précache ignoré : ${url}`, err)
          )
        )
      );
      self.skipWaiting();
    })()
  );
});

// ---------- ACTIVATE ----------
self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))
      );
      await self.clients.claim();
    })()
  );
});

// ---------- FETCH ----------
self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  // API → network-first
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(
      (async () => {
        try {
          const network = await fetch(request);
          const cache = await caches.open(CACHE_NAME);
          cache.put(request, network.clone());
          return network;
        } catch {
          const cached = await caches.match(request);
          return cached || new Response('API indisponible', { status: 503 });
        }
      })()
    );
    return;
  }

  // Navigation → network-first avec fallback index.html
  if (request.mode === 'navigate') {
    event.respondWith(
      (async () => {
        try {
          const network = await fetch(request);
          const cache = await caches.open(CACHE_NAME);
          cache.put(request, network.clone());
          return network;
        } catch {
          const cached = await caches.match(request);
          return cached || caches.match('./index.html');
        }
      })()
    );
    return;
  }

  // Statique → cache-first
  event.respondWith(
    (async () => {
      const cached = await caches.match(request);
      if (cached) return cached;
      try {
        const network = await fetch(request);
        if (network.ok) {
          const cache = await caches.open(CACHE_NAME);
          cache.put(request, network.clone());
        }
        return network;
      } catch {
        return new Response('', { status: 504 });
      }
    })()
  );
});

// ---------- MESSAGE (depuis la page) ----------
self.addEventListener('message', (event) => {
  if (event.data?.type === 'SHOW_INSTALL_NOTIFICATION') {
    self.registration.showNotification('NOI Invoice Pro', {
      body: "Installez l'application pour un accès rapide hors-ligne.",
      icon: './icons/Icon-192.png',
      badge: './icons/Icon-192.png',
      vibrate: [100, 50, 100],
      tag: 'noi-install',
      data: { action: 'install-pwa' },
    });
  }
});

// ---------- PUSH ----------
self.addEventListener('push', (event) => {
  if (!event.data) return;
  let data = { title: 'NOI Invoice Pro', body: 'Nouvelle notification.' };
  try { data = event.data.json(); } catch { /* texte brut */ }

  event.waitUntil(
    self.registration.showNotification(data.title || 'NOI Invoice Pro', {
      body: data.body || '',
      icon: './icons/Icon-192.png',
      badge: './icons/Icon-192.png',
      vibrate: [100, 50, 100],
      data: data.data || {},
    })
  );
});

// ---------- CLICK sur notification ----------
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const action = event.action;
  const data = event.notification.data || {};

  if (action === 'later') return;

  event.waitUntil(
    (async () => {
      const clientList = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });

      for (const client of clientList) {
        if ('focus' in client) {
          await client.focus();
          if (action === 'install' || data.action === 'install-pwa') {
            client.postMessage({ type: 'TRIGGER_INSTALL' });
          }
          return;
        }
      }
      if (self.clients.openWindow) {
        await self.clients.openWindow('./');
      }
    })()
  );
});