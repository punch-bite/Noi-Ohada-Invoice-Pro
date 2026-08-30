// lib/screens/customization/invoice_customization_edit_screen.dart
//
// 🎨 PERSONNALISATION « Détails Facture » — maquettes adaptées au thème
// glass indigo → violet de l'application.
//
// Structure (maquettes 1 & 2) :
//   • AppBar « Détails Facture » + action SAUVER
//   • Aperçu live de la facture (InvoiceMockupPreview)
//   • Onglets catégories (Recommandé / Simple / Classique / Professionnel)
//     + carrousel de vignettes modèles (applique la couleur du modèle)
//   • Barre d'outils : Couleur · Logo · Taille de police · Ombres · Signature
//     → panneau contextuel au-dessus de la barre (tailles S/M/L/XL, etc.)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/customization_config.dart';
import '../../providers/theme_provider.dart';
import '../../services/customization_service.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/invoice_mockup_preview.dart';
import '../../models/invoice_template.dart';

class InvoiceCustomizationEditScreen extends StatefulWidget {
  final CustomizationConfig? config;

  const InvoiceCustomizationEditScreen({super.key, this.config});

  @override
  State<InvoiceCustomizationEditScreen> createState() =>
      _InvoiceCustomizationEditScreenState();
}

class _InvoiceCustomizationEditScreenState
    extends State<InvoiceCustomizationEditScreen> {
  static const List<(IconData, String)> _tools = [
    (Icons.palette_outlined, 'Couleur'),
    (Icons.image_outlined, 'Logo'),
    (Icons.text_fields, 'Taille de police'),
    (Icons.texture, 'Ombres'),
    (Icons.draw_outlined, 'Signature'),
  ];

  static const List<Color> _colorPresets = [
    Color(0xFF4338CA),
    Color(0xFF1A237E),
    Color(0xFF00695C),
    Color(0xFF009688),
    Color(0xFF8E24AA),
    Color(0xFFD84315),
    Color(0xFFE91E63),
    Color(0xFF0D47A1),
    Color(0xFF262626),
    Color(0xFFFFD700),
  ];

  CustomizationConfig _config = CustomizationConfig.defaults;
  bool _loading = true;
  bool _saving = false;
  int _activeTool = -1;
  int _activeCategory = 0;
  String? _selectedTemplateId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = widget.config ?? await CustomizationService.instance.load();
    if (!mounted) return;
    String? selectedId;
    int category = 0;
    for (final t in DemoTemplates.all) {
      if (t.primaryColor == cfg.primaryColor) {
        selectedId = t.id;
        final idx = DemoTemplates.categories.indexOf(t.category);
        if (idx >= 0) category = idx;
        break;
      }
    }
    setState(() {
      _config = cfg;
      _selectedTemplateId = selectedId;
      _activeCategory = category;
      _loading = false;
    });
  }

  void _apply(CustomizationConfig cfg) => setState(() => _config = cfg);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await CustomizationService.instance.save(_config);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Personnalisation enregistrée'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    context.pop(_config);
  }

  // ── Build principal ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final text = theme.textColor;

    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Détails Facture',
          style: TextStyle(
            color: text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          _saveButton(theme),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: theme.primaryColor))
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: InvoiceMockupPreview(config: _config),
                        ),
                      ),
                    ),
                  ),
                  _bottomSheetArea(theme, isDark),
                ],
              ),
            ),
    );
  }

  /// Bouton « SAUVER » — pill en dégradé indigo → violet (thème).
  Widget _saveButton(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: _saving ? null : _save,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.primaryColor, theme.gradientEndColor],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: theme.primaryColor.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'SAUVER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Zone basse : onglets catégories + carrousel OR panneau outil ───────
  Widget _bottomSheetArea(ThemeProvider theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF151722).withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor,
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Un outil actif ? → panneau contextuel (maquette 2).
          // Sinon → onglets catégories + carrousel de modèles (maquette 1).
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.bottomCenter,
            child: _activeTool == -1
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _categoryTabs(theme, isDark),
                      _templateCarousel(theme, isDark),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _toolPanel(theme, isDark),
                  ),
          ),
          _toolbar(theme, isDark),
        ],
      ),
    );
  }

  // ── Onglets catégories (Recommandé / Simple / Classique / Pro) ─────────
  Widget _categoryTabs(ThemeProvider theme, bool isDark) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (var i = 0; i < DemoTemplates.categories.length; i++)
            _tab(
              DemoTemplates.categoryLabel(DemoTemplates.categories[i]),
              i,
              theme,
              isDark,
            ),
        ],
      ),
    );
  }

  Widget _tab(String label, int index, ThemeProvider theme, bool isDark) {
    final active = index == _activeCategory;
    return GestureDetector(
      onTap: () => setState(() => _activeCategory = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? theme.textColor
                    : theme.subTextColor,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: 58,
              decoration: BoxDecoration(
                color: active ? theme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Carrousel de vignettes modèles ─────────────────────────────────────
  Widget _templateCarousel(ThemeProvider theme, bool isDark) {
    final category = DemoTemplates.categories[_activeCategory];
    final templates = DemoTemplates.ofCategory(category);
    return SizedBox(
      height: 128,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        children: [
          for (final t in templates) _thumb(t, theme, isDark),
        ],
      ),
    );
  }

  Widget _thumb(DemoTemplate t, ThemeProvider theme, bool isDark) {
    final selected = _selectedTemplateId == t.id;
    return GestureDetector(
      onTap: () => _applyTemplate(t),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 78,
                  height: 102,
                  decoration: BoxDecoration(
                    color: t.backgroundColor == Colors.white
                        ? (isDark ? Colors.white : Colors.white)
                        : t.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? theme.primaryColor
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.black.withValues(alpha: 0.08)),
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: theme.primaryColor.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Bandeau d'en-tête miniature
                      Container(
                        height: 26,
                        decoration: BoxDecoration(
                          color: t.primaryColor,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Lignes simulées
                      ...List.generate(
                        3,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2.5),
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (t.isPremium)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFFE9B949),
                          Color(0xFFD29B26),
                        ]),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE9B949).withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                if (selected)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Applique la couleur d'un modèle au tap sur sa vignette.
  void _applyTemplate(DemoTemplate t) {
    _apply(_config.copyWith(primaryColor: t.primaryColor));
  }

  // ── Barre d'outils (5 outils) ──────────────────────────────────────────
  Widget _toolbar(ThemeProvider theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < _tools.length; i++) _toolButton(i, theme, isDark),
        ],
      ),
    );
  }

  Widget _toolButton(int index, ThemeProvider theme, bool isDark) {
    final (icon, label) = _tools[index];
    final active = _activeTool == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTool = active ? -1 : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? theme.primaryColor.withValues(alpha: isDark ? 0.24 : 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: active ? theme.primaryColor : theme.subTextColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? theme.primaryColor : theme.subTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Panneau contextuel de l'outil actif ────────────────────────────────
  Widget _toolPanel(ThemeProvider theme, bool isDark) {
    switch (_activeTool) {
      case 0:
        return _panelContainer('Couleur principale', theme, isDark,
            _colorsPanel(theme));
      case 1:
        return _panelContainer('Logo', theme, isDark, _logoPanel(theme));
      case 2:
        return _panelContainer(
            'Taille de police', theme, isDark, _fontsPanel(theme, isDark));
      case 3:
        return _panelContainer('Ombres', theme, isDark, _shadowsPanel(theme));
      case 4:
        return _panelContainer(
            'Signature', theme, isDark, _signaturePanel(theme));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _panelContainer(
      String title, ThemeProvider theme, bool isDark, Widget child) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2433) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: theme.subTextColor,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ── Panneau Couleur ────────────────────────────────────────────────────
  Widget _colorsPanel(ThemeProvider theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final c in _colorPresets) _colorDot(c, theme),
        _themeDot(theme),
      ],
    );
  }

  Widget _colorDot(Color c, ThemeProvider theme) {
    final selected = _config.primaryColor.toARGB32() == c.toARGB32();
    return GestureDetector(
      onTap: () => _apply(_config.copyWith(primaryColor: c)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2.5,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: c.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            : null,
      ),
    );
  }

  /// Puce spéciale « thème de l'app » (dégradé indigo → violet).
  Widget _themeDot(ThemeProvider theme) {
    final selected =
        _config.primaryColor.toARGB32() == theme.primaryColor.toARGB32();
    return GestureDetector(
      onTap: () => _apply(_config.copyWith(primaryColor: theme.primaryColor)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.primaryColor, theme.gradientEndColor],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2.5,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            : const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
      ),
    );
  }

  // ── Panneau Logo ───────────────────────────────────────────────────────
  Widget _logoPanel(ThemeProvider theme) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _config.primaryColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            'NOI',
            style: TextStyle(
              color: _config.primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Afficher le logo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Initiales de l\'entreprise dans l\'en-tête',
                style: TextStyle(
                  fontSize: 11.5,
                  color: theme.subTextColor,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _config.showLogo,
          activeThumbColor: theme.primaryColor,
          activeTrackColor: theme.primaryColor.withValues(alpha: 0.4),
          onChanged: (v) => _apply(_config.copyWith(showLogo: v)),
        ),
      ],
    );
  }

  // ── Panneau Taille de police (S / M / L / XL par section) ──────────────
  Widget _fontsPanel(ThemeProvider theme, bool isDark) {
    return Column(
      children: [
        _fontRow('Titre', FontSizeSection.title, theme, isDark),
        _fontRow('Infos de facture', FontSizeSection.invoiceInfo, theme, isDark),
        _fontRow(
            'Entreprise et client', FontSizeSection.companyClient, theme, isDark),
      ],
    );
  }

  Widget _fontRow(
      String label, FontSizeSection section, ThemeProvider theme, bool isDark) {
    final current = _config.fontSizes[section] ?? FontSizeOption.medium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: isDark ? 0.14 : 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  for (final option in FontSizeOption.values)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _setFont(section, option),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: current == option
                                ? theme.primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: current == option
                                ? [
                                    BoxShadow(
                                      color: theme.primaryColor
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              option.label,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: current == option
                                    ? Colors.white
                                    : theme.subTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setFont(FontSizeSection section, FontSizeOption option) {
    final sizes = Map<FontSizeSection, FontSizeOption>.of(_config.fontSizes);
    sizes[section] = option;
    _apply(_config.copyWith(fontSizes: sizes));
  }

  // ── Panneau Ombres ─────────────────────────────────────────────────────
  Widget _shadowsPanel(ThemeProvider theme) {
    return _switchRow(
      'Ombre portée',
      'Applique une ombre douce sous la facture',
      _config.showShadow,
      theme,
      (v) => _apply(_config.copyWith(showShadow: v)),
    );
  }

  // ── Panneau Signature ──────────────────────────────────────────────────
  Widget _signaturePanel(ThemeProvider theme) {
    return Column(
      children: [
        _switchRow(
          'Signature',
          'Ligne de signature en bas de facture',
          _config.showSignature,
          theme,
          (v) => _apply(_config.copyWith(showSignature: v)),
        ),
        _switchRow(
          'Tampon « PAYÉ »',
          'Tampon doré incliné sur les lignes',
          _config.showPaidStamp,
          theme,
          (v) => _apply(_config.copyWith(showPaidStamp: v)),
        ),
      ],
    );
  }

  Widget _switchRow(
    String label,
    String hint,
    bool value,
    ThemeProvider theme,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.subTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            activeThumbColor: theme.primaryColor,
            activeTrackColor: theme.primaryColor.withValues(alpha: 0.4),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
