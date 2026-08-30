// lib/services/customization_service.dart
//
// 🧾 Service léger de persistance locale de [CustomizationConfig].
//
// Le flow "sauver" de l'écran Aperçu sérialise la config choisie par
// l'utilisateur. On privilégie le stockage partagé (SharedPreferences) pour
// rester offline-first et non bloquer sur Firebase lors de l'aperçu.
//
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customization_config.dart';

class CustomizationService {
  CustomizationService._();
  static final CustomizationService instance = CustomizationService._();

  static const _kKey = 'customization_config_v1';

  /// Charge la dernière configuration enregistrée (ou les défauts).
  Future<CustomizationConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null || raw.isEmpty) {
        return CustomizationConfig.defaults;
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _fromMap(map);
    } catch (_) {
      return CustomizationConfig.defaults;
    }
  }

  /// Persiste la configuration courante.
  Future<void> save(CustomizationConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(_toMap(config)));
  }

  Map<String, dynamic> _toMap(CustomizationConfig c) => {
        'primary': c.primaryColor.toARGB32(),
        'background': c.backgroundColor.toARGB32(),
        'text': c.textColor.toARGB32(),
        'showLogo': c.showLogo,
        'showShadow': c.showShadow,
        'showPaidStamp': c.showPaidStamp,
        'showSignature': c.showSignature,
        'showPaymentTerms': c.showPaymentTerms,
        'fontFamily': c.fontFamily,
        'fontSizes': {
          for (final e in c.fontSizes.entries)
            e.key.name: e.value.value,
        },
      };

  CustomizationConfig _fromMap(Map<String, dynamic> m) {
    final fsMap = <FontSizeSection, FontSizeOption>{};
    final rawFs = m['fontSizes'] as Map<String, dynamic>? ?? {};
    for (final entry in rawFs.entries) {
      final section = FontSizeSection.values
          .firstWhere((s) => s.name == entry.key, orElse: () => FontSizeSection.title);
      final opt = FontSizeOption.values
          .firstWhere((o) => o.value == entry.value as int, orElse: () => FontSizeOption.medium);
      fsMap[section] = opt;
    }
    return CustomizationConfig(
      primaryColor: Color(m['primary'] as int? ?? CustomizationConfig.defaults.primaryColor.toARGB32()),
      backgroundColor: Color(m['background'] as int? ?? CustomizationConfig.defaults.backgroundColor.toARGB32()),
      textColor: Color(m['text'] as int? ?? CustomizationConfig.defaults.textColor.toARGB32()),
      fontSizes: fsMap,
      showLogo: m['showLogo'] as bool? ?? CustomizationConfig.defaults.showLogo,
      showShadow: m['showShadow'] as bool? ?? CustomizationConfig.defaults.showShadow,
      showPaidStamp: m['showPaidStamp'] as bool? ?? CustomizationConfig.defaults.showPaidStamp,
      showSignature: m['showSignature'] as bool? ?? CustomizationConfig.defaults.showSignature,
      showPaymentTerms: m['showPaymentTerms'] as bool? ?? CustomizationConfig.defaults.showPaymentTerms,
      fontFamily: m['fontFamily'] as String? ?? CustomizationConfig.defaults.fontFamily,
    );
  }
}
