// lib/screens/admin/admin_add_subscription_screen.dart
// ignore_for_file: duplicate_ignore, use_build_context_synchronously, unused_local_variable

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';
import '../../services/subscription_service.dart';
import '../../models/user.dart';
import '../../models/plan.dart';

class AdminAddSubscriptionScreen extends StatefulWidget {
  final String? userId; // optionnel, si on vient du détail d'un utilisateur
  const AdminAddSubscriptionScreen({super.key, this.userId});

  @override
  State<AdminAddSubscriptionScreen> createState() =>
      _AdminAddSubscriptionScreenState();
}

class _AdminAddSubscriptionScreenState
    extends State<AdminAddSubscriptionScreen> {
  final AdminService _adminService = AdminService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  List<AppUser> _users = [];
  List<Plan> _plans = [];
  AppUser? _selectedUser;
  Plan? _selectedPlan;
  String _paymentMethod = 'orange_money';
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _users = await _adminService.getAllUsers();
    _plans = await _subscriptionService.getPlans();
    if (widget.userId != null) {
      _selectedUser = _users.firstWhere((u) => u.id == widget.userId,
          orElse: () => _users.first);
    }
    if (_plans.isNotEmpty) _selectedPlan = _plans.first;
    setState(() => _isLoading = false);
  }

  Future<void> _submit() async {
    if (_selectedUser == null || _selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez sélectionner un utilisateur et un plan'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _adminService.createSubscriptionForUser(
        userId: _selectedUser!.id,
        planId: _selectedPlan!.id,
        paymentMethod: _paymentMethod,
        amount: _selectedPlan!.price,
        currency: _selectedPlan!.currency,
        interval: _selectedPlan!.interval,
      );
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Abonnement créé avec succès'),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;
    final card = theme.cardColor;
    final primary = theme.primaryColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Ajouter un abonnement'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(
              'Créer',
              style: TextStyle(color: primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Utilisateur
                  DropdownButtonFormField<AppUser>(
                    initialValue: _selectedUser,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Utilisateur *',
                      labelStyle: TextStyle(color: sub),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _users.map((u) {
                      return DropdownMenuItem<AppUser>(
                        value: u,
                        child: Text(u.displayName),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedUser = v),
                  ),
                  const SizedBox(height: 16),

                  // Plan
                  DropdownButtonFormField<Plan>(
                    initialValue: _selectedPlan,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Plan *',
                      labelStyle: TextStyle(color: sub),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _plans.map((p) {
                      return DropdownMenuItem<Plan>(
                        value: p,
                        child: Text('${p.name} - ${p.getFormattedPrice()}'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedPlan = v),
                  ),
                  const SizedBox(height: 16),

                  // Méthode de paiement
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Méthode de paiement',
                      labelStyle: TextStyle(color: sub),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'orange_money', child: Text('Orange Money')),
                      DropdownMenuItem(
                          value: 'mtn_money', child: Text('MTN Mobile Money')),
                      DropdownMenuItem(value: 'wave', child: Text('Wave')),
                      DropdownMenuItem(
                          value: 'stripe', child: Text('Carte bancaire')),
                    ],
                    onChanged: (v) => setState(() => _paymentMethod = v!),
                  ),
                  const SizedBox(height: 24),

                  // Résumé
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Utilisateur', style: TextStyle(color: sub)),
                            Text(
                                _selectedUser?.displayName ?? 'Non sélectionné',
                                style: TextStyle(color: text)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Plan', style: TextStyle(color: sub)),
                            Text(_selectedPlan?.name ?? 'Non sélectionné',
                                style: TextStyle(color: text)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Montant', style: TextStyle(color: sub)),
                            Text(_selectedPlan?.getFormattedPrice() ?? '0 FCFA',
                                style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
