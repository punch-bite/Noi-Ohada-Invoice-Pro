// lib/screens/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glass_widgets.dart';

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
        _errorMessage = auth.error ?? 'Impossible d\'envoyer l\'email de réinitialisation.';
      });
    }
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: _isSent
                    ? _buildSuccessView(primary, text, sub)
                    : _buildFormView(theme, primary, text, sub, isDark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Vue du Formulaire de demande
  Widget _buildFormView(ThemeProvider theme, Color primary, Color text, Color sub, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
                // Icône de clé/cadenas (dégradé + halo)
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primary.withValues(alpha: 0.9),
                theme.secondaryColor.withValues(alpha: 0.7),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.lock_reset_rounded,
              color: Colors.white, size: 30),
        ).animate().scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1, 1),
              curve: Curves.easeOutBack,
            ),
        const SizedBox(height: 14),
        Text(
          'Mot de passe oublié ?',
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
          style: TextStyle(fontSize: 13, color: sub, height: 1.35, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 28),

        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _resetPassword(),
                enabled: !_isLoading,
                style: TextStyle(color: text, fontSize: 14),
                decoration: _inputDecoration(
                  label: 'Adresse email',
                  hint: 'exemple@email.com',
                  icon: Icons.email_outlined,
                  isDark: isDark,
                  primary: primary,
                  sub: sub,
                ),
                validator: (v) {
                  if (v?.trim().isEmpty == true) return 'Veuillez saisir votre email';
                  if (!v!.contains('@') || !v.contains('.')) return 'Adresse email non valide';
                  return null;
                },
              ),
              
              // Affichage dynamique de l'erreur
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
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
              ],

              const SizedBox(height: 24),

                            // Bouton d'action (dégradé indigo → violet)
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

        const SizedBox(height: 20),

        // Retour en arrière
        TextButton(
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
      ],
    );
  }

  // Vue affichée en cas de succès de l'envoi
  Widget _buildSuccessView(Color primary, Color text, Color sub) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined, color: Colors.green, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          'Email envoyé !',
          style: TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.bold, 
            color: text,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Un lien de réinitialisation de mot de passe vient de vous être envoyé. Veuillez vérifier votre boîte de réception.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: sub, height: 1.45, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          '💡 Le lien expire après 24h. Si vous ne trouvez pas l\'e-mail, vérifiez vos spams ou renvoyez la demande.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: sub.withValues(alpha: 0.7),
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 28),

                GradientButton(
          label: 'Retour à la connexion',
          icon: Icons.login_rounded,
          height: 50,
          onPressed: () => context.go('/auth/login'),
        ),
      ],
    );
  }

  // Génération de la décoration des formulaires
  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color primary,
    required Color sub,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: sub, fontSize: 14),
      hintStyle: TextStyle(color: sub.withValues(alpha: 0.5), fontSize: 14),
      prefixIcon: Icon(icon, color: primary, size: 20),
      filled: true,
      fillColor: isDark ? Colors.black26 : Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}