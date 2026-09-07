import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noi_ohada_invoice_pro/models/client.dart';
import 'package:noi_ohada_invoice_pro/models/company.dart';
import 'package:noi_ohada_invoice_pro/models/invoice.dart';
import 'package:noi_ohada_invoice_pro/models/invoice_layout.dart';
import 'package:noi_ohada_invoice_pro/models/invoice_template.dart';
import 'package:noi_ohada_invoice_pro/models/line_item.dart';
import 'package:noi_ohada_invoice_pro/services/printing_service.dart';
import 'package:noi_ohada_invoice_pro/services/template_custom_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 🔴 RÉGRESSION : le rendu PDF du layout personnalisé de l'atelier plantait
  // avec « A borderRadius can only be given for a uniform Border » dans le
  // bloc legal_mentions (BoxDecoration bordure non uniforme + borderRadius,
  // interdit par le package `pdf`) → la facture personnalisée (QR, signature,
  // fond…) ne s'imprimait pas. Ce test garantit que la génération aboutit.
  test('PDF personnalisé (format atelier) généré sans erreur', () async {
    // Reconstruit exactement la map sauvegardee par _saveConfig du workspace.
    final layout = InvoiceLayoutConfig.defaultLayout();
    final positions = layout.toMap();
    positions['header_elements_order'] = ['logo', 'company_info', 'invoice_title'];
    positions['blocks_sections'] = [
      ['billing_info', 'invoice_meta'],
      ['items_table'],
      ['totals'],
      ['legal_mentions', 'signature_block', 'qr_block'],
    ];
    positions['blocks_order'] =
        (positions['blocks_sections'] as List).expand((s) => s as List).toList();
    positions['block_visibility'] = {
      'billing_info': true,
      'invoice_meta': true,
      'items_table': true,
      'totals': true,
      'legal_mentions': true,
      'signature_block': true,
      'qr_block': true,
    };
    positions['block_alignment'] = {
      'billing_info': 'left',
      'invoice_meta': 'right',
      'items_table': 'left',
      'totals': 'right',
      'legal_mentions': 'left',
      'signature_block': 'center',
      'qr_block': 'center',
    };
    positions['qr_position'] = 'totals';
    // Largeurs + couleurs personnalisées par bloc (forme/teinte).
    positions['block_widths'] = {'billing_info': 1.0, 'invoice_meta': 2.2};
    positions['block_bg_colors'] = {'totals': 0xFFB78103};
    positions['block_text_colors'] = {'totals': 0xFF004D40};
    positions['custom_legal_text'] = 'Paiement sous 30 jours net.';
    positions['stamp_text'] = 'PAYÉ';
    positions['signatory_title'] = 'Direction Générale';
    positions['show_paid_stamp'] = true;
    positions['show_signature_line'] = true;
    positions['logo_size'] = 1.0;
    positions['company_name'] = '';
    positions['client_name'] = '';
    positions['invoice_title_text'] = '';

    // 🖼️ Image de fond PERSONNALISÉE (fichier réel → base64) : vérifie que
    // l'image téléversée est bien rendue derrière le papier A4 du PDF.
    final bgBytes = File('assets/images/splash_logo.png').readAsBytesSync();
    final background = TemplateBackgroundSettings(
      fileData: base64Encode(bgBytes),
      fileType: 'png',
      opacity: 0.6,
    );
    SharedPreferences.setMockInitialValues({
      'template_custom_t1': jsonEncode({
        'positions': positions,
        'mapping': <String, String>{},
        'background': background.toMap(),
      }),
    });

    final company = Company(
      userId: 'u1',
      name: 'OHADA Test SARL',
      address: 'Douala, Cameroun',
      taxId: 'NUI123',
      phone: '690000000',
      email: 'contact@test.com',
      logoPath: '',
      legalText: 'Merci de votre confiance.',
      rccm: 'RC-DLA-2024-B123',
    );
    final client = Client(
      userId: 'u1',
      name: 'Client SARL',
      address: 'Yaoundé',
      taxId: 'NUI',
      phone: '691111111',
      email: 'client@test.com',
    );
    final item =
        LineItem(description: 'Service de conseil', quantity: 2, unitPrice: 50000);
    final invoice = Invoice(
      companyId: 'c1',
      clientId: 'cl1',
      invoiceNumber: 'FAC-001',
      issueDate: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 30)),
      items: [item],
      subtotal: 100000,
      taxRate: 18,
      taxAmount: 18000,
      totalAmount: 118000,
      status: 'paid',
    );
    final template = InvoiceTemplate(
      id: 't1',
      name: 'Test',
      description: 'Test',
      showLogo: true,
      showPaymentQR: true,
    );

    final bytes = await PrintingService.generateInvoicePdf(
      invoice: invoice,
      client: client,
      company: company,
      template: template,
      customPositions: positions,
      customMapping: template.mapping,
      customBackground: background,
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    // Écrit une copie dans le dossier temporaire (inspection manuelle possible).
    final out = File('${Directory.systemTemp.path}/repro_custom.pdf');
    await out.writeAsBytes(bytes);
    // ignore: avoid_print
    print('PDF écrit: ${out.path} (${bytes.length} octets)');
  });

  // Modèle ADMIN avec image de fond téléversée (template.fileData) ET chemin
  // InvoiceLayoutConfig (positions imbriquées SANS blocks_sections) → rendu
  // par blocs header/client/items/totals/footer. Le pied contient legalMention
  // + qrCode + signature : doit générer sans erreur.
  test('PDF modèle admin (fond image) + layout par blocs généré sans erreur',
      () async {
    // 1×1 PNG transparent (fausse image de fond admin).
    const tinyPngBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
    final layout = InvoiceLayoutConfig.defaultLayout().toMap();
    layout['show_signature_line'] = true;
    layout['show_paid_stamp'] = true;
    layout['custom_legal_text'] = 'Paiement sous 30 jours net.';

    SharedPreferences.setMockInitialValues({
      'template_custom_admin1': jsonEncode({
        'positions': layout, // clé 'positions' imbriquée → chemin par blocs
        'mapping': <String, String>{},
        'background': const TemplateBackgroundSettings().toMap(),
      }),
    });

    final company = Company(
      userId: 'u1',
      name: 'OHADA Admin SARL',
      address: 'Douala, Cameroun',
      taxId: 'NUI123',
      phone: '690000000',
      email: 'contact@test.com',
      logoPath: '',
      legalText: 'Merci de votre confiance.',
    );
    final client = Client(
      userId: 'u1',
      name: 'Client Admin',
      address: 'Yaoundé',
      taxId: 'NUI',
      phone: '691111111',
      email: 'client@test.com',
    );
    final item =
        LineItem(description: 'Prestation', quantity: 1, unitPrice: 25000);
    final invoice = Invoice(
      companyId: 'c1',
      clientId: 'cl1',
      invoiceNumber: 'FAC-ADMIN-1',
      issueDate: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 30)),
      items: [item],
      subtotal: 25000,
      taxRate: 18,
      taxAmount: 4500,
      totalAmount: 29500,
    );
    // Modèle admin : fond image téléversé (fileData) + QR activé.
    final template = InvoiceTemplate(
      id: 'admin1',
      name: 'Admin Fond',
      description: 'Modèle admin avec image de fond',
      showLogo: false,
      showPaymentQR: true,
      fileData: tinyPngBase64,
      fileType: 'png',
    );

    final bytes = await PrintingService.generateInvoicePdf(
      invoice: invoice,
      client: client,
      company: company,
      template: template,
      customPositions: layout,
      customMapping: template.mapping,
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    final out = File('${Directory.systemTemp.path}/repro_admin_bg.pdf');
    await out.writeAsBytes(bytes);
    // ignore: avoid_print
    print('PDF admin écrit: ${out.path} (${bytes.length} octets)');
  });
}
