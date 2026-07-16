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

  // Gère la saisie, le passage au champ suivant/précédent et le support du copier-coller
  void _onCodeChanged(String value, int index) {
    // Gestion du copier-coller (si l'utilisateur colle un code de 6 chiffres d'un coup)
    if (value.length > 1) {
      final cleanValue = value.replaceAll(RegExp(r'\D'), ''); // Garde uniquement les chiffres
      if (cleanValue.length >= _codeLength) {
        for (int i = 0; i < _codeLength; i++) {
          _controllers[i].text = cleanValue[i];
        }
        _focusNodes[_codeLength - 1].unfocus();
        _verifyCode();
      }
      return;
    }

    if (value.length == 1) {
      if (index < _codeLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyCode(); // Soumission automatique dès que le dernier chiffre est saisi
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

    // Fermer le clavier virtuel
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AppAuthProvider>();
    final success = await authProvider.verifyTwoFactorCode(code);

    if (!mounted) return;
    
    setState(() => _isLoading = false);
    
    if (success) {
      context.go('/dashboard'); // Redirection finale !
    } else {
      setState(() {
        _errorMessage = authProvider.error ?? 'Code de sécurité invalide';
        _clearCode(); // Réinitialiser l'input pour une nouvelle tentative
      });
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
    if (_isLoading) return;
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
          icon: Icon(Icons.arrow_back_rounded, color: text),
          onPressed: _isLoading ? null : _onCancel,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icône de sécurité 2FA
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.security_rounded, color: primary, size: 28),
                    ),
                    const SizedBox(height: 14),
                    
                    Text(
                      'Double authentification',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: text,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    Text(
                      'Saisissez le code de sécurité à $_codeLength chiffres généré par votre application d\'authentification (OTP).',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sub, 
                        fontSize: 13, 
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Grille OTP (6 champs de texte alignés horizontalement)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        _codeLength,
                        (index) => SizedBox(
                          width: 42,
                          height: 52,
                          child: KeyboardListener(
                            focusNode: FocusNode(skipTraversal: true), // Focus Node passif
                            onKeyEvent: (event) {
                              // Gestion propre du retour arrière si la case est vide
                              if (event is KeyDownEvent &&
                                  event.logicalKey == LogicalKeyboardKey.backspace &&
                                  _controllers[index].text.isEmpty &&
                                  index > 0) {
                                _focusNodes[index - 1].requestFocus();
                                _controllers[index - 1].clear();
                              }
                            },
                            child: TextFormField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              enabled: !_isLoading,
                              autofocus: index == 0,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              // Permet de coller une chaîne complète dans le premier champ
                              maxLength: index == 0 ? _codeLength : 1,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: text,
                              ),
                              decoration: InputDecoration(
                                counterText: '', // Masque le compteur par défaut de longueur
                                filled: true,
                                fillColor: isDark ? Colors.black26 : Colors.grey[50],
                                contentPadding: EdgeInsets.zero,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: primary, width: 2),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: isDark ? Colors.transparent : Colors.grey[100]!,
                                  ),
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
                    const SizedBox(height: 20),

                    // Gestion et affichage stylisé de l'erreur
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: Colors.red[700], size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red[850], 
                                  fontSize: 12.5, 
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Bouton de validation manuelle
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text(
                                'Valider et se connecter',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Bouton Annuler
                    TextButton(
                      onPressed: _isLoading ? null : _onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: primary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Retour à l\'écran de connexion', 
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}