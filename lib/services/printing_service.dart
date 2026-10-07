// lib/services/printing_service.dart
//
// CHANGELOG v12 :
//   • 🐛 FIX `boundary null` et `toImage` silencieux sur Flutter Web :
//     - pixelRatio adaptatif (1.5 web, 3.0 mobile)
//     - retry automatique avec pixelRatio réduit si échec
//     - logs ultra-verbeux à chaque étape
//   • 🎯 Fallback vector automatique si capture échoue.
//   • Parité absolue conservée (Solution A + B).
//
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:noi_ohada_invoice_pro/services/template_custom_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/client.dart';
import '../models/company.dart';
import '../models/invoice.dart';
import '../models/invoice_settings.dart';
import '../models/invoice_template.dart';
import '../widgets/template_background_palette.dart';
import 'invoice_render_service.dart';

// ═══════════════════════════════════════════════════════════════════════
//  MODE DE RENDU
// ═══════════════════════════════════════════════════════════════════════
enum InvoiceRenderMode {
  vector, // 📝 texte sélectionnable
  image,  // 🖼️ capture fidèle
}

const double _kPdfScale = 595.28 / 794.0;

class PrintingService {
  // ═══════════════════════════════════════════════════════════════════
  //  API PUBLIQUE
  // ═══════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateInvoicePdf({
    required Invoice invoice,
    required Client client,
    required Company company,
    required InvoiceTemplate template,
    bool isFreePlan = false,
    Map<String, dynamic>? customPositions,
    Map<String, String>? customMapping,
    TemplateBackgroundSettings? customBackground,
    InvoiceSettings? invoiceSettings,
  }) async {
    return _generateVectorPdf(
      invoice: invoice,
      client: client,
      company: company,
      template: template,
      isFreePlan: isFreePlan,
      customPositions: customPositions,
      customMapping: customMapping,
      customBackground: customBackground,
      invoiceSettings: invoiceSettings,
    );
  }

  /// 🎯 Capture un widget Flutter (RepaintBoundary) en PNG.
  ///
  /// ✅ **pixelRatio adaptatif** :
  ///   • Web      : 1.5 (max ~1191 x 1685 px → sous toutes les limites)
  ///   • Mobile   : 3.0 (max ~2382 x 3369 px)
  ///   • Desktop  : 2.5
  ///
  /// ✅ **Retry automatique** : si `toImage()` échoue au pixelRatio demandé,
  ///    on retente avec 50% puis 25% avant d'abandonner.
  static Future<Uint8List?> captureWidgetToPng(
    GlobalKey repaintKey, {
    double? pixelRatio,
  }) async {
    // 1. Laisser Flutter peindre le RepaintBoundary.
    await Future.delayed(const Duration(milliseconds: 150));

    // 2. Vérifier le contexte.
    final ctx = repaintKey.currentContext;
    if (ctx == null) {
      debugPrint('❌ captureWidgetToPng : currentContext null '
          '(widget pas dans l\'arbre)');
      return null;
    }

    final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      debugPrint('❌ captureWidgetToPng : boundary null');
      return null;
    }
    if (!boundary.hasSize) {
      debugPrint('❌ captureWidgetToPng : boundary sans size (pas layouté)');
      return null;
    }

    debugPrint('✅ captureWidgetToPng : boundary OK, size=${boundary.size}');

    // 3. Ratio adaptatif selon plateforme.
    final primaryRatio = pixelRatio ??
        (kIsWeb
            ? 1.5
            : (Platform.isAndroid || Platform.isIOS ? 3.0 : 2.5));

    // 4. Tentatives successives avec pixelRatio décroissant.
    final ratios = <double>[
      primaryRatio,
      primaryRatio * 0.5,
      primaryRatio * 0.25,
    ];

    for (var i = 0; i < ratios.length; i++) {
      final ratio = ratios[i];
      try {
        debugPrint('🎯 Tentative ${i + 1}/${ratios.length} '
            'à pixelRatio=$ratio');

        final image = await boundary.toImage(pixelRatio: ratio);
        debugPrint('   → image générée : ${image.width}×${image.height}');

        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();

        if (byteData == null) {
          debugPrint('   → byteData null (format PNG non supporté ?)');
          continue;
        }

        final bytes = byteData.buffer.asUint8List();
        debugPrint('✅ captureWidgetToPng : ${bytes.length} octets');
        return bytes;
      } catch (e, st) {
        debugPrint('⚠️ Tentative ${i + 1} échouée à ratio=$ratio : $e');
        if (i == ratios.length - 1) {
          debugPrint('❌ Toutes les tentatives ont échoué\n$st');
        }
        // Petite pause avant retry.
        await Future.delayed(const Duration(milliseconds: 80));
      }
    }

    return null;
  }

  /// 🖼️ Génère un PDF depuis un PNG capturé (mode image).
  static Future<Uint8List> generateInvoicePdfFromCapture({
    required Uint8List pngBytes,
    bool isFreePlan = false,
  }) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(pngBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Stack(
          children: [
            pw.Positioned.fill(
              child: pw.Image(image, fit: pw.BoxFit.fill),
            ),
            if (isFreePlan)
              pw.Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: pw.Center(
                  child: pw.Text(
                    'Généré par OHADA Invoice Pro — Version Gratuite',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

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
    final pdf = await generateInvoicePdf(
      invoice: invoice,
      client: client,
      company: company,
      template: template,
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
            '${invoice.isDevis ? 'Devis' : 'Facture'}_${invoice.invoiceNumber}.pdf',
      );
    } else {
      await Printing.layoutPdf(onLayout: (_) async => pdf);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════
  static double _s(num v) => v * _kPdfScale;
  static PdfColor _c(Color c) => PdfColor(c.r, c.g, c.b);
  static PdfColor _withOpacity(PdfColor c, double op) =>
      PdfColor(c.red, c.green, c.blue, op);
  static PdfColor _darken(PdfColor c, double amount) => PdfColor(
        (c.red * (1 - amount)).clamp(0.0, 1.0),
        (c.green * (1 - amount)).clamp(0.0, 1.0),
        (c.blue * (1 - amount)).clamp(0.0, 1.0),
      );

  static String _sanitize(String input) {
    if (input.isEmpty) return input;
    final buf = StringBuffer();
    for (final rune in input.runes) {
      if (_isSafe(rune)) buf.writeCharCode(rune);
    }
    return buf.toString();
  }

  static bool _isSafe(int r) {
    if (r == 0x09 || r == 0x0A || r == 0x0D) return true;
    if (r >= 0x20 && r <= 0x7E) return true;
    if (r >= 0x00A0 && r <= 0x024F) return true;
    if (r >= 0x2000 && r <= 0x206F) return true;
    if (r >= 0x20A0 && r <= 0x20CF) return true;
    if (r >= 0x2190 && r <= 0x21FF) return true;
    if (r >= 0x25A0 && r <= 0x25FF) return true;
    if (r >= 0x2700 && r <= 0x27BF) return true;
    return false;
  }

  static Future<({pw.Font base, pw.Font bold, pw.Font medium})>
      _loadFonts() async {
    try {
      final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      final medium = await rootBundle.load('assets/fonts/Roboto-Medium.ttf');
      return (
        base: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
        medium: pw.Font.ttf(medium),
      );
    } catch (_) {
      final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final f = pw.Font.ttf(regular);
      return (base: f, bold: f, medium: f);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MODE B — RENDU VECTORIEL (inchangé v11)
  // ═══════════════════════════════════════════════════════════════════
  static Future<Uint8List> _generateVectorPdf({
    required Invoice invoice,
    required Client client,
    required Company company,
    required InvoiceTemplate template,
    bool isFreePlan = false,
    Map<String, dynamic>? customPositions,
    Map<String, String>? customMapping,
    TemplateBackgroundSettings? customBackground,
    InvoiceSettings? invoiceSettings,
  }) async {
    final pdf = pw.Document();
    final fonts = await _loadFonts();

    final render = await InvoiceRenderService.resolveRenderState(
      template: template,
      customPositions: customPositions,
      customMapping: customMapping,
      backgroundSettings: customBackground,
      invoiceSettings: invoiceSettings,
    );

    final settings = render.invoiceSettings;
    final positions = render.positions;
    final bgSettings = render.backgroundSettings;
    Uint8List? bgBytes = render.backgroundImage;
    final preset = bgBytes == null && bgSettings.presetId.isNotEmpty
        ? MultiBackgroundPreset.byId(bgSettings.presetId)
        : null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: fonts.base,
          bold: fonts.bold,
          italic: fonts.medium,
          boldItalic: fonts.bold,
        ),
        margin: pw.EdgeInsets.zero,
        build: (ctx) => _renderA4(
          invoice: invoice,
          client: client,
          company: company,
          template: render.effectiveTemplate,
          positions: positions,
          settings: settings,
          bgBytes: bgBytes,
          preset: preset,
          bgOpacity: bgSettings.opacity,
          isFreePlan: isFreePlan,
        ),
      ),
    );

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  RENDU VECTORIEL A4
  // ═══════════════════════════════════════════════════════════════════
  static pw.Widget _renderA4({
    required Invoice invoice,
    required Client client,
    required Company company,
    required InvoiceTemplate template,
    required Map<String, dynamic> positions,
    required InvoiceSettings settings,
    required Uint8List? bgBytes,
    required MultiBackgroundPreset? preset,
    required double bgOpacity,
    required bool isFreePlan,
  }) {
    final pageW = PdfPageFormat.a4.width;
    final pageH = PdfPageFormat.a4.height;
    final pagePadding =
        (positions['page_padding'] as num?)?.toDouble() ?? 32.0;

    final primary = _c(template.primaryColor);
    final textColor = _c(template.textColor);
    final bgColor = _c(template.backgroundColor);
    final fs = template.fontSize.clamp(6.0, 40.0);
    final accentBorder = positions['accent_border']?.toString() ?? '';

    pw.Widget? background;
    if (bgBytes != null) {
      background = pw.Positioned.fill(
        child: pw.Opacity(
          opacity: bgOpacity.clamp(0.0, 1.0),
          child: pw.Image(pw.MemoryImage(bgBytes), fit: pw.BoxFit.fill),
        ),
      );
    } else if (preset != null) {
      background = pw.Positioned.fill(
        child: pw.Opacity(
          opacity: bgOpacity.clamp(0.0, 1.0),
          child: preset.toPdfWidget(),
        ),
      );
    }

    return pw.Container(
      width: pageW,
      height: pageH,
      decoration: pw.BoxDecoration(color: bgColor),
      child: pw.Stack(
        children: [
          pw.SizedBox(width: pageW, height: pageH),
          if (background != null) background,
          ..._accentBorderWidgets(accentBorder, primary, pageW, pageH),
          pw.Positioned.fill(
            child: pw.Padding(
              padding: pw.EdgeInsets.all(_s(pagePadding)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(
                    invoice: invoice,
                    company: company,
                    template: template,
                    positions: positions,
                    primary: primary,
                    textColor: textColor,
                    fs: fs,
                  ),
                  pw.SizedBox(height: _s(16)),
                  _buildBody(
                    invoice: invoice,
                    client: client,
                    company: company,
                    template: template,
                    settings: settings,
                    positions: positions,
                    primary: primary,
                    textColor: textColor,
                    fs: fs,
                  ),
                  pw.Spacer(),
                  _buildFooter(
                    positions: positions,
                    primary: primary,
                    textColor: textColor,
                    fs: fs,
                  ),
                ],
              ),
            ),
          ),
          if ((positions['show_paid_stamp'] as bool? ?? false) &&
              invoice.status == 'paid')
            _buildPaidStamp(positions, pageW, pageH),
          if (settings.showWatermark && settings.watermarkText.isNotEmpty)
            _buildWatermark(settings, textColor),
          if (isFreePlan)
            pw.Positioned(
              bottom: _s(6),
              left: 0,
              right: 0,
              child: pw.Center(
                child: pw.Text(
                  'Généré par OHADA Invoice Pro — Version Gratuite',
                  style: pw.TextStyle(
                    fontSize: _s(8),
                    color: _withOpacity(textColor, 0.4),
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static List<pw.Widget> _accentBorderWidgets(
    String style,
    PdfColor accent,
    double pageW,
    double pageH,
  ) {
    switch (style) {
      case 'top':
        return [
          pw.Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: pw.Container(
              height: _s(8),
              decoration: pw.BoxDecoration(color: accent),
            ),
          ),
        ];
      case 'left':
        return [
          pw.Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: pw.Container(
              width: _s(8),
              decoration: pw.BoxDecoration(color: accent),
            ),
          ),
        ];
      case 'frame':
        return [
          pw.Positioned.fill(
            child: pw.Padding(
              padding: pw.EdgeInsets.all(_s(6)),
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: accent, width: _s(2)),
                  borderRadius: pw.BorderRadius.circular(_s(4)),
                ),
              ),
            ),
          ),
        ];
      case 'stripes_bottom':
        return [
          pw.Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: pw.SizedBox(
              height: _s(14),
              child: _rainbowStrip(accent, 20),
            ),
          ),
        ];
      default:
        return const [];
    }
  }

  static pw.Widget _rainbowStrip(PdfColor accent, int stripes) {
    const colors = [0xFFE8A33D, 0xFF1B4965, 0xFFE67E22, 0xFF111111];
    return pw.Row(
      children: [
        for (var i = 0; i < stripes; i++)
          pw.Expanded(
            child: pw.Container(
              decoration:
                  pw.BoxDecoration(color: PdfColor.fromInt(colors[i % colors.length])),
            ),
          ),
      ],
    );
  }

  // ── En-tête ──
  static pw.Widget _buildHeader({
    required Invoice invoice,
    required Company company,
    required InvoiceTemplate template,
    required Map<String, dynamic> positions,
    required PdfColor primary,
    required PdfColor textColor,
    required double fs,
  }) {
    final headerStyle = positions['header_style']?.toString() ?? 'flat';
    final headerSections =
        InvoiceTemplate.decodeSections(positions['header_sections']);
    final sections = headerSections.isNotEmpty
        ? headerSections
        : [
            ['logo', 'company_info', 'invoice_title'],
          ];

    final widthMap = positions['header_widths'] as Map? ?? {};
    final alignMap = positions['header_alignments'] as Map? ?? {};
    final visMap = positions['header_visibility'] as Map? ?? {};

    double widthOf(String k) => widthMap[k] is num
        ? (widthMap[k] as num).toDouble().clamp(0.4, 3.0)
        : 1.0;
    String alignOf(String k) =>
        alignMap[k]?.toString() ?? (k == 'invoice_title' ? 'right' : 'left');
    bool visOf(String k) => visMap[k] is bool ? visMap[k] as bool : true;

    final hasFilledHeader = headerStyle == 'dark' ||
        headerStyle == 'band' ||
        headerStyle == 'wave' ||
        headerStyle == 'split_orange_left';
    final onColor = hasFilledHeader ? PdfColors.white : textColor;

    pw.Widget buildRow(int r) {
      final keys = sections[r];
      final children = <pw.Widget>[];
      for (var i = 0; i < keys.length; i++) {
        final key = keys[i];
        if (i > 0) children.add(pw.SizedBox(width: _s(8)));
        if (!visOf(key)) continue;
        final flex = (widthOf(key) * 10).round().clamp(4, 30);
        children.add(pw.Expanded(
          flex: flex,
          child: _headerCol(
            key: key,
            company: company,
            positions: positions,
            onColor: onColor,
            primary: primary,
            textColor: textColor,
            fs: fs,
            align: alignOf(key),
          ),
        ));
      }
      return pw.Padding(
        padding: pw.EdgeInsets.only(bottom: _s(4)),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: children,
        ),
      );
    }

    final rows = <pw.Widget>[];
    for (var r = 0; r < sections.length; r++) {
      rows.add(buildRow(r));
    }

    final content = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: rows,
    );

    switch (headerStyle) {
      case 'dark':
        return pw.Container(
          decoration: pw.BoxDecoration(
            color: _darken(primary, 0.3),
            borderRadius: pw.BorderRadius.circular(_s(4)),
          ),
          padding: pw.EdgeInsets.all(_s(6)),
          child: content,
        );
      case 'band':
        return pw.Container(
          decoration: pw.BoxDecoration(
            color: primary,
            borderRadius: pw.BorderRadius.circular(_s(4)),
          ),
          padding: pw.EdgeInsets.all(_s(6)),
          child: content,
        );
      case 'wave':
      case 'split_orange_left':
        return pw.Container(
          height: _s(90),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFF1B4965),
            borderRadius: pw.BorderRadius.circular(_s(4)),
          ),
          child: pw.Stack(
            children: [
              pw.Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: pw.Container(
                  width: _s(240),
                  decoration: pw.BoxDecoration(
                    color: primary,
                    borderRadius: pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(_s(4)),
                      bottomLeft: pw.Radius.circular(_s(4)),
                    ),
                  ),
                ),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(_s(6)),
                child: content,
              ),
            ],
          ),
        );
      case 'orange_band_right':
        return pw.Container(
          decoration: pw.BoxDecoration(
            color: _withOpacity(primary, 0.08),
            border: pw.Border(
              right: pw.BorderSide(color: primary, width: _s(6)),
            ),
            borderRadius: pw.BorderRadius.circular(_s(4)),
          ),
          padding: pw.EdgeInsets.all(_s(6)),
          child: content,
        );
      default:
        return pw.Container(
          padding: pw.EdgeInsets.all(_s(6)),
          child: content,
        );
    }
  }

  static pw.Widget _headerCol({
    required String key,
    required Company company,
    required Map<String, dynamic> positions,
    required PdfColor onColor,
    required PdfColor primary,
    required PdfColor textColor,
    required double fs,
    required String align,
  }) {
    switch (key) {
      case 'logo':
        return _logoPdf(positions, company, onColor, primary);
      case 'company_info':
        final nameOverride = positions['company_name']?.toString();
        final name = (nameOverride != null && nameOverride.trim().isNotEmpty)
            ? nameOverride.trim()
            : company.name;
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            if (name.isNotEmpty)
              pw.Text(
                _sanitize(name),
                style: pw.TextStyle(
                  fontSize: _s(fs * 1.15),
                  fontWeight: pw.FontWeight.bold,
                  color: onColor,
                ),
              ),
            if (company.address.isNotEmpty)
              _companyLinePdf(company.address, onColor, fs),
            if (company.phone.isNotEmpty)
              _companyLinePdf(company.phone, onColor, fs),
            if (company.email.isNotEmpty)
              _companyLinePdf(company.email, onColor, fs),
          ],
        );
      case 'invoice_title':
        final titleOverride = positions['invoice_title_text']?.toString();
        final title =
            (titleOverride != null && titleOverride.trim().isNotEmpty)
                ? titleOverride.trim()
                : 'INVOICE';
        final sub = positions['invoice_subtitle']?.toString() ?? '';
        return pw.Column(
          crossAxisAlignment: align == 'center'
              ? pw.CrossAxisAlignment.center
              : (align == 'right'
                  ? pw.CrossAxisAlignment.end
                  : pw.CrossAxisAlignment.start),
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              _sanitize(title),
              style: pw.TextStyle(
                fontSize: _s(fs * 2.4),
                fontWeight: pw.FontWeight.bold,
                color: onColor,
                letterSpacing: _s(-1),
              ),
              textAlign: align == 'center'
                  ? pw.TextAlign.center
                  : (align == 'right'
                      ? pw.TextAlign.right
                      : pw.TextAlign.left),
            ),
            if (sub.trim().isNotEmpty)
              pw.Padding(
                padding: pw.EdgeInsets.only(top: _s(2)),
                child: pw.Text(
                  _sanitize(sub.trim()),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: _s(fs * 0.85),
                    color: _withOpacity(onColor, 0.7),
                  ),
                ),
              ),
          ],
        );
      default:
        return pw.SizedBox();
    }
  }

  static pw.Widget _companyLinePdf(String text, PdfColor onColor, double fs) =>
      pw.Padding(
        padding: pw.EdgeInsets.only(top: _s(1)),
        child: pw.Text(
          _sanitize(text),
          style: pw.TextStyle(
            fontSize: _s(fs * 0.8),
            color: _withOpacity(onColor, 0.7),
          ),
        ),
      );

  static pw.Widget _logoPdf(
    Map<String, dynamic> positions,
    Company company,
    PdfColor onColor,
    PdfColor primary,
  ) {
    final custom = positions['custom_logo_base64']?.toString();
    Uint8List? bytes;
    if (custom != null && custom.isNotEmpty) {
      try {
        bytes = base64Decode(custom);
      } catch (_) {}
    }
    bytes ??= _logoBytes(company.logoPath);

    final size = _s((positions['logo_size'] as num?)?.toDouble() ?? 46);

    if (bytes != null) {
      return pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: pw.Container(
          width: size,
          height: size,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            color: _withOpacity(onColor, 0.10),
          ),
          child: pw.ClipOval(
            child: pw.Image(
              pw.MemoryImage(bytes),
              width: size,
              height: size,
              fit: pw.BoxFit.cover,
            ),
          ),
        ),
      );
    }

    final initials = company.name.isNotEmpty
        ? company.name
            .substring(0, company.name.length >= 3 ? 3 : company.name.length)
            .toUpperCase()
        : 'ABC';

    return pw.Align(
      alignment: pw.Alignment.centerLeft,
      child: pw.Container(
        width: size,
        height: size,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          color: _withOpacity(primary, 0.10),
          border: pw.Border.all(
            color: _withOpacity(primary, 0.3),
            width: _s(1),
          ),
        ),
        child: pw.Text(
          initials,
          style: pw.TextStyle(
            color: primary,
            fontWeight: pw.FontWeight.bold,
            fontSize: size * 0.30,
          ),
        ),
      ),
    );
  }

  // ── Corps ──
  static pw.Widget _buildBody({
    required Invoice invoice,
    required Client client,
    required Company company,
    required InvoiceTemplate template,
    required InvoiceSettings settings,
    required Map<String, dynamic> positions,
    required PdfColor primary,
    required PdfColor textColor,
    required double fs,
  }) {
    final bodySections =
        InvoiceTemplate.decodeSections(positions['blocks_sections']);
    if (bodySections.isEmpty) return pw.SizedBox();

    final visMap = positions['block_visibility'] as Map? ?? {};
    final alignMap = positions['block_alignment'] as Map? ?? {};
    final widthMap = positions['block_widths'] as Map? ?? {};

    bool visOf(String k) => visMap[k] is bool ? visMap[k] as bool : true;
    String alignOf(String k) => alignMap[k]?.toString() ?? 'left';
    double widthOf(String k) => widthMap[k] is num
        ? (widthMap[k] as num).toDouble().clamp(0.3, 3.0)
        : 1.0;

    final rows = <pw.Widget>[];
    for (final section in bodySections) {
      final visible = section.where(visOf).toList();
      if (visible.isEmpty) continue;

      final totalW = visible.fold<double>(0, (a, k) => a + widthOf(k));
      final avail =
          PdfPageFormat.a4.width - _s(64) - _s(8) * (visible.length - 1);
      final children = <pw.Widget>[];

      for (var i = 0; i < visible.length; i++) {
        if (i > 0) children.add(pw.SizedBox(width: _s(8)));
        final key = visible[i];

        if (key.startsWith('__spacer')) {
          final h = (positions['spacer_sizes'] as Map?)?[key];
          final size = h is num ? h.toDouble().clamp(10.0, 400.0) : 40.0;
          children.add(pw.Container(
            width: _s(30),
            height: _s(size),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: _withOpacity(textColor, 0.08),
                width: _s(0.5),
              ),
              borderRadius: pw.BorderRadius.circular(_s(4)),
            ),
          ));
          continue;
        }

        if (key.startsWith('__divider')) {
          final style = (positions['divider_styles'] as Map?)?[key]?.toString() ??
              'solid';
          children.add(pw.Expanded(child: _dividerPdf(style, textColor)));
          continue;
        }

        final w = totalW == 0 ? avail : avail * widthOf(key) / totalW;
        children.add(pw.SizedBox(
          width: w,
          child: pw.Align(
            alignment: alignOf(key) == 'center'
                ? pw.Alignment.topCenter
                : (alignOf(key) == 'right'
                    ? pw.Alignment.topRight
                    : pw.Alignment.topLeft),
            child: _bodyBlock(
              key: key,
              invoice: invoice,
              client: client,
              company: company,
              template: template,
              settings: settings,
              positions: positions,
              primary: primary,
              textColor: textColor,
              fs: fs,
            ),
          ),
        ));
      }

      rows.add(pw.Container(
        margin: pw.EdgeInsets.only(bottom: _s(10)),
        padding: pw.EdgeInsets.symmetric(vertical: _s(4), horizontal: _s(2)),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: children.isEmpty ? [pw.SizedBox()] : children,
        ),
      ));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  static pw.Widget _dividerPdf(String style, PdfColor textColor) {
    switch (style) {
      case 'dashed':
        return pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: _s(6)),
          child: pw.Row(
            children: List.generate(
              30,
              (_) => pw.Expanded(
                child: pw.Padding(
                  padding: pw.EdgeInsets.symmetric(horizontal: _s(2)),
                  child: pw.Container(
                    height: _s(1.5),
                    decoration: pw.BoxDecoration(
                      color: _withOpacity(textColor, 0.35),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      case 'dots':
        return pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: _s(6)),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: List.generate(
              20,
              (_) => pw.Container(
                width: _s(3),
                height: _s(3),
                margin: pw.EdgeInsets.symmetric(horizontal: _s(3)),
                decoration: pw.BoxDecoration(
                  color: _withOpacity(textColor, 0.35),
                  shape: pw.BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      default:
        return pw.Container(
          height: _s(1),
          margin: pw.EdgeInsets.symmetric(vertical: _s(6)),
          decoration: pw.BoxDecoration(
            color: _withOpacity(textColor, 0.25),
          ),
        );
    }
  }

  static pw.Widget _bodyBlock({
    required String key,
    required Invoice invoice,
    required Client client,
    required Company company,
    required InvoiceTemplate template,
    required InvoiceSettings settings,
    required Map<String, dynamic> positions,
    required PdfColor primary,
    required PdfColor textColor,
    required double fs,
  }) {
    switch (key) {
      case 'billing_info':
        return _billingPdf(client, primary, textColor, fs, positions);
      case 'invoice_meta':
        return _metaPdf(invoice, textColor, fs);
      case 'items_table':
        return _itemsTablePdf(
          invoice,
          positions['table_style']?.toString() ?? 'plain',
          primary,
          textColor,
          fs,
        );
      case 'totals':
        return _totalsPdf(invoice, settings, primary, textColor, fs);
      case 'legal_mentions':
        return _legalPdf(company, settings, textColor, primary, fs, positions);
      case 'signature_block':
        return _signaturePdf(positions, textColor, fs);
      case 'qr_block':
        if (!template.showPaymentQR) return pw.SizedBox();
        return _qrPdf(textColor);
      default:
        if (key.startsWith('text_')) {
          return _textBlockPdf(key, positions, textColor, fs);
        }
        return pw.SizedBox();
    }
  }

  static pw.Widget _billingPdf(
    Client client,
    PdfColor primary,
    PdfColor textColor,
    double fs,
    Map<String, dynamic> positions,
  ) {
    final clientOverride = positions['client_name']?.toString();
    final name = (clientOverride != null && clientOverride.trim().isNotEmpty)
        ? clientOverride.trim()
        : client.name;
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: _s(4)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            'INVOICE TO:',
            style: pw.TextStyle(
              fontSize: _s(fs * 0.85),
              fontWeight: pw.FontWeight.bold,
              color: primary,
              letterSpacing: _s(0.6),
            ),
          ),
          pw.SizedBox(height: _s(4)),
          pw.Text(
            _sanitize(name),
            style: pw.TextStyle(
              fontSize: _s(fs),
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
          if (client.address.isNotEmpty)
            pw.Text(
              _sanitize(client.address),
              style: pw.TextStyle(
                fontSize: _s(fs * 0.85),
                color: _withOpacity(textColor, 0.75),
              ),
            ),
          if (client.phone.isNotEmpty)
            pw.Text(
              _sanitize(client.phone),
              style: pw.TextStyle(
                fontSize: _s(fs * 0.85),
                color: _withOpacity(textColor, 0.75),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _metaPdf(Invoice invoice, PdfColor textColor, double fs) =>
      pw.Padding(
        padding: pw.EdgeInsets.symmetric(vertical: _s(4)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            _metaRowPdf('Invoice #', invoice.invoiceNumber, textColor, fs),
            _metaRowPdf('Date', _fmtDate(invoice.issueDate), textColor, fs),
            _metaRowPdf('Due Date', _fmtDate(invoice.dueDate), textColor, fs),
          ],
        ),
      );

  static pw.Widget _metaRowPdf(
    String label,
    String value,
    PdfColor textColor,
    double fs,
  ) =>
      pw.Padding(
        padding: pw.EdgeInsets.only(bottom: _s(3)),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              '$label : ',
              style: pw.TextStyle(
                fontSize: _s(fs * 0.8),
                fontWeight: pw.FontWeight.bold,
                color: _withOpacity(textColor, 0.65),
              ),
            ),
            pw.Text(
              _sanitize(value),
              style: pw.TextStyle(fontSize: _s(fs * 0.85), color: textColor),
            ),
          ],
        ),
      );

  static pw.Widget _itemsTablePdf(
    Invoice invoice,
    String style,
    PdfColor primary,
    PdfColor textColor,
    double fs,
  ) {
    const maxRows = 12;
    final items = invoice.items;
    final visible = items.take(maxRows).toList();
    final hidden = items.length - visible.length;

    final headerBg = style == 'dark_header'
        ? const PdfColor.fromInt(0xFF1B4965)
        : primary;

    // ✅ FIX : pas de `color:` + `decoration:` simultanés.
    final header = pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: _s(10), vertical: _s(8)),
      decoration: pw.BoxDecoration(
        color: headerBg,
        borderRadius: pw.BorderRadius.only(
          topLeft: pw.Radius.circular(_s(4)),
          topRight: pw.Radius.circular(_s(4)),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 1, child: _thPdf('N°')),
          pw.Expanded(flex: 5, child: _thPdf('ITEM DESCRIPTION')),
          pw.Expanded(
              flex: 2, child: _thPdf('QTY', align: pw.TextAlign.center)),
          pw.Expanded(
              flex: 2, child: _thPdf('PRICE', align: pw.TextAlign.right)),
          pw.Expanded(
              flex: 2, child: _thPdf('TOTAL', align: pw.TextAlign.right)),
        ],
      ),
    );

    final rows = <pw.Widget>[];
    for (var i = 0; i < visible.length; i++) {
      final item = visible[i];
      final isAlt = style == 'alternate_dark' && i.isEven;
      rows.add(pw.Container(
        padding:
            pw.EdgeInsets.symmetric(horizontal: _s(10), vertical: _s(8)),
        decoration: pw.BoxDecoration(
          color: isAlt ? _withOpacity(primary, 0.05) : null,
          border: pw.Border(
            bottom: pw.BorderSide(
              color: _withOpacity(textColor, 0.08),
              width: _s(0.5),
            ),
          ),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(flex: 1, child: _tdPdf('${i + 1}', textColor, fs)),
            pw.Expanded(
                flex: 5,
                child: _tdPdf(_sanitize(item.description), textColor, fs)),
            pw.Expanded(
                flex: 2,
                child: _tdPdf('${item.quantity}', textColor, fs,
                    align: pw.TextAlign.center)),
            pw.Expanded(
                flex: 2,
                child: _tdPdf(_fmtNum(item.unitPrice), textColor, fs,
                    align: pw.TextAlign.right)),
            pw.Expanded(
                flex: 2,
                child: _tdPdf(_fmtNum(item.total), textColor, fs,
                    align: pw.TextAlign.right, bold: true)),
          ],
        ),
      ));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        header,
        ...rows,
        if (hidden > 0)
          pw.Padding(
            padding: pw.EdgeInsets.only(top: _s(4)),
            child: pw.Text(
              '+ $hidden autre(s) article(s)…',
              style: pw.TextStyle(
                fontSize: _s(fs * 0.75),
                color: _withOpacity(textColor, 0.5),
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  static pw.Widget _thPdf(String t,
          {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Text(
        t,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: _s(10),
          letterSpacing: _s(0.4),
        ),
      );

  static pw.Widget _tdPdf(
    String t,
    PdfColor color,
    double fs, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
  }) =>
      pw.Text(
        t,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: _s(10.5),
          color: color,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      );

  static pw.Widget _totalsPdf(
    Invoice invoice,
    InvoiceSettings settings,
    PdfColor primary,
    PdfColor textColor,
    double fs,
  ) =>
      pw.Padding(
        padding: pw.EdgeInsets.symmetric(vertical: _s(6)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            _totalLinePdf(
                'Sub Total', _fmtNum(invoice.subtotal), textColor, fs),
            if (settings.showTaxDetails)
              _totalLinePdf(
                  'Tax (${invoice.taxRate.toStringAsFixed(0)}%)',
                  _fmtNum(invoice.taxAmount),
                  textColor,
                  fs),
            if (invoice.discount > 0)
              _totalLinePdf(
                  'Discount', _fmtNum(invoice.discount), textColor, fs),
            pw.SizedBox(height: _s(4)),
            pw.Container(
              padding: pw.EdgeInsets.symmetric(
                  horizontal: _s(12), vertical: _s(8)),
              decoration: pw.BoxDecoration(
                color: primary,
                borderRadius: pw.BorderRadius.circular(_s(4)),
              ),
              child: pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: _s(fs * 0.95),
                    ),
                  ),
                  pw.SizedBox(width: _s(12)),
                  pw.Text(
                    _fmtNum(invoice.totalAmount),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: _s(fs * 1.1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  static pw.Widget _totalLinePdf(
    String label,
    String value,
    PdfColor textColor,
    double fs,
  ) =>
      pw.Padding(
        padding: pw.EdgeInsets.only(bottom: _s(3)),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              '$label : ',
              style: pw.TextStyle(
                fontSize: _s(fs * 0.85),
                color: _withOpacity(textColor, 0.7),
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: _s(fs * 0.9), color: textColor),
            ),
          ],
        ),
      );

  static pw.Widget _legalPdf(
    Company company,
    InvoiceSettings settings,
    PdfColor textColor,
    PdfColor primary,
    double fs,
    Map<String, dynamic> positions,
  ) {
    final custom = positions['custom_legal_text']?.toString();
    final legal = (custom != null && custom.trim().isNotEmpty)
        ? custom.trim()
        : company.legalText;
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: _s(6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (settings.showPaymentTerms) ...[
            pw.Text(
              'TERMS & CONDITIONS',
              style: pw.TextStyle(
                fontSize: _s(fs * 0.85),
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
            pw.SizedBox(height: _s(4)),
          ],
          if (legal.isNotEmpty)
            pw.Text(
              _sanitize(legal),
              style: pw.TextStyle(
                fontSize: _s(fs * 0.75),
                color: _withOpacity(textColor, 0.75),
                lineSpacing: _s(2),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _signaturePdf(
    Map<String, dynamic> positions,
    PdfColor textColor,
    double fs,
  ) {
    final show = positions['show_signature_line'] as bool? ?? true;
    if (!show) return pw.SizedBox();

    final titleOverride = positions['signatory_title']?.toString();
    final title = (titleOverride != null && titleOverride.trim().isNotEmpty)
        ? titleOverride.trim()
        : 'Authorized Sign';

    final sigB64 = positions['signature_image']?.toString();
    Uint8List? sigBytes;
    if (sigB64 != null && sigB64.isNotEmpty) {
      try {
        sigBytes = base64Decode(sigB64);
      } catch (_) {}
    }

    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: _s(6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (sigBytes != null)
            pw.Padding(
              padding: pw.EdgeInsets.only(bottom: _s(4)),
              child: pw.Image(
                pw.MemoryImage(sigBytes),
                width: _s(120),
                height: _s(44),
                fit: pw.BoxFit.contain,
              ),
            ),
          pw.Container(
            width: _s(110),
            height: _s(1),
            decoration: pw.BoxDecoration(
              color: _withOpacity(textColor, 0.5),
            ),
          ),
          pw.SizedBox(height: _s(3)),
          pw.Text(
            _sanitize(title),
            style: pw.TextStyle(
              fontSize: _s(fs * 0.75),
              color: _withOpacity(textColor, 0.75),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _qrPdf(PdfColor textColor) => pw.Container(
        width: _s(60),
        height: _s(60),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
            color: _withOpacity(textColor, 0.3),
            width: _s(0.5),
          ),
          borderRadius: pw.BorderRadius.circular(_s(4)),
        ),
        child: pw.Text(
          'QR',
          style: pw.TextStyle(
            fontSize: _s(14),
            fontWeight: pw.FontWeight.bold,
            color: textColor,
          ),
        ),
      );

  static pw.Widget _textBlockPdf(
    String key,
    Map<String, dynamic> positions,
    PdfColor textColor,
    double fs,
  ) {
    final rawParas = positions['custom_paragraphs'];
    if (rawParas is Map && rawParas[key] is List) {
      final paras = rawParas[key] as List;
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          for (final p in paras)
            if (p is Map && (p['text']?.toString() ?? '').isNotEmpty)
              _paragraphPdf(
                text: p['text'].toString(),
                align: p['align']?.toString() ?? 'left',
                bold: p['bold'] == true,
                italic: p['italic'] == true,
                textColor: textColor,
                fs: fs,
              ),
        ],
      );
    }
    final rawTexts = positions['custom_texts'];
    if (rawTexts is Map && rawTexts[key] is String) {
      final t = (rawTexts[key] as String).trim();
      if (t.isEmpty) return pw.SizedBox();
      return pw.Text(
        _sanitize(t),
        style: pw.TextStyle(fontSize: _s(fs * 0.85), color: textColor),
      );
    }
    return pw.SizedBox();
  }

  static pw.Widget _paragraphPdf({
    required String text,
    required String align,
    required bool bold,
    required bool italic,
    required PdfColor textColor,
    required double fs,
  }) {
    final ta = align == 'center'
        ? pw.TextAlign.center
        : (align == 'right'
            ? pw.TextAlign.right
            : (align == 'justify'
                ? pw.TextAlign.justify
                : pw.TextAlign.left));
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: _s(2)),
      child: pw.Text(
        _sanitize(text),
        textAlign: ta,
        style: pw.TextStyle(
          fontSize: _s(fs * 0.85),
          color: textColor,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
        ),
      ),
    );
  }

  // ── Pied ──
  static pw.Widget _buildFooter({
    required Map<String, dynamic> positions,
    required PdfColor primary,
    required PdfColor textColor,
    required double fs,
  }) {
    final bankName = positions['bank_name']?.toString() ?? '';
    final bankAccount = positions['bank_account']?.toString() ?? '';
    final showThanks = positions['show_thank_you'] as bool? ?? false;
    final thanksText = positions['thank_you_text']?.toString() ?? '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (bankName.isNotEmpty || bankAccount.isNotEmpty)
          pw.Padding(
            padding: pw.EdgeInsets.only(top: _s(8)),
            child: pw.Text(
              '${bankName} ${bankAccount}'.trim(),
              style: pw.TextStyle(
                fontSize: _s(fs * 0.75),
                color: _withOpacity(textColor, 0.65),
              ),
            ),
          ),
        if (showThanks)
          pw.Padding(
            padding: pw.EdgeInsets.only(top: _s(10)),
            child: pw.Container(
              padding: pw.EdgeInsets.symmetric(
                  horizontal: _s(12), vertical: _s(8)),
              decoration: pw.BoxDecoration(
                color: primary,
                borderRadius: pw.BorderRadius.circular(_s(4)),
              ),
              child: pw.Center(
                child: pw.Text(
                  _sanitize(thanksText.isNotEmpty
                      ? thanksText
                      : 'Merci pour votre confiance !'),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: _s(12),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Overlays ──
  static pw.Widget _buildPaidStamp(
    Map<String, dynamic> positions,
    double pageW,
    double pageH,
  ) {
    final sx =
        ((positions['stamp_x'] as num?)?.toDouble() ?? 0.5).clamp(0.05, 0.95);
    final sy =
        ((positions['stamp_y'] as num?)?.toDouble() ?? 0.5).clamp(0.05, 0.95);
    final rot = ((positions['stamp_rotation'] as num?)?.toDouble() ?? -0.15);
    final sc = ((positions['stamp_scale'] as num?)?.toDouble() ?? 1.0)
        .clamp(0.5, 3.0);
    final text = _sanitize(positions['stamp_text']?.toString() ?? 'PAYÉ');

    return pw.Positioned(
      left: sx * pageW - _s(90) * sc,
      top: sy * pageH - _s(30) * sc,
      child: pw.Transform.rotate(
        angle: rot,
        child: pw.Opacity(
          opacity: 0.85,
          child: pw.Container(
            padding: pw.EdgeInsets.symmetric(
              horizontal: _s(26) * sc,
              vertical: _s(10) * sc,
            ),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0x1AFFFFFF),
              border: pw.Border.all(
                color: const PdfColor.fromInt(0xFFBAAB6D),
                width: _s(4) * sc,
              ),
              borderRadius: pw.BorderRadius.circular(_s(8) * sc),
            ),
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: _s(40) * sc,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFFBAAB6D),
                letterSpacing: _s(6) * sc,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildWatermark(
    InvoiceSettings settings,
    PdfColor textColor,
  ) =>
      pw.Positioned.fill(
        child: pw.Transform.rotate(
          angle: -0.5,
          child: pw.Center(
            child: pw.Opacity(
              opacity: 0.08,
              child: pw.Text(
                _sanitize(settings.watermarkText),
                style: pw.TextStyle(
                  fontSize: _s(48),
                  fontWeight: pw.FontWeight.bold,
                  color: _withOpacity(textColor, 0.5),
                ),
              ),
            ),
          ),
        ),
      );

  // ── Utilitaires ──
  static Uint8List? _logoBytes(String path) {
    if (path.isEmpty) return null;
    try {
      if (path.startsWith('data:image')) {
        final comma = path.indexOf(',');
        if (comma == -1) return null;
        return base64Decode(path.substring(comma + 1));
      }
      final f = File(path);
      if (f.existsSync()) return f.readAsBytesSync();
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _fmtNum(double v) {
    if (v % 1 == 0) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}