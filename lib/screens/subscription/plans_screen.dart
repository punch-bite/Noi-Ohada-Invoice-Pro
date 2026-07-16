// lib/screens/subscription/plans_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // N'oubliez pas d'ajouter intl au pubspec.yaml
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final subProvider = context.read<SubscriptionProvider>();
    final authProvider = context.read<AppAuthProvider>();
    
    await subProvider.loadPlans();
    if (authProvider.user != null) {
      await subProvider.loadSubscriptions(authProvider.user!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    
    if (subProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final plans = subProvider.plans;
    final currentSub = subProvider.subscription;

    return Scaffold(
      appBar: AppBar(title: const Text('Nos offres')),
      body: Column(
        children: [
          _buildHeader(currentSub, plans),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                final isCurrent = currentSub != null && currentSub.planId == plan.id && currentSub.isActive;
                return PlanCard(
                  plan: plan,
                  isCurrentPlan: isCurrent,
                  onSelect: () => isCurrent ? _showSubscriptionDetails(subProvider) : _selectPlan(plan),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(dynamic currentSub, List<Plan> plans) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.blue[50]),
      child: Center(
        child: Text(
          currentSub?.isActive == true 
            ? 'Plan actuel : ${_getPlanName(plans, currentSub.planId)}'
            : 'Choisissez le plan qui vous correspond',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[800]),
        ),
      ),
    );
  }

  void _selectPlan(Plan plan) async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => PaymentScreen(plan: plan, onPaymentComplete: () {  },)),
    );
    if (success == true && mounted) _loadData();
  }

  void _showSubscriptionDetails(SubscriptionProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SubscriptionDetailsSheet(sub: provider.subscription!, plans: provider.plans),
    );
  }

  String _getPlanName(List<Plan> plans, String planId) => 
      plans.firstWhere((p) => p.id == planId, orElse: () => Plan.getFreePlan()).name;
}

// Extraction du Widget pour la lisibilité
class PlanCard extends StatelessWidget {
  final Plan plan;
  final bool isCurrentPlan;
  final VoidCallback onSelect;

  const PlanCard({super.key, required this.plan, required this.isCurrentPlan, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(plan.description),
        trailing: ElevatedButton(
          onPressed: onSelect,
          child: Text(isCurrentPlan ? 'Actif' : 'Choisir'),
        ),
      ),
    );
  }
}

// Widget pour le Modal Bottom Sheet
class SubscriptionDetailsSheet extends StatelessWidget {
  final dynamic sub;
  final List<Plan> plans;

  const SubscriptionDetailsSheet({super.key, required this.sub, required this.plans});

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Fin de l\'abonnement : ${format.format(sub.endDate)}'),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<SubscriptionProvider>().cancelSubscription();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Annuler l\'abonnement', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}