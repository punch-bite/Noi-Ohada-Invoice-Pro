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

  /// Liste de toutes les méthodes de paiement supportées.
  static const List<String> supportedMethods = [
    methodOrangeMoney,
    methodMtnMoney,
    methodWave,
    methodCard,
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
  //  2. VÉRIFICATION DU STATUT (POLLING)
  // ============================================================

  Future<Map<String, dynamic>> checkPaymentStatus(String reference) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/payments/$reference'),
        headers: {'Authorization': _publicKey},
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        final transaction = data['transaction'] as Map<String, dynamic>;
        return {
          'success': true,
          'status': transaction['status'],
          'reference': transaction['reference'],
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
  //  3. VÉRIFICATION DE LA SIGNATURE D'UN WEBHOOK
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
  //  4. GESTION DES TRANSACTIONS EN ATTENTE
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

  void dispose() => _client.close();
}
