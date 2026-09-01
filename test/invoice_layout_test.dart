// test/invoice_layout_test.dart
//
// Tests unitaires pour ElementPosition.visible et la sérialisation du layout.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noi_ohada_invoice_pro/models/invoice_layout.dart';

void main() {
  group('ElementPosition.visible', () {
    test('vaut true par défaut', () {
      const pos = ElementPosition(blockIndex: 0, column: 0, order: 0);
      expect(pos.visible, isTrue);
    });

    test('copyWith bascule la visibilité sans toucher aux autres champs', () {
      const pos = ElementPosition(
        blockIndex: 2,
        column: 1,
        colSpan: 2,
        order: 3,
      );
      final hidden = pos.copyWith(visible: false);

      expect(hidden.visible, isFalse);
      expect(hidden.blockIndex, 2);
      expect(hidden.column, 1);
      expect(hidden.colSpan, 2);
      expect(hidden.order, 3);
    });

    test('aller-retour toMap/fromMap préserve visible', () {
      const pos = ElementPosition(
        blockIndex: 4,
        column: 1,
        colSpan: 2,
        order: 5,
        visible: false,
      );
      final restored = ElementPosition.fromMap(pos.toMap());

      expect(restored.visible, isFalse);
      expect(restored.blockIndex, 4);
      expect(restored.column, 1);
      expect(restored.colSpan, 2);
      expect(restored.order, 5);
    });

    test('fromMap sans clé visible (données legacy) retombe sur true', () {
      final pos = ElementPosition.fromMap(const {
        'blockIndex': 1,
        'column': 0,
        'order': 2,
      });
      expect(pos.visible, isTrue);
    });
  });

  group('ElementStyle', () {
    test('aller-retour toMap/fromMap préserve le poids de police (w700)', () {
      const style = ElementStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w700,
      );
      final restored = ElementStyle.fromMap(style.toMap());

      expect(restored.fontWeight, FontWeight.w700);
      expect(restored.fontSize, 14.0);
    });

    test('aller-retour toMap/fromMap préserve w800', () {
      const style = ElementStyle(fontWeight: FontWeight.w800);
      expect(ElementStyle.fromMap(style.toMap()).fontWeight, FontWeight.w800);
    });

    test("fromMap accepte aussi l'ancien format index (0-8)", () {
      final style = ElementStyle.fromMap(const {'fontWeight': 6});
      expect(style.fontWeight, FontWeight.w700);
    });

    test('fromMap sans fontWeight retombe sur w400', () {
      final style = ElementStyle.fromMap(const {});
      expect(style.fontWeight, FontWeight.w400);
    });
  });

  group('InvoiceLayoutConfig', () {
    test('aller-retour toMap/fromMap conserve la visibilité des éléments', () {
      final config = InvoiceLayoutConfig.defaultLayout();
      final modified = config.withPosition(
        LayoutElement.qrCode,
        config.positions[LayoutElement.qrCode]!.copyWith(visible: false),
      );

      final restored = InvoiceLayoutConfig.fromMap(modified.toMap());

      expect(restored.positions[LayoutElement.qrCode]!.visible, isFalse);
      expect(restored.positions[LayoutElement.logo]!.visible, isTrue);
    });
  });
}
