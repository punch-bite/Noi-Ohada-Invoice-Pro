// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noi_ohada_invoice_pro/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:noi_ohada_invoice_pro/providers/auth_provider.dart';
import 'package:noi_ohada_invoice_pro/providers/theme_provider.dart';
import 'package:noi_ohada_invoice_pro/providers/subscription_provider.dart';
import 'package:noi_ohada_invoice_pro/services/notification_service.dart';
import 'package:noi_ohada_invoice_pro/services/connectivity_service.dart';

void main() {
  testWidgets('App starts with login screen', (WidgetTester tester) async {
    // Créer des mocks
    final notificationService = NotificationService();
    final connectivityService = ConnectivityService();

    // Construire l'app
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppAuthProvider()),
          ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
          ChangeNotifierProvider(create: (_) => notificationService),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => connectivityService),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Vérifier que l'écran de connexion est affiché
    expect(find.text('OHADA Invoice Pro'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('Login form has email and password fields', (WidgetTester tester) async {
    final notificationService = NotificationService();
    final connectivityService = ConnectivityService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppAuthProvider()),
          ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
          ChangeNotifierProvider(create: (_) => notificationService),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => connectivityService),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Vérifier la présence des champs
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}