// ============================================================
//  AppLockScreen — Ecran de verrouillage de l'application.
//  Demande la biométrie (si activée) ou le code PIN (si défini)
//  avant de laisser l'utilisateur accéder au tableau de bord.
//  Style "glassmorphisme" cohérent avec le design system.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/security_service.dart';
import '../../widgets/glass_widgets.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback? onUnlocked;
  const AppLockScreen({super.key, this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _pinController = TextEditingController();
  String? _error;
  bool _biometricAvailable = false;
  bool _hasPin = false;
  bool _hasBiometric = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    _hasPin = await SecurityService.isPinSet();
    _hasBiometric = await SecurityService.isBiometricEnabled();
    _biometricAvailable = await SecurityService.isBiometricAvailable();
    if (mounted) setState(() => _checking = false);
    // Proposer la biométrie automatiquement si elle est disponible et activée.
    if (!_checking && _hasBiometric && _biometricAvailable) {
      _tryBiometric();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _finishUnlock() {
    SecurityService.markSessionUnlocked();
    widget.onUnlocked?.call();
  }

  Future<void> _tryBiometric() async {
    final ok = await SecurityService.authenticateWithBiometrics();
    if (!mounted) return;
    if (ok) {
      _finishUnlock();
    } else {
      setState(() => _error = 'Biométrie non reconnue. Utilisez votre code PIN.');
    }
  }

  Future<void> _unlockWithPin() async {
    if (_pinController.text.length != 6) {
      setState(() => _error = 'Saisissez votre code PIN à 6 chiffres.');
      return;
    }
    final valid = await SecurityService.verifyPin(_pinController.text.trim());
    if (!mounted) return;
    if (valid) {
      _finishUnlock();
    } else {
      setState(() {
        _error = 'Code PIN incorrect.';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E1117) : const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo / cadenas
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4338CA).withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock_rounded, color: Colors.white, size: 40),
                ).animate().scale(
                    begin: const Offset(0.6, 0.6),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutBack),
                const SizedBox(height: 24),
                Text(
                  'Application verrouillée',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF14161C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Déverrouillez pour accéder à vos données de facturation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),

                // Saisie PIN
                if (_checking)
                  const CircularProgressIndicator()
                else ...[
                  if (_hasPin) ...[
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        fontSize: 26,
                        letterSpacing: 12,
                        color: isDark ? Colors.white : const Color(0xFF14161C),
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••••',
                        hintStyle: TextStyle(
                          letterSpacing: 12,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFF4338CA), width: 2),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E2433) : Colors.white,
                      ),
                      onSubmitted: (_) => _unlockWithPin(),
                    ),
                    const SizedBox(height: 20),
                    GradientButton(
                      label: 'Déverrouiller',
                      icon: Icons.lock_open_rounded,
                      height: 50,
                      onPressed: _unlockWithPin,
                    ).animate().fadeIn(delay: 150.ms),
                    const SizedBox(height: 14),
                    if (_hasBiometric && _biometricAvailable)
                      OutlinedButton.icon(
                        onPressed: _tryBiometric,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Utiliser la biométrie'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4338CA),
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: Color(0xFF4338CA)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                  ] else if (_hasBiometric && _biometricAvailable) ...[
                    GradientButton(
                      label: 'Déverrouiller avec la biométrie',
                      icon: Icons.fingerprint,
                      height: 50,
                      onPressed: _tryBiometric,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: Colors.red[700], size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Colors.red[850],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
