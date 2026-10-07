// lib/screens/admin/admin_plan_form_screen.dart
//
// 🎨 Plan form — épuré, corrections : context après await, checkbox unifiée.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/plan.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';

class AdminPlanFormScreen extends StatefulWidget {
  final String? planId;
  const AdminPlanFormScreen({super.key, this.planId});

  @override
  State<AdminPlanFormScreen> createState() => _AdminPlanFormScreenState();
}

class _AdminPlanFormScreenState extends State<AdminPlanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _currencyController = TextEditingController(text: 'XAF');
  final _maxInvoicesController = TextEditingController(text: '-1');
  final _maxClientsController = TextEditingController(text: '-1');

  String _interval = 'month';
  bool _hasPdfExport = true;
  bool _hasCloudSync = true;
  bool _hasTeamAccess = false;
  bool _isPopular = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    if (widget.planId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final plans = await _adminService.getAllPlans();
      final plan = plans.firstWhere((p) => p.id == widget.planId);
      if (!mounted) return;
      _nameController.text = plan.name;
      _descriptionController.text = plan.description;
      _priceController.text = plan.price.toString();
      _currencyController.text = plan.currency;
      _maxInvoicesController.text = plan.maxInvoices.toString();
      _maxClientsController.text = plan.maxClients.toString();
      _interval = plan.interval;
      _hasPdfExport = plan.hasPdfExport;
      _hasCloudSync = plan.hasCloudSync;
      _hasTeamAccess = plan.hasTeamAccess;
      _isPopular = plan.isPopular;
      _isActive = plan.isActive;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _currencyController.dispose();
    _maxInvoicesController.dispose();
    _maxClientsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final plan = Plan(
        id: widget.planId ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.tryParse(_priceController.text) ?? 0.0,
        currency: _currencyController.text.trim(),
        interval: _interval,
        maxInvoices: int.tryParse(_maxInvoicesController.text) ?? -1,
        maxClients: int.tryParse(_maxClientsController.text) ?? -1,
        hasPdfExport: _hasPdfExport,
        hasCloudSync: _hasCloudSync,
        hasTeamAccess: _hasTeamAccess,
        isPopular: _isPopular,
        isActive: _isActive,
      );

      if (widget.planId == null) {
        await _adminService.createPlan(plan);
      } else {
        await _adminService.updatePlan(plan);
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Plan enregistré'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted) navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;
    final primary = theme.primaryColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: text, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.planId == null ? 'Nouveau plan' : 'Modifier le plan',
          style: TextStyle(
            color: text,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            style: TextButton.styleFrom(
              foregroundColor: primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: primary),
                  )
                : Text(
                    widget.planId == null ? 'Créer' : 'Modifier',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionLabel('Informations', sub),
                    const SizedBox(height: 10),
                    _field(_nameController, 'Nom du plan',
                        Icons.text_fields_rounded,
                        isDark: isDark, text: text, sub: sub, primary: primary,
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'Requis'
                            : null),
                    const SizedBox(height: 12),
                    _field(_descriptionController, 'Description',
                        Icons.description_outlined,
                        isDark: isDark, text: text, sub: sub, primary: primary,
                        maxLines: 3),
                    const SizedBox(height: 24),

                    _sectionLabel('Tarification', sub),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _field(_priceController, 'Prix',
                              Icons.attach_money_rounded,
                              isDark: isDark, text: text, sub: sub,
                              primary: primary,
                              keyboard: TextInputType.number,
                              validator: (v) => v?.trim().isEmpty == true
                                  ? 'Requis'
                                  : null),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(_currencyController, 'Devise',
                              Icons.monetization_on_outlined,
                              isDark: isDark, text: text, sub: sub,
                              primary: primary,
                              validator: (v) => v?.trim().isEmpty == true
                                  ? 'Requis'
                                  : null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _dropdown<String>(
                      value: _interval,
                      items: const [
                        DropdownMenuItem(value: 'month', child: Text('Mensuel')),
                        DropdownMenuItem(value: 'year', child: Text('Annuel')),
                      ],
                      onChanged: (v) => setState(() => _interval = v!),
                      card: isDark ? const Color(0xFF1A1D26) : Colors.white,
                      isDark: isDark,
                      text: text,
                      sub: sub,
                      primary: primary,
                      icon: Icons.calendar_today_rounded,
                    ),
                    const SizedBox(height: 24),

                    _sectionLabel('Limites', sub),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _field(_maxInvoicesController,
                              'Max factures (−1 = ∞)',
                              Icons.receipt_long_outlined,
                              isDark: isDark, text: text, sub: sub,
                              primary: primary,
                              keyboard: TextInputType.number,
                              validator: (v) => v?.trim().isEmpty == true
                                  ? 'Requis'
                                  : null),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(_maxClientsController,
                              'Max clients (−1 = ∞)',
                              Icons.people_outline_rounded,
                              isDark: isDark, text: text, sub: sub,
                              primary: primary,
                              keyboard: TextInputType.number,
                              validator: (v) => v?.trim().isEmpty == true
                                  ? 'Requis'
                                  : null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _sectionLabel('Fonctionnalités', sub),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1D26) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                        ),
                      ),
                      child: Column(
                        children: [
                          _switchTile('Export PDF', _hasPdfExport,
                              (v) => setState(() => _hasPdfExport = v),
                              primary, text, isDark),
                          _divider(isDark),
                          _switchTile('Synchronisation cloud', _hasCloudSync,
                              (v) => setState(() => _hasCloudSync = v),
                              primary, text, isDark),
                          _divider(isDark),
                          _switchTile('Accès équipe', _hasTeamAccess,
                              (v) => setState(() => _hasTeamAccess = v),
                              primary, text, isDark),
                          _divider(isDark),
                          _switchTile('Plan populaire (badge)', _isPopular,
                              (v) => setState(() => _isPopular = v),
                              primary, text, isDark),
                          _divider(isDark),
                          _switchTile('Actif', _isActive,
                              (v) => setState(() => _isActive = v),
                              primary, text, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                widget.planId == null
                                    ? 'Créer le plan'
                                    : 'Mettre à jour',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String label, Color sub) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: sub,
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
        height: 1,
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
      );

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    required bool isDark,
    required Color text,
    required Color sub,
    required Color primary,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(color: text, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: sub,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon:
            Icon(icon, size: 20, color: primary.withValues(alpha: 0.7)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.025),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: primary.withValues(alpha: 0.7), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        isDense: true,
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required Color card,
    required bool isDark,
    required Color text,
    required Color sub,
    required Color primary,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: sub),
        dropdownColor: card,
        style: TextStyle(color: text, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon:
              Icon(icon, size: 20, color: primary.withValues(alpha: 0.7)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _switchTile(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
    Color primary,
    Color text,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: text,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}