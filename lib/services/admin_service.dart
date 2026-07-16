import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user.dart';
import '../models/subscription.dart';
import '../models/activity_log.dart';
import 'subscription_service.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SubscriptionService _subscriptionService = SubscriptionService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===== USERS (Batch Optimisé) =====

  /// Utilise une transaction pour garantir que le log et la mise à jour réussissent ensemble
  Future<void> updateUser(AppUser user) async {
    return _db.runTransaction((transaction) async {
      final userRef = _db.collection('users').doc(user.id);
      final logRef = _db.collection('logs').doc();

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

  // ===== ABONNEMENTS (Transactions) =====

  Future<void> extendSubscription(String subscriptionId, int days) async {
    final subRef = _db.collection('subscriptions').doc(subscriptionId);

    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(subRef);
      if (!doc.exists) throw Exception('Abonnement introuvable');

      final sub = Subscription.fromMap(doc.data()!);
      final newEndDate = sub.endDate.add(Duration(days: days));

      transaction.update(subRef, {
        'endDate': newEndDate,
        'status': 'active',
      });

      // Log automatique dans la même transaction
      transaction.set(
          _db.collection('logs').doc(),
          ActivityLog.create(
            userId: sub.userId,
            userEmail: 'admin_action', // Pourrait être récupéré via Auth
            action: 'admin_extend_subscription',
            targetId: subscriptionId,
            targetType: 'subscription',
            details: {'days': days, 'newEndDate': newEndDate.toIso8601String()},
          ).toMap());
    });
  }

  // ===== LOGS D'ACTIVITÉ (Centralisation) =====

  Future<List<ActivityLog>> getActivityLogs(
      {String? userId, int limit = 200}) async {
    try {
      var query = FirebaseFirestore.instance
          .collection('activity_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      final snapshot = await query.get();

      // On transforme les documents en objets ActivityLog manuellement
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ActivityLog(
          id: doc.id,
          action: data['action'] ?? 'unknown',
          userEmail: data['userEmail'] ?? 'inconnu',
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          details: data['details'], userId: data['userId'] ?? ['inconnu'],
          // Ajoutez ici les autres champs que vous avez dans votre modèle
        );
      }).toList();
    } catch (e) {
      debugPrint("Erreur lors de la récupération : $e");
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
    required int limit,
  }) async {
    try {
      await _db.collection('logs').add(ActivityLog.create(
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

  // ===== EXPORT CSV (Optimisé avec StreamWriter) =====

  Future<File> exportUsersCsvToFile() async {
    final users = await _db.collection('users').get();
    final List<List<dynamic>> rows = [
      ['ID', 'Nom', 'Email', 'Rôle', 'Statut']
    ];

    for (var doc in users.docs) {
      final u = AppUser.fromMap(doc.data());
      rows.add([
        u.id,
        u.displayName,
        u.email,
        u.isAdmin ? 'Admin' : 'User',
        u.isActive ? 'Actif' : 'Inactif'
      ]);
    }

    final csv = ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/users_${DateTime.now().millisecondsSinceEpoch}.csv');

    // Ajout du BOM UTF-8 pour Excel
    return await file.writeAsString('\uFEFF$csv', encoding: utf8);
  }

  /// Récupère la liste de tous les utilisateurs inscrits
  Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) => AppUser.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint("Erreur récupération utilisateurs : $e");
      return [];
    }
  }

  // lib/services/admin_service.dart

  Future<void> createSubscriptionForUser({
    required String userId,
    required String planId,
    required int durationMonths,
    required String paymentMethod,
    required double amount,
    required String currency,
    required String interval,
  }) async {
    try {
      // 1. Création de l'objet Abonnement
      final newSubscription = Subscription(
        id: DateTime.now()
            .millisecondsSinceEpoch
            .toString(), // Générateur d'ID simple
        userId: userId,
        planId: planId,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(Duration(days: durationMonths * 30)),
        isActive: true,
        createdAt: DateTime.now(), status: '', paymentMethod: '', paymentId: '',
        amount: 0.0, currency: '',
      );

      // 2. Persistance dans votre base de données (Firestore ou Hive)
      // Exemple avec Firestore :
      await _firestore
          .collection('subscriptions')
          .doc(newSubscription.id)
          .set(newSubscription.toMap());

      // Exemple avec Hive :
      // await Hive.box<Subscription>('subscriptions').put(newSubscription.id, newSubscription);

      debugPrint("Abonnement créé avec succès pour l'utilisateur : $userId");
    } catch (e) {
      debugPrint("Erreur lors de la création de l'abonnement : $e");
      rethrow; // Important pour que l'interface puisse gérer l'erreur (via un Try/Catch)
    }
  }

  Future<Map<String, dynamic>> getUsersStats() async {
    try {
      // Si vous utilisez Firestore :
      final usersSnapshot = await _firestore.collection('users').get();
      final subsSnapshot = await _firestore
          .collection('subscriptions')
          .where('isActive', isEqualTo: true)
          .get();

      final totalUsers = usersSnapshot.size;
      final activeSubscriptions = subsSnapshot.size;

      return {
        'totalUsers': totalUsers,
        'activeSubscriptions': activeSubscriptions,
        'inactiveUsers': totalUsers - activeSubscriptions,
        'conversionRate':
            totalUsers > 0 ? (activeSubscriptions / totalUsers) * 100 : 0,
      };
    } catch (e) {
      debugPrint("Erreur lors du calcul des stats : $e");
      return {
        'totalUsers': 0,
        'activeSubscriptions': 0,
        'inactiveUsers': 0,
        'conversionRate': 0,
      };
    }
  }

  /// 1. Récupère un utilisateur spécifique par son ID
  Future<AppUser?> getUserById(String userId) async {
    try {
      // Si vous utilisez Firestore :
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint("Erreur récupération utilisateur $userId : $e");
      return null;
    }
  }

  /// 2. Active ou désactive un utilisateur
  Future<void> toggleUserActive(String userId, bool isActive) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint("Utilisateur $userId actif: $isActive");
    } catch (e) {
      debugPrint("Erreur lors du toggle état utilisateur : $e");
      rethrow;
    }
  }

  /// 3. Met à jour les rôles d'un utilisateur (ex: 'admin', 'user', 'manager')
  Future<void> updateUserRoles(String userId, List<String> newRoles) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'roles': newRoles,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint("Rôles mis à jour pour $userId : $newRoles");
    } catch (e) {
      debugPrint("Erreur lors de la mise à jour des rôles : $e");
      rethrow;
    }
  }

  // lib/services/admin_service.dart

  /// 1. Récupère tous les abonnements d'un utilisateur spécifique
  Future<List<Subscription>> getUserSubscriptions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs
          .map((doc) => Subscription.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint(
          "Erreur lors de la récupération des abonnements de $userId : $e");
      return [];
    }
  }

  /// 2. Annule un abonnement (met à jour le statut en 'cancelled' ou 'inactive')
  Future<void> cancelSubscription(String subscriptionId, {String? reason}) async {
    try {
      await _firestore.collection('subscriptions').doc(subscriptionId).update({
        'isActive': false,
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      debugPrint("Abonnement $subscriptionId annulé avec succès.");
    } catch (e) {
      debugPrint("Erreur lors de l'annulation de l'abonnement : $e");
      rethrow;
    }
  }

  /// 3. Change le plan d'un abonnement existant
  Future<void> changeUserPlan(String subscriptionId, String newPlanId) async {
    try {
      await _firestore.collection('subscriptions').doc(subscriptionId).update({
        'planId': newPlanId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
          "Abonnement $subscriptionId basculé vers le plan : $newPlanId");
    } catch (e) {
      debugPrint("Erreur lors du changement de plan : $e");
      rethrow;
    }
  }
}
