import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:noi_ohada_invoice_pro/firebase_options.dart';
import 'package:noi_ohada_invoice_pro/services/sync_service.dart';
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
import 'services/template_cart.dart';
import 'services/subscription_checker_service.dart';
import 'services/hive_service.dart';
import 'services/database_service.dart';
import 'services/firestore_initializer.dart';
import 'services/boot_logger.dart' as boot;

// Providers
import 'providers/auth_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/theme_provider.dart';

// Router & Widgets
import 'router/app_router.dart';
import 'widgets/connectivity_wrapper.dart';
import 'widgets/app_bootstrap.dart';
import 'widgets/glass_app_background.dart';

/// Services créés lors de l'initialisation (globales pour être partagées)
NotificationService? gNotificationService;
ConnectivityService? gConnectivityService;
StockService? gStockService;

/// Log de démarrage compatible web + mobile (délègue à boot_logger).
Future<void> _writeLog(String message) => boot.writeBootLog(message);

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

    return MyApp(
      notificationService: notificationService,
      connectivityService: connectivityService,
      stockService: stockService,
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

    // ===== BASE DE DONNÉES (FIRESTORE = source de vérité) =====
  // NB : toute la donnée métier (clients, produits, factures, entreprise…)
  // vit désormais dans Firestore via DatabaseService. Hive n'est conservé
  // que pour le cache interne de certains services auxiliaires.
  bootstrapContext.onStatusChange('Base de données cloud...');
  await _writeLog('🔥 DatabaseService (Firestore)...');
  try {
    await DatabaseService.init();
    await _writeLog('✅ DatabaseService (Firestore) OK');
  } catch (e) {
    await _writeLog('⚠️ DatabaseService: $e');
  }

  // ===== HIVE (cache auxiliaire uniquement) =====
  bootstrapContext.onStatusChange('Cache local...');
  await _writeLog('📦 Hive (cache)...');
  try {
    await HiveService.init();
    await _writeLog('✅ Hive (cache) OK');
  } catch (e) {
    await _writeLog('⚠️ Hive: $e');
  }

  // ===== FIREBASE =====
  bootstrapContext.onStatusChange('Connexion au serveur...');
  await _writeLog('🔥 Firebase...');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
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

  gNotificationService = notificationService;
  gConnectivityService = connectivityService;
  gStockService = stockService;

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
        // 🛒 Panier de modèles de factures (singleton) — requis par la
        // boutique et le checkout (`context.watch<TemplateCart>()`).
        ChangeNotifierProvider<TemplateCart>.value(value: TemplateCart.instance),
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
              // 🖼️ Fond glass global derrière toute la navigation.
              return GlassAppBackground(
                child: ConnectivityWrapper(
                  onRetry: () {},
                  child: child ?? const SizedBox.shrink(),
                ),
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