// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// Services
import 'services/config_service.dart';
import 'services/logger_service.dart';
import 'services/permission_service.dart';
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

  debugPrint('🚀 === DÉMARRAGE APPLICATION ===');

  // ===== PERMISSIONS =====
  debugPrint('📱 Demande des permissions...');
  try {
    await PermissionService.requestPermissions();
  } catch (e) {
    debugPrint('⚠️ Permissions: $e');
  }

  // ===== CONFIGURATION =====
  debugPrint('⚙️ Configuration...');
  await ConfigService.init();
  await LoggerService.init();
  debugPrint('✅ Configuration OK');

  // ===== HIVE =====
  debugPrint('📦 Hive...');
  await HiveService.init();
  debugPrint('✅ Hive OK');

  // ===== FIREBASE =====
  debugPrint('🔥 Firebase...');
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
  debugPrint('✅ Firebase OK');

  // ===== FIRESTORE (NON BLOQUANT) =====
  debugPrint('☁️ Firestore (arrière-plan)...');
  FirestoreInitializer.initialize().catchError((e) {
    debugPrint('⚠️ Firestore init ignorée: $e');
  });
  debugPrint('✅ Firestore lancé en arrière-plan');

  // ===== SERVICES =====
  debugPrint('🛠️ Services...');
  
  // ⚠️ Les services doivent être déclarés AVANT d'être utilisés dans runApp
  final notificationService = NotificationService();
  final connectivityService = ConnectivityService();
  final stockService = StockService();
  final nochPayService = NochPayService();

  try {
    await Future.any([
      Future.wait([
        notificationService.init(),
        ReminderService().init(),
        stockService.init(),
        ThemeService.init(),
        SecurityService.init(),
        DatabaseService.init(),
      ]),
      Future.delayed(const Duration(seconds: 8)),
    ]);
    debugPrint('✅ Services OK (ou timeout)');
  } catch (e) {
    debugPrint('⚠️ Services: $e (continue)');
  }

  // ===== SUBSCRIPTION CHECKER =====
  debugPrint('🔄 SubscriptionChecker...');
  SubscriptionCheckerService().start().ignore();
  debugPrint('✅ SubscriptionChecker lancé');

  // ===== LANCEMENT =====
  debugPrint('🚀 Lancement de l\'application...');
  
  // ✅ Vérifier que tous les services sont passés correctement
  runApp(
    MyApp(
      notificationService: notificationService,
      connectivityService: connectivityService,
      stockService: stockService,
      nochPayService: nochPayService,
    ),
  );
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
        // 🔥 AUTH
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        
        // 🔥 SUBSCRIPTION (dépend de AUTH)
        ChangeNotifierProxyProvider<AppAuthProvider, SubscriptionProvider>(
          create: (context) => SubscriptionProvider(
            context.read<AppAuthProvider>(),
          ),
          update: (context, authProvider, previous) {
            if (previous != null) return previous;
            return SubscriptionProvider(authProvider);
          },
        ),
        
        // 🔥 AUTRES PROVIDERS
        ChangeNotifierProvider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: notificationService),
        ChangeNotifierProvider.value(value: connectivityService),
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