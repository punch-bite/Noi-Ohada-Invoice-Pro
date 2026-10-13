// test/localizations_textfield_test.dart
//
// Régression : « Null check operator used on a null value » au clavier dans
// les formulaires (TextField / TextFormField).
//
// Cause racine : `MaterialApp` déclarait `locale: Locale('fr')` avec les
// delegates `DefaultMaterialLocalizations` / `DefaultWidgetsLocalizations`,
// qui ne supportent QUE `en_US`. En locale `fr`, `MaterialLocalizations` était
// donc `null`, et `EditableText` faisait `Localizations.of<MaterialLocalizations>(
// context)!` → crash au premier focus / frappe.
//
// Corrigé dans `lib/main.dart` avec les delegates `Global*`
// (flutter_localizations) qui couvrent fr + en.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noi_ohada_invoice_pro/l10n/app_localizations.dart';

/// Construit un MaterialApp strictement identique à celui de `lib/main.dart`
/// du point de vue de la localisation, mais avec des delegates injectables
/// pour pouvoir tester l'ancien (cassé) et le nouveau (corrigé).
Widget _harness({
  required Locale locale,
  required List<LocalizationsDelegate<dynamic>> delegates,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: delegates,
    home: Scaffold(
      body: Form(
        child: ListView(
          children: [
            TextFormField(key: const Key('email')),
            TextField(key: const Key('plain')),
            ElevatedButton(onPressed: () {}, child: const Text('OK')),
          ],
        ),
      ),
    ),
  );
}

/// Les delegates APRÈS correction (fr + en).
const _fixedDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'MaterialLocalizations est chargé en locale ${locale.languageCode} '
      '(delegates Global*)',
      (tester) async {
        await tester.pumpWidget(
          _harness(locale: locale, delegates: _fixedDelegates),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(TextFormField));
        expect(
          Localizations.of<MaterialLocalizations>(context, MaterialLocalizations),
          isNotNull,
          reason:
              'MaterialLocalizations ne doit jamais être null, sinon '
              'EditableText lève « Null check operator used on a null value ».',
        );
        expect(
          Localizations.of<WidgetsLocalizations>(context, WidgetsLocalizations),
          isNotNull,
        );
      },
    );

    testWidgets(
      'saisie clavier dans un TextFormField en locale '
      '${locale.languageCode} sans exception',
      (tester) async {
        await tester.pumpWidget(
          _harness(locale: locale, delegates: _fixedDelegates),
        );
        await tester.pumpAndSettle();

        // Le tap déclenche le focus → c'est là que l'ancien code plantait.
        await tester.tap(find.byKey(const Key('email')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('email')), 'facture@ohada.cg');
        await tester.pumpAndSettle();

        expect(find.text('facture@ohada.cg'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'saisie clavier dans un TextField brut en locale '
      '${locale.languageCode} sans exception',
      (tester) async {
        await tester.pumpWidget(
          _harness(locale: locale, delegates: _fixedDelegates),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('plain')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('plain')), 'OHADA 2026');
        await tester.pumpAndSettle();

        expect(find.text('OHADA 2026'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'les libellés de sélection (menu contextuel) sont disponibles en locale '
      '${locale.languageCode}',
      (tester) async {
        await tester.pumpWidget(
          _harness(locale: locale, delegates: _fixedDelegates),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(TextFormField));
        final l10n = Localizations.of<MaterialLocalizations>(
          context,
          MaterialLocalizations,
        )!;
        expect(l10n.selectAllButtonLabel, isNotEmpty);
        expect(l10n.pasteButtonLabel, isNotEmpty);
        expect(l10n.okButtonLabel, isNotEmpty);
      },
    );
  }

  // Preuve du bug : avec les anciens delegates, la locale non-anglaise n'est
  // PAS supportée → MaterialLocalizations absent → null-check dans EditableText.
  // (On interroge `isSupported` plutôt que de rendre l'arbre, car rendre
  // l'arbre cassé lève l'exception et fait échouer le test framework.)
  test(
    'RÉGRESSION DOCUMENTÉE : delegates Default* ne supportent que en_US',
    () {
      const fr = Locale('fr');
      const en = Locale('en');

      expect(
        DefaultMaterialLocalizations.delegate.isSupported(en),
        isTrue,
        reason: 'Default* gère uniquement en_US.',
      );
      expect(
        DefaultMaterialLocalizations.delegate.isSupported(fr),
        isFalse,
        reason:
            'En locale fr, Default* ne fournit aucun MaterialLocalizations, '
            'donc Localizations.of<MaterialLocalizations>(context)! dans '
            'EditableText lève « Null check operator used on a null value ».',
      );
      // En revanche DefaultWidgetsLocalizations accepte n'importe quelle
      // locale (simplification volontaire du framework) — ce n'est donc pas
      // lui le coupable ; seul le delegate Material est restrictif.
      expect(
        DefaultWidgetsLocalizations.delegate.isSupported(fr),
        isTrue,
        reason: 'DefaultWidgetsLocalizations accepte toute locale.',
      );
    },
  );

  // Le nouveau delegate, lui, couvre bien les deux locales de l'app.
  test(
    'delegates Global* supportent fr ET en',
    () {
      for (final locale in AppLocalizations.supportedLocales) {
        expect(GlobalMaterialLocalizations.delegate.isSupported(locale),
            isTrue);
        expect(GlobalWidgetsLocalizations.delegate.isSupported(locale), isTrue);
        expect(GlobalCupertinoLocalizations.delegate.isSupported(locale),
            isTrue);
        expect(AppLocalizations.delegate.isSupported(locale), isTrue);
      }
    },
  );
}
