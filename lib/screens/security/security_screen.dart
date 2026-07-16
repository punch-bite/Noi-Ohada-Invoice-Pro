import 'package:flutter/material.dart';
import '../../services/security_service.dart';
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
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
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

  Widget _buildDivider() => Divider(height: 1, indent: 16, endIndent: 16, color: Theme.of(context).dividerColor.withOpacity(0.5));

  // --- Logiques ---
  
  Future<void> _handleBiometric(bool enable) async {
    if (enable) {
      final success = await SecurityService.authenticateWithBiometrics();
      if (!success) return;
    }
    await SecurityService.setBiometricEnabled(enable);
    _loadSecuritySettings();
  }

  void _showPinDialog(bool enable) { /* Logique identique à votre version précédente */ }
  void _showTwoFactorDialog(bool enable) { /* Logique identique à votre version précédente */ }
}