// lib/screens/dashboard/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../models/user.dart';
import '../../services/theme_service.dart';
import '../../widgets/glass_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final user = authProvider.user;

    // 🔒 Sécurisation des couleurs
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final primaryColor = themeProvider.primaryColor;
    final bgColor = themeProvider.backgroundColor;
    final cardColor = themeProvider.cardColor;

        return GlassScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Paramètres',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== PROFIL =====
            _buildProfileTile(
              context,
              user,
              textColor,
              subTextColor,
              primaryColor,
              cardColor,
              isDark,
            ),
            const SizedBox(height: 24),

            // ===== SECTION COMPTE =====
            _buildSectionTitle('Compte', isDark, subTextColor),
            const SizedBox(height: 8),
            _buildSettingsCard(
              cardColor: cardColor,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.payment_outlined,
                  title: 'Abonnement',
                  subtitle: subscriptionProvider.currentPlan?.name ?? 'Gratuit',
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
            const SizedBox(height: 20),

            // ===== SECTION PERSONNALISATION =====
            _buildSectionTitle('Personnalisation', isDark, subTextColor),
            const SizedBox(height: 8),
            _buildSettingsCard(
              cardColor: cardColor,
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
                  premium: !subscriptionProvider.canAccessPremiumTemplates,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Portefeuille',
                  subtitle: 'Encaissements clients et retraits',
                  onTap: () => context.push('/wallet'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  premium: !subscriptionProvider.canCollectClientPayments,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Sauvegarde Google Drive',
                  subtitle: 'Synchroniser vos données (Business)',
                  onTap: () => context.push('/settings/drive-sync'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  premium: !subscriptionProvider.hasGoogleDriveSync,
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
            const SizedBox(height: 20),

            // ===== SECTION SUPPORT =====
            _buildSectionTitle('Support', isDark, subTextColor),
            const SizedBox(height: 8),
            _buildSettingsCard(
              cardColor: cardColor,
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
            const SizedBox(height: 20),

            // ===== SECTION À PROPOS =====
            _buildSectionTitle('À propos', isDark, subTextColor),
            const SizedBox(height: 8),
            _buildSettingsCard(
              cardColor: cardColor,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'OHADA Invoice Pro',
                  subtitle: 'Version 1.0.0',
                  onTap: () => _showAboutDialog(
                    context,
                    cardColor,
                    primaryColor,
                    textColor,
                    subTextColor,
                  ),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                // 🧪 Test paiement E-nkap — visible UNIQUEMENT pour l'admin.
                if (authProvider.user?.isAdmin == true) ...[
                  _SettingsDivider(isDark: isDark),
                  _SettingsTile(
                    icon: Icons.payment,
                    title: 'Test paiement E-nkap',
                    subtitle: 'Écran de test développeur (admin uniquement)',
                    onTap: () => context.push('/dev/enkap-test'),
                    isDark: isDark,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                ],
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.logout,
                  title: 'Déconnexion',
                  subtitle: 'Se déconnecter de l\'application',
                  onTap: () => _showLogoutDialog(
                    context,
                    authProvider,
                    cardColor,
                    textColor,
                    subTextColor,
                  ),
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

  // ===== PROFIL TILE (SÉCURISÉ) =====
  Widget _buildProfileTile(
    BuildContext context,
    AppUser? user,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    Color cardColor,
    bool isDark,
  ) {
    // ✅ VÉRIFICATION CRUCIALE : si user est null, on ne construit rien
    if (user == null) {
      return const SizedBox.shrink();
    }

    final String displayName = user.displayName;
    final String email = user.email;
    final String initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'U';

        return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/dashboard/profile'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initial,
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
                        displayName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: subTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: subTextColor.withOpacity(0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== SECTION TITLE =====
  Widget _buildSectionTitle(String title, bool isDark, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ===== SETTINGS CARD =====
  Widget _buildSettingsCard({
    required Color cardColor,
    required bool isDark,
    required List<Widget> children,
  }) {
        return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
          width: 0.5,
        ),
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
    // NB : toutes les couleurs sont lues DANS le builder (via context.watch)
    // afin d'être re-calculées après le changement de thème. Aucune valeur
    // n'est capturée avant le rebuild (source d'écrans "gelés" ou obsolètes).
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomContext) {
        final theme = bottomContext.watch<ThemeProvider>();
        final cardColor = theme.cardColor;
        final textColor = theme.textColor;
        final primaryColor = theme.primaryColor;

        return Container(
          color: cardColor,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choisir un thème',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              _ThemeOption(
                label: 'Clair',
                icon: Icons.light_mode_outlined,
                isSelected: theme.currentTheme == AppTheme.light,
                onTap: () {
                  themeProvider.setLightTheme();
                  Navigator.of(bottomContext).pop();
                },
              ),
              _ThemeOption(
                label: 'Sombre',
                icon: Icons.dark_mode_outlined,
                isSelected: theme.currentTheme == AppTheme.dark,
                onTap: () {
                  themeProvider.setDarkTheme();
                  Navigator.of(bottomContext).pop();
                },
              ),
              _ThemeOption(
                label: 'Système',
                icon: Icons.settings_suggest_outlined,
                isSelected: theme.currentTheme == AppTheme.system,
                onTap: () {
                  themeProvider.setSystemTheme();
                  Navigator.of(bottomContext).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ===== ABOUT DIALOG =====
  void _showAboutDialog(
    BuildContext context,
    Color cardColor,
    Color primaryColor,
    Color textColor,
    Color subTextColor,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: cardColor,
        title: Text(
          'À propos',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long,
                size: 40,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'OHADA Invoice Pro',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Gestion de factures conforme OHADA',
              style: TextStyle(
                fontSize: 13,
                color: subTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Fermer',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== LOGOUT DIALOG =====
  void _showLogoutDialog(
    BuildContext context,
    AppAuthProvider authProvider,
    Color cardColor,
    Color textColor,
    Color subTextColor,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: cardColor,
        title: Text(
          'Déconnexion',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Voulez-vous vraiment vous déconnecter ?',
          style: TextStyle(color: subTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: textColor.withOpacity(0.7)),
            ),
          ),
          TextButton(
            onPressed: () {
              authProvider.logout();
              Navigator.pop(context);
              context.go('/');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text(
              'Se déconnecter',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== WIDGETS INTERNES (SÉCURISÉS) =====

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDark;
  final Color textColor;
  final Color subTextColor;
  final bool isDanger;
  final bool premium;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
    required this.textColor,
    required this.subTextColor,
    this.isDanger = false,
    this.premium = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDanger ? Colors.redAccent : textColor.withOpacity(0.8),
        size: 22,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                color: isDanger ? Colors.redAccent : textColor,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // ⭐ Badge premium sur les fonctionnalités payantes
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
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: subTextColor,
          fontSize: 13,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDanger
            ? Colors.redAccent
            : (isDark ? Colors.grey[500]! : Colors.grey[400]!),
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
      color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
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
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final primaryColor = themeProvider.primaryColor;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? primaryColor
            : (isDark ? Colors.grey[400]! : Colors.grey[600]!),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? primaryColor : textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: primaryColor, size: 20)
          : null,
      onTap: onTap,
    );
  }
}