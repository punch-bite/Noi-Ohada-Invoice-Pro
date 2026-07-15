// lib/providers/subscription_provider.dart
import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../models/subscription.dart';
import '../models/plan.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _subscriptionService = SubscriptionService();
  
  Subscription? _subscription;
  List<Plan> _plans = [];
  bool _isLoading = false;
  String? _error;

  Subscription? get subscription => _subscription;
  List<Plan> get plans => _plans;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveSubscription => _subscription != null && _subscription!.isActive;
  
  // 🔥 NOUVEAU : Vérifier si l'utilisateur peut accéder aux templates premium
  bool get canAccessPremiumTemplates {
    if (_subscription == null) return false;
    return _subscription!.planId == 'pro' || _subscription!.planId == 'business';
  }
  
  bool get isProPlan {
    return _subscription?.planId == 'pro' || _subscription?.planId == 'business';
  }

  Plan? get currentPlan {
    if (_subscription == null) return null;
    try {
      return _plans.firstWhere(
        (plan) => plan.id == _subscription!.planId,
        orElse: () => Plan.getFreePlan(),
      );
    } catch (e) {
      return Plan.getFreePlan();
    }
  }

  Future<void> loadSubscription(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _subscription = await _subscriptionService.getUserSubscription(userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPlans() async {
    _isLoading = true;
    notifyListeners();

    try {
      _plans = await _subscriptionService.getPlans();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🔥 MÉTHODE CRÉER UN ABONNEMENT (AJOUTÉE)
  Future<bool> createSubscription({
    required String userId,
    required String planId,
    required String paymentMethod,
    required String paymentId,
    required double amount,
    required String currency,
    required String interval,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _subscription = await _subscriptionService.createSubscription(
        userId: userId,
        planId: planId,
        paymentMethod: paymentMethod,
        paymentId: paymentId,
        amount: amount,
        currency: currency,
        interval: interval,
      );
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> cancelSubscription() async {
    if (_subscription == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _subscriptionService.cancelSubscription(_subscription!.id);
      _subscription = _subscription!.copyWith(
        status: 'canceled',
        autoRenew: false,
        canceledAt: DateTime.now(),
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> renewSubscription() async {
    if (_subscription == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _subscriptionService.renewSubscription(_subscription!.id);
      await loadSubscription(_subscription!.userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool canCreateInvoice() {
    if (!hasActiveSubscription) return false;
    return true;
  }

  bool canCreateClient() {
    if (!hasActiveSubscription) return false;
    return true;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}