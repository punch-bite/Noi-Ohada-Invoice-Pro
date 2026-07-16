// lib/screens/dashboard/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../models/user.dart';
import '../../services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final user = authProvider.user;
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final primaryColor = themeProvider.primaryColor;
    final bgColor = themeProvider.backgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Paramètres',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // ===== PROFIL =====
            _buildProfileTile(
              user,
              textColor,
              subTextColor,
              primaryColor,
              isDark,
            ),
            const SizedBox(height: 8),
            // 🔥 Lien vers la modification du profil
            _buildProfileEditTile(
              context,
              isDark,
              textColor,
              subTextColor,
              primaryColor,
            ),
            const SizedBox(height: 24),

            // ===== SECTION COMPTE =====
            _buildSectionTitle('Compte', isDark, subTextColor),
            const SizedBox(height: 8),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.payment_outlined,
                  title: 'Abonnement',
                  subtitle: subscriptionProvider.currentPlan.name ?? 'Gratuit',
                  onTap: () => context.push('/subscription'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.business_outlined,
                  title: 'Entreprise',
                  subtitle: 'Configurer votre entreprise',
                  onTap: () => context.push('/dashboard/company-config'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.security_outlined,
                  title: 'Sécurité',
                  subtitle: 'Mot de passe, 2FA, biométrie',
                  onTap: () => context.push('/security'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ===== SECTION PERSONNALISATION =====
            _buildSectionTitle('Personnalisation', isDark, subTextColor),
            const SizedBox(height: 8),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Thème',
                  subtitle: _getThemeLabel(themeProvider.currentTheme),
                  onTap: () => _showThemeDialog(context, themeProvider),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.receipt_long,
                  title: 'Modèles de factures',
                  subtitle: 'Personnaliser vos factures',
                  onTap: () => context.push('/customization'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Gérer vos alertes',
                  onTap: () => context.push('/notifications'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ===== SECTION SUPPORT =====
            _buildSectionTitle('Support', isDark, subTextColor),
            const SizedBox(height: 8),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.help_outline,
                  title: 'Centre d\'aide',
                  subtitle: 'FAQ et documentation',
                  onTap: () => context.push('/support/faq'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.chat,
                  title: 'Support en ligne',
                  subtitle: 'Discuter avec notre équipe',
                  onTap: () => context.push('/support'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.email_outlined,
                  title: 'Contacter le support',
                  subtitle: 'Envoyez-nous un email',
                  onTap: () => context.push('/support/contact'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ===== SECTION À PROPOS =====
            _buildSectionTitle('À propos', isDark, subTextColor),
            const SizedBox(height: 8),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'OHADA Invoice Pro',
                  subtitle: 'Version 1.0.0',
                  onTap: () => _showAboutDialog(context),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.logout,
                  title: 'Déconnexion',
                  subtitle: 'Se déconnecter de l\'application',
                  onTap: () => _showLogoutDialog(context, authProvider),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  isDanger: true,
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ===== PROFIL TILE =====
  Widget _buildProfileTile(
    AppUser? user,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                user?.displayName.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Utilisateur',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Text(
                  user?.email ?? 'user@email.com',
                  style: TextStyle(
                    fontSize: 13,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: subTextColor,
            size: 20,
          ),
        ],
      ),
    );
  }

  // ===== PROFIL EDIT TILE (lien vers la modification) =====
  Widget _buildProfileEditTile(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(
          Icons.edit_outlined,
          color: primaryColor,
        ),
        title: Text(
          'Modifier le profil',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Mettre à jour vos informations',
          style: TextStyle(
            color: subTextColor,
            fontSize: 13,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: subTextColor,
          size: 20,
        ),
        onTap: () => context.push('/dashboard/profile'),
      ),
    );
  }

  // ===== SECTION TITLE =====
  Widget _buildSectionTitle(String title, bool isDark, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[400] : Colors.grey[500],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ===== SETTINGS CARD =====
  Widget _buildSettingsCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  // ===== THEME LABEL =====
  String _getThemeLabel(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return 'Clair';
      case AppTheme.dark:
        return 'Sombre';
      case AppTheme.system:
        return 'Système';
    }
  }

  // ===== THEME DIALOG =====
  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choisir un thème',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _ThemeOption(
              label: 'Clair',
              icon: Icons.light_mode,
              isSelected: themeProvider.currentTheme == AppTheme.light,
              onTap: () {
                themeProvider.setLightTheme();
                Navigator.pop(context);
              },
            ),
            _ThemeOption(
              label: 'Sombre',
              icon: Icons.dark_mode,
              isSelected: themeProvider.currentTheme == AppTheme.dark,
              onTap: () {
                themeProvider.setDarkTheme();
                Navigator.pop(context);
              },
            ),
            _ThemeOption(
              label: 'Système',
              icon: Icons.settings_suggest,
              isSelected: themeProvider.currentTheme == AppTheme.system,
              onTap: () {
                themeProvider.setSystemTheme();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===== ABOUT DIALOG =====
  void _showAboutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: const Text('À propos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long,
              size: 48,
              color: isDark ? Colors.blue[300] : Colors.blue,
            ),
            const SizedBox(height: 12),
            const Text(
              'OHADA Invoice Pro',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gestion de factures conforme OHADA',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // ===== LOGOUT DIALOG =====
  void _showLogoutDialog(BuildContext context, AppAuthProvider authProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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

// ===== WIDGETS INTERNES =====

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDark;
  final Color textColor;
  final Color subTextColor;
  final bool isDanger;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
    required this.textColor,
    required this.subTextColor,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDanger ? Colors.red : textColor,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDanger ? Colors.red : textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: subTextColor,
          fontSize: 13,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDanger ? Colors.red : (isDark ? Colors.grey[500] : Colors.grey[400]),
        size: 20,
      ),
      onTap: onTap,
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  final bool isDark;

  const _SettingsDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: isDark ? Colors.grey[800] : Colors.grey[100],
      indent: 16,
      endIndent: 16,
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue : (isDark ? Colors.grey[400] : Colors.grey[500]),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.blue, size: 20)
          : null,
      onTap: onTap,
    );
  }
}