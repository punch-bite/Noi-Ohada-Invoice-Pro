// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// Services
import 'services/config_service.dart';
import 'services/logger_service.dart';
import 'services/theme_service.dart';
import 'services/security_service.dart';
import 'services/database_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/reminder_service.dart';
import 'services/connectivity_service.dart';
import 'services/stock_service.dart';
import 'services/nochpay_service.dart';
import 'services/subscription_checker_service.dart';
import 'services/hive_service.dart';
import 'services/firestore_initializer.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/theme_provider.dart';

// Router & Widgets
import 'router/app_router.dart';
import 'widgets/connectivity_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ===== ÉTAPE 1 : Configuration =====
  await ConfigService.init();
  await LoggerService.init();

  // ===== ÉTAPE 2 : Hive (stockage local) =====
  await HiveService.init();

  // ===== ÉTAPE 3 : Firebase =====
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: ConfigService.firebaseApiKey,
      appId: ConfigService.firebaseAppId,
      messagingSenderId: ConfigService.firebaseMessagingSenderId,
      projectId: ConfigService.firebaseProjectId,
      authDomain: ConfigService.firebaseAuthDomain,
      storageBucket: ConfigService.firebaseStorageBucket,
    ),
  );

  // ===== ÉTAPE 4 : Initialisation Firestore (création des collections) =====
  await FirestoreInitializer.initialize();

  // ===== ÉTAPE 5 : Services =====
  final notificationService = NotificationService();
  final connectivityService = ConnectivityService();
  final stockService = StockService();
  final nochPayService = NochPayService();

  await Future.wait([
    notificationService.init(),
    ReminderService().init(),
    stockService.init(),
    ThemeService.init(),
    SecurityService.init(),
  ]);

  // DatabaseService.init() pour les éventuelles migrations ou vérifications
  await DatabaseService.init();

  // ===== ÉTAPE 6 : Vérificateur d'abonnements =====
  SubscriptionCheckerService().start().ignore();

  // ===== ÉTAPE 7 : Lancement de l'application =====
  runApp(MyApp(
    notificationService: notificationService,
    connectivityService: connectivityService,
    stockService: stockService,
    nochPayService: nochPayService,
  ));
}

class MyApp extends StatelessWidget {
  final NotificationService notificationService;
  final ConnectivityService connectivityService;
  final StockService stockService;
  final NochPayService nochPayService;

  const MyApp({
    super.key,
    required this.notificationService,
    required this.connectivityService,
    required this.stockService,
    required this.nochPayService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Providers avec ChangeNotifier
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: notificationService),
        ChangeNotifierProvider.value(value: connectivityService),
        
        // Services simples (sans notification)
        Provider<StockService>.value(value: stockService),
        Provider<NochPayService>.value(value: nochPayService),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: 'NOI OHADA Invoice Pro',
            debugShowCheckedModeBanner: false,
            theme: ThemeService.getLightTheme(),
            darkTheme: ThemeService.getDarkTheme(),
            themeMode: _getThemeMode(themeProvider.currentTheme),
            routerConfig: AppRouter.router,
            builder: (context, child) {
              return ConnectivityWrapper(
                onRetry: () {},
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }

  ThemeMode _getThemeMode(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return ThemeMode.light;
      case AppTheme.dark:
        return ThemeMode.dark;
      case AppTheme.system:
        return ThemeMode.system;
    }
  }
}