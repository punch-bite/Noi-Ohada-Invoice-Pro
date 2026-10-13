// lib/screens/dashboard/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/user.dart';
import '../../services/theme_service.dart';
import '../../services/locale_service.dart';
import '../../l10n/app_localizations.dart';
import '../../services/update_service.dart';
import '../../widgets/glass_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final l10n = AppLocalizations.of(context);
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
          l10n.settingsTitle,
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
            _buildSectionTitle(l10n.sectionAccount, isDark, subTextColor),
            const SizedBox(height: 8),
            _buildSettingsCard(
              cardColor: cardColor,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.payment_outlined,
                  title: l10n.subscription,
                  subtitle: subscriptionProvider.currentPlan?.name ?? l10n.free,
                  onTap: () => context.push('/subscription'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.business_outlined,
                  title: l10n.company,
                  subtitle: l10n.companySubtitle,
                  onTap: () => context.push('/dashboard/company-config'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.security_outlined,
                  title: l10n.security,
                  subtitle: l10n.securitySubtitle,
                  onTap: () => context.push('/security'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ===== SECTION PERSONNALISATION =====
            _buildSectionTitle(l10n.sectionPersonalization, isDark, subTextColor),
            const SizedBox(height: 8),
            _buildSettingsCard(
              cardColor: cardColor,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  title: l10n.theme,
                  subtitle: switch (themeProvider.currentTheme) {
                    AppTheme.light => l10n.themeLight,
                    AppTheme.dark => l10n.themeDark,
                    AppTheme.system => l10n.themeSystem,
                  },
                  onTap: () => _showThemeDialog(context, themeProvider),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.translate,
                  title: l10n.languageSetting,
                  subtitle: l10n.languageName(localeProvider.currentLanguage.languageCode),
                  onTap: () => _showLanguageDialog(context, localeProvider),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.receipt_long,
                  title: l10n.invoiceTemplates,
                  subtitle: l10n.invoiceTemplatesSubtitle,
                  onTap: () => context.push('/templates/mine'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  premium: !subscriptionProvider.canAccessPremiumTemplates,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: l10n.wallet,
                  subtitle: l10n.walletSubtitle,
                  onTap: () => context.push('/wallet'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  premium: !subscriptionProvider.canCollectClientPayments,
                ),
                                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.design_services_outlined,
                  title: l10n.invoiceSettings,
                  subtitle: l10n.invoiceSettingsSubtitle,
                  onTap: () => context.push('/dashboard/settings/invoice'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.ios_share_rounded,
                  title: l10n.exportData,
                  subtitle: l10n.exportDataSubtitle,
                  onTap: () => context.push('/dashboard/settings/export'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.cloud_upload_outlined,
                  title: l10n.driveBackup,
                  subtitle: l10n.driveBackupSubtitle,
                  onTap: () => context.push('/settings/drive-sync'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: l10n.notifications,
                  subtitle: l10n.notificationsSubtitle,
                  onTap: () => context.push('/notifications'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ===== SECTION SUPPORT =====
            _buildSectionTitle(l10n.sectionSupport, isDark, subTextColor),
            const SizedBox(height: 8),
            _buildSettingsCard(
              cardColor: cardColor,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.help_outline,
                  title: l10n.helpCenter,
                  subtitle: l10n.helpCenterSubtitle,
                  onTap: () => context.push('/support/faq'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.chat,
                  title: l10n.onlineSupport,
                  subtitle: l10n.onlineSupportSubtitle,
                  onTap: () => context.push('/support'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.email_outlined,
                  title: l10n.contactSupport,
                  subtitle: l10n.contactSupportSubtitle,
                  onTap: () => context.push('/support/contact'),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ===== SECTION À PROPOS =====
            _buildSectionTitle(l10n.sectionAbout, isDark, subTextColor),
            const SizedBox(height: 8),
            _buildSettingsCard(
              cardColor: cardColor,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: l10n.appName,
                  subtitle: l10n.versionLabel,
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
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.system_update_alt,
                  title: l10n.checkUpdates,
                  subtitle: l10n.checkUpdatesSubtitle,
                  onTap: () => UpdateService.checkAndPrompt(context, manual: true),
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                // 🧪 Test paiement E-nkap — visible UNIQUEMENT pour l'admin.
                if (authProvider.user?.isAdmin == true) ...[
                  _SettingsDivider(isDark: isDark),
                  _SettingsTile(
                    icon: Icons.payment,
                    title: l10n.enkapTest,
                    subtitle: l10n.enkapTestSubtitle,
                    onTap: () => context.push('/dev/enkap-test'),
                    isDark: isDark,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                ],
                _SettingsDivider(isDark: isDark),
                _SettingsTile(
                  icon: Icons.logout,
                  title: l10n.logout,
                  subtitle: l10n.logoutSubtitle,
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
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
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
                      colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
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
                  color: subTextColor.withValues(alpha: 0.7),
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
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
          width: 0.5,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
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
        final l10n = AppLocalizations.of(bottomContext);
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
                l10n.chooseTheme,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              _ThemeOption(
                label: l10n.themeLight,
                icon: Icons.light_mode_outlined,
                isSelected: theme.currentTheme == AppTheme.light,
                onTap: () {
                  themeProvider.setLightTheme();
                  Navigator.of(bottomContext).pop();
                },
              ),
              _ThemeOption(
                label: l10n.themeDark,
                icon: Icons.dark_mode_outlined,
                isSelected: theme.currentTheme == AppTheme.dark,
                onTap: () {
                  themeProvider.setDarkTheme();
                  Navigator.of(bottomContext).pop();
                },
              ),
              _ThemeOption(
                label: l10n.themeSystem,
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

  // ===== LANGUAGE DIALOG =====
  void _showLanguageDialog(BuildContext context, LocaleProvider localeProvider) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomContext) {
        final theme = bottomContext.watch<ThemeProvider>();
        final locale = bottomContext.watch<LocaleProvider>();
        final l10n = AppLocalizations.of(bottomContext);
        final cardColor = theme.cardColor;
        final textColor = theme.textColor;
        final primaryColor = theme.primaryColor;
        final isDark = theme.isDarkMode;

        return Container(
          color: cardColor,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.chooseLanguage,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              ...AppLanguage.values.map((language) {
                final selected = locale.currentLanguage == language;
                return _ThemeOption(
                  label: language.nativeName,
                  icon: Icons.language,
                  isSelected: selected,
                  onTap: () {
                    localeProvider.setLanguage(language);
                    Navigator.of(bottomContext).pop();
                  },
                );
              }),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.languageSettingSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                  ),
                ),
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
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: cardColor,
        title: Text(
          l10n.sectionAbout,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
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
              l10n.appName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.versionLabel,
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.appDescription,
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
              l10n.close,
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
      },
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
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: cardColor,
        title: Text(
          l10n.logoutDialogTitle,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n.logoutDialogMessage,
          style: TextStyle(color: subTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: textColor.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () {
              authProvider.logout();
              Navigator.pop(context);
              context.go('/');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(
              l10n.confirmLogout,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
      },
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
        color: isDanger ? Colors.redAccent : textColor.withValues(alpha: 0.8),
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