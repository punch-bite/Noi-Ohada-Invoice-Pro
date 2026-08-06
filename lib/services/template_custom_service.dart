// lib/services/template_custom_service.dart
//
// 🧩 Sauvegarde les personnalisations d'un modèle (positions drag & drop +
// mapping des variables) de façon locale, par modèle.
// Clé : template_custom_{templateId} → JSON {positions, mapping}
//
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TemplateCustomService {
  static String _key(String templateId) => 'template_custom_$templateId';

  /// Sauvegarde les positions + mapping personnalisés d'un modèle.
  static Future<void> saveCustom(
    String templateId, {
    required Map<String, dynamic> positions,
    required Map<String, String> mapping,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(templateId),
      jsonEncode({'positions': positions, 'mapping': mapping}),
    );
  }

  /// Charge les personnalisations d'un modèle (vide si aucune).
  static Future<({Map<String, dynamic> positions, Map<String, String> mapping})>
      loadCustom(String templateId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(templateId));
    if (raw == null || raw.isEmpty) {
      return (positions: <String, dynamic>{}, mapping: <String, String>{});
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return (
        positions: Map<String, dynamic>.from(data['positions'] ?? const {}),
        mapping: Map<String, String>.from(data['mapping'] ?? const {}),
      );
    } catch (_) {
      return (positions: <String, dynamic>{}, mapping: <String, String>{});
    }
  }

  /// Supprime les personnalisations d'un modèle.
  static Future<void> clearCustom(String templateId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(templateId));
  }
}
