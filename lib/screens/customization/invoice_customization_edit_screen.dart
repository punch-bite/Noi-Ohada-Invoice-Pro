// lib/screens/customization/invoice_customization_edit_screen.dart
//
// 🛠️ Écran Personnaliser (refonte maquette) :
//   - Preview de la facture en haut (InvoicePreviewWidget).
//   - Panneau d'onglets collant en bas :
//       Modèles | Couleur | Logo | Taille de police | Ombres | Signature | Tampon
//   - Bouton «Aperçu» pour ouvrir l'écran plein écran.
//
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/customization_config.dart';
import '../../providers/theme_provider.dart';
import '../../services/customization_service.dart';
import '../../widgets/invoice_preview_widget.dart';

class InvoiceCustomizationEditScreen extends StatefulWidget {
  final CustomizationConfig? config;

  const InvoiceCustomizationEditScreen({super.key, this.config});

  @override
  State<InvoiceCustomizationEditScreen> createState() =>
      _InvoiceCustomizationEditState();
}

class _InvoiceCustomizationEditState
    extends State<InvoiceCustomizationEditScreen> {
  late CustomizationConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config ?? CustomizationConfig.defaults;
    if (widget.config == null) {
      // Charger l'état persistant au premier affichage.
      CustomizationService.instance.load().then((saved) {
        if (mounted) setState(() => _config = saved);
      });
    }
  }

  void _update(CustomizationConfig next) {
    setState(() => _config = next);
    CustomizationService.instance.save(next);
  }

  void _openPreview() {
    context.push('/templates/apropos/preview', extra: {'config': _config});
  }

  Widget _buildTopBar(ThemeProvider theme) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: theme.textColor, size: 20),
            onPressed: () => context.pop(),
          ),
          Icon(Icons.palette_outlined,
              color: theme.primaryColor, size: 22),
          const SizedBox(width: 8),
          Text(
            'Personnaliser',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _openPreview,
            icon: Icon(Icons.visibility_outlined,
                color: theme.primaryColor, size: 18),
            label: const Text('Aperçu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Column(
        children: [
          _buildTopBar(theme),
          // ── Preview en haut ─
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: InvoicePreviewWidget(
                  config: _config,
                  showShadow: _config.showShadow,
                ),
              ),
            ),
          ),
          // ── Panneau d'onglets bas ─
          _buildBottomPanel(),
        ],
      ),
    );
  }
  Widget _buildBottomPanel() {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final card = theme.cardColor;
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: card,
        border: Border(top: BorderSide(color: theme.dividerColor)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: theme.subTextColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          _buildTabs(theme),
          Expanded(
            child: _buildTabContent(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  final List<_TabItem> _tabs = [
    _TabItem('Modèles', Icons.grid_view_outlined),
    _TabItem('Couleur', Icons.palette_outlined),
    _TabItem('Logo', Icons.image_outlined),
    _TabItem('Police', Icons.text_format_outlined),
    _TabItem('Ombres', Icons.blur_on),
    _TabItem('Signature', Icons.draw_outlined),
    _TabItem('Tampon', Icons.verified_outlined),
  ];

  int _selectedTab = 0;

  Widget _buildTabs(ThemeProvider theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final selected = _selectedTab == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedTab = i),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? theme.primaryColor.withValues(alpha: 0.12)
                    : theme.dividerColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? theme.primaryColor
                      : theme.dividerColor,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _tabs[i].icon,
                    size: 16,
                    color: selected
                        ? theme.primaryColor
                        : theme.textColor.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _tabs[i].label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? theme.primaryColor
                          : theme.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

    Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildModelsTab();
      case 1:
        return _buildColorTab();
      case 2:
        return _buildLogoTab();
      case 3:
        return _buildFontTab();
      case 4:
        return _buildShadowTab();
      case 5:
        return _buildSignatureTab();
      case 6:
        return _buildStampTab();
            default:
        return const SizedBox.shrink();
    }
  }

  // ─── ONGLET : MODÈLES ──────────────────────────────────────────────
  String _selectedCategory = 'recommended';

  Widget _buildModelsTab() {
    final theme = context.watch<ThemeProvider>();
    final models = DemoTemplates.ofCategory(_selectedCategory);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: DemoTemplates.categories.map((cat) {
              final selected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedCategory = cat),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.primaryColor
                        : theme.dividerColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DemoTemplates.categoryLabel(cat),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : theme.textColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3.4,
            ),
            itemCount: models.length,
            itemBuilder: (context, i) => _DemoTemplateTile(
              template: models[i],
              isSelected: _config.primaryColor == models[i].primaryColor,
              onTap: () => _selectDemoTemplate(models[i]),
            ),
          ),
        ),
      ],
    );
  }

  void _selectDemoTemplate(DemoTemplate dt) {
    setState(() {
      _config = _config.copyWith(primaryColor: dt.primaryColor);
    });
        CustomizationService.instance.save(_config);
  }

  // ─── ONGLET : COULEUR ───────────────────────────────────────────────
  static const List<Color> _presetColors = [
    Color(0xFF1A237E), Color(0xFF4338CA), Color(0xFF4CAF50),
    Color(0xFF00695C), Color(0xFF009688), Color(0xFF0D47A1),
    Colors.black,
    Color(0xFF8E24AA), Color(0xFFE91E63), Color(0xFFD84315),
  ];

  Widget _buildColorTab() {
    final theme = context.watch<ThemeProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Palette principale',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor)),
          const SizedBox(height: 6),
          Text('Choisissez la couleur dominante de votre facture',
              style: TextStyle(fontSize: 11, color: theme.subTextColor)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _presetColors.map((c) {
              final selected =
                  c.toARGB32() == _config.primaryColor.toARGB32();
              return GestureDetector(
                onTap: () => _update(_config.copyWith(primaryColor: c)),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.9)
                          : theme.dividerColor,
                      width: selected ? 2.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: c.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                                    child: selected
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── ONGLET : LOGO ──────────────────────────────────────────────────
  Widget _buildLogoTab() {
    final theme = context.watch<ThemeProvider>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: theme.isDarkMode
                  ? const Color(0xFF2A2F3D)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.add_a_photo_outlined,
                size: 34, color: theme.subTextColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Importer votre logo',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Format PNG/JPG recommandé',
            style: TextStyle(fontSize: 11, color: theme.subTextColor),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            value: _config.showLogo,
            onChanged: (v) => _update(_config.copyWith(showLogo: v)),
            title: const Text('Afficher le logo'),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24),
          ),
        ]),
      ),
    );
  }

  // ─── ONGLET : TAILLE DE POLICE ─────────────────────────────────────
  Widget _buildFontTab() {
    final theme = context.watch<ThemeProvider>();
    const sections = [
      (FontSizeSection.title, 'Titre'),
      (FontSizeSection.invoiceInfo, 'Infos de facture'),
      (FontSizeSection.companyClient, 'Entreprise & client'),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Police d\'écriture',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor)),
          const SizedBox(height: 8),
          _fontDropdown(theme),
          const SizedBox(height: 24),
          Text('Taille de police',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor)),
          const SizedBox(height: 8),
          ...sections.map((s) => _fontSizeSelector(
              theme, s.$1, s.$2, _config.fontSizes[s.$1])),
        ],
      ),
    );
  }

  Widget _fontDropdown(ThemeProvider theme) {
    const fonts = ['Roboto', 'Inter', 'Lato', 'Montserrat', 'Open Sans'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _config.fontFamily,
          items: fonts
              .map((f) => DropdownMenuItem(
                  value: f,
                  child: Text(f,
                      style: TextStyle(color: theme.textColor))))
              .toList(),
          onChanged: (v) =>
              _update(_config.copyWith(
                  fontFamily: v ?? _config.fontFamily)),
          icon: Icon(Icons.arrow_drop_down, color: theme.subTextColor),
        ),
      ),
    );
  }

  Widget _fontSizeSelector(ThemeProvider theme, FontSizeSection section,
      String label, FontSizeOption? current) {
    const options = FontSizeOption.values;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor.withValues(alpha: 0.85))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: options.map((o) {
              final selected = current == o;
              return GestureDetector(
                onTap: () {
                  final next = Map<FontSizeSection, FontSizeOption>.of(
                      _config.fontSizes)
                    ..[section] = o;
                  _update(_config.copyWith(fontSizes: next));
                },
                child: Container(
                  width: 46,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.primaryColor
                        : theme.dividerColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected
                            ? theme.primaryColor
                            : theme.dividerColor),
                  ),
                                    child: Text(o.label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : theme.textColor)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── ONGLET : OMBRES ────────────────────────────────────────────────
  Widget _buildShadowTab() {
    final theme = context.watch<ThemeProvider>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: SwitchListTile(
          value: _config.showShadow,
          activeThumbColor: theme.primaryColor,
          onChanged: (v) => _update(_config.copyWith(showShadow: v)),
          title: const Text('Ombre portée'),
          subtitle: Text('Ombre douce autour de la facture',
              style: TextStyle(fontSize: 11, color: theme.subTextColor)),
          secondary: const Icon(Icons.blur_on),
        ),
      ),
    );
  }

  // ─── ONGLET : SIGNATURE ─────────────────────────────────────────────
  Widget _buildSignatureTab() {
    final theme = context.watch<ThemeProvider>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: SwitchListTile(
          value: _config.showSignature,
          activeThumbColor: theme.primaryColor,
          onChanged: (v) => _update(_config.copyWith(showSignature: v)),
          title: const Text('Signature'),
          subtitle: Text('Ligne de signature en bas de facture',
              style: TextStyle(fontSize: 11, color: theme.subTextColor)),
          secondary: const Icon(Icons.draw_outlined),
        ),
      ),
    );
  }

  // ─── ONGLET : TAMPON PAYÉ ──────────────────────────────────────────
  Widget _buildStampTab() {
    final theme = context.watch<ThemeProvider>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: SwitchListTile(
          value: _config.showPaidStamp,
          activeThumbColor: Colors.green,
          onChanged: (v) => _update(_config.copyWith(showPaidStamp: v)),
          title: const Text('Tampon PAYÉ'),
          subtitle: Text('Affiche le sceau "PAYÉ" sur la facture',
              style: TextStyle(fontSize: 11, color: theme.subTextColor)),
          secondary: const Icon(Icons.verified_outlined),
        ),
      ),
    );
  }
}

// ─── TILE : vignette d'un modèle de démonstration ───────────────────
class _DemoTemplateTile extends StatelessWidget {
  final DemoTemplate template;
  final VoidCallback onTap;
  final bool isSelected;

  const _DemoTemplateTile({
    required this.template,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: template.backgroundColor ?? theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.primaryColor
                    : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: template.primaryColor.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.description_outlined,
                          color: template.primaryColor, size: 18),
                    ),
                  ),
                ),
                Expanded(
                  flex: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(template.name,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.textColor)),
                      Text(template.description,
                          style: TextStyle(
                              fontSize: 10, color: theme.subTextColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (template.isPremium)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.star,
                    size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  const _TabItem(this.label, this.icon);
}




