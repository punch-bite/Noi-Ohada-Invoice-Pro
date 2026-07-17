// lib/providers/subscription_provider.dart
import 'package:flutter/material.dart';
import '../models/subscription.dart';
import '../models/plan.dart';
import '../services/subscription_service.dart';
import '../providers/auth_provider.dart';
import '../services/logger_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final AppAuthProvider _authProvider;

  Subscription? _subscription;
  Plan? _currentPlan;
  List<Plan> _plans = [];
  bool _isLoading = false;

  SubscriptionProvider(this._authProvider) {
    _loadSubscription();
    loadPlans();
  }

  // ===== GETTERS =====
  Subscription? get subscription => _subscription;
  Plan? get currentPlan => _currentPlan;
  List<Plan> get plans => _plans;
  bool get isLoading => _isLoading;

  // ===== ACCÈS PREMIUM =====
  bool get canAccessPremiumTemplates {
    if (_authProvider.user?.isAdmin == true) {
      debugPrint("🔥 Admin détecté, accès premium accordé");
      return true;
    }
    final isActive = _subscription?.isActive ?? false;
    debugPrint("🔔 Abonnement actif ? $isActive");
    return isActive;
  }

  bool get hasUnlimitedAccess {
    if (_authProvider.user?.isAdmin == true) return true;
    return _subscription?.planId == 'unlimited';
  }

  int get maxInvoices {
    if (_authProvider.user?.isAdmin == true) return -1;
    return _currentPlan?.maxInvoices ?? 3;
  }

  int get maxClients {
    if (_authProvider.user?.isAdmin == true) return -1;
    return _currentPlan?.maxClients ?? 5;
  }

  bool get canSyncToCloud {
    if (_authProvider.user?.isAdmin == true) return true;
    return _currentPlan?.hasCloudSync ?? false;
  }

  // ===== LOAD PLANS =====
  Future<void> loadPlans() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Récupérer les plans depuis Firestore via SubscriptionService
      final fetchedPlans = await _subscriptionService.getPlans();

      if (fetchedPlans.isEmpty) {
        // Fallback sur les plans par défaut si rien en base
        _plans = Plan.getDefaultPlans();
      } else {
        _plans = fetchedPlans;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur chargement plans: $e');
      // En cas d'erreur, on utilise les plans par défaut
      _plans = Plan.getDefaultPlans();
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===== CRÉATION D'ABONNEMENT =====
  Future<bool> createSubscription({
    required String userId,
    required String planId,
    required String paymentMethod,
    required String paymentId,
    required double amount,
    required String currency,
    required String interval,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final subscription = await _subscriptionService.createSubscription(
        userId: userId,
        planId: planId,
        paymentMethod: paymentMethod,
        paymentId: paymentId,
        amount: amount,
        currency: currency,
        interval: interval,
      );

      _subscription = subscription;
      _currentPlan = await _subscriptionService.getPlan(planId);

      await LoggerService.info(
        'create_subscription',
        details: 'Abonnement ${_currentPlan?.name} créé pour $userId',
        targetId: subscription.id,
        targetType: 'subscription',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Erreur création abonnement: $e');
      await LoggerService.error(
        'create_subscription_failed',
        details: e.toString(),
      );
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ===== ANNULATION =====
  Future<bool> cancelSubscription() async {
    if (_subscription == null) {
      debugPrint('❌ Aucun abonnement actif à annuler');
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      await _subscriptionService.cancelSubscription(_subscription!.id);

      // Recharger l'abonnement
      await _loadSubscription();

      await LoggerService.info(
        'cancel_subscription',
        details: 'Abonnement ${_currentPlan?.name} annulé',
        targetId: _subscription?.id,
        targetType: 'subscription',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Erreur annulation abonnement: $e');
      await LoggerService.error(
        'cancel_subscription_failed',
        details: e.toString(),
      );
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ===== RENOUVELLEMENT =====
  Future<bool> renewSubscription() async {
    if (_subscription == null) {
      debugPrint('❌ Aucun abonnement à renouveler');
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      await _subscriptionService.renewSubscription(_subscription!.id);

      // Recharger l'abonnement
      await _loadSubscription();

      await LoggerService.info(
        'renew_subscription',
        details: 'Abonnement ${_currentPlan?.name} renouvelé',
        targetId: _subscription?.id,
        targetType: 'subscription',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Erreur renouvellement abonnement: $e');
      await LoggerService.error(
        'renew_subscription_failed',
        details: e.toString(),
      );
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ===== CHARGEMENT ABONNEMENT =====
  Future<void> _loadSubscription() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = _authProvider.user?.id;
      if (userId == null) {
        _subscription = null;
        _currentPlan = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      _subscription = await _subscriptionService.getUserSubscription(userId);
      if (_subscription != null) {
        _currentPlan = await _subscriptionService.getPlan(_subscription!.planId);
      } else {
        _currentPlan = Plan.getFreePlan();
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement abonnement: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _loadSubscription();
    await loadPlans();
  }
}