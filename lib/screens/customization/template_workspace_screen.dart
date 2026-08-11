// lib/screens/customization/template_workspace_screen.dart
// ============================================================
//  🎨 ESPACE DE TRAVAIL DRAG & DROP — personnalisation visuelle d'un modèle.
//
//  Fonctionnalités :
//   - Palette d'éléments (en-tête, client, lignes, totaux, pied, QR, signature)
//   - Glisser-déposer des éléments sur la page (coordonnées relatives 0..1)
//   - Déplacement libre au doigt/souris + redimensionnement (scale)
//   - Mapping des variables de facture vers chaque élément
//   - Sauvegarde locale des positions + mapping (TemplateCustomService)
// ============================================================
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_template.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/template_service.dart';
import '../../services/template_custom_service.dart';

/// Identifiants des éléments d'une facture.
class TemplateElement {
  final String id;
  final String label;
  final IconData icon;
  const TemplateElement(this.id, this.label, this.icon);
}

/// 🧩 CHAQUE VARIABLE de facture est un élément à part entière : déplaçable,
/// redimensionnable et masquable individuellement (drag & drop).
const List<TemplateElement> kTemplateElements = [
  // En-tête société
  TemplateElement('logo', 'Logo', Icons.image_outlined),
  TemplateElement('company_name', 'Nom société', Icons.business_rounded),
  TemplateElement('company_address', 'Adresse société', Icons.location_on_outlined),
  TemplateElement('company_phone', 'Tél société', Icons.phone_outlined),
  TemplateElement('company_email', 'Email société', Icons.email_outlined),
  TemplateElement('invoice_title', 'Titre FACTURE', Icons.title),
  // Client
  TemplateElement('client_name', 'Nom client', Icons.person_rounded),
  TemplateElement('client_address', 'Adresse client', Icons.location_city_outlined),
  TemplateElement('client_phone', 'Tél client', Icons.phone_iphone_outlined),
  TemplateElement('client_email', 'Email client', Icons.alternate_email),
  // Corps
  TemplateElement('items', 'Lignes', Icons.receipt_long_rounded),
  TemplateElement('subtotal', 'Sous-total', Icons.calculate_outlined),
  TemplateElement('tax_amount', 'TVA', Icons.percent),
  TemplateElement('discount', 'Remise', Icons.local_offer_outlined),
  TemplateElement('total_amount', 'Total', Icons.summarize_outlined),
  // Pied de page
  TemplateElement('footer', 'Pied de page', Icons.text_snippet_rounded),
  TemplateElement('qr', 'QR Paiement', Icons.qr_code_rounded),
  TemplateElement('signature', 'Signature', Icons.draw_rounded),
];

/// Sections de la facture : chaque VARIABLE est déplaçable et éditable.
const Map<String, List<String>> kTemplateSections = {
  'En-tête': [
    'logo',
    'company_name',
    'company_address',
    'company_phone',
    'company_email',
    'invoice_title',
  ],
  'Client': [
    'client_name',
    'client_address',
    'client_phone',
    'client_email',
  ],
  'Corps': ['items', 'subtotal', 'tax_amount', 'discount', 'total_amount'],
  'Pied de page': ['footer', 'qr', 'signature'],
};

/// Position par défaut de chaque variable (x,y relatifs 0..1, scale).
const Map<String, dynamic> kDefaultPositions = {
  'logo': {'x': 0.04, 'y': 0.02, 'scale': 1.0, 'visible': true},
  'company_name': {'x': 0.22, 'y': 0.04, 'scale': 1.0, 'visible': true},
  'company_address': {'x': 0.22, 'y': 0.065, 'scale': 1.0, 'visible': true},
  'company_phone': {'x': 0.22, 'y': 0.09, 'scale': 1.0, 'visible': true},
  'company_email': {'x': 0.22, 'y': 0.115, 'scale': 1.0, 'visible': true},
  'invoice_title': {'x': 0.58, 'y': 0.04, 'scale': 1.0, 'visible': true},
  'client_name': {'x': 0.04, 'y': 0.16, 'scale': 1.0, 'visible': true},
  'client_address': {'x': 0.04, 'y': 0.185, 'scale': 1.0, 'visible': true},
  'client_phone': {'x': 0.04, 'y': 0.21, 'scale': 1.0, 'visible': true},
  'client_email': {'x': 0.04, 'y': 0.235, 'scale': 1.0, 'visible': true},
  'items': {'x': 0.04, 'y': 0.30, 'scale': 1.0, 'visible': true},
  'subtotal': {'x': 0.5, 'y': 0.60, 'scale': 1.0, 'visible': true},
  'tax_amount': {'x': 0.5, 'y': 0.63, 'scale': 1.0, 'visible': true},
  'discount': {'x': 0.5, 'y': 0.66, 'scale': 1.0, 'visible': true},
  'total_amount': {'x': 0.5, 'y': 0.69, 'scale': 1.0, 'visible': true},
  'footer': {'x': 0.04, 'y': 0.85, 'scale': 1.0, 'visible': true},
  'qr': {'x': 0.04, 'y': 0.64, 'scale': 1.0, 'visible': true},
  'signature': {'x': 0.55, 'y': 0.86, 'scale': 1.0, 'visible': true},
};

class TemplateWorkspaceScreen extends StatefulWidget {
  final InvoiceTemplate template;
  const TemplateWorkspaceScreen({super.key, required this.template});

  @override
  State<TemplateWorkspaceScreen> createState() => _TemplateWorkspaceScreenState();
}

class _TemplateWorkspaceScreenState extends State<TemplateWorkspaceScreen> {
  late Map<String, dynamic> _positions;
  Map<String, String> _mapping = {};
  String? _selectedElement;
  bool _saving = false;

  // Valeurs d'exemple pour l'aperçu
  final String _companyName = 'OHADA Invoice Pro';
  final String _companyAddress = 'Douala, Cameroun';
  final String _clientName = 'Client SARL';
  final List<Map<String, String>> _sampleItems = const [
    {'name': 'Service de conseil', 'qty': '2', 'price': '50 000', 'total': '100 000'},
    {'name': 'Formation', 'qty': '1', 'price': '75 000', 'total': '75 000'},
  ];

  @override
  void initState() {
    super.initState();
    _positions = _mergeWithDefaults(widget.template.positions);
    _mapping = Map<String, String>.from(widget.template.mapping);
    _loadCustom();
  }

  Map<String, dynamic> _mergeWithDefaults(Map<String, dynamic> stored) {
    final result = <String, dynamic>{
      for (final e in kDefaultPositions.entries) e.key: Map<String, dynamic>.from(e.value as Map),
    };
    stored.forEach((id, value) {
      if (value is Map) {
        result[id] = {...(result[id] as Map? ?? {}), ...Map<String, dynamic>.from(value)};
      }
    });
    return result;
  }

  Future<void> _loadCustom() async {
    final custom = await TemplateCustomService.loadCustom(widget.template.id);
    if (!mounted) return;
    setState(() {
      _positions = _mergeWithDefaults(custom.positions);
      _mapping = {..._mapping, ...custom.mapping};
    });
  }

  Map<String, dynamic> _posOf(String id) =>
      (_positions[id] as Map?)?.cast<String, dynamic>() ?? {};

  bool _visible(String id) => (_posOf(id)['visible'] as bool?) ?? true;
  double _scale(String id) => ((_posOf(id)['scale'] as num?) ?? 1.0).toDouble();
  double _x(String id) => ((_posOf(id)['x'] as num?) ?? 0.04).toDouble().clamp(0.0, 0.98);
  double _y(String id) => ((_posOf(id)['y'] as num?) ?? 0.04).toDouble().clamp(0.0, 0.98);

  void _updatePos(String id, Map<String, dynamic> patch) {
    setState(() {
      final cur = _posOf(id);
      _positions[id] = {...cur, ...patch};
    });
  }

  // ===== ENREGISTREMENT =====
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // 1) Sauvegarde locale (positions + mapping) — persiste pour l'utilisateur.
      await TemplateCustomService.saveCustom(
        widget.template.id,
        positions: _positions,
        mapping: _mapping,
      );

      // 2) Si l'utilisateur est admin, on persiste aussi le template source.
      final auth = context.read<AppAuthProvider>();
      final isAdmin = auth.user?.isAdmin == true;
      if (isAdmin && (widget.template.createdBy?.isNotEmpty ?? false)) {
        final updated = widget.template.copyWith(
          positions: _positions,
          mapping: _mapping,
        );
        await TemplateService().updateTemplate(updated);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Personnalisation enregistrée'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur d\'enregistrement : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Personnaliser — ${widget.template.name}',
          style: TextStyle(
            color: theme.textColor,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.textColor, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Réinitialiser',
            icon: Icon(Icons.restart_alt_rounded, color: theme.subTextColor),
            onPressed: () {
              setState(() => _positions = _mergeWithDefaults({}));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Positions réinitialisées'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _saving
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _save,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.save_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Enregistrer',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ),
        ],
      ),
      body: _buildPage(theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openToolbar,
        backgroundColor: widget.template.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.tune_rounded),
        label: const Text('Éléments'),
      ),
    );
  }

  /// Ouvre la barre d'outils de personnalisation en tiroir (drawer) par le bas.
  void _openToolbar() {
    final theme = context.read<ThemeProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) =>
            _buildToolbarSheet(theme, setSheetState),
      ),
    );
  }

  // ===== BARRE D'OUTILS (tiroir depuis le bas) =====
  Widget _buildToolbarSheet(ThemeProvider theme, StateSetter setSheetState) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.62,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.dashboard_customize_rounded,
                  color: widget.template.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Éléments',
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Fermer',
                icon: Icon(Icons.close, color: theme.subTextColor, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Sections En-tête / Corps / Pied de page — chaque élément est
          // déplaçable et éditable individuellement.
          for (final entry in kTemplateSections.entries) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                entry.key,
                style: TextStyle(
                  color: theme.subTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final id in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildToolbarChip(
                        _elementById(id),
                        theme,
                        setSheetState,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Divider(height: 1, color: theme.dividerColor),
          const SizedBox(height: 8),
          // Propriétés de l'élément sélectionné.
          Expanded(
            child: _selectedElement == null
                ? Center(
                    child: Text(
                      'Touchez un élément pour le modifier',
                      style: TextStyle(color: theme.subTextColor, fontSize: 12),
                    ),
                  )
                : _buildProperties(theme),
          ),
        ],
      ),
    );
  }

  TemplateElement _elementById(String id) => kTemplateElements.firstWhere(
        (e) => e.id == id,
        orElse: () => kTemplateElements.first,
      );

  Widget _buildToolbarChip(
      TemplateElement e, ThemeProvider theme, StateSetter setSheetState) {
    final isSelected = _selectedElement == e.id;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedElement = e.id);
        setSheetState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? widget.template.primaryColor.withValues(alpha: 0.12)
              : theme.backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? widget.template.primaryColor
                : theme.dividerColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(e.icon, size: 16, color: widget.template.primaryColor),
            const SizedBox(width: 6),
            Text(
              e.label,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== PAGE (aperçu A4 avec éléments positionnés) =====
  Widget _buildPage(ThemeProvider theme) {
    final pageBg = widget.template.backgroundColor;
    final bgBytes = _templateBgBytes();
    return Container(
      color: theme.isDarkMode ? const Color(0xFF111114) : const Color(0xFFEEEEF2),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: AspectRatio(
            aspectRatio: 210 / 297,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return DragTarget<String>(
                  onAcceptWithDetails: (details) {
                    final id = details.data;
                    if (_positions.containsKey(id)) {
                      // Le drop repositionne simplement l'élément (centré).
                      _selectedElement = id;
                    } else {
                      _positions[id] = {...kDefaultPositions[id] as Map};
                    }
                    setState(() {});
                  },
                  builder: (context, candidates, rejected) {
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: pageBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: widget.template.primaryColor.withValues(alpha: 0.35),
                                width: widget.template.showBorder ? 1.5 : 0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 🖼️ Image téléversée du modèle en arrière-plan.
                        if (bgBytes != null)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Opacity(
                                opacity: 0.3,
                                child: Image.memory(
                                  bgBytes,
                                  fit: BoxFit.fill,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        for (final e in kTemplateElements)
                          if (_visible(e.id))
                            _buildPositionedElement(e, w, h, theme),
                        // Grille de repère (léger)
                        ..._buildGuideGrid(w, h, theme),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Décode l'image téléversée du modèle (base64) pour l'arrière-plan.
  Uint8List? _templateBgBytes() {
    if (widget.template.fileData.isEmpty ||
        widget.template.fileType == 'pdf') {
      return null;
    }
    try {
      return base64Decode(widget.template.fileData);
    } catch (_) {
      return null;
    }
  }

  List<Widget> _buildGuideGrid(double w, double h, ThemeProvider theme) {
    const n = 4;
    return [
      for (int i = 1; i < n; i++)
        Positioned(
          left: w * i / n,
          top: 0,
          width: 1,
          height: h,
          child: Container(color: theme.isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
        ),
      for (int j = 1; j < n; j++)
        Positioned(
          left: 0,
          top: h * j / n,
          width: w,
          height: 1,
          child: Container(color: theme.isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
        ),
    ];
  }

  Widget _buildPositionedElement(
      TemplateElement e, double w, double h, ThemeProvider theme) {
    final x = _x(e.id);
    final y = _y(e.id);
    final scale = _scale(e.id);
    final isSelected = _selectedElement == e.id;

    // Taille relative de l'élément (largeur ~ 55% de la page, hauteur variable).
    final elemWidth = w * 0.55 * scale;
    final content = _buildElementContent(e, elemWidth, theme);

    // Mesure la hauteur approximative pour éviter les débordements.
    return Positioned(
      left: x * w,
      top: y * h,
      width: elemWidth,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedElement = e.id);
          _openToolbar();
        },
        onPanUpdate: (details) {
          if (!isSelected) setState(() => _selectedElement = e.id);
          final newX = (_x(e.id) + details.delta.dx / w).clamp(0.0, 0.98);
          final newY = (_y(e.id) + details.delta.dy / h).clamp(0.0, 0.98);
          _updatePos(e.id, {'x': newX, 'y': newY});
        },
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? widget.template.primaryColor.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isSelected
                    ? Border.all(
                        color: widget.template.primaryColor,
                        width: 1.4,
                      )
                    : Border.all(color: Colors.transparent),
              ),
              child: content,
            ),
            // Étiquette de l'élément (petit badge)
            Positioned(
              top: -4,
              left: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.template.primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(e.icon, size: 9, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(
                      e.label,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            // Poignée de redimensionnement (bas-droite)
            if (isSelected)
              Positioned(
                right: -8,
                bottom: -8,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    final newScale =
                        (_scale(e.id) + d.delta.dx / 200).clamp(0.5, 2.5);
                    _updatePos(e.id, {'scale': newScale});
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: widget.template.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.open_with_rounded, size: 10, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===== CONTENU DE CHAQUE ÉLÉMENT =====
  Widget _buildElementContent(TemplateElement e, double width, ThemeProvider theme) {
    final primary = widget.template.primaryColor;
    final text = widget.template.textColor;
    final mappedVar = _mapping[e.id];
    final varBadge = mappedVar == null
        ? null
        : '{{$mappedVar}}';

    Widget inner;
    switch (e.id) {
      case 'logo':
        inner = Container(
          width: width * 0.14,
          height: width * 0.14,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primary.withValues(alpha: 0.3)),
          ),
          child: Icon(Icons.business_rounded, color: primary, size: 20),
        );
      case 'company_name':
        inner = Text(
          _companyName,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case 'company_address':
        inner = Text(
          _companyAddress,
          style: TextStyle(fontSize: 9, color: text.withValues(alpha: 0.7)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case 'company_phone':
        inner = Text(
          'Tél : +237 6 90 00 00 00',
          style: TextStyle(fontSize: 9, color: text.withValues(alpha: 0.7)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case 'company_email':
        inner = Text(
          'contact@ohada-invoice-pro.com',
          style: TextStyle(fontSize: 9, color: text.withValues(alpha: 0.7)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case 'invoice_title':
        inner = Text(
          'FACTURE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: primary,
            letterSpacing: 2,
          ),
          textAlign: TextAlign.right,
        );
      case 'client_name':
        inner = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Facturé à :',
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
            Text(
              _clientName,
              style: TextStyle(
                color: text,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      case 'client_address':
        inner = Text(
          'Douala, Cameroun',
          style: TextStyle(
            color: text.withValues(alpha: 0.6),
            fontSize: 9,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case 'client_phone':
        inner = Text(
          'Tél : +237 6 90 00 00 00',
          style: TextStyle(
            color: text.withValues(alpha: 0.6),
            fontSize: 9,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case 'client_email':
        inner = Text(
          'client@email.com',
          style: TextStyle(
            color: text.withValues(alpha: 0.6),
            fontSize: 9,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case 'items':
        inner = Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: _tableHead('Désignation')),
                  Expanded(child: _tableHead('Qté', center: true)),
                  Expanded(child: _tableHead('Prix', right: true)),
                  Expanded(child: _tableHead('Total', right: true)),
                ],
              ),
            ),
            for (final item in _sampleItems)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: primary.withValues(alpha: 0.12)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(item['name']!,
                          style: TextStyle(fontSize: 9, color: text),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      child: Text(item['qty']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9, color: text)),
                    ),
                    Expanded(
                      child: Text(item['price']!,
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 9, color: text)),
                    ),
                    Expanded(
                      child: Text(item['total']!,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 9, color: text, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
          ],
        );
      case 'subtotal':
        inner = _totalRow('Sous-total', '175 000 XAF');
      case 'tax_amount':
        inner = _totalRow('TVA (18%)', '31 500 XAF');
      case 'discount':
        inner = _totalRow('Remise', '-5 000 XAF');
      case 'total_amount':
        inner = Container(
          padding: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: primary.withValues(alpha: 0.4)),
            ),
          ),
          child: _totalRow('TOTAL', '206 500 XAF', bold: true, primary: primary),
        );
      case 'footer':
        inner = Text(
          'Merci de votre confiance. Paiement à 30 jours.',
          style: TextStyle(
            fontSize: 9,
            color: text.withValues(alpha: 0.65),
            fontStyle: FontStyle.italic,
          ),
        );
      case 'qr':
        inner = Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: primary.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.qr_code_rounded, size: 34, color: text.withValues(alpha: 0.8)),
        );
      case 'signature':
        inner = Container(
          width: width * 0.5,
          padding: const EdgeInsets.only(top: 4),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.black45)),
          ),
          child: Text(
            'Signature',
            style: TextStyle(fontSize: 9, color: text.withValues(alpha: 0.6)),
          ),
        );
      default:
        inner = const SizedBox.shrink();
    }

    // Badge variable assignée (si mapping)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (varBadge != null)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.4)),
            ),
            child: Text(
              varBadge,
              style: const TextStyle(
                color: Colors.deepPurple,
                fontSize: 8,
                fontFamily: 'monospace',
              ),
            ),
          ),
        inner,
      ],
    );
  }

  Widget _tableHead(String t, {bool center = false, bool right = false}) {
    return Text(
      t,
      textAlign: right
          ? TextAlign.right
          : center
              ? TextAlign.center
              : TextAlign.left,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 9,
      ),
    );
  }

  Widget _totalRow(String label, String value,
      {bool bold = false, Color? primary}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: bold ? (primary ?? Colors.black) : null,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ===== PANNEAU DE PROPRIÉTÉS =====
  Widget _buildProperties(ThemeProvider theme) {
    final id = _selectedElement;
    if (id == null) {
      return Center(
        child: Text(
          'Sélectionnez un élément\npour le personnaliser',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.subTextColor, fontSize: 12, height: 1.5),
        ),
      );
    }
    final el = kTemplateElements.firstWhere((e) => e.id == id,
        orElse: () => kTemplateElements.first);
    final visible = _visible(id);
    final scale = _scale(id);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(el.icon, size: 18, color: widget.template.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  el.label,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Supprimer de la page',
                icon: Icon(Icons.delete_outline_rounded,
                    color: theme.subTextColor, size: 20),
                onPressed: () => _updatePos(id, {'visible': false}),
              ),
            ],
          ),
          const Divider(height: 16),
          // Visible
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Visible',
              style: TextStyle(fontSize: 12),
            ),
            value: visible,
            onChanged: (v) => _updatePos(id, {'visible': v}),
          ),
          // Échelle
          Text('Taille', style: TextStyle(color: theme.subTextColor, fontSize: 11)),
          Row(
            children: [
              const Icon(Icons.zoom_out, size: 16),
              Expanded(
                child: Slider(
                  value: scale,
                  min: 0.5,
                  max: 2.5,
                  onChanged: (v) => _updatePos(id, {'scale': v}),
                ),
              ),
              const Icon(Icons.zoom_in, size: 16),
            ],
          ),
          // Variable de facture à afficher (mapping)
          if (InvoiceTemplate.availableVariables.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Variable de facture',
              style: TextStyle(color: theme.subTextColor, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _mapping.containsKey(id) ? _mapping[id] : null,
                  hint: Text(
                    'Aucune (texte fixe)',
                    style: TextStyle(color: theme.subTextColor, fontSize: 12),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Aucune (texte fixe)',
                          style: TextStyle(fontSize: 12)),
                    ),
                    for (final v in InvoiceTemplate.availableVariables)
                      DropdownMenuItem<String>(
                        value: v,
                        child: Text(v, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    if (v == null) {
                      _mapping.remove(id);
                    } else {
                      _mapping[id] = v;
                    }
                  }),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Astuce : glissez l\'élément sur la page pour le déplacer, '
            'utilisez la poignée pour l\'agrandir.',
            style: TextStyle(color: theme.subTextColor, fontSize: 10, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ===== AJUSTEMENT MATHÉMATIQUE (scale pour garder l'élément dans la page) =====
  // (utilisé par la poignée — la logique clamp est dans _buildPositionedElement)
}
