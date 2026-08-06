// lib/services/quota_enforcement_service.dart
//
// ✅ Application des QUOTAS selon le plan de l'utilisateur (logique SaaS).
//
// Norme de quotas :
//   - GRATUIT  :  5 clients,   5 produits,  10 factures
//   - PRO      : 200 clients,  25 produits,  factures illimitées
//   - BUSINESS : clients illimités, produits illimités, factures illimitées
//
// Une valeur de limite <= 0 signifie "illimité".
//
import '../models/plan.dart';
import 'database_service.dart';

class QuotaEnforcementService {
  final DatabaseService _db = DatabaseService();

  /// Retourne la limite restante (-1 = illimité, 0 = plus de place).
  Future<int> remainingClients(Plan plan) async {
    if (plan.isUnlimitedClients()) return -1;
    final current = await _db.getClients();
    return plan.maxClients - current.length;
  }

  Future<int> remainingProducts(Plan plan) async {
    if (plan.isUnlimitedProducts()) return -1;
    final current = await _db.getProducts();
    return plan.maxProducts - current.length;
  }

  Future<int> remainingInvoices(Plan plan) async {
    if (plan.isUnlimitedInvoices()) return -1;
    final current = await _db.getInvoices();
    return plan.maxInvoices - current.length;
  }

  /// Vérifie si l'utilisateur peut ajouter un nouveau client.
  Future<QuotaResult> canAddClient(Plan plan) async {
    if (plan.isUnlimitedClients()) return QuotaResult.allowed();
    final remaining = await remainingClients(plan);
    if (remaining > 0) return QuotaResult.allowed(remaining);
    return QuotaResult.denied(
      'Limite de clients atteinte (${plan.maxClients}). '
      'Passez au plan Pro (200 clients) ou Business (illimité).',
    );
  }

  /// Vérifie si l'utilisateur peut ajouter un nouveau produit.
  Future<QuotaResult> canAddProduct(Plan plan) async {
    if (plan.isUnlimitedProducts()) return QuotaResult.allowed();
    final remaining = await remainingProducts(plan);
    if (remaining > 0) return QuotaResult.allowed(remaining);
    return QuotaResult.denied(
      'Limite de produits atteinte (${plan.maxProducts}). '
      'Passez au plan Pro (25 produits) ou Business (illimité).',
    );
  }

  /// Vérifie si l'utilisateur peut émettre une nouvelle facture.
  Future<QuotaResult> canAddInvoice(Plan plan) async {
    if (plan.isUnlimitedInvoices()) return QuotaResult.allowed();
    final remaining = await remainingInvoices(plan);
    if (remaining > 0) return QuotaResult.allowed(remaining);
    return QuotaResult.denied(
      'Limite de factures atteinte (${plan.maxInvoices}). '
      'Passez au plan Pro ou Business pour des factures illimitées.',
    );
  }
}

class QuotaResult {
  final bool ok;
  final int remaining;
  final String? message;

  const QuotaResult._({required this.ok, this.remaining = -1, this.message});

  factory QuotaResult.allowed([int remaining = -1]) =>
      QuotaResult._(ok: true, remaining: remaining);

  factory QuotaResult.denied(String message) =>
      QuotaResult._(ok: false, remaining: 0, message: message);

  bool get isAllowed => ok;

  @override
  String toString() =>
      ok ? 'Autorisé (restant: $remaining)' : 'Refusé: ${message ?? ''}';
}
