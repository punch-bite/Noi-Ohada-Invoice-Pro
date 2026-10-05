// lib/screens/admin/admin_dashboard.dart
//
// 👑 Admin dashboard — épuré : stats en grille, actions iconographiées.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminService _adminService = AdminService();
  Map<String, int> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final stats = await _adminService.getUsersStats();
      if (!mounted) return;
      setState(() {
        _stats = stats.map((key, value) {
          if (value is num) return MapEntry(key, value.toInt());
          return MapEntry(key, 0);
        });
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de charger les stats : $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          'Administration',
          style: TextStyle(
            color: text,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section stats
                    _sectionLabel('Vue d\'ensemble', sub),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _statCard('Total', _stats['total'] ?? 0,
                            Icons.people_rounded, const Color(0xFF4F46E5),
                            isDark, text, sub),
                        const SizedBox(width: 10),
                        _statCard('Actifs', _stats['active'] ?? 0,
                            Icons.check_circle_rounded, const Color(0xFF10B981),
                            isDark, text, sub),
                        const SizedBox(width: 10),
                        _statCard('Inactifs', _stats['inactive'] ?? 0,
                            Icons.block_rounded, const Color(0xFFEF4444),
                            isDark, text, sub),
                      ],
                    ).animate().fadeIn(duration: 400.ms).slideY(
                          begin: 0.1,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _statCard('Admins', _stats['admins'] ?? 0,
                            Icons.admin_panel_settings_rounded,
                            const Color(0xFF8B5CF6), isDark, text, sub),
                        const SizedBox(width: 10),
                        _statCard('Utilisateurs', _stats['users'] ?? 0,
                            Icons.person_rounded, const Color(0xFFF59E0B),
                            isDark, text, sub),
                      ],
                    ).animate().fadeIn(delay: 50.ms, duration: 400.ms),
                    const SizedBox(height: 32),

                    // Section actions
                    _sectionLabel('Actions', sub),
                    const SizedBox(height: 12),

                    _actionTile(
                      icon: Icons.people_alt_rounded,
                      title: 'Gérer les utilisateurs',
                      subtitle: 'Rôles, activation, abonnements',
                      color: primary,
                      onTap: () => context.push('/admin/users'),
                      isDark: isDark,
                      text: text,
                      sub: sub,
                    ),
                    const SizedBox(height: 10),
                    _actionTile(
                      icon: Icons.history_toggle_off_rounded,
                      title: 'Logs d\'activité',
                      subtitle: 'Audit complet des actions',
                      color: const Color(0xFF06B6D4),
                      onTap: () => context.push('/admin/logs'),
                      isDark: isDark,
                      text: text,
                      sub: sub,
                    ),
                    const SizedBox(height: 10),
                    _actionTile(
                      icon: Icons.description_rounded,
                      title: 'Modèles de factures',
                      subtitle: 'Créer, éditer, publier',
                      color: const Color(0xFF7C3AED),
                      onTap: () => context.push('/admin/templates'),
                      isDark: isDark,
                      text: text,
                      sub: sub,
                    ),
                    const SizedBox(height: 10),
                    _actionTile(
                      icon: Icons.add_circle_outline_rounded,
                      title: 'Créer un plan',
                      subtitle: 'Nouveau forfait personnalisé',
                      color: const Color(0xFF10B981),
                      onTap: () => context.push('/admin/plans/create'),
                      isDark: isDark,
                      text: text,
                      sub: sub,
                    ),
                    const SizedBox(height: 10),
                    _actionTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Retraits portefeuille',
                      subtitle: 'Traiter les demandes en attente',
                      color: const Color(0xFFF59E0B),
                      onTap: () => context.push('/admin/withdrawals'),
                      isDark: isDark,
                      text: text,
                      sub: sub,
                    ),
                    const SizedBox(height: 10),
                    _actionTile(
                      icon: Icons.assignment_ind_rounded,
                      title: 'Affecter un plan',
                      subtitle: 'Assigner manuellement un forfait',
                      color: const Color(0xFF3B82F6),
                      onTap: () => context.push('/admin/assign-plan'),
                      isDark: isDark,
                      text: text,
                      sub: sub,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String label, Color sub) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: sub,
      ),
    );
  }

  Widget _statCard(
    String label,
    int count,
    IconData icon,
    Color color,
    bool isDark,
    Color text,
    Color sub,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D26) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 10),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: text,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: sub,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    required Color text,
    required Color sub,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(color: sub, fontSize: 11.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: sub.withValues(alpha: 0.5), size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}