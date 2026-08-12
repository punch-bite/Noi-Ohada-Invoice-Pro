import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/security_service.dart';
import '../../services/two_factor_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      SecurityService.isBiometricEnabled(),
      SecurityService.isTwoFactorEnabled(),
      SecurityService.isPinSet(),
    ]);
    if (!mounted) return;
    setState(() {
      _biometricEnabled = results[0];
      _twoFactorEnabled = results[1];
      _isPinSet = results[2];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('Sécurité'),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection('AUTHENTIFICATION'),
                _buildCard([
                  _buildOptionTile(Icons.lock_outline, 'Mot de passe', 'Modifier votre mot de passe', 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
                  _buildDivider(),
                  _buildSwitchTile(Icons.fingerprint, 'Biométrie', 'Face ID ou Empreinte', _biometricEnabled, (val) => _handleBiometric(val)),
                  _buildDivider(),
                  _buildSwitchTile(Icons.pin, 'Code PIN', _isPinSet ? 'Activé' : 'Désactivé', _isPinSet, (val) => _showPinDialog(val)),
                ]),
                
                const SizedBox(height: 24),
                _buildSection('SÉCURITÉ AVANCÉE'),
                _buildCard([
                  _buildSwitchTile(Icons.security, '2FA', 'Authentification forte', _twoFactorEnabled, (val) => _showTwoFactorDialog(val)),
                  _buildDivider(),
                  _buildOptionTile(Icons.devices, 'Sessions', 'Gérer vos appareils', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionsScreen()))),
                  _buildDivider(),
                  _buildOptionTile(Icons.history, 'Journal', 'Historique des accès', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityLogScreen()))),
                ]),
              ],
            ),
    );
  }

  // --- Composants UI ---

  Widget _buildSection(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
    child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
  );

  Widget _buildCard(List<Widget> children) => Card(
    elevation: 0,
    color: Theme.of(context).cardColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5))),
    child: Column(children: children),
  );

  Widget _buildOptionTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) => ListTile(
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );

  Widget _buildSwitchTile(IconData icon, String title, String subtitle, bool value, Function(bool) onChanged) => ListTile(
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    trailing: Switch.adaptive(value: value, onChanged: onChanged),
  );

  Widget _buildDivider() => Divider(height: 1, indent: 16, endIndent: 16, color: Theme.of(context).dividerColor.withValues(alpha: 0.5));

  // --- Logiques ---
  
  Future<void> _handleBiometric(bool enable) async {
    if (enable) {
      final success = await SecurityService.authenticateWithBiometrics();
      if (!success) return;
    }
    await SecurityService.setBiometricEnabled(enable);
    _loadSecuritySettings();
  }

    // ===== CODE PIN =====
  void _showPinDialog(bool enable) {
    if (enable) {
      _showSetPinDialog();
    } else {
      _showRemovePinDialog();
    }
  }

  /// Définir / modifier le code PIN (6 chiffres)
  Future<void> _showSetPinDialog() async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Définir un code PIN'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choisissez un code à 6 chiffres pour protéger l\'application.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Nouveau PIN'),
                validator: (v) => (v == null || v.length != 6) ? '6 chiffres requis' : null,
                onChanged: (_) => formKey.currentState?.validate(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Confirmer le PIN'),
                validator: (v) => (v == pinCtrl.text) ? null : 'Les PIN ne correspondent pas',
                onChanged: (_) => formKey.currentState?.validate(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await SecurityService.setPin(pinCtrl.text.trim());
              await _setBiometricIfAvailable();
              Navigator.pop(dialogContext);
              _loadSecuritySettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Code PIN enregistré')),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    pinCtrl.dispose();
    confirmCtrl.dispose();
  }

  /// Supprimer le code PIN (en vérifiant le PIN actuel)
  Future<void> _showRemovePinDialog() async {
    final pinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final isValid = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer le code PIN'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: pinCtrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'PIN actuel'),
            validator: (v) => (v == null || v.length != 6) ? '6 chiffres requis' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final ok = await SecurityService.verifyPin(pinCtrl.text.trim());
              if (!ok) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('❌ PIN incorrect')),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Vérifier'),
          ),
        ],
      ),
    );

    pinCtrl.dispose();
    if (isValid == true) {
      await SecurityService.removePin();
      _loadSecuritySettings();
    }
  }

  // ===== 2FA =====
  void _showTwoFactorDialog(bool enable) {
    if (enable) {
      _showEnable2FADialog();
    } else {
      _showDisable2FADialog();
    }
  }

  /// Activer la 2FA via code TOTP (Google Authenticator / Authy / Compatible)
  Future<void> _showEnable2FADialog() async {
    final authProvider = context.read<AppAuthProvider>();
    final userId = authProvider.user?.id;
    final email = authProvider.user?.email ?? 'utilisateur';

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Aucun utilisateur connecté')),
      );
      return;
    }

    // Générer un secret et le provisionner
    final secret = TwoFactorService.generateSecret();
    final uri = TwoFactorService.getProvisioningUri(secret, email);
    final codeCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Activer la 2FA'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Scannez ce QR code avec Google Authenticator (ou une app compatible),',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ou saisissez la clé manuellement ci-dessous :',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                // Clé secrète affichée + bouton copier
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    secret,
                    key: ValueKey(secret),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copier la clé'),
                      onPressed: () => Clipboard.setData(ClipboardData(text: secret)),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.qr_code, size: 18),
                      label: const Text('Copier l\'URI'),
                      onPressed: () => Clipboard.setData(ClipboardData(text: uri)),
                    ),
                  ],
                ),
                const Divider(),
                const Text('2. Saisissez le code à 6 chiffres généré par l\'application :',
                  style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Code à 6 chiffres'),
                  validator: (v) => (v == null || v.length != 6) ? '6 chiffres requis' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final isValid = await TwoFactorService.verifyCode(secret, codeCtrl.text.trim());
              if (!isValid) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('❌ Code invalide, réessayez.')),
                );
                return;
              }
              // Valider → stocker le secret + activer la 2FA
              await TwoFactorService.storeSecret(userId, secret);
              await SecurityService.setTwoFactorEnabled(true);
              Navigator.pop(dialogContext);
              _loadSecuritySettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ 2FA activée')),
                );
              }
            },
            child: const Text('Activer'),
          ),
        ],
      ),
    );
    codeCtrl.dispose();
  }

  /// Désactiver la 2FA (en vérifiant un code TOTP valide)
  Future<void> _showDisable2FADialog() async {
    final authProvider = context.read<AppAuthProvider>();
    final userId = authProvider.user?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Aucun utilisateur connecté')),
      );
      return;
    }

    final codeCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Désactiver la 2FA'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Code à 6 chiffres'),
            validator: (v) => (v == null || v.length != 6) ? '6 chiffres requis' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final isValid = await TwoFactorService.verifyCode(userId, codeCtrl.text.trim());
              if (!isValid) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('❌ Code invalide')),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );

    codeCtrl.dispose();
    if (confirmed == true) {
      await TwoFactorService.deleteSecret(userId);
      await SecurityService.setTwoFactorEnabled(false);
      _loadSecuritySettings();
    }
  }

  /// Si la biométrie est disponible et que l'utilisateur a posé un PIN,
  /// on l'active au passage pour renforcer la sécurité (optionnel).
  Future<void> _setBiometricIfAvailable() async {}
}