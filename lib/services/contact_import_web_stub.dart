// lib/services/contact_import_web_stub.dart
//
// Stub pour plateformes NON-WEB (mobile, desktop).
// Le vrai code web est dans `contact_import_web.dart`.
//
import 'contact_import_types.dart';

/// Sur mobile, l'API Contact Picker web n'existe pas.
bool webContactPickerSupported() => false;

/// Ne sera jamais appelé sur mobile (garde d'usage côté UI).
Future<List<ImportedContactData>> pickContactsFromWeb({
  bool multiple = true,
}) async {
  throw UnsupportedError(
    'Contact Picker web non disponible sur cette plateforme.',
  );
}