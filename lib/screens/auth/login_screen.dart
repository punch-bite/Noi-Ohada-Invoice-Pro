// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/logo_image.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email');
    if (email != null && email.isNotEmpty && mounted) {
      setState(() {
        _emailController.text = email;
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveEmailPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe && _emailController.text.isNotEmpty) {
      await prefs.setString('saved_email', _emailController.text.trim());
    } else {
      await prefs.remove('saved_email');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AppAuthProvider>();
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      await _saveEmailPreference();

      if (authProvider.needsTwoFactor) {
        context.push('/auth/verify-2fa');
      } else {
        context.go('/dashboard');
      }
    } else {
      setState(() {
        _errorMessage = authProvider.error ?? 'Échec de connexion';
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AppAuthProvider>();
    final success = await authProvider.loginWithGoogle();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      if (authProvider.needsTwoFactor) {
        context.push('/auth/verify-2fa');
      } else {
        context.go('/dashboard');
      }
    } else {
      setState(() {
        _errorMessage = authProvider.error ?? 'Connexion Google échouée';
      });
    }
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
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo de la marque
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
                      'Noi Invoice Pro',
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
                      'Facturation conforme SYSCOHADA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sub,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Champ Email
                    _buildEmailField(primary, text, sub),
                    const SizedBox(height: 22),

                    // Champ Mot de passe
                    _buildPasswordField(primary, text, sub),
                    const SizedBox(height: 18),

                    // Mémorisation + mot de passe oublié
                    Row(
                      children: [
                        InkWell(
                          onTap: _isLoading
                              ? null
                              : () =>
                                  setState(() => _rememberMe = !_rememberMe),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: _isLoading
                                        ? null
                                        : (v) =>
                                            setState(() => _rememberMe = v!),
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
                                Text(
                                  'Se souvenir',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: sub,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => context.push('/auth/forgot-password'),
                          style: TextButton.styleFrom(
                            foregroundColor: primary,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Mot de passe oublié ?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Bannière d'erreur (épurée)
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 18),
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
                    ],

                    const SizedBox(height: 32),

                    // Bouton Se connecter
                    GradientButton(
                      label: 'Se connecter',
                      icon: Icons.lock_open_rounded,
                      height: 52,
                      loading: _isLoading,
                      onPressed: _login,
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                    const SizedBox(height: 24),

                    // Séparateur "ou"
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: sub.withValues(alpha: 0.2),
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'ou',
                            style: TextStyle(
                              color: sub.withValues(alpha: 0.7),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: sub.withValues(alpha: 0.2),
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Bouton Google (épuré)
                    _buildGoogleButton(text, sub),

                    const SizedBox(height: 26),

                    // Lien inscription
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Pas encore de compte ?',
                          style: TextStyle(color: sub, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => context.push('/auth/register'),
                          style: TextButton.styleFrom(
                            foregroundColor: primary,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'S\'inscrire',
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

  // ── Champ Email épuré (underline only) ──
  Widget _buildEmailField(Color primary, Color text, Color sub) {
    return TextFormField(
      controller: _emailController,
      focusNode: _emailFocus,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      enabled: !_isLoading,
      style: TextStyle(color: text, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: 'Adresse e-mail',
        hintText: 'exemple@email.com',
        labelStyle: TextStyle(
          color: sub,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: sub.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        prefixIcon: Icon(Icons.mail_outline, color: primary, size: 20),
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
      validator: (v) {
        if (v?.trim().isEmpty == true) {
          return 'Veuillez saisir votre email';
        }
        if (!v!.contains('@') || !v.contains('.')) {
          return 'Adresse email non valide';
        }
        return null;
      },
    );
  }

  // ── Champ Mot de passe épuré (underline only) ──
  Widget _buildPasswordField(Color primary, Color text, Color sub) {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _login(),
      obscureText: _obscurePassword,
      enabled: !_isLoading,
      style: TextStyle(color: text, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: 'Mot de passe',
        hintText: '••••••••',
        labelStyle: TextStyle(
          color: sub,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: sub.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: primary,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: sub.withValues(alpha: 0.7),
            size: 20,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
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
      validator: (v) {
        if (v?.isEmpty == true) {
          return 'Veuillez renseigner votre mot de passe';
        }
        if (v!.length < 6) {
          return 'Le mot de passe doit faire 6 caractères minimum';
        }
        return null;
      },
    );
  }

  // ── Bouton Google épuré (underline / ghost) ──
  Widget _buildGoogleButton(Color text, Color sub) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _loginWithGoogle,
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(
            color: sub.withValues(alpha: 0.25),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.grey,
                ),
              )
            : const Icon(
                Icons.g_mobiledata_rounded,
                size: 28,
                color: Color(0xFF4285F4),
              ),
        label: const Text(
          'Se connecter avec Google',
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}