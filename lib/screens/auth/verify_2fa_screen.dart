// lib/screens/auth/verify_2fa_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class VerifyTwoFactorScreen extends StatefulWidget {
  const VerifyTwoFactorScreen({super.key});

  @override
  State<VerifyTwoFactorScreen> createState() => _VerifyTwoFactorScreenState();
}

class _VerifyTwoFactorScreenState extends State<VerifyTwoFactorScreen> {
  final int _codeLength = 6;
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_codeLength, (index) => TextEditingController());
    _focusNodes = List.generate(_codeLength, (index) => FocusNode());
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // Permet de reconstruire le code à partir des 6 champs individuels
  String get _currentCode {
    return _controllers.map((controller) => controller.text).join();
  }

  // Gère la saisie dans un champ OTP
  void _onCodeChanged(String value, int index) {
    if (value.length == 1) {
      if (index < _codeLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyCode(); // Soumission automatique dès que le 6ème chiffre est saisi
      }
    } else if (value.isEmpty) {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  // Action de vérification du code 2FA
  Future<void> _verifyCode() async {
    final code = _currentCode;
    if (code.length < _codeLength) {
      setState(() => _errorMessage = 'Veuillez saisir le code complet');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AppAuthProvider>();
    final success = await authProvider.verifyTwoFactorCode(code);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.go('/dashboard'); // Redirection finale en cas de succès !
      } else {
        setState(() {
          _errorMessage = authProvider.error ?? 'Code de sécurité invalide';
          _clearCode(); // Réinitialiser l'input pour une nouvelle tentative
        });
      }
    }
  }

  // Réinitialiser les champs en cas d'erreur
  void _clearCode() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  // Annuler la tentative et revenir au login
  void _onCancel() {
    context.read<AppAuthProvider>().cancelTwoFactorLogin();
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: text),
          onPressed: _onCancel,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icone de sécurité 2FA
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.security, color: primary, size: 36),
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Double authentification',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: text,
                  ),
                ),
                const SizedBox(height: 8),
                
                Text(
                  'Saisissez le code de sécurité à $_codeLength chiffres généré par votre application d\'authentification.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: sub, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 32),

                // Grille OTP (6 champs de texte alignés horizontalement)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    _codeLength,
                    (index) => SizedBox(
                      width: 45,
                      height: 55,
                      child: KeyboardListener(
                        focusNode: FocusNode(), // Détecte la touche retour arrière
                        onKeyEvent: (event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.backspace &&
                              _controllers[index].text.isEmpty &&
                              index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                        },
                        child: TextFormField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          enabled: !_isLoading,
                          autofocus: index == 0,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: text,
                          ),
                          decoration: InputDecoration(
                            counterText: '', // Masque le compteur par défaut
                            filled: true,
                            fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: primary, width: 2),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (v) => _onCodeChanged(v, index),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Gestion de l'erreur
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red[700], fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Bouton de validation
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Valider et se connecter',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Bouton Annuler
                TextButton(
                  onPressed: _isLoading ? null : _onCancel,
                  style: TextButton.styleFrom(foregroundColor: sub),
                  child: const Text('Retour à l\'écran de connexion', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}