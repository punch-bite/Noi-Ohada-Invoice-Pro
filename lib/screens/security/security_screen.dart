// lib/screens/security/security_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/security_service.dart';
import '../../services/logger_service.dart'; // Nouvel import
import 'change_password_screen.dart';
import 'sessions_screen.dart';
import 'activity_log_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _biometricEnabled = false;
  bool _twoFactorEnabled = false;
  bool _isPinSet = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        SecurityService.isBiometricEnabled(),
        SecurityService.isTwoFactorEnabled(),
        SecurityService.isPinSet(),
      ]);

      setState(() {
        _biometricEnabled = results[0];
        _twoFactorEnabled = results[1];
        _isPinSet = results[2];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final bgColor = themeProvider.backgroundColor;
    final shadowColor = themeProvider.shadowColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Sécurité',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView(context, isDark, textColor, subTextColor, primaryColor)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // ===== AUTHENTIFICATION =====
                      _buildSectionHeader('Authentification', isDark, subTextColor),
                      const SizedBox(height: 8),
                      _buildCard(
                        isDark: isDark,
                        cardColor: cardColor,
                        shadowColor: shadowColor,
                        children: [
                          _buildListTile(
                            context: context,
                            icon: Icons.lock_outline,
                            title: 'Changer le mot de passe',
                            subtitle: 'Modifier votre mot de passe actuel',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                            ),
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            primaryColor: primaryColor,
                          ),
                          _buildDivider(isDark),
                          _buildSwitchTile(
                            context: context,
                            icon: Icons.fingerprint,
                            title: 'Empreinte digitale',
                            subtitle: 'Connexion par empreinte ou Face ID',
                            value: _biometricEnabled,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            primaryColor: primaryColor,
                            onChanged: (value) async {
                              if (value) {
                                final available = await SecurityService.isBiometricAvailable();
                                if (!available) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('La biométrie n\'est pas disponible'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                final authenticated = await SecurityService.authenticateWithBiometrics();
                                if (!authenticated) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Authentification échouée'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                              }
                              await SecurityService.setBiometricEnabled(value);
                              _loadSecuritySettings();
                            },
                          ),
                          _buildDivider(isDark),
                          _buildSwitchTile(
                            context: context,
                            icon: Icons.pin,
                            title: 'Code PIN',
                            subtitle: _isPinSet ? 'Code PIN activé' : 'Définir un code PIN',
                            value: _isPinSet,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            primaryColor: primaryColor,
                            onChanged: (value) => _showPinDialog(context, value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ===== SÉCURITÉ AVANCÉE =====
                      _buildSectionHeader('Sécurité avancée', isDark, subTextColor),
                      const SizedBox(height: 8),
                      _buildCard(
                        isDark: isDark,
                        cardColor: cardColor,
                        shadowColor: shadowColor,
                        children: [
                          _buildSwitchTile(
                            context: context,
                            icon: Icons.security,
                            title: 'Authentification à deux facteurs (2FA)',
                            subtitle: 'Ajoutez une couche de sécurité supplémentaire',
                            value: _twoFactorEnabled,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            primaryColor: primaryColor,
                            onChanged: (value) => _showTwoFactorDialog(context, value),
                          ),
                          _buildDivider(isDark),
                          _buildListTile(
                            context: context,
                            icon: Icons.devices,
                            title: 'Sessions actives',
                            subtitle: 'Gérer vos appareils connectés',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SessionsScreen()),
                            ),
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            primaryColor: primaryColor,
                          ),
                          _buildDivider(isDark),
                          _buildListTile(
                            context: context,
                            icon: Icons.history,
                            title: 'Journal d\'activité',
                            subtitle: 'Consulter l\'historique des actions',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ActivityLogScreen()),
                            ),
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            primaryColor: primaryColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ===== VERROUILLAGE =====
                      _buildSectionHeader('Verrouillage', isDark, subTextColor),
                      const SizedBox(height: 8),
                      _buildCard(
                        isDark: isDark,
                        cardColor: cardColor,
                        shadowColor: shadowColor,
                        children: [
                          _buildTimeoutSelector(
                            context,
                            isDark,
                            textColor,
                            subTextColor,
                            primaryColor,
                            cardColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  // ===== WIDGETS =====

  Widget _buildErrorView(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: isDark ? Colors.grey[400] : Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Une erreur est survenue',
            style: TextStyle(
              fontSize: 14,
              color: subTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadSecuritySettings,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCard({
    required bool isDark,
    required Color cardColor,
    required Color shadowColor,
    required List<Widget> children,
  }) {
    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildListTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color primaryColor,
    Color? color,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color == Colors.red
              ? Colors.red.withOpacity(0.1)
              : isDark
                  ? Colors.grey[800]!
                  : const Color(0xFFE8EAF6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: color ?? primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? (isDark ? Colors.white : Colors.black87),
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: subTextColor,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? Colors.grey[600] : Colors.grey[400],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color primaryColor,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800]! : const Color(0xFFE8EAF6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: subTextColor,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: primaryColor,
      ),
    );
  }

  Widget _buildTimeoutSelector(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    Color cardColor,
  ) {
    return FutureBuilder<int>(
      future: SecurityService.getLockTimeout(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            title: Text('Chargement...'),
          );
        }
        final timeout = snapshot.data ?? 5;
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800]! : const Color(0xFFE8EAF6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.timer_outlined,
              color: primaryColor,
              size: 20,
            ),
          ),
          title: Text(
            'Verrouillage automatique',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            'Verrouiller l\'application après $timeout min d\'inactivité',
            style: TextStyle(
              color: subTextColor,
            ),
          ),
          trailing: PopupMenuButton<int>(
            icon: Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            onSelected: (value) async {
              await SecurityService.setLockTimeout(value);
              _loadSecuritySettings();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 1, child: Text('1 minute')),
              const PopupMenuItem(value: 5, child: Text('5 minutes')),
              const PopupMenuItem(value: 15, child: Text('15 minutes')),
              const PopupMenuItem(value: 30, child: Text('30 minutes')),
              const PopupMenuItem(value: 60, child: Text('1 heure')),
              const PopupMenuItem(value: 0, child: Text('Jamais')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? Colors.grey[800] : Colors.grey[200],
      indent: 16,
      endIndent: 16,
    );
  }

  // ===== DIALOGUES =====

  void _showPinDialog(BuildContext context, bool enable) {
    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final primaryColor = themeProvider.primaryColor;

    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: cardColor,
        title: Text(
          enable ? 'Définir un code PIN' : 'Supprimer le code PIN',
          style: TextStyle(color: textColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (enable) ...[
              TextField(
                controller: pinController,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Code PIN (4 chiffres)',
                  labelStyle: TextStyle(color: subTextColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Confirmer le code PIN',
                  labelStyle: TextStyle(color: subTextColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                ),
              ),
            ] else ...[
              Text(
                'Voulez-vous vraiment supprimer votre code PIN ?',
                style: TextStyle(color: textColor),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: subTextColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (enable) {
                if (pinController.text.length != 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Le PIN doit contenir 4 chiffres'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (pinController.text != confirmController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Les PIN ne correspondent pas'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                await SecurityService.setPin(pinController.text);
                await LoggerService.info(
                  'pin_set',
                  details: 'Code PIN défini',
                );
              } else {
                await SecurityService.removePin();
                await LoggerService.info(
                  'pin_removed',
                  details: 'Code PIN supprimé',
                );
              }
              Navigator.pop(context);
              _loadSecuritySettings();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    enable ? 'Code PIN défini avec succès' : 'Code PIN supprimé',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(enable ? 'Définir' : 'Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showTwoFactorDialog(BuildContext context, bool enable) {
    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final primaryColor = themeProvider.primaryColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: cardColor,
        title: Text(
          enable ? 'Activer 2FA' : 'Désactiver 2FA',
          style: TextStyle(color: textColor),
        ),
        content: Text(
          enable
              ? 'L\'authentification à deux facteurs ajoute une couche de sécurité supplémentaire. Vous devrez entrer un code unique à chaque connexion.'
              : 'Voulez-vous vraiment désactiver l\'authentification à deux facteurs ?',
          style: TextStyle(color: subTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: subTextColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await SecurityService.setTwoFactorEnabled(enable);
              if (enable) {
                await SecurityService.setTwoFactorSecret(
                  DateTime.now().millisecondsSinceEpoch.toString(),
                );
                await LoggerService.info(
                  'two_factor_enabled',
                  details: '2FA activé',
                );
              } else {
                await LoggerService.info(
                  'two_factor_disabled',
                  details: '2FA désactivé',
                );
              }
              Navigator.pop(context);
              _loadSecuritySettings();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    enable ? '2FA activé avec succès' : '2FA désactivé',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(enable ? 'Activer' : 'Désactiver'),
          ),
        ],
      ),
    );
  }
}