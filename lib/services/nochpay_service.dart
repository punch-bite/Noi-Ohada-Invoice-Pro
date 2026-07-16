import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/notification_service.dart';

class NochPayService {
  static const String _baseUrl = 'https://api.nochpay.com/v1';
  
  // Utilisation de getters statiques sécurisés
  static String get _apiKey => dotenv.env['NOCHPAY_API_KEY'] ?? '';
  static String get _mode => dotenv.env['NOCHPAY_MODE'] ?? 'sandbox';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final NotificationService _notificationService = NotificationService();
  final http.Client _client = http.Client();

  bool get isConfigured => _apiKey.isNotEmpty;

  // --- Méthodes API ---

  Future<Map<String, dynamic>> initiatePayment({
    required double amount,
    required String currency,
    required String phoneNumber,
    required String invoiceNumber,
    required String description,
  }) async {
    if (!isConfigured) return {'success': false, 'error': 'Configuration API manquante.'};

    try {
      final response = await _client.post(
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
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);
      return (response.statusCode == 200 || response.statusCode == 201)
          ? {'success': true, ...data}
          : {'success': false, 'error': data['message'] ?? 'Erreur lors de l\'initialisation'};
    } catch (e) {
      return {'success': false, 'error': 'Connexion échouée: $e'};
    }
  }

  /// Vérifie le statut d'une transaction (Polling)
  Future<Map<String, dynamic>> checkPaymentStatus(String transactionId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/payments/$transactionId/status'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      return {'success': true, 'status': data['status']}; // ex: 'paid', 'pending', 'failed'
    } catch (e) {
      return {'success': false, 'error': e.toString()};
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
          'Authorization': 'Bearer $_apiKey',
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

  // --- Logique métier et Persistence ---

  Future<void> _processSuccessfulPayment(String transactionId) async {
    final pending = await getPendingTransaction(transactionId);
    if (pending != null) {
      await _notificationService.notifyInvoicePaid(pending['invoice_number']);
      await _notificationService.notifyPaymentReceived((pending['amount'] as num).toDouble());
      await removePendingTransaction(transactionId);
    }
  }

  Future<void> savePendingTransaction({
    required String transactionId,
    required String invoiceId,
    required String invoiceNumber,
    required double amount,
    required String phoneNumber,
  }) async {
    await _storage.write(
      key: 'txn_$transactionId',
      value: json.encode({
        'invoice_id': invoiceId,
        'invoice_number': invoiceNumber,
        'amount': amount,
        'ts': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<Map<String, dynamic>?> getPendingTransaction(String tid) async {
    final val = await _storage.read(key: 'txn_$tid');
    return val != null ? json.decode(val) : null;
  }

  Future<void> removePendingTransaction(String tid) async {
    await _storage.delete(key: 'txn_$tid');
  }
      
  void dispose() => _client.close();
}