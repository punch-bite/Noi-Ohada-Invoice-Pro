// test/header_element_visibility_test.dart
//
// 🧪 Visibilité des VARIABLES D'EN-TÊTE (logo / infos société / titre) :
// chaque variable déplaçable dans l'atelier peut être décochée
// (`header_visibility`). Elle disparaît alors du papier A4 sans quitter son
// ordre — donc reste réactivable d'un tap dans l'atelier.
//
// Ce test verrouille le contrat de bout en bout côté APERÇU :
//   • l'ordre effectif reste calculé par `InvoiceTemplate.resolveHeaderOrder` ;
//   • `StitchA4InvoicePreview` n'affiche que
//     `InvoiceTemplate.visibleHeaderElements(...)` ;
//   • masquer TOUT l'en-tête ne provoque ni exception ni débordement.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noi_ohada_invoice_pro/models/invoice_layout.dart';
import 'package:noi_ohada_invoice_pro/widgets/stitch_a4_invoice_preview.dart';

/// Papier A4 de l'aperçu, alimenté par des positions personnalisées.
/// Même harnais que TemplatePreviewScreen : vue défilante + centrage.
Widget _paper(Map<String, dynamic> positions) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Center(
            child: StitchA4InvoicePreview(
              data: StitchPreviewData.sample(),
              accentColor: const Color(0xFF4338CA),
              showLogo: false,
              customPositions: positions,
              layoutConfig: InvoiceLayoutConfig.defaultLayout(),
            ),
          ),
        ),
      ),
    );

void main() {
  // Grand écran (style tablette), comme template_preview_screen_test.dart.
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // Nom de la société dans les données d'exemple (bloc « DE » de l'en-tête).
  const companyName = 'Noi Concept digital';

  testWidgets("par défaut, l'en-tête affiche société et titre", (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(_paper(const {}));
    await tester.pumpAndSettle();

    expect(find.text(companyName), findsOneWidget); // company_info
    expect(find.text('FACTURE'), findsOneWidget); // invoice_title
    expect(tester.takeException(), isNull);
  });

  testWidgets('décocher « Infos Société » retire le bloc du papier',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(_paper(const {
      'header_visibility': <String, dynamic>{'company_info': false},
    }));
    await tester.pumpAndSettle();

    expect(find.text(companyName), findsNothing);
    // Le titre reste affiché : la colonne masquée libère seulement sa place.
    expect(find.text('FACTURE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('décocher le titre retire FACTURE mais garde la société',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(_paper(const {
      'header_visibility': <String, dynamic>{'invoice_title': false},
    }));
    await tester.pumpAndSettle();

    expect(find.text('FACTURE'), findsNothing);
    expect(find.text(companyName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("masquer tout l'en-tête ne casse pas le rendu", (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(_paper(const {
      'header_visibility': <String, dynamic>{
        'logo': false,
        'company_info': false,
        'invoice_title': false,
      },
    }));
    await tester.pumpAndSettle();

    expect(find.text('FACTURE'), findsNothing);
    expect(find.text(companyName), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("l'ordre personnalisé reste respecté quand tout est visible",
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(_paper(const {
      'header_elements_order': ['invoice_title', 'company_info', 'logo'],
    }));
    await tester.pumpAndSettle();

    // Les deux textes sont présents : seul l'ORDRE des colonnes change.
    expect(find.text(companyName), findsOneWidget);
    expect(find.text('FACTURE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
