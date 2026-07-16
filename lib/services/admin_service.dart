// lib/services/admin_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user.dart';
import '../models/subscription.dart';
import '../models/activity_log.dart';
import '../models/plan.dart';
import 'subscription_service.dart';
import 'cloud_access_service.dart';
import 'logger_service.dart';

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SubscriptionService _subscriptionService = SubscriptionService();
  final CloudAccessService _cloudAccess = CloudAccessService();

  // ============================================================
  //  UTILISATEURS
  // ============================================================

  Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) => AppUser.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint("❌ Erreur getAllUsers: $e");
      return [];
    }
  }

  Future<AppUser?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) return AppUser.fromMap(doc.data()!);
      return null;
    } catch (e) {
      debugPrint("❌ Erreur getUserById: $e");
      return null;
    }
  }

  Future<void> updateUser(AppUser user) async {
    await _firestore.runTransaction((transaction) async {
      final userRef = _firestore.collection('users').doc(user.id);
      final logRef = _firestore.collection('logs').doc();
      transaction.update(userRef, user.toMap());
      transaction.set(
          logRef,
          ActivityLog.create(
            userId: user.id,
            userEmail: user.email,
            action: 'update_user',
            targetId: user.id,
            targetType: 'user',
            details: {
              'displayName': user.displayName,
              'isActive': user.isActive
            },
          ).toMap());
    });
  }

  Future<void> toggleUserActive(String userId, bool isActive) async {
    await _firestore.collection('users').doc(userId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await LoggerService.info('toggle_user_active',
        details: 'User $userId actif: $isActive');
  }

  Future<void> updateUserRoles(String userId, List<String> newRoles) async {
    await _firestore.collection('users').doc(userId).update({
      'roles': newRoles,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await LoggerService.info('update_user_roles',
        details: 'User $userId roles: $newRoles');
  }

  // ============================================================
  //  ABONNEMENTS
  // ============================================================

  Future<List<Subscription>> getUserSubscriptions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs
          .map((doc) => Subscription.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      debugPrint("❌ Erreur getUserSubscriptions: $e");
      return [];
    }
  }

  Future<void> cancelSubscription(String subscriptionId,
      {String? reason}) async {
    await _firestore.collection('subscriptions').doc(subscriptionId).update({
      'status': 'canceled',
      'isActive': false,
      'canceledAt': FieldValue.serverTimestamp(),
      'metadata': {
        'adminCanceled': true,
        'reason': reason ?? 'Annulation par administrateur',
      },
    });
    await LoggerService.info('cancel_subscription',
        details: 'Abonnement $subscriptionId annulé');
  }

  Future<void> extendSubscription(String subscriptionId, int days) async {
    final subRef = _firestore.collection('subscriptions').doc(subscriptionId);
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(subRef);
      if (!doc.exists) throw Exception('Abonnement introuvable');
      final sub = Subscription.fromMap(doc.data()!);
      final newEndDate = sub.endDate.add(Duration(days: days));
      transaction.update(subRef, {
        'endDate': newEndDate,
        'status': 'active',
      });
      transaction.set(
          _firestore.collection('logs').doc(),
          ActivityLog.create(
            userId: sub.userId,
            userEmail: 'admin',
            action: 'admin_extend_subscription',
            targetId: subscriptionId,
            targetType: 'subscription',
            details: {'days': days, 'newEndDate': newEndDate.toIso8601String()},
          ).toMap());
    });
  }

  Future<void> changeUserPlan(String subscriptionId, String newPlanId) async {
    await _firestore.collection('subscriptions').doc(subscriptionId).update({
      'planId': newPlanId,
      'updatedAt': FieldValue.serverTimestamp(),
      'metadata': {
        'planChangedByAdmin': true,
        'changedAt': FieldValue.serverTimestamp(),
      },
    });
    await LoggerService.info('change_user_plan',
        details: 'Sub $subscriptionId -> plan $newPlanId');
  }

  /// Crée un abonnement pour un utilisateur (admin)
  Future<void> createSubscriptionForUser({
    required String userId,
    required String planId,
    required int durationMonths,
    required String paymentMethod,
    required double amount,
    required String currency,
    required String interval,
    String? paymentId,
  }) async {
    final newId = _firestore.collection('subscriptions').doc().id;
    final now = DateTime.now();
    final endDate = now.add(Duration(days: durationMonths * 30));
    final subscription = Subscription(
      id: newId,
      userId: userId,
      planId: planId,
      startDate: now,
      endDate: endDate,
      status: 'active',
      paymentMethod: paymentMethod,
      paymentId: paymentId ?? 'admin_${now.millisecondsSinceEpoch}',
      amount: amount,
      currency: currency,
      autoRenew: true,
      isActive: true,
      createdAt: now,
      metadata: {'createdByAdmin': true},
    );
    await _firestore
        .collection('subscriptions')
        .doc(newId)
        .set(subscription.toMap());
    await _firestore.collection('users').doc(userId).update({
      'subscriptionId': newId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await LoggerService.info('create_subscription_admin',
        details: 'Abonnement créé pour $userId');
  }

  // ============================================================
  //  PLANS PERSONNALISÉS (NOUVEAU)
  // ============================================================

  /// Récupère tous les plans (par défaut + personnalisés)
  Future<List<Plan>> getAllPlans() async {
    try {
      final snapshot = await _firestore.collection('plans').get();
      if (snapshot.docs.isEmpty) return Plan.getDefaultPlans();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Plan.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint("❌ Erreur getAllPlans: $e");
      return Plan.getDefaultPlans();
    }
  }

  /// Crée un plan personnalisé
  Future<void> createPlan(Plan plan) async {
    await _firestore.collection('plans').doc(plan.id).set(plan.toMap());
    await LoggerService.info('create_plan', details: 'Plan ${plan.name} créé');
  }

  /// Met à jour un plan
  Future<void> updatePlan(Plan plan) async {
    await _firestore.collection('plans').doc(plan.id).update(plan.toMap());
    await LoggerService.info('update_plan',
        details: 'Plan ${plan.name} mis à jour');
  }

  /// Supprime un plan (soft delete)
  Future<void> deletePlan(String planId) async {
    await _firestore
        .collection('plans')
        .doc(planId)
        .update({'isActive': false});
    await LoggerService.info('delete_plan', details: 'Plan $planId désactivé');
  }

  /// Supprime définitivement un plan
  Future<void> deletePlanPermanently(String planId) async {
    await _firestore.collection('plans').doc(planId).delete();
    await LoggerService.info('delete_plan_permanent',
        details: 'Plan $planId supprimé définitivement');
  }

  // ============================================================
  //  LOGS
  // ============================================================

  Future<List<ActivityLog>> getActivityLogs(
      {String? userId, int limit = 200}) async {
    try {
      var query = _firestore
          .collection('logs')
          .orderBy('timestamp', descending: true)
          .limit(limit);
      if (userId != null) query = query.where('userId', isEqualTo: userId);
      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ActivityLog(
          id: doc.id,
          userId: data['userId'] ?? 'inconnu',
          userEmail: data['userEmail'] ?? 'inconnu',
          action: data['action'] ?? 'unknown',
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          targetId: data['targetId'],
          targetType: data['targetType'],
          details: data['details'] as Map<String, dynamic>?,
        );
      }).toList();
    } catch (e) {
      debugPrint("❌ Erreur getActivityLogs: $e");
      return [];
    }
  }

  Future<void> logActivity({
    required String userId,
    required String userEmail,
    required String action,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _firestore.collection('logs').add(ActivityLog.create(
            userId: userId,
            userEmail: userEmail,
            action: action,
            targetId: targetId,
            targetType: targetType,
            details: details,
          ).toMap());
    } catch (e) {
      debugPrint('❌ Erreur log activité: $e');
    }
  }

  // ============================================================
  //  EXPORT CSV
  // ============================================================

  Future<File> exportUsersCsvToFile() async {
    final users = await _firestore.collection('users').get();
    final rows = <List<dynamic>>[
      ['ID', 'Nom', 'Email', 'Rôle', 'Statut']
    ];
    for (final doc in users.docs) {
      final u = AppUser.fromMap(doc.data());
      rows.add([
        u.id,
        u.displayName,
        u.email,
        u.isAdmin ? 'Admin' : 'User',
        u.isActive ? 'Actif' : 'Inactif'
      ]);
    }
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/users_${DateTime.now().millisecondsSinceEpoch}.csv');
    return await file.writeAsString('\uFEFF$csv', encoding: utf8);
  }

  // ============================================================
  //  STATISTIQUES
  // ============================================================

  Future<Map<String, dynamic>> getUsersStats() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final subsSnapshot = await _firestore
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .get();
      final total = usersSnapshot.size;
      final active = subsSnapshot.size;
      return {
        'totalUsers': total,
        'activeSubscriptions': active,
        'inactiveUsers': total - active,
        'conversionRate': total > 0 ? (active / total) * 100 : 0,
      };
    } catch (e) {
      debugPrint("❌ Erreur getUsersStats: $e");
      return {
        'totalUsers': 0,
        'activeSubscriptions': 0,
        'inactiveUsers': 0,
        'conversionRate': 0
      };
    }
  }

  Future<Plan?> getPlan(String id) async {
    final doc = await _firestore.collection('plans').doc(id).get();
    if (doc.exists) return Plan.fromMap(doc.data()!, documentId: doc.id);
    return null;
  }

//   Future<List<Plan>> getAllPlans() async {
//   try {
//     final snapshot = await _firestore.collection('plans').get();
//     if (snapshot.docs.isEmpty) return Plan.getDefaultPlans();
//     return snapshot.docs.map((doc) {
//       final data = doc.data();
//       data['id'] = doc.id;
//       return Plan.fromMap(data);
//     }).toList();
//   } catch (e) {
//     debugPrint("❌ Erreur getAllPlans: $e");
//     return Plan.getDefaultPlans();
//   }
// }
}
