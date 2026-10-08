// ============================================================
//  register-sw.js - Enregistrement du SW + notification d'accueil
// ============================================================

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker
      .register('./sw.js')
      .then((registration) => {
        console.log('✅ Service Worker enregistré :', registration.scope);
        requestNotificationPermissionAndNotify(registration);
      })
      .catch((error) => {
        console.warn('❌ Échec enregistrement SW :', error);
      });
  });
}

// ---------- Notification d'accueil (1 seule fois / session) ----------
const NOTIF_FLAG = 'noi-install-notif-shown';

async function requestNotificationPermissionAndNotify(registration) {
  if (!('Notification' in window)) return;
  if (sessionStorage.getItem(NOTIF_FLAG) === '1') return;

  const isStandalone =
    window.matchMedia('(display-mode: standalone)').matches ||
    window.navigator.standalone === true;
  if (isStandalone) return;

  let permission = Notification.permission;
  if (permission === 'default') {
    permission = await Notification.requestPermission();
  }
  if (permission !== 'granted') return;

  sessionStorage.setItem(NOTIF_FLAG, '1');
  await showInstallNotification(registration);
}

async function showInstallNotification(registration) {
  const options = {
    body: "Installez NOI Invoice Pro pour un accès rapide hors-ligne.",
    icon: './icons/Icon-192.png',
    badge: './icons/Icon-192.png',
    vibrate: [100, 50, 100],
    tag: 'noi-install',
    renotify: false,
    data: { action: 'install-pwa', timestamp: Date.now() },
    requireInteraction: false,
    actions: [
      { action: 'install', title: '📥 Installer' },
      { action: 'later',   title: 'Plus tard' },
    ],
  };

  try {
    await registration.showNotification('NOI Invoice Pro', options);
  } catch (err) {
    console.warn('Échec affichage notification :', err);
  }
}

// ---------- Installation PWA ----------
let deferredPrompt = null;

window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  deferredPrompt = event;
  console.log("💡 Invite d'installation PWA disponible.");
});

window.addEventListener('appinstalled', () => {
  console.log('🎉 PWA installée avec succès.');
  deferredPrompt = null;
});

window.installPWA = async () => {
  if (!deferredPrompt) {
    console.warn("Aucune invite d'installation disponible.");
    return;
  }
  deferredPrompt.prompt();
  const choice = await deferredPrompt.userChoice;
  console.log('Choix utilisateur :', choice.outcome);
  deferredPrompt = null;
};

// ---------- Message reçu du SW (clic "Installer") ----------
navigator.serviceWorker?.addEventListener('message', (event) => {
  if (event.data?.type === 'TRIGGER_INSTALL') {
    window.installPWA?.();
  }
});

// ---------- Log mode standalone ----------
window.addEventListener('load', () => {
  if (
    window.matchMedia('(display-mode: standalone)').matches ||
    window.navigator.standalone === true
  ) {
    console.log('📱 App exécutée en mode standalone (installée).');
  }
});