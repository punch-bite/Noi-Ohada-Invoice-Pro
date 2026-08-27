// lib/screens/customization/template_preview_screen.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/invoice_template.dart';
import '../../models/invoice_settings.dart';
import '../../models/company.dart';
import '../../services/database_service.dart';
import '../../services/template_cart.dart';
import '../../services/template_custom_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/logo_image.dart';

class TemplatePreviewScreen extends StatefulWidget {
  final InvoiceTemplate template;
  final InvoiceSettings? settings;

  const TemplatePreviewScreen({
    super.key,
    required this.template,
    this.settings,
  });

  @override
  State<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends State<TemplatePreviewScreen> {
  final DatabaseService _db = DatabaseService();
  Company? _company;
  late InvoiceSettings _settings;
  bool _isLoading = true;
  // 🖼️ Image téléversée du modèle : arrière-plan de l'aperçu.
  Uint8List? _backgroundBytes;
  // 🧩 Positions personnalisées (drag & drop) → l'aperçu reflète
  // les modifications faites dans l'espace de travail.
  Map<String, dynamic> _customPositions = {};
  // 🧩 Mapping personnalisé (élément → variable de facture) → l'aperçu
  // respecte les réassignations faites dans l'espace de travail.
  Map<String, String> _customMapping = {};

  // ─── Aperçu zoomable (page A4 + règles graduées) ─────────────────────
  // Taille de la page A4 de l'aperçu (420 px ↔ 210 mm) et de ses règles.
  static const double _pageW = 420.0;
  static const double _pageH = 594.0; // 420 × 297/210
  static const double _rulerSize = 26.0;
  static const double _contentW = _pageW + _rulerSize; // 446
  static const double _contentH = _pageH + _rulerSize; // 620

  // Le contenu est toujours dessiné à sa taille réelle puis mis à l'échelle
  // (pinch / boutons) → il ne déborde JAMAIS, quel que soit l'écran.
  double _zoom = 1.0; // multiplicateur au-delà de l'échelle d'ajustement
  double _fitScale = 1.0; // échelle qui fait tenir page + règles à l'écran
  Offset _pan = Offset.zero;
  Size _viewport = Size.zero;
  bool _zoomInitialized = false;
  // État de départ du geste (pinch / glisser).
  double _gestureStartZoom = 1.0;
  Offset _gestureStartPan = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  /// Échelle d'affichage réelle = ajustement à l'écran × zoom utilisateur.
  double get _displayScale => _fitScale * _zoom;

  /// Positions effectives à utiliser : les personnalisations locales si
  /// présentes, sinon les positions par défaut du modèle. Si les deux sont
  /// vides → layout fixe historique (non positionné).
  Map<String, dynamic> get _positions =>
      _customPositions.isNotEmpty
          ? _customPositions
          : Map<String, dynamic>.from(widget.template.positions);

  // Note: settings are stored in `_settings`. Template default values are
  // accessed via `widget.template` where needed. No extra getters required.

  @override
  void initState() {
    super.initState();
    _settings = widget.settings ?? InvoiceSettings.defaultSettings;
    _loadData();
  }

  Future<void> _loadData() async {
    final company = await _db.getCompany();
    // Charge les personnalisations (positions + mapping) du modèle pour
    // que l'aperçu affiche exactement ce qui a été configuré en drag & drop.
    final custom = await TemplateCustomService.loadCustom(widget.template.id);

    if (mounted) {
      setState(() {
        _company = company;
        _backgroundBytes = _decodeBackground();
        _customPositions = custom.positions;
        _customMapping = custom.mapping;
        _settings = widget.settings ?? InvoiceSettings.defaultSettings;
        _isLoading = false;
      });
    }
  }

  /// Décode l'image téléversée du modèle (base64) pour l'utiliser en arrière-plan.
  Uint8List? _decodeBackground() {
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

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final bg = isDark ? Colors.grey[950] : Colors.grey[100];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          'Aperçu - ${widget.template.name}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.check_circle_outline, color: _settings.primaryColor, size: 26),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Modèle configuré avec succès'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildZoomToolbar(theme),
                Expanded(
                  child: _buildZoomablePreview(theme),
                ),
                // Boutons d'action sous l'aperçu (prix, panier, personnaliser).
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141417) : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: _buildActionButtons(theme),
                  ),
                ),
              ],
            ),
    );
  }

  // ============================================================
  //  BARRE DE ZOOM (avant/arrière, % réel, ajuster, 100 %)
  // ============================================================
  Widget _buildZoomToolbar(ThemeProvider theme) {
    final dark = theme.isDarkMode;
    final boxColor = dark ? const Color(0xFF1E1E22) : Colors.white;
    final borderColor =
        dark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);
    final textColor = dark ? Colors.white70 : Colors.black54;
    final percent = (_displayScale * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: boxColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _zoomButton(
                  Icons.remove,
                  'Zoom arrière',
                  textColor,
                  () => _zoomBy(0.8),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 62),
                  alignment: Alignment.center,
                  child: Text(
                    '$percent %',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                _zoomButton(
                  Icons.add,
                  'Zoom avant',
                  textColor,
                  () => _zoomBy(1.25),
                ),
                Container(width: 1, height: 18, color: borderColor),
                _zoomButton(
                  Icons.fit_screen_outlined,
                  'Ajuster à l\'écran',
                  textColor,
                  _zoomToFit,
                ),
                _zoomButton(
                  Icons.aspect_ratio,
                  'Taille réelle (100 %)',
                  textColor,
                  _zoomTo100,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: boxColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Tooltip(
              message: 'Pincez pour zoomer • Glissez pour déplacer',
              child: Icon(Icons.touch_app_outlined, size: 18, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoomButton(
    IconData icon,
    String tooltip,
    Color color,
    VoidCallback onTap,
  ) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 36),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 20, color: color),
      onPressed: onTap,
    );
  }

  // ============================================================
  //  APERÇU ZOOMABLE : toile quadrillée + page A4 + règles graduées.
  //  Le contenu est dessiné à sa taille réelle puis mis à l'échelle
  //  (pinch / boutons / double-tap) → il ne déborde jamais de l'écran.
  // ============================================================
  Widget _buildZoomablePreview(ThemeProvider theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availW = constraints.maxWidth;
        final availH = constraints.maxHeight;
        if (availW > 0 && availH > 0) {
          // L'échelle d'ajustement suit la taille de la zone (rotation...).
          _fitScale = min(
            (availW - 16) / _contentW,
            (availH - 16) / _contentH,
          );
          if (!_zoomInitialized) {
            _zoomInitialized = true;
            _zoom = 1.0;
            _pan = Offset.zero;
          }
          _viewport = Size(availW, availH);
        }

        return ClipRect(
          child: GestureDetector(
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onDoubleTap: _onDoubleTap,
            child: Stack(
              children: [
                // Toile de design : fond quadrillé discret.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DotGridPainter(
                      color: (theme.isDarkMode ? Colors.white : Colors.black)
                          .withValues(alpha: theme.isDarkMode ? 0.05 : 0.045),
                    ),
                  ),
                ),
                // Page + règles, centrées, mises à l'échelle et déplaçables.
                Positioned(
                  left: (availW - _contentW) / 2 + _pan.dx,
                  top: (availH - _contentH) / 2 + _pan.dy,
                  child: Transform.scale(
                    scale: _displayScale,
                    child: SizedBox(
                      width: _contentW,
                      height: _contentH,
                      child: Stack(
                        children: [
                          // Coin (A4).
                          Positioned(
                            left: 0,
                            top: 0,
                            child: _buildCornerBox(theme),
                          ),
                          // Règle horizontale (au-dessus de la page).
                          Positioned(
                            left: _rulerSize,
                            top: 0,
                            child: _buildHRuler(theme),
                          ),
                          // Règle verticale (à gauche de la page).
                          Positioned(
                            left: 0,
                            top: _rulerSize,
                            child: _buildVRuler(theme),
                          ),
                          // Page A4.
                          Positioned(
                            left: _rulerSize,
                            top: _rulerSize,
                            child: _buildPageCard(theme),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Gestion du geste (pinch / glisser / double-tap) ---

  void _onScaleStart(ScaleStartDetails d) {
    _gestureStartZoom = _zoom;
    _gestureStartPan = _pan;
    _gestureStartFocal = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _zoom = (_gestureStartZoom * d.scale).clamp(0.4, 5.0);
      _pan = _gestureStartPan + (d.focalPoint - _gestureStartFocal);
      _clampPan();
    });
  }

  void _onDoubleTap() {
    setState(() {
      if (_zoom > 1.05) {
        _zoom = 1.0;
        _pan = Offset.zero;
      } else {
        _zoom = 2.0;
        _clampPan();
      }
    });
  }

  /// Borne le déplacement pour que la page reste accessible à l'écran.
  void _clampPan() {
    final vp = _viewport;
    if (vp.isEmpty) return;
    final scaledW = _contentW * _displayScale;
    final scaledH = _contentH * _displayScale;
    final maxDx = max(0.0, (scaledW - vp.width) / 2) + 100;
    final maxDy = max(0.0, (scaledH - vp.height) / 2) + 100;
    _pan = Offset(_pan.dx.clamp(-maxDx, maxDx), _pan.dy.clamp(-maxDy, maxDy));
  }

  // --- Boutons de zoom ---

  void _zoomBy(double factor) {
    setState(() {
      _zoom = (_zoom * factor).clamp(0.4, 5.0);
      _clampPan();
    });
  }

  void _zoomToFit() {
    setState(() {
      _zoom = 1.0;
      _pan = Offset.zero;
    });
  }

  void _zoomTo100() {
    setState(() {
      if (_fitScale > 0) _zoom = (1.0 / _fitScale).clamp(0.4, 5.0);
      _clampPan();
    });
  }

  // ============================================================
  //  RÈGLES GRADUÉES + COIN (mesures stylisées)
  // ============================================================

  Widget _buildCornerBox(ThemeProvider theme) {
    final dark = theme.isDarkMode;
    return Container(
      width: _rulerSize,
      height: _rulerSize,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E1E22) : Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(10)),
        border: Border.all(
          color: dark ? Colors.white12 : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'A4',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: dark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  Widget _buildHRuler(ThemeProvider theme) {
    final dark = theme.isDarkMode;
    return Container(
      width: _pageW,
      height: _rulerSize,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E1E22) : Colors.white,
        borderRadius: const BorderRadius.only(topRight: Radius.circular(10)),
        border: Border.all(
          color: dark ? Colors.white12 : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: CustomPaint(
        painter: _RulerPainter(
          vertical: false,
          pxPerMm: 2.0, // 420 px ↔ 210 mm
          tickColor: dark ? Colors.white38 : Colors.black38,
          labelColor: dark ? Colors.white70 : Colors.black54,
          rulerSize: _rulerSize,
        ),
      ),
    );
  }

  Widget _buildVRuler(ThemeProvider theme) {
    final dark = theme.isDarkMode;
    return Container(
      width: _rulerSize,
      height: _pageH,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E1E22) : Colors.white,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10)),
        border: Border.all(
          color: dark ? Colors.white12 : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: CustomPaint(
        painter: _RulerPainter(
          vertical: true,
          pxPerMm: 2.0, // même échelle que la largeur
          tickColor: dark ? Colors.white38 : Colors.black38,
          labelColor: dark ? Colors.white70 : Colors.black54,
          rulerSize: _rulerSize,
        ),
      ),
    );
  }

  // ============================================================
  //  CARTE DE LA PAGE A4 (fond, filigrane, layout positionné ou fixe)
  // ============================================================
  Widget _buildPageCard(ThemeProvider theme) {
    final isDark = theme.isDarkMode;
    return Container(
      width: _pageW,
      height: _pageH,
      decoration: BoxDecoration(
        color: _settings.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: _settings.showBorder
            ? Border.all(
                color: _settings.primaryColor.withValues(alpha: 0.35),
                width: 1.5,
              )
            : Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            if (_backgroundBytes != null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.35,
                  child: Image.memory(
                    _backgroundBytes!,
                    fit: BoxFit.fill,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            if (_positions.isNotEmpty)
              _buildPositionedLayout()
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const Divider(height: 24, thickness: 1),
                    if (_settings.showClientInfo) ...[
                      _buildClientSection(),
                      const SizedBox(height: 16),
                    ],
                    _buildItemsTable(),
                    const SizedBox(height: 16),
                    _buildTotalsAndQR(),
                    const SizedBox(height: 16),
                    _buildFooter(),
                  ],
                ),
              ),
            if (_settings.showWatermark)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.35,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _settings.primaryColor.withValues(alpha: 0.12),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _settings.watermarkText.toUpperCase(),
                          style: TextStyle(
                            color: _settings.primaryColor.withValues(alpha: 0.09),
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //  BOUTONS D'ACHAT / PANIER (sous l'aperçu)
  // ============================================================
  Widget _buildActionButtons(ThemeProvider theme) {
    final auth = context.watch<AppAuthProvider>();
    final currentUserId = auth.user?.id ?? '';
    final isAdmin = auth.isAdmin;
    final template = widget.template;
    final isOwned = isAdmin ||
        (currentUserId.isNotEmpty &&
            template.purchasedBy.contains(currentUserId)) ||
        template.price <= 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 💰 Prix / statut du modèle.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.isDarkMode ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isOwned ? Icons.check_circle : Icons.sell,
                color: isOwned ? Colors.green : template.primaryColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOwned
                      ? (template.price <= 0
                          ? 'Modèle gratuit'
                          : 'Modèle débloqué ✓')
                      : 'Prix : ${template.price.toStringAsFixed(0)} XAF',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        theme.isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isOwned)
          // Déjà possédé → accès à la personnalisation.
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _openWorkspace,
              style: ElevatedButton.styleFrom(
                backgroundColor: template.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.tune_rounded, size: 20),
              label: const Text(
                'Personnaliser ce modèle',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addToCart,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: template.primaryColor,
                    side: BorderSide(color: template.primaryColor),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text(
                    'Panier',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _buyNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: template.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: Text(
                    'Acheter ${template.price.toStringAsFixed(0)} XAF',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Ajoute le modèle au panier (avec retour visuel).
  void _addToCart() {
    final cart = TemplateCart.instance;
    if (cart.contains(widget.template.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Déjà dans le panier 🛒'),
          backgroundColor: Colors.orange,
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }
    cart.add(widget.template);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.template.name} ajouté au panier 🛒'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  /// Ajoute au panier puis redirige vers le checkout sécurisé.
  void _buyNow() {
    final cart = TemplateCart.instance;
    if (!cart.contains(widget.template.id)) {
      cart.add(widget.template);
    }
    context.push('/templates/checkout');
  }

  /// Ouvre l'espace de travail de personnalisation (drag & drop).
  void _openWorkspace() {
    context.push('/templates/workspace', extra: widget.template);
  }

  // ============================================================
  //  RENDU POSITIONNÉ (customisation drag & drop)
  //  Reflète les positions relatives (0..1), l'échelle et la visibilité
  //  choisies dans l'espace de travail, comme lors de l'impression PDF.
  // ============================================================
  Widget _buildPositionedLayout() {
    final pageW = _pageW; // largeur du conteneur d'aperçu
    final pageH = _pageH; // ratio A4 (~594)
    final children = <Widget>[
      // Base pleine page : donne une taille au Stack (sinon il collapserait
      // car tous ses enfants sont positionnés).
      SizedBox(width: pageW, height: pageH),
    ];

    _positions.forEach((id, raw) {
      if (raw is! Map) return;
      final visible = (raw['visible'] as bool?) ?? true;
      if (!visible) return;
      final x = ((raw['x'] as num?) ?? 0.04).toDouble().clamp(0.0, 0.98);
      final y = ((raw['y'] as num?) ?? 0.04).toDouble().clamp(0.0, 0.98);
      final scale = ((raw['scale'] as num?) ?? 1.0).toDouble().clamp(0.5, 2.5);

      final widget = _variableWidget(id, scale);
      if (widget == null) return;

      // Les blocs larges (tableau des lignes) ont besoin d'une largeur bornée.
      final width = id == 'items' ? (pageW - 48) * 0.92 : null;

      children.add(
        Positioned(
          left: x * pageW,
          top: y * pageH,
          child: ConstrainedBox(
            // ⚠️ Un Positioned sans `width` donne des contraintes de largeur
            // ILLIMITÉES → certains éléments (footer, `width: double.infinity`)
            // lèveraient « BoxConstraints forces an infinite width ».
            // On borne donc la largeur de chaque élément positionné.
            constraints: BoxConstraints(maxWidth: pageW - 48),
            child: width == null
                ? widget
                : SizedBox(width: width, child: widget),
          ),
        ),
      );
    });

    return Stack(children: children);
  }

  /// Valeur d'affichage d'une variable de facture (pour le mapping).
  /// Retourne le widget correspondant à la variable, ou null si inconnue.
  Widget? _variableValue(String varName, double scale) {
    final template = widget.template;
    final company = _company;
    final primary = template.primaryColor;
    final text = template.textColor;
    final fs = (template.fontSize * scale).clamp(6.0, 40.0);
    final sub = text.withValues(alpha: 0.6);

    switch (varName) {
      case 'invoice_number':
        return Text(
          'FAC-2024-001',
          style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.bold, color: text),
        );
      case 'issue_date':
        return Text(
          '12 Oct 2023',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'due_date':
        return Text(
          '12 Nov 2023',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'client_name':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Facturé à :',
              style: TextStyle(
                fontSize: 10 * scale,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            Text(
              'Client SARL',
              style: TextStyle(
                fontSize: 12 * scale,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
          ],
        );
      case 'client_email':
        return Text(
          'client@exemple.com',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'client_phone':
        return Text(
          'Tél: +237 6XX XX XX XX',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'company_name':
        return Text(
          company?.name ?? 'OHADA Invoice Pro',
          style: TextStyle(
            fontSize: 18 * scale,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        );
      case 'company_address':
        return Text(
          company?.address ?? '',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'company_tax_id':
        return Text(
          'N° TVA: M01234567890A',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'subtotal':
        return _totalRow('Sous-total', '100 000 FCFA', text, fs);
      case 'tax_amount':
        return _totalRow('TVA (18%)', '18 000 FCFA', text, fs);
      case 'total_amount':
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: _totalRow(
            'TOTAL TTC',
            '118 000 FCFA',
            primary,
            16 * scale,
            bold: true,
          ),
        );
      case 'status':
        return Text(
          'Payée',
          style: TextStyle(
            fontSize: 10 * scale,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        );
      default:
        return null;
    }
  }

  /// Widget Flutter d'une variable de facture (ou null si à masquer).
  /// Miroir de `printing_service._variableWidget` pour l'aperçu.
  Widget? _variableWidget(String id, double scale) {
    final template = widget.template;
    final company = _company;
    final primary = template.primaryColor;
    final text = template.textColor;
    final fs = (template.fontSize * scale).clamp(6.0, 40.0);
    final sub = text.withValues(alpha: 0.6);

    // 🧩 MAPPING : si l'utilisateur a réassigné une variable de facture à cet
    // élément dans l'espace de travail, on rend la variable mappée à la place
    // du contenu par défaut de l'élément.
    final mappedVar = _customMapping[id];
    if (mappedVar != null && mappedVar.isNotEmpty) {
      final mapped = _variableValue(mappedVar, scale);
      if (mapped != null) return mapped;
    }

    switch (id) {
      case 'logo':
        if (!template.showLogo || company?.logoPath.isEmpty == true) return null;
        return LogoImage(
          path: company?.logoPath,
          width: 72 * scale,
          height: 72 * scale,
        );
      case 'company_name':
        return Text(
          company?.name ?? 'OHADA Invoice Pro',
          style: TextStyle(
            fontSize: 18 * scale,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        );
      case 'company_address':
        return Text(
          company?.address ?? '',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'company_phone':
        return Text(
          'Tél: ${company?.phone ?? ''}',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'company_email':
        return Text(
          'Email: ${company?.email ?? ''}',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'invoice_title':
        return Text(
          'FACTURE',
          style: TextStyle(
            fontSize: 26 * scale,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
          textAlign: TextAlign.right,
        );
      case 'client_name':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Facturé à :',
              style: TextStyle(
                fontSize: 10 * scale,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            Text(
              'Client SARL',
              style: TextStyle(
                fontSize: 12 * scale,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
          ],
        );
      case 'client_address':
        return Text(
          'Douala, Cameroun',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'client_phone':
        return Text(
          'Tél: +237 6XX XX XX XX',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'client_email':
        return Text(
          'client@exemple.com',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'items':
        return _buildItemsTable();
      case 'subtotal':
        return _totalRow('Sous-total', '100 000 FCFA', text, fs);
      case 'tax_amount':
        return _totalRow('TVA (18%)', '18 000 FCFA', text, fs);
      case 'discount':
        return _totalRow('Remise', '-0 FCFA', Colors.red, fs);
      case 'total_amount':
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: _totalRow(
            'TOTAL TTC',
            '118 000 FCFA',
            primary,
            16 * scale,
            bold: true,
          ),
        );
      case 'footer':
        return _buildFooter();
      case 'qr':
        if (!template.showPaymentQR) return null;
        return Text(
          '📱 Paiement Mobile Money accepté',
          style: TextStyle(fontSize: 10 * scale, color: primary),
        );
      case 'signature':
        return SizedBox(
          width: 160 * scale,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 1, color: Colors.grey),
              const SizedBox(height: 4),
              Text(
                'Signature',
                style: TextStyle(fontSize: 9 * scale, color: sub),
              ),
            ],
          ),
        );
      default:
        return null;
    }
  }

  /// Ligne de total (label + valeur) pour le rendu positionné.
  Widget _totalRow(
    String label,
    String value,
    Color color,
    double fs, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fs,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fs,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final template = widget.template;
    final company = _company;
    final textColor = template.textColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_settings.showLogo) ...[
          LogoImage(
            path: company?.logoPath,
            width: 52,
            height: 52,
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                company?.name ?? 'OHADA Invoice Pro',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: template.primaryColor,
                ),
              ),
              if (_settings.showCompanyInfo) ...[
                const SizedBox(height: 4),
                if (company?.address.isNotEmpty == true)
                  Text(
                    company!.address,
                    style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.7)),
                  ),
                if (company?.phone.isNotEmpty == true)
                  Text(
                    'Tél: ${company!.phone}',
                    style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6)),
                  ),
                if (company?.email.isNotEmpty == true)
                  Text(
                    'Email: ${company!.email}',
                    style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6)),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: template.primaryColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'FACTURE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClientSection() {
    final textColor = widget.template.textColor;
    final primaryColor = widget.template.primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.04),
        border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Facturé à :',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Client SARL', 
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text(
            'Douala, Cameroun',
            style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 11),
          ),
          Text(
            'Tél: +237 6XX XX XX XX',
            style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    final template = widget.template;
    final textColor = template.textColor;
    final primaryColor = template.primaryColor;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Désignation',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Qté',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Prix',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          ..._sampleItems.map((item) => Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: primaryColor.withValues(alpha: 0.1),
                      width: _sampleItems.last == item ? 0 : 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item['name']!,
                        style: TextStyle(fontSize: 11, color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item['qty']!,
                        style: TextStyle(fontSize: 11, color: textColor),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item['price']!,
                        style: TextStyle(fontSize: 11, color: textColor),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item['total']!,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTotalsAndQR() {
    final template = widget.template;
    final textColor = template.textColor;
    final primaryColor = template.primaryColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Intégration du code QR de paiement
        if (_settings.showPaymentQR)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded, 
              size: 64, 
              color: textColor.withValues(alpha: 0.8),
            ),
          )
        else
          const Spacer(),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sous-total:', style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.7))),
                    Text('100 000 FCFA', style: TextStyle(fontSize: 11, color: textColor)),
                  ],
                ),
                if (_settings.showTaxDetails) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TVA (18%):', style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.7))),
                      Text('18 000 FCFA', style: TextStyle(fontSize: 11, color: textColor)),
                    ],
                  ),
                ],
                const Divider(height: 8, thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL TTC:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                    Text(
                      _settings.showTaxDetails ? '118 000 FCFA' : '100 000 FCFA',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final template = widget.template;
    final textColor = template.textColor;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: template.primaryColor.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _company?.legalText ?? 'Conforme aux normes OHADA et SYSCOHADA',
            style: TextStyle(
              fontSize: 9,
              color: textColor.withValues(alpha: 0.55),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (_settings.showPaymentTerms) ...[
          const SizedBox(height: 8),
          Text(
            'Conditions de règlement : Paiement à réception.',
            style: TextStyle(
              fontSize: 8.5, 
              color: textColor.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ]
      ],
    );
  }

  final List<Map<String, String>> _sampleItems = [
    {
      'name': 'Consultation & Audit',
      'qty': '2',
      'price': '25 000 FCFA',
      'total': '50 000 FCFA'
    },
    {
      'name': 'Développement Application',
      'qty': '1',
      'price': '30 000 FCFA',
      'total': '30 000 FCFA'
    },
    {
      'name': 'Maintenance mensuelle',
      'qty': '1',
      'price': '20 000 FCFA',
      'total': '20 000 FCFA'
    },
  ];
}

// ============================================================
//  Peintres personnalisés : règles graduées + toile quadrillée
// ============================================================

/// Règle graduée (mm / cm) dessinée le long de la page A4.
class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.vertical,
    required this.pxPerMm,
    required this.tickColor,
    required this.labelColor,
    required this.rulerSize,
  });

  final bool vertical;
  final double pxPerMm;
  final Color tickColor;
  final Color labelColor;
  final double rulerSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = tickColor
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.square;

    final length = vertical ? size.height : size.width;
    final textStyle = TextStyle(
      fontSize: 7.5,
      fontWeight: FontWeight.w600,
      color: labelColor,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    for (int mm = 0; mm * pxPerMm <= length + 0.5; mm++) {
      final pos = mm * pxPerMm;
      final isCm = mm % 10 == 0;
      final isHalf = mm % 5 == 0;
      final tickLen = isCm
          ? rulerSize - 5
          : (isHalf ? rulerSize - 9 : rulerSize - 12);

      if (vertical) {
        // Graduations depuis le bord droit (côté page).
        canvas.drawLine(
          Offset(size.width, pos),
          Offset(size.width - tickLen, pos),
          paint,
        );
        if (isCm) {
          final tp = TextPainter(
            text: TextSpan(text: '${mm ~/ 10}', style: textStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(2.5, pos - tp.height / 2));
        }
      } else {
        // Graduations depuis le bord bas (côté page).
        canvas.drawLine(
          Offset(pos, size.height),
          Offset(pos, size.height - tickLen),
          paint,
        );
        if (isCm) {
          final tp = TextPainter(
            text: TextSpan(text: '${mm ~/ 10}', style: textStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(pos - tp.width / 2, 2));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) =>
      oldDelegate.vertical != vertical ||
      oldDelegate.pxPerMm != pxPerMm ||
      oldDelegate.tickColor != tickColor ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.rulerSize != rulerSize;
}

/// Fond de toile de design : grille de points discrets.
class _DotGridPainter extends CustomPainter {
  _DotGridPainter({required this.color});

  final Color color;
  static const double _spacing = 22;
  static const double _radius = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double x = 0; x < size.width; x += _spacing) {
      for (double y = 0; y < size.height; y += _spacing) {
        canvas.drawCircle(Offset(x, y), _radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) => oldDelegate.color != color;
}