// lib/screens/admin/user_detail_screen.dart
//
// 👤 Détail utilisateur — épuré : héro gradient, sections, actions iconographiées.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final AdminService _adminService = AdminService();
  AppUser? _user;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = await _adminService.getUserById(widget.userId);
      if (!mounted) return;
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive() async {
    if (_user == null || _isUpdating) return;
    setState(() => _isUpdating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _adminService.toggleUserActive(_user!.id, !_user!.isActive);
      await _loadUser();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _toggleAdmin() async {
    if (_user == null || _isUpdating) return;
    setState(() => _isUpdating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final newRoles = _user!.isAdmin ? ['user'] : ['user', 'admin'];
      await _adminService.updateUserRoles(_user!.id, newRoles);
      await _loadUser();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
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
    final card = theme.cardColor;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: text, size: 20),
            onPressed: () => context.go('/admin/users'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  'Utilisateur introuvable',
                  style: TextStyle(
                      color: text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = _user!;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
          onPressed: () => context.go('/admin/users'),
        ),
        title: Text(
          'Profil utilisateur',
          style: TextStyle(
            color: text,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (_isUpdating)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: primary),
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Héro
            _hero(user, primary),
            const SizedBox(height: 24),

            // Infos
            _sectionLabel('Informations', sub),
            const SizedBox(height: 10),
            _infoSection(
              card: card,
              isDark: isDark,
              rows: [
                _infoRow('Email', user.email, text, sub),
                if (user.phone?.trim().isNotEmpty ?? false)
                  _infoRow('Téléphone', user.phone!, text, sub),
                if (user.companyName?.trim().isNotEmpty ?? false)
                  _infoRow('Entreprise', user.companyName!, text, sub),
                if (user.companyAddress?.trim().isNotEmpty ?? false)
                  _infoRow('Adresse', user.companyAddress!, text, sub),
                if (user.taxId?.trim().isNotEmpty ?? false)
                  _infoRow('NIF / IFU', user.taxId!, text, sub),
                _infoRow(
                  'Droits',
                  user.isAdmin ? 'Administrateur' : 'Utilisateur standard',
                  text,
                  sub,
                ),
                _infoRow(
                  'Statut',
                  user.isActive ? 'Actif' : 'Désactivé',
                  user.isActive ? const Color(0xFF10B981) : Colors.redAccent,
                  sub,
                ),
                _infoRow(
                  'Inscrit le',
                  '${user.createdAt.day.toString().padLeft(2, '0')}/${user.createdAt.month.toString().padLeft(2, '0')}/${user.createdAt.year}',
                  text,
                  sub,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Actions
            _sectionLabel('Actions', sub),
            const SizedBox(height: 10),
            _actionTile(
              icon: user.isActive
                  ? Icons.block_rounded
                  : Icons.check_circle_rounded,
              title: user.isActive
                  ? 'Désactiver le compte'
                  : 'Activer le compte',
              color:
                  user.isActive ? Colors.redAccent : const Color(0xFF10B981),
              onTap: _toggleActive,
              card: card,
              text: text,
              sub: sub,
              isDark: isDark,
            ),
            _actionTile(
              icon: user.isAdmin
                  ? Icons.admin_panel_settings_rounded
                  : Icons.person_add_alt_rounded,
              title: user.isAdmin
                  ? 'Retirer les droits admin'
                  : 'Promouvoir administrateur',
              color: user.isAdmin
                  ? Colors.orangeAccent
                  : const Color(0xFF8B5CF6),
              onTap: _toggleAdmin,
              card: card,
              text: text,
              sub: sub,
              isDark: isDark,
            ),
            _actionTile(
              icon: Icons.subscriptions_rounded,
              title: 'Gérer les abonnements',
              color: const Color(0xFF4F46E5),
              onTap: () =>
                  context.push('/admin/users/${user.id}/subscriptions'),
              card: card,
              text: text,
              sub: sub,
              isDark: isDark,
            ),
            _actionTile(
              icon: Icons.history_rounded,
              title: 'Historique d\'activité',
              color: const Color(0xFF06B6D4),
              onTap: () => context.push('/admin/logs?userId=${user.id}'),
              card: card,
              text: text,
              sub: sub,
              isDark: isDark,
            ),
            _actionTile(
              icon: Icons.add_circle_outline_rounded,
              title: 'Ajouter un abonnement',
              color: const Color(0xFF10B981),
              onTap: () => context
                  .push('/admin/users/${user.id}/add-subscription'),
              card: card,
              text: text,
              sub: sub,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(AppUser user, Color primary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary,
            primary.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            user.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
            ),
          ),
          if (user.companyName?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                user.companyName!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(
          begin: -0.1,
          end: 0,
          duration: 400.ms,
          curve: Curves.easeOut,
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

  Widget _infoSection({
    required Color card,
    required bool isDark,
    required List<Widget> rows,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(children: rows),
    );
  }

  Widget _infoRow(
      String label, String value, Color valueColor, Color sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: sub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                color: valueColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    required Color card,
    required Color text,
    required Color sub,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
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
      ),
    );
  }
}