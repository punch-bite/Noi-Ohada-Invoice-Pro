import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/notification.dart';
import '../services/subscription_service.dart';
import '../services/notification_service.dart';
import '../models/subscription.dart';

class SubscriptionCheckerService {
  static final SubscriptionCheckerService _instance = SubscriptionCheckerService._internal();
  factory SubscriptionCheckerService() => _instance;
  SubscriptionCheckerService._internal();

  final SubscriptionService _subscriptionService = SubscriptionService();
  final NotificationService _notificationService = NotificationService();

  Timer? _timer;
  bool _isRunning = false;
  
  // Utilisation d'une variable pour garder la boîte ouverte en mémoire
  Box? _cacheBox;
  static const String _cacheBoxName = 'subscription_notifications_cache';

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    
    // Ouverture unique de la boîte au démarrage
    _cacheBox = await Hive.openBox(_cacheBoxName);
    
    _checkAll();
    _timer = Timer.periodic(const Duration(hours: 1), (_) => _checkAll());
    debugPrint('✅ SubscriptionCheckerService démarré.');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  Future<void> _checkAll() async {
    try {
      final subscriptions = await _subscriptionService.getActiveSubscriptions();
      for (final sub in subscriptions) {
        await _checkSubscription(sub);
      }
    } catch (e) {
      debugPrint('❌ Erreur checkAll: $e');
    }
  }

  Future<void> _checkSubscription(Subscription sub) async {
    final now = DateTime.now();
    final diff = sub.endDate.difference(now).inDays;
    final lastStatus = _cacheBox?.get(sub.id);

    // Détermination de l'état actuel
    String? currentStatus;
    String? title;
    String? body;

    if (now.isAfter(sub.endDate)) {
      currentStatus = 'expired';
      title = '⛔ Abonnement expiré';
      body = 'Votre abonnement est expiré. Renouvelez-le pour continuer.';
    } else if (diff <= 7) {
      currentStatus = 'expiring_soon';
      title = '⏳ Abonnement bientôt expiré';
      body = 'Votre abonnement expire dans $diff jour(s). Pensez à renouveler.';
    }

    // Envoi de notification uniquement si l'état a changé
    if (currentStatus != null && currentStatus != lastStatus) {
      await _notificationService.addNotification(
        AppNotification(
          title: title!,
          body: body!,
          type: NotificationType.subscription_expired.name,
          referenceId: sub.id,
          referenceType: 'subscription',
        ),
      );
      await _cacheBox?.put(sub.id, currentStatus);
    } else if (currentStatus == null && lastStatus != null) {
      // Nettoyage si l'abonnement a été renouvelé
      await _cacheBox?.delete(sub.id);
    }
  }

  Future<void> resetAlerts() async {
    await _cacheBox?.clear();
  }
}