import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../models/client.dart';
import '../../models/company.dart';
import '../../models/invoice.dart';
import '../../models/invoice_settings.dart';
import '../../models/invoice_template.dart';
import '../../services/printing_service.dart';
import '../../services/template_custom_service.dart';

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

class InvoicePrintPreviewScreen extends StatelessWidget {
  final InvoicePrintPreviewArgs args;

  const InvoicePrintPreviewScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final title = args.invoice.isDevis ? 'Aperçu du devis' : 'Aperçu facture';
    final fileName =
        '${args.invoice.isDevis ? 'Devis' : 'Facture'}_${args.invoice.invoiceNumber}.pdf';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: 'Retour à la facture',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: PdfPreview(
        build: (_) => PrintingService.generateInvoicePdf(
          invoice: args.invoice,
          client: args.client,
          company: args.company,
          template: args.template,
          customPositions: args.customPositions,
          customBackground: args.background,
          isFreePlan: args.isFreePlan,
          invoiceSettings: args.invoiceSettings,
        ),
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
        previewPageMargin: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
