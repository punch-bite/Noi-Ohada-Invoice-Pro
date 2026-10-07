// lib/screens/dashboard/invoice_print_preview_screen.dart
//
// CHANGELOG v4 :
//   • 🎯 PARITÉ ABSOLUE avec `invoice_detail_screen` :
//     - `previewBackground` est transmis résolu (plus de re-décodage).
//     - Le template effectif est utilisé TEL QUEL (plus de double
//       `applyToTemplate`).
//     - Le widget caché capture EXACTEMENT le même rendu que l'aperçu
//       affiché dans l'écran détail.
//   • Résultat : détail = aperçu PDF = impression, pixel-perfect.
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
import '../../services/template_custom_service.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/stitch_a4_invoice_preview.dart';

class InvoicePrintPreviewArgs {
  final Invoice invoice;
  final Client client;
  final Company company;
  final InvoiceTemplate template;

  /// 📐 Positions **déjà résolues** (preset + custom fusionnés).
  final Map<String, dynamic> customPositions;

  /// 🎨 Background settings résolus.
  final TemplateBackgroundSettings background;

  /// 🖼️ Image de fond **déjà décodée** (custom, ou template.fileData).
  /// Null si ni custom ni preset ni template.fileData.
  ///
  /// ⚠️ CRITIQUE : ce champ garantit la parité visuelle avec l'écran détail.
  final Uint8List? previewBackground;

  final InvoiceSettings invoiceSettings;
  final bool isFreePlan;

  const InvoicePrintPreviewArgs({
    required this.invoice,
    required this.client,
    required this.company,
    required this.template,
    required this.customPositions,
    required this.background,
    this.previewBackground,
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
  /// 🎯 Clé du RepaintBoundary caché → capture PNG.
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
      // 2 frames pour garantir le rendu du RepaintBoundary.
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
        // ── Mode image : capture → PDF (WYSIWYG strict) ──
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

      // 🎯 Widget A4 caché — IDENTIQUE au `_buildInvoicePaper` du détail.
      bottomSheet: _widgetReady
          ? const SizedBox.shrink()
          : _buildHiddenCapture(),
    );
  }

  /// 🎯 Construit le widget A4 caché — **parité absolue** avec l'aperçu détail.
  ///
  /// ⚠️ AUCUNE re-computation :
  ///   • `args.template` est déjà le template **effectif** (settings appliqués
  ///     par `InvoiceRenderService.resolveRenderState` dans le détail).
  ///   • `args.customPositions` sont déjà fusionnées (preset + custom).
  ///   • `args.background` sont déjà résolues.
  ///   • `args.previewBackground` est déjà décodée (custom OU fileData).
  Widget _buildHiddenCapture() {
    return SizedBox(
      width: 0,
      height: 0,
      child: OverflowBox(
        maxWidth: InvoiceTemplate.kPageWidth,
        maxHeight: InvoiceTemplate.kPageHeight,
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: _captureKey,
          child: SizedBox(
            width: InvoiceTemplate.kPageWidth,
            height: InvoiceTemplate.kPageHeight,
            child: StitchA4InvoicePreview(
              // ── Données dynamiques ──
              data: StitchPreviewDataX.fromInvoice(
                invoice: args.invoice,
                client: args.client,
                company: args.company,
              ),

              // ── Template effectif (settings déjà appliqués) ──
              accentColor: args.template.primaryColor,
              pageColor: args.template.backgroundColor,
              showLogo: args.template.showLogo,
              showBorder: args.template.showBorder,
              showTaxDetails: args.template.showTaxDetails,
              showPaymentTerms: args.template.showPaymentTerms,
              showPaymentQR: args.template.showPaymentQR,
              fontFamily: args.template.fontFamily,
              fontScale: args.template.fontSize / 12,

              // ── Layout (positions résolues) ──
              layoutConfig: InvoiceLayoutConfig.defaultLayout(),
              customPositions: args.customPositions,

              // ── Background (image pré-décodée, settings résolus) ──
              backgroundSettings: args.background,
              backgroundImage: args.previewBackground,

              // ── Filigrane / tampon ──
              watermarkText: args.invoiceSettings.watermarkText,
              showWatermark: args.invoiceSettings.showWatermark,
              showPaidStamp: args.invoice.status == 'paid',
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