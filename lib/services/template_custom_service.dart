// lib/services/template_custom_service.dart
//
// 🧩 Sauvegarde les personnalisations d'un modèle (positions drag & drop,
// mapping des variables ET arrière-plan personnalisé) de façon locale,
// par modèle.
// Clé : template_custom_{templateId} → JSON {positions, mapping, background}
//
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 🖼️ Réglages d'arrière-plan personnalisés d'un modèle (par utilisateur).
///
/// Ces réglages sont sauvegardés LOCALEMENT (comme les positions/mapping)
/// et sont appliqués :
///   - dans l'aperçu du workspace (`template_workspace_screen.dart`)
///   - dans l'aperçu plein écran (`template_preview_screen.dart`)
///   - dans le PDF imprimé (`printing_service.dart`)
class TemplateBackgroundSettings {
  /// Image d'arrière-plan en base64 (vide = utiliser celle du modèle admin,
  /// ou aucune image si le modèle n'en a pas non plus).
  final String fileData;

  /// Type du fichier : 'jpeg' | 'png'.
  final String fileType;

  /// Opacité de l'arrière-plan (0.0 → 1.0).
  final double opacity;

  /// Flou (blur sigma en px, 0 = pas de flou).
  final double blur;

  /// Mode d'ajustement : 'fill' (remplir) | 'contain' (ajuster).
  final String fit;

  /// 🎨 Identifiant du fond préréglé sélectionné dans la palette
  /// (`template_background_palette.dart`). Vide = aucun préréglage.
  /// Une image personnalisée reste toujours prioritaire sur le préréglage.
  final String presetId;

  const TemplateBackgroundSettings({
    this.fileData = '',
    this.fileType = 'jpeg',
    this.opacity = 0.3,
    this.blur = 0,
    this.fit = 'fill',
    this.presetId = '',
  });

  bool get hasCustomImage => fileData.isNotEmpty;

  /// Un fond préréglé de la palette est sélectionné.
  bool get hasPreset => presetId.isNotEmpty;

  /// Crée une copie avec les champs modifiés.
  TemplateBackgroundSettings copyWith({
    String? fileData,
    String? fileType,
    double? opacity,
    double? blur,
    String? fit,
    String? presetId,
  }) {
    return TemplateBackgroundSettings(
      fileData: fileData ?? this.fileData,
      fileType: fileType ?? this.fileType,
      opacity: opacity ?? this.opacity,
      blur: blur ?? this.blur,
      fit: fit ?? this.fit,
      presetId: presetId ?? this.presetId,
    );
  }

  Map<String, dynamic> toMap() => {
        'fileData': fileData,
        'fileType': fileType,
        'opacity': opacity,
        'blur': blur,
        'fit': fit,
        'presetId': presetId,
      };

  factory TemplateBackgroundSettings.fromMap(Map<String, dynamic> map) {
    return TemplateBackgroundSettings(
      fileData: map['fileData'] as String? ?? '',
      fileType: map['fileType'] as String? ?? 'jpeg',
      opacity: ((map['opacity'] as num?) ?? 0.3).toDouble().clamp(0.0, 1.0),
      blur: ((map['blur'] as num?) ?? 0).toDouble().clamp(0.0, 20.0),
      fit: map['fit'] == 'contain' ? 'contain' : 'fill',
      presetId: map['presetId'] as String? ?? '',
    );
  }
}

class TemplateCustomService {
  static String _key(String templateId) => 'template_custom_$templateId';

  /// Sauvegarde les positions + mapping + arrière-plan d'un modèle.
  static Future<void> saveCustom(
    String templateId, {
    required Map<String, dynamic> positions,
    required Map<String, String> mapping,
    TemplateBackgroundSettings? background,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(templateId),
      jsonEncode({
        'positions': positions,
        'mapping': mapping,
        'background': (background ?? const TemplateBackgroundSettings())
            .toMap(),
      }),
    );
  }

  /// Charge les personnalisations d'un modèle (vides si aucune).
  static Future<
      ({
        Map<String, dynamic> positions,
        Map<String, String> mapping,
        TemplateBackgroundSettings background,
      })> loadCustom(String templateId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(templateId));
    if (raw == null || raw.isEmpty) {
      return (
        positions: <String, dynamic>{},
        mapping: <String, String>{},
        background: const TemplateBackgroundSettings(),
      );
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return (
        positions: Map<String, dynamic>.from(data['positions'] ?? const {}),
        mapping: Map<String, String>.from(data['mapping'] ?? const {}),
        background: data['background'] is Map
            ? TemplateBackgroundSettings.fromMap(
                Map<String, dynamic>.from(data['background'] as Map))
            : const TemplateBackgroundSettings(),
      );
    } catch (_) {
      return (
        positions: <String, dynamic>{},
        mapping: <String, String>{},
        background: const TemplateBackgroundSettings(),
      );
    }
  }

  /// Supprime les personnalisations d'un modèle.
  static Future<void> clearCustom(String templateId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(templateId));
  }
}
