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

  // Design system: encre botanique, ivoire clair et laiton discret.
  static const Color primaryLight = Color(0xFF176B58);
  static const Color primaryGradientEndLight = Color(0xFF3B8B73);
  static const Color accentGold = Color(0xFFC49A48);
  static const Color bgLight = Color(0xFFF4F6F2);
  static const Color bgDark = Color(0xFF111916);
  static const Color surfaceDark = Color(0xFF19231F);
  static const Color surfaceDarkAlt = Color(0xFF202D28);

  /// Titres Manrope, avec Work Sans pour le texte courant.
  static TextStyle _displayLarge(Color color, {double size = 34}) => TextStyle(
        fontFamily: 'Manrope',
        fontSize: size,
        fontWeight: FontWeight.w700,
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
      // Transparent : le fond glass global (GlassAppBackground) transparaît.
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.light(
        primary: primaryLight,
        secondary: gradientEnd,
        surface: const Color(0xFFFCFDFB),
        surfaceContainerHighest: const Color(0xFFE9EEE9),
        outline: const Color(0xFF78857E),
        outlineVariant: const Color(0xFFD8E0D9),
        error: const Color(0xFFB5473F),
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
          fontFamily: 'Manrope',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF14161C),
        ),
        titleLarge: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF14161C),
        ),
        titleMedium: TextStyle(
          fontFamily: 'WorkSans',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1D24),
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'WorkSans',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF33373F),
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'WorkSans',
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
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1D2923),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1D2923),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        color: const Color(0xFFFCFDFB),
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0xFF20372D).withValues(alpha: 0.06),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: 'WorkSans',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          side: const BorderSide(color: Color(0xFFB9CEC3), width: 1),
          textStyle: TextStyle(
            fontFamily: 'WorkSans',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
        fillColor: const Color(0xFFFCFDFB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD8E0D9), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryLight, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFB5473F), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFB5473F), width: 1.4),
        ),
        labelStyle: TextStyle(
          color: const Color(0xFF1D2923),
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
        backgroundColor: const Color(0xFFFCFDFB),
        selectedItemColor: primary,
        unselectedItemColor: const Color(0xFF78857E),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
    );
  }

  // ===== THÈME SOMBRE =====
  static ThemeData getDarkTheme() {
    const primary = Color(0xFF83C8AC);
    const gradientEnd = Color(0xFFC5AA69);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      // Transparent : le fond glass global (GlassAppBackground) transparaît.
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: gradientEnd,
        surface: surfaceDark,
        surfaceContainerHighest: surfaceDarkAlt,
        outline: const Color(0xFF91A198),
        outlineVariant: const Color(0xFF34433C),
        error: const Color(0xFFE9897F),
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
          fontFamily: 'Manrope',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontFamily: 'WorkSans',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.92),
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'WorkSans',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.82),
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'WorkSans',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.6),
          height: 1.45,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primary,
          letterSpacing: 0.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF0F4F0),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        color: surfaceDark,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.18),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: 'WorkSans',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          side: const BorderSide(color: Color(0xFF52675C), width: 1),
          textStyle: const TextStyle(
            fontFamily: 'WorkSans',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF83C8AC),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
        fillColor: surfaceDarkAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF34433C), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF83C8AC), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE9897F), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE9897F), width: 1.4),
        ),
        labelStyle: const TextStyle(
          color: Color(0xFFF0F4F0),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
    );
  }

  static ThemeData getSystemTheme() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
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
