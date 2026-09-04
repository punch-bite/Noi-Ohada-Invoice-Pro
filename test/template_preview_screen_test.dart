// test/template_preview_screen_test.dart
//
// 🧪 Test de régression de l'aperçu de modèle (`TemplatePreviewScreen`) —
// refonte maquette Stitch « Aperçu de la facture » :
//   • AppBar : nom du modèle + sous-titre A4 (SYSCOHADA)
//   • Papier A4 fidèle à la maquette (`StitchA4InvoicePreview`) avec
//     tampon « PAYÉ » (données d'exemple payées)
//   • Contrôle de zoom +/− avec pourcentage
//   • Barre basse sombre : Éditer + Utiliser
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
      );

  testWidgets('L’aperçu A4 se construit sans débordement', (tester) async {
    // Grand écran (style tablette) pour laisser l'aperçu respirer.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp(sampleTemplate()));
    // Laisse _loadData (personnalisations sauvegardées) se terminer.
    await tester.pumpAndSettle();

    // Titre de l'en-tête = nom du modèle + sous-titre A4.
    expect(find.text('Classique Pro'), findsOneWidget);
    expect(find.text('Aperçu Format A4 (SYSCOHADA)'), findsOneWidget);

    // Contrôle de zoom présent (100 % au départ).
    expect(find.text('100%'), findsOneWidget);

    // Tampon « PAYÉ » rendu sur le papier (données d'exemple payées).
    expect(find.text('PAYÉ'), findsOneWidget);

    // Barre d'actions inférieure : Éditer + Utiliser.
    expect(find.text('Éditer'), findsOneWidget);
    expect(find.text('Utiliser'), findsOneWidget);

    // Structure du papier (maquette Stitch).
    expect(find.text('FACTURE'), findsOneWidget);
    expect(find.text('FACTURÉ À'), findsOneWidget);
    expect(find.text('MONTANT TOTAL'), findsOneWidget);
    expect(find.text('Termes et conditions'), findsOneWidget);

    // Aucune exception de layout (débordement) pendant le rendu.
    expect(tester.takeException(), isNull);
  });

  testWidgets('Le contrôle de zoom +/− ajuste le pourcentage',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp(sampleTemplate()));
    await tester.pumpAndSettle();

    // Échelle 1.0 au départ → « 100% ».
    expect(find.text('100%'), findsOneWidget);

    // 1er tap sur « + » → 110 %.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('110%'), findsOneWidget);

    // 2e tap → 120 %.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('120%'), findsOneWidget);

    // Deux taps sur « − » → retour à 100 %.
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
