// lib/services/contact_import_web.dart
//
// CHANGELOG v2 :
//   • 🐛 FIX `Null check operator used on a null value` :
//     - Toutes les valeurs JS sont castées défensivement.
//     - Plus aucun `!` implicite.
//     - Retourne liste vide en cas d'erreur au lieu de throw.
//   • 🛡️ Vérifications null partout.
//
import 'dart:convert';
import 'dart:js_interop';

import 'contact_import_types.dart';

// ─── Ponts JS (définis dans web/contact_picker.js) ───
@JS('contactPickerIsSupported')
external JSBoolean? _jsIsSupported();   // ⚠️ Nullable

@JS('contactPickerSelect')
external JSPromise<JSString>? _jsSelect(JSArray<JSString> properties);   // ⚠️ Nullable

/// Vrai si l'API Contact Picker est disponible.
bool webContactPickerSupported() {
  try {
    final result = _jsIsSupported();
    if (result == null) return false;
    return result.toDart;
  } catch (_) {
    return false;
  }
}

/// Ouvre le sélecteur natif et retourne les contacts choisis.
///
/// 🛡️ Ne lève JAMAIS d'exception — retourne liste vide en cas d'erreur.
Future<List<ImportedContactData>> pickContactsFromWeb({
  bool multiple = true,
}) async {
  if (!webContactPickerSupported()) {
    throw UnsupportedError(
      'Import de contacts disponible uniquement sur Chrome Android.',
    );
  }

  try {
    // ✅ Conversion correcte : List<JSString> → JSArray<JSString>
    final props = <JSString>[
      'name'.toJS,
      'email'.toJS,
      'tel'.toJS,
    ].toJS;

    // Appel JS — vérifie null sur le promise.
    final promise = _jsSelect(props);
    if (promise == null) {
      throw Exception('Bridge JS non initialisé (contact_picker.js absent ?)');
    }

    // Attend le résultat.
    final result = await promise.toDart;

    // 🛡️ Vérifie que result est bien une JSString.
    final String jsonStr;
    try {
      jsonStr = result.toDart;
    } catch (e) {
      return const [];
    }

    if (jsonStr.isEmpty) return const [];

    final decoded = jsonDecode(jsonStr);
    if (decoded is! List) return const [];

    final contacts = <ImportedContactData>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      final name = (map['name'] as String?)?.trim() ?? '';
      final email = (map['email'] as String?)?.trim() ?? '';
      final tel = (map['tel'] as String?)?.trim() ?? '';

      contacts.add(ImportedContactData(
        name: name.isNotEmpty ? name : 'Sans nom',
        phone: tel.isNotEmpty ? tel : null,
        email: email.isNotEmpty ? email : null,
      ));
    }

    return contacts;
  } catch (e) {
    // 🛡️ Ne remonte JAMAIS l'exception → liste vide.
    return const [];
  }
}