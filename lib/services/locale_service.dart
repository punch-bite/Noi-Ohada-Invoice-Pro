// lib/services/locale_service.dart
//
// Persistance de la langue choisie par l'utilisateur (même mécanisme que
// ThemeService : une Box Hive dédiée). Par défaut : français.
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Langues supportées par l'application.
enum AppLanguage {
  french('fr', 'Français', 'French'),
  english('en', 'English', 'Anglais');

  const AppLanguage(this.languageCode, this.nativeName, this.foreignName);

  /// Code de langue ISO 639-1 (utilisé pour construire le [Locale]).
  final String languageCode;

  /// Nom de la langue dans sa propre écriture (ex. « Français »).
  final String nativeName;

  /// Nom de la langue traduit dans l'autre langue (ex. « French » en anglais).
  final String foreignName;

  /// [Locale] Flutter correspondant.
  Locale get locale => Locale(languageCode);
}

class LocaleService {
  static const String _boxName = 'locale_preferences';
  static const String _languageKey = 'app_language';
  static Box? _box;

  /// Langue par défaut : français.
  static const AppLanguage defaultLanguage = AppLanguage.french;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// Langue actuellement sélectionnée (français si non configurée).
  static AppLanguage getLanguage() {
    if (_box == null) return defaultLanguage;
    final value = _box!.get(_languageKey, defaultValue: 'fr') as String;
    return fromCode(value);
  }

  /// Retrouve une [AppLanguage] à partir de son code, avec repli français.
  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (e) => e.languageCode == code,
      orElse: () => defaultLanguage,
    );
  }

  static Future<void> setLanguage(AppLanguage language) async {
    if (_box == null) {
      // Si la box n'est pas encore ouverte, on l'ouvre au vol.
      await init();
    }
    if (_box != null) {
      await _box!.put(_languageKey, language.languageCode);
    }
  }
}
