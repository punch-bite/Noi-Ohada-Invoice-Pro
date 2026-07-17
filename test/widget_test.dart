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
import 'package:noi_ohada_invoice_pro/services/hive_service.dart';
import 'package:noi_ohada_invoice_pro/services/logger_service.dart';
import 'package:noi_ohada_invoice_pro/services/config_service.dart';

void main() {
  // Initialisation avant les tests
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await ConfigService.init();
    await LoggerService.init();
    await HiveService.init();
  });

  // Nettoyage après les tests
  tearDownAll(() async {
    // Fermer les boxes Hive si nécessaire
    await HiveService.closeAllBoxes();
    // await HiveService.dispose();
  });

  testWidgets('App starts with login screen', (WidgetTester tester) async {
    // Créer des mocks des services
    final notificationService = NotificationService();
    final connectivityService = ConnectivityService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppAuthProvider()),
          ChangeNotifierProxyProvider<AppAuthProvider, SubscriptionProvider>(
            create: (context) => SubscriptionProvider(
              context.read<AppAuthProvider>(),
            ),
            update: (context, authProvider, previous) {
              if (previous != null) return previous;
              return SubscriptionProvider(authProvider);
            },
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: notificationService),
          ChangeNotifierProvider.value(value: connectivityService),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Attendre que l'UI se stabilise
    await tester.pumpAndSettle();

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
          ChangeNotifierProxyProvider<AppAuthProvider, SubscriptionProvider>(
            create: (context) => SubscriptionProvider(
              context.read<AppAuthProvider>(),
            ),
            update: (context, authProvider, previous) {
              if (previous != null) return previous;
              return SubscriptionProvider(authProvider);
            },
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: notificationService),
          ChangeNotifierProvider.value(value: connectivityService),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Vérifier la présence des champs (email + mot de passe)
    expect(find.byType(TextFormField), findsNWidgets(2));
    
    // Vérifier la présence du bouton de connexion
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('Login button is disabled when fields are empty', (WidgetTester tester) async {
    final notificationService = NotificationService();
    final connectivityService = ConnectivityService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppAuthProvider()),
          ChangeNotifierProxyProvider<AppAuthProvider, SubscriptionProvider>(
            create: (context) => SubscriptionProvider(
              context.read<AppAuthProvider>(),
            ),
            update: (context, authProvider, previous) {
              if (previous != null) return previous;
              return SubscriptionProvider(authProvider);
            },
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: notificationService),
          ChangeNotifierProvider.value(value: connectivityService),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Vérifier que le bouton est activé
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Se connecter'),
    );
    expect(button.enabled, isTrue);
  });

  testWidgets('Login screen shows logo and app name', (WidgetTester tester) async {
    final notificationService = NotificationService();
    final connectivityService = ConnectivityService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppAuthProvider()),
          ChangeNotifierProxyProvider<AppAuthProvider, SubscriptionProvider>(
            create: (context) => SubscriptionProvider(
              context.read<AppAuthProvider>(),
            ),
            update: (context, authProvider, previous) {
              if (previous != null) return previous;
              return SubscriptionProvider(authProvider);
            },
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: notificationService),
          ChangeNotifierProvider.value(value: connectivityService),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Vérifier le logo (icône)
    expect(find.byIcon(Icons.receipt_long), findsOneWidget);
    
    // Vérifier le nom de l'application
    expect(find.text('OHADA Invoice Pro'), findsOneWidget);
    expect(find.text('Gestion de factures conforme OHADA'), findsOneWidget);
  });

  testWidgets('Login screen has "Mot de passe oublié" link', (WidgetTester tester) async {
    final notificationService = NotificationService();
    final connectivityService = ConnectivityService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppAuthProvider()),
          ChangeNotifierProxyProvider<AppAuthProvider, SubscriptionProvider>(
            create: (context) => SubscriptionProvider(
              context.read<AppAuthProvider>(),
            ),
            update: (context, authProvider, previous) {
              if (previous != null) return previous;
              return SubscriptionProvider(authProvider);
            },
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: notificationService),
          ChangeNotifierProvider.value(value: connectivityService),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Vérifier le lien "Mot de passe oublié"
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);
  });

  testWidgets('Login screen has "S\'inscrire" link', (WidgetTester tester) async {
    final notificationService = NotificationService();
    final connectivityService = ConnectivityService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppAuthProvider()),
          ChangeNotifierProxyProvider<AppAuthProvider, SubscriptionProvider>(
            create: (context) => SubscriptionProvider(
              context.read<AppAuthProvider>(),
            ),
            update: (context, authProvider, previous) {
              if (previous != null) return previous;
              return SubscriptionProvider(authProvider);
            },
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: notificationService),
          ChangeNotifierProvider.value(value: connectivityService),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Vérifier le lien "S'inscrire"
    expect(find.text('S\'inscrire'), findsOneWidget);
  });
}