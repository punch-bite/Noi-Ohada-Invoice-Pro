// lib/screens/admin/admin_template_form_screen.dart
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
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
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
        '#${template.primaryColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    _textColorController.text =
        '#${template.textColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    _backgroundColorController.text =
        '#${template.backgroundColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    _showLogo = template.showLogo;
    _showTaxDetails = template.showTaxDetails;
    _showPaymentTerms = template.showPaymentTerms;
    _showPaymentQR = template.showPaymentQR;
    _isPremium = template.isPremium;
    _showBorder = template.showBorder;
    _fontFamily = template.fontFamily;
  }

  Future<void> _loadTemplate(String id) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final template = await _templateService.getTemplateById(id);
      if (mounted) {
        if (template != null) {
          setState(() {
            _updateControllersFromTemplate(template);
            _isLoadingData = false;
          });
        } else {
          setState(() => _isLoadingData = false);
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Modèle introuvable'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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
      String clean = hex.replaceAll('#', '').trim();
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
    final navigator = GoRouter.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    String? existingId;
    if (widget.templateId != null) {
      final t = await _templateService.getTemplateById(widget.templateId!);
      existingId = t?.id;
    }

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
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Modèle enregistré avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      if (mounted) {
        navigator.pop(true);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erreur d\'enregistrement : $e'),
          backgroundColor: Colors.redAccent,
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
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final bgColor = theme.backgroundColor;
    final cardColor = theme.cardColor;
    final primaryColor = theme.primaryColor;

    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(
            widget.templateId == null ? 'Nouveau modèle' : 'Modifier le modèle',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          widget.templateId == null ? 'Nouveau modèle' : 'Modifier le modèle',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: Text(
              widget.templateId == null ? 'Ajouter' : 'Modifier',
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionLabel('Informations générales', textColor),
                      const SizedBox(height: 10),
                      _buildField('Nom du modèle *', _nameController, Icons.label_important_outline_rounded, cardColor, textColor, subTextColor, primaryColor, isDark),
                      const SizedBox(height: 12),
                      _buildField('Description *', _descriptionController, Icons.description_outlined, cardColor, textColor, subTextColor, primaryColor, isDark, maxLines: 3),
                      
                      const SizedBox(height: 24),
                      _buildSectionLabel('Couleurs du modèle (Hexadécimal)', textColor),
                      const SizedBox(height: 10),
                      _buildColorField('Couleur primaire *', _primaryColorController, cardColor, textColor, subTextColor, primaryColor, isDark),
                      const SizedBox(height: 12),
                      _buildColorField('Couleur de texte *', _textColorController, cardColor, textColor, subTextColor, primaryColor, isDark),
                      const SizedBox(height: 12),
                      _buildColorField('Couleur d\'arrière-plan *', _backgroundColorController, cardColor, textColor, subTextColor, primaryColor, isDark),
                      
                      const SizedBox(height: 24),
                      _buildSectionLabel('Options d\'affichage', textColor),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildSwitch('Afficher le logo principal', _showLogo, primaryColor, textColor, (v) => setState(() => _showLogo = v)),
                            const Divider(height: 12, thickness: 0.5),
                            _buildSwitch('Détailler le calcul de la TVA', _showTaxDetails, primaryColor, textColor, (v) => setState(() => _showTaxDetails = v)),
                            const Divider(height: 12, thickness: 0.5),
                            _buildSwitch('Afficher les conditions de règlement', _showPaymentTerms, primaryColor, textColor, (v) => setState(() => _showPaymentTerms = v)),
                            const Divider(height: 12, thickness: 0.5),
                            _buildSwitch('Inclure le QR Code de paiement', _showPaymentQR, primaryColor, textColor, (v) => setState(() => _showPaymentQR = v)),
                            const Divider(height: 12, thickness: 0.5),
                            _buildSwitch('Ajouter une bordure de page', _showBorder, primaryColor, textColor, (v) => setState(() => _showBorder = v)),
                            const Divider(height: 12, thickness: 0.5),
                            _buildSwitch('Définir comme modèle Premium', _isPremium, primaryColor, textColor, (v) => setState(() => _isPremium = v)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      _buildSectionLabel('Typographie & Structure', textColor),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildDropdown('Police de caractères', _fontFamily, _fontOptions, cardColor, textColor, subTextColor, isDark, (v) => setState(() => _fontFamily = v!)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: _buildField('Taille *', _fontSizeController, Icons.format_size_rounded, cardColor, textColor, subTextColor, primaryColor, isDark, keyboard: TextInputType.number),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // Bouton d'action
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            widget.templateId == null ? 'Créer le modèle' : 'Mettre à jour',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ========== WIDGETS DÉCOUPLÉS ET SÉCURISÉS ==========

  Widget _buildField(
    String label, 
    TextEditingController controller, 
    IconData icon,
    Color cardColor,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    bool isDark, {
    int maxLines = 1, 
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subTextColor, fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: primaryColor.withOpacity(0.5)),
        filled: true,
        fillColor: cardColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: primaryColor,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Requis';
        }
        return null;
      },
    );
  }

  Widget _buildColorField(
    String label, 
    TextEditingController controller,
    Color cardColor,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    bool isDark,
  ) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subTextColor, fontSize: 13),
        prefixIcon: Icon(Icons.palette_outlined, size: 20, color: primaryColor.withOpacity(0.5)),
        filled: true,
        fillColor: cardColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: primaryColor,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Requis';
        }
        final regExp = RegExp(r'^#?[0-9a-fA-F]{6}$');
        if (!regExp.hasMatch(v.trim())) {
          return 'Format Hexadécimal invalide (ex: #1976D2)';
        }
        return null;
      },
    );
  }

  Widget _buildSwitch(
    String label, 
    bool value, 
    Color activeColor, 
    Color textColor,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label, 
    String value, 
    List<String> items,
    Color cardColor,
    Color textColor,
    Color subTextColor,
    bool isDark,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      style: TextStyle(color: textColor, fontSize: 14),
      dropdownColor: cardColor,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subTextColor, fontSize: 13),
        filled: true,
        fillColor: cardColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}