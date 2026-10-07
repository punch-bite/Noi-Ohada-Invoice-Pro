// lib/screens/auth/register_screen.dart
//
// CHANGELOG v3 « Login Style » :
//   • 🎨 REFONTE : alignement strict sur le design du LoginScreen.
//   • Champs en `UnderlineInputBorder` (comme le login) au lieu des filled.
//   • Suppression des halos → fond épuré homogène avec le login.
//   • Erreur en simple Row (icône + texte) au lieu du conteneur coloré.
//   • Utilisation du `GradientButton` partagé (glass_widgets) comme le login.
//   • Checkbox Material standard pour les CGU (comme "Se souvenir" du login).
//   • Barre de force du mot de passe conservée, rendu discret (thin).
//   • Spacing, tailles, typographies strictement identiques au login.
//   • Animations allégées : logo scale + fadeIn du bouton (comme le login).
//
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/logo_image.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Rebuild pour la barre de force du mot de passe.
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      setState(() {
        _errorMessage = 'Vous devez accepter les conditions d\'utilisation.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AppAuthProvider>();
    final ok = await auth.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _nameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      context.go('/dashboard');
    } else {
      setState(() {
        _errorMessage =
            auth.error ?? 'Une erreur est survenue lors de l\'inscription.';
      });
    }
  }

  // ─── Force du mot de passe (0..1) ───
  double _passwordStrength() {
    final p = _passwordController.text;
    if (p.isEmpty) return 0;
    double s = 0;
    if (p.length >= 6) s += 0.35;
    if (p.length >= 10) s += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(p)) s += 0.15;
    if (RegExp(r'[0-9]').hasMatch(p)) s += 0.15;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s += 0.20;
    return s.clamp(0.0, 1.0);
  }

  Color _strengthColor(double v) {
    if (v < 0.35) return const Color(0xFFEF4444);
    if (v < 0.65) return const Color(0xFFF59E0B);
    if (v < 0.9) return const Color(0xFF3B82F6);
    return const Color(0xFF10B981);
  }

  String _strengthLabel(double v) {
    if (v < 0.35) return 'Faible';
    if (v < 0.65) return 'Moyen';
    if (v < 0.9) return 'Bon';
    return 'Excellent';
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logo ──
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

                    // ── Titre ──
                    Text(
                      'Créer un compte',
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
                      'Rejoignez NOI Invoice Pro',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sub,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Nom ──
                    _field(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      nextFocusNode: _emailFocus,
                      label: 'Nom complet',
                      hint: 'Jean Dupont',
                      icon: Icons.person_outline_rounded,
                      primary: primary,
                      text: text,
                      sub: sub,
                      validator: (v) => v?.trim().isEmpty == true
                          ? 'Veuillez saisir votre nom'
                          : null,
                    ),
                    const SizedBox(height: 22),

                    // ── Email ──
                    _field(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      nextFocusNode: _passwordFocus,
                      label: 'Adresse e-mail',
                      hint: 'exemple@email.com',
                      icon: Icons.mail_outline,
                      primary: primary,
                      text: text,
                      sub: sub,
                      keyboard: TextInputType.emailAddress,
                      validator: (v) {
                        if (v?.trim().isEmpty == true) {
                          return 'Veuillez saisir votre email';
                        }
                        if (!v!.contains('@') || !v.contains('.')) {
                          return 'Adresse email non valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),

                    // ── Mot de passe ──
                    _passwordField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      nextFocusNode: _confirmFocus,
                      label: 'Mot de passe',
                      hint: '••••••••',
                      obscure: _obscurePassword,
                      toggle: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                      primary: primary,
                      text: text,
                      sub: sub,
                      validator: (v) {
                        if (v?.isEmpty == true) {
                          return 'Mot de passe requis';
                        }
                        if (v!.length < 6) {
                          return 'Minimum 6 caractères';
                        }
                        return null;
                      },
                    ),

                    // ── Barre de force ──
                    _passwordStrengthBar(theme),

                    const SizedBox(height: 22),

                    // ── Confirmation ──
                    _passwordField(
                      controller: _confirmController,
                      focusNode: _confirmFocus,
                      label: 'Confirmer le mot de passe',
                      hint: '••••••••',
                      obscure: _obscureConfirm,
                      toggle: () => setState(
                          () => _obscureConfirm = !_obscureConfirm),
                      primary: primary,
                      text: text,
                      sub: sub,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _register(),
                      validator: (v) {
                        if (v?.isEmpty == true) {
                          return 'Veuillez confirmer';
                        }
                        if (v != _passwordController.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // ── CGU ──
                    _buildTermsRow(primary, sub),

                    // ── Erreur ──
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 18),
                      _buildError(),
                    ],

                    const SizedBox(height: 32),

                    // ── Bouton ──
                    GradientButton(
                      label: 'Créer mon compte',
                      icon: Icons.person_add_alt_1_rounded,
                      height: 52,
                      loading: _isLoading,
                      onPressed: _register,
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                    const SizedBox(height: 26),

                    // ── Lien vers login ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Déjà un compte ?',
                          style: TextStyle(color: sub, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => context.go('/auth/login'),
                          style: TextButton.styleFrom(
                            foregroundColor: primary,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Se connecter',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

  // ═══════════════════════════════════════════════════════════════
  //  CHAMP STANDARD — style underline (identique au login)
  // ═══════════════════════════════════════════════════════════════
  Widget _field({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
    required String label,
    required String hint,
    required IconData icon,
    required Color primary,
    required Color text,
    required Color sub,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      textInputAction:
          nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: (_) => nextFocusNode?.requestFocus(),
      keyboardType: keyboard,
      enabled: !_isLoading,
      validator: validator,
      style: TextStyle(color: text, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: sub,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: sub.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: primary, size: 20),
        filled: false,
        border: UnderlineInputBorder(
          borderSide: BorderSide(
            color: sub.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: sub.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: primary.withValues(alpha: 0.9),
            width: 1.6,
          ),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red.withValues(alpha: 0.7),
            width: 1.2,
          ),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red.withValues(alpha: 0.9),
            width: 1.6,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CHAMP MOT DE PASSE — style underline
  // ═══════════════════════════════════════════════════════════════
  Widget _passwordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback toggle,
    required Color primary,
    required Color text,
    required Color sub,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted ?? (_) => nextFocusNode?.requestFocus(),
      enabled: !_isLoading,
      validator: validator,
      style: TextStyle(color: text, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: sub,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: sub.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: primary, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: sub.withValues(alpha: 0.7),
            size: 20,
          ),
          onPressed: toggle,
        ),
        filled: false,
        border: UnderlineInputBorder(
          borderSide: BorderSide(
            color: sub.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: sub.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: primary.withValues(alpha: 0.9),
            width: 1.6,
          ),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red.withValues(alpha: 0.7),
            width: 1.2,
          ),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red.withValues(alpha: 0.9),
            width: 1.6,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BARRE DE FORCE DU MOT DE PASSE (discrète, sous le champ)
  // ═══════════════════════════════════════════════════════════════
  Widget _passwordStrengthBar(ThemeProvider theme) {
    final strength = _passwordStrength();
    if (_passwordController.text.isEmpty) return const SizedBox.shrink();

    final color = _strengthColor(strength);
    final label = _strengthLabel(strength);

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                tween: Tween(begin: 0, end: strength),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 2.5,
                  backgroundColor:
                      theme.subTextColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  LIGNE CGU — Checkbox Material (comme "Se souvenir" du login)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTermsRow(Color primary, Color sub) {
    return InkWell(
      onTap: _isLoading
          ? null
          : () => setState(() => _acceptTerms = !_acceptTerms),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _acceptTerms,
                onChanged: _isLoading
                    ? null
                    : (v) => setState(() => _acceptTerms = v!),
                activeColor: primary,
                side: BorderSide(
                  color: sub.withValues(alpha: 0.4),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: sub,
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      const TextSpan(text: 'J\'accepte les '),
                      TextSpan(
                        text: 'conditions d\'utilisation',
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () =>
                              context.go('/support/legal/mentions'),
                      ),
                      const TextSpan(text: ' et la '),
                      TextSpan(
                        text: 'politique de confidentialité',
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () =>
                              context.go('/support/legal/privacy'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  MESSAGE D'ERREUR — Row simple (comme le login)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildError() {
    return Row(
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
    );
  }
}