// lib/services/pdf_service.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice.dart';
import '../models/client.dart';
import '../models/company.dart';

class PdfService {
  static Future<Uint8List> generateInvoicePdf({
    required Invoice invoice,
    required Client client,
    required Company company,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // EN-TÊTE
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Logo et infos entreprise
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    company.name,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(company.address, style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Tél: ${company.phone}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Email: ${company.email}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('NUI: ${company.taxId}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              // Titre FACTURE
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    invoice.isDevis ? 'DEVIS' : 'FACTURE',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'N° ${invoice.invoiceNumber}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 16),

          // INFOS CLIENT
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Facturé à :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(client.name, style: const pw.TextStyle(fontSize: 12)),
                pw.Text(client.address, style: const pw.TextStyle(fontSize: 10)),
                pw.Text('NUI: ${client.taxId}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Tél: ${client.phone}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          
          pw.SizedBox(height: 16),

          // DATES
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Date d\'émission: ${invoice.issueDate.day}/${invoice.issueDate.month}/${invoice.issueDate.year}'),
              pw.Text('Date d\'échéance: ${invoice.dueDate.day}/${invoice.dueDate.month}/${invoice.dueDate.year}'),
            ],
          ),
          
          pw.SizedBox(height: 16),

          // TABLEAU DES PRODUITS
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
            },
            children: [
              // En-tête du tableau
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Désignation', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Qté', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('PU HT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('TVA %', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Total TTC', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              // Lignes du tableau
              ...invoice.items.map((item) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(item.description),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(item.quantity.toString()),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('${item.unitPrice.toStringAsFixed(0)} FCFA'),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(item.taxRate.toString()),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('${item.total.toStringAsFixed(0)} FCFA'),
                  ),
                ],
              )),
            ],
          ),

          pw.SizedBox(height: 16),

          // TOTAUX (alignés à droite)
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('Sous-total: ', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('${invoice.subtotal.toStringAsFixed(0)} FCFA'),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('TVA (${invoice.taxRate}%): ', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('${invoice.taxAmount.toStringAsFixed(0)} FCFA'),
                  ],
                ),
                if (invoice.discount > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('Remise: ', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('-${invoice.discount.toStringAsFixed(0)} FCFA'),
                    ],
                  ),
                ],
                pw.Divider(thickness: 1),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      'TOTAL TTC: ',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${invoice.totalAmount.toStringAsFixed(0)} FCFA',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),
          pw.Divider(thickness: 1),

          // PIED DE PAGE (Mentions légales OHADA)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Conditions de paiement: ${invoice.terms}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                company.legalText,
                style: const pw.TextStyle(
                  fontSize: 8),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Document généré par OHADA Invoice Pro - Conforme SYSCOHADA',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // Méthode pour prévisualiser le PDF
  static Future<void> previewPdf(Uint8List pdfData) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
    );
  }
}
