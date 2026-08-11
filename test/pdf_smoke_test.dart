import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noi_ohada_invoice_pro/models/client.dart';
import 'package:noi_ohada_invoice_pro/models/company.dart';
import 'package:noi_ohada_invoice_pro/models/invoice.dart';
import 'package:noi_ohada_invoice_pro/models/invoice_template.dart';
import 'package:noi_ohada_invoice_pro/models/line_item.dart';
import 'package:noi_ohada_invoice_pro/services/printing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF généré avec customisation positionnée sans erreur', () async {
    // Simule une personnalisation enregistrée (positions drag & drop).
    SharedPreferences.setMockInitialValues({
      'template_custom_t1': jsonEncode({
        'positions': {
          'logo': {'x': 0.04, 'y': 0.02, 'scale': 1.0, 'visible': true},
          'company_name': {'x': 0.22, 'y': 0.04, 'scale': 1.0, 'visible': true},
          'company_address': {'x': 0.22, 'y': 0.07, 'scale': 1.0, 'visible': true},
          'invoice_title': {'x': 0.58, 'y': 0.04, 'scale': 1.0, 'visible': true},
          'client_name': {'x': 0.04, 'y': 0.16, 'scale': 1.0, 'visible': true},
          'client_address': {'x': 0.04, 'y': 0.19, 'scale': 1.0, 'visible': true},
          'items': {'x': 0.04, 'y': 0.30, 'scale': 1.0, 'visible': true},
          'subtotal': {'x': 0.5, 'y': 0.60, 'scale': 1.0, 'visible': true},
          'tax_amount': {'x': 0.5, 'y': 0.63, 'scale': 1.0, 'visible': true},
          'total_amount': {'x': 0.5, 'y': 0.69, 'scale': 1.0, 'visible': true},
          'footer': {'x': 0.04, 'y': 0.85, 'scale': 1.0, 'visible': true},
          'signature': {'x': 0.55, 'y': 0.86, 'scale': 1.0, 'visible': true},
          // variable masquée : ne doit PAS être rendue
          'company_phone': {'x': 0.22, 'y': 0.10, 'scale': 1.0, 'visible': false},
        },
        'mapping': {},
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
    );
    final client = Client(
      userId: 'u1',
      name: 'Client SARL',
      address: 'Yaoundé',
      taxId: 'NUI',
      phone: '691111111',
      email: 'client@test.com',
    );
    final item = LineItem(description: 'Service de conseil', quantity: 2, unitPrice: 50000);
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
    );
    final template = InvoiceTemplate(id: 't1', name: 'Test', description: 'Test', showLogo: true);

    final bytes = await PrintingService.generateInvoicePdf(
      invoice: invoice,
      client: client,
      company: company,
      template: template,
    );

    expect(bytes, isNotEmpty);
    // En-tête PDF.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
