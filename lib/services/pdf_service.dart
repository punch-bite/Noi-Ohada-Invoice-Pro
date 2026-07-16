// lib/services/pdf_service.dart
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice.dart';
import '../models/client.dart';
import '../models/company.dart';

extension PriceFormatter on double {
  String toFormattedPrice() => toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ');
}

class PdfService {
  static pw.Font? _cachedFont;

  static Future<pw.Font> _loadFont() async {
    _cachedFont ??= await rootBundle
        .load("assets/fonts/Roboto-Regular.ttf")
        .then((data) => pw.Font.ttf(data));
    return _cachedFont!;
  }

  static Future<Uint8List> generateInvoicePdf({
    required Invoice invoice,
    required Client client,
    required Company company,
    Uint8List? logoBytes,
  }) async {
    final font = await _loadFont();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font),
        build: (pw.Context context) => [
          _buildHeader(invoice, company, logoBytes),
          _buildClientInfo(client),
          _buildItemsTable(invoice),
          _buildTotals(invoice),
          pw.Spacer(),
          _buildFooter(company, invoice),
        ],
      ),
    );
    return pdf.save();
  }

  static pw.Widget _buildHeader(Invoice invoice, Company company, Uint8List? logoBytes) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(children: [
          if (logoBytes != null) pw.Image(pw.MemoryImage(logoBytes), width: 60),
          pw.SizedBox(width: 10),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(company.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(company.address, style: const pw.TextStyle(fontSize: 9)),
          ]),
        ]),
        pw.Text(invoice.isDevis ? 'DEVIS' : 'FACTURE',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
      ],
    );
  }

  static pw.Widget _buildClientInfo(Client client) => pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 20),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Facturé à : ${client.name}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text('NUI: ${client.taxId} | Tél: ${client.phone}', style: const pw.TextStyle(fontSize: 10)),
      ]));

  static pw.Widget _buildItemsTable(Invoice invoice) => pw.Table.fromTextArray(
        headers: ['Désignation', 'Qté', 'PU HT', 'TVA', 'Total'],
        data: invoice.items.map((item) => [
              item.description,
              item.quantity.toString(),
              item.unitPrice.toFormattedPrice(),
              '${item.taxRate}%',
              item.total.toFormattedPrice(),
            ]).toList(),
        border: pw.TableBorder.all(color: PdfColors.grey300),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellAlignment: pw.Alignment.center,
        cellAlignments: {0: pw.Alignment.centerLeft},
      );

  static pw.Widget _buildTotals(Invoice invoice) => pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('Sous-total : ${invoice.subtotal.toFormattedPrice()} FCFA'),
          pw.Text('Total TTC : ${invoice.totalAmount.toFormattedPrice()} FCFA',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
        ]),
      );

  static pw.Widget _buildFooter(Company company, Invoice invoice) {
    final String paymentData = "PAY:${company.name}:AMOUNT:${invoice.totalAmount}";

    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
      pw.Expanded(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Divider(),
          pw.Text(company.legalText, style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Conforme SYSCOHADA', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ]),
      ),
      pw.SizedBox(width: 20),
      pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: paymentData,
        width: 50,
        height: 50,
      ),
    ]);
  }

  static Future<void> previewPdf(Uint8List pdfData) async {
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfData);
  }
}