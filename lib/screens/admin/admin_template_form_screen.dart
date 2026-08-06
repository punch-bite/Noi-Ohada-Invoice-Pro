// lib/screens/admin/admin_template_form_screen.dart
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  late TextEditingController _priceController;
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
  String _category = 'classique';
  bool _isLoading = false;
  bool _isLoadingData = true;

  // 🏷️ Catégories proposées pour la boutique
  static const List<String> _categoryOptions = [
    'classique',
    'moderne',
    'elegant',
    'premium',
    'minimaliste',
    'entreprise',
  ];

  static String _categoryLabel(String c) =>
      c.isEmpty ? 'Classique' : c[0].toUpperCase() + c.substring(1);

  // 🗂️ Fichier téléversé (PDF/JPEG/PNG)
  String _fileType = '';
  String _fileData = '';
  String _fileName = '';
  // 🧩 Mapping variable de facture → placeholder
  final Map<String, String> _mapping = {};
  // Contrôleurs pour le mapping (un par variable)
  final Map<String, TextEditingController> _mappingControllers = {};

  /// Libellé lisible d'une variable (ex. invoice_number → 'N° de facture').
  static String _varLabel(String v) {
    switch (v) {
      case 'invoice_number':
        return 'N° de facture';
      case 'issue_date':
        return 'Date d\'émission';
      case 'due_date':
        return 'Date d\'échéance';
      case 'client_name':
        return 'Nom du client';
      case 'client_email':
        return 'Email client';
      case 'client_phone':
        return 'Téléphone client';
      case 'company_name':
        return 'Nom de l\'entreprise';
      case 'company_address':
        return 'Adresse entreprise';
      case 'company_tax_id':
        return 'N° fiscal';
      case 'subtotal':
        return 'Sous-total';
      case 'tax_amount':
        return 'Montant TVA';
      case 'total_amount':
        return 'Total TTC';
      case 'status':
        return 'Statut';
      default:
        return v;
    }
  }

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
    _priceController = TextEditingController(text: '0');
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
    _category = template.category.isEmpty ? 'classique' : template.category;
    _priceController.text = template.price.toStringAsFixed(0);
    _fileType = template.fileType;
    _fileData = template.fileData;
    _fileName = template.fileData.isNotEmpty
        ? 'Fichier téléversé (${template.fileType.toUpperCase()})'
        : '';
    _mapping.clear();
    _mapping.addAll(template.mapping);
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
    for (final c in _mappingControllers.values) {
      c.dispose();
    }
    _mappingControllers.clear();
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

  /// 🗂️ Téléverse un fichier template (PDF / JPEG / PNG) et le stocke en base64.
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpeg', 'jpg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) return;
      final ext = file.extension?.toLowerCase() ?? 'png';
      final type = ext == 'pdf'
          ? 'pdf'
          : (ext == 'png' ? 'png' : 'jpeg');
      setState(() {
        _fileType = type;
        _fileData = base64Encode(bytes);
        _fileName = file.name;
      });
    } catch (e) {
      // Repli : image_picker pour les images si file_picker échoue.
      try {
        final picked = await ImagePicker()
            .pickImage(source: ImageSource.gallery, maxWidth: 2048);
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          final type = picked.name.toLowerCase().endsWith('png')
              ? 'png'
              : 'jpeg';
          setState(() {
            _fileType = type;
            _fileData = base64Encode(bytes);
            _fileName = picked.name;
          });
        }
      } catch (_) {}
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
      // 💰 Prix de vente (0 = gratuit) — template vendu sur la plateforme.
      price: double.tryParse(_priceController.text) ?? 0,
      paid: _isPremium && (double.tryParse(_priceController.text) ?? 0) > 0,
      // 🗂️ Fichier téléversé + mapping
      fileType: _fileType,
      fileData: _fileData,
      mapping: Map<String, String>.from(_mapping),
      category: _category,
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
                      const SizedBox(height: 12),
                      // 🏷️ Catégorie (boutique)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _category,
                            icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                            dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                            style: TextStyle(color: textColor, fontSize: 14),
                            items: _categoryOptions.map((c) {
                              return DropdownMenuItem<String>(
                                value: c,
                                child: Row(
                                  children: [
                                    Icon(Icons.category_outlined, size: 18, color: primaryColor),
                                    const SizedBox(width: 10),
                                    Text(_categoryLabel(c)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _category = v);
                            },
                          ),
                        ),
                      ),

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
                            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
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
                            const Divider(height: 12, thickness: 0.5),
                            // 💰 Prix de vente du template sur la plateforme.
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: TextFormField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Prix de vente (XAF)',
                                  labelStyle: TextStyle(color: subTextColor, fontSize: 13),
                                  hintText: '0 = gratuit',
                                  prefixIcon: Icon(Icons.sell_outlined, size: 20, color: primaryColor),
                                  filled: true,
                                  fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                style: TextStyle(color: textColor, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      _buildSectionLabel('Fichier du modèle & Mapping', textColor),
                      const SizedBox(height: 4),
                      Text(
                        'Téléversez votre template (PDF/JPEG/PNG) puis mappez '
                        'les variables de facture à leurs emplacements.',
                        style: TextStyle(
                            color: subTextColor, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 10),

                      // ===== Bouton d'upload =====
                      InkWell(
                        onTap: _pickFile,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey[800]
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!,
                              width: 0.6,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _fileData.isEmpty
                                    ? Icons.upload_file_rounded
                                    : (_fileType == 'pdf'
                                        ? Icons.picture_as_pdf_rounded
                                        : Icons.image_rounded),
                                color: primaryColor,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _fileData.isEmpty
                                          ? 'Téléverser un template'
                                          : _fileName.isNotEmpty
                                              ? _fileName
                                              : 'Fichier chargé',
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _fileData.isEmpty
                                          ? 'PDF, JPEG ou PNG'
                                          : '${_fileType.toUpperCase()} • cliquer pour remplacer',
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.edit_outlined,
                                  color: Colors.grey, size: 18),
                            ],
                          ),
                        ),
                      ),

                      // ===== Aperçu de l'image si JPEG/PNG =====
                      if (_fileData.isNotEmpty && _fileType != 'pdf') ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(_fileData),
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // ===== Mapping des variables =====
                      Text(
                        'Mapping des variables',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Associez chaque variable de facture à son placeholder '
                        'dans le template (ex. {invoice_number}).',
                        style: TextStyle(
                            color: subTextColor, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      ...InvoiceTemplate.availableVariables.map(
                        (v) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  _varLabel(v),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _mappingControllers[v] ??
                                      (_mappingControllers[v] =
                                          TextEditingController(
                                              text: _mapping[v] ??
                                                  '{$v}')),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: '{$v}',
                                    hintStyle: TextStyle(
                                        color: subTextColor, fontSize: 12),
                                    filled: true,
                                    fillColor: isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                  ),
                                  style: TextStyle(
                                      color: textColor, fontSize: 13),
                                  onChanged: (val) =>
                                      _mapping[v] = val.trim(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

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