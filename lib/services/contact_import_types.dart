// lib/services/contact_import_types.dart
//
// Types partagés entre toutes les implémentations d'import de contacts.
//
class ImportedContactData {
  final String name;
  final String? phone;
  final String? email;

  const ImportedContactData({
    required this.name,
    this.phone,
    this.email,
  });

  bool get isUsable => name.trim().isNotEmpty;
}