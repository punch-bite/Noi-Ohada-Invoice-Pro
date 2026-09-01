// lib/models/invoice_layout.dart
//
// 📐 Layout par blocs avec grille de colonnes pour facture A4.
//
// Chaque élément est positionné dans un BLOC (header, client, items, totals, footer)
// et occupe 1 ou 2 colonnes sur une grille de 2 colonnes.
// Le snap automatique garantit l'alignement et évite les surprises en preview/impression.
//
// 🎨 NOUVEAU : chaque élément possède un style personnalisable (taille, poids,
// couleur, alignement, visibilité) pour un drag & drop WYSIWYG complet.

import 'package:flutter/material.dart';

/// Blocs de la facture (ordre vertical fixe).
enum LayoutBlock {
  header,
  client,
  items,
  totals,
  footer;

  String get label {
    switch (this) {
      case LayoutBlock.header:
        return 'En-tête';
      case LayoutBlock.client:
        return 'Client';
      case LayoutBlock.items:
        return 'Lignes';
      case LayoutBlock.totals:
        return 'Totaux';
      case LayoutBlock.footer:
        return 'Pied';
    }
  }
}

/// Éléments positionnables dans la facture.
enum LayoutElement {
  logo,
  companyName,
  companyAddress,
  companyPhone,
  companyEmail,
  invoiceTitle,
  clientName,
  clientAddress,
  clientPhone,
  clientEmail,
  itemsTable,
  subtotal,
  taxAmount,
  discount,
  totalAmount,
  footerText,
  legalMention,
  qrCode,
  signature;

  String get label {
    switch (this) {
      case LayoutElement.logo:
        return 'Logo';
      case LayoutElement.companyName:
        return 'Nom société';
      case LayoutElement.companyAddress:
        return 'Adresse société';
      case LayoutElement.companyPhone:
        return 'Tél société';
      case LayoutElement.companyEmail:
        return 'Email société';
      case LayoutElement.invoiceTitle:
        return 'Titre facture';
      case LayoutElement.clientName:
        return 'Nom client';
      case LayoutElement.clientAddress:
        return 'Adresse client';
      case LayoutElement.clientPhone:
        return 'Tél client';
      case LayoutElement.clientEmail:
        return 'Email client';
      case LayoutElement.itemsTable:
        return 'Tableau lignes';
      case LayoutElement.subtotal:
        return 'Sous-total';
      case LayoutElement.taxAmount:
        return 'TVA';
      case LayoutElement.discount:
        return 'Remise';
      case LayoutElement.totalAmount:
        return 'Total';
      case LayoutElement.footerText:
        return 'Texte pied';
      case LayoutElement.legalMention:
        return 'Mention légale';
      case LayoutElement.qrCode:
        return 'QR Code';
      case LayoutElement.signature:
        return 'Signature';
    }
  }

  LayoutBlock get block {
    switch (this) {
      case LayoutElement.logo:
      case LayoutElement.companyName:
      case LayoutElement.companyAddress:
      case LayoutElement.companyPhone:
      case LayoutElement.companyEmail:
      case LayoutElement.invoiceTitle:
        return LayoutBlock.header;
      case LayoutElement.clientName:
      case LayoutElement.clientAddress:
      case LayoutElement.clientPhone:
      case LayoutElement.clientEmail:
        return LayoutBlock.client;
      case LayoutElement.itemsTable:
        return LayoutBlock.items;
      case LayoutElement.subtotal:
      case LayoutElement.taxAmount:
      case LayoutElement.discount:
      case LayoutElement.totalAmount:
        return LayoutBlock.totals;
      case LayoutElement.footerText:
      case LayoutElement.legalMention:
      case LayoutElement.qrCode:
      case LayoutElement.signature:
        return LayoutBlock.footer;
    }
  }
}

/// 🎨 Style personnalisable d'un élément (WYSIWYG).
class ElementStyle {
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final TextAlign alignment;
  final bool visible;

  const ElementStyle({
    this.fontSize = 11.0,
    this.fontWeight = FontWeight.w400,
    this.color,
    this.alignment = TextAlign.left,
    this.visible = true,
  });

  ElementStyle copyWith({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    TextAlign? alignment,
    bool? visible,
  }) {
    return ElementStyle(
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      color: color ?? this.color,
      alignment: alignment ?? this.alignment,
      visible: visible ?? this.visible,
    );
  }

  Map<String, dynamic> toMap() => {
        'fontSize': fontSize,
        'fontWeight': fontWeight.value,
        'color': color?.toARGB32(),
        'alignment': alignment.index,
        'visible': visible,
      };

  factory ElementStyle.fromMap(Map<String, dynamic> map) {
    return ElementStyle(
      fontSize: ((map['fontSize'] as num?) ?? 11.0).toDouble(),
      fontWeight: _fontWeightFromInt((map['fontWeight'] as num?)?.toInt()),
      color: map['color'] != null ? Color(map['color'] as int) : null,
      alignment: TextAlign.values[(map['alignment'] as int?) ?? 0],
      visible: map['visible'] as bool? ?? true,
    );
  }

  /// Convertit une valeur sérialisée en [FontWeight].
  ///
  /// [toMap] stocke la **valeur** du poids (100–900) et non un index :
  /// les deux formats sont acceptés ici pour rester compatible avec
  /// d'éventuelles anciennes données indexées (0–8).
  static FontWeight _fontWeightFromInt(int? raw) {
    if (raw == null) return FontWeight.w400;
    if (raw >= 100) {
      return FontWeight.values.firstWhere(
        (w) => w.value == raw,
        orElse: () => FontWeight.w400,
      );
    }
    final index = raw.clamp(0, FontWeight.values.length - 1);
    return FontWeight.values[index];
  }
}

/// Position d'un élément dans son bloc.
class ElementPosition {
  final int blockIndex;
  final int column;
  final int colSpan;
  final int order;
  final bool visible;

  const ElementPosition({
    required this.blockIndex,
    required this.column,
    this.colSpan = 1,
    required this.order,
    this.visible = true,
  });

  ElementPosition copyWith({
    int? blockIndex,
    int? column,
    int? colSpan,
    int? order,
    bool? visible,
  }) {
    return ElementPosition(
      blockIndex: blockIndex ?? this.blockIndex,
      column: column ?? this.column,
      colSpan: colSpan ?? this.colSpan,
      order: order ?? this.order,
      visible: visible ?? this.visible,
    );
  }

  Map<String, dynamic> toMap() => {
        'blockIndex': blockIndex,
        'column': column,
        'colSpan': colSpan,
        'order': order,
        'visible': visible,
      };

  factory ElementPosition.fromMap(Map<String, dynamic> map) {
    return ElementPosition(
      blockIndex: map['blockIndex'] as int? ?? 0,
      column: map['column'] as int? ?? 0,
      colSpan: map['colSpan'] as int? ?? 1,
      order: map['order'] as int? ?? 0,
      visible: map['visible'] as bool? ?? true,
    );
  }
}

/// Configuration complète du layout d'une facture.
class InvoiceLayoutConfig {
  final Map<LayoutElement, ElementPosition> positions;
  final Map<LayoutElement, ElementStyle> styles;
  final double blockSpacing;
  final double pagePadding;

  const InvoiceLayoutConfig({
    required this.positions,
    this.styles = const {},
    this.blockSpacing = 12.0,
    this.pagePadding = 24.0,
  });

  ElementStyle styleOf(LayoutElement element) {
    return styles[element] ?? const ElementStyle();
  }

  InvoiceLayoutConfig withStyle(LayoutElement element, ElementStyle style) {
    final newStyles = Map<LayoutElement, ElementStyle>.of(styles);
    newStyles[element] = style;
    return copyWith(styles: newStyles);
  }

  InvoiceLayoutConfig withPosition(LayoutElement element, ElementPosition position) {
    final newPositions = Map<LayoutElement, ElementPosition>.of(positions);
    newPositions[element] = position;
    return copyWith(positions: newPositions);
  }

  factory InvoiceLayoutConfig.defaultLayout() {
    return InvoiceLayoutConfig(
      positions: {
        LayoutElement.logo: ElementPosition(blockIndex: 0, column: 0, order: 0),
        LayoutElement.companyName: ElementPosition(blockIndex: 0, column: 1, order: 1),
        LayoutElement.companyAddress: ElementPosition(blockIndex: 0, column: 1, order: 2),
        LayoutElement.companyPhone: ElementPosition(blockIndex: 0, column: 1, order: 3),
        LayoutElement.companyEmail: ElementPosition(blockIndex: 0, column: 1, order: 4),
        LayoutElement.invoiceTitle: ElementPosition(blockIndex: 0, column: 0, colSpan: 2, order: 5),
        LayoutElement.clientName: ElementPosition(blockIndex: 1, column: 0, colSpan: 2, order: 0),
        LayoutElement.clientAddress: ElementPosition(blockIndex: 1, column: 0, colSpan: 2, order: 1),
        LayoutElement.clientPhone: ElementPosition(blockIndex: 1, column: 0, order: 2),
        LayoutElement.clientEmail: ElementPosition(blockIndex: 1, column: 1, order: 2),
        LayoutElement.itemsTable: ElementPosition(blockIndex: 2, column: 0, colSpan: 2, order: 0),
        LayoutElement.subtotal: ElementPosition(blockIndex: 3, column: 1, order: 0),
        LayoutElement.taxAmount: ElementPosition(blockIndex: 3, column: 1, order: 1),
        LayoutElement.discount: ElementPosition(blockIndex: 3, column: 1, order: 2),
        LayoutElement.totalAmount: ElementPosition(blockIndex: 3, column: 1, order: 3),
        LayoutElement.footerText: ElementPosition(blockIndex: 4, column: 0, colSpan: 2, order: 0),
        LayoutElement.legalMention: ElementPosition(blockIndex: 4, column: 0, colSpan: 2, order: 2),
        LayoutElement.qrCode: ElementPosition(blockIndex: 4, column: 0, order: 1),
        LayoutElement.signature: ElementPosition(blockIndex: 4, column: 1, order: 1),
      },
      styles: {
        LayoutElement.companyName: const ElementStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w700,
        ),
        LayoutElement.invoiceTitle: const ElementStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.w800,
          alignment: TextAlign.center,
        ),
        LayoutElement.clientName: const ElementStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
        ),
        LayoutElement.totalAmount: const ElementStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w700,
        ),
      },
    );
  }

  InvoiceLayoutConfig copyWith({
    Map<LayoutElement, ElementPosition>? positions,
    Map<LayoutElement, ElementStyle>? styles,
    double? blockSpacing,
    double? pagePadding,
  }) {
    return InvoiceLayoutConfig(
      positions: positions ?? Map.of(this.positions),
      styles: styles ?? Map.of(this.styles),
      blockSpacing: blockSpacing ?? this.blockSpacing,
      pagePadding: pagePadding ?? this.pagePadding,
    );
  }

  Map<String, dynamic> toMap() => {
        'positions': {
          for (final e in positions.entries) e.key.name: e.value.toMap(),
        },
        'styles': {
          for (final e in styles.entries) e.key.name: e.value.toMap(),
        },
        'blockSpacing': blockSpacing,
        'pagePadding': pagePadding,
      };

  factory InvoiceLayoutConfig.fromMap(Map<String, dynamic> map) {
    final posMap = map['positions'] as Map<String, dynamic>? ?? {};
    final positions = <LayoutElement, ElementPosition>{};
    for (final entry in posMap.entries) {
      final element = LayoutElement.values.firstWhere(
        (e) => e.name == entry.key,
        orElse: () => LayoutElement.logo,
      );
      positions[element] = ElementPosition.fromMap(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }

    final styleMap = map['styles'] as Map<String, dynamic>? ?? {};
    final styles = <LayoutElement, ElementStyle>{};
    for (final entry in styleMap.entries) {
      final element = LayoutElement.values.firstWhere(
        (e) => e.name == entry.key,
        orElse: () => LayoutElement.logo,
      );
      styles[element] = ElementStyle.fromMap(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }

    InvoiceLayoutConfig.defaultLayout().positions.forEach(
          (element, position) => positions.putIfAbsent(element, () => position),
        );

    return InvoiceLayoutConfig(
      positions: positions,
      styles: styles,
      blockSpacing: (map['blockSpacing'] as num?)?.toDouble() ?? 12.0,
      pagePadding: (map['pagePadding'] as num?)?.toDouble() ?? 24.0,
    );
  }
}