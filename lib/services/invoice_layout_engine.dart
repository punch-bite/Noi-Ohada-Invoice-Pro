// lib/services/invoice_layout_engine.dart
//
// 📐 Moteur de calcul pour le layout par blocs.
// Fournit les constantes A4 et les fonctions de snap-to-grid.
//
// Utilisé par TOUS les écrans (workspace, preview, impression) pour garantir
// une UI/UX cohérente sans décalage.

import '../models/invoice_layout.dart';

/// Constantes de la page A4 en pixels (à 96 DPI).
class A4Dimensions {
  /// Largeur A4 en pixels.
  static const double width = 794; // 210mm à 96 DPI

  /// Hauteur A4 en pixels.
  static const double height = 1123; // 297mm à 96 DPI

  /// Marge par défaut en pixels.
  static const double defaultMargin = 24.0;

  /// Nombre de colonnes de la grille.
  static const int columns = 2;

  /// Gouttière entre colonnes en pixels.
  static const double gutter = 12.0;

  /// Espacement entre blocs en pixels.
  static const double blockSpacing = 12.0;

  /// Taille d'une cellule de snap en pixels.
  static const double snapSize = 8.0;

  /// Largeur utile (entre les marges).
  static double usableWidth(double margin) => width - (margin * 2);

  /// Largeur d'une colonne.
  static double columnWidth(double margin) =>
      (usableWidth(margin) - gutter) / columns;
}

/// Moteur de layout pour les éléments de la facture.
class InvoiceLayoutEngine {
  final InvoiceLayoutConfig config;

  const InvoiceLayoutEngine(this.config);

  /// Calcule la largeur d'un élément selon son colSpan.
  double elementWidth(LayoutElement element) {
    final pos = config.positions[element];
    if (pos == null) return 0;
    final colW = A4Dimensions.columnWidth(config.pagePadding);
    if (pos.colSpan == 2) {
      return (colW * 2) + A4Dimensions.gutter;
    }
    return colW;
  }

  /// Calcule la position X d'un élément.
  double elementX(LayoutElement element) {
    final pos = config.positions[element];
    if (pos == null) return config.pagePadding;
    final colW = A4Dimensions.columnWidth(config.pagePadding);
    return config.pagePadding + (pos.column * (colW + A4Dimensions.gutter));
  }

  /// Retourne les éléments d'un bloc triés par ordre.
  List<LayoutElement> elementsInBlock(LayoutBlock block) {
    final index = block.index;
    final elements = config.positions.entries
        .where((e) => e.value.blockIndex == index && e.value.visible)
        .map((e) => e.key)
        .toList();
    elements.sort(
      (a, b) => config.positions[a]!.order.compareTo(config.positions[b]!.order),
    );
    return elements;
  }

  /// Retourne les éléments d'une rangée dans un bloc (même valeur d'ordre).
  List<LayoutElement> elementsInRow(LayoutBlock block, int rowOrder) {
    return elementsInBlock(block)
        .where((e) => config.positions[e]!.order == rowOrder)
        .toList();
  }

  /// Snap une position X sur la grille.
  double snapX(double x) {
    final colW = A4Dimensions.columnWidth(config.pagePadding);
    final snapUnit = colW / (colW / A4Dimensions.snapSize).round();
    return (x / snapUnit).round() * snapUnit;
  }

  /// Snap une position Y sur la grille.
  double snapY(double y) {
    final snapUnit = A4Dimensions.snapSize;
    return (y / snapUnit).round() * snapUnit;
  }

  /// Calcule la largeur de la zone de contenu pour le renderer.
  double get contentWidth => A4Dimensions.usableWidth(config.pagePadding);

  /// Calcule la hauteur de la zone de contenu.
  double get contentHeight => A4Dimensions.height - (config.pagePadding * 2);

  /// Retourne un résumé du layout pour debug.
  Map<String, dynamic> debugSummary() {
    return {
      'blockSpacing': config.blockSpacing,
      'pagePadding': config.pagePadding,
      'contentWidth': contentWidth,
      'contentHeight': contentHeight,
      'elements': config.positions.length,
    };
  }
}
