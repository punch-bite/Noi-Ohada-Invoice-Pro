// lib/services/cloud_access_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:noi_ohada_invoice_pro/services/database_service.dart';

class CloudAccessService {
  final DatabaseService _db = DatabaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Vérifie si l'utilisateur actuel a accès à la synchronisation cloud.
  ///
  /// Recherche d'abord dans le cache local Hive (mode hors-ligne), puis
  /// fait un fallback sur Firestore si les données locales sont absentes
  /// (par exemple après un logout ou lorsque le cache est vide).
  Future<bool> hasAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // 1) Tentative en mode local (hors-ligne)
    try {
      final localSubscription = await _db.getUserActiveSubscription(user.uid);
      if (localSubscription != null) {
        final localPlan = await _db.getPlan(localSubscription.planId);
        if (localPlan != null && localPlan.hasCloudSync) {
          return true;
        }
      }
    } catch (_) {
      // Cache local indisponible → on passe au fallback cloud
    }

    // 2) Fallback sur Firestore (données à jour)
    try {
      final query = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return false;

      final subData = query.docs.first.data();
      final planId = subData['planId'] as String?;
      if (planId == null) return false;

      final planDoc = await _firestore.collection('plans').doc(planId).get();
      if (!planDoc.exists) return false;

      final plan = planDoc.data();
      final hasCloudSync = plan?['hasCloudSync'] == true;
      return hasCloudSync;
    } catch (e) {
      // Erreur réseau ou permission → on considère qu'il n'y a pas accès
      return false;
    }
  }

  Future<void> requireAccess() async {
    if (!await hasAccess()) {
      throw Exception('Abonnement Pro requis pour la synchronisation cloud');
    }
  }
}