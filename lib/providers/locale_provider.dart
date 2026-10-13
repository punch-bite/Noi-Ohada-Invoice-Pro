// lib/providers/locale_provider.dart
//
// Expose la langue sélectionnée à toute l'arbre de widgets (MaterialApp
// inclus) et notifie les listeners lors d'un changement. Reproduit le
// fonctionnement de ThemeProvider.
import 'package:flutter/material.dart';
import '../services/locale_service.dart';

class LocaleProvider extends ChangeNotifier {
  AppLanguage _currentLanguage = LocaleService.defaultLanguage;

  LocaleProvider() {
    _loadLanguage();
  }

  AppLanguage get currentLanguage => _currentLanguage;

  /// Locale Flutter courante.
  Locale get locale => _currentLanguage.locale;

  Future<void> _loadLanguage() async {
    _currentLanguage = LocaleService.getLanguage();
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_currentLanguage == language) return;
    _currentLanguage = language;
    await LocaleService.setLanguage(language);
    notifyListeners();
  }
}
