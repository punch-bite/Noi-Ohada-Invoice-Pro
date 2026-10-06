// lib/screens/admin/admin_assign_plan_screen.dart
//
// 🎯 Affecter un plan — épuré, durée tactile, récap animé.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/plan.dart';
import '../../models/user.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';
import '../../services/subscription_service.dart';

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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final users = await _adminService.getAllUsers();
      final plans = await _subscriptionService.getPlans();
      if (!mounted) return;
      setState(() {
        _users = users;
        _plans = plans;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _assignPlan() async {
    if (_selectedUser == null || _selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez un utilisateur et un plan'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

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
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Plan affecté avec succès'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted) navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Affecter un plan',
          style: TextStyle(
            color: text,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _assignPlan,
            style: TextButton.styleFrom(
              foregroundColor: primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text(
              'Affecter',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionLabel('Utilisateur', sub),
                  const SizedBox(height: 8),
                  _dropdown<AppUser>(
                    value: _selectedUser,
                    items: _users
                        .map((u) => DropdownMenuItem(
                              value: u,
                              child: Text(
                                u.displayName,
                                style: TextStyle(color: text),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedUser = v),
                    card: card,
                    isDark: isDark,
                    text: text,
                    sub: sub,
                    primary: primary,
                    icon: Icons.person_outline_rounded,
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 20),

                  _sectionLabel('Plan', sub),
                  const SizedBox(height: 8),
                  _dropdown<Plan>(
                    value: _selectedPlan,
                    items: _plans
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                '${p.name} · ${p.getFormattedPrice()}',
                                style: TextStyle(color: text),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedPlan = v),
                    card: card,
                    isDark: isDark,
                    text: text,
                    sub: sub,
                    primary: primary,
                    icon: Icons.subscriptions_rounded,
                  ).animate().fadeIn(delay: 50.ms, duration: 300.ms),
                  const SizedBox(height: 20),

                  _sectionLabel('Durée', sub),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_rounded,
                              color: primary, size: 20),
                          onPressed: _durationMonths > 1
                              ? () => setState(() => _durationMonths--)
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            '$_durationMonths mois',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_rounded,
                              color: primary, size: 20),
                          onPressed: () => setState(() => _durationMonths++),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
                  const SizedBox(height: 28),

                  _sectionLabel('Récapitulatif', sub),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                      ),
                    ),
                    child: Column(
                      children: [
                        _summaryRow('Utilisateur',
                            _selectedUser?.displayName ?? '—', text, sub),
                        _divider(isDark),
                        _summaryRow('Plan',
                            _selectedPlan?.name ?? '—', text, sub),
                        _divider(isDark),
                        _summaryRow(
                            'Prix', _selectedPlan?.getFormattedPrice() ?? '—',
                            text, sub),
                        _divider(isDark),
                        _summaryRow('Durée', '$_durationMonths mois', text, sub),
                        _divider(isDark),
                        _summaryRow(
                          'Total',
                          _selectedPlan != null
                              ? '${(_selectedPlan!.price * _durationMonths).toStringAsFixed(0)} ${_selectedPlan!.currency}'
                              : '—',
                          primary,
                          sub,
                          bold: true,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text, Color sub) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: sub,
      ),
    );
  }

  Widget _divider(bool isDark) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Divider(
          height: 1,
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      );

  Widget _dropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required Color card,
    required bool isDark,
    required Color text,
    required Color sub,
    required Color primary,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: sub),
        dropdownColor: card,
        style: TextStyle(color: text, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon:
              Icon(icon, size: 20, color: primary.withValues(alpha: 0.7)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value,
    Color valueColor,
    Color labelColor, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 13)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 15 : 13.5,
            ),
          ),
        ),
      ],
    );
  }
}