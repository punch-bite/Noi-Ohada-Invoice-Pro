// lib/screens/dashboard/invoice_print_preview_screen.dart
//
// CHANGELOG v3 :
//   • 🎯 FIX PARITÉ ABSOLUE : le widget capturé pour le PDF applique
//     EXACTEMENT la même transformation que `invoice_detail_screen.dart`
//     (SettingsService.applyToTemplate + même background image + même
//     layoutConfig + même watermark).
//   • Résultat : PDF = aperçu à 100%, pixel-perfect, en mode "image".
//
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../models/client.dart';
import '../../models/company.dart';
import '../../models/invoice.dart';
import '../../models/invoice_layout.dart';
import '../../models/invoice_settings.dart';
import '../../models/invoice_template.dart';
import '../../services/printing_service.dart';
import '../../services/settings_service.dart';
import '../../services/template_custom_service.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/stitch_a4_invoice_preview.dart';

class InvoicePrintPreviewArgs {
  final Invoice invoice;
  final Client client;
  final Company company;
  final InvoiceTemplate template;
  final Map<String, dynamic> customPositions;
  final TemplateBackgroundSettings background;
  final InvoiceSettings invoiceSettings;
  final bool isFreePlan;

  const InvoicePrintPreviewArgs({
    required this.invoice,
    required this.client,
    required this.company,
    required this.template,
    required this.customPositions,
    required this.background,
    required this.invoiceSettings,
    required this.isFreePlan,
  });
}

class InvoicePrintPreviewScreen extends StatefulWidget {
  final InvoicePrintPreviewArgs args;
  const InvoicePrintPreviewScreen({super.key, required this.args});

  @override
  State<InvoicePrintPreviewScreen> createState() =>
      _InvoicePrintPreviewScreenState();
}

class _InvoicePrintPreviewScreenState
    extends State<InvoicePrintPreviewScreen> {
  /// 🎯 Clé du RepaintBoundary caché → capture PNG pour le mode image.
  final GlobalKey _captureKey = GlobalKey();

  InvoiceRenderMode _mode = InvoiceRenderMode.image;
  bool _isGenerating = false;
  Uint8List? _pdfBytes;
  bool _widgetReady = false;

  InvoicePrintPreviewArgs get args => widget.args;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 2 frames pour être sûr que le RepaintBoundary est peint.
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) {
        setState(() => _widgetReady = true);
        _generatePdf();
      }
    });
  }

  Future<void> _generatePdf() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      Uint8List pdf;

      if (_mode == InvoiceRenderMode.image) {
        // ── Mode image : capture du widget → PDF (WYSIWYG) ──
        final png = await PrintingService.captureWidgetToPng(
          _captureKey,
          pixelRatio: 3.0,
        );
        if (png == null) {
          if (mounted) setState(() => _isGenerating = false);
          return;
        }
        pdf = await PrintingService.generateInvoicePdfFromCapture(
          pngBytes: png,
          isFreePlan: args.isFreePlan,
        );
      } else {
        // ── Mode vector : PDF texte ──
        pdf = await PrintingService.generateInvoicePdf(
          invoice: args.invoice,
          client: args.client,
          company: args.company,
          template: args.template,
          customPositions: args.customPositions,
          customBackground: args.background,
          isFreePlan: args.isFreePlan,
          invoiceSettings: args.invoiceSettings,
        );
      }

      if (!mounted) return;
      setState(() {
        _pdfBytes = pdf;
        _isGenerating = false;
      });
    } catch (e) {
      debugPrint('⚠️ _generatePdf : $e');
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _onModeChanged(InvoiceRenderMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _pdfBytes = null;
    });
    _generatePdf();
  }

  @override
  Widget build(BuildContext context) {
    final c = RoyalScheme.of(context);
    final isDevis = args.invoice.isDevis;
    final title = isDevis ? 'Aperçu Devis' : 'Aperçu Facture';
    final subtitle =
        '${isDevis ? 'Devis' : 'Facture'} N° ${args.invoice.invoiceNumber}';
    final fileName =
        '${isDevis ? 'Devis' : 'Facture'}_${args.invoice.invoiceNumber}.pdf';

    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: c.onSurface,
            size: 20,
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: c.onSurface,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 11,
                color: c.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                args.template.name,
                style: TextStyle(
                  fontFamily: 'WorkSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.onSecondaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildModeToggle(c),
          Expanded(
            child: _isGenerating || _pdfBytes == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          'Génération du PDF…',
                          style: TextStyle(
                            color: c.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : PdfPreview(
                    key: ValueKey(_mode),
                    build: (_) async => _pdfBytes!,
                    initialPageFormat: PdfPageFormat.a4,
                    pageFormats: const {'A4': PdfPageFormat.a4},
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    maxPageWidth: 720,
                    pdfFileName: fileName,
                    allowPrinting: true,
                    allowSharing: true,
                    padding: const EdgeInsets.all(16),
                    previewPageMargin:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
          ),
        ],
      ),

      // 🎯 Widget A4 caché — reproduit EXACTEMENT l'aperçu de la facture.
      bottomSheet: _widgetReady
          ? const SizedBox.shrink()
          : _buildHiddenCapture(),
    );
  }

  /// Construit le widget A4 caché.
  ///
  /// ⚠️ CRITIQUE : utilise la MÊME transformation que `_buildInvoicePaper`
  /// dans `invoice_detail_screen.dart` → parité pixel-perfect garantie.
  Widget _buildHiddenCapture() {
    // 🎯 Reproduit exactement `_buildInvoicePaper` :
    //    effective = SettingsService.applyToTemplate(args.template, settings)
    final effective = SettingsService.applyToTemplate(
      args.template,
      args.invoiceSettings,
    );

    // 🎯 Même logique de background que dans `_applyCustomisation`.
    final hasCustom = args.background.hasCustomImage;
    final hasPreset = args.background.presetId.isNotEmpty;
    final backgroundBytes = hasCustom
        ? TemplateCustomService.decodeBackground(args.background)
        : null;

    // Si preset sans image custom → on laisse backgroundImage null,
    // le preset est géré par StitchA4InvoicePreview via backgroundSettings.

    return SizedBox(
      width: 0,
      height: 0,
      child: OverflowBox(
        maxWidth: 794,
        maxHeight: 1123,
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: _captureKey,
          child: SizedBox(
            width: 794,
            height: 1123,
            child: StitchA4InvoicePreview(
              data: StitchPreviewDataX.fromInvoice(
                invoice: args.invoice,
                client: args.client,
                company: args.company,
              ),
              // 🎯 TOUTES ces valeurs sont désormais issues du template
              //    "effective" (settings appliqués), comme dans l'aperçu.
              accentColor: effective.primaryColor,
              pageColor: effective.backgroundColor,
              showLogo: effective.showLogo,
              showBorder: effective.showBorder,
              showTaxDetails: effective.showTaxDetails,
              showPaymentTerms: effective.showPaymentTerms,
              showPaymentQR: effective.showPaymentQR,
              fontFamily: effective.fontFamily,
              fontScale: effective.fontSize / 12,
              layoutConfig: InvoiceLayoutConfig.defaultLayout(),
              backgroundSettings: args.background,
              backgroundImage: backgroundBytes,
              watermarkText: args.invoiceSettings.watermarkText,
              showWatermark: args.invoiceSettings.showWatermark,
              showPaidStamp: args.invoice.status == 'paid',
              customPositions: args.customPositions,
            ),
          ),
        ),
      ),
    );
  }

  /// 🎛️ Toggle entre les 2 modes.
  Widget _buildModeToggle(RoyalScheme c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: c.surface,
      child: Row(
        children: [
          Expanded(
            child: _modeChip(
              c,
              icon: Icons.image_outlined,
              label: 'Fidèle (image)',
              mode: InvoiceRenderMode.image,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _modeChip(
              c,
              icon: Icons.text_fields_rounded,
              label: 'Texte (vector)',
              mode: InvoiceRenderMode.vector,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(
    RoyalScheme c, {
    required IconData icon,
    required String label,
    required InvoiceRenderMode mode,
  }) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => _onModeChanged(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? c.primary.withValues(alpha: 0.12)
              : c.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? c.primary
                : c.outlineVariant.withValues(alpha: 0.5),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16, color: selected ? c.primary : c.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? c.primary : c.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}