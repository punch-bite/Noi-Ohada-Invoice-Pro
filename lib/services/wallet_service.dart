// lib/services/wallet_service.dart
//
// 💰 Portefeuille marchand : quand un client paie une facture EN LIGNE (ENKAP),
// l'argent est encaissé sur le compte ENKAP de la PLATEFORME. Le portefeuille
// interne crédite alors le marchand du montant. Le marchand demande un retrait,
// la plateforme le paie (portail ENKAP / banque) puis met à jour le statut.
//
// 🔒 SÉCURITÉ : le solde n'est PLUS modifiable par le client. Le crédit passe
// par le serveur (POST /wallet/credit) qui VÉRIFIE la confirmation E-nkap
// avant de créditer — un utilisateur ne peut pas s'auto-créditer.
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config_service.dart';

class WalletService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===== PORTEFEUILLE =====

  /// Solde actuel du portefeuille d'un utilisateur (0 si absent).
  Future<double> getBalance(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      final doc = await _db.collection('wallets').doc(userId).get();
      return (doc.data()?['balance'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      debugPrint('⚠️ getBalance: $e');
      return 0;
    }
  }

  /// Crédite le portefeuille de façon sécurisée et journalise la transaction.
  ///
  /// 🔒 Le crédit passe par le SERVEUR (`POST /wallet/credit`) qui vérifie
  /// auprès d'E-nkap que la commande est bien CONFIRMÉE avant de créditer
  /// (le client ne peut plus s'auto-créditer un solde arbitraire).
  /// Appelé après la confirmation d'un paiement en ligne (ENKAP).
  Future<bool> credit({
    required String userId,
    required double amount,
    required String reference,
    required String description,
  }) async {
    if (userId.isEmpty || amount <= 0) return false;
    final apiBase = ConfigService.apiBaseUrl.trim();
    if (apiBase.isEmpty) return false;
    try {
      final resp = await http
          .post(
            Uri.parse('$apiBase/wallet/credit'),
            headers: ConfigService.serverHeaders(),
            body: jsonEncode({
              'userId': userId,
              'amount': amount,
              'reference': reference,
              'description': description,
            }),
          )
          .timeout(const Duration(seconds: 25));
      final ok = resp.statusCode == 200;
      if (!ok) {
        debugPrint(
            '⚠️ credit wallet serveur: ${resp.statusCode} ${resp.body}');
      }
      return ok;
    } catch (e) {
      debugPrint('⚠️ credit wallet serveur (réseau): $e');
      return false;
    }
  }

  /// Historique des transactions (crédits) du portefeuille.
  Future<List<Map<String, dynamic>>> getTransactions(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final snap = await _db
          .collection('wallet_transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    } catch (e) {
      debugPrint('⚠️ getTransactions: $e');
      return [];
    }
  }

  // ===== RETRAIT (géré par la plateforme) =====

  /// Crée une demande de retrait (statut `pending`). La plateforme la traite
  /// ensuite (paiement via portail ENKAP / banque) puis passe au statut payé.
  Future<bool> requestWithdrawal({
    required String userId,
    required double amount,
    required String phone,
  }) async {
    if (userId.isEmpty || amount <= 0 || phone.isEmpty) return false;
    try {
      final balance = await getBalance(userId);
      if (amount > balance) return false;
      await _db.collection('wallet_withdrawals').add({
        'userId': userId,
        'amount': amount,
        'phone': phone,
        'currency': 'XAF',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ requestWithdrawal: $e');
      return false;
    }
  }

  /// Demandes de retrait de l'utilisateur.
  Future<List<Map<String, dynamic>>> getWithdrawals(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final snap = await _db
          .collection('wallet_withdrawals')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    } catch (e) {
      debugPrint('⚠️ getWithdrawals: $e');
      return [];
    }
  }

  // ===== ADMIN : traitement des demandes de retrait =====

  /// [ADMIN] Toutes les demandes de retrait (option : filtrer par statut).
  Future<List<Map<String, dynamic>>> getAllWithdrawals({
    String? status,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db.collection('wallet_withdrawals');
      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }
      final snap = await query
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();
      return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    } catch (e) {
      debugPrint('⚠️ getAllWithdrawals: $e');
      return [];
    }
  }

  /// [ADMIN] Traite une demande de retrait (paid / rejected).
  /// Si le retrait passe à `paid`, le solde du portefeuille est décrémenté
  /// et une transaction `withdrawal` est journalisée.
  Future<bool> setWithdrawalStatus({
    required String withdrawalId,
    required String status,
    required String processedBy,
  }) async {
    if (withdrawalId.isEmpty) return false;
    try {
      final ref = _db.collection('wallet_withdrawals').doc(withdrawalId);
      final snap = await ref.get();
      final data = snap.data();
      if (data == null) return false;

      final userId = data['userId']?.toString() ?? '';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final wasPaid = data['status'] == 'paid';
      final phone = data['phone']?.toString() ?? '';

      await ref.update({
        'status': status,
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': processedBy,
      });

      // Paiement du retrait : décrément du solde + journalisation.
      if (status == 'paid' && !wasPaid && userId.isNotEmpty && amount > 0) {
        final walletRef = _db.collection('wallets').doc(userId);
        await _db.runTransaction((tx) async {
          final ws = await tx.get(walletRef);
          final current = (ws.data()?['balance'] as num?)?.toDouble() ?? 0;
          tx.set(
            walletRef,
            {
              'userId': userId,
              'balance': (current - amount).clamp(0, double.infinity),
              'currency': 'XAF',
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        });
        await _db.collection('wallet_transactions').add({
          'userId': userId,
          'type': 'withdrawal',
          'amount': amount,
          'currency': 'XAF',
          'reference': withdrawalId,
          'description': 'Retrait vers ${phone.isEmpty ? 'Mobile Money' : phone}',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ setWithdrawalStatus: $e');
      return false;
    }
  }
}
