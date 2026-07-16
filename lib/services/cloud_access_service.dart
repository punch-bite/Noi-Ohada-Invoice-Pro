// lib/services/cloud_access_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'subscription_service.dart';

class CloudAccessService {
  final SubscriptionService _subscriptionService = SubscriptionService();

  /// Vérifie si l'utilisateur a accès au cloud (abonnement Pro ou Business)
  Future<bool> hasAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final sub = await _subscriptionService.getUserSubscription(user.uid);
    if (sub == null || !sub.isActive) return false;
    return sub.planId == 'pro' || sub.planId == 'business';
  }

  /// Lève une exception si l'utilisateur n'a pas accès
  Future<void> requireAccess() async {
    if (!await hasAccess()) {
      throw Exception('Abonnement Pro requis pour la synchronisation cloud');
    }
  }
}