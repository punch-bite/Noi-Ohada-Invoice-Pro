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

const List<TemplateElement> kTemplateElements = [
  TemplateElement('header', 'En-tête', Icons.business_rounded),
  TemplateElement('client', 'Client', Icons.person_rounded),
  TemplateElement('items', 'Lignes', Icons.receipt_long_rounded),
  TemplateElement('totals', 'Totaux', Icons.calculate_rounded),
  TemplateElement('footer', 'Pied de page', Icons.text_snippet_rounded),
  TemplateElement('qr', 'QR Paiement', Icons.qr_code_rounded),
  TemplateElement('signature', 'Signature', Icons.draw_rounded),
];

/// Position par défaut de chaque élément (x,y relatifs 0..1, scale).
const Map<String, dynamic> kDefaultPositions = {
  'header': {'x': 0.04, 'y': 0.04, 'scale': 1.0, 'visible': true},
  'client': {'x': 0.04, 'y': 0.16, 'scale': 1.0, 'visible': true},
  'items': {'x': 0.04, 'y': 0.30, 'scale': 1.0, 'visible': true},
  'totals': {'x': 0.45, 'y': 0.62, 'scale': 1.0, 'visible': true},
  'footer': {'x': 0.04, 'y': 0.85, 'scale': 1.0, 'visible': true},
  'qr': {'x': 0.04, 'y': 0.64, 'scale': 1.0, 'visible': false},
  'signature': {'x': 0.55, 'y': 0.86, 'scale': 1.0, 'visible': false},
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
      body: _isWide(context)
          ? _buildWideLayout(theme)
          : _buildNarrowLayout(theme),
    );
  }

  bool _isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  // ===== LAYOUT LARGE (palette à gauche, page au centre, props à droite) =====
  Widget _buildWideLayout(ThemeProvider theme) {
    return Row(
      children: [
        SizedBox(width: 200, child: _buildPalette(theme)),
        const VerticalDivider(width: 1),
        Expanded(child: _buildPage(theme)),
        const VerticalDivider(width: 1),
        SizedBox(width: 250, child: _buildProperties(theme)),
      ],
    );
  }

  // ===== LAYOUT ÉTROIT (page au centre, palette/props en panneaux) =====
  Widget _buildNarrowLayout(ThemeProvider theme) {
    return Column(
      children: [
        Expanded(child: _buildPage(theme)),
        _buildBottomBar(theme),
      ],
    );
  }

  Widget _buildBottomBar(ThemeProvider theme) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final e in kTemplateElements)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildPaletteChip(e, theme),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _selectedElement == null
                ? Center(
                    child: Text(
                      'Touchez un élément pour le modifier',
                      style: TextStyle(color: theme.subTextColor, fontSize: 11),
                    ),
                  )
                : _buildProperties(theme, compact: true),
          ),
        ],
      ),
    );
  }

  // ===== PALETTE (liste des éléments) =====
  Widget _buildPalette(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Text(
            'Éléments',
            style: TextStyle(
              color: theme.textColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Glissez un élément sur la page',
            style: TextStyle(color: theme.subTextColor, fontSize: 11),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              for (final e in kTemplateElements)
                Draggable<String>(
                  data: e.id,
                  feedback: Material(
                    color: Colors.transparent,
                    child: _paletteChipWidget(e, theme, elevated: true),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.4,
                    child: _paletteChipWidget(e, theme),
                  ),
                  child: _paletteChipWidget(e, theme),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaletteChip(TemplateElement e, ThemeProvider theme) {
    return _paletteChipWidget(e, theme);
  }

  Widget _paletteChipWidget(TemplateElement e, ThemeProvider theme,
      {bool elevated = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(e.icon, size: 18, color: widget.template.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              e.label,
              style: TextStyle(color: theme.textColor, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ===== PAGE (aperçu A4 avec éléments positionnés) =====
  Widget _buildPage(ThemeProvider theme) {
    final pageBg = widget.template.backgroundColor;
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
        onTap: () => setState(() => _selectedElement = e.id),
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
      case 'header':
        inner = Row(
          children: [
            Container(
              width: width * 0.16,
              height: width * 0.16,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.business_rounded, color: primary, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _companyName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _companyAddress,
                    style: TextStyle(fontSize: 9, color: text.withValues(alpha: 0.7)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'FACTURE',
                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      case 'client':
        inner = Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.05),
            border: Border.all(color: primary.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
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
              Text(
                'Douala, Cameroun',
                style: TextStyle(
                  color: text.withValues(alpha: 0.6),
                  fontSize: 9,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
      case 'totals':
        inner = Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: primary.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              _totalRow('Sous-total', '175 000 XAF'),
              _totalRow('TVA (18%)', '31 500 XAF'),
              const Divider(height: 6),
              _totalRow('TOTAL', '206 500 XAF', bold: true, primary: primary),
            ],
          ),
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
  Widget _buildProperties(ThemeProvider theme, {bool compact = false}) {
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
            title: const Text('Visible', style: TextStyle(fontSize: 12)),
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
