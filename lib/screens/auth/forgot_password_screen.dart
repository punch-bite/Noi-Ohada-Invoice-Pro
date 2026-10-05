// lib/screens/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/logo_image.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    // Fermer proprement le clavier virtuel
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AppAuthProvider>();
    final ok = await auth.resetPassword(_emailController.text.trim());

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _isSent = ok;
    });

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email de réinitialisation envoyé avec succès'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      setState(() {
        _errorMessage =
            auth.error ?? 'Impossible d\'envoyer l\'email de réinitialisation.';
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _isSent
                  ? _buildSuccessView(primary, text, sub)
                  : _buildFormView(primary, text, sub),
            ),
          ),
        ),
      ),
    );
  }

  // ── Vue Formulaire de demande ──
  Widget _buildFormView(Color primary, Color text, Color sub) {
    return Column(
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
          'Mot de passe oublié ?',
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
          'Entrez votre adresse email pour recevoir un lien de réinitialisation',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: sub,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 40),

        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Champ email épuré
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _resetPassword(),
                enabled: !_isLoading,
                style: TextStyle(color: text, fontSize: 14.5),
                decoration: InputDecoration(
                  labelText: 'Adresse email',
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
                  prefixIcon:
                      Icon(Icons.email_outlined, color: primary, size: 20),
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
              ),

              // Erreur (épurée, sans cadre)
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

              // Bouton envoyer
              GradientButton(
                label: 'Envoyer le lien',
                icon: Icons.send_rounded,
                height: 50,
                loading: _isLoading,
                onPressed: _resetPassword,
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Retour
        Center(
          child: TextButton(
            onPressed: () => context.go('/auth/login'),
            style: TextButton.styleFrom(
              foregroundColor: primary,
              padding: EdgeInsets.zero,
              minimumSize: const Size(50, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Retour à la connexion',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ── Vue Succès ──
  Widget _buildSuccessView(Color primary, Color text, Color sub) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icône succès (sans cadre, cercle discret)
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: Colors.green,
              size: 34,
            ),
          ),
        ).animate().scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1, 1),
              curve: Curves.easeOutBack,
            ),
        const SizedBox(height: 20),
        Text(
          'Email envoyé !',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: text,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Un lien de réinitialisation de mot de passe vient de vous être envoyé. '
          'Veuillez vérifier votre boîte de réception.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: sub,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '💡 Le lien expire après 24h. Si vous ne trouvez pas l\'e-mail, '
          'vérifiez vos spams ou renvoyez la demande.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            color: sub.withValues(alpha: 0.7),
            fontStyle: FontStyle.italic,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 36),

        // Bouton retour
        GradientButton(
          label: 'Retour à la connexion',
          icon: Icons.login_rounded,
          height: 50,
          onPressed: () => context.go('/auth/login'),
        ),
      ],
    );
  }
}