// lib/screens/admin/admin_template_form_screen.dart
//
// CHANGELOG (v3 — REFONTE ATELIER) :
//   • Catégories alignées sur les 8 presets (Classique, Moderne, Élégant,
//     Premium, Corporate) — au lieu de la liste libre précédente.
//   • Nouveaux sélecteurs de STYLE : header_style, table_style, footer_style,
//     accent_border (chips visuels).
//   • Polices cohérentes avec le moteur PDF (WorkSans, Manrope, Roboto).
//   • Aperçu live intégré (mini-vignette) qui reflète les couleurs et styles
//     choisis en temps réel.
//   • Bouton "Ouvrir dans l'atelier" une fois le modèle créé → accès direct
//     au workspace drag & drop.
//   • Grille / marges ajustables (pagePadding) exposées ici.
//   • UI épurée alignée sur le workspace (barres fines, chips, cards sobres).
//
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/template_service.dart';

class AdminTemplateFormScreen extends StatefulWidget {
  final String? templateId;
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
  late TextEditingController _pagePaddingController;

  // Affichage
  bool _showLogo = true;
  bool _showTaxDetails = true;
  bool _showPaymentTerms = true;
  bool _showPaymentQR = false;
  bool _isPremium = false;
  bool _showBorder = false;
  String _fontFamily = 'WorkSans';
  String _category = 'Classique';

  // 🎨 STYLES PRO (identiques au moteur PDF)
  String _headerStyle = 'flat';
  String _tableStyle = 'plain';
  String _footerStyle = 'simple';
  String _accentBorder = '';
  double _pagePadding = 32;

  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _createdTemplateId; // pour proposer "Ouvrir dans l'atelier"

  // ── Catégories (alignées sur les 8 presets) ──
  static const List<String> _categoryOptions = [
    'Classique',
    'Moderne',
    'Élégant',
    'Premium',
    'Corporate',
    'Minimaliste',
  ];

  // ── Polices réellement disponibles dans les assets ──
  static const List<String> _fontOptions = [
    'WorkSans',
    'Manrope',
    'Roboto',
  ];

  // ── Fichier ──
  String _fileType = '';
  String _fileData = '';
  String _fileName = '';
  static const int _maxFileBytes = 700 * 1024;

  // ── Mapping ──
  final Map<String, String> _mapping = {};
  final Map<String, TextEditingController> _mappingControllers = {};

  // ── Catalogue de styles (source unique pour l'UI + le PDF) ──
  static const List<(String, String)> _headerStyles = [
    ('flat', 'Plat'),
    ('dark', 'Foncé'),
    ('band', 'Bandeau'),
    ('wave', 'Vague'),
    ('split_orange_left', 'Orange (G)'),
    ('split_diagonal_corners', 'Diagonales'),
    ('circle_accent_top_left', 'Cercle (G)'),
    ('orange_band_right', 'Orange (D)'),
    ('cursive_title', 'Cursive'),
    ('diamond_center', 'Losange'),
  ];
  static const List<(String, String)> _tableStyles = [
    ('plain', 'Simple'),
    ('alternate_dark', 'Zébré foncé'),
    ('dark_header', 'Header foncé'),
    ('orange_bars', 'Barres orange'),
    ('cards', 'Cartes'),
  ];
  static const List<(String, String)> _footerStyles = [
    ('simple', 'Simple'),
    ('contact_bar_icons', 'Contact'),
    ('zigzag_thankyou', 'Zigzag'),
    ('thick_orange_band', 'Bande orange'),
    ('rainbow_strip', 'Arc-en-ciel'),
    ('diagonal_bottom_stripes', 'Diagonales'),
  ];
  static const List<(String, String)> _accentBorders = [
    ('', 'Aucune'),
    ('top', 'Haut'),
    ('left', 'Gauche'),
    ('frame', 'Cadre'),
    ('stripes_bottom', 'Bandes bas'),
  ];

  /// Libellé lisible d'une variable (ex. invoice_number → 'N° de facture').
  static String _varLabel(String v) {
    switch (v) {
      case 'invoice_number':
        return 'N° de facture';
      case 'issue_date':
        return "Date d'émission";
      case 'due_date':
        return "Date d'échéance";
      case 'client_name':
        return 'Nom du client';
      case 'client_email':
        return 'Email client';
      case 'client_phone':
        return 'Téléphone client';
      case 'company_name':
        return "Nom de l'entreprise";
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
    _primaryColorController = TextEditingController(text: '#F39200');
    _textColorController = TextEditingController(text: '#1F2937');
    _backgroundColorController = TextEditingController(text: '#FFFFFF');
    _pagePaddingController = TextEditingController(text: '32');
  }

  void _updateControllersFromTemplate(InvoiceTemplate template) {
    _nameController.text = template.name;
    _descriptionController.text = template.description;
    _fontSizeController.text = template.fontSize.toString();
    _primaryColorController.text = '#${template.primaryColorValue
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase()}';
    _textColorController.text = '#${template.textColorValue
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase()}';
    _backgroundColorController.text = '#${template.backgroundColorValue
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase()}';

    _showLogo = template.showLogo;
    _showTaxDetails = template.showTaxDetails;
    _showPaymentTerms = template.showPaymentTerms;
    _showPaymentQR = template.showPaymentQR;
    _isPremium = template.isPremium;
    _showBorder = template.showBorder;
    _fontFamily = template.fontFamily.isEmpty ? 'WorkSans' : template.fontFamily;
    _category = template.category.isEmpty ? 'Classique' : template.category;
    _priceController.text = template.price.toStringAsFixed(0);

    // Styles depuis les positions enregistrées
    final p = template.positions;
    _headerStyle = p['header_style']?.toString() ?? 'flat';
    _tableStyle = p['table_style']?.toString() ?? 'plain';
    _footerStyle = p['footer_style']?.toString() ?? 'simple';
    _accentBorder = p['accent_border']?.toString() ?? '';
    _pagePadding = (p['page_padding'] as num?)?.toDouble() ?? 32;
    _pagePaddingController.text = _pagePadding.toStringAsFixed(0);

    _fileType = template.fileType;
    _fileData = template.fileData;
    _fileName = template.fileData.isNotEmpty
        ? 'Fichier téléversé (${template.fileType.toUpperCase()})'
        : '';
    _mapping
      ..clear()
      ..addAll(template.mapping);
    _createdTemplateId = template.id;
  }

  Future<void> _loadTemplate(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final template = await _templateService.getTemplateById(id);
      if (!mounted) return;
      if (template != null) {
        setState(() {
          _updateControllersFromTemplate(template);
          _isLoadingData = false;
        });
      } else {
        setState(() => _isLoadingData = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Modèle introuvable'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur de chargement: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _fontSizeController.dispose();
    _priceController.dispose();
    _primaryColorController.dispose();
    _textColorController.dispose();
    _backgroundColorController.dispose();
    _pagePaddingController.dispose();
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
      if (bytes.length > _maxFileBytes) {
        _toast('Fichier trop lourd (max 700 Ko).', Colors.orange);
        return;
      }
      final ext = file.extension?.toLowerCase() ?? 'png';
      final type = ext == 'pdf' ? 'pdf' : (ext == 'png' ? 'png' : 'jpeg');
      setState(() {
        _fileType = type;
        _fileData = base64Encode(bytes);
        _fileName = file.name;
      });
    } catch (_) {
      try {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          imageQuality: 80,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        if (bytes.length > _maxFileBytes) {
          _toast('Image trop lourde (max 700 Ko).', Colors.orange);
          return;
        }
        final type =
            picked.name.toLowerCase().endsWith('png') ? 'png' : 'jpeg';
        setState(() {
          _fileType = type;
          _fileData = base64Encode(bytes);
          _fileName = picked.name;
        });
      } catch (_) {}
    }
  }

  void _toast(String msg, [Color? color]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color ?? Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _save({bool openWorkspaceAfter = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = context.read<AppAuthProvider>();
    final userId = auth.user?.id ?? 'admin_unknown';
    final navigator = GoRouter.of(context);

    String? existingId;
    if (widget.templateId != null) {
      final t = await _templateService.getTemplateById(widget.templateId!);
      existingId = t?.id;
    }

    // Fusionner les styles dans `positions` (source unique lue par le
    // workspace ET le moteur PDF).
    final mergedPositions = <String, dynamic>{
      'header_style': _headerStyle,
      'table_style': _tableStyle,
      'footer_style': _footerStyle,
      'accent_border': _accentBorder,
      'page_padding': _pagePadding,
      'grid_snap': InvoiceTemplate.gridSnap,
      'design_version': InvoiceTemplate.kRoyalDesignVersion,
    };

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
      price: double.tryParse(_priceController.text) ?? 0,
      paid: _isPremium && (double.tryParse(_priceController.text) ?? 0) > 0,
      fileType: _fileType,
      fileData: _fileData,
      mapping: Map<String, String>.from(_mapping),
      category: _category,
      positions: mergedPositions,
    );

    try {
      if (widget.templateId != null) {
        await _templateService.updateTemplate(template);
      } else {
        await _templateService.createTemplate(template);
      }
      if (!mounted) return;
      setState(() => _createdTemplateId = template.id);
      _toast('Modèle enregistré avec succès');

      if (openWorkspaceAfter) {
        navigator.push('/templates/workspace', extra: template);
      } else if (widget.templateId != null) {
        navigator.pop(true);
      }
    } catch (e) {
      _toast("Erreur d'enregistrement : $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
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
        appBar: _appBar(isDark, textColor, primaryColor, 'Chargement…'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _appBar(
        isDark,
        textColor,
        primaryColor,
        widget.templateId == null ? 'Nouveau modèle' : 'Modifier le modèle',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Informations générales ──
                      _section('Informations générales', textColor),
                      const SizedBox(height: 10),
                      _field('Nom du modèle *', _nameController,
                          Icons.label_important_outline_rounded, cardColor,
                          textColor, subTextColor, primaryColor, isDark),
                      const SizedBox(height: 12),
                      _field('Description *', _descriptionController,
                          Icons.description_outlined, cardColor, textColor,
                          subTextColor, primaryColor, isDark,
                          maxLines: 3),
                      const SizedBox(height: 12),
                      _chipRow<String>(
                        label: 'Catégorie',
                        current: _category,
                        options: [
                          for (final c in _categoryOptions) (c, c)
                        ],
                        primaryColor: primaryColor,
                        textColor: textColor,
                        onChanged: (v) => setState(() => _category = v),
                      ),

                      // ── Couleurs ──
                      const SizedBox(height: 24),
                      _section('Couleurs', textColor),
                      const SizedBox(height: 10),
                      _colorField('Couleur primaire *',
                          _primaryColorController, cardColor, textColor,
                          subTextColor, primaryColor, isDark),
                      const SizedBox(height: 12),
                      _colorField('Couleur de texte *', _textColorController,
                          cardColor, textColor, subTextColor, primaryColor,
                          isDark),
                      const SizedBox(height: 12),
                      _colorField('Couleur de fond *',
                          _backgroundColorController, cardColor, textColor,
                          subTextColor, primaryColor, isDark),

                      // ── Aperçu live ──
                      const SizedBox(height: 20),
                      _section('Aperçu', textColor),
                      const SizedBox(height: 10),
                      _buildLivePreview(
                        primaryColor: _parseColor(_primaryColorController.text),
                        textColor: _parseColor(_textColorController.text),
                        bgColor: _parseColor(_backgroundColorController.text),
                        cardColor: cardColor,
                      ),

                      // ── Styles ──
                      const SizedBox(height: 24),
                      _section('Styles de la facture', textColor),
                      const SizedBox(height: 10),
                      _chipRow<String>(
                        label: 'En-tête',
                        current: _headerStyle,
                        options: _headerStyles,
                        primaryColor: primaryColor,
                        textColor: textColor,
                        onChanged: (v) => setState(() => _headerStyle = v),
                      ),
                      const SizedBox(height: 12),
                      _chipRow<String>(
                        label: 'Tableau',
                        current: _tableStyle,
                        options: _tableStyles,
                        primaryColor: primaryColor,
                        textColor: textColor,
                        onChanged: (v) => setState(() => _tableStyle = v),
                      ),
                      const SizedBox(height: 12),
                      _chipRow<String>(
                        label: 'Pied de page',
                        current: _footerStyle,
                        options: _footerStyles,
                        primaryColor: primaryColor,
                        textColor: textColor,
                        onChanged: (v) => setState(() => _footerStyle = v),
                      ),
                      const SizedBox(height: 12),
                      _chipRow<String>(
                        label: 'Bordure décorative',
                        current: _accentBorder,
                        options: _accentBorders,
                        primaryColor: primaryColor,
                        textColor: textColor,
                        onChanged: (v) => setState(() => _accentBorder = v),
                      ),
                      const SizedBox(height: 12),
                      _sliderField(
                        label:
                            'Marge de page (${_pagePadding.round()} pt)',
                        value: _pagePadding,
                        min: 8,
                        max: 80,
                        primaryColor: primaryColor,
                        textColor: textColor,
                        onChanged: (v) => setState(() => _pagePadding = v),
                      ),

                      // ── Options d'affichage ──
                      const SizedBox(height: 24),
                      _section("Options d'affichage", textColor),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey[800]!
                                : Colors.grey[200]!,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            _switchTile('Afficher le logo', _showLogo,
                                primaryColor, textColor,
                                (v) => setState(() => _showLogo = v)),
                            const Divider(height: 12, thickness: 0.5),
                            _switchTile('Détailler le calcul de la TVA',
                                _showTaxDetails, primaryColor, textColor,
                                (v) => setState(() => _showTaxDetails = v)),
                            const Divider(height: 12, thickness: 0.5),
                            _switchTile('Conditions de règlement',
                                _showPaymentTerms, primaryColor, textColor,
                                (v) => setState(() => _showPaymentTerms = v)),
                            const Divider(height: 12, thickness: 0.5),
                            _switchTile('QR code de paiement', _showPaymentQR,
                                primaryColor, textColor,
                                (v) => setState(() => _showPaymentQR = v)),
                            const Divider(height: 12, thickness: 0.5),
                            _switchTile('Bordure de page', _showBorder,
                                primaryColor, textColor,
                                (v) => setState(() => _showBorder = v)),
                            const Divider(height: 12, thickness: 0.5),
                            _switchTile('Modèle Premium', _isPremium,
                                primaryColor, textColor,
                                (v) => setState(() => _isPremium = v)),
                            const Divider(height: 12, thickness: 0.5),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _field(
                                'Prix de vente (XAF)',
                                _priceController,
                                Icons.sell_outlined,
                                isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey[50]!,
                                textColor,
                                subTextColor,
                                primaryColor,
                                isDark,
                                keyboard: TextInputType.number,
                                validator: null,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Fichier & mapping ──
                      const SizedBox(height: 24),
                      _section('Fichier & Mapping', textColor),
                      const SizedBox(height: 4),
                      Text(
                        'Téléversez votre template (PDF/JPEG/PNG) puis mappez '
                        'les variables de facture à leurs placeholders.',
                        style: TextStyle(
                            color: subTextColor, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      _uploadCard(primaryColor, textColor, subTextColor, isDark),
                      if (_fileData.isNotEmpty && _fileType != 'pdf') ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(_fileData),
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
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
                        'Associez chaque variable à son placeholder dans le '
                        'fichier (ex. {invoice_number}).',
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
                                  controller: _mappingControllers[v] ??=
                                      TextEditingController(
                                          text: _mapping[v] ?? '{$v}'),
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
                                    contentPadding:
                                        const EdgeInsets.symmetric(
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

                      // ── Typographie ──
                      const SizedBox(height: 24),
                      _section('Typographie', textColor),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _dropdown(
                              'Police',
                              _fontFamily,
                              _fontOptions,
                              cardColor,
                              textColor,
                              subTextColor,
                              isDark,
                              (v) => setState(() => _fontFamily = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: _field(
                              'Taille *',
                              _fontSizeController,
                              Icons.format_size_rounded,
                              cardColor,
                              textColor,
                              subTextColor,
                              primaryColor,
                              isDark,
                              keyboard: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // ── Actions ──
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _save(openWorkspaceAfter: false),
                              icon: const Icon(Icons.save_outlined, size: 18),
                              label: Text(widget.templateId == null
                                  ? 'Créer'
                                  : 'Mettre à jour'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () =>
                                      _save(openWorkspaceAfter: true),
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text('Ouvrir l\'atelier'),
                              style: FilledButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 52),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  WIDGETS INTERNES
  // ═══════════════════════════════════════════════════════════════
  PreferredSizeWidget _appBar(
    bool isDark,
    Color textColor,
    Color primaryColor,
    String title,
  ) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
        onPressed: () => context.pop(),
      ),
      actions: [
        if (_createdTemplateId != null && widget.templateId != null)
          IconButton(
            tooltip: 'Ouvrir dans l\'atelier',
            icon: Icon(Icons.tune_rounded, color: primaryColor, size: 20),
            onPressed: () => context.push(
              '/templates/workspace',
              extra: _workingCopyForWorkspace(),
            ),
          ),
      ],
    );
  }

  InvoiceTemplate _workingCopyForWorkspace() => InvoiceTemplate(
        id: _createdTemplateId ?? const Uuid().v4(),
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
        fontFamily: _fontFamily,
        fontSize: double.tryParse(_fontSizeController.text) ?? 12,
        showBorder: _showBorder,
        category: _category,
        price: double.tryParse(_priceController.text) ?? 0,
        positions: {
          'header_style': _headerStyle,
          'table_style': _tableStyle,
          'footer_style': _footerStyle,
          'accent_border': _accentBorder,
          'page_padding': _pagePadding,
        },
      );

  Widget _section(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _field(
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subTextColor, fontSize: 13),
        prefixIcon:
            Icon(icon, size: 20, color: primaryColor.withValues(alpha: 0.6)),
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
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: validator ??
          (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
    );
  }

  Widget _colorField(
    String label,
    TextEditingController controller,
    Color cardColor,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    bool isDark,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            style: TextStyle(color: textColor, fontSize: 14),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: subTextColor, fontSize: 13),
              prefixIcon: Icon(Icons.palette_outlined,
                  size: 20, color: primaryColor.withValues(alpha: 0.6)),
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
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Requis';
              final r = RegExp(r'^#?[0-9a-fA-F]{6}$');
              return r.hasMatch(v.trim()) ? null : 'Format #RRGGBB';
            },
          ),
        ),
        const SizedBox(width: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _parseColor(controller.text),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipRow<T>({
    required String label,
    required T current,
    required List<(T, String)> options,
    required Color primaryColor,
    required Color textColor,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.75),
            )),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (v, lbl) in options)
              GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: v == current
                        ? primaryColor.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: v == current
                          ? primaryColor
                          : textColor.withValues(alpha: 0.15),
                      width: v == current ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    lbl,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          v == current ? FontWeight.w700 : FontWeight.w500,
                      color:
                          v == current ? primaryColor : textColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _sliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color primaryColor,
    required Color textColor,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.75),
            )),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: 18,
          activeColor: primaryColor,
          label: '${value.round()}',
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _switchTile(
    String label,
    bool value,
    Color activeColor,
    Color textColor,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
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

  Widget _dropdown(
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
      initialValue: items.contains(value) ? value : items.first,
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
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items:
          items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _uploadCard(
    Color primaryColor,
    Color textColor,
    Color subTextColor,
    bool isDark,
  ) {
    return InkWell(
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
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
                        ? 'PDF, JPEG ou PNG (max 700 Ko)'
                        : '${_fileType.toUpperCase()} • cliquer pour remplacer',
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  /// 🎴 Aperçu live : mini-vignette qui reflète les couleurs + styles
  /// sélectionnés, en temps réel.
  Widget _buildLivePreview({
    required Color primaryColor,
    required Color textColor,
    required Color bgColor,
    required Color cardColor,
  }) {
    final showHeaderBand = _headerStyle == 'band' ||
        _headerStyle == 'dark' ||
        _headerStyle == 'wave' ||
        _headerStyle == 'split_orange_left';
    final showOrangeTable =
        _tableStyle == 'orange_bars' || _tableStyle == 'dark_header';

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: showHeaderBand ? primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: showHeaderBand
                  ? null
                  : Border.all(color: primaryColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                if (_showLogo)
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: showHeaderBand
                          ? Colors.white.withValues(alpha: 0.9)
                          : primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 5,
                        width: 60,
                        decoration: BoxDecoration(
                          color: showHeaderBand
                              ? Colors.white.withValues(alpha: 0.9)
                              : primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height: 3,
                        width: 40,
                        color: showHeaderBand
                            ? Colors.white.withValues(alpha: 0.6)
                            : textColor.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
                Text(
                  'INVOICE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: showHeaderBand ? Colors.white : primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Client / Meta
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 3,
                      width: 30,
                      color: primaryColor.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      height: 3,
                      width: 44,
                      color: textColor.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    height: 3,
                    width: 26,
                    color: textColor.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: 3,
                    width: 26,
                    color: textColor.withValues(alpha: 0.2),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Tableau
          Container(
            decoration: BoxDecoration(
              color: showOrangeTable ? primaryColor : Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4)),
              border: showOrangeTable
                  ? null
                  : Border.all(
                      color: textColor.withValues(alpha: 0.15)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    height: 3,
                    color: showOrangeTable
                        ? Colors.white.withValues(alpha: 0.9)
                        : textColor.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 3,
                    color: showOrangeTable
                        ? Colors.white.withValues(alpha: 0.9)
                        : textColor.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 3,
                    color: showOrangeTable
                        ? Colors.white.withValues(alpha: 0.9)
                        : textColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < 3; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: _tableStyle == 'alternate_dark' && i.isEven
                    ? textColor.withValues(alpha: 0.05)
                    : null,
                border: Border(
                  bottom: BorderSide(
                    color: textColor.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Container(
                      height: 2.5,
                      width: double.infinity,
                      color: textColor.withValues(alpha: 0.25),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 2.5,
                      color: textColor.withValues(alpha: 0.25),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 2.5,
                      color: textColor.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          // Totaux
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Merci
          if (_footerStyle == 'zigzag_thankyou' ||
              _footerStyle == 'thick_orange_band' ||
              _footerStyle == 'rainbow_strip')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}