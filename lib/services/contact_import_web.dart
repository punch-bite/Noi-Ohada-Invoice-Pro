// lib/services/contact_import_web_legacy.dart
//
// ⚠️ Version alternative utilisant dart:js (deprecated mais stable).
//
import 'dart:async';
import 'dart:convert';
// ignore: deprecated_member_use
import 'dart:js' as js;

import 'contact_import_types.dart';

bool webContactPickerSupported() {
  try {
    final nav = js.context['navigator'];
    return nav.hasProperty('contacts') &&
        nav['contacts'].hasProperty('select');
  } catch (_) {
    return false;
  }
}

Future<List<ImportedContactData>> pickContactsFromWeb({
  bool multiple = true,
}) async {
  if (!webContactPickerSupported()) {
    throw UnsupportedError(
      'Import de contacts disponible uniquement sur Chrome Android.',
    );
  }

  final completer = Completer<String>();

  // Appel JS avec callback.
  js.context.callMethod(r'$contactPickerSelectNative', [
    js.JsArray.from(['name', 'email', 'tel']),
    (String jsonStr) => completer.complete(jsonStr),
    (String err) => completer.completeError(Exception(err)),
  ]);

  final jsonStr = await completer.future;
  final List<dynamic> rawList = jsonDecode(jsonStr);

  return rawList.map<ImportedContactData>((item) {
    final map = item as Map<String, dynamic>;
    final name = (map['name'] as String?)?.trim() ?? '';
    final email = (map['email'] as String?)?.trim() ?? '';
    final tel = (map['tel'] as String?)?.trim() ?? '';

    return ImportedContactData(
      name: name.isNotEmpty ? name : 'Sans nom',
      phone: tel.isNotEmpty ? tel : null,
      email: email.isNotEmpty ? email : null,
    );
  }).toList();
}