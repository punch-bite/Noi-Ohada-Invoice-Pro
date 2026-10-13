// test/landing_slide_navigation_test.dart
//
// Navigation du carrousel de la landing page : bouton Â« slide prÃ©cÃ©dente Â»,
// points cliquables, flÃ¨ches clavier et Ã©tats dÃ©sactivÃ©s aux bornes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noi_ohada_invoice_pro/screens/landing/landing_screen.dart';

/// DurÃ©e d'une frame Â« longue Â» : couvre les animations d'entrÃ©e (420 ms)
/// et la transition du PageView (520 ms) en un seul pump.
const _frame = Duration(milliseconds: 600);

Future<void> _pumpLanding(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: const LandingScreen(),
    ),
  );
  await tester.pump(_frame);
}

/// Pump suffisant pour laisser la transition de page se terminer.
///
/// âš ï¸ Pas de `pumpAndSettle` ici : `_orbitController` est en `repeat()`
/// (animation perpÃ©tuelle), ce qui empÃªcherait tout settle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(_frame);
  await tester.pump(_frame);
}

void main() {
  testWidgets('la flÃ¨che retour est dÃ©sactivÃ©e sur la premiÃ¨re slide',
      (tester) async {
    await _pumpLanding(tester);

    final back = tester.widget<Semantics>(find.ancestor(
      of: find.byIcon(Icons.arrow_back_rounded),
      matching: find.byType(Semantics),
    ));

    expect(back.properties.enabled, isFalse);
  });

  testWidgets('avancer puis revenir en arriÃ¨re ramÃ¨ne sur le hÃ©ros',
      (tester) async {
    await _pumpLanding(tester);

    // Le hÃ©ros est prÃ©sent au dÃ©part.
    expect(find.text('simple & puissante.'), findsOneWidget);

    // Avance de 2 slides.
    await tester.tap(find.byKey(const Key('nav_next')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('nav_next')));
    await _settle(tester);

    // Le hÃ©ros a disparu : on est bien sur une slide de contenu.
    expect(find.text('simple & puissante.'), findsNothing);

    // Retour arriÃ¨re Ã— 2.
    await tester.tap(find.byKey(const Key('nav_back')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('nav_back')));
    await _settle(tester);

    // De retour sur le hÃ©ros.
    expect(find.text('simple & puissante.'), findsOneWidget);
  });

  testWidgets('la flÃ¨che retour se rÃ©active aprÃ¨s avoir avancÃ©',
      (tester) async {
    await _pumpLanding(tester);

    await tester.tap(find.byKey(const Key('nav_next')));
    await _settle(tester);

    final back = tester.widget<Semantics>(find.ancestor(
      of: find.byIcon(Icons.arrow_back_rounded),
      matching: find.byType(Semantics),
    ));

    expect(back.properties.enabled, isTrue);
  });

  testWidgets('le bouton retour est inerte sur la premiÃ¨re slide',
      (tester) async {
    await _pumpLanding(tester);

    // Tap sur une flÃ¨che dÃ©sactivÃ©e : rien ne doit bouger.
    await tester.tap(find.byKey(const Key('nav_back')));
    await _settle(tester);

    expect(find.text('simple & puissante.'), findsOneWidget);
  });

  testWidgets('la flÃ¨che droite du clavier avance la slide', (tester) async {
    await _pumpLanding(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _settle(tester);

    expect(find.text('simple & puissante.'), findsNothing);

    // Retour arriÃ¨re au clavier.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _settle(tester);

    expect(find.text('simple & puissante.'), findsOneWidget);
  });

  testWidgets('un point cliquÃ© amÃ¨ne directement Ã  sa slide', (tester) async {
    await _pumpLanding(tester);

    // Saut direct Ã  la 3e slide (index 2) â€” le carrousel en compte 6.
    await tester.tap(find.byKey(const Key('nav_dot_2')));
    await _settle(tester);

    // On a quittÃ© le hÃ©ros sans passer par les slides intermÃ©diaires.
    expect(find.text('simple & puissante.'), findsNothing);

    // Depuis l'index 2 on peut encore avancerâ€¦ et revenir.
    await tester.tap(find.byKey(const Key('nav_back')));
    await _settle(tester);
    expect(find.text('simple & puissante.'), findsNothing);

    await tester.tap(find.byKey(const Key('nav_back')));
    await _settle(tester);
    expect(find.text('simple & puissante.'), findsOneWidget);
  });

  testWidgets('la flÃ¨che suivante est dÃ©sactivÃ©e sur la derniÃ¨re slide',
      (tester) async {
    await _pumpLanding(tester);

    // Saut Ã  la derniÃ¨re slide (hÃ©ros + 5 fonctionnalitÃ©s = index 5).
    await tester.tap(find.byKey(const Key('nav_dot_5')));
    await _settle(tester);

    final next = tester.widget<Semantics>(find.ancestor(
      of: find.byIcon(Icons.arrow_forward_rounded),
      matching: find.byType(Semantics),
    ));

    expect(next.properties.enabled, isFalse);
  });
}
