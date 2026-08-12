// lib/providers/theme_provider.dart
// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class ThemeProvider extends ChangeNotifier {
  AppTheme _currentTheme = AppTheme.system;
  bool _isInitialized = false;

  ThemeProvider() {
    _loadTheme();
  }

  AppTheme get currentTheme => _currentTheme;
  ThemeData get themeData => ThemeService.getTheme(_currentTheme);

  bool get isDarkMode {
    if (_currentTheme == AppTheme.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _currentTheme == AppTheme.dark;
  }

  Future<void> _loadTheme() async {
    _currentTheme = ThemeService.getThemeMode();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    await ThemeService.setThemeMode(theme);
    notifyListeners();
  }

  void toggleTheme() {
    if (_currentTheme == AppTheme.light) {
      setTheme(AppTheme.dark);
    } else {
      setTheme(AppTheme.light);
    }
  }

  void setLightTheme() {
    setTheme(AppTheme.light);
  }

  void setDarkTheme() {
    setTheme(AppTheme.dark);
  }

  void setSystemTheme() {
    setTheme(AppTheme.system);
  }

    // ===== COULEURS DYNAMIQUES (design system Glass/Indigo) =====
  Color get primaryColor => isDarkMode
      ? const Color(0xFF7C6CF0)
      : const Color(0xFF4338CA);

  Color get secondaryColor => isDarkMode
      ? const Color(0xFF9A7BFF)
      : const Color(0xFF7C3AED);

  /// Extrémité du dégradé indigo → violet.
  Color get gradientEndColor => isDarkMode
      ? const Color(0xFF9A7BFF)
      : const Color(0xFF7C3AED);

  /// Accent doré (marketing, badges premium).
  Color get accentGold => const Color(0xFFE9B949);

  Color get backgroundColor => isDarkMode
      ? const Color(0xFF0E1117)
      : const Color(0xFFF6F7FB);

  Color get cardColor => isDarkMode
      ? const Color(0xFF1E2433)
      : Colors.white;

  Color get textColor => isDarkMode
      ? Colors.white
      : const Color(0xFF14161C);

  Color get subTextColor => isDarkMode
      ? (Colors.grey[400] ?? Colors.grey)
      : (Colors.grey[600] ?? Colors.grey);

  Color get dividerColor => isDarkMode
      ? const Color(0xFF2A2F3D)
      : (Colors.grey[200] ?? Colors.grey);

  Color get inputFillColor => isDarkMode
      ? const Color(0xFF1E2433)
      : Colors.white.withValues(alpha: 0.85);

  Color get inputBorderColor => isDarkMode
      ? Colors.white.withValues(alpha: 0.08)
      : (Colors.grey[200] ?? Colors.grey);

  Color get inputFocusedBorderColor => isDarkMode
      ? const Color(0xFF7C6CF0)
      : const Color(0xFF4338CA);

  Color get shadowColor => isDarkMode
      ? Colors.black.withValues(alpha: 0.3)
      : const Color(0xFF4338CA).withValues(alpha: 0.08);
}