import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:noi_ohada_invoice_pro/models/company.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../models/client.dart';
import '../../../models/invoice.dart';
import '../../../models/invoice_template.dart';
import '../../../models/line_item.dart';
import 'template_custom_service.dart';

class PrintingService {
  
  // Chargement de la police pour supporter les caractères spéciaux et accents
  static Future<pw.Font> _getFont() async {
    try {
      final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
      return pw.Font.ttf(fontData);
    } catch (_) {
      // Fallback sur la police par défaut si l'asset n'est pas trouvé
      return pw.Font.helvetica();
    }
  }

  static Future<void> printInvoice({
    required Invoice invoice,
    required Client client,
    required Company company,
    required InvoiceTemplate template,
    bool share = false,
  }) async {
    final font = await _getFont();
    final pdf = await generateInvoicePdf(
      invoice: invoice,
      client: client,
      company: company,
      template: template,
      font: font,
    );

    if (share) {
      await Printing.sharePdf(
        bytes: pdf,
        filename: '${invoice.isDevis ? "Devis" : "Facture"}_${invoice.invoiceNumber}.pdf',
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
    pw.Font? font,
  }) async {
    final pdf = pw.Document();
    final baseFont = font ?? await _getFont();

    // 🔧 APPLIQUE LA CUSTOMISATION de l'utilisateur (positions + mapping +
    // arrière-plan enregistrés dans l'espace de travail drag & drop). Sans
    // positions, on garde le layout fixe historique.
    final custom = await TemplateCustomService.loadCustom(template.id);
    final positions = custom.positions.isNotEmpty
        ? custom.positions
        : Map<String, dynamic>.from(template.positions);
    final mapping = custom.mapping.isNotEmpty
        ? custom.mapping
        : Map<String, String>.from(template.mapping);

    // 🖼️ ARRIÈRE-PLAN imprimé : priorité à l'image personnalisée uploadée
    // dans l'espace de travail, sinon celle téléversée du modèle (admin).
    // L'opacité et l'ajustement personnalisés sont appliqués.
    Uint8List? bgBytes;
    if (custom.background.hasCustomImage) {
      try {
        bgBytes = base64Decode(custom.background.fileData);
      } catch (_) {
        bgBytes = null;
      }
    }
    bgBytes ??= _templateBackgroundBytes(template);
    final bgOpacity = custom.background.opacity.clamp(0.0, 1.0);
    final bgFit = custom.background.fit == 'contain'
        ? pw.BoxFit.contain
        : pw.BoxFit.fill;
    final pw.Widget? background = bgBytes == null
        ? null
        : pw.Positioned.fill(
            child: pw.Opacity(
              opacity: bgOpacity,
              child: pw.Image(
                pw.MemoryImage(bgBytes),
                fit: bgFit,
              ),
            ),
          );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: baseFont),
        margin: positions.isEmpty
            ? const pw.EdgeInsets.all(32)
            : pw.EdgeInsets.zero,
        build: (pw.Context context) => positions.isEmpty
            ? [
                pw.Stack(
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
              ]
            : [
                _buildPositionedLayout(
                  context,
                  positions,
                  invoice,
                  client,
                  company,
                  template,
                  mapping: mapping,
                  background: background,
                ),
              ],
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
      // Base pleine page : donne une taille au Stack (sinon il collapserait
      // car tous ses enfants sont positionnés).
      pw.SizedBox(width: pageW, height: pageH),
      // `background` est déjà un Positioned.fill → enfant direct du Stack.
      if (background != null) background,
    ];

    positions.forEach((id, raw) {
      if (raw is! Map) return;
      final visible = (raw['visible'] as bool?) ?? true;
      if (!visible) return;
      final x = ((raw['x'] as num?) ?? 0.04).toDouble().clamp(0.0, 0.98);
      final y = ((raw['y'] as num?) ?? 0.04).toDouble().clamp(0.0, 0.98);
      final scale = ((raw['scale'] as num?) ?? 1.0).toDouble().clamp(0.5, 2.5);

      final widget = _variableWidget(id, scale, invoice, client, company, template, mapping: mapping);
      if (widget == null) return;

      // Les blocs larges (tableau des lignes) ont besoin d'une largeur bornée.
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

    return pw.Stack(children: children);
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
        return pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: _withOpacity(primary, 0.1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
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
        mappedVar, scale, invoice, client, company, template,
        primary: primary, text: text, fs: fs, sub: sub,
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
        return pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: _withOpacity(primary, 0.1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
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
        color: _withOpacity(primaryColor, 0.05),
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
          imageWidget = pw.ClipRRect(
            horizontalRadius: 4,
            verticalRadius: 4,
            child: pw.Image(
              pw.MemoryImage(bytes),
              width: 26,
              height: 26,
              fit: pw.BoxFit.cover,
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
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc',
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