// lib/widgets/custom_drawer.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
          // Header du drawer (avatar + nom + email + badge) - CENTRÉ
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // ✅ Centré
              children: [
                const SizedBox(height: 20),
                // Avatar centré
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  child: Text(
                    user?.displayName.isNotEmpty == true
                        ? user!.displayName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Nom centré
                Text(
                  user?.displayName ?? 'Utilisateur',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center, // ✅ Centré
                ),
                const SizedBox(height: 2),
                // Email centré
                Text(
                  user?.email ?? 'user@email.com',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center, // ✅ Centré
                ),
                const SizedBox(height: 8),
                // Badge centré
                Center(
                  // ✅ Centré
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
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
                  premium: !subscriptionProvider.canAccessPremiumTemplates,
                ),
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
                // Dans CustomDrawer
                _buildTile(
                  icon: Icons.groups_outlined,
                  label: 'Équipes',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/teams');
                  },
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  premium: !subscriptionProvider.hasTeamAccess,
                ),
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
                _buildTile(
                  icon: Icons.campaign_outlined,
                  label: 'Relance clients',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/dashboard/relance');
                  },
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  premium: !subscriptionProvider.canUseRelance,
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
                _buildTile(
                  icon: Icons.share_outlined,
                  label: 'Partager l\'application',
                  onTap: () {
                    Navigator.pop(context);
                    _shareApp(context);
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

  /// Partage un lien de téléchargement de l'application.
  static Future<void> _shareApp(BuildContext context) async {
    const message = '🚀 Découvrez OHADA Invoice Pro — la facturation conforme '
        'OHADA/SYSCOHADA : factures, devis, clients, stock, équipe et '
        'paiement Mobile Money (Orange / MTN / carte).\n\n'
        '👉 Téléchargez-la : https://ohada-invoice-pro.com';
    try {
      await SharePlus.instance.share(ShareParams(text: message));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de partager : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    bool isLogout = false,
    bool premium = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isLogout
            ? Colors.red
            : (isDark ? Colors.grey[400] : Colors.grey[700]),
        size: 22,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: isLogout ? Colors.red : textColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // ⭐ Badge premium sur les fonctionnalités réservées aux plans payants
          if (premium) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE9B949).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFE9B949).withValues(alpha: 0.5),
                  width: 0.6,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 12, color: Color(0xFFB8860B)),
                  SizedBox(width: 2),
                  Text(
                    'PREMIUM',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB8860B),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
            onPressed: () async {
              // ✅ Attendre la déconnexion complète (incluant la purge des
              // données locales) avant de naviguer, pour éviter que
              // l'écran suivant affiche des données de l'utilisateur précédent.
              Navigator.pop(context); // ferme la boîte de dialogue
              await authProvider.logout();
              if (context.mounted) {
                context.go('/');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}
