// lib/widgets/invoice_renderer.dart
//
// 📐 Rendu unifié de la facture — utilisé par TOUS les écrans.
//
// Layout par grille 2 colonnes avec gestion du colSpan.
// Les éléments sont groupés par bloc et rangée.

import 'package:flutter/material.dart';
import '../models/invoice_layout.dart';
import '../services/invoice_layout_engine.dart';

/// Mode de rendu.
enum RenderMode { render, edit }

/// Callback appelé lors d'un drag & drop en mode edit.
typedef ElementMoveCallback = void Function(
  LayoutElement element,
  LayoutBlock targetBlock,
  int targetColumn,
  int targetOrder,
);

/// Widget de rendu unifié de la facture.
class InvoiceRenderer extends StatelessWidget {
  final InvoiceLayoutConfig config;
  final RenderMode mode;
  final ElementMoveCallback? onElementMoved;
  final Widget Function(BuildContext, LayoutElement, ElementPosition)? elementBuilder;

  /// Couleur d'accent utilisée pour le highlight DragTarget (mode edit).
  final Color dragAccentColor;

  const InvoiceRenderer({
    super.key,
    required this.config,
    this.mode = RenderMode.render,
    this.onElementMoved,
    this.elementBuilder,
    this.dragAccentColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: A4Dimensions.width,
      height: A4Dimensions.height,
      color: Colors.white,
      padding: EdgeInsets.all(config.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final block in LayoutBlock.values) ...[
            _buildBlock(context, block),
            if (block.index < LayoutBlock.values.length - 1)
              SizedBox(height: config.blockSpacing),
          ],
        ],
      ),
    );
  }

  Widget _buildBlock(BuildContext context, LayoutBlock block) {
    final engine = InvoiceLayoutEngine(config);
    final elements = engine.elementsInBlock(block);
    if (elements.isEmpty) return const SizedBox.shrink();

    final rows = <int, List<LayoutElement>>{};
    for (final element in elements) {
      final pos = config.positions[element]!;
      rows.putIfAbsent(pos.order, () => []).add(element);
    }

    final sortedOrders = rows.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final order in sortedOrders) ...[
          _buildRow(context, rows[order]!),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<LayoutElement> elements) {
    elements.sort(
      (a, b) => config.positions[a]!.column.compareTo(config.positions[b]!.column),
    );

    final colWidth = A4Dimensions.columnWidth(config.pagePadding);
    final gutter = A4Dimensions.gutter;
    final contentWidth = (colWidth * 2) + gutter;

    // Cas spécial: un seul élément en colSpan=2
    if (elements.length == 1 && config.positions[elements.first]!.colSpan == 2) {
      return _buildElement(context, elements.first, config.positions[elements.first]!, contentWidth);
    }

    // Séparer les éléments par colonne
    final col0Elements = elements.where((e) => config.positions[e]!.column == 0).toList();
    final col1Elements = elements.where((e) => config.positions[e]!.column == 1).toList();

    final col0Widget = col0Elements.isNotEmpty
        ? _buildElement(context, col0Elements.first, config.positions[col0Elements.first]!, colWidth)
        : const SizedBox();
    final col1Widget = col1Elements.isNotEmpty
        ? _buildElement(context, col1Elements.first, config.positions[col1Elements.first]!, colWidth)
        : const SizedBox();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: colWidth, child: col0Widget),
        SizedBox(width: gutter),
        SizedBox(width: colWidth, child: col1Widget),
      ],
    );
  }

  Widget _buildElement(BuildContext context, LayoutElement element, ElementPosition pos, double width) {
    final child = elementBuilder != null
        ? elementBuilder!(context, element, pos)
        : _defaultElement(element);

    final widget = SizedBox(width: width, child: child);

    if (mode == RenderMode.edit) {
      return Draggable<LayoutElement>(
        data: element,
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(width: width * 0.8, child: widget),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: widget),
        child: DragTarget<LayoutElement>(
          onAcceptWithDetails: (details) {
            onElementMoved?.call(
              details.data,
              LayoutBlock.values[pos.blockIndex],
              pos.column,
              pos.order,
            );
          },
          builder: (context, candidateData, rejectedData) {
            return Container(
              decoration: BoxDecoration(
                border: candidateData.isNotEmpty
                    ? Border.all(color: dragAccentColor, width: 2)
                    : Border.all(color: Colors.transparent, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: widget,
            );
          },
        ),
      );
    }

    return widget;
  }

  Widget _defaultElement(LayoutElement element) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        element.label,
        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
      ),
    );
  }
}
