# Script: write-register-sw.ps1
# Écrit le fichier register-sw.js dans web/

$content = @'
// ============================================================
//  register-sw.js - Enregistrement du service worker
//  et gestion de l'installation PWA
// ============================================================

// Vérifie si le navigateur supporte les Service Workers et le Push
if ('serviceWorker' in navigator && 'PushManager' in window) {
  // Enregistre le service worker
  window.addEventListener('load', () => {
    navigator.serviceWorker
      .register('./sw.js')
      .then((registration) => {
        console.log('Service Worker enregistré avec succès :', registration.scope);
      })
      .catch((error) => {
        console.warn('Échec de l\'enregistrement du Service Worker :', error);
      });
  });
}

// Variables globales pour gérer l'installation PWA
let deferredPrompt = null;

// Fonction pour afficher la notification d'installation
function showInstallNotification() {
  if (!('Notification' in window)) {
    console.warn('Notifications non supportées par ce navigateur.');
    return;
  }

  // Vérifie que l'utilisateur a accepté les notifications
  if (Notification.permission === 'granted') {
    const options = {
      body: 'NOI Invoice Pro est installé et prêt à l\'emploi.',
      icon: './favicon.png',
      badge: './favicon.png',
      vibrate: [100, 50, 100],
      silent: false,
      data: {
        action: 'install-pwa',
        timestamp: Date.now(),
      },
      requireInteraction: true,
    };

    new Notification('NOI Invoice Pro', options)
      .then((notification) => {
        // Optionnel : cliquer sur la notification pour ouvrir l'app
        notification.onclick = () => {
          window.focus();
          window.open('./', '_self');
        };
      })
      .catch((err) => {
        console.warn('Échec de l\'affichage de la notification :', err);
      });
  } else {
    console.log('Autorisation de notification non accordée.');
  }
}

// Écouteur pour l'événement beforeinstallprompt
window.addEventListener('beforeinstallprompt', (event) => {
  // Empêche le comportement par défaut du navigateur
  event.preventDefault();
  // Stocke la promesse pour une utilisation ultérieure
  deferredPrompt = event;
  console.log('Invite d\'installation PWA disponible.');
});

// Écouteur pour l'événement appinstalled
window.addEventListener('appinstalled', (event) => {
  console.log('Application PWA installée :', event);
  // Déclenche une notification pour informer l'utilisateur
  showInstallNotification();
});

// Fonction pour enregistrer l'installation PWA manuellement
window.installPWA = () => {
  if (deferredPrompt) {
    deferredPrompt.prompt();
    deferredPrompt.userChoice.then((choice) => {
      if (choice.outcome === 'accepted') {
        console.log('Utilisateur a accepté l\'installation de l\'application.');
        deferredPrompt = null;
      } else {
        console.log('Utilisateur a refusé l\'installation.');
        deferredPrompt = null;
      }
    });
  } else {
    console.warn('Aucune invite d\'installation disponible.');
    // Fallback : afficher une notification si possible
    showInstallNotification();
  }
};

// Expose l'installation sur l'objet window pour le contrôle
window.addEventListener('load', () => {
  // Si l'application est déjà installée, on peut afficher une notification
  if (window.matchMedia('(display-mode: standalone)').matches ||
      window.navigator.standalone === true) {
    console.log('Application exécutée en mode standalone (installée).');
  }
});
'@

$content | Set-Content -Path "G:\futter_projets\noi_ohada_invoice_pro\web\register-sw.js" -Force -Encoding UTF8
Write-Host "register-sw.js créé."
