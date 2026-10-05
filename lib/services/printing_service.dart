// lib/services/printing_service.dart
//
// 🖨️ Service d'impression PDF — WYSIWYG avec l'aperçu StitchA4InvoicePreview.
//
// Corrige et aligne avec invoice_detail_screen :
//   • `invoiceSettings` optionnel (évite le double chargement SettingsService)
//   • `isFreePlan` propagé partout (filigrane + bandeau version gratuite)
//   • `InvoiceTemplate.effectivePositions` utilisé pour la fusion positions
//   • Filigrane + tampon PAYÉ déplaçable (stamp_x/y/rotation/scale)
//   • Marge paramétrable (page_padding) sur tous les layouts
//   • Whitelist stricte des clés positionnables
//   • MultiBackgroundPreset (catalogue multi-modèles)
//   • Bloc `empty_column` préserve sa largeur
//   • `signature_image` + `signatory_title` respectés partout
//
// ignore_for_file: dead_null_aware_expression, deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:noi_ohada_invoice_pro/models/company.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/client.dart';
import '../models/invoice.dart';
import '../models/invoice_layout.dart';
import '../models/invoice_settings.dart';
import '../models/invoice_template.dart';
import '../models/line_item.dart';
import '../widgets/template_background_palette.dart';
import 'invoice_layout_engine.dart' show A4Dimensions;
import 'template_custom_service.dart';
import 'settings_service.dart';

class PrintingService {
  // ═════════════════════════════════════════════════════════════
  //  POLICE
  // ═════════════════════════════════════════════════════════════
  static Future<({
    pw.Font base,
    pw.Font bold,
    pw.Font medium,
    pw.Font? condensed,
  })> _loadFontFamily() async {
    try {
      final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      final medium = await rootBundle.load('assets/fonts/Roboto-Medium.ttf');
      pw.Font? condensed;
      try {
        condensed = pw.Font.ttf(
            await rootBundle.load('assets/fonts/Roboto-Condensed.ttf'));
      } catch (_) {
        condensed = null;
      }
      return (
        base: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
        medium: pw.Font.ttf(medium),
        condensed: condensed,
      );
    } catch (_) {
      final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      return (
        base: pw.Font.ttf(regular),
        bold: pw.Font.ttf(regular),
        medium: pw.Font.ttf(regular),
        condensed: null,
      );
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  API PUBLIQUE
  // ═════════════════════════════════════════════════════════════
  static Future<void> printInvoice({
    required Invoice invoice,
    required Client client,
    required Company company,
    required InvoiceTemplate template,
    bool share = false,
    bool isFreePlan = false,
    Map<String, dynamic>? customPositions,
    Map<String, String>? customMapping,
    TemplateBackgroundSettings? customBackground,
    InvoiceSettings? invoiceSettings,
  }) async {
    final fontFamily = await _loadFontFamily();
    final pdf = await generateInvoicePdf(
      invoice: invoice,
      client: client,
      company: company,
      template: template,
      fontFamily: fontFamily,
      isFreePlan: isFreePlan,
      customPositions: customPositions,
      customMapping: customMapping,
      customBackground: customBackground,
      invoiceSettings: invoiceSettings,
    );

    if (share) {
      await Printing.sharePdf(
        bytes: pdf,
        filename:
            '${invoice.isDevis ? "Devis" : "Facture"}_${invoice.invoiceNumber}.pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf,
      );
    }
  }

  static Future<Uint8List> generateInvoicePdf({
    required Invoice invoice,
    required Client client,
    required Company company,
    required InvoiceTemplate template,
    ({
      pw.Font base,
      pw.Font bold,
      pw.Font medium,
      pw.Font? condensed,
    })? fontFamily,
    bool isFreePlan = false,
    Map<String, dynamic>? customPositions,
    Map<String, String>? customMapping,
    TemplateBackgroundSettings? customBackground,
    InvoiceSettings? invoiceSettings,
  }) async {
    final pdf = pw.Document();
    final fonts = fontFamily ?? await _loadFontFamily();

    // 🧩 Customisation + réglages globaux.
    final custom = await TemplateCustomService.loadCustom(template.id);
    final settings =
        invoiceSettings ?? await SettingsService.instance.loadSettings();
    final effectiveTemplate =
        SettingsService.applyToTemplate(template, settings);

    // ✅ Positions effectives : custom > template (jamais écraser par du vide).
    final positions = customPositions?.isNotEmpty == true
        ? customPositions!
        : InvoiceTemplate.effectivePositions(
            customPositions: custom.positions,
            templatePositions: template.positions,
          );

    final mapping = customMapping?.isNotEmpty == true
        ? customMapping!
        : <String, String>{
            ...template.mapping,
            ...custom.mapping,
          };

    // ───── Arrière-plan ─────
    final bgSettings = customBackground ?? custom.background;
    Uint8List? bgBytes;
    if (bgSettings.hasCustomImage) {
      try {
        bgBytes = base64Decode(bgSettings.fileData);
      } catch (_) {
        bgBytes = null;
      }
    }

    // ✅ Détection d'un « aucun fond » explicite (customBackground fourni vide).
    final wantsNoBackground = customBackground != null &&
        !bgSettings.hasCustomImage &&
        bgSettings.presetId.isEmpty;

    final preset = (bgBytes == null && !wantsNoBackground)
        ? MultiBackgroundPreset.byId(bgSettings.presetId)
        : null;

    if (preset == null && bgBytes == null && !wantsNoBackground) {
      bgBytes = _templateBackgroundBytes(template);
    }

    final bgOpacity = bgSettings.opacity.clamp(0.0, 1.0);

    final pw.Widget? background;
    if (bgBytes != null) {
      background = pw.Positioned.fill(
        child: pw.Opacity(
          opacity: bgOpacity,
          child: pw.Image(pw.MemoryImage(bgBytes), fit: pw.BoxFit.fill),
        ),
      );
    } else if (preset != null) {
      background = pw.Positioned.fill(
        child: pw.Opacity(
          opacity: bgOpacity,
          child: preset.toPdfWidget(),
        ),
      );
    } else {
      background = null;
    }

    // ───── Détection format ─────
    final blockConfig = _blockLayoutFromCustom(positions);

    List<List<String>>? workspaceSections;
    Map<String, bool>? workspaceVisibility;
    final wsSections = positions['blocks_sections'];
    if (wsSections is List && wsSections.isNotEmpty) {
      workspaceSections = InvoiceTemplate.decodeSections(wsSections);
      final wsVis = positions['block_visibility'];
      if (wsVis is Map) {
        workspaceVisibility = <String, bool>{};
        wsVis.forEach((k, v) {
          if (v is bool) workspaceVisibility![k.toString()] = v;
        });
      }
    }

    final margin = _effectivePadding(positions, blockConfig);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: fonts.base,
          bold: fonts.bold,
          italic: fonts.medium,
          boldItalic: fonts.bold,
        ),
        margin: margin,
        build: (pw.Context context) {
          if (workspaceSections != null) {
            return [
              _buildWorkspaceBlocksPdf(
                sections: workspaceSections,
                visibility: workspaceVisibility ?? const <String, bool>{},
                invoice: invoice,
                client: client,
                company: company,
                template: effectiveTemplate,
                mapping: mapping,
                customPositions: positions,
                background: background,
                settings: settings,
                isFreePlan: isFreePlan,
              ),
            ];
          }
          if (blockConfig != null) {
            return [
              _buildBlockLayoutPdf(
                blockConfig,
                invoice,
                client,
                company,
                effectiveTemplate,
                mapping: mapping,
                background: background,
                customPositions: positions,
                isFreePlan: isFreePlan,
                settings: settings,
              ),
            ];
          }
          if (positions.isNotEmpty) {
            return [
              _buildPositionedLayout(
                context,
                positions,
                invoice,
                client,
                company,
                effectiveTemplate,
                mapping: mapping,
                background: background,
                settings: settings,
                isFreePlan: isFreePlan,
              ),
            ];
          }
          return [
            _buildLegacyLayout(
              invoice,
              client,
              company,
              effectiveTemplate,
              settings: settings,
              isFreePlan: isFreePlan,
              background: background,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ═════════════════════════════════════════════════════════════
  //  HELPERS COMMUNS
  // ═════════════════════════════════════════════════════════════

  /// Marge effective : 32 défaut, sinon `page_padding`, sinon 0.
  static pw.EdgeInsets _effectivePadding(
    Map<String, dynamic> positions,
    InvoiceLayoutConfig? blockConfig,
  ) {
    final custom = positions['page_padding'];
    if (custom is num) {
      return pw.EdgeInsets.all(custom.toDouble().clamp(0.0, 120.0));
    }
    if (positions.isEmpty && blockConfig == null) {
      return const pw.EdgeInsets.all(32);
    }
    return pw.EdgeInsets.zero;
  }

  /// Applique filigrane + bandeau « version gratuite ».
  static pw.Widget _applyPageOverlays({
    required pw.Widget body,
    required InvoiceSettings settings,
    required InvoiceTemplate template,
    required bool isFreePlan,
    required Map<String, dynamic> customPositions,
  }) {
    final overlays = <pw.Widget>[
      pw.Positioned.fill(child: body),
    ];

    // 🧧 Filigrane (personnalisable via customPositions).
    final wmShow =
        (customPositions['show_watermark'] as bool?) ?? settings.showWatermark;
    final wmText = (customPositions['watermark_text'] as String?) ??
        (settings.showWatermark ? settings.watermarkText : '');
    if (wmShow && wmText.isNotEmpty) {
      final wmOpacity =
          ((customPositions['watermark_opacity'] as num?) ?? 0.08)
              .toDouble()
              .clamp(0.01, 0.5);
      final wmRotation =
          ((customPositions['watermark_rotation'] as num?) ?? -0.5).toDouble();
      final wmSize =
          ((customPositions['watermark_size'] as num?) ?? 48).toDouble();
      overlays.add(
        pw.Positioned.fill(
          child: pw.Transform.rotate(
            angle: wmRotation,
            child: pw.Center(
              child: pw.Opacity(
                opacity: wmOpacity,
                child: pw.Text(
                  wmText,
                  style: pw.TextStyle(
                    fontSize: wmSize,
                    color: _getPdfColor(settings.textColor),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 🆓 Bandeau version gratuite.
    if (isFreePlan) {
      overlays.add(
        pw.Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: pw.Center(
            child: pw.Text(
              'Généré par OHADA Invoice Pro — Version Gratuite',
              style: pw.TextStyle(
                fontSize: 8,
                color: _withOpacity(_getPdfColor(template.textColor), 0.4),
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }

    return pw.Stack(children: overlays);
  }

  // ═════════════════════════════════════════════════════════════
  //  LAYOUT HISTORIQUE
  // ═════════════════════════════════════════════════════════════
  static pw.Widget _buildLegacyLayout(
    Invoice invoice,
    Client client,
    Company company,
    InvoiceTemplate template, {
    required InvoiceSettings settings,
    required bool isFreePlan,
    pw.Widget? background,
  }) {
    return _applyPageOverlays(
      body: pw.Stack(
        children: [
          if (background != null) background,
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(invoice, company, template),
              pw.SizedBox(height: 16),
              _buildClientInfo(client, template),
              pw.SizedBox(height: 16),
              _buildItemsTable(invoice, template),
              pw.SizedBox(height: 16),
              _buildTotals(invoice, template),
              pw.SizedBox(height: 16),
              _buildFooter(company, template),
            ],
          ),
        ],
      ),
      settings: settings,
      template: template,
      isFreePlan: isFreePlan,
      customPositions: const {},
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  RENDU POSITIONNÉ
  // ═════════════════════════════════════════════════════════════

  /// ✅ Whitelist : seules ces clés sont des éléments positionnables.
  static const Set<String> _positionableKeys = {
    'logo',
    'company_name',
    'company_address',
    'company_phone',
    'company_email',
    'company_tax_id',
    'invoice_title',
    'invoice_number',
    'issue_date',
    'due_date',
    'status',
    'client_name',
    'client_address',
    'client_phone',
    'client_email',
    'items',
    'subtotal',
    'tax_amount',
    'discount',
    'total_amount',
    'footer',
    'qr',
    'signature',
  };

  static pw.Widget _buildPositionedLayout(
    pw.Context context,
    Map<String, dynamic> positions,
    Invoice invoice,
    Client client,
    Company company,
    InvoiceTemplate template, {
    Map<String, String> mapping = const {},
    pw.Widget? background,
    required InvoiceSettings settings,
    required bool isFreePlan,
  }) {
    final pageW = PdfPageFormat.a4.width;
    final pageH = PdfPageFormat.a4.height;
    final children = <pw.Widget>[
      pw.SizedBox(width: pageW, height: pageH),
      if (background != null) background,
    ];

    positions.forEach((id, raw) {
      if (!_positionableKeys.contains(id)) return;
      if (raw is! Map) return;
      final visible = (raw['visible'] as bool?) ?? true;
      if (!visible) return;
      final x = ((raw['x'] as num?) ?? 0.04).toDouble().clamp(0.0, 0.98);
      final y = ((raw['y'] as num?) ?? 0.04).toDouble().clamp(0.0, 0.98);
      final scale = ((raw['scale'] as num?) ?? 1.0).toDouble().clamp(0.5, 2.5);

      final widget = _variableWidget(
        id,
        scale,
        invoice,
        client,
        company,
        template,
        mapping: mapping,
        customPositions: positions,
      );
      if (widget == null) return;

      final width = id == 'items' ? (pageW - 48) * 0.92 : null;
      children.add(
        pw.Positioned(
          left: x * pageW,
          top: y * pageH,
          child: width == null
              ? widget
              : pw.SizedBox(width: width, child: widget),
        ),
      );
    });

    return _applyPageOverlays(
      body: pw.Stack(children: children),
      settings: settings,
      template: template,
      isFreePlan: isFreePlan,
      customPositions: positions,
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  LAYOUT PAR BLOCS (ancien format x/y admin)
  // ═════════════════════════════════════════════════════════════
  static InvoiceLayoutConfig? _blockLayoutFromCustom(
    Map<String, dynamic> custom,
  ) {
    if (custom.isEmpty) return null;
    try {
      if (custom.containsKey('positions')) {
        return InvoiceLayoutConfig.fromMap(custom);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _buildBlockLayoutPdf(
    InvoiceLayoutConfig config,
    Invoice invoice,
    Client client,
    Company company,
    InvoiceTemplate template, {
    Map<String, String> mapping = const {},
    pw.Widget? background,
    Map<String, dynamic> customPositions = const {},
    bool isFreePlan = false,
    required InvoiceSettings settings,
  }) {
    final pageW = PdfPageFormat.a4.width;
    final pageH = PdfPageFormat.a4.height;
    final scaleRatio = pageW / A4Dimensions.width;
    final padding =
        config.pagePadding.clamp(8.0, 80.0).toDouble() * scaleRatio;
    final gutter = A4Dimensions.gutter * scaleRatio;
    final colW = (pageW - padding * 2 - gutter) / 2;

    final children = <pw.Widget>[
      pw.SizedBox(width: pageW, height: pageH),
      if (background != null) background,
      pw.Padding(
        padding: pw.EdgeInsets.all(padding),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final block in LayoutBlock.values) ...[
              _buildPdfBlock(
                block,
                config,
                invoice,
                client,
                company,
                template,
                colW: colW,
                gutter: gutter,
                mapping: mapping,
                customPositions: customPositions,
              ),
              if (block.index < LayoutBlock.values.length - 1)
                pw.SizedBox(
                  height: config.blockSpacing.clamp(0.0, 60.0).toDouble() *
                      scaleRatio,
                ),
            ],
          ],
        ),
      ),
    ];

    return _applyPageOverlays(
      body: pw.Stack(children: children),
      settings: settings,
      template: template,
      isFreePlan: isFreePlan,
      customPositions: customPositions,
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  LAYOUT PAR BLOCS MÉTIER (workspace drag & drop)
  // ═════════════════════════════════════════════════════════════

  static const Map<String, List<LayoutElement>> _workspaceBlockElements = {
    'company_header': [
      LayoutElement.logo,
      LayoutElement.companyName,
      LayoutElement.companyAddress,
      LayoutElement.companyPhone,
      LayoutElement.companyEmail,
    ],
    'invoice_meta': [
      LayoutElement.invoiceTitle,
      LayoutElement.invoiceNumber,
      LayoutElement.issueDate,
      LayoutElement.dueDate,
      LayoutElement.status,
    ],
    'billing_info': [
      LayoutElement.clientName,
      LayoutElement.clientAddress,
      LayoutElement.clientPhone,
      LayoutElement.clientEmail,
    ],
    'items_table': [LayoutElement.itemsTable],
    'totals': [
      LayoutElement.subtotal,
      LayoutElement.taxAmount,
      LayoutElement.discount,
      LayoutElement.totalAmount,
    ],
    'legal_mentions': [LayoutElement.legalMention],
    'signature_block': [LayoutElement.signature],
    'qr_block': [LayoutElement.qrCode],
    'footer_text': [LayoutElement.footerText],
  };

  static const String _emptySpaceMarker = 'empty_column';

  static pw.Widget? _workspaceBlockPdf(
    String key,
    Invoice invoice,
    Client client,
    Company company,
    InvoiceTemplate template, {
    required Map<String, String> mapping,
    required Map<String, dynamic> customPositions,
    required double fs,
    PdfColor? text,
    PdfColor? sub,
  }) {
    final t = text ?? _getPdfColor(template.textColor);
    final s = sub ?? _withOpacity(t, 0.6);

    if (key == 'invoice_meta') {
      final elts = _workspaceBlockElements[key]!;
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final e in elts)
            _pdfElement(e, invoice, client, company, template,
                mapping: mapping, customPositions: customPositions),
        ],
      );
    }

    final elts = _workspaceBlockElements[key];
    if (elts != null) {
      final alignEnd = key == 'totals';
      return pw.Column(
        crossAxisAlignment:
            alignEnd ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: [
          for (final e in elts)
            _pdfElement(e, invoice, client, company, template,
                mapping: mapping, customPositions: customPositions),
        ],
      );
    }

    // Repli : élément isolé ou variable legacy.
    final single = _layoutElementFromKey(key);
    if (single != null) {
      return _pdfElement(single, invoice, client, company, template,
          mapping: mapping, customPositions: customPositions);
    }
    return _variableWidget(key, 1.0, invoice, client, company, template,
        mapping: mapping, customPositions: customPositions);
  }

  static LayoutElement? _layoutElementFromKey(String key) {
    for (final e in LayoutElement.values) {
      if (e.name == key) return e;
    }
    return null;
  }

  static pw.Widget _buildWorkspaceBlocksPdf({
    required List<List<String>> sections,
    required Map<String, bool> visibility,
    required Invoice invoice,
    required Client client,
    required Company company,
    required InvoiceTemplate template,
    required Map<String, String> mapping,
    required Map<String, dynamic> customPositions,
    required pw.Widget? background,
    required InvoiceSettings settings,
    required bool isFreePlan,
  }) {
    final pageW = PdfPageFormat.a4.width;
    final pageH = PdfPageFormat.a4.height;
    final text = _getPdfColor(template.textColor);
    final sub = _withOpacity(text, 0.6);
    final fs = template.fontSize.clamp(6.0, 40.0).toDouble();

    final pad =
        ((customPositions['page_padding'] as num?)?.toDouble() ?? 24.0)
            .clamp(8.0, 80.0);
    const gap = 10.0;
    final contentW = pageW - pad * 2;

    final headerRow = _workspaceHeaderRowPdf(
      invoice,
      company,
      template,
      customPositions: customPositions,
      contentW: contentW,
      gap: gap,
      fs: fs,
      text: text,
      sub: sub,
    );

    // Sortie des blocs « pied » de la dernière section (ancrés en bas).
    const footerish = {'legal_mentions', 'signature_block', 'qr_block'};
    List<String> footerKeys = const [];
    final bodySections = <List<String>>[];
    for (var i = 0; i < sections.length; i++) {
      final sec = sections[i];
      if (i == sections.length - 1 &&
          sec.isNotEmpty &&
          sec.every(
              (k) => k == _emptySpaceMarker || footerish.contains(k))) {
        footerKeys = sec;
      } else {
        bodySections.add(sec);
      }
    }

    final bodyRows = <pw.Widget>[];
    for (final section in bodySections) {
      final keys = section.where((k) => visibility[k] ?? true).toList();
      if (keys.isEmpty) continue;
      bodyRows.add(_workspaceRowPdf(
        keys,
        contentW,
        gap,
        invoice,
        client,
        company,
        template,
        mapping: mapping,
        customPositions: customPositions,
        fs: fs,
        text: text,
        sub: sub,
      ));
      bodyRows.add(pw.SizedBox(height: 14));
    }

    pw.Widget? footerWidget;
    if (footerKeys.isNotEmpty) {
      final keys = footerKeys.where((k) => visibility[k] ?? true).toList();
      if (keys.isNotEmpty) {
        footerWidget = _workspaceRowPdf(
          keys,
          contentW,
          gap,
          invoice,
          client,
          company,
          template,
          mapping: mapping,
          customPositions: customPositions,
          fs: fs,
          text: text,
          sub: sub,
        );
      }
    }

    // ✅ QR en pied de page si demandé par l'atelier (et pas déjà en section).
    final qrPos = customPositions['qr_position'] as String?;
    final showQrInFooter = qrPos == 'footer' &&
        template.showPaymentQR &&
        footerWidget == null;

    final page = pw.Stack(
      children: [
        pw.SizedBox(width: pageW, height: pageH),
        if (background != null) background,
        pw.Padding(
          padding: pw.EdgeInsets.all(pad),
          child: pw.SizedBox(
            height: pageH - pad * 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                headerRow,
                pw.SizedBox(height: 16),
                ...bodyRows,
                if (footerWidget != null) pw.Spacer(),
                if (footerWidget != null) footerWidget,
                if (showQrInFooter) ...[
                  pw.Spacer(),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: _qrWidget(invoice, size: 56),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_buildStampOverlayPdf(invoice, customPositions, fs) != null)
          _buildStampOverlayPdf(invoice, customPositions, fs)!,
      ],
    );

    return _applyPageOverlays(
      body: page,
      settings: settings,
      template: template,
      isFreePlan: isFreePlan,
      customPositions: customPositions,
    );
  }

  /// 🏷️ Tampon PAYÉ — position/rotation/échelle paramétrables.
  static pw.Widget? _buildStampOverlayPdf(
    Invoice invoice,
    Map<String, dynamic> customPositions,
    double fs,
  ) {
    final invoicePaid = invoice.status == 'paid';
    final showPaidStamp =
        (customPositions['show_paid_stamp'] as bool?) ?? invoicePaid;
    if (!showPaidStamp) return null;

    final stampText =
        ((customPositions['stamp_text'] as String?) ?? 'PAYÉ').trim();
    final stampColor = (customPositions['stamp_color'] as int?) != null
        ? Color(customPositions['stamp_color'] as int)
        : const Color(0xFFBAAB6D);
    final stampX = ((customPositions['stamp_x'] as num?) ?? 0.5)
        .toDouble()
        .clamp(0.05, 0.95);
    final stampY = ((customPositions['stamp_y'] as num?) ?? 0.5)
        .toDouble()
        .clamp(0.05, 0.95);
    final rotation =
        ((customPositions['stamp_rotation'] as num?) ?? -0.15).toDouble();
    final scale = ((customPositions['stamp_scale'] as num?) ?? 1.0)
        .toDouble()
        .clamp(0.5, 3.0);

    final pageW = PdfPageFormat.a4.width;
    final pageH = PdfPageFormat.a4.height;

    return pw.Positioned(
      left: stampX * pageW,
      top: stampY * pageH,
      child: pw.Transform.rotate(
        angle: rotation,
        child: pw.Container(
          padding: pw.EdgeInsets.symmetric(
              horizontal: 10 * scale, vertical: 4 * scale),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
                color: _getPdfColor(stampColor), width: 2 * scale),
            borderRadius: pw.BorderRadius.circular(6 * scale),
          ),
          child: pw.Text(
            stampText,
            style: pw.TextStyle(
              fontSize: (fs + 6) * scale,
              fontWeight: pw.FontWeight.bold,
              color: _getPdfColor(stampColor),
            ),
          ),
        ),
      ),
    );
  }

  /// Rangée d'en-tête PDF (colonnes pondérées + alignements).
  static pw.Widget _workspaceHeaderRowPdf(
    Invoice invoice,
    Company company,
    InvoiceTemplate template, {
    required Map<String, dynamic> customPositions,
    required double contentW,
    required double gap,
    required double fs,
    required PdfColor text,
    required PdfColor sub,
  }) {
    final primary = _getPdfColor(template.primaryColor);
    final order = InvoiceTemplate.visibleHeaderElements(customPositions);

    double hweight(String k) {
      final m = customPositions['header_widths'];
      if (m is Map) {
        final v = m[k];
        if (v is num) return v.toDouble().clamp(0.4, 3.0);
      }
      return k == 'company_info' ? 2.0 : 1.0;
    }

    double hdx(String k) {
      final m = customPositions['header_alignments'];
      final s = (m is Map) ? m[k] : null;
      final v = s is String ? s : null;
      if (v == 'center') return 0.0;
      if (v == 'right' || (v == null && k == 'invoice_title')) return 1.0;
      return -1.0;
    }

    final htotal = order.fold<double>(0, (a, k) => a + hweight(k));
    final havail =
        order.isEmpty ? 0.0 : contentW - gap * (order.length - 1);

    String companyName() {
      final o = customPositions['company_name'] as String?;
      return (o != null && o.trim().isNotEmpty) ? o.trim() : company.name;
    }

    pw.Widget content(String key) {
      switch (key) {
        case 'logo':
          if (!template.showLogo) return pw.SizedBox();
          final custom = customPositions['custom_logo_base64'] as String?;
          Uint8List? bytes;
          if (custom != null && custom.isNotEmpty) {
            try {
              bytes = base64Decode(custom);
            } catch (_) {
              bytes = null;
            }
          }
          bytes ??= _logoBytesFromPath(company.logoPath);
          if (bytes == null) return pw.SizedBox();
          return pw.Image(
            pw.MemoryImage(bytes),
            width: 52,
            height: 52,
            fit: pw.BoxFit.contain,
          );
        case 'company_info':
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                companyName(),
                maxLines: 2,
                style: pw.TextStyle(
                  fontSize: fs + 4,
                  fontWeight: pw.FontWeight.bold,
                  color: primary,
                ),
              ),
              pw.SizedBox(height: 3),
              if (company.address.isNotEmpty)
                pw.Text(company.address,
                    style: pw.TextStyle(fontSize: fs - 1, color: sub)),
              if (company.phone.isNotEmpty)
                pw.Text('Tél: ${company.phone}',
                    style: pw.TextStyle(fontSize: fs - 1, color: sub)),
              if (company.email.isNotEmpty)
                pw.Text(company.email,
                    style: pw.TextStyle(fontSize: fs - 1, color: sub)),
            ],
          );
        case 'invoice_title':
        default:
          final t = customPositions['invoice_title_text'] as String?;
          final title = (t != null && t.trim().isNotEmpty)
              ? t.trim()
              : (invoice.isDevis ? 'DEVIS' : 'FACTURE');
          final subtitle =
              customPositions['invoice_subtitle'] as String? ?? '';
          final children = <pw.Widget>[
            pw.Text(
              title,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: fs + 10,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
            if (subtitle.trim().isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  subtitle.trim(),
                  textAlign: pw.TextAlign.right,
                  maxLines: 2,
                  style: pw.TextStyle(
                    fontSize: fs + 1,
                    fontWeight: pw.FontWeight.bold,
                    color: sub,
                  ),
                ),
              ),
          ];
          final qrPos = customPositions['qr_position'] as String?;
          if ((qrPos == 'header') && template.showPaymentQR) {
            children.add(pw.SizedBox(height: 4));
            children.add(_qrWidget(invoice, size: 42));
          }
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: children,
          );
      }
    }

    final rowChildren = <pw.Widget>[];
    for (var i = 0; i < order.length; i++) {
      final key = order[i];
      if (i > 0) rowChildren.add(pw.SizedBox(width: gap));
      final w = order.isEmpty ? contentW : havail * hweight(key) / htotal;
      rowChildren.add(pw.SizedBox(
        width: w,
        child: pw.Align(
          alignment: pw.Alignment(hdx(key), 0),
          child: content(key),
        ),
      ));
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rowChildren,
    );
  }

  /// Rangée d'une section — gère `empty_column` (largeur préservée).
  static pw.Widget _workspaceRowPdf(
    List<String> keys,
    double contentW,
    double gap,
    Invoice invoice,
    Client client,
    Company company,
    InvoiceTemplate template, {
    required Map<String, String> mapping,
    required Map<String, dynamic> customPositions,
    required double fs,
    required PdfColor text,
    required PdfColor sub,
  }) {
    double weight(String k) {
      final m = customPositions['block_widths'];
      if (m is Map) {
        final v = m[k];
        if (v is num) return v.toDouble().clamp(0.3, 3.0);
      }
      return 1.0;
    }

    final totalW = keys.fold<double>(0, (a, k) => a + weight(k));
    final availW = keys.isEmpty ? 0.0 : contentW - gap * (keys.length - 1);

    Color? colorFrom(String mapKey, String k) {
      final m = customPositions[mapKey];
      if (m is Map) {
        final v = m[k];
        if (v is int && v != 0) return Color(v);
      }
      return null;
    }

    final children = <pw.Widget>[];
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      if (i > 0) children.add(pw.SizedBox(width: gap));

      // ✅ Colonne vide : réserve sa largeur, aucun contenu.
      if (key == _emptySpaceMarker) {
        final w = keys.isEmpty ? contentW : availW * weight(key) / totalW;
        children.add(pw.SizedBox(width: w));
        continue;
      }

      final kTextColor = colorFrom('block_text_colors', key);
      final kText = kTextColor == null ? text : _getPdfColor(kTextColor);
      final kSub = _withOpacity(kText, 0.6);
      pw.Widget? cell = _workspaceBlockPdf(
        key,
        invoice,
        client,
        company,
        template,
        mapping: mapping,
        customPositions: customPositions,
        fs: fs,
        text: kText,
        sub: kSub,
      );

      final kBg = colorFrom('block_bg_colors', key);
      if (cell != null && kBg != null) {
        cell = pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            color: _withOpacity(_getPdfColor(kBg), 0.20),
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(
              color: _withOpacity(_getPdfColor(kBg), 0.45),
            ),
          ),
          child: cell,
        );
      }

      final w = keys.isEmpty ? contentW : availW * weight(key) / totalW;
      children.add(pw.SizedBox(width: w, child: cell ?? pw.SizedBox()));
    }
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  BLOCS (ancien format x/y admin)
  // ═════════════════════════════════════════════════════════════
  static pw.Widget _buildPdfBlock(
    LayoutBlock block,
    InvoiceLayoutConfig config,
    Invoice invoice,
    Client client,
    Company company,
    InvoiceTemplate template, {
    required double colW,
    required double gutter,
    Map<String, String> mapping = const {},
    Map<String, dynamic> customPositions = const {},
  }) {
    final entries = config.positions.entries
        .where((e) =>
            e.value.blockIndex == block.index &&
            config.styleOf(e.key).visible)
        .toList()
      ..sort((a, b) {
        final byOrder = a.value.order.compareTo(b.value.order);
        if (byOrder != 0) return byOrder;
        return a.value.column.compareTo(b.value.column);
      });
    if (entries.isEmpty) return pw.SizedBox();

    final rows = <int, List<MapEntry<LayoutElement, ElementPosition>>>{};
    for (final entry in entries) {
      rows.putIfAbsent(entry.value.order, () => []).add(entry);
    }
    final sortedOrders = rows.keys.toList()..sort();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final order in sortedOrders) ...[
          _buildPdfRow(
            rows[order]!,
            invoice,
            client,
            company,
            template,
            colW: colW,
            gutter: gutter,
            mapping: mapping,
            customPositions: customPositions,
            config: config,
          ),
          pw.SizedBox(height: 6),
        ],
      ],
    );
  }

  static pw.Widget _buildPdfRow(
    List<MapEntry<LayoutElement, ElementPosition>> row,
    Invoice invoice,
    Client client,
    Company company,
    InvoiceTemplate template, {
    required double colW,
    required double gutter,
    Map<String, String> mapping = const {},
    Map<String, dynamic> customPositions = const {},
    InvoiceLayoutConfig? config,
  }) {
    row.sort((a, b) => a.value.column.compareTo(b.value.column));

    pw.Widget build(MapEntry<LayoutElement, ElementPosition> entry,
            double width) =>
        pw.SizedBox(
          width: width,
          child: _pdfElement(
            entry.key,
            invoice,
            client,
            company,
            template,
            mapping: mapping,
            customPositions: customPositions,
            config: config,
          ),
        );

    if (row.length == 1 && row.first.value.colSpan == 2) {
      return build(row.first, colW * 2 + gutter);
    }

    final left = row.where((e) => e.value.column == 0).toList();
    final right = row.where((e) => e.value.column == 1).toList();

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: colW,
          child: left.isEmpty ? pw.SizedBox() : build(left.first, colW),
        ),
        pw.SizedBox(width: gutter),
        pw.SizedBox(
          width: colW,
          child: right.isEmpty ? pw.SizedBox() : build(right.first, colW),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  ÉLÉMENT PDF
  // ═════════════════════════════════════════════════════════════
  static pw.Widget _pdfElement(
    LayoutElement element,
    Invoice invoice,
    Client client,
    Company company,
    InvoiceTemplate template, {
    Map<String, String> mapping = const {},
    Map<String, dynamic> customPositions = const {},
    InvoiceLayoutConfig? config,
  }) {
    final elStyle = config?.styleOf(element);
    if (elStyle != null && !elStyle.visible) {
      return pw.SizedBox();
    }

    const byVariable = <LayoutElement, String>{
      LayoutElement.logo: 'logo',
      LayoutElement.companyName: 'company_name',
      LayoutElement.companyAddress: 'company_address',
      LayoutElement.companyPhone: 'company_phone',
      LayoutElement.companyEmail: 'company_email',
      LayoutElement.invoiceTitle: 'invoice_title',
      LayoutElement.invoiceNumber: 'invoice_number',
      LayoutElement.issueDate: 'issue_date',
      LayoutElement.dueDate: 'due_date',
      LayoutElement.status: 'status',
      LayoutElement.clientName: 'client_name',
      LayoutElement.clientAddress: 'client_address',
      LayoutElement.clientPhone: 'client_phone',
      LayoutElement.clientEmail: 'client_email',
      LayoutElement.itemsTable: 'items',
      LayoutElement.subtotal: 'subtotal',
      LayoutElement.taxAmount: 'tax_amount',
      LayoutElement.discount: 'discount',
      LayoutElement.totalAmount: 'total_amount',
    };
    final variable = byVariable[element];
    if (variable != null) {
      final widget = _variableWidget(
        variable,
        1.0,
        invoice,
        client,
        company,
        template,
        mapping: mapping,
        customPositions: customPositions,
      );
      return widget ?? pw.SizedBox();
    }

    final text = elStyle?.color != null
        ? _getPdfColor(elStyle!.color!)
        : _getPdfColor(template.textColor);
    final primary = _getPdfColor(template.primaryColor);
    final sub = _withOpacity(text, 0.6);
    final fs =
        (elStyle?.fontSize ?? template.fontSize).clamp(6.0, 40.0).toDouble();

    switch (element) {
      case LayoutElement.footerText:
        final customLegal = customPositions['custom_legal_text'] as String?;
        final legalTextToDisplay =
            (customLegal != null && customLegal.trim().isNotEmpty)
                ? customLegal.trim()
                : company.legalText;
        return pw.Text(
          legalTextToDisplay,
          style: pw.TextStyle(
            fontSize: fs - 1,
            color: sub,
            fontStyle: pw.FontStyle.italic,
          ),
        );
      case LayoutElement.legalMention:
        final customLegal = customPositions['custom_legal_text'] as String?;
        final legalTextToDisplay =
            (customLegal != null && customLegal.trim().isNotEmpty)
                ? customLegal.trim()
                : company.legalText;
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'MENTION LÉGALE',
                style: pw.TextStyle(
                  fontSize: fs - 2,
                  fontWeight: pw.FontWeight.bold,
                  color: primary,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'RCCM : ${company.rccm.isEmpty ? '—' : company.rccm}',
                style: pw.TextStyle(fontSize: fs - 2, color: sub),
              ),
              pw.Text(
                'N° Contribuable : ${company.taxId.isEmpty ? '—' : company.taxId}',
                style: pw.TextStyle(fontSize: fs - 2, color: sub),
              ),
              if (legalTextToDisplay.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  legalTextToDisplay,
                  style: pw.TextStyle(
                    fontSize: fs - 2,
                    color: sub,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        );
      case LayoutElement.qrCode:
        if (!template.showPaymentQR) return pw.SizedBox();
        return _qrWidget(invoice, size: 64);
      case LayoutElement.signature:
        final showSignature =
            (customPositions['show_signature_line'] as bool?) ?? true;
        if (!showSignature) return pw.SizedBox();
        final signatoryTitle =
            (customPositions['signatory_title'] as String?)?.trim();
        final signatureImage = _decodeBase64Image(
            customPositions['signature_image'] as String?);
        return pw.Align(
          alignment: pw.Alignment.bottomLeft,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (signatureImage != null) ...[
                pw.Image(signatureImage,
                    width: 130, height: 52, fit: pw.BoxFit.contain),
                pw.SizedBox(height: 2),
              ],
              pw.Container(
                width: 120,
                height: 1,
                color: _withOpacity(text, 0.4),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                (signatoryTitle == null || signatoryTitle.isEmpty)
                    ? 'Signature & Cachet'
                    : signatoryTitle,
                style: pw.TextStyle(fontSize: fs - 2, color: sub),
              ),
            ],
          ),
        );
      default:
        return pw.SizedBox();
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  VALEURS VARIABLES
  // ═════════════════════════════════════════════════════════════
  static pw.Widget? _variableValue(
    String varName,
    double scale,
    Invoice invoice,
    Client client,
    Company company,
    InvoiceTemplate template, {
    required PdfColor primary,
    required PdfColor text,
    required double fs,
    required PdfColor sub,
  }) {
    switch (varName) {
      case 'invoice_number':
        return pw.Text(
          invoice.invoiceNumber,
          style: pw.TextStyle(
            fontSize: 12 * scale,
            fontWeight: pw.FontWeight.bold,
            color: text,
          ),
        );
      case 'issue_date':
        return pw.Text(
          _formatDate(invoice.issueDate),
          style: pw.TextStyle(fontSize: fs, color: sub),
        );
      case 'due_date':
        return pw.Text(
          _formatDate(invoice.dueDate),
          style: pw.TextStyle(fontSize: fs, color: sub),
        );
      case 'client_name':
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Facturé à :',
              style: pw.TextStyle(
                fontSize: 10 * scale,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
            pw.Text(
              client.name,
              style: pw.TextStyle(
                fontSize: 12 * scale,
                fontWeight: pw.FontWeight.bold,
                color: text,
              ),
            ),
          ],
        );
      case 'client_email':
        return pw.Text(client.email,
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'client_phone':
        return pw.Text('Tél: ${client.phone}',
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'company_name':
        return pw.Text(
          company.name,
          style: pw.TextStyle(
            fontSize: 18 * scale,
            fontWeight: pw.FontWeight.bold,
            color: primary,
          ),
        );
      case 'company_address':
        return pw.Text(company.address,
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'company_tax_id':
        return pw.Text(
          company.taxId.isEmpty ? 'N° TVA: —' : 'N° TVA: ${company.taxId}',
          style: pw.TextStyle(fontSize: fs, color: sub),
        );
      case 'subtotal':
        return _totalRowPdf('Sous-total',
            '${invoice.subtotal.toStringAsFixed(0)} FCFA', text, fs);
      case 'tax_amount':
        return _totalRowPdf('TVA (${invoice.taxRate}%)',
            '${invoice.taxAmount.toStringAsFixed(0)} FCFA', text, fs);
      case 'discount':
        if (invoice.discount <= 0) return null;
        return _totalRowPdf('Remise',
            '-${invoice.discount.toStringAsFixed(0)} FCFA', PdfColors.red, fs);
      case 'total_amount':
        return pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: _totalRowPdf(
            'TOTAL TTC',
            '${invoice.totalAmount.toStringAsFixed(0)} FCFA',
            primary,
            16 * scale,
            bold: true,
          ),
        );
      case 'status':
        return pw.Text(
          _statusLabel(invoice.status),
          style: pw.TextStyle(
            fontSize: 10 * scale,
            fontWeight: pw.FontWeight.bold,
            color: primary,
          ),
        );
      default:
        return null;
    }
  }

  static pw.Widget? _variableWidget(
    String id,
    double scale,
    Invoice invoice,
    Client client,
    Company company,
    InvoiceTemplate template, {
    Map<String, String> mapping = const {},
    required Map<String, dynamic> customPositions,
  }) {
    final primary = _getPdfColor(template.primaryColor);
    final text = _getPdfColor(template.textColor);
    final fs = (template.fontSize * scale).clamp(6, 40).toDouble();
    final sub = _withOpacity(text, 0.6);

    final mappedVar = mapping[id];
    if (mappedVar != null && mappedVar.isNotEmpty) {
      final mapped = _variableValue(
        mappedVar,
        scale,
        invoice,
        client,
        company,
        template,
        primary: primary,
        text: text,
        fs: fs,
        sub: sub,
      );
      if (mapped != null) return mapped;
    }

    switch (id) {
      case 'logo':
        if (!template.showLogo || company.logoPath.isEmpty) return null;
        final bytes = _logoBytesFromPath(company.logoPath);
        if (bytes == null) return null;
        return pw.Image(
          pw.MemoryImage(bytes),
          width: 72 * scale,
          height: 72 * scale,
          fit: pw.BoxFit.contain,
        );
      case 'company_name':
        return pw.Text(
          company.name,
          style: pw.TextStyle(
            fontSize: 18 * scale,
            fontWeight: pw.FontWeight.bold,
            color: primary,
          ),
        );
      case 'company_address':
        return pw.Text(company.address,
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'company_phone':
        return pw.Text('Tél: ${company.phone}',
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'company_email':
        return pw.Text('Email: ${company.email}',
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'company_tax_id':
        return pw.Text(
          company.taxId.isEmpty ? 'NUI: —' : 'NUI: ${company.taxId}',
          style: pw.TextStyle(fontSize: fs, color: sub),
        );
      case 'invoice_title':
        return pw.Text(
          invoice.isDevis ? 'DEVIS' : 'FACTURE',
          style: pw.TextStyle(
            fontSize: 26 * scale,
            fontWeight: pw.FontWeight.bold,
            color: primary,
          ),
          textAlign: pw.TextAlign.right,
        );
      case 'invoice_number':
        return pw.Text(
          'N° ${invoice.invoiceNumber}',
          style: pw.TextStyle(
            fontSize: 14 * scale,
            fontWeight: pw.FontWeight.bold,
            color: text,
          ),
        );
      case 'issue_date':
        return pw.Text(
          'Date : ${_formatDate(invoice.issueDate)}',
          style: pw.TextStyle(fontSize: fs, color: sub),
        );
      case 'due_date':
        return pw.Text(
          'Échéance : ${_formatDate(invoice.dueDate)}',
          style: pw.TextStyle(fontSize: fs, color: sub),
        );
      case 'status':
        return pw.Text(
          _statusLabel(invoice.status),
          style: pw.TextStyle(
            fontSize: 12 * scale,
            fontWeight: pw.FontWeight.bold,
            color: primary,
          ),
        );
      case 'client_name':
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Facturé à :',
              style: pw.TextStyle(
                fontSize: 10 * scale,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
            pw.Text(
              client.name,
              style: pw.TextStyle(
                fontSize: 12 * scale,
                fontWeight: pw.FontWeight.bold,
                color: text,
              ),
            ),
          ],
        );
      case 'client_address':
        return pw.Text(client.address,
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'client_phone':
        return pw.Text('Tél: ${client.phone}',
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'client_email':
        return pw.Text(client.email,
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'items':
        return _buildItemsTable(invoice, template);
      case 'subtotal':
        return _totalRowPdf('Sous-total',
            '${invoice.subtotal.toStringAsFixed(0)} FCFA', text, fs);
      case 'tax_amount':
        return _totalRowPdf('TVA (${invoice.taxRate}%)',
            '${invoice.taxAmount.toStringAsFixed(0)} FCFA', text, fs);
      case 'discount':
        if (invoice.discount <= 0) return null;
        return _totalRowPdf('Remise',
            '-${invoice.discount.toStringAsFixed(0)} FCFA', PdfColors.red, fs);
      case 'total_amount':
        return pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: _totalRowPdf(
            'TOTAL TTC',
            '${invoice.totalAmount.toStringAsFixed(0)} FCFA',
            primary,
            16 * scale,
            bold: true,
          ),
        );
      case 'footer':
        return _buildFooter(company, template);
      case 'qr':
        if (!template.showPaymentQR) return null;
        return _qrWidget(invoice, size: 64);
      case 'signature':
        // ✅ Aligné sur _pdfElement : image + titre personnalisé.
        final showSignature =
            (customPositions['show_signature_line'] as bool?) ?? true;
        if (!showSignature) return null;
        final signatoryTitle =
            (customPositions['signatory_title'] as String?)?.trim();
        final signatureImage = _decodeBase64Image(
            customPositions['signature_image'] as String?);
        return pw.SizedBox(
          width: 160 * scale,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (signatureImage != null) ...[
                pw.Image(signatureImage,
                    width: 130 * scale,
                    height: 52 * scale,
                    fit: pw.BoxFit.contain),
                pw.SizedBox(height: 2),
              ],
              pw.Container(height: 1, color: PdfColors.grey600),
              pw.SizedBox(height: 4),
              pw.Text(
                (signatoryTitle == null || signatoryTitle.isEmpty)
                    ? 'Signature'
                    : signatoryTitle,
                style: pw.TextStyle(
                  fontSize: 9 * scale,
                  color: _withOpacity(text, 0.6),
                ),
              ),
            ],
          ),
        );
      default:
        return null;
    }
  }

  /// 📱 QR code — fallback visuel (brancher `qr` package pour un vrai QR).
  static pw.Widget _qrWidget(Invoice invoice, {double size = 64}) {
    // Pour un vrai QR, ajoutez `qr: ^3.0.1` et décommentez :
    //
    // final data = 'https://pay.example.com/${invoice.invoiceNumber}'
    //     '?amount=${invoice.totalAmount.toStringAsFixed(0)}';
    // final qr = QrCode.fromData(
    //     data: data, errorCorrectLevel: QrErrorCorrectLevel.M);
    // final qrImage = QrImage(qr);
    // ...
    final primary = _getPdfColor(const Color(0xFF1A1A1A));
    return pw.Container(
      width: size,
      height: size,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: primary, width: 0.6),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(
        'QR\n${invoice.invoiceNumber}',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: size * 0.15,
          color: primary,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _totalRowPdf(
    String label,
    String value,
    PdfColor color,
    double fs, {
    bool bold = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(
            fontSize: fs,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fs,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  IMAGES & UTILITAIRES
  // ═════════════════════════════════════════════════════════════
  static Uint8List? _templateBackgroundBytes(InvoiceTemplate template) {
    if (template.fileData.isEmpty || template.fileType == 'pdf') return null;
    try {
      return base64Decode(template.fileData);
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _logoBytesFromPath(String logoPath) {
    try {
      if (logoPath.startsWith('data:image')) {
        final comma = logoPath.indexOf(',');
        if (comma == -1) return null;
        return base64Decode(logoPath.substring(comma + 1));
      }
      final file = File(logoPath);
      if (file.existsSync()) return file.readAsBytesSync();
      return null;
    } catch (_) {
      return null;
    }
  }

  static pw.MemoryImage? _decodeBase64Image(String? base64Data) {
    if (base64Data == null || base64Data.isEmpty) return null;
    try {
      final bytes = base64Decode(base64Data);
      if (bytes.isEmpty) return null;
      return pw.MemoryImage(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  HEADER / CLIENT / ITEMS / TOTALS / FOOTER (historique)
  // ═════════════════════════════════════════════════════════════
  static pw.Widget _buildHeader(
    Invoice invoice,
    Company company,
    InvoiceTemplate template,
  ) {
    final primaryColor = _getPdfColor(template.primaryColor);
    final textColor = _getPdfColor(template.textColor);

    pw.Widget? logoWidget;
    if (template.showLogo && company.logoPath.isNotEmpty) {
      try {
        final bytes = _logoBytesFromPath(company.logoPath);
        if (bytes != null) {
          logoWidget = pw.Image(
            pw.MemoryImage(bytes),
            width: 80,
            height: 80,
            fit: pw.BoxFit.contain,
          );
        }
      } catch (_) {
        logoWidget = null;
      }
    }

    return pw.Container(
      decoration: template.showBorder
          ? pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: primaryColor, width: 2),
              ),
            )
          : null,
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoWidget != null) ...[
                  logoWidget,
                  pw.SizedBox(width: 12),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        company.name,
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        company.address,
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: _withOpacity(textColor, 0.6),
                        ),
                      ),
                      pw.Text(
                        'Tél: ${company.phone}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: _withOpacity(textColor, 0.6),
                        ),
                      ),
                      pw.Text(
                        'Email: ${company.email}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: _withOpacity(textColor, 0.6),
                        ),
                      ),
                      pw.Text(
                        'NUI: ${company.taxId}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: _withOpacity(textColor, 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                invoice.isDevis ? 'DEVIS' : 'FACTURE',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'N° ${invoice.invoiceNumber}',
                style: pw.TextStyle(fontSize: 14, color: textColor),
              ),
              pw.Text(
                'Date: ${invoice.issueDate.day}/${invoice.issueDate.month}/${invoice.issueDate.year}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _withOpacity(textColor, 0.6),
                ),
              ),
              pw.Text(
                'Échéance: ${invoice.dueDate.day}/${invoice.dueDate.month}/${invoice.dueDate.year}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _withOpacity(textColor, 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildClientInfo(Client client, InvoiceTemplate template) {
    final primaryColor = _getPdfColor(template.primaryColor);
    final textColor = _getPdfColor(template.textColor);

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _withOpacity(primaryColor, 0.00),
        border: pw.Border.all(
          color: _withOpacity(primaryColor, 0.3),
          width: 1,
        ),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Facturé à :',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(client.name,
              style: pw.TextStyle(fontSize: 12, color: textColor)),
          pw.Text(client.address,
              style: pw.TextStyle(
                  fontSize: 10, color: _withOpacity(textColor, 0.6))),
          pw.Text('NUI: ${client.taxId}',
              style: pw.TextStyle(
                  fontSize: 10, color: _withOpacity(textColor, 0.6))),
          pw.Text('Tél: ${client.phone}',
              style: pw.TextStyle(
                  fontSize: 10, color: _withOpacity(textColor, 0.6))),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(
      Invoice invoice, InvoiceTemplate template) {
    final primaryColor = _getPdfColor(template.primaryColor);
    final textColor = _getPdfColor(template.textColor);

    return pw.Table(
      border: pw.TableBorder.all(
        color: _withOpacity(primaryColor, 0.3),
        width: 1,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: primaryColor),
          children: [
            _th('Désignation'),
            _th('Qté', align: pw.TextAlign.center),
            _th('Prix HT', align: pw.TextAlign.right),
            _th('TVA %', align: pw.TextAlign.center),
            _th('Total TTC', align: pw.TextAlign.right),
          ],
        ),
        ...invoice.items.map((item) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: _buildItemCell(item, template),
                ),
                _td(item.quantity.toString(),
                    template: template,
                    textColor: textColor,
                    align: pw.TextAlign.center),
                _td('${item.unitPrice.toStringAsFixed(0)} FCFA',
                    template: template,
                    textColor: textColor,
                    align: pw.TextAlign.right),
                _td(item.taxRate.toString(),
                    template: template,
                    textColor: textColor,
                    align: pw.TextAlign.center),
                _td('${item.total.toStringAsFixed(0)} FCFA',
                    template: template,
                    textColor: textColor,
                    align: pw.TextAlign.right,
                    bold: true),
              ],
            )),
      ],
    );
  }

  static pw.Widget _th(String label, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 11,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _td(
    String value, {
    required InvoiceTemplate template,
    required PdfColor textColor,
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: template.fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildItemCell(LineItem item, InvoiceTemplate template) {
    final textColor = _getPdfColor(template.textColor);

    pw.Widget? imageWidget;
    if (item.imageData.isNotEmpty) {
      try {
        final bytes = _logoBytesFromPath(item.imageData);
        if (bytes != null) {
          imageWidget = pw.Container(
            width: 26,
            height: 26,
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(4),
              image: pw.DecorationImage(
                image: pw.MemoryImage(bytes),
                fit: pw.BoxFit.cover,
              ),
            ),
          );
        }
      } catch (_) {
        imageWidget = null;
      }
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (imageWidget != null) ...[
          imageWidget,
          pw.SizedBox(width: 6),
        ],
        pw.Expanded(
          child: pw.Text(
            item.description,
            style: pw.TextStyle(
              fontSize: template.fontSize,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTotals(Invoice invoice, InvoiceTemplate template) {
    final primaryColor = _getPdfColor(template.primaryColor);
    final textColor = _getPdfColor(template.textColor);

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (template.showTaxDetails) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Sous-total: ',
                    style: pw.TextStyle(
                        fontSize: template.fontSize, color: textColor)),
                pw.Text('${invoice.subtotal.toStringAsFixed(0)} FCFA',
                    style: pw.TextStyle(
                        fontSize: template.fontSize, color: textColor)),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('TVA (${invoice.taxRate}%): ',
                    style: pw.TextStyle(
                        fontSize: template.fontSize, color: textColor)),
                pw.Text('${invoice.taxAmount.toStringAsFixed(0)} FCFA',
                    style: pw.TextStyle(
                        fontSize: template.fontSize, color: textColor)),
              ],
            ),
          ],
          if (invoice.discount > 0)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Remise: ',
                    style: pw.TextStyle(
                        fontSize: template.fontSize, color: PdfColors.red)),
                pw.Text('-${invoice.discount.toStringAsFixed(0)} FCFA',
                    style: pw.TextStyle(
                        fontSize: template.fontSize, color: PdfColors.red)),
              ],
            ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: _withOpacity(primaryColor, 0.1),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('TOTAL TTC: ',
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor)),
                pw.Text('${invoice.totalAmount.toStringAsFixed(0)} FCFA',
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(Company company, InvoiceTemplate template) {
    final primaryColor = _getPdfColor(template.primaryColor);
    final textColor = _getPdfColor(template.textColor);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: _withOpacity(primaryColor, 0.3)),
        pw.SizedBox(height: 8),
        if (template.showPaymentTerms)
          pw.Text(
            'Conditions de paiement: 30 jours net',
            style: pw.TextStyle(
                fontSize: 10, color: _withOpacity(textColor, 0.6)),
          ),
        pw.SizedBox(height: 4),
        pw.Text(
          company.legalText,
          style: pw.TextStyle(
            fontSize: 8,
            fontStyle: pw.FontStyle.italic,
            color: _withOpacity(textColor, 0.5),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Document généré par OHADA Invoice Pro - Conforme SYSCOHADA',
          style: pw.TextStyle(
            fontSize: 8,
            color: _withOpacity(textColor, 0.3),
          ),
        ),
        if (template.showPaymentQR) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Text(
              '📱 Paiement Mobile Money accepté',
              style: pw.TextStyle(fontSize: 10, color: primaryColor),
            ),
          ),
        ],
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  UTILITAIRES DE FORMAT
  // ═════════════════════════════════════════════════════════════
  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Payée';
      case 'sent':
        return 'En attente';
      case 'overdue':
        return 'En retard';
      case 'cancelled':
        return 'Annulée';
      default:
        return 'Brouillon';
    }
  }

  static PdfColor _getPdfColor(Color color) =>
      PdfColor(color.r, color.g, color.b);

  static PdfColor _withOpacity(PdfColor color, double opacity) =>
      PdfColor(color.red, color.green, color.blue, opacity);
}