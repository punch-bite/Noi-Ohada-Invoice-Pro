// lib/services/config_service.dart
//
// 🔐 Sécurité : les SECRETS (clés ENKAP, SMTP…) ne sont
// JAMAIS embarqués dans le bundle. Ils sont injectés au build via
// `--dart-define` et restent hors de l'APK.
//
// Les valeurs non sensibles (Firebase, préférences UI) peuvent aussi être
// lues depuis un fichier `.env` NON embarqué, uniquement en développement.
//
// Injection en production :
//   flutter build apk --dart-define=SMTP_PASSWORD=xxx
//
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'env_loader.dart';

class ConfigService {
  // ===== GESTION DES SECRETS (via --dart-define uniquement) =====

  /// Lit un secret depuis --dart-define. En debug uniquement, on autorise
  /// un repli sur le fichier `.env` local (jamais embarqué dans l'APK).
  //
  // 🔴 NB : `String.fromEnvironment` exige un argument CONSTANT au niveau
  // compilation. Appelé au runtime avec une variable, il lève
  // UnsupportedError sous le compilateur web de dev (DDC) → on protège.
  static String _secret(String key) {
    String fromEnv;
    try {
      fromEnv = String.fromEnvironment(key);
    } catch (_) {
      fromEnv = '';
    }
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

  /// Lit une valeur NON sensible : priorité à `--dart-define` (injectée au
  /// build, ex. CodeMagic : `--dart-define=API_BASE_URL=...`), puis `.env`.
  /// SANS cette lecture, le `--dart-define` serait un no-op (le getter ne
  /// voyait que dotenv, jamais initialisé en release → toujours la valeur
  /// par défaut).
  static String _env(String key, {String def = ''}) {
    // 🔴 try/catch : sur web dev (DDC), String.fromEnvironment avec un
    // argument non-constant lève UnsupportedError → repli sur `.env`/défaut.
    String fromEnv;
    try {
      fromEnv = String.fromEnvironment(key);
    } catch (_) {
      fromEnv = '';
    }
    if (fromEnv.isNotEmpty) return fromEnv;
    return _read(key, def: def);
  }

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

  // ENKAP (Maviance e-nkap) — paiement Mobile Money (Orange/MTN) + Carte.
  // Base de l'API de paiement (production par défaut).
  static const String _defaultEnkapBaseUrl =
      'https://api-v2.enkap.cm/purchase/v1.2';
  static String get enkapBaseUrl =>
      _env('ENKAP_BASE_URL', def: _defaultEnkapBaseUrl);
  static String get enkapTokenUrl => _env('ENKAP_TOKEN_URL');
  static String get enkapConsumerKey => _secret('ENKAP_CONSUMER_KEY');
  static String get enkapConsumerSecret => _secret('ENKAP_CONSUMER_SECRET');
  static String get enkapAccessToken => _secret('ENKAP_ACCESS_TOKEN');
  /// Vrai si une configuration ENKAP (jeton ou clés) est présente.
  static bool get enkapConfigured =>
      enkapAccessToken.isNotEmpty ||
      (enkapConsumerKey.isNotEmpty &&
          enkapConsumerSecret.isNotEmpty &&
          enkapTokenUrl.isNotEmpty);

  /// Vrai si des secrets ENKAP sont injectés AU BUILD via `--dart-define`
  /// (donc réellement embarqués, disponibles même en release).
  ///
  /// Contrairement à [enkapConfigured], ce getter IGNORE le fichier `.env`
  /// (qui n'est jamais embarqué dans l'APK et peut contenir des clés de dev
  /// expirées/invalides). Il sert à décider si l'app peut appeler ENKAP en
  /// direct ou doit passer par le serveur proxy (qui détient les bons secrets).
  static bool get enkapSecretsAtBuild {
    String f(String key) {
      try {
        return String.fromEnvironment(key);
      } catch (_) {
        return '';
      }
    }

    final t = f('ENKAP_ACCESS_TOKEN').trim();
    final k = f('ENKAP_CONSUMER_KEY').trim();
    final s = f('ENKAP_CONSUMER_SECRET').trim();
    final u = f('ENKAP_TOKEN_URL').trim();
    return t.isNotEmpty || (k.isNotEmpty && s.isNotEmpty && u.isNotEmpty);
  }

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
  /// Serveur de callback + proxy ENKAP (Vercel) — URL publique. Utilisée par
  /// le web pour relayer les appels ENKAP (l'API E-nkap bloque le CORS
  /// navigateur) et par l'app pour les callbacks / intentions d'abonnement.
  static const String _defaultApiBaseUrl =
      'https://server-xi-two-23.vercel.app';
  // 🔧 `_env` : priorité au --dart-define (CodeMagic) puis .env puis défaut.
  static String get apiBaseUrl => _env('API_BASE_URL', def: _defaultApiBaseUrl);
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
