// lib/screens/subscription/plans_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    await subscriptionProvider.loadPlans();
    
    final authProvider = context.read<AppAuthProvider>();
    if (authProvider.user != null) {
      await subscriptionProvider.loadSubscription(authProvider.user!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final authProvider = context.watch<AppAuthProvider>();

    if (subscriptionProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final plans = subscriptionProvider.plans;
    final currentSubscription = subscriptionProvider.subscription;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nos offres'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Choisissez le plan qui vous correspond',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentSubscription != null && currentSubscription.isActive
                      ? 'Vous êtes actuellement sur le plan ${_getPlanName(plans, currentSubscription.planId)}'
                      : 'Commencez gratuitement, évoluez ensuite',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Liste des plans
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                final isCurrentPlan = currentSubscription != null &&
                    currentSubscription.planId == plan.id &&
                    currentSubscription.isActive;
                
                return _buildPlanCard(
                  plan: plan,
                  isCurrentPlan: isCurrentPlan,
                  onSelect: () {
                    if (isCurrentPlan) {
                      _showSubscriptionDetails(context);
                    } else {
                      _selectPlan(plan);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required Plan plan,
    required bool isCurrentPlan,
    required VoidCallback onSelect,
  }) {
    final bool isFree = plan.isFree;
    final bool isPopular = plan.isPopular;

    return Card(
      elevation: isPopular ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPopular
            ? BorderSide(color: Colors.blue[700]!, width: 2)
            : BorderSide.none,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête du plan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isPopular ? Colors.blue[700] : Colors.black87,
                            ),
                          ),
                          if (plan.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              plan.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isPopular)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[700],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'POPULAIRE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Prix
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isFree ? 'Gratuit' : plan.getFormattedPrice(),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isFree ? Colors.green[700] : Colors.black87,
                      ),
                    ),
                    if (!isFree) ...[
                      const SizedBox(width: 4),
                      Text(
                        '/ ${plan.interval == 'year' ? 'an' : 'mois'}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Features
                ...plan.features.map((feature) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 20,
                        color: isFree ? Colors.green[400] : Colors.blue[400],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

                const SizedBox(height: 24),

                // Bouton
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrentPlan
                          ? Colors.green
                          : isPopular
                              ? Colors.blue
                              : Colors.grey[300],
                      foregroundColor: isCurrentPlan
                          ? Colors.white
                          : isPopular
                              ? Colors.white
                              : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isCurrentPlan
                          ? 'Plan actuel'
                          : isFree
                              ? 'Commencer gratuitement'
                              : 'Choisir ce plan',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isCurrentPlan)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ACTIF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _selectPlan(Plan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(plan: plan, onPaymentComplete: () {  },),
      ),
    ).then((success) {
      if (success == true) {
        _loadData();
      }
    });
  }

  void _showSubscriptionDetails(BuildContext context) {
    final provider = context.read<SubscriptionProvider>();
    final sub = provider.subscription;
    if (sub == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Détails de l\'abonnement',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Plan', _getPlanName(provider.plans, sub.planId)),
            _buildDetailRow('Début', _formatDate(sub.startDate)),
            _buildDetailRow('Fin', _formatDate(sub.endDate)),
            _buildDetailRow('Jours restants', '${sub.daysRemaining} jours'),
            _buildDetailRow('Statut', sub.isActive ? 'Actif' : 'Inactif'),
            _buildDetailRow(
              'Renouvellement automatique',
              sub.autoRenew ? 'Activé' : 'Désactivé',
            ),
            const SizedBox(height: 24),
            if (sub.isActive && !sub.isCanceled)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _showCancelDialog(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Annuler l\'abonnement'),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getPlanName(List<Plan> plans, String planId) {
    final plan = plans.firstWhere(
      (p) => p.id == planId,
      orElse: () => Plan.getFreePlan(),
    );
    return plan.name;
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler l\'abonnement'),
        content: const Text(
          'Êtes-vous sûr de vouloir annuler votre abonnement ? '
          'Vous perdrez l\'accès aux fonctionnalités premium à la fin de la période en cours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Fermer le dialog
              Navigator.pop(context); // Fermer le bottom sheet
              final provider = context.read<SubscriptionProvider>();
              await provider.cancelSubscription();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Abonnement annulé avec succès'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirmer l\'annulation'),
          ),
        ],
      ),
    );
  }
}