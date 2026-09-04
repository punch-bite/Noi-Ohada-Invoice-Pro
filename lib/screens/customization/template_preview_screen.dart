// lib/screens/customization/template_preview_screen.dart
//
// 👁️ Aperçu d'un modèle — refonte maquette Stitch « Aperçu de la facture » :
//   • En-tête : retour + nom du modèle + sous-titre A4 (SYSCOHADA)
//   • Canvas rosé + bouton « zoom » flottant (maquette)
//   • PAPIER A4 fidèle à la maquette (`StitchA4InvoicePreview`) avec les
//     PARAMÈTRES DE PERSONNALISATION sauvegardés : couleurs du modèle,
//     layout drag & drop, fond image/préréglage, options d'affichage
//   • Barre basse sombre : « Éditer » (workspace) + « Utiliser » (modèle actif)
import 'dart:convert' show base64Decode;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/invoice_layout.dart';
import '../../models/invoice_template.dart';
import '../../services/template_custom_service.dart';
import '../../services/template_selection_service.dart';
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

  @override
  void initState() {
    super.initState();
    _layoutConfig = InvoiceLayoutConfig.defaultLayout();
    _loadData();
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

  @override
  Widget build(BuildContext context) {
    final c = RoyalScheme.of(context);
    final template = widget.template;
    final Uint8List? bgImage = _decodeBg(_backgroundSettings);

    return Scaffold(
      backgroundColor: c.surfaceContainerLow,
      appBar: _buildAppBar(c, template.name, 'Aperçu Format A4 (SYSCOHADA)'),
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
                _buildBottomBar(c),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      RoyalScheme c, String title, String subtitle) {
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

  /// Barre basse sombre (inverseSurface) : Éditer + Utiliser.
  Widget _buildBottomBar(RoyalScheme c) {
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
        ],
      ),
    );
  }

  /// Action de la barre basse : cercle bordé + libellé (maquette).
  Widget _bottomAction(
    RoyalScheme c, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
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
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20)),
              ),
              child: Icon(icon, size: 22, color: c.inverseOnSurface),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 13,
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
