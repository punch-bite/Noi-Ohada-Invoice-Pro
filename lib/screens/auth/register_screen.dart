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

  // Gestion des focus du formulaire
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
        _errorMessage = auth.error ?? 'Une erreur est survenue lors de l\'inscription.';
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge Icône d'inscription
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person_add_alt_1_rounded, color: primary, size: 28),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Créer un compte',
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold, 
                          color: text,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rejoignez OHADA Invoice Pro',
                        style: TextStyle(fontSize: 13, color: sub, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 28),

                      // Champ : Nom complet
                      _buildField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        nextFocusNode: _emailFocus,
                        label: 'Nom complet',
                        icon: Icons.person_outline_rounded,
                        theme: theme,
                        validator: (v) => v?.trim().isEmpty == true ? 'Veuillez saisir votre nom' : null,
                      ),
                      const SizedBox(height: 14),

                      // Champ : Email
                      _buildField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        nextFocusNode: _passwordFocus,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        theme: theme,
                        keyboard: TextInputType.emailAddress,
                        validator: (v) {
                          if (v?.trim().isEmpty == true) return 'Veuillez saisir votre email';
                          if (!v!.contains('@') || !v.contains('.')) return 'Adresse email non valide';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Champ : Mot de passe
                      _buildPasswordField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        nextFocusNode: _confirmFocus,
                        label: 'Mot de passe',
                        obscure: _obscurePassword,
                        toggle: () => setState(() => _obscurePassword = !_obscurePassword),
                        theme: theme,
                        validator: (v) {
                          if (v?.isEmpty == true) return 'Mot de passe requis';
                          if (v!.length < 6) return 'Le mot de passe doit faire 6 caractères min.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Champ : Confirmation mot de passe
                      _buildPasswordField(
                        controller: _confirmController,
                        focusNode: _confirmFocus,
                        label: 'Confirmer le mot de passe',
                        obscure: _obscureConfirm,
                        toggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        theme: theme,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _register(),
                        validator: (v) {
                          if (v?.isEmpty == true) return 'Veuillez confirmer votre mot de passe';
                          if (v != _passwordController.text) return 'Les mots de passe ne correspondent pas';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // Case à cocher : CGU
                      InkWell(
                        onTap: _isLoading ? null : () => setState(() => _acceptTerms = !_acceptTerms),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _acceptTerms,
                                  onChanged: _isLoading ? null : (v) => setState(() => _acceptTerms = v!),
                                  activeColor: primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'J\'accepte les conditions d\'utilisation',
                                  style: TextStyle(fontSize: 13, color: sub, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Message d'erreur stylisé
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
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
                      ],

                      const SizedBox(height: 24),

                      // Bouton d'inscription
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5, 
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Créer mon compte', 
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Redirection vers Connexion
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Déjà un compte ?', style: TextStyle(color: sub, fontSize: 13)),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () => context.go('/auth/login'),
                            style: TextButton.styleFrom(
                              foregroundColor: primary,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Se connecter', 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
      ),
    );
  }

  // Widget utilitaire pour les champs standards
  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
    required String label,
    required IconData icon,
    required ThemeProvider theme,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    final isDark = theme.isDarkMode;
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: (_) => nextFocusNode?.requestFocus(),
      keyboardType: keyboard,
      enabled: !_isLoading,
      validator: validator,
      style: TextStyle(color: theme.textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.subTextColor, fontSize: 14),
        prefixIcon: Icon(icon, color: theme.primaryColor, size: 20),
        filled: true,
        fillColor: bgFillColor(theme),
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
          borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      ),
    );
  }

  // Widget utilitaire pour les champs de mots de passe
  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
    required ThemeProvider theme,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) {
    final isDark = theme.isDarkMode;
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted ?? (_) => nextFocusNode?.requestFocus(),
      enabled: !_isLoading,
      validator: validator,
      style: TextStyle(color: theme.textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.subTextColor, fontSize: 14),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: theme.primaryColor, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, 
            color: theme.subTextColor.withOpacity(0.7), 
            size: 20,
          ),
          onPressed: toggle,
        ),
        filled: true,
        fillColor: bgFillColor(theme),
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
          borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      ),
    );
  }

  // Détermine la couleur d'arrière-plan des champs de saisie selon le thème actif
  Color bgFillColor(ThemeProvider theme) {
    return theme.isDarkMode ? Colors.black26 : Colors.grey[50]!;
  }
}