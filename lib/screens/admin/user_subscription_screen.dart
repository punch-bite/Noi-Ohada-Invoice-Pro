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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final subscriptions =
          await _adminService.getUserSubscriptions(widget.userId);
      final plans = await _subscriptionService.getPlans();

      if (mounted) {
        setState(() {
          _subscriptions = subscriptions;
          _plans = plans;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur lors de la récupération des données : $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelSubscription(Subscription subscription) async {
    final theme = context.read<ThemeProvider>();
    String reason = '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Annuler l\'abonnement',
          style: TextStyle(
              color: theme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voulez-vous annuler cet abonnement ?',
              style: TextStyle(color: theme.textColor, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              style: TextStyle(color: theme.textColor, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Motif d\'annulation (optionnel)',
                hintStyle: TextStyle(color: theme.subTextColor, fontSize: 13),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: theme.isDarkMode
                          ? Colors.grey[800]!
                          : Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.primaryColor),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) => reason = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text('Conserver', style: TextStyle(color: theme.subTextColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Confirmer l\'annulation',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _adminService.cancelSubscription(subscription.id,
            reason: reason.isNotEmpty ? reason : null);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Abonnement annulé avec succès'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erreur d\'annulation : $e'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _extendSubscription(Subscription subscription) async {
    final theme = context.read<ThemeProvider>();
    int days = 0;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Prolonger l\'abonnement',
          style: TextStyle(
              color: theme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nombre de jours à ajouter :',
              style: TextStyle(color: theme.textColor, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              keyboardType: TextInputType.number,
              style: TextStyle(color: theme.textColor, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ex: 30',
                hintStyle: TextStyle(color: theme.subTextColor, fontSize: 13),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: theme.isDarkMode
                          ? Colors.grey[800]!
                          : Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.primaryColor),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (v) => days = int.tryParse(v) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Annuler', style: TextStyle(color: theme.subTextColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, days),
            style: TextButton.styleFrom(foregroundColor: theme.primaryColor),
            child: const Text('Prolonger',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null && result > 0 && mounted) {
      try {
        await _adminService.extendSubscription(subscription.id, result);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Abonnement prolongé de $result jours'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erreur : $e'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _changePlan(Subscription subscription) async {
    final theme = context.read<ThemeProvider>();
    Plan? selected = _plans.firstWhere((p) => p.id == subscription.planId,
        orElse: () => _plans.first);

    final result = await showDialog<Plan>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title:
            Text('Choisir un plan', style: TextStyle(color: theme.textColor)),
        content: SizedBox(
          width: double
              .maxFinite, // Important pour éviter les erreurs de contrainte
          child: DropdownButtonFormField<Plan>(
            initialValue: selected,
            // Correction visuelle : fond transparent et texte aux bonnes couleurs
            dropdownColor: theme.cardColor,
            style: TextStyle(color: theme.textColor, fontSize: 14),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: theme.subTextColor.withOpacity(0.5)),
              ),
            ),
            items: _plans
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.name),
                    ))
                .toList(),
            onChanged: (p) => selected = p,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => context.pop(), child: const Text('Annuler')),
          TextButton(
            onPressed: () => context.pop(selected),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        await _adminService.changeUserPlan(widget.userId, result.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Plan modifié avec succès : ${result.name}'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erreur : $e'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
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
        title: Text(
          'Gestion des abonnements',
          style:
              TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        : (subscription.isExpired ? Colors.redAccent : Colors.orange);

    // Recherche sécurisée et sans allocation mémoire superflue pour le plan par défaut
    final matchedPlan = _plans.cast<Plan?>().firstWhere(
          (p) => p?.id == subscription.planId,
          orElse: () => null,
        );
    final planName = matchedPlan?.name ?? 'Plan inconnu';

    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: statusColor.withOpacity(0.2), width: 0.5),
                  ),
                  child: Text(
                    subscription.isActive
                        ? 'Actif'
                        : (subscription.isExpired ? 'Expiré' : 'Annulé'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14, color: subTextColor),
                const SizedBox(width: 8),
                Text(
                  'Début : ${DateFormat('dd/MM/yyyy').format(subscription.startDate)}',
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.event_busy_rounded, size: 14, color: subTextColor),
                const SizedBox(width: 8),
                Text(
                  'Fin : ${DateFormat('dd/MM/yyyy').format(subscription.endDate)}',
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
              ],
            ),
            if (subscription.autoRenew) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.autorenew_rounded,
                      size: 14, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Renouvellement automatique actif',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            if (subscription.isActive) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _extendSubscription(subscription),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Prolonger',
                          style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _changePlan(subscription),
                      icon: const Icon(Icons.swap_horiz, size: 14),
                      label:
                          const Text('Changer', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _cancelSubscription(subscription),
                      icon: const Icon(Icons.cancel, size: 14),
                      label:
                          const Text('Annuler', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _emptyState(
      bool isDark, Color textColor, Color subTextColor, Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.subscriptions_rounded,
                  size: 48, color: primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun abonnement trouvé',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cet utilisateur ne possède aucun forfait actif ou expiré.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: subTextColor),
            ),
          ],
        ),
      ),
    );
  }
}
