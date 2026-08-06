// lib/services/env_loader_io.dart
// Implémentation NATIVE (mobile/desktop) : lecture du fichier .env système.
//
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

/// Retourne le contenu brut du .env, ou null si introuvable.
Future<String?> loadEnvContent() async {
  try {
    // 1) Asset (si .env est déclaré dans pubspec assets)
    try {
      final data = await rootBundle.loadString('assets/.env');
      return data;
    } catch (_) {}
    // 2) Fichier système (dossier courant)
    final f = File('.env');
    if (f.existsSync()) {
      return f.readAsStringSync();
    }
    // 3) Chemin relatif parent (exécution depuis lib/)
    final alt = File('../.env');
    if (alt.existsSync()) {
      return alt.readAsStringSync();
    }
    return null;
  } catch (_) {
    return null;
  }
}
