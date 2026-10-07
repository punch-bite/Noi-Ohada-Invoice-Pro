// lib/services/template_selection_service.dart
//
// CHANGELOG (v2) :
//   • Clé scopée par utilisateur Firebase UID : 'active_template_id_{uid}'
//     → deux utilisateurs sur le même appareil ne partagent plus leur
//       sélection de modèle.
//   • Migration automatique : l'ancienne clé globale 'active_template_id'
//     est lue en fallback et migrée vers la clé user-scoped au premier accès.
//   • API UNCHANGED : mêmes méthodes statiques, mêmes signatures.
//
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TemplateSelectionService {
  /// Clé historique (globale) — conservée pour migration.
  static const String _legacyKey = 'active_template_id';

  /// Clé scopée par utilisateur.
  static String _keyFor(String uid) => 'active_template_id_$uid';

  /// Retourne l'UID Firebase courant, ou une clé "anonyme" si non connecté.
  static String _currentUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '_anonymous';
    } catch (_) {
      return '_anonymous';
    }
  }

  /// Sauvegarde l'ID du modèle actif (null pour revenir au défaut).
  static Future<void> setActiveTemplateId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(_currentUid());
    if (id == null || id.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, id);
    }
  }

  /// Retourne l'ID du modèle actif (ou null si aucun choix).
  ///
  /// 🔄 Migration : si aucune valeur user-scoped n'existe mais qu'une valeur
  /// globale (ancienne clé) est présente, on la migre et on la supprime.
  static Future<String?> getActiveTemplateId() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _currentUid();
    final scopedKey = _keyFor(uid);

    // 1. Valeur user-scoped déjà présente → on la retourne.
    final scoped = prefs.getString(scopedKey);
    if (scoped != null && scoped.isNotEmpty) return scoped;

    // 2. Fallback : ancienne clé globale (migration one-shot).
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null && legacy.isNotEmpty) {
      // Migre vers la clé user-scoped et supprime l'ancienne.
      await prefs.setString(scopedKey, legacy);
      await prefs.remove(_legacyKey);
      return legacy;
    }

    return null;
  }

  /// 🧹 Purge la sélection pour l'utilisateur courant (appelé au logout).
  static Future<void> clearActiveTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(_currentUid()));
  }
}