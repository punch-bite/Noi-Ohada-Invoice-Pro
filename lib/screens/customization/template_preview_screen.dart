// lib/screens/customization/template_preview_screen.dart
//
// 👁️ APERÇU DU MODÈLE — refonte fidèle à la maquette Stitch
// « design/stitch_refined_billing_interface/aper_u_de_la_facture/code.html »
// (version mobile), adaptée au thème de l'application
// (système / sombre / claire) via `RoyalScheme`.
//
// Structure : header « Détails Facture » · action « SAUVER » · zoom flottant ·
// papier facture (en-tête pointillé secondaire + logo, infos, table,
// totaux, filigrane « PAYÉ ») · barre basse « Éditer / Personnaliser ».

import "dart:math" as math;

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../models/company.dart";
import "../../models/invoice_template.dart";
import "../../services/database_service.dart";
import "../../services/template_custom_service.dart";
import "../../theme/royal_ledger.dart";

class TemplatePreviewScreen extends StatefulWidget {
  final InvoiceTemplate template;

  const TemplatePreviewScreen({super.key, required this.template});

  @override
  State<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends State<TemplatePreviewScreen> {
  final DatabaseService _db = DatabaseService();
  Company? _company;

  /// Paliers de zoom appliqués au bouton flottant (maquette : zoom_in).
  static const List<double> _zoomSteps = [1.0, 1.5, 2.0];
  int _zoomIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final company = await _db.getCompany();
    if (!mounted) return;
    setState(() => _company = company);
  }

  // ------------------------------------------------------ Données société

  String get _companyName {
    final n = _company?.name ?? "";
    return n.isEmpty ? "Noi Concept digital" : n;
  }

  String get _companyAddress {
    final a = _company?.address ?? "";
    return a.isEmpty ? "Dovv Essos Yaoundé Cameroun" : a;
  }

  String get _companyPhone {
    final p = _company?.phone ?? "";
    return p.isEmpty ? "+237620409383" : p;
  }

  String get _companyEmail {
    final e = _company?.email ?? "";
    return e.isEmpty ? "contact@noiconcept.com" : e;
  }

  String get _companyWebsite {
    final w = _company?.website ?? "";
    return w.isEmpty ? "noiconcept.com" : w;
  }

  Future<void> _save() async {
    await TemplateCustomService.saveCustom(
      widget.template.id,
      positions: const {},
      mapping: const {},
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sauvegardé")),
    );
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
            Expanded(
              child: Stack(
                children: [
                  _buildCanvas(c),
                  _saveAction(c),
                  _zoomButton(c),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(c),
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
          140,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.fitWidth,
            child: Transform.scale(
              scale: _zoomSteps[_zoomIndex],
              child: _paper(c),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Papier

  Widget _paper(RoyalScheme c) {
    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(RoyalRadius.sm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RoyalRadius.sm),
        child: Stack(
          children: [
            // Filigrane « PAYÉ » (pivoté, calque absolu — cf. maquette).
            Positioned.fill(
              child: Center(
                child: Transform.rotate(
                  angle: -12 * math.pi / 180,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RoyalSpacing.lg,
                      vertical: RoyalSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceContainerLowest.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(RoyalRadius.def),
                      border: Border.all(color: c.tertiaryFixedDim, width: 4),
                    ),
                    child: Text(
                      "PAYÉ",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 8,
                        color: c.tertiaryFixedDim,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Contenu du document.
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _invoiceHeader(c),
                _invoiceInfo(c),
                const SizedBox(height: RoyalSpacing.md),
                _invoiceTable(c),
                const SizedBox(height: RoyalSpacing.md),
                _invoiceTotals(c),
                const SizedBox(height: RoyalSpacing.lg),
                _invoiceFooter(c),
                const SizedBox(height: RoyalSpacing.md),
                Container(
                    height: 8, color: c.secondary.withValues(alpha: 0.8)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------- Papier : en-tête

  Widget _invoiceHeader(RoyalScheme c) {
    return Container(
      color: c.secondary,
      child: Stack(
        children: [
          // Motif pointillé (maquette : radial-gradient 8px).
          Positioned.fill(
            child: CustomPaint(
              painter: _DotsPatternPainter(
                color: c.onSecondary.withValues(alpha: 0.15),
                step: 8,
                radius: 1.1,
              ),
            ),
          ),
          // Voile dégradé pour la lisibilité (maquette : from-secondary/90
          // via-secondary/70 to-secondary/30).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: const [0, 0.5, 1],
                  colors: [
                    c.secondary.withValues(alpha: 0.95),
                    c.secondary.withValues(alpha: 0.75),
                    c.secondary.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(RoyalSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: c.errorContainer,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c.onSecondary.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "NO!",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: c.onErrorContainer,
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
                        style: RoyalText.labelBold(
                          c.onSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: RoyalSpacing.unit),
                      Text(
                        _companyName,
                        style: RoyalText.headlineMd(c.onSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: RoyalSpacing.unit),
                      _contactText(_companyAddress, c),
                      _contactText(_companyPhone, c),
                      _contactText(_companyEmail, c),
                      _contactText(_companyWebsite, c),
                    ],
                  ),
                ),
                const SizedBox(width: RoyalSpacing.unit),
                Text(
                  "FACTURE",
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: c.onSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactText(String s, RoyalScheme c) {
    return Text(
      s,
      style: RoyalText.labelSm(c.onSecondary.withValues(alpha: 0.9)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ------------------------------------------------- Papier : infos & table

  Widget _invoiceInfo(RoyalScheme c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RoyalSpacing.lg,
        RoyalSpacing.md,
        RoyalSpacing.lg,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "FACTURÉ À",
                  style: RoyalText.labelBold(c.onSurfaceVariant),
                ),
                const SizedBox(height: RoyalSpacing.sm),
                Text("-", style: RoyalText.bodyMd(c.onSurface)),
              ],
            ),
          ),
          const SizedBox(width: RoyalSpacing.gutter),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _infoRow(c, "Facture N°", "INV000342"),
              _infoRow(c, "Date", "26/03/2025"),
              _infoRow(c, "Échéance", "02/04/2025"),
              _infoRow(c, "Devise", "XAF"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(RoyalScheme c, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: RoyalText.labelBold(c.onSurfaceVariant),
          ),
          const SizedBox(width: RoyalSpacing.gutter),
          SizedBox(
            width: 76,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: RoyalText.labelSm(c.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceTable(RoyalScheme c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RoyalSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: RoyalSpacing.gutter,
              vertical: RoyalSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: c.secondary.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(RoyalRadius.sm),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: _th(c, "Description")),
                SizedBox(width: 48, child: _th(c, "Qté", TextAlign.center)),
                SizedBox(width: 72, child: _th(c, "Prix", TextAlign.right)),
                SizedBox(
                    width: 72, child: _th(c, "Montant", TextAlign.right)),
              ],
            ),
          ),
          Container(
            height: 64,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(RoyalRadius.sm),
              ),
              border: Border(
                left: BorderSide(
                  color: c.outlineVariant.withValues(alpha: 0.3),
                ),
                right: BorderSide(
                  color: c.outlineVariant.withValues(alpha: 0.3),
                ),
                bottom: BorderSide(
                  color: c.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                _cellDivider(c, 48),
                _cellDivider(c, 72),
                _cellDivider(c, 72),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _th(RoyalScheme c, String text, [TextAlign align = TextAlign.left]) {
    return Text(
      text.toUpperCase(),
      textAlign: align,
      style: RoyalText.labelBold(c.onSecondary),
    );
  }

  Widget _cellDivider(RoyalScheme c, double width) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: c.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

  // --------------------------------------------- Papier : totaux & footer

  Widget _invoiceTotals(RoyalScheme c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RoyalSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 200,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: RoyalSpacing.gutter),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Sous-Total",
                      style: RoyalText.labelBold(c.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Fr0",
                    style: RoyalText.bodyMd(c.onSurface)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RoyalSpacing.sm),
          Container(
            width: 200,
            padding: const EdgeInsets.symmetric(
              horizontal: RoyalSpacing.gutter,
              vertical: RoyalSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: c.secondary.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(RoyalRadius.sm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "MONTANT TOTAL",
                    style: RoyalText.labelBold(c.onSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Fr0",
                  style: RoyalText.bodyMd(c.onSecondary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceFooter(RoyalScheme c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RoyalSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Termes et conditions",
            style: RoyalText.labelBold(c.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            "Merci pour votre confiance.",
            style:
                RoyalText.labelSm(c.onSurfaceVariant.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------- Overlays flottants

  Widget _saveAction(RoyalScheme c) {
    return Positioned(
      top: 8,
      right: RoyalSpacing.containerPadding,
      child: GestureDetector(
        onTap: _save,
        child: Text(
          "SAUVER",
          style: RoyalText.labelBold(c.secondary)
              .copyWith(letterSpacing: 1, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _zoomButton(RoyalScheme c) {
    return Positioned(
      top: 44,
      right: RoyalSpacing.md,
      child: GestureDetector(
        onTap: () =>
            setState(() => _zoomIndex = (_zoomIndex + 1) % _zoomSteps.length),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.surfaceContainerLowest.withValues(alpha: 0.6),
            shape: BoxShape.circle,
            border: Border.all(
              color: c.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            _zoomIndex == 0 ? Icons.zoom_in : Icons.zoom_out,
            size: 22,
            color: c.onSurface,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Barre basse

  Widget _buildBottomBar(RoyalScheme c) {
    return Container(
      decoration: BoxDecoration(
        color: c.inverseSurface.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: c.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 84,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomAction(
                c,
                Icons.edit_outlined,
                "Éditer",
                () => context.push(
                  "/templates/workspace",
                  extra: widget.template,
                ),
              ),
              _bottomAction(
                c,
                Icons.palette_outlined,
                "Personnaliser",
                () => context.push(
                  "/templates/workspace",
                  extra: widget.template,
                ),
                hasDot: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomAction(
    RoyalScheme c,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool hasDot = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surface.withValues(alpha: 0.05),
                  border: Border.all(
                    color: c.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(icon, size: 22, color: c.inverseOnSurface),
              ),
              if (hasDot)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.tertiaryFixed,
                      boxShadow: [
                        BoxShadow(
                          color: c.tertiaryFixed.withValues(alpha: 0.8),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: RoyalText.bodyMd(c.inverseOnSurface)),
        ],
      ),
    );
  }
}

/// Motif pointillé décoratif (en-tête du papier facture — cf. maquette).
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