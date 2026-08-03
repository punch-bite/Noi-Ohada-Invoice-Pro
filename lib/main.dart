import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:noi_ohada_invoice_pro/services/sync_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// Services
import 'services/config_service.dart';
import 'services/logger_service.dart';
import 'services/permission_service.dart';
import 'services/theme_service.dart';
import 'services/security_service.dart';
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
import 'widgets/app_bootstrap.dart';

// 📝 Fonction de log vers un fichier
Future<void> _writeLog(String message) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/app_log.txt');
    await file.writeAsString('${DateTime.now()}: $message\n',
        mode: FileMode.append);
  } catch (_) {}
}

/// Services créés lors de l'initialisation (globales pour être partagées)
NotificationService? gNotificationService;
ConnectivityService? gConnectivityService;
StockService? gStockService;
NochPayService? gNochPayService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ⚠️ À placer en tout premier

  // NB : on N'attend plus AUCUNE initialisation lourde ici.
  // On appelle runApp immédiatement, l'écran de démarrage (splash)
  // gère toutes les initialisations en arrière-plan de manière non-bloquante.
  runApp(
    AppBootstrap(
      onReady: _initServices,
      child: const MyAppHost(),
    ),
  );
}

/// Host qui construit MyApp avec les services disponibles.
/// Les services sont créés pendant l'initialisation du splash.
class MyAppHost extends StatelessWidget {
  const MyAppHost({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationService = gNotificationService ?? NotificationService();
    final connectivityService = gConnectivityService ?? ConnectivityService();
    final stockService = gStockService ?? StockService();
    final nochPayService = gNochPayService ?? NochPayService();

    return MyApp(
      notificationService: notificationService,
      connectivityService: connectivityService,
      stockService: stockService,
      nochPayService: nochPayService,
    );
  }
}

/// Initialisation "best-effort" de tous les services.
/// Chaque étape est protégée par un try/catch individuel, de sorte qu'une
/// erreur ne bloque JAMAIS l'affichage de l'application.
Future<void> _initServices(AppBootstrapContext bootstrapContext) async {
  await _writeLog('🚀 === DÉMARRAGE APPLICATION ===');

  // ===== PERMISSIONS =====
  bootstrapContext.onStatusChange('Demande des permissions...');
  await _writeLog('📱 Demande des permissions...');
  try {
    await PermissionService.requestPermissions();
    await _writeLog('✅ Permissions OK');
  } catch (e) {
    await _writeLog('⚠️ Permissions: $e');
  }

  // ===== CONFIGURATION =====
  bootstrapContext.onStatusChange('Configuration...');
  await _writeLog('⚙️ Configuration...');
  try {
    await ConfigService.init();
    await LoggerService.init();
    await _writeLog('✅ Configuration OK');
  } catch (e) {
    await _writeLog('⚠️ Configuration: $e');
  }

  // ===== HIVE =====
  bootstrapContext.onStatusChange('Base de données locale...');
  await _writeLog('📦 Hive...');
  try {
    await HiveService.init();
    await _writeLog('✅ Hive OK');
  } catch (e) {
    await _writeLog('⚠️ Hive: $e');
  }

  // ===== FIREBASE =====
  bootstrapContext.onStatusChange('Connexion au serveur...');
  await _writeLog('🔥 Firebase...');
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
    await _writeLog('✅ Firebase OK');
  } catch (e) {
    await _writeLog('⚠️ Firebase: $e');
  }

  // ===== FIRESTORE (NON BLOQUANT) =====
  bootstrapContext.onStatusChange('Préparation du cloud...');
  await _writeLog('☁️ Firestore (arrière-plan)...');
  try {
    FirestoreInitializer.initialize().catchError((e) {
      _writeLog('⚠️ Firestore init ignorée: $e');
    });
    await _writeLog('✅ Firestore lancé en arrière-plan');
  } catch (e) {
    await _writeLog('⚠️ Firestore: $e');
  }

  // ===== SERVICES =====
  bootstrapContext.onStatusChange('Initialisation des services...');
  await _writeLog('🛠️ Services...');
  final notificationService = NotificationService();
  final connectivityService = ConnectivityService();
  final stockService = StockService();
  final nochPayService = NochPayService();

  gNotificationService = notificationService;
  gConnectivityService = connectivityService;
  gStockService = stockService;
  gNochPayService = nochPayService;

  try {
    await Future.any([
      Future.wait([
        notificationService.init(),
        ReminderService().init(),
        stockService.init(),
        ThemeService.init(),
        SecurityService.init(),
      ]),
      Future.delayed(const Duration(seconds: 8)),
    ]);
    await _writeLog('✅ Services OK (ou timeout)');
  } catch (e) {
    await _writeLog('⚠️ Services: $e (continue)');
  }

  // ===== SUBSCRIPTION CHECKER =====
  bootstrapContext.onStatusChange('Préparation des rappels...');
  await _writeLog('🔄 SubscriptionChecker...');
  try {
    SubscriptionCheckerService().start().ignore();
    await _writeLog('✅ SubscriptionChecker lancé');
  } catch (e) {
    await _writeLog('⚠️ SubscriptionChecker: $e');
  }

  // 🔥 Synchronisation après lancement (en arrière-plan)
  _syncAfterStartup();
}

// 🔥 Fonction de synchronisation différée
void _syncAfterStartup() {
  // Attendre que l'utilisateur soit authentifié et que la connexion soit stable
  Future.delayed(const Duration(seconds: 5), () async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user != null) {
        // Vérifier la connectivité
        final connectivity = ConnectivityService();
        if (await connectivity.checkConnection()) {
          await SyncService().syncAll();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Synchronisation différée: $e');
    }
  });
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
        ChangeNotifierProxyProvider<AppAuthProvider, SubscriptionProvider>(
          create: (context) => SubscriptionProvider(
            context.read<AppAuthProvider>(),
          ),
          update: (context, authProvider, previous) {
            return previous ?? SubscriptionProvider(authProvider);
          },
        ),
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