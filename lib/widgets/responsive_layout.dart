// lib/widgets/responsive_layout.dart
//
// 🎨 Système responsive minimaliste.
// Ajuste automatiquement la mise en page à la taille d'écran :
//  - < 600px  (téléphone)   → dense, 1 colonne
//  - 600-1200 (tablette)    → grilles 2 colonnes
//  - > 1200px  (desktop)    → largeur max centrée, NavigationRail
//
import 'package:flutter/material.dart';

/// Breakpoints de l'application (cohérents avec Material 3).
class AppBreakpoints {
  static const double phone = 600;
  static const double tablet = 1200;

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < phone;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= phone &&
      MediaQuery.sizeOf(context).width < tablet;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
}

/// Widget utilitaire : applique un layout différent selon la taille d'écran.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
    this.desktop,
  });

  final Widget phone;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width;
    if (size >= AppBreakpoints.tablet && desktop != null) {
      return desktop!;
    }
    if (size >= AppBreakpoints.phone && tablet != null) {
      return tablet!;
    }
    return phone;
  }
}

/// Conteneur qui centre le contenu sur une largeur maximale (desktop).
/// Évite que les lignes deviennent illisibles sur les grands écrans.
class ConstrainedContent extends StatelessWidget {
  const ConstrainedContent({
    super.key,
    this.maxWidth = 1100,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  });

  final double maxWidth;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Grille responsive simple (colonnes adaptatives).
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.phoneColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  final List<Widget> children;
  final int phoneColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final int columns;
    if (width >= AppBreakpoints.tablet) {
      columns = desktopColumns;
    } else if (width >= AppBreakpoints.phone) {
      columns = tabletColumns;
    } else {
      columns = phoneColumns;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

/// Espaceur vertical standard minimaliste.
class Gap {
  static const SizedBox xs = SizedBox(height: 4);
  static const SizedBox sm = SizedBox(height: 8);
  static const SizedBox md = SizedBox(height: 16);
  static const SizedBox lg = SizedBox(height: 24);
  static const SizedBox xl = SizedBox(height: 40);
}
