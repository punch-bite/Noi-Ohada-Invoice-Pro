// web/contact_picker.js
//
// 📇 Bridge JS robuste pour Contact Picker API.
// Retourne TOUJOURS une string JSON (jamais null).
//
(function () {
  'use strict';

  window.contactPickerIsSupported = function () {
    try {
      return (
        typeof navigator !== 'undefined' &&
        'contacts' in navigator &&
        'ContactsManager' in window &&
        typeof navigator.contacts.select === 'function'
      );
    } catch (e) {
      console.warn('⚠️ contactPickerIsSupported error:', e);
      return false;
    }
  };

  window.contactPickerSelect = function (properties) {
    return new Promise(function (resolve) {
      // 🛡️ Jamais de reject qui casse côté Dart. On retourne TOUJOURS
      //    une string JSON (vide en cas d'erreur).
      try {
        if (!window.contactPickerIsSupported()) {
          console.warn('⚠️ Contact Picker API non supportée');
          resolve('[]');
          return;
        }

        navigator.contacts
          .select(properties, { multiple: true })
          .then(function (contacts) {
            try {
              if (!Array.isArray(contacts)) {
                resolve('[]');
                return;
              }
              var mapped = contacts.map(function (c) {
                return {
                  name:
                    c && c.name && c.name.length > 0
                      ? String(c.name[0])
                      : c && c.displayName
                        ? String(c.displayName)
                        : '',
                  email:
                    c && c.email && c.email.length > 0
                      ? String(c.email[0])
                      : '',
                  tel:
                    c && c.tel && c.tel.length > 0
                      ? String(c.tel[0])
                      : '',
                };
              });
              resolve(JSON.stringify(mapped));
            } catch (innerErr) {
              console.warn('⚠️ Mapping contacts error:', innerErr);
              resolve('[]');
            }
          })
          .catch(function (err) {
            console.warn('⚠️ contacts.select rejected:', err);
            resolve('[]');
          });
      } catch (e) {
        console.warn('⚠️ contactPickerSelect exception:', e);
        resolve('[]');
      }
    });
  };
})();