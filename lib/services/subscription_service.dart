// lib/services/subscription_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../models/subscription.dart';
import '../models/plan.dart';
import '../services/notification_service.dart';

class SubscriptionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Cache mémoire pour éviter les lectures Firestore inutiles
  final Map<String, Plan> _planCache = {};

  // --- Lecture optimisée avec support du cache ---
  Future<Plan?> getPlan(String planId) async {
    if (_planCache.containsKey(planId)) return _planCache[planId];

    final doc = await _db.collection('plans').doc(planId).get();
    if (doc.exists) {
      final plan = Plan.fromMap({...doc.data()!, 'id': doc.id});
      _planCache[planId] = plan;
      return plan;
    }
    return null;
  }

  // --- Lecture optimisée (Indexée) ---
  Future<Subscription?> getUserSubscription(String userId) async {
    final query = await _db
        .collection('subscriptions')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    return query.docs.isNotEmpty
        ? Subscription.fromMap(
            {...query.docs.first.data(), 'id': query.docs.first.id})
        : null;
  }

  Future<bool> hasUnlimitedAccess(String userId) async {
    // Vérifier si l'utilisateur est admin
    final user = await _db.collection('users').doc(userId).get();
    final roles = List<String>.from(user.data()?['roles'] ?? ['user']);
    if (roles.contains('admin')) return true;

    // Vérifier si l'abonnement est "unlimited"
    final subscription = await getUserSubscription(userId);
    return subscription?.planId == 'unlimited';
  }

  // --- Écritures sécurisées ---
  Future<Subscription> createSubscription({
    required String userId,
    required String planId,
    required String paymentMethod,
    required String paymentId,
    required double amount,
    required String currency,
    required String interval,
  }) async {
    final plan = await getPlan(planId) ?? Plan.getFreePlan();

    try {
      return await _db.runTransaction((transaction) async {
        final subRef = _db.collection('subscriptions').doc();
        final userRef = _db.collection('users').doc(userId);

        final startDate = DateTime.now();
        final endDate =
            startDate.add(Duration(days: interval == 'year' ? 365 : 30));

        final sub = Subscription(
          id: subRef.id,
          userId: userId,
          planId: planId,
          startDate: startDate,
          endDate: endDate,
          status: 'active',
          paymentMethod: paymentMethod,
          paymentId: paymentId,
          amount: amount,
          currency: currency,
          autoRenew: true,
          isActive: true,
          createdAt: DateTime.now(), interval: '',
        );

        transaction.set(subRef, sub.toMap());
        transaction.update(userRef, {'subscriptionId': subRef.id});
        return sub;
      }).then((sub) async {
        await _notifications.addNotification(_buildNotif('🎉 Abonnement activé',
            'Votre abonnement ${plan.name} est actif.', sub.id));
        return sub;
      });
    } catch (e) {
      await _notifications.addNotification(
          _buildNotif('⚠️ Échec activation', 'L\'activation a échoué.'));
      throw Exception('Transaction échouée: $e');
    }
  }

  // ===== RENOUVELLEMENT D'ABONNEMENT =====

  /// Renouvelle un abonnement existant
  Future<void> renewSubscription(String subscriptionId) async {
    try {
      // Récupérer l'abonnement actuel
      final doc = await _db.collection('subscriptions').doc(subscriptionId).get();
      if (!doc.exists) {
        throw Exception('Abonnement non trouvé');
      }

      final subscription = Subscription.fromMap({...doc.data()!, 'id': doc.id});
      final plan = await getPlan(subscription.planId);
      if (plan == null) {
        throw Exception('Plan non trouvé');
      }

      // Calculer la nouvelle date de fin
      final now = DateTime.now();
      final newEndDate = now.add(
        Duration(days: subscription.interval == 'year' ? 365 : 30),
      );

      // Mettre à jour l'abonnement
      await _db.collection('subscriptions').doc(subscriptionId).update({
        'endDate': newEndDate,
        'status': 'active',
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'metadata': {
          'renewedAt': FieldValue.serverTimestamp(),
          'renewedFrom': subscription.endDate.toIso8601String(),
        },
      });

      // Notification de renouvellement
      await _notifications.addNotification(_buildNotif(
        '🔄 Abonnement renouvelé',
        'Votre abonnement ${plan.name} a été renouvelé jusqu\'au ${_formatDate(newEndDate)}.',
        subscriptionId,
      ));

      debugPrint('✅ Abonnement $subscriptionId renouvelé avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors du renouvellement: $e');
      throw Exception('Impossible de renouveler l\'abonnement: $e');
    }
  }

  // ===== ANNULATION =====

  /// Annule un abonnement
  Future<void> cancelSubscription(String subscriptionId) async {
    try {
      // Récupérer l'abonnement pour avoir des infos pour la notification
      final doc = await _db.collection('subscriptions').doc(subscriptionId).get();
      if (!doc.exists) {
        throw Exception('Abonnement non trouvé');
      }

      final subscription = Subscription.fromMap({...doc.data()!, 'id': doc.id});
      final plan = await getPlan(subscription.planId);

      await _db.collection('subscriptions').doc(subscriptionId).update({
        'status': 'canceled',
        'autoRenew': false,
        'isActive': false,
        'canceledAt': FieldValue.serverTimestamp(),
        'metadata': {
          'canceledAt': FieldValue.serverTimestamp(),
          'canceledBy': 'user',
        },
      });

      await _notifications.addNotification(_buildNotif(
        '📌 Abonnement annulé',
        'Votre abonnement ${plan?.name ?? ''} a été annulé avec succès.',
        subscriptionId,
      ));

      debugPrint('✅ Abonnement $subscriptionId annulé avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'annulation: $e');
      throw Exception('Impossible d\'annuler l\'abonnement: $e');
    }
  }

  // ===== LISTE DES ABONNEMENTS ACTIFS =====

  Future<List<Subscription>> getActiveSubscriptions() async {
    try {
      final querySnapshot = await _db
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .get();

      return querySnapshot.docs.map((doc) {
        return Subscription.fromMap({...doc.data(), 'id': doc.id});
      }).toList();
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des abonnements actifs: $e');
      return [];
    }
  }

  // --- Vérification des limites (Performance) ---
  Future<bool> hasReachedInvoiceLimit(String userId) async {
    final sub = await getUserSubscription(userId);
    if (sub == null) return true;

    final plan = await getPlan(sub.planId);
    if (plan == null || !plan.hasInvoiceLimit) return false;

    final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

    // .count() est la méthode la plus légère (ne télécharge aucun document)
    final snapshot = await _db
        .collection('invoices')
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: startOfMonth)
        .count()
        .get();

    return (snapshot.count ?? 0) >= plan.maxInvoices;
  }

  // ===== MÉTHODE POUR RÉCUPÉRER TOUS LES PLANS =====

  /// Récupère la liste des plans d'abonnement disponibles
  Future<List<Plan>> getPlans() async {
    try {
      final snapshot = await _firestore
          .collection('plans')
          .orderBy('price') // Tri par prix par exemple
          .get();
      return snapshot.docs.map((doc) => Plan.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint("Erreur récupération plans : $e");
      return [];
    }
  }

  // ===== UTILITAIRES =====

  AppNotification _buildNotif(String title, String body, [String? refId]) =>
      AppNotification(
        title: title,
        body: body,
        type: 'subscription_update',
        referenceId: refId,
        referenceType: 'subscription',
      );

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // ===== VÉRIFICATION DES LIMITES =====

  Future<bool> hasReachedClientLimit(String userId) async {
    final sub = await getUserSubscription(userId);
    if (sub == null) return true;

    final plan = await getPlan(sub.planId);
    if (plan == null || !plan.hasClientLimit) return false;

    final snapshot = await _db
        .collection('clients')
        .where('userId', isEqualTo: userId)
        .count()
        .get();

    return (snapshot.count ?? 0) >= plan.maxClients;
  }
}