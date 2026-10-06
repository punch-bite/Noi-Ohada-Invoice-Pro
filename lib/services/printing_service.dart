// lib/services/printing_service.dart
//
// 🖨️ Service d'impression PDF — WYSIWYG strict avec StitchA4InvoicePreview.
// 🔄 v6 :
//   • ✅ FIX « Widget won't fit into the page » : `pw.Page` (hauteur fixe)
//     utilisé pour les layouts WYSIWYG (workspace, blocks, positioned).
//     `MultiPage` reste utilisé uniquement pour le layout historique.
//   • ✅ FIX `_applyPageOverlays` : ajout d'un `SizedBox` non-positionné en
//     premier enfant du `Stack` (donne une hauteur intrinsèque).
//   • `_sanitizeText` : retire les emojis non supportés par Roboto.
//   • Support COMPLET des styles PRO :
//     - `header_style` : flat | band | bar | dark | zigzag
//     - `table_style`  : plain | zebra | cards | numbered
//     - `footer_style` : simple | contact | banner | icons
//     - `accent_border`: top | left | frame
//     - `show_thank_you` / `thank_you_text`
//     - `bank_name` / `bank_account`

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
  //  🔤 SANITIZE
  // ═════════════════════════════════════════════════════════════
  static String _sanitizeText(String input) {
    if (input.isEmpty) return input;

    const replacements = <String, String>{
      '📱': '',
      '📞': '',
      '✉': '',
      '📧': '',
      '🏦': '',
      '🏛': '',
      '⚖': '',
      '🧾': '',
      '📄': '',
      '🧧': '',
      '⭐': '*',
      '★': '*',
      '✓': 'v',
      '✔': 'v',
      '✗': 'x',
      '✘': 'x',
      '→': '->',
      '←': '<-',
      '↔': '<->',
      '€': 'EUR',
      '💶': 'EUR',
      '💵': 'USD',
      '💴': 'JPY',
      '£': 'GBP',
      '•': '-',
      '▪': '-',
      '▫': '-',
      '●': '-',
      '◦': '-',
      '·': '-',
      '—': '-',
      '–': '-',
      '…': '...',
      '“': '"',
      '”': '"',
      '‘': "'",
      '’': "'",
      '«': '"',
      '»': '"',
      '\u00A0': ' ',
      '\u202F': ' ',
      '\u200B': '',
      '\u200C': '',
      '\u200D': '',
      '\uFEFF': '',
    };

    var out = input;
    replacements.forEach((from, to) {
      out = out.replaceAll(from, to);
    });

    final buffer = StringBuffer();
    for (final rune in out.runes) {
      if (_isSafeRune(rune)) buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }

  static bool _isSafeRune(int rune) {
    if (rune == 0x09 || rune == 0x0A || rune == 0x0D) return true;
    if (rune >= 0x20 && rune <= 0x7E) return true;
    if (rune >= 0x00A0 && rune <= 0x024F) return true;
    if (rune >= 0x2000 && rune <= 0x206F) return true;
    if (rune >= 0x20A0 && rune <= 0x20CF) return true;
    if (rune >= 0x2190 && rune <= 0x21FF) return true;
    if (rune >= 0x25A0 && rune <= 0x25FF) return true;
    if (rune >= 0x2700 && rune <= 0x27BF) return true;
    if (rune == 0xFEFF) return false;
    return false;
  }

  // ═════════════════════════════════════════════════════════════
  //  🎨 HELPERS STYLE
  // ═════════════════════════════════════════════════════════════
  static String _readStyleKey(
    Map<String, dynamic> customPositions,
    String key,
    String fallback,
  ) {
    final v = customPositions[key];
    if (v is String && v.isNotEmpty) return v;
    return fallback;
  }

  static PdfColor _darkenPdf(PdfColor color, double amount) {
    return PdfColor(
      (color.red * (1 - amount)).clamp(0.0, 1.0),
      (color.green * (1 - amount)).clamp(0.0, 1.0),
      (color.blue * (1 - amount)).clamp(0.0, 1.0),
    );
  }

  /// 🎨 Applique `accent_border` (top / left / frame) dans un Stack.
  static List<pw.Widget> _accentBorderPdfs(
    String style,
    PdfColor accent,
  ) {
    switch (style) {
      case 'top':
        return [
          pw.Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: pw.Container(height: 10, color: accent),
          ),
        ];
      case 'left':
        return [
          pw.Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: pw.Container(width: 10, color: accent),
          ),
        ];
      case 'frame':
        return [
          pw.Positioned.fill(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: accent, width: 2),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ];
      default:
        return const [];
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

    final custom = await TemplateCustomService.loadCustom(template.id);
    final settings =
        invoiceSettings ?? await SettingsService.instance.loadSettings();
    final effectiveTemplate =
        SettingsService.applyToTemplate(template, settings);

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

    final bgSettings = customBackground ?? custom.background;
    Uint8List? bgBytes;
    if (bgSettings.hasCustomImage) {
      try {
        bgBytes = base64Decode(bgSettings.fileData);
      } catch (_) {
        bgBytes = null;
      }
    }

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

    // ═════════════════════════════════════════════════════════════
    //  ✅ DÉTECTION : layout WYSIWYG (page unique) vs legacy (multi-page).
    //  Les layouts WYSIWYG dessinent une page A4 à hauteur fixe. Dans un
    //  `MultiPage`, la mesure en hauteur infinie provoque « Widget won't
    //  fit into the page (Infinity) » → utiliser `pw.Page`.
    // ═════════════════════════════════════════════════════════════
    final useSinglePage = workspaceSections != null ||
        blockConfig != null ||
        positions.isNotEmpty;

    if (useSinglePage) {
      pdf.addPage(
        pw.Page(
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
              return _buildWorkspaceBlocksPdf(
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
              );
            }
            if (blockConfig != null) {
              return _buildBlockLayoutPdf(
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
              );
            }
            return _buildPositionedLayout(
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
            );
          },
        ),
      );
    } else {
      // 📄 Layout historique : pagination autorisée.
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
    }

    return pdf.save();
  }

  // ═════════════════════════════════════════════════════════════
  //  HELPERS COMMUNS
  // ═════════════════════════════════════════════════════════════
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

  /// ✅ FIX : ajoute un `SizedBox` NON-positionné en premier enfant du Stack
  /// pour lui donner une hauteur intrinsèque (sinon hauteur infinie).
  static pw.Widget _applyPageOverlays({
    required pw.Widget body,
    required InvoiceSettings settings,
    required InvoiceTemplate template,
    required bool isFreePlan,
    required Map<String, dynamic> customPositions,
  }) {
    final overlays = <pw.Widget>[
      pw.SizedBox(
        width: PdfPageFormat.a4.width,
        height: PdfPageFormat.a4.height,
      ),
      pw.Positioned.fill(child: body),
    ];

    final wmShow =
        (customPositions['show_watermark'] as bool?) ?? settings.showWatermark;
    final wmRaw = (customPositions['watermark_text'] as String?) ??
        (settings.showWatermark ? settings.watermarkText : '');
    final wmText = _sanitizeText(wmRaw);
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
          // ✅ Enfant NON-positionné → hauteur intrinsèque.
          pw.SizedBox(
            width: PdfPageFormat.a4.width,
            height: PdfPageFormat.a4.height,
          ),
          if (background != null) background,
          pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
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
          ),
        ],
      ),
      settings: settings,
      template: template,
      isFreePlan: isFreePlan,
      customPositions: const {},
    );
  }

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

    // ✅ Items : style `table_style` appliqué.
    if (key == 'items_table') {
      final style = _readStyleKey(customPositions, 'table_style', 'plain');
      return _buildItemsTableStyled(
        invoice,
        template,
        style: style,
        textColor: t,
      );
    }

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

    // 🎨 Couleur d'accent (pour les styles band/bar/dark/zigzag).
    final accent = _getPdfColor(template.primaryColor);

    final pad =
        ((customPositions['page_padding'] as num?)?.toDouble() ?? 24.0)
            .clamp(8.0, 80.0);
    const gap = 10.0;
    final contentW = pageW - pad * 2;

    // ✅ En-tête stylé (`header_style`).
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

    final qrPos = customPositions['qr_position'] as String?;
    final showQrInFooter = qrPos == 'footer' &&
        template.showPaymentQR &&
        footerWidget == null;

    final showThankYou =
        (customPositions['show_thank_you'] as bool?) ?? false;
    final thankYouText = _sanitizeText(
      (customPositions['thank_you_text'] as String?)?.trim().isNotEmpty == true
          ? (customPositions['thank_you_text'] as String).trim()
          : 'Merci pour votre confiance !',
    );
    final bankName =
        _sanitizeText((customPositions['bank_name'] as String?) ?? '');
    final bankAccount =
        _sanitizeText((customPositions['bank_account'] as String?) ?? '');

    // ✅ Bandeau contact (icons/contact/banner).
    final footerStyle =
        _readStyleKey(customPositions, 'footer_style', 'simple');
    final contactBar = footerStyle == 'icons' ||
        footerStyle == 'contact' ||
        footerStyle == 'banner';

    final page = pw.Stack(
      children: [
        pw.SizedBox(width: pageW, height: pageH),
        if (background != null) background,

        // ✅ `accent_border` : bande décorative.
        ..._accentBorderPdfs(
          _readStyleKey(customPositions, 'accent_border', ''),
          accent,
        ),

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
                if (bankName.isNotEmpty || bankAccount.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '${bankName.isNotEmpty ? 'Banque : $bankName' : ''}'
                    '${bankName.isNotEmpty && bankAccount.isNotEmpty ? '  ·  ' : ''}'
                    '${bankAccount.isNotEmpty ? 'Compte : $bankAccount' : ''}',
                    style: pw.TextStyle(fontSize: fs - 2, color: sub),
                  ),
                ],
                if (showThankYou) ...[
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Text(
                      thankYouText,
                      style: pw.TextStyle(
                        fontSize: fs + 1,
                        fontWeight: pw.FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  ),
                ],
                // ✅ Bandeau contact.
                if (contactBar) ...[
                  pw.SizedBox(height: 10),
                  _buildFooterContactPdf(
                    footerStyle: footerStyle,
                    website: _sanitizeText(company.email.isEmpty
                        ? 'www.example.com'
                        : company.email),
                    email: _sanitizeText(company.email.isEmpty
                        ? 'mail@example.com'
                        : company.email),
                    phone: _sanitizeText(company.phone.isEmpty
                        ? '+00 123 45X XX'
                        : company.phone),
                    accent: accent,
                    fs: fs,
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

  /// ✅ Bandeau contact différencié : icons / contact / banner.
  static pw.Widget _buildFooterContactPdf({
    required String footerStyle,
    required String website,
    required String email,
    required String phone,
    required PdfColor accent,
    required double fs,
  }) {
    switch (footerStyle) {
      case 'banner':
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                website,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '$email  ·  $phone',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        );

      case 'contact':
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(website,
                  style: const pw.TextStyle(
                      fontSize: 9.5, color: PdfColors.white)),
              pw.Text(email,
                  style: const pw.TextStyle(
                      fontSize: 9.5, color: PdfColors.white)),
              pw.Text(phone,
                  style: const pw.TextStyle(
                      fontSize: 9.5, color: PdfColors.white)),
            ],
          ),
        );

      case 'icons':
      default:
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('- $website',
                  style: const pw.TextStyle(
                      fontSize: 9.5, color: PdfColors.white)),
              pw.Text('- $email',
                  style: const pw.TextStyle(
                      fontSize: 9.5, color: PdfColors.white)),
              pw.Text('- $phone',
                  style: const pw.TextStyle(
                      fontSize: 9.5, color: PdfColors.white)),
            ],
          ),
        );
    }
  }

  static pw.Widget? _buildStampOverlayPdf(
    Invoice invoice,
    Map<String, dynamic> customPositions,
    double fs,
  ) {
    final invoicePaid = invoice.status == 'paid';
    final showPaidStamp =
        (customPositions['show_paid_stamp'] as bool?) ?? invoicePaid;
    if (!showPaidStamp) return null;

    final stampText = _sanitizeText(
      ((customPositions['stamp_text'] as String?) ?? 'PAYÉ').trim(),
    );
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
      left: stampX * pageW - 90 * scale,
      top: stampY * pageH - 30 * scale,
      child: pw.Transform.rotate(
        angle: rotation,
        child: pw.Opacity(
          opacity: 0.85,
          child: pw.Container(
            padding: pw.EdgeInsets.symmetric(
                horizontal: 26 * scale, vertical: 10 * scale),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0x1AFFFFFF),
              border: pw.Border.all(
                  color: _getPdfColor(stampColor), width: 4 * scale),
              borderRadius: pw.BorderRadius.circular(8 * scale),
            ),
            child: pw.Text(
              stampText,
              style: pw.TextStyle(
                fontSize: 40 * scale,
                fontWeight: pw.FontWeight.bold,
                color: _getPdfColor(stampColor),
                letterSpacing: 6 * scale,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ En-tête stylé : flat | band | bar | dark | zigzag.
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
    final style = _readStyleKey(customPositions, 'header_style', 'flat');

    // Couleurs du contenu selon le style.
    final bool coloredBg = style == 'band' ||
        style == 'bar' ||
        style == 'dark' ||
        style == 'zigzag';
    final PdfColor onAccent = coloredBg ? PdfColors.white : text;
    final PdfColor onAccentSub =
        coloredBg ? PdfColor.fromInt(0xB3FFFFFF) : sub;
    final PdfColor titleColor = coloredBg ? PdfColors.white : primary;
    final PdfColor companyColor = coloredBg ? PdfColors.white : primary;

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
      final raw = (o != null && o.trim().isNotEmpty) ? o.trim() : company.name;
      return _sanitizeText(raw);
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
                  color: companyColor,
                ),
              ),
              pw.SizedBox(height: 3),
              if (company.address.isNotEmpty)
                pw.Text(_sanitizeText(company.address),
                    style: pw.TextStyle(fontSize: fs - 1, color: onAccentSub)),
              if (company.phone.isNotEmpty)
                pw.Text(_sanitizeText('Tél: ${company.phone}'),
                    style: pw.TextStyle(fontSize: fs - 1, color: onAccentSub)),
              if (company.email.isNotEmpty)
                pw.Text(_sanitizeText(company.email),
                    style: pw.TextStyle(fontSize: fs - 1, color: onAccentSub)),
            ],
          );
        case 'invoice_title':
        default:
          final t = customPositions['invoice_title_text'] as String?;
          final rawTitle = (t != null && t.trim().isNotEmpty)
              ? t.trim()
              : (invoice.isDevis ? 'DEVIS' : 'FACTURE');
          final title = _sanitizeText(rawTitle);
          final rawSubtitle =
              customPositions['invoice_subtitle'] as String? ?? '';
          final subtitle = _sanitizeText(rawSubtitle);
          final children = <pw.Widget>[
            pw.Text(
              title,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: fs + 10,
                fontWeight: pw.FontWeight.bold,
                color: titleColor,
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
                    color: onAccentSub,
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

    final row = pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rowChildren,
    );

    // ✅ Wrap selon `header_style`.
    switch (style) {
      case 'band':
        return pw.Container(
          decoration: pw.BoxDecoration(
            color: primary,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          padding: const pw.EdgeInsets.all(12),
          child: row,
        );

      case 'bar':
        return pw.Column(
          children: [
            pw.Container(
              height: 8,
              decoration: pw.BoxDecoration(
                color: primary,
                borderRadius: pw.BorderRadius.circular(4),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Container(
              decoration: pw.BoxDecoration(color: primary),
              padding: const pw.EdgeInsets.all(12),
              child: row,
            ),
          ],
        );

      case 'dark':
        return pw.Container(
          decoration: pw.BoxDecoration(
            color: _darkenPdf(primary, 0.3),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          padding: const pw.EdgeInsets.all(12),
          child: row,
        );

      case 'zigzag':
        return pw.Column(
          children: [
            pw.Container(
              height: 45,
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  colors: [
                    primary,
                    _darkenPdf(primary, 0.2),
                  ],
                ),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              child: row,
            ),
          ],
        );

      case 'flat':
      default:
        return row;
    }
  }

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
        final legalTextToDisplay = _sanitizeText(
          (customLegal != null && customLegal.trim().isNotEmpty)
              ? customLegal.trim()
              : company.legalText,
        );
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
        final legalTextToDisplay = _sanitizeText(
          (customLegal != null && customLegal.trim().isNotEmpty)
              ? customLegal.trim()
              : company.legalText,
        );
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
                _sanitizeText(
                    'RCCM : ${company.rccm.isEmpty ? '—' : company.rccm}'),
                style: pw.TextStyle(fontSize: fs - 2, color: sub),
              ),
              pw.Text(
                _sanitizeText(
                    'N° Contribuable : ${company.taxId.isEmpty ? '—' : company.taxId}'),
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
        final rawTitle =
            (customPositions['signatory_title'] as String?)?.trim();
        final signatoryTitle =
            rawTitle == null ? null : _sanitizeText(rawTitle);
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
          _sanitizeText(invoice.invoiceNumber),
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
              _sanitizeText(client.name),
              style: pw.TextStyle(
                fontSize: 12 * scale,
                fontWeight: pw.FontWeight.bold,
                color: text,
              ),
            ),
          ],
        );
      case 'client_email':
        return pw.Text(_sanitizeText(client.email),
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'client_phone':
        return pw.Text(_sanitizeText('Tél: ${client.phone}'),
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'company_name':
        return pw.Text(
          _sanitizeText(company.name),
          style: pw.TextStyle(
            fontSize: 18 * scale,
            fontWeight: pw.FontWeight.bold,
            color: primary,
          ),
        );
      case 'company_address':
        return pw.Text(_sanitizeText(company.address),
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'company_tax_id':
        return pw.Text(
          _sanitizeText(company.taxId.isEmpty
              ? 'N° TVA: —'
              : 'N° TVA: ${company.taxId}'),
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
          _sanitizeText(company.name),
          style: pw.TextStyle(
            fontSize: 18 * scale,
            fontWeight: pw.FontWeight.bold,
            color: primary,
          ),
        );
      case 'company_address':
        return pw.Text(_sanitizeText(company.address),
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'company_phone':
        return pw.Text(_sanitizeText('Tél: ${company.phone}'),
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'company_email':
        return pw.Text(_sanitizeText('Email: ${company.email}'),
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'company_tax_id':
        return pw.Text(
          _sanitizeText(
              company.taxId.isEmpty ? 'NUI: —' : 'NUI: ${company.taxId}'),
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
          _sanitizeText('N° ${invoice.invoiceNumber}'),
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
              _sanitizeText(client.name),
              style: pw.TextStyle(
                fontSize: 12 * scale,
                fontWeight: pw.FontWeight.bold,
                color: text,
              ),
            ),
          ],
        );
      case 'client_address':
        return pw.Text(_sanitizeText(client.address),
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'client_phone':
        return pw.Text(_sanitizeText('Tél: ${client.phone}'),
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'client_email':
        return pw.Text(_sanitizeText(client.email),
            style: pw.TextStyle(fontSize: fs, color: sub));
      case 'items':
        return _buildItemsTableStyled(
          invoice,
          template,
          style: _readStyleKey(customPositions, 'table_style', 'plain'),
          textColor: text,
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
      case 'footer':
        return _buildFooter(company, template);
      case 'qr':
        if (!template.showPaymentQR) return null;
        return _qrWidget(invoice, size: 64);
      case 'signature':
        final showSignature =
            (customPositions['show_signature_line'] as bool?) ?? true;
        if (!showSignature) return null;
        final rawTitle =
            (customPositions['signatory_title'] as String?)?.trim();
        final signatoryTitle =
            rawTitle == null ? null : _sanitizeText(rawTitle);
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

  /// ✅ Tableau d'articles stylé : plain | zebra | cards | numbered.
  static pw.Widget _buildItemsTableStyled(
    Invoice invoice,
    InvoiceTemplate template, {
    required String style,
    required PdfColor textColor,
  }) {
    final primaryColor = _getPdfColor(template.primaryColor);
    final fs = template.fontSize.clamp(6.0, 40.0).toDouble();

    // Ligne d'en-tête.
    pw.Widget headerRow() => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: pw.BoxDecoration(color: primaryColor),
          child: pw.Row(
            children: [
              pw.Expanded(flex: 8, child: _th('Désignation')),
              pw.Expanded(
                  flex: 2,
                  child: _th('Qté', align: pw.TextAlign.center)),
              pw.Expanded(
                  flex: 3,
                  child: _th('Prix HT', align: pw.TextAlign.right)),
              pw.Expanded(
                  flex: 3,
                  child: _th('Total TTC', align: pw.TextAlign.right)),
            ],
          ),
        );

    pw.Widget rowCells(LineItem item, {required int index}) => pw.Row(
          children: [
            if (style == 'numbered')
              pw.SizedBox(
                width: 26,
                child: pw.Text(
                  '${index + 1}.',
                  style: pw.TextStyle(
                    fontSize: fs,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            pw.Expanded(
              flex: 8,
              child: _buildItemCell(item, template),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                item.quantity.toString(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: fs, color: textColor),
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                '${item.unitPrice.toStringAsFixed(0)} FCFA',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: fs, color: textColor),
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                '${item.total.toStringAsFixed(0)} FCFA',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: fs,
                  fontWeight: pw.FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        );

    // Cas vide.
    if (invoice.items.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          headerRow(),
          pw.SizedBox(height: 24),
        ],
      );
    }

    switch (style) {
      case 'zebra':
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            headerRow(),
            for (var i = 0; i < invoice.items.length; i++)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: i.isEven
                      ? PdfColor.fromInt(0xFFF2F2F2)
                      : PdfColors.white,
                ),
                child: rowCells(invoice.items[i], index: i),
              ),
          ],
        );

      case 'cards':
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            headerRow(),
            pw.SizedBox(height: 4),
            for (var i = 0; i < invoice.items.length; i++)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 4),
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border.all(
                      color: _withOpacity(primaryColor, 0.2)),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: rowCells(invoice.items[i], index: i),
              ),
          ],
        );

      case 'numbered':
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            headerRow(),
            for (var i = 0; i < invoice.items.length; i++)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(
                      color: _withOpacity(primaryColor, 0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: rowCells(invoice.items[i], index: i),
              ),
          ],
        );

      case 'plain':
      default:
        return pw.Table(
          border: pw.TableBorder.all(
            color: _withOpacity(primaryColor, 0.3),
            width: 1,
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(8),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FlexColumnWidth(3),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: primaryColor),
              children: [
                _th('Désignation'),
                _th('Qté', align: pw.TextAlign.center),
                _th('Prix HT', align: pw.TextAlign.right),
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
  }

  static pw.Widget _qrWidget(Invoice invoice, {double size = 64}) {
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
        'QR\n${_sanitizeText(invoice.invoiceNumber)}',
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
                        _sanitizeText(company.name),
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _sanitizeText(company.address),
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: _withOpacity(textColor, 0.6),
                        ),
                      ),
                      pw.Text(
                        _sanitizeText('Tél: ${company.phone}'),
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: _withOpacity(textColor, 0.6),
                        ),
                      ),
                      pw.Text(
                        _sanitizeText('Email: ${company.email}'),
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: _withOpacity(textColor, 0.6),
                        ),
                      ),
                      pw.Text(
                        _sanitizeText('NUI: ${company.taxId}'),
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
                _sanitizeText('N° ${invoice.invoiceNumber}'),
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
          pw.Text(_sanitizeText(client.name),
              style: pw.TextStyle(fontSize: 12, color: textColor)),
          pw.Text(_sanitizeText(client.address),
              style: pw.TextStyle(
                  fontSize: 10, color: _withOpacity(textColor, 0.6))),
          pw.Text(_sanitizeText('NUI: ${client.taxId}'),
              style: pw.TextStyle(
                  fontSize: 10, color: _withOpacity(textColor, 0.6))),
          pw.Text(_sanitizeText('Tél: ${client.phone}'),
              style: pw.TextStyle(
                  fontSize: 10, color: _withOpacity(textColor, 0.6))),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(
      Invoice invoice, InvoiceTemplate template) {
    final textColor = _getPdfColor(template.textColor);
    return _buildItemsTableStyled(
      invoice,
      template,
      style: 'plain',
      textColor: textColor,
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
    final safeDescription = _sanitizeText(item.description);

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
            safeDescription,
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
          _sanitizeText(company.legalText),
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
              'Paiement Mobile Money accepté',
              style: pw.TextStyle(fontSize: 10, color: primaryColor),
            ),
          ),
        ],
      ],
    );
  }

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