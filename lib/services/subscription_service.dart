// lib/services/subscription_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification.dart';
import '../models/subscription.dart';
import '../models/plan.dart';
import '../services/notification_service.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Obtenir l'abonnement actif d'un utilisateur
  Future<Subscription?> getUserSubscription(String userId) async {
    try {
      final query = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Subscription.fromMap(query.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Erreur get user subscription: $e');
      return null;
    }
  }

  // Obtenir tous les abonnements d'un utilisateur
  Future<List<Subscription>> getUserSubscriptions(String userId) async {
    try {
      final query = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .orderBy('startDate', descending: true)
          .get();

      return query.docs
          .map((doc) => Subscription.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Erreur get user subscriptions: $e');
      return [];
    }
  }

  // Obtenir tous les abonnements actifs (pour vérification périodique)
  Future<List<Subscription>> getActiveSubscriptions() async {
    try {
      final query = await _firestore
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .get();

      return query.docs.map((doc) => Subscription.fromMap(doc.data())).toList();
    } catch (e) {
      print('Erreur get active subscriptions: $e');
      return [];
    }
  }

  // Créer un abonnement
  Future<Subscription> createSubscription({
    required String userId,
    required String planId,
    required String paymentMethod,
    required String paymentId,
    required double amount,
    required String currency,
    required String interval,
  }) async {
    try {
      final plan = await getPlan(planId);
      if (plan == null) {
        throw Exception('Plan non trouvé');
      }

      final startDate = DateTime.now();
      final endDate = interval == 'year'
          ? DateTime(startDate.year + 1, startDate.month, startDate.day)
          : DateTime(startDate.year, startDate.month + 1, startDate.day);

      final subscription = Subscription(
        id: _firestore.collection('subscriptions').doc().id,
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
      );

      await _firestore
          .collection('subscriptions')
          .doc(subscription.id)
          .set(subscription.toMap());

      await _firestore.collection('users').doc(userId).update({
        'subscriptionId': subscription.id,
      });

      // ✅ Notification d'activation
      await _notificationService.addNotification(
        AppNotification(
          title: '🎉 Abonnement activé',
          body: 'Votre abonnement ${plan.name} est maintenant actif.',
          type: NotificationType.subscription_activated.toString(),
          referenceId: subscription.id,
          referenceType: 'subscription',
        ),
      );

      return subscription;
    } catch (e) {
      // Notification d'échec
      await _notificationService.addNotification(
        AppNotification(
          title: '⚠️ Échec de l\'activation',
          body: 'L\'activation de votre abonnement a échoué. Veuillez réessayer.',
          type: NotificationType.system_update.toString(),
        ),
      );
      throw Exception('Erreur création abonnement: $e');
    }
  }

  // Annuler un abonnement
  Future<void> cancelSubscription(String subscriptionId) async {
    try {
      await _firestore.collection('subscriptions').doc(subscriptionId).update({
        'status': 'canceled',
        'autoRenew': false,
        'canceledAt': FieldValue.serverTimestamp(),
      });

      // ✅ Notification d'annulation
      await _notificationService.addNotification(
        AppNotification(
          title: '📌 Abonnement annulé',
          body: 'Votre abonnement a été annulé avec succès.',
          type: NotificationType.system_update.toString(),
          referenceId: subscriptionId,
          referenceType: 'subscription',
        ),
      );
    } catch (e) {
      throw Exception('Erreur annulation abonnement: $e');
    }
  }

  // Renouveler un abonnement
  Future<void> renewSubscription(String subscriptionId) async {
    try {
      final doc = await _firestore.collection('subscriptions').doc(subscriptionId).get();
      if (!doc.exists) {
        throw Exception('Abonnement non trouvé');
      }

      final subscription = Subscription.fromMap(doc.data()!);
      final newEndDate = DateTime(
        subscription.endDate.year,
        subscription.endDate.month + 1,
        subscription.endDate.day,
      );

      await _firestore.collection('subscriptions').doc(subscriptionId).update({
        'endDate': newEndDate,
        'status': 'active',
      });

      // ✅ Notification de renouvellement
      final plan = await getPlan(subscription.planId);
      await _notificationService.addNotification(
        AppNotification(
          title: '🔄 Abonnement renouvelé',
          body: 'Votre abonnement ${plan?.name ?? ''} a été renouvelé jusqu\'au ${_formatDate(newEndDate)}.',
          type: NotificationType.system_update.toString(),
          referenceId: subscriptionId,
          referenceType: 'subscription',
        ),
      );
    } catch (e) {
      throw Exception('Erreur renouvellement abonnement: $e');
    }
  }

  // Obtenir un plan
  Future<Plan?> getPlan(String planId) async {
    try {
      final doc = await _firestore.collection('plans').doc(planId).get();
      if (doc.exists) {
        return Plan.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Erreur get plan: $e');
      return null;
    }
  }

  // Obtenir tous les plans
  Future<List<Plan>> getPlans() async {
    try {
      final query = await _firestore
          .collection('plans')
          .where('isActive', isEqualTo: true)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.map((doc) => Plan.fromMap(doc.data())).toList();
      }
      
      return Plan.getDefaultPlans();
    } catch (e) {
      print('Erreur get plans: $e');
      return Plan.getDefaultPlans();
    }
  }

  // Initialiser les plans par défaut dans Firestore
  Future<void> initializeDefaultPlans() async {
    try {
      final existing = await _firestore.collection('plans').get();
      if (existing.docs.isEmpty) {
        final plans = Plan.getDefaultPlans();
        for (final plan in plans) {
          await _firestore.collection('plans').doc(plan.id).set(plan.toMap());
        }
        print('Plans par défaut créés avec succès');
      }
    } catch (e) {
      print('Erreur initialization plans: $e');
    }
  }

  // Vérifier si l'utilisateur a dépassé la limite de factures
  Future<bool> hasReachedInvoiceLimit(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) return true;

      final plan = await getPlan(subscription.planId);
      if (plan == null) return true;
      if (!plan.hasInvoiceLimit) return false;

      final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final endOfMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 1);

      final query = await _firestore
          .collection('invoices')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: startOfMonth)
          .where('createdAt', isLessThan: endOfMonth)
          .get();

      return query.size >= plan.maxInvoices;
    } catch (e) {
      print('Erreur vérification limite: $e');
      return true;
    }
  }

  // Vérifier si l'utilisateur a dépassé la limite de clients
  Future<bool> hasReachedClientLimit(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) return true;

      final plan = await getPlan(subscription.planId);
      if (plan == null) return true;
      if (!plan.hasClientLimit) return false;

      final query = await _firestore
          .collection('clients')
          .where('userId', isEqualTo: userId)
          .get();

      return query.size >= plan.maxClients;
    } catch (e) {
      print('Erreur vérification limite clients: $e');
      return true;
    }
  }

  // ===== UTILITAIRES =====
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}