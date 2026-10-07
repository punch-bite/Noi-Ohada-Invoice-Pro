// lib/screens/dashboard/invoice_print_preview_screen.dart
//
// 🖨️ Aperçu / Impression PDF — stylé conformément au design system RoyalScheme.
// Cohérent avec InvoiceDetailScreen : titre contextuel Facture/Devis, thème,
// numéro de facture affiché dans le sous-titre AppBar.
//
// ignore_for_file: deprecated_member_use

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
import '../../theme/royal_ledger.dart';

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
    final c = RoyalScheme.of(context);
    final isDevis = args.invoice.isDevis;
    final title = isDevis ? 'Aperçu Devis' : 'Aperçu Facture';
    final subtitle = '${isDevis ? 'Devis' : 'Facture'} N° ${args.invoice.invoiceNumber}';
    final fileName = '${isDevis ? 'Devis' : 'Facture'}_${args.invoice.invoiceNumber}.pdf';

    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
          // Indicateur modèle utilisé
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
