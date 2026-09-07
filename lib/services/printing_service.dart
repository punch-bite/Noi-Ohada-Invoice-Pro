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
import '../models/invoice_template.dart';
import '../models/line_item.dart';
import '../widgets/template_background_palette.dart';
import 'invoice_layout_engine.dart' show A4Dimensions;
import 'template_custom_service.dart';
import 'settings_service.dart';

class PrintingService {
  // Chargement de la police pour supporter les caractères spéciaux et accents.
  //
  // ⚠️ Le package `pdf` ne sait PAS synthétiser le gras d'un TTF : quand on
  // ne lui fournit que la variante regular, un `pw.FontWeight.bold` retombe
  // sur sa police intégrée `Helvetica-Bold` qui n'a PAS les glyphes
  // accentués (é, à, É…) → erreur « Helvetica-Bold has no Unicode support ».
  // On charge donc TOUTES les variantes Roboto et on les transmet via
  // `ThemeData.withFont(base:, bold:, italic:, boldItalic:)`.
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
        condensed =
            pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Condensed.ttf'));
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
      // Fallback : uniquement la police régulière (les variantes retombent
      // alors sur Helvetica — sans accents si un bold est demandé).
      final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      return (
        base: pw.Font.ttf(regular),
        bold: pw.Font.ttf(regular),
        medium: pw.Font.ttf(regular),
        condensed: null,
      );
    }
  }

  static Future<void> printInvoice({
    required Invoice invoice,
    required Client client,
    required Company company,
    required InvoiceTemplate template,
    bool share = false,
    bool isFreePlan = false,
    // 🧩 Personnalisations optionnelles passées par l'écran de détail
    // (positions drag & drop, mapping, arrière-plan). Si non fournies,
    // elles sont chargées depuis TemplateCustomService.
    Map<String, dynamic>? customPositions,
    Map<String, String>? customMapping,
    TemplateBackgroundSettings? customBackground,
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
    // Police complète (base + variantes). Facultatif : sinon chargée ici.
    ({
      pw.Font base,
      pw.Font bold,
      pw.Font medium,
      pw.Font? condensed,
    })? fontFamily,
    bool isFreePlan = false,
    // 🧩 Personnalisations optionnelles passées par l'écran de détail
    // (positions drag & drop, mapping, arrière-plan). Si non fournies,
    // elles sont chargées depuis TemplateCustomService.
    Map<String, dynamic>? customPositions,
    Map<String, String>? customMapping,
    TemplateBackgroundSettings? customBackground,
  }) async {
    final pdf = pw.Document();
    // 🖋️ Chargement des variantes (regular/bold/medium) : indispensable pour
    // que les textes en GRAS accentués rendent avec Roboto (Unicode) et non
    // avec Helvetica-Bold (qui échoue sur les accents).
    final fonts = fontFamily ?? await _loadFontFamily();

        // 🔧 APPLIQUE LA CUSTOMISATION de l'utilisateur (positions + mapping +
    // arrière-plan). Priorité : personnalisations passées en paramètre (depuis
    // l'écran de détail) > TemplateCustomService > template par défaut.
    final custom = await TemplateCustomService.loadCustom(template.id);
    // 📦 Paramètres globaux de facture (filigrane, couleurs, police…)
    // Chargés en même temps pour limiter les awaits.
    final settings = await SettingsService.instance.loadSettings();
    // 🎨 Template EFFECTIF : les personnalisations globales (couleurs,
    // police, taille, options d'affichage) sont appliquées au modèle pour
    // un PDF WYSIWYG aligné sur l'aperçu.
    final effectiveTemplate =
        SettingsService.applyToTemplate(template, settings);
    // 🧩 Utilise les personnalisations passées en paramètre si fournies,
    // sinon utilise celles de TemplateCustomService, sinon celles du template.
    final positions = customPositions?.isNotEmpty == true
        ? customPositions!
        : custom.positions.isNotEmpty
            ? custom.positions
            : Map<String, dynamic>.from(template.positions);
    final mapping = customMapping?.isNotEmpty == true
        ? customMapping!
        : custom.mapping.isNotEmpty
            ? custom.mapping
            : Map<String, String>.from(template.mapping);

    // 🖼️ ARRIÈRE-PLAN imprimé — priorité : image personnalisée (workspace)
    // > préréglage de la palette > image téléversée du modèle (admin).
    // L'opacité et l'ajustement personnalisés sont appliqués.
    // Utilise customBackground si fourni (depuis l'écran de détail).
    final bgSettings = customBackground ?? custom.background;
    Uint8List? bgBytes;
    if (bgSettings.hasCustomImage) {
      try {
        bgBytes = base64Decode(bgSettings.fileData);
      } catch (_) {
        bgBytes = null;
      }
    }
    final preset = bgBytes == null
        ? BackgroundPreset.byId(bgSettings.presetId)
        : null;
    if (preset == null) bgBytes ??= _templateBackgroundBytes(template);
    final bgOpacity = bgSettings.opacity.clamp(0.0, 1.0);
    // 🖼️ L'image de fond couvre TOUJOURS 100 % de la largeur et 100 % de la
    // hauteur du papier (pleine page), quelle que soit la valeur « Remplir /
    // Ajuster » choisie à la personnalisation : on force `fill` pour que
    // l'image occupe tout l'arrière-plan A4 (aucun bandeau / lettreboxage).
    final pw.Widget? background;
    if (bgBytes != null) {
      background = pw.Positioned.fill(
        child: pw.Opacity(
          opacity: bgOpacity,
          child: pw.Image(
            pw.MemoryImage(bgBytes),
            fit: pw.BoxFit.fill,
          ),
        ),
      );
    } else if (preset != null) {
      // 🎨 Fond préréglé : approximation PDF par dégradé vertical.
      background = pw.Positioned.fill(
        child: pw.Opacity(
          opacity: bgOpacity,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                begin: pw.Alignment.topCenter,
                end: pw.Alignment.bottomCenter,
                colors: preset.colors.map(_getPdfColor).toList(),
              ),
            ),
          ),
        ),
      );
    } else {
      background = null;
    }

    // 🧩 Détection du format de personnalisation :
    //   • NOUVEAU format drag & drop (blocs / colonnes / ordre) : la clé
    //     'positions' est présente → rendu WYSIWYG aligné sur le workspace ;
    //   • ANCIEN format x/y/scale (modèles admin) : clés variables à la racine ;
    //   • aucune personnalisation : layout fixe historique.
    final blockConfig = _blockLayoutFromCustom(positions);

    // 🧩 Rendu par blocs métier (format atelier) : si l'utilisateur a une
    // configuration « blocks_sections » (ordre des sections) sauvegardée,
    // on la privilégie sur les anciens formats pour que l'APERÇU et le PDF
    // respectent exactement l'ordre et la visibilité définis dans l'atelier.
    List<List<String>>? workspaceSections;
    Map<String, bool>? workspaceVisibility;
    final wsSections = positions['blocks_sections'];
    if (wsSections is List && wsSections.isNotEmpty) {
      workspaceSections = [
        for (final s in wsSections)
          if (s is List) List<String>.from(s.whereType<String>()) else <String>[],
      ];
      final wsVis = positions['block_visibility'];
      if (wsVis is Map) {
        workspaceVisibility = <String, bool>{};
        wsVis.forEach((k, v) {
          if (v is bool) workspaceVisibility![k.toString()] = v;
        });
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: fonts.base,
          bold: fonts.bold,
          italic: fonts.medium,
          boldItalic: fonts.bold,
        ),
        margin: (positions.isEmpty && blockConfig == null)
            ? const pw.EdgeInsets.all(32)
            : pw.EdgeInsets.zero,
        build: (pw.Context context) {
          // 1️⃣ Priorité : rendu par blocs métier (atelier) — ordre + visibilité.
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
              ),
            ];
          }
                    return [
            pw.Stack(
              children: [
                if (background != null) background,
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildHeader(invoice, company, effectiveTemplate),
                    pw.SizedBox(height: 16),
                    _buildClientInfo(client, effectiveTemplate),
                    pw.SizedBox(height: 16),
                    _buildItemsTable(invoice, effectiveTemplate),
                    pw.SizedBox(height: 16),
                    _buildTotals(invoice, effectiveTemplate),
                    pw.SizedBox(height: 16),
                    _buildFooter(company, effectiveTemplate),
                  ],
                ),
                // 🧧 FILIGRANE personnalisé (InvoiceSettings).
                if (settings.showWatermark && settings.watermarkText.isNotEmpty)
                  pw.Positioned.fill(
                    child: pw.Transform.rotate(
                      angle: -0.5,
                      child: pw.Center(
                        child: pw.Opacity(
                          opacity: 0.08,
                          child: pw.Text(
                            settings.watermarkText,
                            style: pw.TextStyle(
                              fontSize: 48,
                              color: _getPdfColor(settings.textColor),
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isFreePlan)
                  pw.Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: pw.Center(
                      child: pw.Text(
                        'Généré par OHADA Invoice Pro — Version Gratuite',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: _withOpacity(
                              _getPdfColor(effectiveTemplate.textColor), 0.4),
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================
  //  RENDU POSITIONNÉ (customisation drag & drop)
  //  Place chaque variable visible à ses coordonnées relatives (0..1) sur la
  //  page A4, en respectant la visibilité et l'échelle choisies.
  // ============================================================
  static pw.Widget _buildPositionedLayout(
    pw.Context context,
    Map<String, dynamic> positions,
    Invoice invoice,
    Client client,
    Company company,
    InvoiceTemplate template, {
    Map<String, String> mapping = const {},
    pw.Widget? background,
  }) {
    final pageW = PdfPageFormat.a4.width;
    final pageH = PdfPageFormat.a4.height;
    final children = <pw.Widget>[
      pw.SizedBox(width: pageW, height: pageH),
      if (background != null) background,
    ];

    positions.forEach((id, raw) {
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
          child:
              width == null ? widget : pw.SizedBox(width: width, child: widget),
        ),
      );
    });

    return pw.Stack(children: children);
  }

  // ============================================================
  //  🧩 RENDU PAR BLOCS (drag & drop — nouveau format)
  // ============================================================

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
  }) {
    final pageW = PdfPageFormat.a4.width;
    final pageH = PdfPageFormat.a4.height;
    final scaleRatio = pageW / A4Dimensions.width;
    final padding = config.pagePadding.clamp(8.0, 80.0).toDouble() * scaleRatio;
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
      if (isFreePlan)
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
    ];

    return pw.Stack(children: children);
  }

  // ============================================================
  //  🧩 RENDU PAR BLOCS MÉTIER (workspace drag & drop)
  //  Compose l'en-tête société PUIS les sections de blocs dans leur
  //  ordre tel que défini dans l'atelier, en respectant la visibilité.
  //  Utilisé quand `blocks_sections` est présent dans la personnalisation.
  // ============================================================
  static const Map<String, List<LayoutElement>> _workspaceBlockElements = {
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
  };

  static const String _emptySpaceMarker = 'empty_column';

  /// Rendu d'un bloc spécifique du corps dans l'ordre de l'atelier.
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

    switch (key) {
      case 'invoice_meta':
        // Le titre « FACTURE / DEVIS » est déjà porté par le bandeau
        // d'en-tête → on n'imprime QUE la méta (N°, dates) pour éviter le
        // doublon du mot titre sur la facture.
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('N° ${invoice.invoiceNumber}',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: t)),
            pw.SizedBox(height: 2),
            pw.Text(
              'Date: ${invoice.issueDate.day}/${invoice.issueDate.month}/${invoice.issueDate.year}',
              style: pw.TextStyle(fontSize: 10, color: s),
            ),
            pw.Text(
              'Échéance: ${invoice.dueDate.day}/${invoice.dueDate.month}/${invoice.dueDate.year}',
              style: pw.TextStyle(fontSize: 10, color: s),
            ),
          ],
        );
      case 'billing_info': {
        final elts = _workspaceBlockElements[key] ?? const <LayoutElement>[];
        // L'élément client_nom imprime déjà l'étiquette « Facturé à : » → on
        // ne la répète PAS ici (suppression du doublon de mots).
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final e in elts) _pdfElement(e, invoice, client, company, template,
                mapping: mapping, customPositions: customPositions),
          ],
        );
      }
      case 'items_table':
        return _pdfElement(LayoutElement.itemsTable, invoice, client, company,
            template,
            mapping: mapping, customPositions: customPositions);
      case 'totals':
        final elts = _workspaceBlockElements[key] ?? const <LayoutElement>[];
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            for (final e in elts) _pdfElement(e, invoice, client, company, template,
                mapping: mapping, customPositions: customPositions),
          ],
        );
      case 'legal_mentions':
        return _pdfElement(LayoutElement.legalMention, invoice, client, company,
            template,
            mapping: mapping, customPositions: customPositions);
      case 'signature_block':
        return _pdfElement(LayoutElement.signature, invoice, client, company,
            template,
            mapping: mapping, customPositions: customPositions);
      case 'qr_block':
        return _pdfElement(LayoutElement.qrCode, invoice, client, company,
            template,
            mapping: mapping, customPositions: customPositions);
      default:
        return null;
    }
  }

  /// Compose tout le flux dans l'ordre des sections de l'atelier.
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
  }) {
    final pageW = PdfPageFormat.a4.width;
    final pageH = PdfPageFormat.a4.height;
    final text = _getPdfColor(template.textColor);
    final sub = _withOpacity(text, 0.6);
    final fs = template.fontSize.clamp(6.0, 40.0).toDouble();
    const pad = 24.0;
    const gap = 10.0;
    final contentW = pageW - pad * 2;

    // 1️⃣ EN-TÊTE : PAS de bandeau — le logo / société / titre est rendu
    // comme une rangée normale du corps, à colonnes de largeur ÉGALE, dans
    // la MÊME grille que les sections (drag & drop identique au corps).
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

    // 2️⃣ CORPS : chaque section = rangée pleine largeur, blocs à largeurs
    // ÉGALES côte à côte (colonnes identiques à l'aperçu de l'atelier).
    // Une section « vide » réserve la largeur d'une colonne.
    // La DERNIÈRE section, si elle ne contient QUE des blocs de pied
    // (mentions légales / signature / QR), est sortie du flux puis ancrée
    // TOUT EN BAS de la page A4, pleine largeur.
    const footerish = {'legal_mentions', 'signature_block', 'qr_block'};
    List<String> footerKeys = const [];
    final bodySections = <List<String>>[];
    for (var i = 0; i < sections.length; i++) {
      final sec = sections[i];
      if (i == sections.length - 1 &&
          sec.isNotEmpty &&
          sec.every((k) =>
              k == _emptySpaceMarker || footerish.contains(k))) {
        footerKeys = sec;
      } else {
        bodySections.add(sec);
      }
    }

    final bodyRows = <pw.Widget>[];
    for (final section in bodySections) {
      final keys = section
          .where((k) => k != _emptySpaceMarker && (visibility[k] ?? true))
          .toList();
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
      final keys = footerKeys
          .where((k) => k != _emptySpaceMarker && (visibility[k] ?? true))
          .toList();
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

    return pw.Stack(
      children: [
        pw.SizedBox(width: pageW, height: pageH),
        if (background != null) background,
        pw.Padding(
          padding: const pw.EdgeInsets.all(pad),
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Rangée d'en-tête PDF — PAS de bandeau : le logo / société / titre est
  /// rendu comme une rangée normale du corps, à colonnes de largeur ÉGALE,
  /// dans la MÊME grille que les sections (drag & drop identique au corps).
  /// L'ordre des éléments vient de `header_elements_order`.
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
    const defaults = ['logo', 'company_info', 'invoice_title'];
    final rawOrder = (customPositions['header_elements_order'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    const known = {'logo', 'company_info', 'invoice_title'};
    final order = <String>[];
    for (final e in rawOrder) {
      if (known.contains(e) && !order.contains(e)) order.add(e);
    }
    for (final e in defaults) {
      if (!order.contains(e)) order.add(e);
    }
    if (order.isEmpty) order.addAll(defaults);

    // ↔️ Largeurs pondérées (header_widths) : company_info = 2 par défaut.
    double hweight(String k) {
      final m = customPositions['header_widths'];
      if (m is Map) {
        final v = m[k];
        if (v is num) return v.toDouble().clamp(0.4, 3.0);
      }
      return k == 'company_info' ? 2.0 : 1.0;
    }

    // 🔠 Alignement horizontal par colonne (header_alignments).
    double hdx(String k) {
      final m = customPositions['header_alignments'];
      final s = (m is Map) ? m[k] : null;
      final v = s is String ? s : null;
      if (v == 'center') return 0.0;
      if (v == 'right' || (v == null && k == 'invoice_title')) return 1.0;
      return -1.0;
    }

    final htotal = order.fold<double>(0, (a, k) => a + hweight(k));
    final havail = order.isEmpty ? 0.0 : contentW - gap * (order.length - 1);

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
          ];
          // QR dans l'en-tête (si choisi dans l'atelier).
          final qrPos = customPositions['qr_position'] as String?;
          if ((qrPos == 'header') && template.showPaymentQR) {
            children.add(pw.SizedBox(height: 4));
            children.add(pw.Container(
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                color: _withOpacity(primary, 0.08),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'Scannez le QR de paiement',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 6, color: sub),
              ),
            ));
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

  /// Rangée PDF d'une section : les blocs sont rendus à largeurs ÉGALES
  /// côte à côte (comme les colonnes `Expanded` de l'aperçu de l'atelier).
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
    // 🔧 Largeurs proportionnelles aux poids (`block_widths`), 1.0 par défaut :
    // respecte les « formes personnalisées » définies dans l'atelier.
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

    // 🎨 Couleurs personnalisées par bloc (fond + texte) sauvegardées dans
    // l'atelier (`block_bg_colors` / `block_text_colors`).
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
            e.value.blockIndex == block.index && config.styleOf(e.key).visible)
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

    pw.Widget build(
            MapEntry<LayoutElement, ElementPosition> entry, double width) =>
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

    // Cas spécial : un seul élément pleine largeur (colSpan 2).
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

  /// Correspondance LayoutElement → widget PDF (données réelles de la facture,
  /// mapping utilisateur inclus, options personnalisées et styles d'éléments).
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
    // Application du style spécifique à cet élément si présent dans le config.
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
        // 🧾 Mentions légales SANS fond ni barre de couleur (demande user) :
        // texte seul, lisible sur le fond de la page.
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
        return pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _withOpacity(text, 0.3)),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'Paiement Mobile Money / Bank',
                style: pw.TextStyle(
                  fontSize: fs - 2,
                  fontWeight: pw.FontWeight.bold,
                  color: primary,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Scannez le QR de paiement',
                style: pw.TextStyle(fontSize: fs - 2, color: sub),
              ),
            ],
          ),
        );
      case LayoutElement.signature:
        final showSignature =
            (customPositions['show_signature_line'] as bool?) ?? true;
        final showPaidStamp =
            (customPositions['show_paid_stamp'] as bool?) ?? true;
        final stampText = (customPositions['stamp_text'] as String?) ?? 'PAYÉ';
        return pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (showPaidStamp)
              pw.Transform.rotate(
                angle: -0.15,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                        color: _getPdfColor(const Color(0xFFBAAB6D)), width: 2),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    stampText,
                    style: pw.TextStyle(
                      fontSize: fs,
                      fontWeight: pw.FontWeight.bold,
                      color: _getPdfColor(const Color(0xFFBAAB6D)),
                    ),
                  ),
                ),
              )
            else
              pw.SizedBox(),
            if (showSignature)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 120,
                    height: 1,
                    color: _withOpacity(text, 0.4),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Signature & Cachet',
                    style: pw.TextStyle(fontSize: fs - 2, color: sub),
                  ),
                ],
              )
            else
              pw.SizedBox(),
          ],
        );
      default:
        return pw.SizedBox();
    }
  }

  /// Valeur PDF d'une variable de facture (pour le mapping).
  /// Retourne le widget correspondant à la variable, ou null si inconnue.
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
        return pw.Text(
          client.email,
          style: pw.TextStyle(fontSize: fs, color: sub),
        );
      case 'client_phone':
        return pw.Text(
          'Tél: ${client.phone}',
          style: pw.TextStyle(fontSize: fs, color: sub),
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
        return pw.Text(
          company.address,
          style: pw.TextStyle(fontSize: fs, color: sub),
        );
      case 'company_tax_id':
        return pw.Text(
          company.taxId.isEmpty ? 'N° TVA: —' : 'N° TVA: ${company.taxId}',
          style: pw.TextStyle(fontSize: fs, color: sub),
        );
      case 'subtotal':
        return _totalRowPdf(
          'Sous-total',
          '${invoice.subtotal.toStringAsFixed(0)} FCFA',
          text,
          fs,
        );
      case 'tax_amount':
        return _totalRowPdf(
          'TVA (${invoice.taxRate}%)',
          '${invoice.taxAmount.toStringAsFixed(0)} FCFA',
          text,
          fs,
        );
      case 'total_amount':
        // TOTAL TTC sans fond (transparent) pour ne jamais masquer le texte.
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

  /// Retourne le widget PDF d'une variable de facture (ou null si à masquer).
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

    // 🧩 MAPPING : si l'utilisateur a réassigné une variable de facture à cet
    // élément dans l'espace de travail, on rend la variable mappée à la place
    // du contenu par défaut de l'élément.
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
        return pw.Text(
          company.address,
          style: pw.TextStyle(fontSize: fs, color: sub),
        );
      case 'company_phone':
        return pw.Text(
          'Tél: ${company.phone}',
          style: pw.TextStyle(fontSize: fs, color: sub),
        );
      case 'company_email':
        return pw.Text(
          'Email: ${company.email}',
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
        return pw.Text(
          client.address,
          style: pw.TextStyle(fontSize: fs, color: sub),
        );
      case 'client_phone':
        return pw.Text(
          'Tél: ${client.phone}',
          style: pw.TextStyle(fontSize: fs, color: sub),
        );
      case 'client_email':
        return pw.Text(
          client.email,
          style: pw.TextStyle(fontSize: fs, color: sub),
        );
      case 'items':
        return _buildItemsTable(invoice, template);
      case 'subtotal':
        return _totalRowPdf(
          'Sous-total',
          '${invoice.subtotal.toStringAsFixed(0)} FCFA',
          text,
          fs,
        );
      case 'tax_amount':
        return _totalRowPdf(
          'TVA (${invoice.taxRate}%)',
          '${invoice.taxAmount.toStringAsFixed(0)} FCFA',
          text,
          fs,
        );
      case 'discount':
        if (invoice.discount <= 0) return null;
        return _totalRowPdf(
          'Remise',
          '-${invoice.discount.toStringAsFixed(0)} FCFA',
          PdfColors.red,
          fs,
        );
      case 'total_amount':
        // TOTAL TTC sans fond (transparent) pour ne jamais masquer le texte.
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
        return pw.Text(
          '📱 Paiement Mobile Money accepté',
          style: pw.TextStyle(fontSize: 10 * scale, color: primary),
        );
      case 'signature':
        return pw.SizedBox(
          width: 160 * scale,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(height: 1, color: PdfColors.grey600),
              pw.SizedBox(height: 4),
              pw.Text(
                'Signature',
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

  /// Ligne de total (label + valeur) pour le rendu positionné.
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

  /// Extrait les octets de l'image téléversée du modèle (arrière-plan).
  /// Retourne `null` si le modèle n'a pas d'image (ou un PDF).
  static Uint8List? _templateBackgroundBytes(InvoiceTemplate template) {
    if (template.fileData.isEmpty || template.fileType == 'pdf') return null;
    try {
      return base64Decode(template.fileData);
    } catch (_) {
      return null;
    }
  }

  // ===== EN-TÊTE AVEC LOGO =====
  /// Convertit `company.logoPath` (data URI `data:image/...;base64,xxx`
  /// OU chemin de fichier local) en bytes utilisables dans le PDF.
  static Uint8List? _logoBytesFromPath(String logoPath) {
    try {
      if (logoPath.startsWith('data:image')) {
        final comma = logoPath.indexOf(',');
        if (comma == -1) return null;
        final base64 = logoPath.substring(comma + 1);
        return base64Decode(base64);
      }
      final file = File(logoPath);
      if (file.existsSync()) {
        return file.readAsBytesSync();
      }
      return null;
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
      } catch (e) {
        logoWidget = null;
      }
    }

    return pw.Container(
      decoration: template.showBorder
          ? pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: primaryColor,
                  width: 2,
                ),
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
                style: pw.TextStyle(
                  fontSize: 14,
                  color: textColor,
                ),
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

  // ===== INFORMATIONS CLIENT =====
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
          pw.Text(
            client.name,
            style: pw.TextStyle(
              fontSize: 12,
              color: textColor,
            ),
          ),
          pw.Text(
            client.address,
            style: pw.TextStyle(
              fontSize: 10,
              color: _withOpacity(textColor, 0.6),
            ),
          ),
          pw.Text(
            'NUI: ${client.taxId}',
            style: pw.TextStyle(
              fontSize: 10,
              color: _withOpacity(textColor, 0.6),
            ),
          ),
          pw.Text(
            'Tél: ${client.phone}',
            style: pw.TextStyle(
              fontSize: 10,
              color: _withOpacity(textColor, 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ===== TABLEAU DES PRODUITS =====
  static pw.Widget _buildItemsTable(Invoice invoice, InvoiceTemplate template) {
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
          decoration: pw.BoxDecoration(
            color: primaryColor,
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Désignation',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Qté',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Prix HT',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'TVA %',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Total TTC',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        ...invoice.items.map((item) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: _buildItemCell(item, template),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    item.quantity.toString(),
                    style: pw.TextStyle(
                      fontSize: template.fontSize,
                      color: textColor,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    '${item.unitPrice.toStringAsFixed(0)} FCFA',
                    style: pw.TextStyle(
                      fontSize: template.fontSize,
                      color: textColor,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    item.taxRate.toString(),
                    style: pw.TextStyle(
                      fontSize: template.fontSize,
                      color: textColor,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    '${item.total.toStringAsFixed(0)} FCFA',
                    style: pw.TextStyle(
                      fontSize: template.fontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            )),
      ],
    );
  }

  /// Cellule « Désignation » d'une ligne : photo produit (optionnelle) + texte.
  static pw.Widget _buildItemCell(LineItem item, InvoiceTemplate template) {
    final textColor = _getPdfColor(template.textColor);

    // Photo du produit (data URI base64) si présente.
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

  // ===== TOTAUX =====
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
                pw.Text(
                  'Sous-total: ',
                  style: pw.TextStyle(
                    fontSize: template.fontSize,
                    color: textColor,
                  ),
                ),
                pw.Text(
                  '${invoice.subtotal.toStringAsFixed(0)} FCFA',
                  style: pw.TextStyle(
                    fontSize: template.fontSize,
                    color: textColor,
                  ),
                ),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'TVA (${invoice.taxRate}%): ',
                  style: pw.TextStyle(
                    fontSize: template.fontSize,
                    color: textColor,
                  ),
                ),
                pw.Text(
                  '${invoice.taxAmount.toStringAsFixed(0)} FCFA',
                  style: pw.TextStyle(
                    fontSize: template.fontSize,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ],
          if (invoice.discount > 0)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Remise: ',
                  style: pw.TextStyle(
                    fontSize: template.fontSize,
                    color: PdfColors.red,
                  ),
                ),
                pw.Text(
                  '-${invoice.discount.toStringAsFixed(0)} FCFA',
                  style: pw.TextStyle(
                    fontSize: template.fontSize,
                    color: PdfColors.red,
                  ),
                ),
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
                pw.Text(
                  'TOTAL TTC: ',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.Text(
                  '${invoice.totalAmount.toStringAsFixed(0)} FCFA',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== PIED DE PAGE =====
  static pw.Widget _buildFooter(Company company, InvoiceTemplate template) {
    final primaryColor = _getPdfColor(template.primaryColor);
    final textColor = _getPdfColor(template.textColor);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(
          color: _withOpacity(primaryColor, 0.3),
        ),
        pw.SizedBox(height: 8),
        if (template.showPaymentTerms)
          pw.Text(
            'Conditions de paiement: 30 jours net',
            style: pw.TextStyle(
              fontSize: 10,
              color: _withOpacity(textColor, 0.6),
            ),
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
              style: pw.TextStyle(
                fontSize: 10,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ===== FONCTIONS UTILITAIRES =====

  /// Formate une date en « 12 Oct 2023 ».
  static String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sep',
      'Oct',
      'Nov',
      'Déc',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Libellé lisible du statut d'une facture.
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

  static PdfColor _getPdfColor(Color color) {
    return PdfColor(
      color.r,
      color.g,
      color.b,
    );
  }

  static PdfColor _withOpacity(PdfColor color, double opacity) {
    return PdfColor(
      color.red,
      color.green,
      color.blue,
      opacity,
    );
  }
}
