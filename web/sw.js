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

// -----------------------------------------------------------
//  Événement install : pré-cache des ressources statiques
// -----------------------------------------------------------
self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      await cache.addAll(PRECACHE_URLS);
      // Forcer le positionnement du worker (activation immédiate)
      self.skipWaiting();
    })(),
  );
});

// -----------------------------------------------------------
//  Événement activate : nettoyage des anciens caches
// -----------------------------------------------------------
self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys.map(async (key) => {
          if (key !== CACHE_NAME) {
            await caches.delete(key);
          }
        }),
      );
      // Forcer l'adoption du nouveau worker
      self.clients.claim();
    })(),
  );
});

// -----------------------------------------------------------
//  Ã‰vÃ©nement fetch : cache-first pour les statiques,
//  network-first pour les requÃªtes dynamiques (/api/*)
// -----------------------------------------------------------
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Si c'est une requÃªte API â†’ network-first
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(
      (async () => {
        try {
          const network = await fetch(request);
          const cache = await caches.open(CACHE_NAME);
          await cache.put(request, network.clone());
          return network;
        } catch {
          const cached = await caches.match(request);
          return cached || new Response('API indisponible', { status: 503 });
        }
      })(),
    );
    return;
  }

  // Sinon â†’ cache-first
  event.respondWith(
    caches.match(request).then((cachedResponse) => {
      const networkFallback = fetch(request)
        .then((response) => {
          if (response.ok) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
          }
          return response;
        })
        .catch(() => cachedResponse);

      return cachedResponse || networkFallback;
    }),
  );
});

// -----------------------------------------------------------
//  événement message : accepte les requètes du scope pour
//  l'envoi de notifications (appelé par le JS principal)
// -----------------------------------------------------------
self.addEventListener('message', (event) => {
  if (event.data?.type === 'SHOW_INSTALL_NOTIFICATION') {
    // Vérifie que les notifications sont autorisées
    if (!self.registration || !self.registration.pushManager) {
      return;
    }
    const permission = Notification.permission;
    if (permission === 'denied') {
      return;
    }
    if (permission === 'default') {
      // Demande l'autorisation si elle n'a pas encore été accordé
      self.registration
        .showNotification('NOI Invoice Pro', {
          body: 'L\'application poussÃ©e est prÃªte Ã  l\'emploi.',
          icon: './favicon.png',
          badge: './favicon.png',
          vibrate: [100, 50, 100],
          silent: false,
          data: { action: 'install-pwa', timestamp: Date.now() },
          requireInteraction: true,
        })
        .catch(() => {});
      return;
    }
    // Autorisation déjà  accordée : affiche la notification directement
    self.registration
      .showNotification('NOI Invoice Pro', {
        body: 'L\'application poussÃ©e est prête à l\'emploi.',
        icon: './favicon.png',
        badge: './favicon.png',
        vibrate: [100, 50, 100],
        silent: false,
        data: { action: 'install-pwa', timestamp: Date.now() },
        requireInteraction: true,
      })
      .catch(() => {});
  }
});

// -----------------------------------------------------------
//  Événement push (optionnel) : si un push est reçu,
//  on affiche la notification
// -----------------------------------------------------------
self.addEventListener('push', (event) => {
  if (!event.data) {
    return;
  }
  const data = event.data.json ? event.data.json() : { title: 'NOI Invoice Pro', body: 'Nouvelle notification.' };
  const options = {
    body: data.body || 'Nouvelle notification.',
    icon: './favicon.png',
    badge: './favicon.png',
    vibrate: [100, 50, 100],
    data: data.data || {},
  };
  event.waitUntil(
    self.registration.showNotification(data.title || 'NOI Invoice Pro', options),
  );
});

// -----------------------------------------------------------
//  Événement notificationclick : gestion du clic sur la
//  notification (rediriger vers l'application)
// -----------------------------------------------------------
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || { action: 'install-pwa' };
  if (data.action === 'install-pwa') {
    // Ouvrir la fenêtre principale si elle n'est pas ouverte
    event.waitUntil(
      self.clients
        .matchAll({ type: 'window', includeUncontrolled: true })
        .then((clientList) => {
          for (const client of clientList) {
            if (client.url.includes('./')) {
              return client.navigate(client.url);
            }
          }
          return self.clients.openWindow('./');
        }),
    );
  }
});
