// lib/services/config_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class ConfigService {
  // Liste des clés obligatoires pour le bon fonctionnement de l'app
  static const List<String> _requiredKeys = [
    'FIREBASE_API_KEY',
    'FIREBASE_PROJECT_ID',
    'NOCHPAY_API_KEY'
  ];

  /// Initialise les variables d'environnement et vérifie la présence des clés critiques
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: ".env");
      
      // Validation stricte
      for (final key in _requiredKeys) {
        if (!dotenv.env.containsKey(key)) {
          throw Exception('Variable d\'environnement manquante : $key');
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur de chargement du ConfigService: $e');
      rethrow;
    }
  }

  static void printConfig() {
    if (kDebugMode) {
      debugPrint('🔥 ConfigService initialisé | Environnement: $appEnvironment');
    }
  }

  // --- Helpers privés ---
  static String _get(String key, {String def = ''}) => dotenv.env[key] ?? def;
  static bool _getBool(String key) => dotenv.env[key]?.toLowerCase() == 'true';
  static int _getInt(String key, int def) => int.tryParse(dotenv.env[key] ?? '') ?? def;

  // --- Accesseurs Typés ---

  // Firebase
  static String get firebaseApiKey => _get('FIREBASE_API_KEY');
  static String get firebaseAppId => _get('FIREBASE_APP_ID');
  static String get firebaseMessagingSenderId => _get('FIREBASE_MESSAGING_SENDER_ID');
  static String get firebaseProjectId => _get('FIREBASE_PROJECT_ID');
  static String get firebaseAuthDomain => _get('FIREBASE_AUTH_DOMAIN');
  static String get firebaseStorageBucket => _get('FIREBASE_STORAGE_BUCKET');

  // Nochpay
  static String get nochpayApiKey => _get('NOCHPAY_API_KEY');
  static String get nochpayPublicKey => _get('NOCHPAY_PUBLIC_KEY');
  static String get nochpayWebhookSecret => _get('NOCHPAY_WEBHOOK_SECRET');
  static String get nochpayMode => _get('NOCHPAY_MODE', def: 'sandbox');

  // App
  static String get appName => _get('APP_NAME', def: 'OHADA Invoice Pro');
  static String get appVersion => _get('APP_VERSION', def: '1.0.0');
  static String get appEnvironment => _get('APP_ENVIRONMENT', def: 'development');
  static String get defaultCurrency => _get('DEFAULT_CURRENCY', def: 'XAF');
  static double get defaultTaxRate => double.tryParse(_get('DEFAULT_TAX_RATE', def: '18')) ?? 18.0;
  static String get apiBaseUrl => _get('API_BASE_URL');
  static int get apiTimeout => _getInt('API_TIMEOUT', 30);
  static String get supportEmail => _get('SUPPORT_EMAIL');
  static String get supportPhone => _get('SUPPORT_PHONE');

  // Features
  static bool get pdfExportEnabled => _getBool('FEATURE_PDF_EXPORT');
  static bool get cloudSyncEnabled => _getBool('FEATURE_CLOUD_SYNC');
  static bool get teamAccessEnabled => _getBool('FEATURE_TEAM_ACCESS');
  static int get maxFreeInvoices => _getInt('MAX_FREE_INVOICES', 3);
  static int get maxFreeClients => _getInt('MAX_FREE_CLIENTS', 5);
}