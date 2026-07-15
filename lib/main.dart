// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:noi_ohada_invoice_pro/services/logger_service.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'router/app_router.dart';
import 'services/config_service.dart';
import 'services/reminder_service.dart';
import 'services/theme_service.dart';
import 'services/security_service.dart';
import 'services/connectivity_service.dart';
import 'services/stock_service.dart';
import 'services/database_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/subscription_checker_service.dart'; // 🔥 AJOUT
import 'models/product.dart';
import 'models/delivery.dart';
import 'providers/auth_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/theme_provider.dart';
import 'widgets/connectivity_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ConfigService.init();
  ConfigService.printConfig();

  try {
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
    print('✅ Firebase initialisé avec succès');
  } catch (e) {
    print('❌ Erreur Firebase: $e');
  }

  await Hive.initFlutter();

  // 🔥 ENREGISTRER LES ADAPTATEURS HIVE
  Hive.registerAdapter(ProductAdapter());
  Hive.registerAdapter(DeliveryAdapter());

  await DatabaseService.init();
  await ThemeService.init();
  await SecurityService.init();
  await LoggerService.init();

  // 🔥 INITIALISER LE SERVICE DE STOCK
  final stockService = StockService();
  await stockService.init();
  print('✅ StockService initialisé avec succès');

  final notificationService = NotificationService();
  await notificationService.init();
  final reminderService = ReminderService();
  await reminderService.init();
  final connectivityService = ConnectivityService();

  // 🔥 DÉMARRER LE SERVICE DE VÉRIFICATION DES ABONNEMENTS
  await SubscriptionCheckerService().start();

  runApp(MyApp(
    notificationService: notificationService,
    connectivityService: connectivityService,
    stockService: stockService,
  ));
}

class MyApp extends StatelessWidget {
  final NotificationService notificationService;
  final ConnectivityService connectivityService;
  final StockService stockService;

  const MyApp({
    super.key,
    required this.notificationService,
    required this.connectivityService,
    required this.stockService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => notificationService),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => connectivityService),
        Provider<StockService>.value(value: stockService),
      ],
      child: Consumer2<ThemeProvider, ConnectivityService>(
        builder: (context, themeProvider, connectivityService, child) {
          return MaterialApp.router(
            title: 'OHADA Invoice Pro',
            debugShowCheckedModeBanner: false,
            theme: ThemeService.getLightTheme(),
            darkTheme: ThemeService.getDarkTheme(),
            themeMode: _getThemeMode(themeProvider.currentTheme),
            routerConfig: AppRouter.router,
            builder: (context, child) {
              return ConnectivityWrapper(
                child: child!,
                onRetry: () {},
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
