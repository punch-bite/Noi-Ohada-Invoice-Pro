// lib/screens/admin/user_subscription_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';
import '../../services/subscription_service.dart';
import '../../models/subscription.dart';
import '../../models/plan.dart';

class UserSubscriptionScreen extends StatefulWidget {
  final String userId;
  const UserSubscriptionScreen({super.key, required this.userId});

  @override
  State<UserSubscriptionScreen> createState() => _UserSubscriptionScreenState();
}

class _UserSubscriptionScreenState extends State<UserSubscriptionScreen> {
  final AdminService _adminService = AdminService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  List<Subscription> _subscriptions = [];
  List<Plan> _plans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _subscriptions = await _adminService.getUserSubscriptions(widget.userId);
    _plans = await _subscriptionService.getPlans();
    setState(() => _isLoading = false);
  }

  Future<void> _cancelSubscription(Subscription subscription) async {
    String reason = '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler l\'abonnement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Voulez-vous annuler cet abonnement ?'),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Motif (optionnel)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => reason = value,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Annuler l\'abonnement'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _adminService.cancelSubscription(subscription.id, reason: reason.isNotEmpty ? reason : null);
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abonnement annulé'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _extendSubscription(Subscription subscription) async {
    int days = 0;
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Prolonger l\'abonnement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nombre de jours à ajouter :'),
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '30',
              ),
              onChanged: (v) => days = int.tryParse(v) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, days),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('Prolonger'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      await _adminService.extendSubscription(subscription.id, result);
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Abonnement prolongé de $result jours'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _changePlan(Subscription subscription) async {
    Plan? selected = _plans.firstWhere((p) => p.id == subscription.planId, orElse: () => _plans.first);
    final result = await showDialog<Plan>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Changer de plan'),
        content: DropdownButton<Plan>(
          isExpanded: true,
          value: selected,
          items: _plans.map((p) => DropdownMenuItem<Plan>(value: p, child: Text(p.name))).toList(),
          onChanged: (p) => selected = p,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, selected),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('Changer'),
          ),
        ],
      ),
    );
    if (result != null) {
      await _adminService.changeUserPlan(widget.userId, result.id);
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plan changé vers ${result.name}'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final text = theme.textColor;
    final subTextColor = theme.subTextColor;
    final bg = theme.backgroundColor;
    final card = theme.cardColor;
    final primary = theme.primaryColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Gestion des abonnements'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subscriptions.isEmpty
              ? _emptyState(isDark, text, subTextColor, primary)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _subscriptions.length,
                  itemBuilder: (context, index) {
                    final subscription = _subscriptions[index];
                    return _subscriptionCard(
                      subscription,
                      isDark,
                      text,
                      subTextColor,
                      card,
                      primary,
                    );
                  },
                ),
    );
  }

  Widget _subscriptionCard(
    Subscription subscription,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color primaryColor,
  ) {
    final statusColor = subscription.isActive
        ? Colors.green
        : (subscription.isExpired ? Colors.red : Colors.orange);
    final planName = _plans.firstWhere(
      (p) => p.id == subscription.planId,
      orElse: () => Plan(
        id: '',
        name: 'Inconnu',
        description: '',
        price: 0,
        currency: 'XAF',
        interval: 'month',
      ),
    ).name;

    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  planName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    subscription.isActive
                        ? 'Actif'
                        : (subscription.isExpired ? 'Expiré' : 'Annulé'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Début : ${DateFormat('dd/MM/yyyy').format(subscription.startDate)}',
              style: TextStyle(fontSize: 13, color: subTextColor),
            ),
            Text(
              'Fin : ${DateFormat('dd/MM/yyyy').format(subscription.endDate)}',
              style: TextStyle(fontSize: 13, color: subTextColor),
            ),
            if (subscription.autoRenew)
              const Text(
                'Renouvellement automatique',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
            if (subscription.isActive) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _extendSubscription(subscription),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Prolonger'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _changePlan(subscription),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Changer de plan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _cancelSubscription(subscription),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Annuler'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyState(bool isDark, Color textColor, Color subTextColor, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.subscriptions, size: 64, color: subTextColor),
          const SizedBox(height: 16),
          Text(
            'Aucun abonnement',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cet utilisateur n\'a pas encore d\'abonnement',
            style: TextStyle(fontSize: 14, color: subTextColor),
          ),
        ],
      ),
    );
  }
}