// lib/screens/customization/template_store_screen.dart
//
// 🛍️ BOUTIQUE DE MODÈLES — refonte fidèle à la maquette Stitch
// « design/stitch_refined_billing_interface/boutique_de_mod_les/code.html »
// (version mobile), adaptée au thème de l'application
// (système / sombre / claire) via `RoyalScheme`.
//
// Structure (identique à la maquette) :
//   • Header : retour + logo « Facture Pro » + « Modèles » + avatar ;
//   • Zone collante : recherche + pills de catégories (+ « Pro Uniquement ») ;
//   • Grille 2 colonnes — cartes ratio 1/1.4, badge « PRO », nom + statut ;
//   • Bouton « Charger plus de modèles » (pagination locale) ;
//   • Barre de navigation basse : Accueil · Modèles · Factures · Paramètres.

import "dart:math" show min;

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../models/invoice_template.dart";
import "../../services/database_service.dart";
import "../../theme/royal_ledger.dart";

class TemplateStoreScreen extends StatefulWidget {
  const TemplateStoreScreen({super.key});

  @override
  State<TemplateStoreScreen> createState() => _TemplateStoreScreenState();
}

class _TemplateStoreScreenState extends State<TemplateStoreScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<InvoiceTemplate> _templates = [];
  bool _isLoading = true;

  String _selectedCategory = "Tous";
  bool _proOnly = false;
  int _visibleCount = 6;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    final templates = await _db.getTemplates();
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _isLoading = false;
    });
  }

  // --------------------------------------------------------------- Helpers

  bool _isPro(InvoiceTemplate t) => t.price > 0 || t.isPremium;

  List<InvoiceTemplate> get _filtered {
    var list = _templates;
    if (_selectedCategory != "Tous") {
      list = list.where((t) => t.category == _selectedCategory).toList();
    }
    if (_proOnly) list = list.where(_isPro).toList();
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((t) => t.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  /// Pills de catégories : liste de référence du modèle + celles des données.
  List<String> get _pillCategories {
    final cats = <String>["Tous"];
    for (final c in InvoiceTemplate.categories) {
      if (!cats.contains(c)) cats.add(c);
    }
    for (final t in _templates) {
      if (t.category.isNotEmpty && !cats.contains(t.category)) {
        cats.add(t.category);
      }
    }
    return cats;
  }

  static Color _onColor(Color bg) => bg.computeLuminance() > 0.5
      ? const Color(0xFF1E1A1F)
      : Colors.white;

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
            _buildSearchArea(c),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: c.primary))
                  : _buildContent(c),
            ),
            _buildBottomNav(c),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Header

  Widget _buildHeader(RoyalScheme c) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(
        horizontal: RoyalSpacing.containerPadding,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(true),
            icon: Icon(Icons.arrow_back_ios_new, size: 18, color: c.onSurface),
            tooltip: "Retour",
          ),
          const SizedBox(width: 4),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long, size: 20, color: c.onPrimary),
          ),
          const SizedBox(width: 10),
          Text("Facture Pro", style: RoyalText.headlineMd(c.primary)),
          const Spacer(),
          Text("Modèles", style: RoyalText.bodyMd(c.onSurface)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => context.push("/dashboard/profile"),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, size: 18, color: c.onPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------- Recherche & pills

  Widget _buildSearchArea(RoyalScheme c) {
    return Container(
      padding: const EdgeInsets.only(
        top: RoyalSpacing.unit,
        bottom: RoyalSpacing.md,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.surfaceVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RoyalSpacing.containerPadding,
            ),
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                style: RoyalText.bodyMd(c.onSurface),
                cursorColor: c.primary,
                decoration: InputDecoration(
                  hintText: "Rechercher un modèle...",
                  hintStyle: RoyalText.bodyMd(c.onSurfaceVariant),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: c.onSurfaceVariant,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: c.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RoyalRadius.def),
                    borderSide: BorderSide(color: c.surfaceVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RoyalRadius.def),
                    borderSide: BorderSide(color: c.primary, width: 2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: RoyalSpacing.md),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: RoyalSpacing.containerPadding,
              ),
              itemCount: _pillCategories.length + 1,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: RoyalSpacing.gutter),
              itemBuilder: (context, i) {
                if (i == _pillCategories.length) return _proPill(c);
                return _categoryPill(c, _pillCategories[i]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryPill(RoyalScheme c, String label) {
    final active = _selectedCategory == label && !_proOnly;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedCategory = label;
        _proOnly = false;
        _visibleCount = 6;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.primary : c.surfaceContainer,
          borderRadius: BorderRadius.circular(RoyalRadius.full),
          border: Border.all(color: active ? c.primary : c.outlineVariant),
        ),
        child: Text(
          label,
          style: RoyalText.labelBold(active ? c.onPrimary : c.onSurface),
        ),
      ),
    );
  }

  Widget _proPill(RoyalScheme c) {
    final active = _proOnly;
    return GestureDetector(
      onTap: () => setState(() {
        _proOnly = !_proOnly;
        _visibleCount = 6;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.tertiary : c.tertiaryContainer,
          borderRadius: BorderRadius.circular(RoyalRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              size: 14,
              color: active ? c.onTertiary : c.onTertiaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              "Pro Uniquement",
              style: RoyalText.labelBold(
                active ? c.onTertiary : c.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Grille

  Widget _buildContent(RoyalScheme c) {
    final filtered = _filtered;
    if (filtered.isEmpty) return _buildEmpty(c);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth =
            (width - RoyalSpacing.containerPadding * 2 - RoyalSpacing.gutter) /
                2;
        const labelHeight = 26.0;
        final itemHeight = itemWidth * 1.4 + labelHeight;
        final shown = min(_visibleCount, filtered.length);

        return SingleChildScrollView(
          child: Column(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(RoyalSpacing.containerPadding),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: RoyalSpacing.gutter,
                  mainAxisSpacing: RoyalSpacing.md,
                  childAspectRatio: itemWidth / itemHeight,
                ),
                itemCount: shown,
                itemBuilder: (context, i) =>
                    _templateCard(c, filtered[i], isDark),
              ),
              if (filtered.length > shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: RoyalSpacing.lg),
                  child: GestureDetector(
                    onTap: () => setState(() => _visibleCount += 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceContainer,
                        borderRadius: BorderRadius.circular(RoyalRadius.full),
                      ),
                      child: Text(
                        "Charger plus de modèles",
                        style: RoyalText.labelBold(c.onSurface),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _templateCard(RoyalScheme c, InvoiceTemplate t, bool isDark) {
    final pro = _isPro(t);
    return GestureDetector(
      onTap: () => context.push("/templates/preview", extra: t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1 / 1.4,
            child: Container(
              decoration: BoxDecoration(
                color: c.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(RoyalRadius.def),
                border: Border.all(color: c.outlineVariant),
                boxShadow: RoyalShadows.card(isDark),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(RoyalRadius.def - 1),
                child: Stack(
                  children: [
                    Positioned.fill(child: _miniPreview(t)),
                    if (pro)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: c.tertiary,
                            borderRadius:
                                BorderRadius.circular(RoyalRadius.sm),
                          ),
                          child: Text(
                            "PRO",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: c.onTertiary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RoyalText.labelBold(c.onSurface),
                ),
              ),
              if (!pro)
                Text("Gratuit", style: RoyalText.labelSm(c.onSurfaceVariant))
              else
                Icon(Icons.verified, size: 16, color: c.tertiary),
            ],
          ),
        ],
      ),
    );
  }

  /// Aperçu miniature dessiné (pas d'asset image) aux couleurs du modèle.
  Widget _miniPreview(InvoiceTemplate t) {
    final bandFg = _onColor(t.primaryColor);
    final paperFg = t.textColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 28,
          child: Container(
            color: t.primaryColor,
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bandFg.withValues(alpha: 0.35),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "FACTURE",
                      style: TextStyle(
                        fontSize: 6,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: bandFg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: 44,
                  height: 3,
                  color: bandFg.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 72,
          child: Container(
            color: t.backgroundColor,
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 3,
                  width: double.infinity,
                  color: paperFg.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 3),
                FractionallySizedBox(
                  widthFactor: 0.6,
                  child: Container(
                    height: 3,
                    color: paperFg.withValues(alpha: 0.15),
                  ),
                ),
                const Spacer(),
                Container(
                  height: 5,
                  width: double.infinity,
                  color: t.primaryColor.withValues(alpha: 0.18),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 3,
                  width: double.infinity,
                  color: paperFg.withValues(alpha: 0.10),
                ),
                const SizedBox(height: 3),
                FractionallySizedBox(
                  widthFactor: 0.75,
                  child: Container(
                    height: 3,
                    color: paperFg.withValues(alpha: 0.10),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(height: 4, color: t.primaryColor),
      ],
    );
  }

  // ------------------------------------------------------------ État vide

  Widget _buildEmpty(RoyalScheme c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off, size: 28, color: c.onSurfaceVariant),
          ),
          const SizedBox(height: RoyalSpacing.md),
          Text(
            "Aucun modèle trouvé",
            style: RoyalText.bodyLg(c.onSurface)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: RoyalSpacing.unit),
          Text(
            "Essayez une autre recherche ou catégorie.",
            style: RoyalText.labelSm(c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Bottom nav

  Widget _buildBottomNav(RoyalScheme c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: c.outlineVariant.withValues(alpha: 0.4)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                c,
                Icons.home,
                "Accueil",
                false,
                onTap: () => context.go("/dashboard"),
              ),
              _navItem(c, Icons.description, "Modèles", true),
              _navItem(
                c,
                Icons.receipt_long,
                "Factures",
                false,
                onTap: () => context.go("/dashboard/invoices"),
              ),
              _navItem(
                c,
                Icons.settings,
                "Paramètres",
                false,
                onTap: () => context.go("/dashboard/settings"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    RoyalScheme c,
    IconData icon,
    String label,
    bool active, {
    VoidCallback? onTap,
  }) {
    final color = active ? c.secondary : c.onSurfaceVariant;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'WorkSans',
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}