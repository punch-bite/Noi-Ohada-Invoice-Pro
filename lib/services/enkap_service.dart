// lib/services/enkap_service.dart
//
// 💳 PAIEMENT ENKAP (Maviance e-nkap) — Mobile Money (Orange / MTN) + Carte.
//
// E-nkap est une passerelle de paiement camerounaise qui parle directement
// aux opérateurs (MTN Mobile Money, Orange Money, carte…). Le client est
// redirigé sur la page de paiement E-nkap où il confirme (invite USSD avec
// son code secret pour le Mobile Money, ou formulaire carte), puis la
// confirmation est reçue par :
//   - Notification instantanée (ITN) : PUT <notificationUrl>/<reference>
//   - Polling : GET /api/order/status?orderMerchantId=<reference>
//
// Endpoints (base : https://api-v2.enkap.cm/purchase/v1.2) :
//   POST   /api/order            → créer une commande (retourne redirectUrl)
//   GET    /api/order/status     → statut (CREATED/INITIALISED/IN_PROGRESS/
//                                   CONFIRMED/FAILED/CANCELED)
//   GET    /api/order            → détails (+ paymentProviderName)
//   PUT    /api/order/setup      → configurer returnUrl / notificationUrl
//   DELETE /api/order/{txid}     → annuler une commande
//
// Authentification : OAuth2 (WSO2 APIM) — jeton d'accès via
// `Authorization: Bearer <token>`, renouvelable avec consumer key/secret.
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../services/config_service.dart';

class EnkapService {
  // ===== Constantes des méthodes de paiement (affichage) =====
  static const String methodOrangeMoney = 'orange_money';
  static const String methodMtnMoney = 'mtn_money';
  static const String methodCard = 'card';

  // Statuts possibles renvoyés par l'API E-nkap.
  static const List<String> statuses = [
    'CREATED',
    'INITIALISED',
    'IN_PROGRESS',
    'CONFIRMED',
    'FAILED',
    'CANCELED',
  ];

  final http.Client _client = http.Client();

  String get _baseUrl => ConfigService.enkapBaseUrl;

  /// Sur le web, l'API E-nkap refuse les appels navigateur (CORS → 403
  /// « Invalid CORS request ») : on relaie TOUJOURS via notre serveur
  /// (Vercel), qui détient les secrets ENKAP.
  ///
  /// En natif (Android/iOS), on relaie aussi via le serveur lorsque les
  /// secrets ENKAP ne sont pas embarqués dans l'app (cas standard : l'APK
  /// ne contient JAMAIS les secrets). Si des secrets sont injectés au build
  /// via --dart-define, on appelle ENKAP en direct.
  String get _serverBase => ConfigService.apiBaseUrl.trim();
  bool get _useServerProxy =>
      kIsWeb || (!isConfigured && _serverBase.isNotEmpty);
  bool get isConfigured => ConfigService.enkapConfigured;

  /// Vrai si la configuration suffit : le serveur (proxy) est joignable,
  /// ou les secrets ENKAP sont présents pour un appel direct.
  bool get _configOk => _useServerProxy ? _serverBase.isNotEmpty : isConfigured;

  String? _cachedToken;
  DateTime? _tokenExpiry;

  /// Statut considéré comme un paiement réussi.
  static bool isConfirmed(String status) {
    final s = status.trim().toUpperCase();
    return s == 'CONFIRMED' || s == 'COMPLETED';
  }

  /// Statut considéré comme un échec / annulation.
  static bool isFailed(String status) {
    final s = status.trim().toUpperCase();
    return s == 'FAILED' || s == 'CANCELED';
  }

  // ============================================================
  //  AUTHENTIFICATION (jeton d'accès)
  // ============================================================

  /// Retourne le jeton `Bearer` à utiliser. Priorité au jeton configuré
  /// (ENKAP_ACCESS_TOKEN), sinon renouvellement OAuth2 client_credentials
  /// via ENKAP_CONSUMER_KEY / ENKAP_CONSUMER_SECRET / ENKAP_TOKEN_URL.
  Future<String> _getToken() async {
    final configured = ConfigService.enkapAccessToken.trim();
    if (configured.isNotEmpty) return configured;

    if (_cachedToken != null &&
        _tokenExpiry != null &&
        _tokenExpiry!.isAfter(DateTime.now())) {
      return _cachedToken!;
    }

    final tokenUrl = ConfigService.enkapTokenUrl.trim();
    final key = ConfigService.enkapConsumerKey.trim();
    final secret = ConfigService.enkapConsumerSecret.trim();
    if (tokenUrl.isEmpty || key.isEmpty || secret.isEmpty) {
      throw Exception(
        'Configuration ENKAP manquante : renseignez ENKAP_ACCESS_TOKEN '
        'ou les clés consommateur + URL de jeton dans .env.',
      );
    }

    final resp = await _client
        .post(
          Uri.parse(tokenUrl),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'client_credentials',
            'client_id': key,
            'client_secret': secret,
          },
        )
        .timeout(const Duration(seconds: 15));

    final data = _decode(resp);
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception(
        'Erreur jeton ENKAP : '
        '${data['error_description'] ?? data['error'] ?? resp.body}',
      );
    }
    _cachedToken = data['access_token'] as String?;
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 259200;
    _tokenExpiry =
        DateTime.now().add(Duration(seconds: expiresIn > 60 ? expiresIn - 60 : expiresIn));
    return _cachedToken ?? '';
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Map<String, dynamic> _decode(http.Response resp) {
    try {
      final decoded = json.decode(utf8.decode(resp.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      return {'raw': decoded};
    } catch (_) {
      return {'error': resp.body};
    }
  }

  // ============================================================
  //  CRÉATION D'UNE COMMANDE DE PAIEMENT
  // ============================================================

  /// Enregistre une commande dans E-nkap.
  ///
  /// Retourne (succès) :
  ///   { success, orderTransactionId, merchantReferenceId, redirectUrl }
  Future<Map<String, dynamic>> registerOrder({
    required double amount,
    required String currency,
    required String description,
    required String merchantReference,
    String? customerName,
    String? customerEmail,
    String? phoneNumber,
    List<Map<String, dynamic>>? items,
  }) async {
    if (!_configOk) {
      return {
        'success': false,
        'error':
            'Paiement non configuré. Assurez-vous que l\'URL du serveur de '
            'paiement (API_BASE_URL) est valide, ou injectez les clés ENKAP '
            'au build (--dart-define).',
      };
    }

    final payload = <String, dynamic>{
      'currency': currency,
      'totalAmount': amount,
      'description': description,
      'merchantReference': merchantReference,
      'langKey': 'fr',
      if (customerName != null && customerName.isNotEmpty)
        'customerName': customerName,
      if (customerEmail != null && customerEmail.isNotEmpty)
        'email': customerEmail,
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        'phoneNumber': phoneNumber,
      if (items != null && items.isNotEmpty) 'items': items,
    };

    try {
      if (_useServerProxy) {
        // Web : relais par notre serveur (qui détient les secrets ENKAP).
        final resp = await _client
            .post(
              Uri.parse('$_serverBase/enkap/order'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: json.encode(payload),
            )
            .timeout(const Duration(seconds: 20));
        final data = _decode(resp);
        if (resp.statusCode == 200 || resp.statusCode == 201) {
          return {
            'success': data['success'] != false,
            'orderTransactionId': data['orderTransactionId'],
            'merchantReferenceId': data['merchantReferenceId'],
            'redirectUrl': data['redirectUrl'],
          };
        }
        return {
          'success': false,
          'error': data['error'] ??
              data['message'] ??
              'Erreur serveur (${resp.statusCode})',
        };
      }

      final token = await _getToken();
      final resp = await _client
          .post(
            Uri.parse('$_baseUrl/api/order'),
            headers: _headers(token),
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 20));
      final data = _decode(resp);
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        return {
          'success': true,
          'orderTransactionId': data['orderTransactionId'],
          'merchantReferenceId': data['merchantReferenceId'],
          'redirectUrl': data['redirectUrl'],
        };
      }
      return {
        'success': false,
        'error': data['message'] ??
            data['error'] ??
            'Erreur ENKAP (${resp.statusCode})',
      };
    } catch (e) {
      // Ne JAMAIS lever ici : un échec réseau/CORS doit afficher une erreur
      // dans le dialogue, pas bloquer sur un spinner infini.
      return {'success': false, 'error': 'Erreur réseau : $e'};
    }
  }

  // ============================================================
  //  STATUT / DÉTAILS
  // ============================================================

  /// Interroge le statut d'un paiement (par référence marchand ou txid).
  Future<String> getStatus({String? txid, String? merchantReference}) async {
    try {
      final params = <String, String>{
        if (txid != null && txid.isNotEmpty) 'txid': txid,
        if (merchantReference != null && merchantReference.isNotEmpty)
          'orderMerchantId': merchantReference,
      };
      if (_useServerProxy) {
        final uri = Uri.parse('$_serverBase/enkap/order/status')
            .replace(queryParameters: params);
        final resp = await _client
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));
        final data = _decode(resp);
        return data['status'] ?? '';
      }
      final token = await _getToken();
      final uri = Uri.parse('$_baseUrl/api/order/status')
          .replace(queryParameters: params);
      final resp = await _client
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      final data = _decode(resp);
      return data['status'] ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Détails complets d'un paiement (moyen utilisé, payeur…).
  Future<Map<String, dynamic>> getDetails({
    String? txid,
    String? merchantReference,
  }) async {
    try {
      final params = <String, String>{
        if (txid != null && txid.isNotEmpty) 'txid': txid,
        if (merchantReference != null && merchantReference.isNotEmpty)
          'orderMerchantId': merchantReference,
      };
      if (_useServerProxy) {
        final uri = Uri.parse('$_serverBase/enkap/order')
            .replace(queryParameters: params);
        final resp = await _client
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));
        return _decode(resp);
      }
      final token = await _getToken();
      final uri =
          Uri.parse('$_baseUrl/api/order').replace(queryParameters: params);
      final resp = await _client
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      return _decode(resp);
    } catch (_) {
      return {};
    }
  }

  // ============================================================
  //  ENREGISTREMENT CÔTÉ SERVEUR (activation par callback ENKAP)
  // ============================================================

  /// Enregistre l'intention d'abonnement sur notre serveur (Vercel) afin que
  /// le callback ENKAP (`PUT /enkap/callback/:reference`) puisse activer
  /// l'abonnement même si l'app est fermée. Best-effort : en cas d'échec,
  /// l'app active elle-même via [registerOrder] + polling.
  Future<void> registerSubscriptionIntent({
    required String reference,
    required String userId,
    required String planId,
    required double amount,
    required String currency,
    required String paymentMethod,
  }) async {
    final apiBase = ConfigService.apiBaseUrl.trim();
    if (apiBase.isEmpty) return;
    try {
      await _client
          .post(
            Uri.parse('$apiBase/enkap/register'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'reference': reference,
              'user_id': userId,
              'plan_id': planId,
              'amount': amount,
              'currency': currency,
              'payment_method': paymentMethod,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Ignoré : l'activation côté client reste le mécanisme principal.
    }
  }
}
