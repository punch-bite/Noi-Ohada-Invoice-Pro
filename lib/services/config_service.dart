// lib/services/config_service.dart
//
// 🔐 Sécurité : les SECRETS (clés privées NochPay, webhook, SMTP…) ne sont
// JAMAIS embarqués dans le bundle. Ils sont injectés au build via
// `--dart-define` et restent hors de l'APK.
//
// Les valeurs non sensibles (Firebase, préférences UI) peuvent aussi être
// lues depuis un fichier `.env` NON embarqué, uniquement en développement.
//
// Injection en production :
//   flutter build apk --dart-define=NOCHPAY_PRIVATE_KEY=sk_xxx \
//                     --dart-define=NOCHPAY_WEBHOOK_SECRET=whsec_xxx \
//                     --dart-define=SMTP_PASSWORD=xxx
//
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'env_loader.dart';

class ConfigService {
  // ===== GESTION DES SECRETS (via --dart-define uniquement) =====

  /// Lit un secret depuis --dart-define. En debug uniquement, on autorise
  /// un repli sur le fichier `.env` local (jamais embarqué dans l'APK).
  static String _secret(String key) {
    final fromEnv = String.fromEnvironment(key);
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kDebugMode) return _read(key);
    return '';
  }

  /// Initialise la config non sensible depuis `.env` (dév. uniquement).
  /// Ne lève JAMAIS d'exception si le fichier est absent : l'app doit
  /// démarrer même sans `.env` (les secrets viennent de --dart-define).
  static Future<void> init() async {
    try {
      if (kDebugMode) {
        final content = await loadEnvContent();
        if (content != null && content.trim().isNotEmpty) {
          dotenv.loadFromString(envString: content);
          debugPrint('ℹ️ ConfigService: .env chargé');
        } else {
          debugPrint('ℹ️ ConfigService: .env introuvable (mode dev)');
        }
      }
    } catch (e) {
      debugPrint('ℹ️ ConfigService: .env non chargé (mode dev) : $e');
    }
    printConfig();
  }

  static void printConfig() {
    if (kDebugMode) {
      debugPrint(
          '🔥 ConfigService initialisé | Environnement: $appEnvironment');
    }
  }

  // --- Helpers privés (config NON sensible) ---
  // ⚠️ Tous les accès dotenv passent par `_read` : si `.env` n'a pas été
  // chargé (web/release), on retourne la valeur par défaut SANS lever
  // NotInitializedError.
  static String _read(String key, {String def = ''}) {
    try {
      if (!dotenv.isInitialized) return def;
      return dotenv.env[key] ?? def;
    } catch (_) {
      return def;
    }
  }

  static String _get(String key, {String def = ''}) => _read(key, def: def);
  static bool _getBool(String key) => _read(key).toLowerCase() == 'true';
  static int _getInt(String key, int def) =>
      int.tryParse(_read(key)) ?? def;

  // --- Accesseurs Typés ---

  // Firebase (valeurs publiques des apps mobiles : OK en clair)
  static String get firebaseApiKey => _get('FIREBASE_API_KEY');
  static String get firebaseAppId => _get('FIREBASE_APP_ID');
  static String get firebaseMessagingSenderId =>
      _get('FIREBASE_MESSAGING_SENDER_ID');
  static String get firebaseProjectId => _get('FIREBASE_PROJECT_ID');
  static String get firebaseAuthDomain => _get('FIREBASE_AUTH_DOMAIN');
  static String get firebaseStorageBucket => _get('FIREBASE_STORAGE_BUCKET');
  static String get firebaseWebClientId =>
      _get('FIREBASE_WEB_CLIENT_ID', def: _defaultWebClientId);

  /// Web client ID OAuth (valeur publique) — requis pour Google Sign-In
  /// sur web. Correspond au client_id de type "web" dans google-services.json.
  static const String _defaultWebClientId =
      '942740787802-a5e4djanel0fk1edu1umdi1h3qm4l3e2.apps.googleusercontent.com';

  // Nochpay — clé publique (publishable, toujours côté client) + secrets
  // La clé publique `pk_` est CONÇUE pour être publique (comme une clé
  // publishable Stripe) : elle vit dans le client par défaut. Elle peut être
  // surchargée via --dart-define/.env (NOCHPAY_PUBLIC_KEY) en production.
  static const String _defaultNochpayPublicKey =
      'pk_test.udZRV3kzUtgQHymnJArUFnnSvZxww3WxH6WfSZWxNHJSPUf9bIoguBPpkR6aNtMX7RDA51j1mxYP23UB1i3D9BfrkGwwxAAgQAHmlSrUG1OjiNs4E7G2cpK5m14Vm';
  static String get nochpayPublicKey {
    final v = _secret('NOCHPAY_PUBLIC_KEY');
    return v.isNotEmpty ? v : _defaultNochpayPublicKey;
  }

  static String get nochpayPrivateKey => _secret('NOCHPAY_PRIVATE_KEY');
  static String get nochpayWebhookSecret => _secret('NOCHPAY_WEBHOOK_SECRET');
  static bool get isProduction => _get('NOCHPAY_MODE') == 'production';

  // SMTP — SECRET (--dart-define uniquement)
  static String get smtpHost => _get('SMTP_HOST', def: 'smtp.gmail.com');
  static int get smtpPort => _getInt('SMTP_PORT', 587);
  static String get smtpUsername => _get('SMTP_USERNAME');
  static String get smtpPassword => _secret('SMTP_PASSWORD');
  static String get smtpFromEmail => _get('SMTP_FROM_EMAIL');
  static String get smtpFromName => _get('SMTP_FROM_NAME', def: 'OHADA Invoice Pro');
  static bool get smtpSecure =>
      _get('SMTP_SECURE', def: 'false').toLowerCase() == 'true';

  // App
  static String get appName => _get('APP_NAME', def: 'Noi OHADA Invoice Pro');
  static String get appVersion => _get('APP_VERSION', def: '1.0.0');
  static String get appEnvironment =>
      _get('APP_ENVIRONMENT', def: 'development');
  static String get defaultCurrency => _get('DEFAULT_CURRENCY', def: 'XAF');
  static double get defaultTaxRate =>
      double.tryParse(_get('DEFAULT_TAX_RATE', def: '18')) ?? 18.0;
  static String get apiBaseUrl => _get('API_BASE_URL');
  static int get apiTimeout => _getInt('API_TIMEOUT', 30);
  static String get supportEmail => _get('SUPPORT_EMAIL');
  static String get supportPhone => _get('SUPPORT_PHONE');

  // Features
  static bool get pdfExportEnabled => _getBool('FEATURE_PDF_EXPORT');
  static bool get cloudSyncEnabled => _getBool('FEATURE_CLOUD_SYNC');
  static bool get teamAccessEnabled => _getBool('FEATURE_TEAM_ACCESS');
  static int get maxFreeInvoices => _getInt('MAX_FREE_INVOICES', 5);
  static int get maxFreeClients => _getInt('MAX_FREE_CLIENTS', 5);
}
