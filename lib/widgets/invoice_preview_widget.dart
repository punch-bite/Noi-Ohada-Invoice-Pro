// lib/widgets/invoice_preview_widget.dart
//
// 🧩 Rendu visuel de la facture — WRAPPER autour du InvoiceRenderer unifié.
//
// Utilise le même moteur que le workspace et l'impression pour garantir
// une UI/UX cohérente sans décalage.
//
import 'package:flutter/material.dart';
import '../models/customization_config.dart';
import '../models/invoice_layout.dart';
import 'invoice_renderer.dart';

/// Données factices affichées dans l'aperçu.
class PreviewInvoiceData {
  final String companyName;
  final String companyAddress;
  final String companyPhone;
  final String companyEmail;
  final String rccm;
  final String clientName;
  final String clientAddress;
  final String clientPhone;
  final String clientEmail;
  final String invoiceNumber;
  final String issueDate;
  final String dueDate;
  final String currency;
  final List<PreviewLineItem> items;
  final String subtotal;
  final String tax;
  final String total;
  final String legalText;

  const PreviewInvoiceData({
    this.companyName = 'DE Noi Concept digital',
    this.companyAddress = '123 Rue de l\'Indépendance, Douala',
    this.companyPhone = 'TEL: +237 690 00 00 00',
    this.companyEmail = 'contact@noiconcept.cm',
    this.rccm = 'RCCM: DZ-02-2021-B001',
    this.clientName = 'Client SARL',
    this.clientAddress = 'Douala, Cameroun',
    this.clientPhone = 'Tél: +237 6XX XX XX XX',
    this.clientEmail = 'client@exemple.com',
    this.invoiceNumber = 'FV-2024-0018',
    this.issueDate = '30/08/2026',
    this.dueDate = '30/09/2026',
    this.currency = 'FCFA',
    this.items = const [
      PreviewLineItem(description: 'Développement prestation web', quantity: '2', unitPrice: '50 000', amount: '100 000'),
      PreviewLineItem(description: 'Hébergement et maintenance mensuelle', quantity: '1', unitPrice: '20 000', amount: '20 000'),
    ],
    this.subtotal = '100 000 FCFA',
    this.tax = '18 000 FCFA',
    this.total = '118 000 FCFA',
    this.legalText = 'Conforme aux normes OHADA et SYSCOHADA',
  });
}

class PreviewLineItem {
  final String description;
  final String quantity;
  final String unitPrice;
  final String amount;
  const PreviewLineItem({required this.description, required this.quantity, required this.unitPrice, required this.amount});
}

/// Widget d'aperçu utilisant le renderer unifié.
class InvoicePreviewWidget extends StatelessWidget {
  final CustomizationConfig config;
  final PreviewInvoiceData? data;
  final bool showShadow;

  const InvoicePreviewWidget({super.key, required this.config, this.data, this.showShadow = true});

  PreviewInvoiceData get _d => data ?? const PreviewInvoiceData();

  @override
  Widget build(BuildContext context) {
    final layoutConfig = InvoiceLayoutConfig.defaultLayout();
    return Container(
      decoration: showShadow
          ? BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8)),
            ])
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(showShadow ? 14 : 0),
        child: InvoiceRenderer(
          config: layoutConfig,
          mode: RenderMode.render,
          elementBuilder: (context, element, pos) => _buildElement(element, pos),
        ),
      ),
    );
  }

  Widget _buildElement(LayoutElement element, ElementPosition pos) {
    final primary = config.primaryColor;
    final text = config.textColor;
    final subText = text.withValues(alpha: 0.7);
    switch (element) {
      case LayoutElement.logo:
        return Container(width: 50, height: 50, decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.business, color: primary, size: 28));
      case LayoutElement.companyName:
        return Text(_d.companyName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primary));
      case LayoutElement.companyAddress:
        return Text(_d.companyAddress, style: TextStyle(fontSize: 10, color: subText));
      case LayoutElement.companyPhone:
        return Text(_d.companyPhone, style: TextStyle(fontSize: 10, color: subText));
      case LayoutElement.companyEmail:
        return Text(_d.companyEmail, style: TextStyle(fontSize: 10, color: subText));
      case LayoutElement.invoiceTitle:
        return Text(_d.invoiceNumber, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primary, letterSpacing: 1.5));
      case LayoutElement.clientName:
        return Text(_d.clientName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text));
      case LayoutElement.clientAddress:
        return Text(_d.clientAddress, style: TextStyle(fontSize: 10, color: subText));
      case LayoutElement.clientPhone:
        return Text(_d.clientPhone, style: TextStyle(fontSize: 10, color: subText));
      case LayoutElement.clientEmail:
        return Text(_d.clientEmail, style: TextStyle(fontSize: 10, color: subText));
      case LayoutElement.itemsTable:
        return Column(children: [
          Container(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), decoration: BoxDecoration(color: primary, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))), child: Row(children: [Expanded(flex: 3, child: Text('Désignation', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))), Expanded(child: Text('Qté', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))), Expanded(child: Text('Prix', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))), Expanded(child: Text('Total', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)))])),
          for (final item in _d.items)
            Container(padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))), child: Row(children: [Expanded(flex: 3, child: Text(item.description, style: TextStyle(fontSize: 9, color: text))), Expanded(child: Text(item.quantity, style: TextStyle(fontSize: 9, color: text))), Expanded(child: Text(item.unitPrice, style: TextStyle(fontSize: 9, color: text))), Expanded(child: Text(item.amount, style: TextStyle(fontSize: 9, color: text)))])),
        ]);
      case LayoutElement.subtotal:
        return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Sous-total', style: TextStyle(fontSize: 11, color: text)), Text(_d.subtotal, style: TextStyle(fontSize: 11, color: text))]);
      case LayoutElement.taxAmount:
        return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('TVA', style: TextStyle(fontSize: 11, color: text)), Text(_d.tax, style: TextStyle(fontSize: 11, color: text))]);
      case LayoutElement.discount:
        return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Remise', style: TextStyle(fontSize: 11, color: Colors.red)), Text('-0 FCFA', style: TextStyle(fontSize: 11, color: Colors.red))]);
      case LayoutElement.totalAmount:
        return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primary)), Text(_d.total, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primary))]));
      case LayoutElement.footerText:
        return Text(_d.legalText, style: TextStyle(fontSize: 9, color: subText, fontStyle: FontStyle.italic));
      case LayoutElement.qrCode:
        return Container(width: 70, height: 70, decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.qr_code_2, size: 50, color: primary));
      case LayoutElement.signature:
        return Column(children: [Container(width: 120, height: 1, color: Colors.grey), const SizedBox(height: 4), Text('Signature', style: TextStyle(fontSize: 10, color: subText))]);
    }
  }
}
