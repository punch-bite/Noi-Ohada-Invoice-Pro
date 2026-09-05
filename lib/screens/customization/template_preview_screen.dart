// lib/screens/customization/template_preview_screen.dart
//
// 👁️ Aperçu d'un modèle — refonte maquette Stitch « Aperçu de la facture » :
//   • En-tête : retour + nom du modèle + sous-titre A4 (SYSCOHADA)
//   • Canvas rosé + bouton « zoom » flottant (maquette)
//   • PAPIER A4 fidèle à la maquette (`StitchA4InvoicePreview`) avec les
//     PARAMÈTRES DE PERSONNALISATION sauvegardés : couleurs du modèle,
//     layout drag & drop, fond image/préréglage, options d'affichage
//   • Barre basse sombre : « Éditer » (workspace) + « Utiliser » (modèle
//     actif) — et pour un modèle PAYANT non acquis : « Panier » (ajout au
//     panier) + « Commander » (checkout ENKAP).
import 'dart:convert' show base64Decode;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_layout.dart';
import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/template_cart.dart';
import '../../services/template_custom_service.dart';
import '../../services/template_selection_service.dart';
import '../../services/template_service.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/stitch_a4_invoice_preview.dart';

/// 👁️ Aperçu A4 haute fidélité (maquette Stitch) d'un modèle de facture.
class TemplatePreviewScreen extends StatefulWidget {
  final InvoiceTemplate template;

  const TemplatePreviewScreen({super.key, required this.template});

  @override
  State<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends State<TemplatePreviewScreen> {
  late InvoiceLayoutConfig _layoutConfig;
  TemplateBackgroundSettings _backgroundSettings =
      const TemplateBackgroundSettings();
  bool _isLoading = true;
  double _zoom = 1.0;
  // 🛒 Possession du modèle (pour n'afficher Panier/Commander que si utile).
  bool _ownedChecked = false;
  bool _isOwned = false;

  @override
  void initState() {
    super.initState();
    _layoutConfig = InvoiceLayoutConfig.defaultLayout();
    _loadData();
    _loadOwnership();
  }

  /// Vérifie si ce modèle est déjà acquis (comme dans la boutique) afin de
  /// masquer « Panier » / « Commander » pour un modèle déjà possédé.
  Future<void> _loadOwnership() async {
    final auth = context.read<AppAuthProvider>();
    final userId = auth.user?.id ?? '';
    // 🚀 Sans utilisateur connecté, rien n'est acquis : inutile d'interroger
    // Firestore (getMyTemplates('') ne renverrait de toute façon que les
    // modèles gratuits, déjà couverts par canBeCustomizedBy).
    if (userId.isEmpty) {
      setState(() => _ownedChecked = true);
      return;
    }
    try {
      final mine = await TemplateService().getMyTemplates(userId);
      if (!mounted) return;
      setState(() {
        _isOwned = mine.any((t) => t.id == widget.template.id);
        _ownedChecked = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _ownedChecked = true);
    }
  }

  Future<void> _loadData() async {
    // 🧩 Personnalisations sauvegardées du modèle (positions drag & drop +
    // fond image/préréglage) — mêmes sources que le workspace et le PDF.
    final custom = await TemplateCustomService.loadCustom(widget.template.id);
    if (!mounted) return;
    setState(() {
      if (custom.positions.isNotEmpty) {
        _layoutConfig = InvoiceLayoutConfig.fromMap(custom.positions);
      }
      _backgroundSettings = custom.background;
      _isLoading = false;
    });
  }

  /// Définit ce modèle comme modèle actif (sélection persistée localement).
  Future<void> _useThisTemplate() async {
    await TemplateSelectionService.setActiveTemplateId(widget.template.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '« ${widget.template.name} » est maintenant votre modèle actif'),
        backgroundColor: RoyalColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.pop();
  }

  void _openWorkspace() =>
      context.push('/templates/workspace', extra: widget.template);

  /// 🛒 Ajoute / retire ce modèle du panier local (partagé avec la boutique
  /// et le checkout via [TemplateCart]).
  void _toggleCart() {
    final cart = context.read<TemplateCart>();
    final template = widget.template;
    final wasInCart = cart.contains(template.id);
    if (wasInCart) {
      cart.remove(template.id);
    } else {
      cart.add(template);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(wasInCart
              ? '« ${template.name} » retiré du panier'
              : '« ${template.name} » ajouté au panier '
                  '(${TemplateCart.instance.count} modèle(s))'),
          backgroundColor:
              wasInCart ? RoyalColors.secondary : RoyalColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// 💳 Passe au checkout avec ce modèle (paiement ENKAP ou déblocage
  /// gratuit si le prix est nul).
  void _checkout() =>
      context.push('/templates/checkout', extra: widget.template);

  @override
  Widget build(BuildContext context) {
    final c = RoyalScheme.of(context);
    final template = widget.template;
    final Uint8List? bgImage = _decodeBg(_backgroundSettings);

    // 👮 Personnalisation réservée à l'administrateur et au propriétaire du
    // modèle (créateur / acheteur / accès premium / modèle gratuit).
    final hasPremiumAccess =
        context.watch<SubscriptionProvider>().canAccessPremiumTemplates;
    final isAdmin = context.watch<AppAuthProvider>().isAdmin;
    final userId = context.read<AppAuthProvider>().user?.id ?? '';
    final canCustomize = _ownedChecked &&
        (_isOwned ||
            template.canBeCustomizedBy(
              userId: userId,
              isAdmin: isAdmin,
              hasPremiumAccess: hasPremiumAccess,
            ));
    // 🛒 Actions commerce : modèle payant non acquis (ni admin, ni premium).
    final showCommerce = template.price > 0 &&
        _ownedChecked &&
        !_isOwned &&
        !hasPremiumAccess &&
        !isAdmin;
    final inCart = context.watch<TemplateCart>().contains(template.id);

    return Scaffold(
      backgroundColor: c.surfaceContainerLow,
      appBar: _buildAppBar(c, template.name, 'Aperçu Format A4 (SYSCOHADA)',
          canCustomize: canCustomize),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : Column(
              children: [
                Expanded(
                  // Canvas de la maquette (surfaceContainerLow) + papier A4.
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        child: Center(
                          child: Transform.scale(
                            scale: _zoom,
                            alignment: Alignment.topCenter,
                            child: StitchA4InvoicePreview(
                              data: StitchPreviewData.sample(),
                              accentColor: template.primaryColor,
                              pageColor: template.backgroundColor,
                              showLogo: template.showLogo,
                              showBorder: template.showBorder,
                              showTaxDetails: template.showTaxDetails,
                              showPaymentTerms: template.showPaymentTerms,
                              showPaymentQR: template.showPaymentQR,
                              fontFamily: template.fontFamily,
                              fontScale: template.fontSize / 12,
                              layoutConfig: _layoutConfig,
                              backgroundSettings: _backgroundSettings,
                              backgroundImage: bgImage,
                              // Tampon « PAYÉ » — démonstration maquette.
                              showPaidStamp: true,
                            ),
                          ),
                        ),
                      ),
                      // Bouton zoom flottant (haut droite, maquette).
                      Positioned(
                        top: 8,
                        right: 16,
                        child: _zoomButton(c),
                      ),
                    ],
                  ),
                ),
                _buildBottomBar(
                  c,
                  canCustomize: canCustomize,
                  showCommerce: showCommerce,
                  inCart: inCart,
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(RoyalScheme c, String title, String subtitle,
      {required bool canCustomize}) {
    return AppBar(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0.5,
      scrolledUnderElevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      centerTitle: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: c.onSurface),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/templates');
          }
        },
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: c.onSurface,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(22),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 56, bottom: 6),
            child: Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 11,
                color: c.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
      actions: [
        // 👮 Personnalisation réservée à l'admin et au propriétaire du modèle.
        if (canCustomize)
          IconButton(
            tooltip: 'Personnaliser (Drag & Drop)',
            icon: Icon(Icons.tune, color: c.tertiary),
            onPressed: _openWorkspace,
          ),
      ],
    );
  }

  /// Bouton zoom flottant de la maquette (cercle translucide bordé).
  Widget _zoomButton(RoyalScheme c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomIcon(c, Icons.remove, () {
            setState(() => _zoom = (_zoom - 0.1).clamp(0.5, 1.6));
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '${(_zoom * 100).toInt()}%',
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: c.onSurface,
              ),
            ),
          ),
          _zoomIcon(c, Icons.add, () {
            setState(() => _zoom = (_zoom + 0.1).clamp(0.5, 1.6));
          }),
        ],
      ),
    );
  }

  Widget _zoomIcon(RoyalScheme c, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Icon(icon, size: 16, color: c.onSurface),
      ),
    );
  }

  /// Barre basse sombre (inverseSurface) : Utiliser (+ Éditer si la
  /// personnalisation est autorisée, et Panier/Commander pour un modèle
  /// payant non acquis).
  Widget _buildBottomBar(
    RoyalScheme c, {
    required bool canCustomize,
    required bool showCommerce,
    required bool inCart,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: c.inverseSurface.withValues(alpha: 0.97),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 👮 « Éditer » visible uniquement si l'utilisateur peut
          // personnaliser (administrateur ou propriétaire du modèle).
          if (canCustomize)
            _bottomAction(
              c,
              icon: Icons.edit_outlined,
              label: 'Éditer',
              onTap: _openWorkspace,
            ),
          _bottomAction(
            c,
            icon: Icons.check_circle_outline_rounded,
            label: 'Utiliser',
            onTap: _useThisTemplate,
          ),
          if (showCommerce) ...[
            _bottomAction(
              c,
              icon: inCart
                  ? Icons.check_circle_rounded
                  : Icons.add_shopping_cart_rounded,
              label: inCart ? 'Ajouté' : 'Panier',
              onTap: _toggleCart,
            ),
            _bottomAction(
              c,
              icon: Icons.shopping_cart_checkout_rounded,
              label: 'Commander',
              filled: true,
              onTap: _checkout,
            ),
          ],
        ],
      ),
    );
  }

  /// Action de la barre basse : cercle bordé + libellé (maquette).
  /// Si [filled] est vrai (bouton « Commander ») : cercle plein doré.
  Widget _bottomAction(
    RoyalScheme c, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? RoyalColors.tertiaryContainer : null,
                border: Border.all(
                  color: filled
                      ? RoyalColors.tertiaryContainer
                      : Colors.white.withValues(alpha: 0.20),
                ),
              ),
              child: Icon(
                icon,
                size: 22,
                color: filled
                    ? RoyalColors.onTertiaryContainer
                    : c.inverseOnSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 13,
                fontWeight: filled ? FontWeight.w700 : null,
                color: c.inverseOnSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Décode l'image de fond sauvegardée (base64 → bytes).
  static Uint8List? _decodeBg(TemplateBackgroundSettings settings) {
    if (!settings.hasCustomImage) return null;
    try {
      return base64Decode(settings.fileData);
    } catch (_) {
      return null;
    }
  }
}
