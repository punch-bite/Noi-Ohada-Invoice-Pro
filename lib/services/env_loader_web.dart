// lib/services/env_loader_web.dart
// Implémentation WEB : pas de système de fichiers, asset uniquement.
//
import 'package:flutter/services.dart' show rootBundle;

Future<String?> loadEnvContent() async {
  try {
    return await rootBundle.loadString('assets/.env');
  } catch (_) {
    return null;
  }
}
