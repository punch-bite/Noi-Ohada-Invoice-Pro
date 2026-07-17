// lib/screens/subscription/plans_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/plan.dart';
import 'payment_screen.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isInitialLoading = true);
    final subProvider = context.read<SubscriptionProvider>();
    final authProvider = context.read<AppAuthProvider>();
    
    try {
      await subProvider.loadPlans();
      if (authProvider.user != null) {
        await subProvider.refresh();
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement: $e');
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    final authProvider = context.watch<AppAuthProvider>();
    
    if (_isInitialLoading || subProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final plans = subProvider.plans;
    final currentSub = subProvider.subscription;
    final isAdmin = authProvider.user?.isAdmin ?? false;

    // Debug
    debugPrint('📦 Plans chargés: ${plans.length}');
    debugPrint('📦 Plans: ${plans.map((p) => p.name).join(', ')}');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Nos offres'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          _buildHeader(currentSub, plans, isAdmin),
          Expanded(
            child: plans.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: plans.length,
                    itemBuilder: (context, index) {
                      final plan = plans[index];
                      final isCurrent = currentSub != null && currentSub.planId == plan.id && currentSub.isActive;
                      return PlanCard(
                        plan: plan,
                        isCurrentPlan: isCurrent,
                        isAdmin: isAdmin,
                        onSelect: () => isCurrent ? _showSubscriptionDetails(subProvider) : _selectPlan(plan),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Aucun plan disponible',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Veuillez réessayer plus tard',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(dynamic currentSub, List<Plan> plans, bool isAdmin) {
    String text;
    if (isAdmin) {
      text = '👑 Administrateur - Accès illimité';
    } else if (currentSub?.isActive == true) {
      text = 'Plan actuel : ${_getPlanName(plans, currentSub.planId)}';
    } else {
      text = 'Choisissez le plan qui vous correspond';
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAdmin ? Colors.amber[50] : Colors.blue[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isAdmin ? Colors.amber[800] : Colors.blue[800],
          ),
        ),
      ),
    );
  }

  Future<void> _selectPlan(Plan plan) async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          plan: plan,
          onPaymentComplete: () {},
        ),
      ),
    );
    if (success == true && mounted) _loadData();
  }

  void _showSubscriptionDetails(SubscriptionProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SubscriptionDetailsSheet(
        sub: provider.subscription!,
        plans: provider.plans,
      ),
    );
  }

  String _getPlanName(List<Plan> plans, String planId) {
    try {
      return plans.firstWhere((p) => p.id == planId).name;
    } catch (_) {
      return 'Inconnu';
    }
  }
}

// ===== WIDGET CARTE PLAN =====
class PlanCard extends StatelessWidget {
  final Plan plan;
  final bool isCurrentPlan;
  final bool isAdmin;
  final VoidCallback onSelect;

  const PlanCard({
    super.key,
    required this.plan,
    required this.isCurrentPlan,
    required this.isAdmin,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isPopular = plan.isPopular;
    final isFree = plan.isFree;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isPopular ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPopular
            ? BorderSide(color: Colors.amber, width: 2)
            : BorderSide.none,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isCurrentPlan ? Colors.green : Colors.black87,
                        ),
                      ),
                    ),
                    if (isPopular)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'POPULAIRE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  plan.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                // Prix
                Row(
                  children: [
                    Text(
                      plan.getFormattedPrice(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isCurrentPlan ? Colors.green : Colors.black87,
                      ),
                    ),
                    if (!isFree)
                      Text(
                        ' / ${plan.interval == 'year' ? 'an' : 'mois'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Fonctionnalités
                ...plan.features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: isCurrentPlan ? Colors.green : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Bouton
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isAdmin ? null : onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrentPlan
                          ? Colors.green
                          : (isPopular ? Colors.amber : Colors.blue),
                      foregroundColor: isCurrentPlan ? Colors.white : Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      isAdmin
                          ? 'Accès illimité'
                          : (isCurrentPlan ? '✅ Actif' : 'Choisir ce plan'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Badge "Actuel" si c'est le plan actif
          if (isCurrentPlan && !isAdmin)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ACTUEL',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===== WIDGET DÉTAILS ABONNEMENT =====
class SubscriptionDetailsSheet extends StatelessWidget {
  final dynamic sub;
  final List<Plan> plans;

  const SubscriptionDetailsSheet({
    super.key,
    required this.sub,
    required this.plans,
  });

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy');
    final planName = plans.firstWhere(
      (p) => p.id == sub.planId,
      orElse: () => Plan.getFreePlan(),
    ).name;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            children: [
              Icon(Icons.subscriptions, color: Colors.blue),
              const SizedBox(width: 12),
              Text(
                'Détails de votre abonnement',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          // Informations
          _infoRow('Plan', planName),
          _infoRow('Statut', sub.isActive ? 'Actif' : 'Inactif'),
          _infoRow('Début', format.format(sub.startDate)),
          _infoRow('Fin', format.format(sub.endDate)),
          _infoRow('Jours restants', '${sub.daysRemaining} jours'),
          if (sub.autoRenew) _infoRow('Renouvellement', 'Automatique'),
          const SizedBox(height: 20),
          // Boutons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Fermer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text('Annuler l\'abonnement'),
                        content: const Text(
                          'Voulez-vous vraiment annuler votre abonnement ? '
                          'Vous perdrez l\'accès aux fonctionnalités premium.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Non'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Oui, annuler'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await context.read<SubscriptionProvider>().cancelSubscription();
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Abonnement annulé avec succès'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('Annuler'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}