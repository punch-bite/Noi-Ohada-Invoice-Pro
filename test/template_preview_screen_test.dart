// test/template_preview_screen_test.dart
//
// 🧪 Test de régression de l'aperçu de modèle (`TemplatePreviewScreen`).
// Vérifie que l'aperçu A4 zoomable (page + règles graduées + barre de zoom)
// se construit SANS débordement et que les contrôles de zoom réagissent.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noi_ohada_invoice_pro/models/invoice_template.dart';
import 'package:noi_ohada_invoice_pro/providers/auth_provider.dart';
import 'package:noi_ohada_invoice_pro/providers/theme_provider.dart';
import 'package:noi_ohada_invoice_pro/screens/customization/template_preview_screen.dart';
import 'package:noi_ohada_invoice_pro/services/config_service.dart';
import 'package:noi_ohada_invoice_pro/services/hive_service.dart';
import 'package:noi_ohada_invoice_pro/services/logger_service.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_firebase.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Cache Hive local (pattern des autres tests du projet).
    await HiveService.initForTest();
    await ConfigService.init();
    await LoggerService.init();
    // Fake Firebase Core → DatabaseService/Firestore/Auth constructibles
    // (aucun utilisateur → getCompany() retourne null sans requête).
    await setupFakeFirebaseForTests();
  });

  tearDownAll(() async {
    await HiveService.closeAllBoxes();
  });

  Widget buildApp(InvoiceTemplate template) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MaterialApp(
        home: TemplatePreviewScreen(template: template),
      ),
    );
  }

  /// Modèle avec positions drag & drop → chemin `_buildPositionedLayout`
  /// (page A4 + règles + zoom), le plus complexe.
  InvoiceTemplate sampleTemplate() => InvoiceTemplate(
        id: 'test-1',
        name: 'Classique Pro',
        description: 'Modèle de test',
        primaryColor: const Color(0xFF4338CA),
        textColor: const Color(0xFF111111),
        backgroundColor: const Color(0xFFFFFFFF),
        fontSize: 12,
        showLogo: false,
        showPaymentQR: true,
        positions: {
          'company_name': {'x': 0.05, 'y': 0.05, 'scale': 1.0, 'visible': true},
          'invoice_title': {'x': 0.62, 'y': 0.05, 'scale': 1.0, 'visible': true},
          'client_name': {'x': 0.05, 'y': 0.28, 'scale': 1.0, 'visible': true},
          'items': {'x': 0.05, 'y': 0.42, 'scale': 1.0, 'visible': true},
          'total_amount': {'x': 0.5, 'y': 0.82, 'scale': 1.0, 'visible': true},
          'footer': {'x': 0.05, 'y': 0.92, 'scale': 1.0, 'visible': true},
        },
      );

  /// Icône du bouton de zoom cyclique : `zoom_in` à l'échelle 1.0,
  /// `zoom_out` aux échelles supérieures (1.5 / 2.0).
  bool isZoomedIn(WidgetTester tester) =>
      find.byIcon(Icons.zoom_out).evaluate().isNotEmpty;

  testWidgets('L’aperçu A4 se construit sans débordement', (tester) async {
    // Grand écran (style tablette) pour laisser l'aperçu zoomable respirer.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp(sampleTemplate()));
    // Laisse _loadData (company + personnalisations) se terminer.
    await tester.pumpAndSettle();

    // Titre de l'en-tête (interface actuelle : « Détails Facture »).
    expect(find.text('Détails Facture'), findsOneWidget);

    // Bouton de zoom cyclique présent (icône zoom_in à l'échelle 1.0).
    expect(find.byIcon(Icons.zoom_in), findsOneWidget);

    // Filigrane « PAYÉ » rendu sur le papier.
    expect(find.text('PAYÉ'), findsOneWidget);

    // Barre d'actions inférieure : Éditer + Personnaliser.
    expect(find.text('Éditer'), findsOneWidget);
    expect(find.text('Personnaliser'), findsOneWidget);

    // Aucune exception de layout (débordement) pendant le rendu.
    expect(tester.takeException(), isNull);
  });

  testWidgets('Le bouton de zoom bascule l’icône (zoom cyclique)',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp(sampleTemplate()));
    await tester.pumpAndSettle();

    // Échelle 1.0 au départ → icône « zoom_in ».
    expect(find.byIcon(Icons.zoom_in), findsOneWidget);
    expect(isZoomedIn(tester), isFalse);

    // 1er tap → échelle 1.5 → icône « zoom_out ».
    await tester.tap(find.byIcon(Icons.zoom_in));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.zoom_out), findsOneWidget);
    expect(isZoomedIn(tester), isTrue);

    // 2e tap → échelle 2.0 (toujours « zoom_out »).
    await tester.tap(find.byIcon(Icons.zoom_out));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.zoom_out), findsOneWidget);

    // 3e tap → retour à l'échelle 1.0 → « zoom_in ».
    await tester.tap(find.byIcon(Icons.zoom_out));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.zoom_in), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
