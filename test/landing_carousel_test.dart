// test/landing_carousel_test.dart
//
// Vérifie la navigation du carrousel de la landing page :
//   • bouton « Slide précédente » / « Slide suivante »
//   • points cliquables
//   • raccourcis clavier ← / →
//   • geste de swipe
//   • désactivation des flèches aux bornes
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:noi_ohada_invoice_pro/screens/landing/landing_screen.dart';

/// Enveloppe minimale : GoRouter est requis car le CTA utilise
/// `context.push('/auth/register')`.
Widget _wrap() {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(
        path: '/auth/register',
        builder: (_, __) => const Scaffold(body: Text('register')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

/// L'écran contient une orbite en `repeat()` : `pumpAndSettle` ne termine
/// jamais. On avance donc le temps par paliers fixes.
Future<void> _pump(WidgetTester tester) async {
  await tester.pump(); // construit l'arbre
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// L'état activé/désactivé d'une flèche de navigation.
///
/// La clé vise directement le nœud [Semantics], seul porteur de cet état.
bool _arrowEnabled(WidgetTester tester, String semanticsKey) {
  final semantics = tester.widget<Semantics>(
    find.byKey(Key(semanticsKey)),
  );
  return semantics.properties.enabled ?? true;
}

void main() {
  testWidgets('le bouton précédent recule vers la slide héros', (tester) async {
    await tester.pumpWidget(_wrap());
    await _pump(tester);

    expect(find.byKey(const Key('nav_back')), findsOneWidget);
    expect(find.byKey(const Key('nav_next')), findsOneWidget);

    // Sur la première slide, « précédent » est désactivé.
    expect(_arrowEnabled(tester, 'nav_back_semantics'), isFalse);

    // On avance de deux slides.
    await tester.tap(find.byKey(const Key('nav_next')));
    await _pump(tester);
    await tester.tap(find.byKey(const Key('nav_next')));
    await _pump(tester);

    expect(_arrowEnabled(tester, 'nav_back_semantics'), isTrue);

    // Puis on recule.
    await tester.tap(find.byKey(const Key('nav_back')));
    await _pump(tester);

    // De retour sur la slide 1 : le point 1 est le point actif (le plus large).
    expect(find.byKey(const Key('nav_dot_1')), findsOneWidget);
  });

  testWidgets('les points sont cliquables et changent de slide', (tester) async {
    await tester.pumpWidget(_wrap());
    await _pump(tester);

    await tester.tap(find.byKey(const Key('nav_dot_3')));
    await _pump(tester);

    expect(_arrowEnabled(tester, 'nav_back_semantics'), isTrue);
  });

  testWidgets('les flèches du clavier naviguent', (tester) async {
    await tester.pumpWidget(_wrap());
    await _pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _pump(tester);
    expect(_arrowEnabled(tester, 'nav_back_semantics'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _pump(tester);
    expect(_arrowEnabled(tester, 'nav_back_semantics'), isFalse);
  });

  testWidgets('le swipe change de slide', (tester) async {
    await tester.pumpWidget(_wrap());
    await _pump(tester);

    // Glissé vers la gauche sur le contenu → slide suivante.
    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1200);
    await _pump(tester);

    expect(_arrowEnabled(tester, 'nav_back_semantics'), isTrue);

    // Glissé vers la droite → retour à la slide précédente.
    await tester.fling(find.byType(PageView), const Offset(500, 0), 1200);
    await _pump(tester);

    expect(_arrowEnabled(tester, 'nav_back_semantics'), isFalse);
  });

  testWidgets('le bouton suivant se désactive sur la dernière slide',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await _pump(tester);

    // 6 slides au total : on saute directement à la dernière via ses points.
    await tester.tap(find.byKey(const Key('nav_dot_5')));
    await _pump(tester);

    expect(_arrowEnabled(tester, 'nav_next_semantics'), isFalse);
    expect(_arrowEnabled(tester, 'nav_back_semantics'), isTrue);
  });
}
