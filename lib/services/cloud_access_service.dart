// lib/services/cloud_access_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:noi_ohada_invoice_pro/services/database_service.dart';

class CloudAccessService {
  final DatabaseService _db = DatabaseService();

  Future<bool> hasAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Récupérer l'abonnement actif de l'utilisateur
    final subscription = await _db.getUserActiveSubscription(user.uid);
    if (subscription == null) return false;

    final plan = await _db.getPlan(subscription.planId);
    if (plan == null) return false;

    return plan.hasCloudSync;
  }

  Future<void> requireAccess() async {
    if (!await hasAccess()) {
      throw Exception('Abonnement Pro requis pour la synchronisation cloud');
    }
  }
}