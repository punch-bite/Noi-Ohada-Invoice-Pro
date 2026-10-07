window.$contactPickerSelectNative = function (properties, onSuccess, onError) {
  if (!window.contactPickerIsSupported()) {
    onError('API non supportée');
    return;
  }
  navigator.contacts.select(properties, { multiple: true })
    .then(contacts => {
      const mapped = contacts.map(c => ({
        name: c.name?.[0] || c.displayName || '',
        email: c.email?.[0] || '',
        tel: c.tel?.[0] || '',
      }));
      onSuccess(JSON.stringify(mapped));
    })
    .catch(err => onError(String(err)));
};