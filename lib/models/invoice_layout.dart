// lib/models/invoice_layout.dart
//
// 📐 Layout par blocs avec grille de colonnes pour facture A4.
//
// Chaque élément est positionné dans un BLOC (header, client, items, totals, footer)
// et occupe 1 ou 2 colonnes sur une grille de 2 colonnes.
// Le snap automatique garantit l'alignement et évite les surprises en preview/impression.

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

/// Position d'un élément sur la grille.
class ElementPosition {
  /// Index du bloc (0=header, 1=client, 2=items, 3=totals, 4=footer).
  final int blockIndex;

  /// Colonne de départ (0 ou 1).
  final int column;

  /// Nombre de colonnes occupées (1 ou 2).
  final int colSpan;

  /// Ordre dans le bloc (0 = premier).
  final int order;

  /// Visibilité de l'élément.
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
  /// Positions des éléments.
  final Map<LayoutElement, ElementPosition> positions;

  /// Espacement vertical entre blocs (pixels).
  final double blockSpacing;

  /// Marge intérieure de la page (pixels).
  final double pagePadding;

  const InvoiceLayoutConfig({
    required this.positions,
    this.blockSpacing = 12.0,
    this.pagePadding = 24.0,
  });

  /// Layout par défaut équilibré.
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
    );
  }

  InvoiceLayoutConfig copyWith({
    Map<LayoutElement, ElementPosition>? positions,
    double? blockSpacing,
    double? pagePadding,
  }) {
    return InvoiceLayoutConfig(
      positions: positions ?? Map.of(this.positions),
      blockSpacing: blockSpacing ?? this.blockSpacing,
      pagePadding: pagePadding ?? this.pagePadding,
    );
  }

  Map<String, dynamic> toMap() => {
        'positions': {
          for (final e in positions.entries) e.key.name: e.value.toMap(),
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

    // 🔁 Compatibilité ascendante : les éléments absents d'une ancienne
    // personnalisation (ex : « Mention légale », ajoutée après coup) sont
    // réinjectés depuis le layout par défaut, à leur place d'origine.
    InvoiceLayoutConfig.defaultLayout().positions.forEach(
          (element, position) => positions.putIfAbsent(element, () => position),
        );

    return InvoiceLayoutConfig(
      positions: positions,
      blockSpacing: (map['blockSpacing'] as num?)?.toDouble() ?? 12.0,
      pagePadding: (map['pagePadding'] as num?)?.toDouble() ?? 24.0,
    );
  }
}
