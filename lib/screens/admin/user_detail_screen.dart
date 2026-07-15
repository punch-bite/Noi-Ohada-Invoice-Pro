// lib/screens/admin/user_detail_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';
import '../../models/user.dart';

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
    setState(() => _isLoading = true);
    _user = await _adminService.getUserById(widget.userId);
    setState(() => _isLoading = false);
  }

  Future<void> _toggleActive() async {
    if (_user == null) return;
    setState(() => _isUpdating = true);
    await _adminService.toggleUserActive(_user!.id, !_user!.isActive);
    await _loadUser();
    setState(() => _isUpdating = false);
  }

  Future<void> _toggleAdmin() async {
    if (_user == null) return;
    setState(() => _isUpdating = true);
    final newRoles = _user!.isAdmin ? ['user'] : ['user', 'admin'];
    await _adminService.updateUserRoles(_user!.id, newRoles);
    await _loadUser();
    setState(() => _isUpdating = false);
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
        appBar: AppBar(
          title: const Text('Détail utilisateur'),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
            onPressed: () => context.go('/admin/users'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Utilisateur non trouvé', style: TextStyle(color: text)),
              TextButton(
                onPressed: () => context.go('/admin/users'),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    final user = _user!;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(user.displayName, style: TextStyle(color: text)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.go('/admin/users'),
        ),
        actions: [
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary, primary.withOpacity(0.7)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        user.displayName[0].toUpperCase(),
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.displayName,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: text),
                  ),
                  Text(user.email, style: TextStyle(fontSize: 14, color: sub)),
                  if (user.companyName != null && user.companyName!.isNotEmpty)
                    Text(user.companyName!,
                        style: TextStyle(fontSize: 14, color: sub)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Infos
            _infoSection(
              title: 'Informations',
              children: [
                _infoRow('Email', user.email, text, sub),
                if (user.phone != null)
                  _infoRow('Téléphone', user.phone!, text, sub),
                if (user.companyName != null && user.companyName!.isNotEmpty)
                  _infoRow('Entreprise', user.companyName!, text, sub),
                if (user.companyAddress != null &&
                    user.companyAddress!.isNotEmpty)
                  _infoRow('Adresse', user.companyAddress!, text, sub),
                if (user.taxId != null && user.taxId!.isNotEmpty)
                  _infoRow('NUI', user.taxId!, text, sub),
                _infoRow('Rôle',
                    user.isAdmin ? 'Administrateur' : 'Utilisateur', text, sub),
                _infoRow(
                    'Statut', user.isActive ? 'Actif' : 'Inactif', text, sub),
                _infoRow(
                    'Inscrit le',
                    '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                    text,
                    sub),
              ],
            ),
            const SizedBox(height: 16),

            // Actions
            Text(
              'Actions',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: text),
            ),
            const SizedBox(height: 12),
            _actionTile(
              icon: user.isActive ? Icons.block : Icons.check_circle,
              title: user.isActive
                  ? 'Désactiver l\'utilisateur'
                  : 'Activer l\'utilisateur',
              color: user.isActive ? Colors.red : Colors.green,
              onTap: _toggleActive,
            ),
            _actionTile(
              icon: user.isAdmin ? Icons.admin_panel_settings : Icons.person,
              title: user.isAdmin
                  ? 'Retirer les droits admin'
                  : 'Donner les droits admin',
              color: user.isAdmin ? Colors.orange : Colors.purple,
              onTap: _toggleAdmin,
            ),
            _actionTile(
              icon: Icons.subscriptions,
              title: 'Voir l\'abonnement',
              color: Colors.blue,
              onTap: () {
                // Navigation vers l'abonnement
              },
            ),
            _actionTile(
              icon: Icons.subscriptions,
              title: 'Gérer les abonnements',
              color: Colors.indigo,
              onTap: () =>
                  context.push('/admin/users/${user.id}/subscriptions'),
            ),
            _actionTile(
              icon: Icons.history,
              title: 'Voir les logs de cet utilisateur',
              color: Colors.teal,
              onTap: () => context.push('/admin/logs?userId=${user.id}'),
            ),
            _actionTile(
              icon: Icons.add_circle_outline,
              title: 'Ajouter un abonnement',
              color: Colors.green,
              onTap: () =>
                  context.push('/admin/users/${user.id}/add-subscription'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _infoRow(String label, String value, Color text, Color sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 13, color: sub)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 13, color: text)),
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
  }) {
    final theme = context.watch<ThemeProvider>();
    final card = theme.cardColor;

    return Card(
      color: card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 0.5),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing:
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }
}
