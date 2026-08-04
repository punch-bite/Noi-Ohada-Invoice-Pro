// lib/services/theme_service.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum AppTheme {
  light,
  dark,
  system,
}

class ThemeService {
  static const String _boxName = 'theme_preferences';
  static const String _themeKey = 'app_theme';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static AppTheme getThemeMode() {
    if (_box == null) return AppTheme.system;
    final value = _box!.get(_themeKey, defaultValue: 'system') as String;
    return AppTheme.values.firstWhere(
      (e) => e.toString() == value,
      orElse: () => AppTheme.system,
    );
  }

  static Future<void> setThemeMode(AppTheme theme) async {
    if (_box == null) {
      // Si la box n'est pas encore ouverte, on l'ouvre au vol
      await init();
    }
    if (_box != null) {
      await _box!.put(_themeKey, theme.toString());
    }
  }

    // ============================================================
  //  DESIGN SYSTEM — Marquee moderne "Glass + Indigo/Violet"
  //  Couleur primaire : Deep Indigo #2A2A72 → Violet #5B3B8C (dégradé)
  //  Accent premium   : Or cuivré #D4AF37
  // ============================================================

  /// Couleur primaire (dégradé indigo/violette) — ton clair
  static const Color primaryLight = Color(0xFF4338CA);
  static const Color primaryGradientEndLight = Color(0xFF7C3AED);
  /// Accent doré (marketing, badges premium, highlights)
  static const Color accentGold = Color(0xFFE9B949);
  /// Fond clair : très léger dégradé indigo
  static const Color bgLight = Color(0xFFF6F7FB);
  /// Fond sombre
  static const Color bgDark = Color(0xFF0E1117);
  static const Color surfaceDark = Color(0xFF161B26);
  static const Color surfaceDarkAlt = Color(0xFF1E2433);

  /// Typographie : hiérarchie raffinée sur la police Roboto (embarquée,
  /// fiable hors-ligne) avec graisses et espacements soignés.
  static TextStyle _displayLarge(Color color, {double size = 34}) => TextStyle(
        fontFamily: 'Roboto',
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.1,
        color: color,
      );

  // ===== THÈME CLAIR =====
  static ThemeData getLightTheme() {
    final primary = primaryLight;
    final gradientEnd = primaryGradientEndLight;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: bgLight,
      fontFamily: 'Roboto',
            colorScheme: ColorScheme.light(
        primary: primaryLight,
        secondary: gradientEnd,
        surface: Colors.white,
        error: Colors.redAccent,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: const Color(0xFF14161C),
        onError: Colors.white,
      ),
      // ===== Texte raffiné =====
      textTheme: TextTheme(
        displayLarge: _displayLarge(const Color(0xFF14161C)),
        headlineLarge: _displayLarge(const Color(0xFF14161C), size: 28),
        headlineMedium: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF14161C),
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF14161C),
        ),
        titleMedium: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1D24),
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF33373F),
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF5A5F6B),
          height: 1.45,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primary,
          letterSpacing: 0.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white.withValues(alpha: 0.72),
        foregroundColor: const Color(0xFF14161C),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF14161C),
        ),
      ),
      // ===== Cartes en "glassmorphisme" =====
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: Colors.white.withValues(alpha: 0.7),
        shadowColor: const Color(0xFF4338CA).withValues(alpha: 0.08),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: const BorderSide(color: primaryLight, width: 1.5),
          textStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            color: primary,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.85),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        labelStyle: TextStyle(
          color: const Color(0xFF14161C),
          fontWeight: FontWeight.w500,
          fontFamily: 'Roboto',
        ),
        hintStyle: TextStyle(color: Colors.grey[400], fontFamily: 'Roboto'),
        prefixIconColor: primary,
        suffixIconColor: primary,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey[200],
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.85),
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey[500],
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: const Color(0xFF14161C),
        contentTextStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }
            return Colors.grey[400]!;
          },
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }
            return Colors.grey[400]!;
          },
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }
            return Colors.grey[300]!;
          },
        ),
                trackColor: WidgetStateProperty.resolveWith<Color>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return primary.withValues(alpha: 0.5);
            }
            return Colors.grey[300]!;
          },
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primary.withValues(alpha: 0.15),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
    );
  }

    // ===== THÈME SOMBRE =====
  static ThemeData getDarkTheme() {
    final primary = const Color(0xFF7C6CF0);
    final gradientEnd = const Color(0xFF9A7BFF);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: bgDark,
      fontFamily: 'Roboto',
            colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: gradientEnd,
        surface: surfaceDark,
        error: const Color(0xFFFF6B6B),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onError: Colors.black,
      ),
      // ===== Texte raffiné =====
      textTheme: TextTheme(
        displayLarge: _displayLarge(Colors.white),
        headlineLarge: _displayLarge(Colors.white, size: 28),
        headlineMedium: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.92),
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.82),
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.6),
          height: 1.45,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primary,
          letterSpacing: 0.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgDark.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      // ===== Cartes en "glassmorphisme" sombre =====
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: surfaceDarkAlt.withValues(alpha: 0.6),
        shadowColor: Colors.black.withValues(alpha: 0.3),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: const BorderSide(color: Color(0xFF7C6CF0), width: 1.5),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7C6CF0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            color: Color(0xFF7C6CF0),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDarkAlt.withValues(alpha: 0.65),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C6CF0), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2),
        ),
        labelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontFamily: 'Roboto',
        ),
        hintStyle: TextStyle(color: Colors.grey[500], fontFamily: 'Roboto'),
        prefixIconColor: primary,
        suffixIconColor: primary,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgDark.withValues(alpha: 0.85),
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey[500],
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: const Color(0xFF1E2433),
        contentTextStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }
            return Colors.grey[600]!;
          },
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }
            return Colors.grey[600]!;
          },
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }
            return Colors.grey[600]!;
          },
        ),
                trackColor: WidgetStateProperty.resolveWith<Color>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return primary.withValues(alpha: 0.5);
            }
            return Colors.grey[700]!;
          },
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primary.withValues(alpha: 0.15),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
    );
  }

  static ThemeData getSystemTheme() {
    final brightness = WidgetsBinding.instance.window.platformBrightness;
    return brightness == Brightness.dark ? getDarkTheme() : getLightTheme();
  }

  static ThemeData getTheme(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return getLightTheme();
      case AppTheme.dark:
        return getDarkTheme();
      case AppTheme.system:
        return getSystemTheme();
    }
  }

  static String getThemeLabel(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return 'Clair';
      case AppTheme.dark:
        return 'Sombre';
      case AppTheme.system:
        return 'Système';
    }
  }

  static IconData getThemeIcon(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return Icons.light_mode;
      case AppTheme.dark:
        return Icons.dark_mode;
      case AppTheme.system:
        return Icons.settings_suggest;
    }
  }
}