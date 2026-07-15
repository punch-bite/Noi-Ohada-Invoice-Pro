// lib/screens/admin/admin_template_form_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unused_local_variable

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/invoice_template.dart';
import '../../services/template_service.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';

class AdminTemplateFormScreen extends StatefulWidget {
  final String? templateId; // ✅ pour l'édition
  const AdminTemplateFormScreen({super.key, this.templateId});

  @override
  State<AdminTemplateFormScreen> createState() =>
      _AdminTemplateFormScreenState();
}

class _AdminTemplateFormScreenState extends State<AdminTemplateFormScreen> {
  final TemplateService _templateService = TemplateService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _fontSizeController;
  late TextEditingController _primaryColorController;
  late TextEditingController _textColorController;
  late TextEditingController _backgroundColorController;

  bool _showLogo = true;
  bool _showTaxDetails = true;
  bool _showPaymentTerms = true;
  bool _showPaymentQR = false;
  bool _isPremium = false;
  bool _showBorder = true;
  String _fontFamily = 'Roboto';
  bool _isLoading = false;
  bool _isLoadingData = true;

  final List<String> _fontOptions = [
    'Roboto',
    'Open Sans',
    'Lato',
    'Montserrat'
  ];

  @override
  void initState() {
    super.initState();
    _initControllers();
    if (widget.templateId != null) {
      _loadTemplate(widget.templateId!);
    } else {
      setState(() => _isLoadingData = false);
    }
  }

  void _initControllers() {
    _nameController = TextEditingController(text: '');
    _descriptionController = TextEditingController(text: '');
    _fontSizeController = TextEditingController(text: '12');
    _primaryColorController = TextEditingController(text: '#1976D2');
    _textColorController = TextEditingController(text: '#000000');
    _backgroundColorController = TextEditingController(text: '#FFFFFF');
  }

  void _updateControllersFromTemplate(InvoiceTemplate template) {
    _nameController.text = template.name;
    _descriptionController.text = template.description;
    _fontSizeController.text = template.fontSize.toString();
    _primaryColorController.text =
        '#${template.primaryColor.value.toRadixString(16).padLeft(6, '0')}';
    _textColorController.text =
        '#${template.textColor.value.toRadixString(16).padLeft(6, '0')}';
    _backgroundColorController.text =
        '#${template.backgroundColor.value.toRadixString(16).padLeft(6, '0')}';
    _showLogo = template.showLogo;
    _showTaxDetails = template.showTaxDetails;
    _showPaymentTerms = template.showPaymentTerms;
    _showPaymentQR = template.showPaymentQR;
    _isPremium = template.isPremium;
    _showBorder = template.showBorder;
    _fontFamily = template.fontFamily;
  }

  Future<void> _loadTemplate(String id) async {
    final template = await _templateService.getTemplateById(id);
    if (template != null) {
      setState(() {
        _updateControllersFromTemplate(template);
        _isLoadingData = false;
      });
    } else {
      setState(() => _isLoadingData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Modèle introuvable'),
            backgroundColor: Colors.orange),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _fontSizeController.dispose();
    _primaryColorController.dispose();
    _textColorController.dispose();
    _backgroundColorController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      String clean = hex.replaceAll('#', '');
      if (clean.length == 6) clean = 'FF$clean';
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = context.read<AppAuthProvider>();
    final userId = auth.user?.id ?? 'admin_unknown';

    final existingId = widget.templateId != null
        ? (await _templateService.getTemplateById(widget.templateId!))?.id
        : null;

    final template = InvoiceTemplate(
      id: existingId ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      primaryColor: _parseColor(_primaryColorController.text),
      textColor: _parseColor(_textColorController.text),
      backgroundColor: _parseColor(_backgroundColorController.text),
      showLogo: _showLogo,
      showTaxDetails: _showTaxDetails,
      showPaymentTerms: _showPaymentTerms,
      showPaymentQR: _showPaymentQR,
      isPremium: _isPremium,
      isDefault: false,
      fontFamily: _fontFamily,
      fontSize: double.tryParse(_fontSizeController.text) ?? 12,
      showBorder: _showBorder,
      createdBy: userId,
      isActive: true,
      createdAt: DateTime.now(),
    );

    try {
      if (widget.templateId != null) {
        await _templateService.updateTemplate(template);
      } else {
        await _templateService.createTemplate(template);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Modèle enregistré'), backgroundColor: Colors.green),
      );
      context.pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
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

    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: Text(
            widget.templateId == null ? 'Nouveau modèle' : 'Modifier le modèle',
            style: TextStyle(color: text, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          widget.templateId == null ? 'Nouveau modèle' : 'Modifier le modèle',
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
            onPressed: _isLoading ? null : _save,
            child: Text(
              widget.templateId == null ? 'Ajouter' : 'Modifier',
              style: TextStyle(color: primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildField(
                        'Nom du modèle', _nameController, Icons.text_fields),
                    const SizedBox(height: 12),
                    _buildField('Description', _descriptionController,
                        Icons.description,
                        maxLines: 2),
                    const SizedBox(height: 12),
                    _buildColorField(
                        'Couleur primaire', _primaryColorController),
                    const SizedBox(height: 12),
                    _buildColorField('Couleur du texte', _textColorController),
                    const SizedBox(height: 12),
                    _buildColorField(
                        'Couleur de fond', _backgroundColorController),
                    const SizedBox(height: 12),

                    // Options avancées
                    _buildSwitch('Afficher le logo', _showLogo,
                        (v) => setState(() => _showLogo = v)),
                    _buildSwitch('Afficher la TVA', _showTaxDetails,
                        (v) => setState(() => _showTaxDetails = v)),
                    _buildSwitch(
                        'Afficher les conditions de paiement',
                        _showPaymentTerms,
                        (v) => setState(() => _showPaymentTerms = v)),
                    _buildSwitch('Afficher QR Code paiement', _showPaymentQR,
                        (v) => setState(() => _showPaymentQR = v)),
                    _buildSwitch('Afficher les bordures', _showBorder,
                        (v) => setState(() => _showBorder = v)),
                    _buildSwitch('Modèle premium', _isPremium,
                        (v) => setState(() => _isPremium = v)),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                              'Police',
                              _fontFamily,
                              _fontOptions,
                              (v) => setState(() => _fontFamily = v!)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField('Taille police',
                              _fontSizeController, Icons.format_size,
                              keyboard: TextInputType.number),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          widget.templateId == null
                              ? 'Créer le modèle'
                              : 'Mettre à jour',
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

  // ========== WIDGETS (inchangés) ==========
  Widget _buildField(String label, TextEditingController c, IconData icon,
      {int maxLines = 1, TextInputType? keyboard}) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final sub = theme.subTextColor;
    final text = theme.textColor;
    final primary = theme.primaryColor;

    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: TextStyle(color: text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: sub),
        prefixIcon: Icon(icon, size: 20, color: primary.withOpacity(0.5)),
        filled: true,
        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
      validator: (v) => v?.trim().isEmpty == true ? 'Requis' : null,
    );
  }

  Widget _buildColorField(String label, TextEditingController c) {
    return _buildField(label, c, Icons.color_lens);
  }

  Widget _buildSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final text = theme.textColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: theme.primaryColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final primary = theme.primaryColor;

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      style: TextStyle(color: text),
      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: sub),
        filled: true,
        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        isDense: true,
      ),
      items:
          items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}
