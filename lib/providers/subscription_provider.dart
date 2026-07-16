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

  // --- Getters ---
  Subscription? get subscription => _subscription;
  List<Plan> get plans => _plans;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get hasActiveSubscription => _subscription?.isActive ?? false;
  bool get isPremium => ['pro', 'business'].contains(_subscription?.planId);

  Plan get currentPlan {
    return _plans.firstWhere(
      (p) => p.id == _subscription?.planId,
      orElse: () => Plan.getFreePlan(),
    );
  }

  bool get canAccessPremiumTemplates {
    final can = (_subscription?.isActive ?? false);
    debugPrint("Debug Access: Abonnement actif ? $can");
    return can;
  }

  bool get hasCloudAccess {
    final sub = subscription;
    if (sub == null || !sub.isActive) return false;
    return sub.planId == 'pro' || sub.planId == 'business';
  }

// C'est ici que la logique doit être centralisée
  // bool get canAccessPremiumTemplates {
  //   if (_subscription == null) return false;
  //   // Vérifie si l'abonnement est actif et n'est pas le plan gratuit
  //   return _subscription!.isActive && !_subscription!.isTrial;
  // }

  // N'oubliez pas d'appeler notifyListeners() après chaque mise à jour de _subscription
  void updateSubscription(Subscription newSub) {
    _subscription = newSub;
    notifyListeners(); // Crucial pour que le .watch() dans l'UI réagisse
  }
  // --- Logique métier ---

  /// Initialise les données de l'utilisateur
  Future<void> initialize(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _subscriptionService.getUserSubscription(userId),
        _subscriptionService
            .getPlan(userId), // Assurez-vous d'avoir cette méthode
      ]);

      _subscription = results[0] as Subscription?;
      _plans = results[1] as List<Plan>;
      _error = null;
    } catch (e) {
      _error = "Erreur de chargement: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crée un nouvel abonnement
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
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Annule l'abonnement en cours
  Future<void> cancelSubscription() async {
    if (_subscription == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _subscriptionService.cancelSubscription(_subscription!.id);
      _subscription = _subscription!.copyWith(status: 'canceled');
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Charge les plans depuis la base de données
  Future<void> loadPlans() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Si vous avez une méthode getPlans dans DatabaseService ou AdminService
      _plans = await _subscriptionService.getPlans();
    } catch (e) {
      debugPrint("Erreur lors du chargement des plans : $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charge les abonnements depuis la base de données
  Future<void> loadSubscriptions(String id) async {
    try {
      // Si vous avez une méthode getSubscriptions dans DatabaseService
      _subscription = (await _subscriptionService.getActiveSubscriptions())
          as Subscription?;
      notifyListeners();
    } catch (e) {
      debugPrint("Erreur lors du chargement des abonnements : $e");
    }
  }
}
