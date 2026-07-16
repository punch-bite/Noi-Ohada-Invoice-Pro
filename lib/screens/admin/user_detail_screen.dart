// lib/screens/admin/user_detail_screen.dart
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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = await _adminService.getUserById(widget.userId);
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur lors de la récupération de l'utilisateur : $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleActive() async {
    if (_user == null || _isUpdating) return;
    setState(() => _isUpdating = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _adminService.toggleUserActive(_user!.id, !_user!.isActive);
      await _loadUser();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la modification du statut : $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _toggleAdmin() async {
    if (_user == null || _isUpdating) return;
    setState(() => _isUpdating = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final newRoles = _user!.isAdmin ? ['user'] : ['user', 'admin'];
      await _adminService.updateUserRoles(_user!.id, newRoles);
      await _loadUser();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la modification des rôles : $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
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
        appBar: AppBar(
          title: const Text('Détail utilisateur'),
          backgroundColor: Colors.transparent,
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
            onPressed: () => context.go('/admin/users'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 60, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  'Utilisateur introuvable',
                  style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le compte utilisateur recherché n\'existe pas ou a été supprimé.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: sub, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/admin/users'),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Retourner à la liste'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
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
        title: Text(
          'Profil Utilisateur',
          style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.go('/admin/users'),
        ),
        actions: [
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entête d'identité (Avatar, Nom, Email)
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary, primary.withOpacity(0.75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primary.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Center(
                      child: Text(
                        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.displayName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: TextStyle(fontSize: 13, color: sub),
                  ),
                  if (user.companyName != null && user.companyName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user.companyName!,
                        style: TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Infos Section
            _infoSection(
              title: 'Informations de compte',
              textColor: text,
              cardColor: card,
              isDark: isDark,
              children: [
                _infoRow('Email', user.email, text, sub),
                if (user.phone != null && user.phone!.trim().isNotEmpty)
                  _infoRow('Téléphone', user.phone!, text, sub),
                if (user.companyName != null && user.companyName!.isNotEmpty)
                  _infoRow('Entreprise', user.companyName!, text, sub),
                if (user.companyAddress != null && user.companyAddress!.isNotEmpty)
                  _infoRow('Adresse', user.companyAddress!, text, sub),
                if (user.taxId != null && user.taxId!.isNotEmpty)
                  _infoRow('NUI / Identifiant fiscal', user.taxId!, text, sub),
                _infoRow('Droits d\'accès', user.isAdmin ? 'Administrateur' : 'Utilisateur standard', text, sub),
                _infoRow('Statut d\'activité', user.isActive ? 'Actif' : 'Désactivé', user.isActive ? Colors.green : Colors.red, sub),
                _infoRow(
                  'Inscrit le',
                  '${user.createdAt.day.toString().padLeft(2, '0')}/${user.createdAt.month.toString().padLeft(2, '0')}/${user.createdAt.year}',
                  text,
                  sub,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Actions Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Actions d\'administration',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: text),
              ),
            ),
            const SizedBox(height: 10),
            
            _actionTile(
              icon: user.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
              title: user.isActive ? 'Désactiver le compte' : 'Activer le compte',
              color: user.isActive ? Colors.redAccent : Colors.green,
              cardColor: card,
              textColor: text,
              isDark: isDark,
              onTap: _toggleActive,
            ),
            _actionTile(
              icon: user.isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_add_alt_rounded,
              title: user.isAdmin ? 'Retirer les droits administrateur' : 'Promouvoir au rôle administrateur',
              color: user.isAdmin ? Colors.orangeAccent : Colors.purple,
              cardColor: card,
              textColor: text,
              isDark: isDark,
              onTap: _toggleAdmin,
            ),
            _actionTile(
              icon: Icons.subscriptions_rounded,
              title: 'Gérer les abonnements',
              color: Colors.indigoAccent,
              cardColor: card,
              textColor: text,
              isDark: isDark,
              onTap: () => context.push('/admin/users/${user.id}/subscriptions'),
            ),
            _actionTile(
              icon: Icons.history_rounded,
              title: 'Consulter l\'historique d\'activité',
              color: Colors.teal,
              cardColor: card,
              textColor: text,
              isDark: isDark,
              onTap: () => context.push('/admin/logs?userId=${user.id}'),
            ),
            _actionTile(
              icon: Icons.add_circle_outline_rounded,
              title: 'Ajouter un abonnement manuel',
              color: Colors.green,
              cardColor: card,
              textColor: text,
              isDark: isDark,
              onTap: () => context.push('/admin/users/${user.id}/add-subscription'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoSection({
    required String title, 
    required List<Widget> children,
    required Color textColor,
    required Color cardColor,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
              width: 0.5,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, Color valueColor, Color subColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label, 
              style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value, 
              style: TextStyle(fontSize: 12, color: valueColor, fontWeight: FontWeight.w600),
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
    required Color cardColor,
    required Color textColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
          width: 0.5,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.grey[600] : Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }
}