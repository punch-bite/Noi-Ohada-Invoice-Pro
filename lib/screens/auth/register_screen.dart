// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

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

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acceptez les conditions'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final auth = context.read<AppAuthProvider>();
    final ok = await auth.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _nameController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (ok && mounted) context.go('/dashboard');
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
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person_add, color: primary, size: 28),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Créer un compte',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: text),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rejoignez OHADA Invoice Pro',
                        style: TextStyle(fontSize: 13, color: sub),
                      ),
                      const SizedBox(height: 24),

                      // Champs
                      _field(
                        _nameController,
                        'Nom complet',
                        Icons.person_outline,
                        isDark,
                        text,
                        sub,
                        primary,
                        validator: (v) => v?.trim().isEmpty == true ? 'Requis' : null,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        _emailController,
                        'Email',
                        Icons.email_outlined,
                        isDark,
                        text,
                        sub,
                        primary,
                        keyboard: TextInputType.emailAddress,
                        validator: (v) {
                          if (v?.trim().isEmpty == true) return 'Requis';
                          if (!v!.contains('@')) return 'Email invalide';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _password(
                        _passwordController,
                        'Mot de passe',
                        _obscurePassword,
                        () => setState(() => _obscurePassword = !_obscurePassword),
                        isDark,
                        text,
                        sub,
                        primary,
                        validator: (v) {
                          if (v?.isEmpty == true) return 'Requis';
                          if (v!.length < 6) return '6 caractères min.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _password(
                        _confirmController,
                        'Confirmation',
                        _obscureConfirm,
                        () => setState(() => _obscureConfirm = !_obscureConfirm),
                        isDark,
                        text,
                        sub,
                        primary,
                        validator: (v) {
                          if (v?.isEmpty == true) return 'Requis';
                          if (v != _passwordController.text) return 'Non identique';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Conditions
                      Row(
                        children: [
                          Checkbox(
                            value: _acceptTerms,
                            onChanged: (v) => setState(() => _acceptTerms = v!),
                            activeColor: primary,
                            visualDensity: VisualDensity.compact,
                          ),
                          Expanded(
                            child: Text(
                              'J\'accepte les conditions',
                              style: TextStyle(fontSize: 13, color: sub),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Bouton
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Créer mon compte', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Lien connexion
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Déjà un compte ?', style: TextStyle(color: sub, fontSize: 13)),
                          TextButton(
                            onPressed: () => context.go('/auth/login'),
                            style: TextButton.styleFrom(foregroundColor: primary),
                            child: const Text('Se connecter', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon,
    bool isDark,
    Color text,
    Color sub,
    Color primary, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      validator: validator,
      style: TextStyle(color: text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: sub),
        prefixIcon: Icon(icon, color: primary, size: 20),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _password(
    TextEditingController c,
    String label,
    bool obscure,
    VoidCallback toggle,
    bool isDark,
    Color text,
    Color sub,
    Color primary, {
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: c,
      obscureText: obscure,
      validator: validator,
      style: TextStyle(color: text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: sub),
        prefixIcon: Icon(Icons.lock_outline, color: primary, size: 20),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: sub, size: 20),
          onPressed: toggle,
        ),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}