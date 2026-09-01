// lib/screens/customization/template_workspace_screen.dart
//
// 🧩 ESPACE DE PERSONNALISATION — refonte fidèle à la maquette Stitch
// « design/stitch_refined_billing_interface/personnalisation_avec_drag_drop/
// code.html » (version mobile), adaptée au thème de l'application
// (système / sombre / claire) via `RoyalScheme`.
//
// Structure : header « Détails Facture » · action « SAUVER » (primaire) ·
// feuille facture flottante (en-tête pointillé, table, totaux, tampon
// « PAYÉ », liseré décoratif) · panneau bas (onglets catégories, carrousel
// de miniatures, barre d'outils Couleur/Logo/…/Tampon Payé).

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../models/company.dart";
import "../../models/invoice_layout.dart";
import "../../models/invoice_template.dart";
import "../../services/database_service.dart";
import "../../services/template_custom_service.dart";
import "../../theme/royal_ledger.dart";
import "../../widgets/template_background_palette.dart";

class TemplateWorkspaceScreen extends StatefulWidget {
  final InvoiceTemplate template;

  const TemplateWorkspaceScreen({super.key, required this.template});

  @override
  State<TemplateWorkspaceScreen> createState() =>
      _TemplateWorkspaceScreenState();
}

class _TemplateWorkspaceScreenState extends State<TemplateWorkspaceScreen> {
  final DatabaseService _db = DatabaseService();

  Company? _company;
  late InvoiceTemplate _current;
  InvoiceLayoutConfig _layoutConfig = InvoiceLayoutConfig.defaultLayout();
  TemplateBackgroundSettings _background = const TemplateBackgroundSettings();
  List<InvoiceTemplate> _templates = [];
  bool _isLoading = true;

  bool _showStamp = true;
  int _selectedCategoryIndex = 0;
  final List<String> _categories = const [
    "Recommandé",
    "Simple",
    "Classique",
    "Professionnel",
  ];

  /// Filtre niveaux de gris pour les miniatures « PRO » non sélectionnées.
  static const ColorFilter _greyScale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  void initState() {
    super.initState();
    _current = widget.template;
    _loadData();
  }

  Future<void> _loadData() async {
    final company = await _db.getCompany();
    final templates = await _db.getTemplates();
    final custom = await TemplateCustomService.loadCustom(_current.id);
    if (!mounted) return;
    setState(() {
      _company = company;
      _templates = templates;
      if (custom.positions.isNotEmpty) {
        _layoutConfig = InvoiceLayoutConfig.fromMap(custom.positions);
      }
      _background = custom.background;
      _isLoading = false;
    });
  }

  Future<void> _selectTemplate(InvoiceTemplate t) async {
    if (t.id == _current.id) return;
    setState(() {
      _current = t;
      _isLoading = true;
    });
    final custom = await TemplateCustomService.loadCustom(t.id);
    if (!mounted) return;
    setState(() {
      if (custom.positions.isNotEmpty) {
        _layoutConfig = InvoiceLayoutConfig.fromMap(custom.positions);
      }
      _background = custom.background;
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    await TemplateCustomService.saveCustom(
      _current.id,
      positions: _layoutConfig.toMap(),
      mapping: const {},
      background: _background,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Modèle sauvegardé avec succès")),
    );
  }

  void _openColorPalette() {
    showBackgroundSettingsSheet(
      context,
      current: _background,
      onChanged: (s) => setState(() => _background = s),
    );
  }

  void _soon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("« $label » — bientôt disponible")),
    );
  }

  // ------------------------------------------------------ Données société

  String get _companyName {
    final n = _company?.name ?? "";
    return n.isEmpty ? "Noi Concept digital" : n;
  }

  String get _companyAddress {
    final a = _company?.address ?? "";
    return a.isEmpty ? "Doww Essos Yaoundé Cameroun" : a;
  }

  String get _companyPhone {
    final p = _company?.phone ?? "";
    return p.isEmpty ? "+237620409383" : p;
  }

  String get _companyEmail {
    final e = _company?.email ?? "";
    return e.isEmpty ? "contact@noiconcept.com" : e;
  }

  // ----------------------------------------------------------------- Build

  @override
  Widget build(BuildContext context) {
    final c = RoyalScheme.of(context);
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(c),
            _buildSaveRow(c),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: c.primary))
                  : _buildCanvas(c),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomPanel(c),
    );
  }

  // ---------------------------------------------------------------- Header

  Widget _buildHeader(RoyalScheme c) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back, color: c.onSurface),
            tooltip: "Retour",
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Détails Facture",
              style: RoyalText.headlineMd(c.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Rangée « SAUVER » (maquette : texte primaire, MAJUSCULES, à droite).
  Widget _buildSaveRow(RoyalScheme c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RoyalSpacing.containerPadding,
        RoyalSpacing.unit,
        RoyalSpacing.containerPadding,
        0,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: _saveConfig,
          child: Text(
            "SAUVER",
            style: RoyalText.labelBold(c.primary)
                .copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Canvas

  Widget _buildCanvas(RoyalScheme c) {
    return Container(
      color: c.surfaceContainerLow,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          RoyalSpacing.containerPadding,
          RoyalSpacing.md,
          RoyalSpacing.containerPadding,
          RoyalSpacing.lg,
        ),
        child: Center(child: _buildSheet(c)),
      ),
    );
  }

  // ------------------------------------------------- Feuille facture (A4)

  Widget _buildSheet(RoyalScheme c) {
    final hasBg = _background.hasCustomImage || _background.hasPreset;
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        color: hasBg ? null : c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(RoyalRadius.xl),
        border: Border.all(color: c.surfaceVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RoyalRadius.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetHeader(c),
            _sheetBody(c, hasBg),
            _sheetEdgeDecor(c),
          ],
        ),
      ),
    );
  }

  Widget _sheetHeader(RoyalScheme c) {
    return Container(
      color: c.secondary,
      padding: const EdgeInsets.all(RoyalSpacing.md),
      child: Stack(
        children: [
          // Motif pointillé (maquette : radial-gradient 12px, opacité 10%).
          Positioned.fill(
            child: CustomPaint(
              painter: _DotsPatternPainter(
                color: c.onSecondary.withValues(alpha: 0.12),
                step: 12,
                radius: 1.2,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.onSecondary.withValues(alpha: 0.18),
                  border: Border.all(
                    color: c.onSecondary.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  "NOI",
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.onSecondary,
                  ),
                ),
              ),
              const SizedBox(width: RoyalSpacing.gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "DE",
                      style: TextStyle(
                        fontFamily: 'WorkSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: c.onSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'WorkSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.onSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$_companyAddress\n$_companyPhone\n$_companyEmail",
                      style: TextStyle(
                        fontFamily: 'WorkSans',
                        fontSize: 9,
                        height: 1.25,
                        color: c.onSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RoyalSpacing.unit),
              Text(
                "FACTURE",
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: c.onSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------ Corps de facture

  Widget _sheetBody(RoyalScheme c, bool hasBg) {
    return Stack(
      children: [
        // Fond personnalisé (image galerie ou préréglage de la palette).
        if (hasBg)
          TemplateBackgroundLayer(
            presetId: _background.presetId,
            imageBytes: decodeBackgroundImage(_background.fileData),
            opacity: _background.opacity,
            blur: _background.blur,
            fit: _background.fit,
          ),
        Padding(
          padding: const EdgeInsets.all(RoyalSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _clientAndMetaRow(c),
              const SizedBox(height: RoyalSpacing.md),
              _miniTable(c),
              const SizedBox(height: RoyalSpacing.md),
              _totalsRow(c),
              const SizedBox(height: RoyalSpacing.md),
              _termsBlock(c),
            ],
          ),
        ),
        // Filigrane « PAYÉ » (pivoté — cf. maquette).
        if (_showStamp)
          Positioned.fill(
            child: Center(
              child: Transform.rotate(
                angle: -0.2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RoyalSpacing.md,
                    vertical: RoyalSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: c.tertiaryContainer.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(RoyalRadius.def),
                    border: Border.all(color: c.tertiaryContainer, width: 3),
                  ),
                  child: Text(
                    "PAYÉ",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                      color: c.tertiaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _clientAndMetaRow(RoyalScheme c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "FACTURÉ À",
                style: TextStyle(
                  fontFamily: 'WorkSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: c.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: RoyalSpacing.unit),
              Text(
                "-",
                style: TextStyle(
                  fontFamily: 'WorkSans',
                  fontSize: 11,
                  color: c.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: RoyalSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _metaRow(c, "Facture N°", "INV000342"),
            _metaRow(c, "Date", "26/03/2025"),
            _metaRow(c, "Échéance", "02/04/2025"),
          ],
        ),
      ],
    );
  }

  Widget _metaRow(RoyalScheme c, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RoyalSpacing.unit),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'WorkSans',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: c.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: RoyalSpacing.sm),
          SizedBox(
            width: 72,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 10,
                color: c.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------- Table, totaux, terms

  Widget _miniTable(RoyalScheme c) {
    final headerStyle = TextStyle(
      fontFamily: 'WorkSans',
      fontSize: 9,
      fontWeight: FontWeight.w600,
      color: c.secondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: RoyalSpacing.gutter,
            vertical: RoyalSpacing.unit,
          ),
          decoration: BoxDecoration(
            color: c.secondary.withValues(alpha: 0.10),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(RoyalRadius.sm),
            ),
          ),
          child: Row(
            children: [
              Expanded(child: Text("Description", style: headerStyle)),
              SizedBox(
                width: 40,
                child: Text("QTÉ",
                    textAlign: TextAlign.center, style: headerStyle),
              ),
              SizedBox(
                width: 64,
                child: Text("Prix",
                    textAlign: TextAlign.right, style: headerStyle),
              ),
              SizedBox(
                width: 64,
                child: Text("Montant",
                    textAlign: TextAlign.right, style: headerStyle),
              ),
            ],
          ),
        ),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(
            horizontal: RoyalSpacing.gutter,
            vertical: RoyalSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: c.surfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: const [
              Expanded(child: SizedBox()),
              SizedBox(width: 40),
              SizedBox(width: 64),
              SizedBox(width: 64),
            ],
          ),
        ),
      ],
    );
  }

  Widget _totalsRow(RoyalScheme c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 128,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: RoyalSpacing.unit,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Sous-Total",
                      style: TextStyle(
                        fontFamily: 'WorkSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: c.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      "Fr0",
                      style: TextStyle(
                        fontFamily: 'WorkSans',
                        fontSize: 10,
                        color: c.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: RoyalSpacing.unit),
              Container(
                padding: const EdgeInsets.all(RoyalSpacing.unit),
                decoration: BoxDecoration(
                  color: c.secondary,
                  borderRadius: BorderRadius.circular(RoyalRadius.sm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "MONTANT TOTAL",
                      style: TextStyle(
                        fontFamily: 'WorkSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: c.onSecondary,
                      ),
                    ),
                    Text(
                      "Fr0",
                      style: TextStyle(
                        fontFamily: 'WorkSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: c.onSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _termsBlock(RoyalScheme c) {
    return Container(
      padding: const EdgeInsets.only(top: RoyalSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.surfaceVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Termes et conditions",
            style: TextStyle(
              fontFamily: 'WorkSans',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: c.onSurface,
            ),
          ),
          const SizedBox(height: RoyalSpacing.unit),
          Text(
            "Merci pour votre confiance.",
            style: TextStyle(
              fontFamily: 'WorkSans',
              fontSize: 8,
              color: c.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Liseré décoratif bas (maquette : h-2 secondaire + bandes inclinées).
  Widget _sheetEdgeDecor(RoyalScheme c) {
    return SizedBox(
      height: 8,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: c.secondary)),
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Container(
              width: 32,
              color: c.onSecondary.withValues(alpha: 0.2),
              transform: Matrix4.skewX(-0.3),
            ),
          ),
          Positioned(
            left: 52,
            top: 0,
            bottom: 0,
            child: Container(
              width: 16,
              color: c.onSecondary.withValues(alpha: 0.2),
              transform: Matrix4.skewX(-0.3),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Panneau bas

  Widget _buildBottomPanel(RoyalScheme c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: c.surfaceVariant.withValues(alpha: 0.5)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _categoryTabs(c),
            _thumbCarousel(c),
            _toolBar(c),
          ],
        ),
      ),
    );
  }

  /// Onglets catégories (maquette : actif = primaire + soulignement 2px).
  Widget _categoryTabs(RoyalScheme c) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.surfaceVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: RoyalSpacing.containerPadding,
          vertical: 10,
        ),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: RoyalSpacing.lg),
        itemBuilder: (context, i) {
          final active = i == _selectedCategoryIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryIndex = i),
            child: Container(
              padding: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 2,
                    color: active ? c.primary : Colors.transparent,
                  ),
                ),
              ),
              child: Text(
                _categories[i],
                style: TextStyle(
                  fontFamily: 'WorkSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? c.primary : c.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Filtre les miniatures selon l'onglet actif.
  List<InvoiceTemplate> get _thumbTemplates {
    switch (_categories[_selectedCategoryIndex]) {
      case "Simple":
        return _templates.where((t) => t.price <= 0).toList();
      case "Classique":
        return _templates
            .where((t) => t.category.toLowerCase() == "classique")
            .toList();
      case "Professionnel":
        return _templates
            .where((t) => const ["corporate", "premium", "moderne"]
                .contains(t.category.toLowerCase()))
            .toList();
      default:
        return _templates;
    }
  }

  /// Carrousel de miniatures (80×112, bordure primaire si active).
  Widget _thumbCarousel(RoyalScheme c) {
    final thumbs = _thumbTemplates;
    return SizedBox(
      height: 136,
      child: thumbs.isEmpty
          ? Center(
              child: Text(
                "Aucun modèle dans cette catégorie",
                style: RoyalText.labelSm(c.onSurfaceVariant),
              ),
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: RoyalSpacing.containerPadding,
                vertical: 12,
              ),
              itemCount: thumbs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final t = thumbs[i];
                final selected = t.id == _current.id;
                final pro = t.price > 0 || t.isPremium;

                Widget thumb = Container(
                  width: 80,
                  height: 112,
                  decoration: BoxDecoration(
                    color: c.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected ? c.primary : c.outlineVariant,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: _thumbPreview(t),
                  ),
                );
                // Miniatures « PRO » non sélectionnées : grisées + voilées.
                if (pro && !selected) {
                  thumb = Opacity(
                    opacity: 0.7,
                    child: ColorFiltered(
                      colorFilter: _greyScale,
                      child: thumb,
                    ),
                  );
                }
                return GestureDetector(
                  onTap: () => _selectTemplate(t),
                  child: SizedBox(
                    width: 80,
                    child: Stack(
                      children: [
                        thumb,
                        if (pro)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: c.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "PRO",
                                style: TextStyle(
                                  fontFamily: 'WorkSans',
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: c.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  /// Aperçu miniature dessiné aux couleurs du modèle (pas d'asset image).
  Widget _thumbPreview(InvoiceTemplate t) {
    final Color bandFg = t.primaryColor.computeLuminance() > 0.5
        ? const Color(0xFF1E1A1F)
        : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 30,
          child: ColoredBox(
            color: t.primaryColor,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bandFg.withValues(alpha: 0.35),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 28,
                    height: 2,
                    color: bandFg.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 70,
          child: ColoredBox(
            color: t.backgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 2,
                    width: double.infinity,
                    color: t.textColor.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 2),
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    child: Container(
                      height: 2,
                      color: t.textColor.withValues(alpha: 0.15),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 4,
                    width: double.infinity,
                    color: t.primaryColor.withValues(alpha: 0.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------- Barre d'outils

  Widget _toolBar(RoyalScheme c) {
    final tools = <(String, VoidCallback, bool, IconData)>[
      ("Couleur", _openColorPalette, false, Icons.palette_outlined),
      ("Logo", () => _soon("Logo"), false, Icons.image_outlined),
      (
        "Taille de police",
        () => _soon("Taille de police"),
        false,
        Icons.format_size,
      ),
      ("Ombres", () => _soon("Ombres"), false, Icons.texture),
      ("Signature", () => _soon("Signature"), false, Icons.draw_outlined),
      (
        "Tampon Payé",
        () => setState(() => _showStamp = !_showStamp),
        _showStamp,
        Icons.verified_outlined,
      ),
    ];
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: RoyalSpacing.containerPadding,
          vertical: 10,
        ),
        itemCount: tools.length,
        separatorBuilder: (_, __) => const SizedBox(width: RoyalSpacing.lg),
        itemBuilder: (context, i) {
          final (label, onTap, active, icon) = tools[i];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon,
                        size: 26,
                        color: active ? c.primary : c.onSurfaceVariant,
                      ),
                      if (active)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: c.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: c.surfaceContainerLow,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'WorkSans',
                      fontSize: 10,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? c.primary : c.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Motif pointillé décoratif (en-tête de la feuille — cf. maquette).
class _DotsPatternPainter extends CustomPainter {
  final Color color;
  final double step;
  final double radius;

  _DotsPatternPainter({
    required this.color,
    this.step = 8,
    this.radius = 1.1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPatternPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.step != step ||
      oldDelegate.radius != radius;
}