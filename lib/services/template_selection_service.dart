// lib/services/template_selection_service.dart
//
// 📌 Mémorise le modèle de facture "actif" choisi par l'utilisateur.
// Stocké localement (SharedPreferences) → sélection persistante même hors-ligne.
//
import 'package:shared_preferences/shared_preferences.dart';

class TemplateSelectionService {
  static const String _key = 'active_template_id';

  /// Sauvegarde l'ID du modèle actif (null pour revenir au défaut).
  static Future<void> setActiveTemplateId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, id);
    }
  }

  /// Retourne l'ID du modèle actif (ou null si aucun choix).
  static Future<String?> getActiveTemplateId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }
}
