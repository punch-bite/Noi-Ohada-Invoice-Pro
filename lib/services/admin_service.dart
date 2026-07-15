// lib/services/admin_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/user.dart';
import '../models/subscription.dart';
import '../models/activity_log.dart';
import 'subscription_service.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SubscriptionService _subscriptionService = SubscriptionService();

  // ===== UTILISATEURS =====

  Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) => AppUser.fromMap(doc.data())).toList();
    } catch (e) {
      print('❌ Erreur getAllUsers: $e');
      return [];
    }
  }

  Future<AppUser?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ Erreur getUserById: $e');
      return null;
    }
  }

  Future<void> updateUser(AppUser user) async {
    try {
      await _firestore.collection('users').doc(user.id).update(user.toMap());
      await _logActivity(
        userId: user.id,
        userEmail: user.email,
        action: 'update_user',
        targetId: user.id,
        targetType: 'user',
        details: {'displayName': user.displayName, 'isActive': user.isActive},
      );
    } catch (e) {
      throw Exception('Erreur mise à jour utilisateur: $e');
    }
  }

  Future<void> updateUserRoles(String userId, List<String> roles) async {
    try {
      await _firestore.collection('users').doc(userId).update({'roles': roles});
      final user = await getUserById(userId);
      if (user != null) {
        await _logActivity(
          userId: userId,
          userEmail: user.email,
          action: 'update_roles',
          targetId: userId,
          targetType: 'user',
          details: {'roles': roles},
        );
      }
    } catch (e) {
      throw Exception('Erreur mise à jour rôles: $e');
    }
  }

  Future<void> toggleUserActive(String userId, bool isActive) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({'isActive': isActive});
      final user = await getUserById(userId);
      if (user != null) {
        await _logActivity(
          userId: userId,
          userEmail: user.email,
          action: isActive ? 'activate_user' : 'deactivate_user',
          targetId: userId,
          targetType: 'user',
          details: {'isActive': isActive},
        );
      }
    } catch (e) {
      throw Exception('Erreur mise à jour statut: $e');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      final user = await getUserById(userId);
      await _firestore.collection('users').doc(userId).delete();
      if (user != null) {
        await _logActivity(
          userId: userId,
          userEmail: user.email,
          action: 'delete_user',
          targetId: userId,
          targetType: 'user',
        );
      }
    } catch (e) {
      throw Exception('Erreur suppression: $e');
    }
  }

  Future<Map<String, int>> getUserStats() async {
    try {
      final users = await getAllUsers();
      return {
        'total': users.length,
        'active': users.where((u) => u.isActive).length,
        'inactive': users.where((u) => !u.isActive).length,
        'admins': users.where((u) => u.isAdmin).length,
        'users': users.where((u) => !u.isAdmin).length,
      };
    } catch (e) {
      print('❌ Erreur getUserStats: $e');
      return {
        'total': 0,
        'active': 0,
        'inactive': 0,
        'admins': 0,
        'users': 0,
      };
    }
  }

  // ===== ABONNEMENTS =====

  Future<List<Subscription>> getUserSubscriptions(String userId) async {
    try {
      final query = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .orderBy('startDate', descending: true)
          .get();
      return query.docs.map((doc) => Subscription.fromMap(doc.data())).toList();
    } catch (e) {
      print('❌ Erreur getUserSubscriptions: $e');
      return [];
    }
  }

  Future<void> cancelSubscription(String subscriptionId,
      {String? reason}) async {
    try {
      await _firestore.collection('subscriptions').doc(subscriptionId).update({
        'status': 'canceled',
        'autoRenew': false,
        'canceledAt': FieldValue.serverTimestamp(),
        'metadata': {
          'adminCanceled': true,
          'reason': reason ?? 'Annulation par administrateur',
        },
      });
      final sub = await _firestore
          .collection('subscriptions')
          .doc(subscriptionId)
          .get();
      if (sub.exists) {
        final data = sub.data()!;
        final userId = data['userId'] as String;
        final user = await getUserById(userId);
        if (user != null) {
          await _logActivity(
            userId: userId,
            userEmail: user.email,
            action: 'admin_cancel_subscription',
            targetId: subscriptionId,
            targetType: 'subscription',
            details: {'reason': reason ?? 'Annulation par administrateur'},
          );
        }
      }
    } catch (e) {
      throw Exception('Erreur annulation abonnement: $e');
    }
  }

  Future<void> extendSubscription(String subscriptionId, int days) async {
    try {
      final doc = await _firestore
          .collection('subscriptions')
          .doc(subscriptionId)
          .get();
      if (!doc.exists) throw Exception('Abonnement non trouvé');
      final sub = Subscription.fromMap(doc.data()!);
      final newEndDate = sub.endDate.add(Duration(days: days));
      await _firestore.collection('subscriptions').doc(subscriptionId).update({
        'endDate': newEndDate,
        'status': 'active',
      });
      final user = await getUserById(sub.userId);
      if (user != null) {
        await _logActivity(
          userId: user.id,
          userEmail: user.email,
          action: 'admin_extend_subscription',
          targetId: subscriptionId,
          targetType: 'subscription',
          details: {'days': days, 'newEndDate': newEndDate.toIso8601String()},
        );
      }
    } catch (e) {
      throw Exception('Erreur prolongation: $e');
    }
  }

  Future<void> changeUserPlan(String userId, String newPlanId) async {
    try {
      final subscriptions = await getUserSubscriptions(userId);
      final activeSub = subscriptions.firstWhere((s) => s.isActive,
          orElse: () => throw Exception('Aucun abonnement actif'));
      await _firestore.collection('subscriptions').doc(activeSub.id).update({
        'planId': newPlanId,
        'metadata': {
          'planChangedByAdmin': true,
          'previousPlan': activeSub.planId,
        },
      });
      final user = await getUserById(userId);
      if (user != null) {
        await _logActivity(
          userId: userId,
          userEmail: user.email,
          action: 'admin_change_plan',
          targetId: activeSub.id,
          targetType: 'subscription',
          details: {'newPlan': newPlanId, 'oldPlan': activeSub.planId},
        );
      }
    } catch (e) {
      throw Exception('Erreur changement de plan: $e');
    }
  }

  // ===== CRÉER UN ABONNEMENT POUR UN UTILISATEUR =====

  Future<void> createSubscriptionForUser({
    required String userId,
    required String planId,
    required String paymentMethod,
    required double amount,
    required String currency,
    required String interval,
    String? paymentId,
  }) async {
    try {
      final plan = await _subscriptionService.getPlan(planId);
      if (plan == null) throw Exception('Plan non trouvé');

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
        paymentId:
            paymentId ?? 'admin_${DateTime.now().millisecondsSinceEpoch}',
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

      final user = await getUserById(userId);
      if (user != null) {
        await _logActivity(
          userId: userId,
          userEmail: user.email,
          action: 'admin_create_subscription',
          targetId: subscription.id,
          targetType: 'subscription',
          details: {'planId': planId, 'amount': amount},
        );
      }
    } catch (e) {
      throw Exception('Erreur création abonnement: $e');
    }
  }

  // ===== LOGS D'ACTIVITÉ =====

  Future<void> _logActivity({
    required String userId,
    required String userEmail,
    required String action,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? details,
  }) async {
    try {
      final log = ActivityLog.create(
        userId: userId,
        userEmail: userEmail,
        action: action,
        targetId: targetId,
        targetType: targetType,
        details: details,
      );
      await _firestore.collection('logs').add(log.toMap());
    } catch (e) {
      print('❌ Erreur log activité: $e');
    }
  }

  // Méthode publique pour logger depuis d'autres services (ex: AuthProvider)
  Future<void> logActivity({
    required String userId,
    required String userEmail,
    required String action,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? details,
  }) async {
    await _logActivity(
      userId: userId,
      userEmail: userEmail,
      action: action,
      targetId: targetId,
      targetType: targetType,
      details: details,
    );
  }

  Future<List<ActivityLog>> getActivityLogs({
    String? userId,
    String? action,
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    try {
      var query = _firestore
          .collection('logs')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      if (action != null) {
        query = query.where('action', isEqualTo: action);
      }
      if (from != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: from);
      }
      if (to != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: to);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ActivityLog.fromMap(data);
      }).toList();
    } catch (e) {
      print('❌ Erreur getActivityLogs: $e');
      return [];
    }
  }

  // ===== EXPORT CSV =====

  Future<String> exportUsersCsv() async {
    final users = await getAllUsers();
    final rows = <List<String>>[
      [
        'ID',
        'Nom',
        'Email',
        'Téléphone',
        'Entreprise',
        'Rôle',
        'Statut',
        'Inscrit le'
      ]
    ];
    for (final u in users) {
      rows.add([
        u.id,
        u.displayName,
        u.email,
        u.phone ?? '',
        u.companyName ?? '',
        u.isAdmin ? 'Administrateur' : 'Utilisateur',
        u.isActive ? 'Actif' : 'Inactif',
        '${u.createdAt.day}/${u.createdAt.month}/${u.createdAt.year}',
      ]);
    }
    final csv = const ListToCsvConverter().convert(rows);
    return csv;
  }

  Future<File> exportUsersCsvToFile() async {
    final csvContent = await exportUsersCsv();
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/utilisateurs_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvContent);
    return file;
  }
}
