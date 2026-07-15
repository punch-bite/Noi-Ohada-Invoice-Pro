// lib/services/nochpay_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/notification_service.dart';

class NochPayService {
  static const String _baseUrl = 'https://api.nochpay.com/v1';

  // 🔥 Récupération des clés depuis .env
  static String get _apiKey => dotenv.env['NOCHPAY_API_KEY'] ?? '';
  static String get _publicKey => dotenv.env['NOCHPAY_PUBLIC_KEY'] ?? '';
  static String get _webhookSecret => dotenv.env['NOCHPAY_WEBHOOK_SECRET'] ?? '';
  static String get _mode => dotenv.env['NOCHPAY_MODE'] ?? 'sandbox';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final NotificationService _notificationService = NotificationService();

  // Pour éviter les notifications en double
  final Set<String> _notifiedTransactions = {};

  // Vérifier que les clés sont bien définies
  bool get isConfigured => _apiKey.isNotEmpty && _publicKey.isNotEmpty;

  /// Retourne le mode en cours (sandbox / live)
  String get mode => _mode;

  Future<Map<String, dynamic>> initiatePayment({
    required double amount,
    required String currency,
    required String phoneNumber,
    required String invoiceNumber,
    required String description,
  }) async {
    if (!isConfigured) {
      return {
        'success': false,
        'error': 'NochPay non configuré. Vérifiez vos clés API.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/payments/initiate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'amount': amount,
          'currency': currency,
          'phone_number': phoneNumber,
          'invoice_number': invoiceNumber,
          'description': description,
          'mode': _mode,
          'callback_url': 'https://ohada-invoice-pro.com/payment/callback',
          'return_url': 'https://ohada-invoice-pro.com/payment/return',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'transaction_id': data['transaction_id'],
          'payment_url': data['payment_url'],
          'status': data['status'],
          'confirmation_code': data['confirmation_code'] ?? '',
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur de paiement: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur: $e',
      };
    }
  }

  Future<Map<String, dynamic>> checkPaymentStatus(String transactionId) async {
    if (!isConfigured) {
      return {
        'success': false,
        'error': 'NochPay non configuré.',
      };
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/payments/$transactionId/status'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'status': data['status'],
          'paid_at': data['paid_at'],
          'confirmation_code': data['confirmation_code'] ?? '',
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur: $e',
      };
    }
  }

  Future<Map<String, dynamic>> confirmPaymentWithCode({
    required String transactionId,
    required String confirmationCode,
  }) async {
    if (!isConfigured) {
      return {
        'success': false,
        'error': 'NochPay non configuré.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/payments/$transactionId/confirm'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({'confirmation_code': confirmationCode}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'];
        final message = data['message'] ?? 'Paiement confirmé';

        // Si le paiement est confirmé avec succès
        if (status == 'paid') {
          final pending = await getPendingTransaction(transactionId);
          if (pending != null) {
            final invoiceNumber = pending['invoice_number'] ?? '';
            final amount = pending['amount'] ?? 0.0;

            if (!_notifiedTransactions.contains(transactionId)) {
              _notifiedTransactions.add(transactionId);

              if (invoiceNumber.isNotEmpty) {
                await _notificationService.notifyInvoicePaid(invoiceNumber);
              }

              if (amount > 0) {
                await _notificationService.notifyPaymentReceived(amount);
              }

              await removePendingTransaction(transactionId);
            }
          }
        }

        return {
          'success': true,
          'status': status,
          'message': message,
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'error': data['error'] ?? 'Erreur de confirmation',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur: $e',
      };
    }
  }

  Future<void> savePendingTransaction({
    required String transactionId,
    required String invoiceId,
    required String invoiceNumber,
    required String phoneNumber,
    required double amount,
  }) async {
    await _storage.write(
      key: 'pending_transaction_$transactionId',
      value: json.encode({
        'transaction_id': transactionId,
        'invoice_id': invoiceId,
        'invoice_number': invoiceNumber,
        'phone_number': phoneNumber,
        'amount': amount,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<Map<String, dynamic>?> getPendingTransaction(String transactionId) async {
    final value = await _storage.read(key: 'pending_transaction_$transactionId');
    if (value != null) {
      return json.decode(value);
    }
    return null;
  }

  Future<void> removePendingTransaction(String transactionId) async {
    await _storage.delete(key: 'pending_transaction_$transactionId');
  }
}