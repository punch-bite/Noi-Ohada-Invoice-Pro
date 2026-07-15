// lib/services/config_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  // ===== INITIALISATION =====
  static Future<void> init() async {
    await dotenv.load(fileName: ".env");
  }

  static void printConfig() {
    print('🔥 ConfigService loaded');
    print('APP_ENVIRONMENT: ${dotenv.env['APP_ENVIRONMENT']}');
    print('FIREBASE_PROJECT_ID: ${dotenv.env['FIREBASE_PROJECT_ID']}');
    print('NOCHPAY_MODE: ${dotenv.env['NOCHPAY_MODE']}');
  }

  // ===== FIREBASE =====
  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';
  static String get firebaseAppId => dotenv.env['FIREBASE_APP_ID'] ?? '';
  static String get firebaseMessagingSenderId => dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  static String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get firebaseAuthDomain => dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '';
  static String get firebaseStorageBucket => dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';

  // ===== NOCHPAY =====
  static String get nochpayApiKey => dotenv.env['NOCHPAY_API_KEY'] ?? '';
  static String get nochpayPublicKey => dotenv.env['NOCHPAY_PUBLIC_KEY'] ?? '';
  static String get nochpayWebhookSecret => dotenv.env['NOCHPAY_WEBHOOK_SECRET'] ?? '';
  static String get nochpayMode => dotenv.env['NOCHPAY_MODE'] ?? 'sandbox';

  // ===== APP =====
  static String get appName => dotenv.env['APP_NAME'] ?? 'OHADA Invoice Pro';
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  static String get appEnvironment => dotenv.env['APP_ENVIRONMENT'] ?? 'development';
  static String get defaultCurrency => dotenv.env['DEFAULT_CURRENCY'] ?? 'XAF';
  static double get defaultTaxRate => double.tryParse(dotenv.env['DEFAULT_TAX_RATE'] ?? '18') ?? 18;
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';
  static int get apiTimeout => int.tryParse(dotenv.env['API_TIMEOUT'] ?? '30') ?? 30;
  static String get supportEmail => dotenv.env['SUPPORT_EMAIL'] ?? '';
  static String get supportPhone => dotenv.env['SUPPORT_PHONE'] ?? '';

  // ===== FEATURES =====
  static bool get pdfExportEnabled => dotenv.env['FEATURE_PDF_EXPORT']?.toLowerCase() == 'true';
  static bool get cloudSyncEnabled => dotenv.env['FEATURE_CLOUD_SYNC']?.toLowerCase() == 'true';
  static bool get teamAccessEnabled => dotenv.env['FEATURE_TEAM_ACCESS']?.toLowerCase() == 'true';
  static int get maxFreeInvoices => int.tryParse(dotenv.env['MAX_FREE_INVOICES'] ?? '3') ?? 3;
  static int get maxFreeClients => int.tryParse(dotenv.env['MAX_FREE_CLIENTS'] ?? '5') ?? 5;
}