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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: baseFont),
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
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
    );

    return pdf.save();
  }

  // ===== EN-TÊTE AVEC LOGO =====
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
        final file = File(company.logoPath);
        if (file.existsSync()) {
          final bytes = file.readAsBytesSync();
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
                  child: pw.Text(
                    item.description,
                    style: pw.TextStyle(
                      fontSize: template.fontSize,
                      color: textColor,
                    ),
                  ),
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

  static PdfColor _getPdfColor(Color color) {
    return PdfColor(
      color.red / 255,
      color.green / 255,
      color.blue / 255,
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