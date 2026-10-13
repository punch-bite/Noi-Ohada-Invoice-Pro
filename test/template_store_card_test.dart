// test/template_store_card_test.dart
//
// Garde-fous visuels de la boutique de modèles (direction « épuré premium »).
//
// Ce qui est verrouillé ici :
//   1. la card de la boutique n'a AUCUNE bordure (l'élévation remplace le trait) ;
//   2. le champ de recherche n'a AUCUNE bordure, pas même au focus ;
//   3. l'aperçu n'a pas de radius inférieur (visuel encastré, coins hauts seuls) ;
//   4. les deux autres appelants de [TemplateThumbFrame] gardent leur rayon
//      symétrique par défaut (pas de régression sur les autres écrans).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noi_ohada_invoice_pro/models/invoice_template.dart';
import 'package:noi_ohada_invoice_pro/screens/customization/customization_ui.dart';
import 'package:noi_ohada_invoice_pro/screens/customization/template_store_screen.dart';

void main() {
  InvoiceTemplate buildTemplate() => InvoiceTemplate(
        id: 'tpl-1',
        name: 'Royal Ivory',
        description: 'Modèle premium',
        category: 'premium',
        price: 2500,
        rating: 4.8,
        primaryColor: const Color(0xFF300546),
        backgroundColor: const Color(0xFFFFF7FC),
        textColor: const Color(0xFF1E1A1F),
      );

  /// Enveloppe la card dans un thème neutre : [CustomPalette] lit le thème
  /// via `Theme.of`, donc on lui fournit un MaterialApp minimal.
  Widget host(Widget child) => MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(body: Center(child: child)),
      );

  group('Card de la boutique', () {
    testWidgets('ne porte aucune bordure', (tester) async {
      await tester.pumpWidget(host(StoreTemplateCard(
        template: buildTemplate(),
        isOwned: false,
      )));
      await tester.pump();

      final containers = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration is BoxDecoration);

      // La card extérieure est celle qui porte l'ombre d'élévation.
      final card = containers.firstWhere(
        (c) => (c.decoration as BoxDecoration).boxShadow != null,
      );
      final box = card.decoration as BoxDecoration;

      expect(box.border, isNull,
          reason: 'la séparation doit venir de l\'élévation, pas d\'un trait 1px');
    });

    testWidgets("porte une ombre d'élévation en remplacement du trait",
        (tester) async {
      await tester.pumpWidget(host(StoreTemplateCard(
        template: buildTemplate(),
        isOwned: false,
      )));
      await tester.pump();

      final card = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration is BoxDecoration)
          .map((c) => c.decoration as BoxDecoration)
          .firstWhere((d) => d.boxShadow != null);

      expect(card.boxShadow, isNotEmpty);
    });
  });

  group('Champ de recherche', () {
    testWidgets("aucune bordure à l'état de repos", (tester) async {
      await tester.pumpWidget(host(CustomSearchField(
        controller: TextEditingController(),
      )));
      await tester.pump();

      // La surface du champ est le seul Container avec un rayon plein (pill).
      final boxes = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.borderRadius != null)
          .toList();

      expect(boxes, isNotEmpty);
      for (final box in boxes) {
        expect(box.border, isNull,
            reason: 'la surface du champ ne doit porter aucun trait');
      }

      // Et la décoration du TextField n'en ajoute pas non plus.
      final decoration =
          tester.widget<TextField>(find.byType(TextField)).decoration!;
      expect(decoration.border, InputBorder.none);
      expect(decoration.enabledBorder, InputBorder.none);
      expect(decoration.focusedBorder, InputBorder.none);
    });

    testWidgets('reste sans bordure une fois le texte saisi', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(host(CustomSearchField(controller: controller)));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'royal');
      // Le suffixe « effacer » est animé (flutter_animate) : on laisse ses
      // timers se consommer pour ne pas les retrouver en fin de test.
      await tester.pump(const Duration(milliseconds: 200));

      final boxes = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.borderRadius != null)
          .toList();

      for (final box in boxes) {
        expect(box.border, isNull);
      }
      // Le bouton « effacer » apparaît bien, sans contour de champ.
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });

  group('TemplateThumbFrame', () {
    /// La décoration du frame porte le rayon : c'est elle qu'on inspecte.
    BorderRadius frameRadius(WidgetTester tester) {
      final decoration = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.borderRadius != null)
          .borderRadius!;
      return decoration as BorderRadius;
    }

    testWidgets('accepte des coins asymétriques (coins hauts seuls)',
        (tester) async {
      const radius = BorderRadius.vertical(top: Radius.circular(20));

      await tester.pumpWidget(host(TemplateThumbFrame(
        template: buildTemplate(),
        borderRadius: radius,
      )));
      await tester.pump();

      expect(frameRadius(tester), radius);

      // Le point clé : aucun arrondi en bas.
      expect(frameRadius(tester).bottomLeft, Radius.zero);
      expect(frameRadius(tester).bottomRight, Radius.zero);
      expect(frameRadius(tester).topLeft, const Radius.circular(20));
      expect(frameRadius(tester).topRight, const Radius.circular(20));
    });

    testWidgets('garde un rayon symétrique par défaut (pas de régression)',
        (tester) async {
      await tester.pumpWidget(host(TemplateThumbFrame(
        template: buildTemplate(),
      )));
      await tester.pump();

      // Comportement hérité : `radius` (12 par défaut) sur les quatre coins.
      expect(frameRadius(tester),
          const BorderRadius.all(Radius.circular(12)));
    });
  });
}
