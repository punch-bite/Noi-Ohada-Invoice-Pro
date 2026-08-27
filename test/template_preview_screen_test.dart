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

  /// Lit le pourcentage de zoom affiché dans la barre de zoom ("NN %").
  int zoomPercent(WidgetTester tester) {
    final label = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere(
          (d) => RegExp(r'^\d+ %$').hasMatch(d),
          orElse: () => '',
        );
    expect(label, isNotEmpty, reason: 'Le % de zoom devrait être affiché');
    return int.parse(label.replaceAll(' %', '').trim());
  }

  testWidgets('L’aperçu A4 se construit sans débordement', (tester) async {
    // Grand écran (style tablette) pour laisser l'aperçu zoomable respirer.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp(sampleTemplate()));
    // Laisse _loadData (company + personnalisations) se terminer.
    await tester.pumpAndSettle();

    // Titre + page rendue.
    expect(find.text('Aperçu - Classique Pro'), findsOneWidget);

    // Barre de zoom présente (moins, %, plus, ajuster, 100 %).
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.fit_screen_outlined), findsOneWidget);
    expect(find.byIcon(Icons.aspect_ratio), findsOneWidget);

    // Règle/coin stylisé (mesures) : le coin "A4".
    expect(find.text('A4'), findsOneWidget);

    // Un pourcentage de zoom est affiché.
    expect(zoomPercent(tester), greaterThan(0));

    // Aucune exception de layout (débordement) pendant le rendu.
    expect(tester.takeException(), isNull);
  });

  testWidgets('Les boutons de zoom changent le pourcentage affiché',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp(sampleTemplate()));
    await tester.pumpAndSettle();

    final initialPercent = zoomPercent(tester);

    // Zoom avant ×1,25 → le % augmente.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    final zoomInPercent = zoomPercent(tester);
    expect(zoomInPercent, greaterThan(initialPercent));

    // Zoom arrière ×0,8 → revient sous la valeur précédente.
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    final zoomOutPercent = zoomPercent(tester);
    expect(zoomOutPercent, lessThan(zoomInPercent));

    // "Ajuster" → revient à l'échelle de départ.
    await tester.tap(find.byIcon(Icons.fit_screen_outlined));
    await tester.pumpAndSettle();
    expect(zoomPercent(tester), initialPercent);

    expect(tester.takeException(), isNull);
  });
}
