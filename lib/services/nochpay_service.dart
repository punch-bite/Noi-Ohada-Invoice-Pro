// lib/services/nochpay_service.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/notification_service.dart';
import '../services/config_service.dart';

class NochPayService {
    // ===== Constantes des méthodes de paiement supportées =====
  static const String methodOrangeMoney = 'orange_money';
  static const String methodMtnMoney = 'mtn_money';
  static const String methodWave = 'wave';
  static const String methodCard = 'card';

  // ✅ Méthodes alternatives (docs Notch Pay "Other Payment Methods")
  static const String methodAssoh = 'asso'; // Portefeuille numérique (Cameroun)
  static const String methodKudi = 'kudi'; // Portefeuille numérique
  static const String methodQrCode = 'qr_code'; // Paiement par QR Code

  /// Liste de toutes les méthodes de paiement supportées.
  static const List<String> supportedMethods = [
    methodOrangeMoney,
    methodMtnMoney,
    methodWave,
    methodCard,
    methodAssoh,
    methodKudi,
    methodQrCode,
  ];

  /// Méthodes "Mobile Money" traitées via l'invite USSD / canal opérateur.
  static const List<String> ussdMethods = [
    methodOrangeMoney,
    methodMtnMoney,
    methodWave,
  ];

  /// Méthodes "Portefeuilles numériques" traitées via la page NotchPay Collect.
  static const List<String> walletMethods = [
    methodAssoh,
    methodKudi,
  ];

  // 🔥 URL de base (sandbox ou production)
  static String get _baseUrl => ConfigService.isProduction
      ? 'https://api.notchpay.co'
      : 'https://api-sandbox.notchpay.co';

  // 🔥 Clés depuis ConfigService (ou dotenv directement)
  static String get _publicKey => ConfigService.nochpayPublicKey; // pk_...
  static String get _privateKey => ConfigService.nochpayPrivateKey; // sk_...
  static String get _webhookSecret => ConfigService.nochpayWebhookSecret; // whsec_...

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final NotificationService _notificationService = NotificationService();
  final http.Client _client = http.Client();

    bool get isConfigured => _publicKey.isNotEmpty && _privateKey.isNotEmpty;

  /// L'initiation d'un paiement (initiatePayment) côté client ne requiert en
  /// réalité que la clé publique (publishable key). La clé privée (secret
  /// key) ne sert qu'aux opérations côté serveur (webhooks, statut complet).
  /// On s'appuie donc sur la seule clé publique pour ne pas bloquer à tort le
  /// paiement Mobile Money si la clé privée est absente.
  bool get isPaymentInitiationConfigured => _publicKey.isNotEmpty;

  // ============================================================
  //  1. INITIATION DU PAIEMENT (AVEC MÉTADONNÉES)
  // ============================================================

    Future<Map<String, dynamic>> initiatePayment({
    required double amount,
    required String currency,
    required String phoneNumber,
    required String invoiceNumber,
    required String description,
    String paymentMethod = methodOrangeMoney,
    String? customerName,
    String? customerEmail,
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>>? items,
  }) async {
        if (!isPaymentInitiationConfigured) {
      return {
        'success': false,
        'error':
            'Configuration API manquante. Vérifiez votre clé publique NochPay '
            '(NOCHPAY_PUBLIC_KEY) dans le fichier .env.',
      };
    }

    // Validation de la méthode de paiement
    if (!supportedMethods.contains(paymentMethod)) {
      return {
        'success': false,
        'error': 'Méthode de paiement non supportée : $paymentMethod',
      };
    }

    try {
      // 🔥 Construction du payload conforme à la doc NotchPay « Create a
      // Payment Session » : champs racines `amount`, `currency`, `phone`,
      // `callback` (+ métadonnées optionnelles acceptées par l'API).
      final apiBase = ConfigService.apiBaseUrl.trim();
      final payload = {
        'amount': amount,
        'currency': currency,
        // `phone` requis par la méthode officielle : on ne l'envoie que s'il
        // est renseigné (la page Collect gère aussi la saisie côté client).
        if (phoneNumber.isNotEmpty) 'phone': phoneNumber,
        // Callback obligatoire dans la méthode officielle : si aucune API
        // n'est configurée, on s'appuie sur le polling / webhook NoChPay.
        if (apiBase.isNotEmpty)
          'callback': '$apiBase/payment/callback',
        // --- Champs optionnels (enrichissement) ---
        'payment_method': paymentMethod,
        'reference': invoiceNumber,
        'description': description,
        'customer': {
          'name': customerName ?? 'Client',
          'email': customerEmail ?? 'client@email.com',
          'phone': phoneNumber,
        },
        'customer_meta': {
          'invoice_number': invoiceNumber,
          'source': 'noi_ohada_invoice_app',
          'payment_method': paymentMethod,
          if (metadata != null) ...metadata,
        },
        if (items != null) 'items': items,
        'mode': ConfigService.isProduction ? 'production' : 'sandbox',
      };

      // ✅ Endpoint OFFICIEL : POST {base}/payment (singulier), conforme à
      // la méthode de réception de paiement NotchPay.
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/payment'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': _publicKey,
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        // La réponse officielle place `authorization_url` à la racine et la
        // transaction sous `transaction`. On gère les deux formes.
        final transaction = (data['transaction'] is Map<String, dynamic>)
            ? data['transaction'] as Map<String, dynamic>
            : (data as Map<String, dynamic>);
        return {
          'success': true,
          'transaction_id':
              (transaction['id'] ?? transaction['reference'] ?? data['reference']),
          'reference': transaction['reference'] ?? data['reference'] ?? invoiceNumber,
          'authorization_url': data['authorization_url'],
          'status': transaction['status'] ?? 'pending',
          'message': data['message'] ?? 'Paiement initialisé',
          'payment_method': paymentMethod,
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Erreur de paiement',
          'code': response.statusCode,
          'errors': data['errors'],
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connexion échouée: $e'};
    }
  }

  // ============================================================
  //  1b. LIEN DE PAIEMENT PUBLIC (page Collect / "receive payment")
  // ============================================================

  /// Crée un paiement destiné à être réglé via la page sécurisée NoChPay
  /// (mode Collect). Retourne le lien `authorization_url` à ouvrir ou
  /// partager. La méthode de paiement par défaut est la carte, mais la
  /// page Collect propose aussi Mobile Money et portefeuilles au client.
  Future<Map<String, dynamic>> createSubscriptionPaymentLink({
    required double amount,
    required String currency,
    required String planName,
    String? planId,
    String? userId,
    String? email,
  }) async {
    if (!isPaymentInitiationConfigured) {
      return {
        'success': false,
        'error':
            'Configuration API manquante. Vérifiez votre clé publique NochPay '
            '(NOCHPAY_PUBLIC_KEY).',
      };
    }
    final reference =
        'SUB-${DateTime.now().millisecondsSinceEpoch}';
    return initiatePayment(
      amount: amount,
      currency: currency,
      phoneNumber: '',
      invoiceNumber: reference,
      description: 'Abonnement $planName — NOI OHADA Invoice Pro',
      paymentMethod: methodCard,
      customerName: planId,
      customerEmail: email,
      metadata: {
        'purpose': 'subscription',
        'plan_id': planId ?? '',
        'user_id': userId ?? '',
        'reference': reference,
      },
    );
  }

  /// Correspondances entre méthodes de l'app et canaux USSD NochPay.
  ///
  /// Selon la doc NochPay, le canal USSD suit le format `{pays}.{opérateur}` :
  ///   - cm.mtn, cm.orange (Cameroun)
  ///   - ci.mtn, ci.orange (Côte d'Ivoire)
  ///   - sn.wave, sn.orange (Sénégal)
  ///   - ke.mpesa (Kenya), gh.mtn (Ghana), ug.airtel (Ouganda)
    static String channelForMethod(String method) {
    switch (method) {
      case methodOrangeMoney:
        return 'cm.orange';
      case methodMtnMoney:
        return 'cm.mtn';
      case methodWave:
        return 'sn.wave';
      // ✅ Portefeuilles numériques (docs "Digital Wallets")
      case methodAssoh:
        return 'cm.assoh';
      case methodKudi:
        return 'ci.kudi';
      default:
        return 'cm.orange';
    }
  }

  // ============================================================
  //  2b. PAIEMENT PAR QR CODE
  // ============================================================

  /// Récupère l'URL du QR code d'un paiement via l'API Notch Pay.
  ///
  /// Appelle `GET /payments/{reference}/qrcode` (voir doc "QR Code
  /// Payments"). Le client paie ensuite en scannant le QR code avec son
  /// application mobile bancaire / portefeuille. Un lien de repli (fallback)
  /// est fourni si l'endpoint QR n'est pas disponible, afin de générer
  /// localement un QR code pointant vers la page Collect.
  Future<Map<String, dynamic>> fetchQRCodeUrl({
    required String reference,
    String? fallbackUrl,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$_baseUrl/payments/$reference/qrcode'),
            headers: {'Authorization': _publicKey},
          )
          .timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final qrCodeUrl = data['qr_code_url'] ??
            data['qr_code'] ??
            data['qr'] ??
            data['url'];
        return {
          'success': true,
          'qr_code_url': qrCodeUrl,
          'reference': reference,
        };
      }

      return {
        'success': false,
        'error': data['message'] ?? 'Erreur lors de la génération du QR code',
        'code': response.statusCode,
        // En cas d'échec, on retombe sur la page Collect si fournie.
        'fallback_url': fallbackUrl,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'fallback_url': fallbackUrl,
      };
    }
  }

  /// Déclenche la confirmation MOBILE MONEY via USSD/canal opérateur.
  ///
  /// Appelle `POST /payments/{reference}` avec le canal (`channel`) et le
  /// numéro de téléphone du client. Le client reçoit alors une invite USSD
  /// sur son téléphone (5 à 30 secondes de traitement).
  Future<Map<String, dynamic>> processMobileMoneyUSSD({
    required String reference,
    required String method,
    required String phoneNumber,
  }) async {
    try {
      final channel = channelForMethod(method);
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/payments/$reference'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': _publicKey,
            },
            body: json.encode({
              'channel': channel,
              'data': {
                'phone': phoneNumber,
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final transaction = data['transaction'] as Map<String, dynamic>? ??
            data as Map<String, dynamic>? ??
            const {};
        return {
          'success': true,
          'status': transaction['status'] ?? 'processing',
          'transaction_id': transaction['id'] ?? reference,
          'reference': transaction['reference'] ?? reference,
          'channel': channel,
        };
      }

      return {
        'success': false,
        'error': data['message'] ?? 'Erreur lors de la demande USSD',
        'code': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============================================================
  //  3. VÉRIFICATION DU STATUT (POLLING)
  // ============================================================

    /// Indique si un statut de transaction = paiement réussi.
  ///
  /// Notch Pay utilise `complete` pour un paiement terminé (statut final).
  /// On accepte aussi `paid` par rétro-compatibilité avec l'ancien flux.
  static bool isPaymentSuccessful(String? status) {
    final normalized = status?.toLowerCase();
    return normalized == 'complete' ||
        normalized == 'paid' ||
        normalized == 'success' ||
        normalized == 'successful';
  }

  Future<Map<String, dynamic>> checkPaymentStatus(String reference) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/payments/$reference'),
        headers: {'Authorization': _publicKey},
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 202) {
        final transaction = data['transaction'] as Map<String, dynamic>? ??
            data as Map<String, dynamic>? ??
            const {};
        final status = transaction['status'] ?? 'pending';
        return {
          'success': true,
          'status': status,
          'is_success': isPaymentSuccessful(status),
          'reference': transaction['reference'] ?? reference,
          'amount': transaction['amount'],
          'currency': transaction['currency'],
          'payment_method': transaction['payment_method'],
          'completed_at': transaction['completed_at'],
          'metadata': transaction['metadata'],
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Erreur de vérification',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

    // ============================================================
  //  4. VÉRIFICATION DE LA SIGNATURE D'UN WEBHOOK
  // ============================================================



  bool verifyWebhookSignature(String payload, String signature) {
    // � Vérification HMAC-SHA256 du webhook NochPay.
    // La signature est fournie dans le header 'x-notch-signature' et
    // se présente sous la forme "sha256=<hex digest>".
    try {
      final secret = _webhookSecret;
      if (secret.isEmpty) {
        return false; // Aucun secret configuré → refuser (sécurité stricte)
      }
      final hmac = Hmac(sha256, utf8.encode(secret));
      final digest = hmac.convert(utf8.encode(payload)).toString();

      // Accepte "sha256=<digest>" ou le digest brut.
      final cleanSignature = signature.trim().startsWith('sha256=')
          ? signature.trim().substring('sha256='.length)
          : signature.trim();

      // Comparaison en temps constant pour éviter les attaques temporelles.
      return _constantTimeEquals(digest, cleanSignature);
    } catch (_) {
      return false;
    }
  }

  /// Comparaison de deux chaînes en temps constant.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  // ============================================================

    Future<void> savePendingTransaction({
    required String transactionId,
    required String invoiceId,
    required String invoiceNumber,
    required String phoneNumber,
    required double amount,
    String? authorizationUrl,
    String? reference,
    String? paymentMethod,
  }) async {
    // Utilise `transactionId` comme clé unique (plus fiable que `reference`
    // qui peut être vide dans certains flux d'appel).
    final key = 'pending_transaction_$transactionId';
    await _storage.write(
      key: key,
      value: json.encode({
        'transaction_id': transactionId,
        'reference': reference ?? transactionId,
        'invoice_id': invoiceId,
        'invoice_number': invoiceNumber,
        'phone_number': phoneNumber,
        'amount': amount,
        'authorization_url': authorizationUrl ?? '',
        'payment_method': paymentMethod ?? NochPayService.methodOrangeMoney,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<Map<String, dynamic>?> getPendingTransaction(String transactionId) async {
    final value = await _storage.read(
      key: 'pending_transaction_$transactionId',
    );
    if (value != null) {
      return json.decode(value);
    }
    return null;
  }

  Future<void> removePendingTransaction(String transactionId) async {
    await _storage.delete(key: 'pending_transaction_$transactionId');
  }

  Future<List<Map<String, dynamic>>> getAllPendingTransactions() async {
    final allKeys = await _storage.readAll();
    final pending = <Map<String, dynamic>>[];
    for (final entry in allKeys.entries) {
      if (entry.key.startsWith('pending_transaction_')) {
        try {
          final data = json.decode(entry.value);
          pending.add(data);
        } catch (_) {}
      }
    }
    return pending;
  }

  Future<void> cleanStaleTransactions() async {
    final allKeys = await _storage.readAll();
    final now = DateTime.now();
    for (final entry in allKeys.entries) {
      if (entry.key.startsWith('pending_transaction_')) {
        try {
          final data = json.decode(entry.value);
          final timestamp = DateTime.parse(data['timestamp']);
          if (now.difference(timestamp).inHours > 24) {
            await _storage.delete(key: entry.key);
          }
        } catch (_) {}
      }
    }
  }

  // ============================================================
  //  5. TRAITEMENT DU PAIEMENT RÉUSSI
  // ============================================================

    Future<void> _processSuccessfulPayment(String transactionId) async {
    final pending = await getPendingTransaction(transactionId);
    if (pending != null) {
      await _notificationService.notifyInvoicePaid(pending['invoice_number']);
      await _notificationService
          .notifyPaymentReceived((pending['amount'] as num).toDouble());
      await removePendingTransaction(transactionId);
    }
  }

  Future<Map<String, dynamic>> confirmPaymentWithCode({
    required String transactionId,
    required String confirmationCode,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/payments/$transactionId/confirm'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': _publicKey,
            },
            body: json.encode({'confirmation_code': confirmationCode}),
          )
          .timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'paid') {
        await _processSuccessfulPayment(transactionId);
        return {'success': true, 'status': 'paid'};
      }
      return {'success': false, 'error': data['error'] ?? 'Code invalide'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Future<Map<String, dynamic>> checkPaymentStatus(String reference) async {
  //   if (!isConfigured) {
  //     return {'success': false, 'error': 'Configuration API manquante.'};
  //   }

  //   try {
  //     final response = await _client.get(
  //       Uri.parse('$_baseUrl/payments/$reference/status'),
  //       headers: {'Authorization': 'Bearer $_privateKey'},
  //     ).timeout(const Duration(seconds: 10));

  //     final data = json.decode(response.body);
  //     if (response.statusCode == 200) {
  //       return {
  //         'success': true,
  //         'status': data['status'] ?? 'pending',
  //         'transaction': data,
  //       };
  //     }
  //     return {
  //       'success': false,
  //       'error': data['message'] ?? 'Erreur de vérification',
  //     };
  //   } catch (e) {
  //     return {'success': false, 'error': e.toString()};
  //   }
  // }
  // ============================================================
  //  6. NETTOYAGE
  // ============================================================
}
