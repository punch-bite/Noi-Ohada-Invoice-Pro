// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class ThemeProvider extends ChangeNotifier {
  AppTheme _currentTheme = AppTheme.system;

  ThemeProvider() {
    _loadTheme();
  }

  AppTheme get currentTheme => _currentTheme;
  ThemeData get themeData => ThemeService.getTheme(_currentTheme);

  bool get isDarkMode {
    if (_currentTheme == AppTheme.system) {
      return WidgetsBinding.instance.window.platformBrightness == Brightness.dark;
    }
    return _currentTheme == AppTheme.dark;
  }

  Future<void> _loadTheme() async {
    _currentTheme = ThemeService.getThemeMode();
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

  // ===== COULEURS DYNAMIQUES =====
  Color get primaryColor => isDarkMode 
      ? const Color(0xFF3949AB) 
      : const Color(0xFF1A237E);
  
  Color get secondaryColor => isDarkMode 
      ? const Color(0xFF5C6BC0) 
      : const Color(0xFF3949AB);
  
  Color get backgroundColor => isDarkMode 
      ? const Color(0xFF121212) 
      : const Color(0xFFF5F7FA);
  
  Color get cardColor => isDarkMode 
      ? const Color(0xFF1E1E1E) 
      : Colors.white;
  
  Color get textColor => isDarkMode 
      ? Colors.white 
      : const Color(0xFF1A1A1A);
  
  Color get subTextColor => isDarkMode 
      ? Colors.grey[400]! 
      : Colors.grey[600]!;
  
  Color get dividerColor => isDarkMode 
      ? Colors.grey[800]! 
      : Colors.grey[200]!;
  
  Color get inputFillColor => isDarkMode 
      ? const Color(0xFF2C2C2C) 
      : Colors.white;
  
  Color get inputBorderColor => isDarkMode 
      ? Colors.grey[700]! 
      : Colors.grey[200]!;
  
  Color get inputFocusedBorderColor => isDarkMode 
      ? const Color(0xFF3949AB) 
      : const Color(0xFF1A237E);
  
  Color get shadowColor => isDarkMode 
      ? Colors.black.withOpacity(0.3) 
      : Colors.black.withOpacity(0.05);
}