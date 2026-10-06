// lib/screens/dashboard/profile_update_screen.dart
//
// 🎨 Refonte moderne et créative du profil utilisateur.
//
// ✨ Améliorations visuelles :
//   • Couverture gradient + avatar flottant qui chevauche
//   • Badge « Vérifié » + stats rapides (membre, complétion)
//   • Sections avec icônes colorées + sous-titres
//   • Champs premium avec indicateur de complétion
//   • Barre de progression du profil dynamique
//   • Micro-interactions (press, focus glow)
//
// ✅ Logique inchangée : mêmes controllers, mêmes validations,
//    même _saveProfile, mêmes services.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/glass_widgets.dart';

class ProfileUpdateScreen extends StatefulWidget {
  const ProfileUpdateScreen({super.key});

  @override
  State<ProfileUpdateScreen> createState() => _ProfileUpdateScreenState();
}

class _ProfileUpdateScreenState extends State<ProfileUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _companyController;
  late final TextEditingController _addressController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppAuthProvider>().user;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _companyController = TextEditingController(text: user?.companyName ?? '');
    _addressController =
        TextEditingController(text: user?.companyAddress ?? '');

    // Écoute les changements pour mettre à jour le compteur de complétion
    for (final c in [
      _nameController,
      _phoneController,
      _companyController,
      _addressController,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  /// Calcule le % de complétion du profil (basé sur 4 champs).
  double get _completionRate {
    final fields = [
      _nameController.text.trim(),
      _phoneController.text.trim(),
      _companyController.text.trim(),
      _addressController.text.trim(),
    ];
    final filled = fields.where((f) => f.isNotEmpty).length;
    return filled / fields.length;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final authProvider = context.read<AppAuthProvider>();
      final user = authProvider.user;

      if (user == null) throw Exception('Utilisateur non connecté');

      final updatedUser = user.copyWith(
        displayName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        companyName: _companyController.text.trim(),
        companyAddress: _addressController.text.trim(),
      );

      await _db.updateUser(updatedUser);
      await authProvider.refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('Profil mis à jour avec succès')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final user = context.select((AppAuthProvider p) => p.user);
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;

    return GlassScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.textColor,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Mon profil',
          style: TextStyle(
            color: theme.textColor,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isSaving
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(primary),
                        ),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _saveProfile,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      'Enregistrer',
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // ── COUVERTURE + AVATAR ──
            _buildCoverSection(theme, user, isDark, primary),

            // ── STATS RAPIDES ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _buildQuickStats(theme, isDark, primary),
            ),

            // ── PROGRESSION ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _buildCompletionBar(theme, isDark, primary),
            ),

            // ── SECTION : Informations personnelles ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: _buildSectionHeader(
                icon: Icons.person_rounded,
                title: 'Informations personnelles',
                subtitle: 'Vos coordonnées principales',
                color: primary,
                theme: theme,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Nom complet',
                    hint: 'Ex. Jean Dupont',
                    icon: Icons.person_outline_rounded,
                    theme: theme,
                    isRequired: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Veuillez entrer votre nom';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Téléphone',
                    hint: 'Ex. +237 6 90 00 00 00',
                    icon: Icons.phone_outlined,
                    theme: theme,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),

            // ── SECTION : Entreprise ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: _buildSectionHeader(
                icon: Icons.business_rounded,
                title: 'Entreprise',
                subtitle: 'Informations professionnelles',
                color: const Color(0xFFF59E0B),
                theme: theme,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _companyController,
                    label: 'Nom de l\'entreprise',
                    hint: 'Ex. NOI Concept Digital',
                    icon: Icons.apartment_rounded,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _addressController,
                    label: 'Adresse',
                    hint: 'Ex. Douala, Cameroun',
                    icon: Icons.location_on_outlined,
                    theme: theme,
                    maxLines: 3,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── BOUTON ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GradientButton(
                label: 'Enregistrer les modifications',
                icon: Icons.check_circle_outline_rounded,
                height: 54,
                loading: _isSaving,
                onPressed: _saveProfile,
              ),
            ),

            const SizedBox(height: 20),

            // ── INFO : sécurité ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSecurityNote(theme, isDark),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //  COUVERTURE + AVATAR FLOTTANT
  // ============================================================
  Widget _buildCoverSection(
    ThemeProvider theme,
    dynamic user,
    bool isDark,
    Color primary,
  ) {
    final name = user?.displayName ?? '';
    final email = user?.email ?? '';

    return SizedBox(
      height: 240,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Couverture gradient
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primary,
                  primary.withValues(alpha: 0.7),
                  const Color(0xFF7C3AED).withValues(alpha: 0.6),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Motif décoratif : cercles translucides
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  left: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shield_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Compte sécurisé',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Carte infos flottante
          Positioned(
            top: 130,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16161D) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar superposé
                  _ProfileAvatar(name: name, primary: primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name.trim().isEmpty
                                    ? 'Mon compte'
                                    : name.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: theme.textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Badge vérifié
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: primary,
                              ),
                            ),
                          ],
                        ),
                        if (email.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.alternate_email_rounded,
                                size: 12,
                                color: theme.subTextColor,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.subTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  STATS RAPIDES
  // ============================================================
  Widget _buildQuickStats(
    ThemeProvider theme,
    bool isDark,
    Color primary,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.verified_user_rounded,
            label: 'Statut',
            value: 'Actif',
            color: const Color(0xFF10B981),
            isDark: isDark,
            theme: theme,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.workspace_premium_rounded,
            label: 'Compte',
            value: 'Membre',
            color: primary,
            isDark: isDark,
            theme: theme,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    required ThemeProvider theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.22 : 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: theme.subTextColor,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : theme.textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  COMPLETION BAR
  // ============================================================
  Widget _buildCompletionBar(
    ThemeProvider theme,
    bool isDark,
    Color primary,
  ) {
    final rate = _completionRate;
    final percent = (rate * 100).round();
    final isComplete = rate >= 1.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (isComplete ? const Color(0xFF10B981) : primary)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isComplete
                      ? Icons.check_circle_rounded
                      : Icons.trending_up_rounded,
                  size: 16,
                  color: isComplete ? const Color(0xFF10B981) : primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complétion du profil',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isComplete
                          ? 'Votre profil est complet ✓'
                          : '$percent% — Complétez vos informations',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isComplete
                            ? const Color(0xFF10B981)
                            : theme.subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isComplete ? const Color(0xFF10B981) : primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: rate),
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation(
                    isComplete ? const Color(0xFF10B981) : primary,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  SECTION HEADER
  // ============================================================
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required ThemeProvider theme,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: theme.subTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  //  NOTE DE SÉCURITÉ
  // ============================================================
  Widget _buildSecurityNote(ThemeProvider theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Vos informations sont chiffrées et synchronisées en toute sécurité.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: theme.subTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  CHAMP TEXTE PREMIUM
  // ============================================================
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeProvider theme,
    String? hint,
    bool isRequired = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isDark = theme.isDarkMode;
    final hasValue = controller.text.trim().isNotEmpty;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(
        color: theme.textColor,
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      cursorColor: theme.primaryColor,
      cursorRadius: const Radius.circular(2),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: theme.subTextColor.withValues(alpha: 0.5),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(
          color: theme.subTextColor.withValues(alpha: 0.9),
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4, right: 2),
          child: Icon(
            icon,
            color: hasValue
                ? theme.primaryColor
                : theme.primaryColor.withValues(alpha: 0.55),
            size: 20,
          ),
        ),
        suffixIcon: isRequired && hasValue
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: const Color(0xFF10B981),
                  size: 18,
                ),
              )
            : null,
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white,
        alignLabelWithHint: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 16 : 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}

// ============================================================
//  AVATAR PREMIUM (compact pour intégration flottante)
// ============================================================
class _ProfileAvatar extends StatelessWidget {
  final String name;
  final Color primary;
  const _ProfileAvatar({
    required this.name,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final String initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';

    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary,
            primary.withValues(alpha: 0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: CircleAvatar(
          backgroundColor: primary,
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
        ),
      ),
    );
  }
}