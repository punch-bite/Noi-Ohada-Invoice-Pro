// lib/services/subscription_checker_service.dart
import 'dart:async';
import 'package:noi_ohada_invoice_pro/models/notification.dart';

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
  final int checkIntervalSeconds = 3600; // 1 heure

  // Cache pour éviter les notifications en double
  final Map<String, String> _notifiedStatuses = {}; // subscriptionId -> 'expired' | 'expiring_soon'

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    await _notificationService.init();
    await _subscriptionService.initializeDefaultPlans();

    await _checkAll();

    _timer = Timer.periodic(
      Duration(seconds: checkIntervalSeconds),
      (_) => _checkAll(),
    );
    print('✅ SubscriptionCheckerService démarré (intervalle: ${checkIntervalSeconds}s)');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    print('⏹️ SubscriptionCheckerService arrêté');
  }

  Future<void> _checkAll() async {
    try {
      final subscriptions = await _subscriptionService.getActiveSubscriptions();
      for (final sub in subscriptions) {
        await _checkSubscription(sub);
      }
    } catch (e) {
      print('❌ Erreur _checkAll: $e');
    }
  }

  Future<void> _checkSubscription(Subscription subscription) async {
    final now = DateTime.now();
    final daysUntilExpiry = subscription.endDate.difference(now).inDays;

    // Expiré
    if (now.isAfter(subscription.endDate)) {
      if (_notifiedStatuses[subscription.id] != 'expired') {
        final plan = await _subscriptionService.getPlan(subscription.planId);
        await _notificationService.addNotification(
          AppNotification(
            title: '⛔ Abonnement expiré',
            body: 'Votre abonnement ${plan?.name ?? ''} est expiré. Renouvelez-le pour continuer.',
            type: NotificationType.subscription_expired.toString(),
            referenceId: subscription.id,
            referenceType: 'subscription',
          ),
        );
        _notifiedStatuses[subscription.id] = 'expired';
      }
    }
    // Expire bientôt (dans moins de 7 jours)
    else if (daysUntilExpiry <= 7 && daysUntilExpiry >= 0) {
      if (_notifiedStatuses[subscription.id] != 'expiring_soon') {
        final plan = await _subscriptionService.getPlan(subscription.planId);
        await _notificationService.addNotification(
          AppNotification(
            title: '⏳ Abonnement bientôt expiré',
            body: 'Votre abonnement ${plan?.name ?? ''} expire dans $daysUntilExpiry jour${daysUntilExpiry > 1 ? 's' : ''}. Pensez à renouveler.',
            type: NotificationType.subscription_expired.toString(),
            referenceId: subscription.id,
            referenceType: 'subscription',
          ),
        );
        _notifiedStatuses[subscription.id] = 'expiring_soon';
      }
    } else {
      // Si l'abonnement est actif et qu'il reste plus de 7 jours, on réinitialise l'état
      _notifiedStatuses.remove(subscription.id);
    }
  }

  void resetAlerts() {
    _notifiedStatuses.clear();
  }
}