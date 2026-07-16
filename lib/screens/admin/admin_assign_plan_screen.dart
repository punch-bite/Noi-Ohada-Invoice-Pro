import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../models/plan.dart';
import '../../services/admin_service.dart';
import '../../services/subscription_service.dart';
import '../../providers/theme_provider.dart';

class AdminAssignPlanScreen extends StatefulWidget {
  const AdminAssignPlanScreen({super.key});

  @override
  State<AdminAssignPlanScreen> createState() => _AdminAssignPlanScreenState();
}

class _AdminAssignPlanScreenState extends State<AdminAssignPlanScreen> {
  final AdminService _adminService = AdminService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  List<AppUser> _users = [];
  List<Plan> _plans = [];
  AppUser? _selectedUser;
  Plan? _selectedPlan;
  int _durationMonths = 1;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _users = await _adminService.getAllUsers();
      _plans = await _subscriptionService.getPlans();
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _assignPlan() async {
    if (_selectedUser == null || _selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un utilisateur et un plan'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _adminService.createSubscriptionForUser(
        userId: _selectedUser!.id,
        planId: _selectedPlan!.id,
        durationMonths: _durationMonths,
        paymentMethod: 'admin_assign',
        amount: _selectedPlan!.price * _durationMonths,
        currency: _selectedPlan!.currency,
        interval: _selectedPlan!.interval,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan affecté avec succès'), backgroundColor: Colors.green),
      );
      context.pop(true);
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
    final primary = theme.primaryColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Affecter un plan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _assignPlan,
            child: Text(
              'Affecter',
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
                  // Sélection utilisateur
                  DropdownButtonFormField<AppUser>(
                    initialValue: _selectedUser,
                    isExpanded: true,
                    style: TextStyle(color: text),
                    dropdownColor: isDark ? Colors.grey[850] : Colors.white,
                    decoration: InputDecoration(
                      labelText: 'Utilisateur *',
                      labelStyle: TextStyle(color: sub),
                      prefixIcon: Icon(Icons.person, color: primary.withOpacity(0.5)),
                      filled: true,
                      fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      isDense: true,
                    ),
                    items: _users.map((u) {
                      return DropdownMenuItem<AppUser>(
                        value: u,
                        child: Text(u.displayName, style: TextStyle(color: text)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedUser = v),
                    validator: (v) => v == null ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),
                  // Sélection plan
                  DropdownButtonFormField<Plan>(
                    initialValue: _selectedPlan,
                    isExpanded: true,
                    style: TextStyle(color: text),
                    dropdownColor: isDark ? Colors.grey[850] : Colors.white,
                    decoration: InputDecoration(
                      labelText: 'Plan *',
                      labelStyle: TextStyle(color: sub),
                      prefixIcon: Icon(Icons.subscriptions, color: primary.withOpacity(0.5)),
                      filled: true,
                      fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      isDense: true,
                    ),
                    items: _plans.map((p) {
                      return DropdownMenuItem<Plan>(
                        value: p,
                        child: Text('${p.name} (${p.getFormattedPrice()})', style: TextStyle(color: text)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedPlan = v),
                    validator: (v) => v == null ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),
                  // Durée en mois
                  TextFormField(
                    initialValue: _durationMonths.toString(),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: text),
                    decoration: InputDecoration(
                      labelText: 'Durée (mois) *',
                      labelStyle: TextStyle(color: sub),
                      prefixIcon: Icon(Icons.timer, color: primary.withOpacity(0.5)),
                      filled: true,
                      fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _durationMonths = int.tryParse(v) ?? 1),
                    validator: (v) {
                      final val = int.tryParse(v ?? '');
                      if (val == null || val <= 0) return 'Durée valide requise';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  // Résumé
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _summaryRow('Utilisateur', _selectedUser?.displayName ?? 'Non sélectionné', text, sub),
                        _summaryRow('Plan', _selectedPlan?.name ?? 'Non sélectionné', text, sub),
                        _summaryRow('Prix', _selectedPlan?.getFormattedPrice() ?? '0 FCFA', text, sub),
                        _summaryRow('Durée', '$_durationMonths mois', text, sub),
                        const Divider(height: 16),
                        _summaryRow('Total', _selectedPlan != null ? '${(_selectedPlan!.price * _durationMonths).toStringAsFixed(0)} ${_selectedPlan!.currency}' : '0 FCFA', primary, sub, bold: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryRow(String label, String value, Color text, Color sub, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: sub, fontSize: 14)),
          Text(value, style: TextStyle(color: text, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
        ],
      ),
    );
  }
}