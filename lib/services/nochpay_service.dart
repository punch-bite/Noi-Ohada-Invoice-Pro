// lib/services/nochpay_service.dart
import 'dart:convert';
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
      ? 'https://api.nochpay.co'
      : 'https://api-sandbox.nochpay.co';

  // 🔥 Clés depuis ConfigService (ou dotenv directement)
  static String get _publicKey => ConfigService.nochpayPublicKey; // pk_...
  static String get _privateKey => ConfigService.nochpayPrivateKey; // sk_...
  static String get _webhookSecret =>
      ConfigService.nochpayWebhookSecret; // whsec_...

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final NotificationService _notificationService = NotificationService();
  final http.Client _client = http.Client();

  bool get isConfigured => _publicKey.isNotEmpty && _privateKey.isNotEmpty;

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
    if (!isConfigured) {
      return {
        'success': false,
        'error': 'Configuration API manquante. Vérifiez vos clés NochPay.',
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
      // 🔥 Construction du payload enrichi
      final payload = {
        'amount': amount,
        'currency': currency,
        'payment_method': paymentMethod,
        'customer': {
          'name': customerName ?? 'Client',
          'email': customerEmail ?? 'client@email.com',
          'phone': phoneNumber,
        },
        'description': description,
        'reference': invoiceNumber,
        'callback': '${ConfigService.apiBaseUrl}/payment/callback',
        // 🔥 Métadonnées pour suivi
        'customer_meta': {
          'invoice_number': invoiceNumber,
          'source': 'noi_ohada_invoice_app',
          'payment_method': paymentMethod,
          if (metadata != null) ...metadata,
        },
        // 🔥 Détails des articles (si fournis)
        if (items != null) 'items': items,
        // 🔥 Mode (sandbox/production)
        'mode': ConfigService.isProduction ? 'production' : 'sandbox',
      };

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/payments'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': _publicKey,
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final transaction = data['transaction'] as Map<String, dynamic>;
        return {
          'success': true,
          'transaction_id': (transaction['id'] ?? transaction['reference']),
          'reference': transaction['reference'],
          'authorization_url': data['authorization_url'],
          'status': transaction['status'],
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
  //  2. TRAITEMENT MOBILE MONEY PAR USSD
  // ============================================================

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
    // 🔥 TODO: Implémenter la vérification HMAC-SHA256
    // La signature est dans le header 'x-notch-signature'
    // Utiliser _webhookSecret pour vérifier
    // Implémentation :
    // final hmac = Hmac(sha256, utf8.encode(_webhookSecret));
    // final digest = hmac.convert(utf8.encode(payload));
    // return digest.toString() == signature;
    return true; // À remplacer par la vérification réelle
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
      final response = await _client.post(
        Uri.parse('$_baseUrl/payments/$transactionId/confirm'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _publicKey,
        },
        body: json.encode({'confirmation_code': confirmationCode}),
      );

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
