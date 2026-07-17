// lib/screens/admin/admin_plan_form_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/plan.dart';
import '../../services/admin_service.dart';
import '../../providers/theme_provider.dart';

class AdminPlanFormScreen extends StatefulWidget {
  final String? planId; // L'ID du plan à modifier (null pour création)
  const AdminPlanFormScreen({super.key, this.planId});

  @override
  State<AdminPlanFormScreen> createState() => _AdminPlanFormScreenState();
}

class _AdminPlanFormScreenState extends State<AdminPlanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  bool _isSaving = false;

  // Contrôleurs
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan enregistré'), backgroundColor: Colors.green),
      );
      context.pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: Text(
            widget.planId == null ? 'Nouveau plan' : 'Modifier le plan',
            style: TextStyle(color: text, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          widget.planId == null ? 'Nouveau plan' : 'Modifier le plan',
          style: TextStyle(color: text, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              widget.planId == null ? 'Ajouter' : 'Modifier',
              style: TextStyle(color: primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(_nameController, 'Nom du plan *', Icons.text_fields, isDark, text, sub, primary,
                        validator: (v) => v?.trim().isEmpty == true ? 'Requis' : null),
                    const SizedBox(height: 12),
                    _buildTextField(_descriptionController, 'Description', Icons.description, isDark, text, sub, primary,
                        maxLines: 3),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(_priceController, 'Prix', Icons.attach_money, isDark, text, sub, primary,
                              keyboard: TextInputType.number,
                              validator: (v) => v?.trim().isEmpty == true ? 'Requis' : null),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(_currencyController, 'Devise', Icons.monetization_on, isDark, text, sub, primary,
                              validator: (v) => v?.trim().isEmpty == true ? 'Requis' : null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'Intervalle',
                      value: _interval,
                      items: const [
                        DropdownMenuItem(value: 'month', child: Text('Mensuel')),
                        DropdownMenuItem(value: 'year', child: Text('Annuel')),
                      ],
                      onChanged: (v) => setState(() => _interval = v!),
                      isDark: isDark,
                      text: text,
                      sub: sub,
                      primary: primary,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(_maxInvoicesController, 'Max factures (-1 = illimité)', Icons.receipt, isDark, text, sub, primary,
                              keyboard: TextInputType.number,
                              validator: (v) => v?.trim().isEmpty == true ? 'Requis' : null),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(_maxClientsController, 'Max clients (-1 = illimité)', Icons.people, isDark, text, sub, primary,
                              keyboard: TextInputType.number,
                              validator: (v) => v?.trim().isEmpty == true ? 'Requis' : null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildCheckbox('Export PDF', _hasPdfExport, (v) => setState(() => _hasPdfExport = v), isDark),
                    _buildCheckbox('Synchronisation cloud', _hasCloudSync, (v) => setState(() => _hasCloudSync = v), isDark),
                    _buildCheckbox('Accès équipe', _hasTeamAccess, (v) => setState(() => _hasTeamAccess = v), isDark),
                    _buildCheckbox('Plan populaire (badge)', _isPopular, (v) => setState(() => _isPopular = v), isDark),
                    _buildCheckbox('Actif', _isActive, (v) => setState(() => _isActive = v), isDark),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          widget.planId == null ? 'Créer le plan' : 'Mettre à jour',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ----- WIDGETS PRIVÉS -----

  Widget _buildTextField(
    TextEditingController c,
    String label,
    IconData icon,
    bool isDark,
    Color text,
    Color sub,
    Color primary, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(color: text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: sub, fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: primary.withOpacity(0.5)),
        filled: true,
        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    required Color text,
    required Color sub,
    required Color primary,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      style: TextStyle(color: text, fontSize: 14),
      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: sub, fontSize: 13),
        prefixIcon: Icon(Icons.calendar_today, size: 20, color: primary.withOpacity(0.5)),
        filled: true,
        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        isDense: true,
      ),
      items: items,
      onChanged: onChanged,
      validator: (v) => v == null ? 'Requis' : null,
    );
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool> onChanged, bool isDark) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v!),
          activeColor: context.watch<ThemeProvider>().primaryColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Text(label, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
      ],
    );
  }
}