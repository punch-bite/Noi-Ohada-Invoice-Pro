// lib/screens/auth/verify_2fa_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/logo_image.dart';

class VerifyTwoFactorScreen extends StatefulWidget {
  const VerifyTwoFactorScreen({super.key});

  @override
  State<VerifyTwoFactorScreen> createState() => _VerifyTwoFactorScreenState();
}

class _VerifyTwoFactorScreenState extends State<VerifyTwoFactorScreen> {
  final int _codeLength = 6;
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late List<FocusNode> _passiveFocusNodes; // ✅ FocusNodes passifs pour le backspace

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controllers =
        List.generate(_codeLength, (index) => TextEditingController());
    _focusNodes = List.generate(_codeLength, (index) => FocusNode());
    _passiveFocusNodes = List.generate(
      _codeLength,
      (index) => FocusNode(skipTraversal: true),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var node in _passiveFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // Reconstitue le code depuis les 6 champs
  String get _currentCode {
    return _controllers.map((controller) => controller.text).join();
  }

  // Gère la saisie, le passage au champ suivant/précédent et le copier-coller
  void _onCodeChanged(String value, int index) {
    // Copier-coller d'un code complet
    if (value.length > 1) {
      final cleanValue = value.replaceAll(RegExp(r'\D'), '');
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
        _verifyCode();
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _currentCode;
    if (code.length < _codeLength) {
      setState(() => _errorMessage = 'Veuillez saisir le code complet');
      return;
    }

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
      context.go('/dashboard');
    } else {
      setState(() {
        _errorMessage = authProvider.error ?? 'Code de sécurité invalide';
        _clearCode();
      });
    }
  }

  void _clearCode() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _onCancel() {
    if (_isLoading) return;
    context.read<AppAuthProvider>().cancelTwoFactorLogin();
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
          onPressed: _isLoading ? null : _onCancel,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  const Center(
                    child: LogoImage(
                      path: 'assets/images/splash_logo.png',
                      width: 70,
                      height: 70,
                    ),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.6, 0.6),
                        end: const Offset(1, 1),
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: 18),

                  Text(
                    'Double authentification',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    'Saisissez le code de sécurité à $_codeLength chiffres '
                    'généré par votre application d\'authentification (OTP).',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: sub,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Grille OTP (6 champs espacés uniformément)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      _codeLength,
                      (index) => SizedBox(
                        width: 46,
                        height: 56,
                        child: KeyboardListener(
                          focusNode: _passiveFocusNodes[index],
                          onKeyEvent: (event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey ==
                                    LogicalKeyboardKey.backspace &&
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
                            maxLength: index == 0 ? _codeLength : 1,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: text,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              // Soulignement uniquement (cohérent avec login/register)
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: sub.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: primary.withValues(alpha: 0.9),
                                  width: 1.8,
                                ),
                              ),
                              disabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: sub.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              errorBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.red.withValues(alpha: 0.7),
                                  width: 1.2,
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
                  const SizedBox(height: 24),

                  // Erreur (épurée, sans cadre)
                  if (_errorMessage != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red[700],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Bouton de validation
                  GradientButton(
                    label: 'Valider et se connecter',
                    icon: Icons.verified_user_rounded,
                    height: 50,
                    loading: _isLoading,
                    onPressed: _verifyCode,
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                  const SizedBox(height: 24),

                  // Annuler
                  Center(
                    child: TextButton(
                      onPressed: _isLoading ? null : _onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: primary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Retour à l\'écran de connexion',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}