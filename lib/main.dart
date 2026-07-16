import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Services & Modèles
import '../services/config_service.dart';
import '../services/logger_service.dart';
import '../services/theme_service.dart';
import '../services/security_service.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../services/connectivity_service.dart';
import '../services/stock_service.dart';
import '../services/nochpay_service.dart'; // Import ajouté
import '../services/subscription_checker_service.dart';

import '../models/product.dart';
import '../models/delivery.dart';
import '../models/reminder.dart';
import '../models/invoice.dart'; // Import nécessaire pour l'adaptateur

import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/theme_provider.dart';
import '../router/app_router.dart';
import '../widgets/connectivity_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialisation synchrone
  await ConfigService.init();
  await LoggerService.init();
  // 2. Initialisation Hive
  await _initHive();

  // 3. Initialisation Firebase
  await _initFirebase();

  // 4. Initialisation services
  final notificationService = NotificationService();
  final connectivityService = ConnectivityService();
  final stockService = StockService();
  final nochPayService = NochPayService(); // Instanciation

  await Future.wait([
    notificationService.init(),
    ReminderService().init(),
    stockService.init(),
    ThemeService.init(),
    SecurityService.init(),
  ]);

  SubscriptionCheckerService().start().ignore();

  runApp(MyApp(
    notificationService: notificationService,
    connectivityService: connectivityService,
    stockService: stockService,
    nochPayService: nochPayService, // Injection
  ));
}

Future<void> _initHive() async {
  await Hive.initFlutter();

  // Enregistrement des adaptateurs (n'oubliez pas de générer invoice.g.dart)
  Hive.registerAdapter(ReminderAdapter());
  Hive.registerAdapter(ProductAdapter());
  Hive.registerAdapter(DeliveryAdapter());
  Hive.registerAdapter(InvoiceAdapter()); // Ajouté

  await Future.wait([
    Hive.openBox<Reminder>('reminders'),
    DatabaseService.init(),
  ]);
}

Future<void> _initFirebase() async {
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
  } catch (e) {
    await LoggerService.error('firebase_init_failed', details: e.toString());
  }
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
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: notificationService),
        ChangeNotifierProvider.value(value: connectivityService),
        Provider<StockService>.value(value: stockService),
        Provider<NochPayService>.value(
            value: nochPayService), // Injection sécurisée
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
            builder: (context, child) => ConnectivityWrapper(
              child: child ?? const SizedBox.shrink(),
              onRetry: () {},
            ),
          );
        },
      ),
    );
  }

  ThemeMode _getThemeMode(AppTheme theme) => switch (theme) {
        AppTheme.light => ThemeMode.light,
        AppTheme.dark => ThemeMode.dark,
        AppTheme.system => ThemeMode.system,
      };
}
