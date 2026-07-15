// lib/screens/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = context.read<AppAuthProvider>();
    final ok = await auth.resetPassword(_emailController.text.trim());
    setState(() {
      _isLoading = false;
      _isSent = ok;
    });
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email de réinitialisation envoyé'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
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
            padding: const EdgeInsets.all(24),
            child: _isSent
                ? _successView(primary, text, sub)
                : _formView(primary, text, sub, isDark),
          ),
        ),
      ),
    );
  }

  Widget _formView(Color primary, Color text, Color sub, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icône
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.lock_outline, color: primary, size: 30),
        ),
        const SizedBox(height: 16),
        Text(
          'Mot de passe oublié ?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: text),
        ),
        const SizedBox(height: 6),
        Text(
          'Entrez votre email pour recevoir un lien',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: sub),
        ),
        const SizedBox(height: 28),

        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: text),
                decoration: _inputDecoration(
                  label: 'Adresse email',
                  hint: 'exemple@email.com',
                  icon: Icons.email_outlined,
                  isDark: isDark,
                  primary: primary,
                  sub: sub,
                ),
                validator: (v) {
                  if (v?.trim().isEmpty == true) return 'Email requis';
                  if (!v!.contains('@')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Envoyer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        TextButton(
          onPressed: () => context.go('/auth/login'),
          style: TextButton.styleFrom(foregroundColor: primary),
          child: const Text('Retour à la connexion', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _successView(Color primary, Color text, Color sub) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          'Email envoyé !',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: text),
        ),
        const SizedBox(height: 6),
        Text(
          'Vérifiez votre boîte pour réinitialiser',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: sub),
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => context.go('/auth/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retour à la connexion', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

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
      labelStyle: TextStyle(color: sub),
      hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
      prefixIcon: Icon(icon, color: primary, size: 20),
      filled: true,
      fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}