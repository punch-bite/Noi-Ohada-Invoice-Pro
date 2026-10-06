// lib/screens/dashboard/suppliers/create_supplier_screen.dart
//
// 🎨 Création / édition fournisseur — refonte moderne.
// Logique inchangée (quota, validation, création/modification).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/subscription_provider.dart';
import '../../../services/supplier_service.dart';
import '../../../services/quota_enforcement_service.dart';
import '../../../models/supplier.dart';
import '../../../models/plan.dart';
import '../../../widgets/glass_widgets.dart';

class CreateSupplierScreen extends StatefulWidget {
  final Supplier? supplier;
  const CreateSupplierScreen({super.key, this.supplier});

  @override
  State<CreateSupplierScreen> createState() => _CreateSupplierScreenState();
}

class _CreateSupplierScreenState extends State<CreateSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupplierService _supplierService = SupplierService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _taxIdController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initServiceAndData();
  }

  Future<void> _initServiceAndData() async {
    await _supplierService.init();
    if (widget.supplier != null) {
      if (!mounted) return;
      setState(() {
        _nameController.text = widget.supplier!.name;
        _emailController.text = widget.supplier!.email;
        _phoneController.text = widget.supplier!.phone;
        _addressController.text = widget.supplier!.address;
        _taxIdController.text = widget.supplier!.taxId;
        _contactPersonController.text = widget.supplier!.contactPerson;
        _notesController.text = widget.supplier!.notes;
        _isActive = widget.supplier!.isActive;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    _contactPersonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.supplier == null) {
        // Blocage quota : uniquement pour un NOUVEAU fournisseur.
        final sub = context.read<SubscriptionProvider>();
        final plan = sub.currentPlan ?? Plan.getFreePlan();
        final result = await QuotaEnforcementService().canAddSupplier(plan);
        if (!result.isAllowed) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  result.message ?? 'Limite de fournisseurs atteinte. Passez au plan supérieur.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
          return;
        }
        final supplier = Supplier(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          taxId: _taxIdController.text.trim(),
          contactPerson: _contactPersonController.text.trim(),
          notes: _notesController.text.trim(),
          isActive: _isActive,
          userId: '',
        );
        await _supplierService.addSupplier(supplier);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('Fournisseur ajouté avec succès'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        final updated = widget.supplier!.copyWith(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          taxId: _taxIdController.text.trim(),
          contactPerson: _contactPersonController.text.trim(),
          notes: _notesController.text.trim(),
          isActive: _isActive,
          updatedAt: DateTime.now(),
        );
        await _supplierService.updateSupplier(updated);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('Fournisseur modifié avec succès'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final primary = theme.primaryColor;
    final isEditing = widget.supplier != null;

    return GlassScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: text, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Modifier fournisseur' : 'Nouveau fournisseur',
          style: TextStyle(
            color: text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isLoading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primary),
                        ),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _saveSupplier,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      isEditing ? 'Enregistrer' : 'Ajouter',
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero avatar ──
                    _buildHeroAvatar(isDark, primary, text, sub, isEditing),

                    const SizedBox(height: 28),

                    // ── Section : Identité ──
                    _sectionLabel(
                      isEditing
                          ? 'Modifier les informations'
                          : 'Informations de base',
                      sub,
                    ),
                    const SizedBox(height: 12),

                    _buildField(
                      controller: _nameController,
                      label: 'Nom du fournisseur',
                      icon: Icons.business_rounded,
                      theme: theme,
                      isDark: isDark,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          v?.trim().isEmpty ?? true ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _contactPersonController,
                      label: 'Personne de contact',
                      icon: Icons.person_rounded,
                      theme: theme,
                      isDark: isDark,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _taxIdController,
                      label: 'NUI / RCCM',
                      icon: Icons.badge_rounded,
                      theme: theme,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 24),

                    // ── Section : Contact ──
                    _sectionLabel('Coordonnées', sub),
                    const SizedBox(height: 12),

                    _buildField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.mail_rounded,
                      theme: theme,
                      isDark: isDark,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v?.isNotEmpty == true && !v!.contains('@')) {
                          return 'Email invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _phoneController,
                      label: 'Téléphone',
                      icon: Icons.phone_rounded,
                      theme: theme,
                      isDark: isDark,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _addressController,
                      label: 'Adresse',
                      icon: Icons.location_on_rounded,
                      theme: theme,
                      isDark: isDark,
                      textCapitalization: TextCapitalization.words,
                    ),

                    const SizedBox(height: 24),

                    // ── Section : Notes ──
                    _sectionLabel('Notes complémentaires', sub),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _notesController,
                      label: 'Notes',
                      icon: Icons.sticky_note_2_rounded,
                      theme: theme,
                      isDark: isDark,
                      maxLines: 3,
                      alignLabelTop: true,
                    ),

                    const SizedBox(height: 24),

                    // ── Statut ──
                    _buildStatusCard(
                      isDark: isDark,
                      primary: primary,
                      text: text,
                      sub: sub,
                    ),

                    const SizedBox(height: 28),

                    // ── CTA ──
                    GradientButton(
                      label: isEditing
                          ? 'Sauvegarder le fournisseur'
                          : 'Ajouter le fournisseur',
                      icon: Icons.check_circle_outline_rounded,
                      height: 54,
                      onPressed: _saveSupplier,
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  // ======================================================================
  //  HERO AVATAR (icône + phrase contextuelle)
  // ======================================================================
  Widget _buildHeroAvatar(
    bool isDark,
    Color primary,
    Color text,
    Color sub,
    bool isEditing,
  ) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primary,
                  primary.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.32),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              isEditing
                  ? Icons.edit_rounded
                  : Icons.add_business_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isEditing
                ? 'Mettez à jour ce fournisseur'
                : 'Ajoutez un nouveau partenaire',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: sub,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  //  SECTION LABEL
  // ======================================================================
  Widget _sectionLabel(String label, Color sub) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          color: sub,
        ),
      ),
    );
  }

  // ======================================================================
  //  FIELD (input premium)
  // ======================================================================
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeProvider theme,
    required bool isDark,
    TextInputType? keyboardType,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    bool alignLabelTop = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      validator: validator,
      style: TextStyle(
        color: theme.textColor,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: theme.primaryColor,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: theme.subTextColor.withValues(alpha: 0.85),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4, right: 2),
          child: Icon(
            icon,
            size: 19,
            color: theme.primaryColor.withValues(alpha: 0.7),
          ),
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.9),
        alignLabelWithHint: alignLabelTop,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: maxLines > 1 ? 14 : 16,
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

  // ======================================================================
  //  STATUS CARD
  // ======================================================================
  Widget _buildStatusCard({
    required bool isDark,
    required Color primary,
    required Color text,
    required Color sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isActive
            ? primary.withValues(alpha: isDark ? 0.10 : 0.05)
            : (isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isActive
              ? primary.withValues(alpha: isDark ? 0.25 : 0.20)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05)),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _isActive
                  ? primary.withValues(alpha: 0.15)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isActive
                  ? Icons.check_circle_rounded
                  : Icons.pause_circle_rounded,
              color: _isActive ? primary : sub,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statut du fournisseur',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: text,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isActive
                      ? 'Actif — associable aux produits'
                      : 'Inactif — masqué des sélections',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: sub,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
            activeThumbColor: primary,
            activeTrackColor: primary,
          ),
        ],
      ),
    );
  }
}