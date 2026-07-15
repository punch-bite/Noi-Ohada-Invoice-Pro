// lib/widgets/custom_drawer.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/theme_provider.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = authProvider.user;
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Column(
        children: [
          // Header du drawer (avatar + nom + email + badge)
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.7)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  child: Text(
                    user?.displayName.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.displayName ?? 'Utilisateur',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user?.email ?? 'user@email.com',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    subscriptionProvider.currentPlan?.name ?? 'Gratuit',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildTile(
                  icon: Icons.person_outline,
                  label: 'Profil',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/dashboard/profile');
                  },
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _buildTile(
                  icon: Icons.subscriptions,
                  label: 'Abonnement',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/subscription');
                  },
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _buildTile(
                  icon: Icons.style,
                  label: 'Modèles de factures',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/templates');
                  },
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                // 🔥 NOUVEAU : Fournisseurs
                _buildTile(
                  icon: Icons.business_outlined,
                  label: 'Fournisseurs',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/suppliers');
                  },
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                // 🔥 NOUVEAU : Rappels
                _buildTile(
                  icon: Icons.alarm_outlined,
                  label: 'Rappels',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/dashboard/reminders');
                  },
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),

                // Condition pour afficher le menu admin
                if (authProvider.user?.isAdmin == true)
                _buildTile(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Administration',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/admin');
                  },
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                
                const Divider(),
                _buildTile(
                  icon: Icons.settings_outlined,
                  label: 'Paramètres',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/dashboard/settings');
                  },
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                const Divider(),
                _buildTile(
                  icon: Icons.support_outlined,
                  label: 'Support',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/support');
                  },
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _buildTile(
                  icon: Icons.help_outline,
                  label: 'FAQ',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/support/faq');
                  },
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                const Divider(),
                _buildTile(
                  icon: Icons.logout,
                  label: 'Déconnexion',
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  isLogout: true,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog(context);
                  },
                ),
              ],
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'OHADA Invoice Pro v1.0.0',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isLogout
            ? Colors.red
            : (isDark ? Colors.grey[400] : Colors.grey[700]),
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isLogout ? Colors.red : textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final authProvider = context.read<AppAuthProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              authProvider.logout();
              Navigator.pop(context);
              context.go('/');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}
