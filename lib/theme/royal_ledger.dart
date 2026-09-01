// lib/theme/royal_ledger.dart
//
// 👑 DESIGN SYSTEM « Royal Ledger » (maquette Stitch — stitch_refined_billing_interface)
//
// Palette améthyste/or + typographies Manrope (titres) / Work Sans (labels) —
// refonte « Détail facture », « Boutique de modèles », « Aperçu » et
// « Personnalisation (drag & drop) ». Exposé en constantes pour être
// réutilisé sans dépendre du ThemeProvider Glass historique.
//
// Source : design/stitch_refined_billing_interface/**/code.html

import 'package:flutter/material.dart';

/// Couleurs « Royal Ledger » (mode clair, valeurs de la maquette).
class RoyalColors {
  RoyalColors._();

  // Surface / fonds
  static const Color surface = Color(0xFFfff7fc);
  static const Color surfaceDim = Color(0xFFe0d8de);
  static const Color surfaceBright = Color(0xFFfff7fc);
  static const Color surfaceContainerLowest = Color(0xFFffffff);
  static const Color surfaceContainerLow = Color(0xFFfaf1f8);
  static const Color surfaceContainer = Color(0xFFf4ebf2);
  static const Color surfaceContainerHigh = Color(0xFFeee6ec);
  static const Color surfaceContainerHighest = Color(0xFFe8e0e7);
  static const Color surfaceVariant = Color(0xFFe8e0e7);

  // Texte
  static const Color onSurface = Color(0xFF1e1a1f);
  static const Color onSurfaceVariant = Color(0xFF4c444e);

  // Inverse (barres sombres)
  static const Color inverseSurface = Color(0xFF332f34);
  static const Color inverseOnSurface = Color(0xFFf7eef5);

  // Primaire / améthyste
  static const Color primary = Color(0xFF300546);
  static const Color onPrimary = Color(0xFFffffff);
  static const Color primaryContainer = Color(0xFF471f5d);
  static const Color onPrimaryContainer = Color(0xFFb688cd);
  static const Color primaryFixed = Color(0xFFf6d9ff);
  static const Color primaryFixedDim = Color(0xFFe6b4fd);
  static const Color onPrimaryFixed = Color(0xFF2f0445);
  static const Color onPrimaryFixedVariant = Color(0xFF5e3674);
  static const Color inversePrimary = Color(0xFFe6b4fd);

  // Secondaire / mauve-gris
  static const Color secondary = Color(0xFF6b5773);
  static const Color onSecondary = Color(0xFFffffff);
  static const Color secondaryContainer = Color(0xFFf1d7f8);
  static const Color onSecondaryContainer = Color(0xFF6f5c78);
  static const Color secondaryFixed = Color(0xFFf4dafb);
  static const Color secondaryFixedDim = Color(0xFFd7bedf);
  static const Color onSecondaryFixed = Color(0xFF25152d);
  static const Color onSecondaryFixedVariant = Color(0xFF52405b);

  // Tertiaire / or
  static const Color tertiary = Color(0xFF6a5e28);
  static const Color onTertiary = Color(0xFFffffff);
  static const Color tertiaryContainer = Color(0xFFbaab6d);
  static const Color onTertiaryContainer = Color(0xFF493f0b);
  static const Color tertiaryFixed = Color(0xFFf3e29f);
  static const Color tertiaryFixedDim = Color(0xFFd6c686);
  static const Color onTertiaryFixed = Color(0xFF211b00);
  static const Color onTertiaryFixedVariant = Color(0xFF514613);

  // Erreur / statuts
  static const Color error = Color(0xFFba1a1a);
  static const Color onError = Color(0xFFffffff);
  static const Color errorContainer = Color(0xFFffdad6);
  static const Color onErrorContainer = Color(0xFF93000a);

  // Contours
  static const Color outline = Color(0xFF7d747f);
  static const Color outlineVariant = Color(0xFFcfc3cf);
}

/// Rayons « Royal Ledger ».
class RoyalRadius {
  RoyalRadius._();
  static const double sm = 4;
  static const double def = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double full = 9999;
}

/// Espacements « Royal Ledger » (grille 4px).
class RoyalSpacing {
  RoyalSpacing._();
  static const double unit = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double gutter = 12;
  static const double containerPadding = 20;
}

/// Styles de texte « Royal Ledger » (Manrope + Work Sans).
class RoyalText {
  RoyalText._();

  /// Titre de section / écran (Manrope 600, 20px).
  static TextStyle headlineMd(Color color) => TextStyle(
        fontFamily: 'Manrope',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: color,
      );

  /// Gros titre (Manrope 700, 24px, mobile).
  static TextStyle headlineLgMobile(Color color) => TextStyle(
        fontFamily: 'Manrope',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 32 / 24,
        color: color,
      );

  /// Corps principal (Work Sans 400, 14px).
  static TextStyle bodyMd(Color color) => TextStyle(
        fontFamily: 'WorkSans',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: color,
      );

  /// Corps secondaire (Work Sans 400, 16px).
  static TextStyle bodyLg(Color color) => TextStyle(
        fontFamily: 'WorkSans',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: color,
      );

  /// Libellé technique (Work Sans 600, 12px, MAJUSCULES, espacé).
  static TextStyle labelBold(Color color) => TextStyle(
        fontFamily: 'WorkSans',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 0.6,
        color: color,
      );

  /// Petit libellé (Work Sans 400, 11px).
  static TextStyle labelSm(Color color) => TextStyle(
        fontFamily: 'WorkSans',
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 14 / 11,
        color: color,
      );
}

/// Dégradés « Royal Ledger ».
class RoyalGradients {
  RoyalGradients._();

  static const LinearGradient royal = LinearGradient(
    colors: [Color(0xFF300546), Color(0xFF6C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gold = LinearGradient(
    colors: [Color(0xFFC9A227), Color(0xFFF3E29F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Ombres « Royal Ledger ».
class RoyalShadows {
  RoyalShadows._();

  static List<BoxShadow> card(bool isDark) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}

/// 🌗 Palette « Royal Ledger » adaptative (thème clair / sombre / système).
///
/// - [RoyalScheme.light] reprend EXACTEMENT les tokens de la maquette Stitch
///   (`design/stitch_refined_billing_interface/royal_ledger/DESIGN.md`).
/// - [RoyalScheme.dark] applique l'inversion tonale Material 3 de la même
///   palette améthyste/or (rôles 80/90 ↔ 30/10). Les rôles « fixed »
///   (`tertiaryFixed`, `tertiaryFixedDim`…) restent inchangés conformément
///   à la spécification M3.
///
/// Usage : `final c = RoyalScheme.of(context);` puis `c.secondary`, etc.
/// La résolution suit automatiquement le `themeMode` de l'application
/// (système / sombre / claire).
class RoyalScheme {
  final Color surface;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color surfaceVariant;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color inverseSurface;
  final Color inverseOnSurface;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color inversePrimary;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color tertiaryFixed;
  final Color tertiaryFixedDim;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color outline;
  final Color outlineVariant;

  const RoyalScheme({
    required this.surface,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.surfaceVariant,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.inverseSurface,
    required this.inverseOnSurface,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.inversePrimary,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.tertiaryFixed,
    required this.tertiaryFixedDim,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.outline,
    required this.outlineVariant,
  });

  /// Mode clair — valeurs exactes de la maquette.
  static const RoyalScheme light = RoyalScheme(
    surface: Color(0xFFFFF7FC),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFAF1F8),
    surfaceContainer: Color(0xFFF4EBF2),
    surfaceContainerHigh: Color(0xFFEEE6EC),
    surfaceContainerHighest: Color(0xFFE8E0E6),
    surfaceVariant: Color(0xFFE8E0E6),
    onSurface: Color(0xFF1E1A1F),
    onSurfaceVariant: Color(0xFF4C444E),
    inverseSurface: Color(0xFF332F34),
    inverseOnSurface: Color(0xFFF7EEF5),
    primary: Color(0xFF300546),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF471F5D),
    onPrimaryContainer: Color(0xFFB688CD),
    inversePrimary: Color(0xFFE6B4FD),
    secondary: Color(0xFF6B5773),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFF1D7F8),
    onSecondaryContainer: Color(0xFF6F5C78),
    tertiary: Color(0xFF6A5E28),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFBAAB6D),
    onTertiaryContainer: Color(0xFF493F0B),
    tertiaryFixed: Color(0xFFF3E29F),
    tertiaryFixedDim: Color(0xFFD6C686),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    outline: Color(0xFF7D747F),
    outlineVariant: Color(0xFFCFC3CF),
  );

  /// Mode sombre — inversion tonale M3 de la même palette.
  static const RoyalScheme dark = RoyalScheme(
    surface: Color(0xFF171216),
    surfaceContainerLowest: Color(0xFF120D13),
    surfaceContainerLow: Color(0xFF1E191E),
    surfaceContainer: Color(0xFF231D24),
    surfaceContainerHigh: Color(0xFF2E2830),
    surfaceContainerHighest: Color(0xFF39333B),
    surfaceVariant: Color(0xFF4C444E),
    onSurface: Color(0xFFE8E0E7),
    onSurfaceVariant: Color(0xFFCFC3CF),
    inverseSurface: Color(0xFFE8E0E7),
    inverseOnSurface: Color(0xFF332F34),
    primary: Color(0xFFE6B4FD),
    onPrimary: Color(0xFF521E6E),
    primaryContainer: Color(0xFF471F5D),
    onPrimaryContainer: Color(0xFFF6D9FF),
    inversePrimary: Color(0xFFE6B4FD),
    secondary: Color(0xFFD7BEDE),
    onSecondary: Color(0xFF392E40),
    secondaryContainer: Color(0xFF52405B),
    onSecondaryContainer: Color(0xFFF4DAFB),
    tertiary: Color(0xFFEFE07C),
    onTertiary: Color(0xFF251A00),
    tertiaryContainer: Color(0xFF514613),
    onTertiaryContainer: Color(0xFFF3E29F),
    tertiaryFixed: Color(0xFFF3E29F),
    tertiaryFixedDim: Color(0xFFD6C686),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    outline: Color(0xFF998D98),
    outlineVariant: Color(0xFF4C444E),
  );

  /// Palette correspondant à la luminosité courante du thème.
  static RoyalScheme of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}