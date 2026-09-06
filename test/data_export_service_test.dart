// test/data_export_service_test.dart
//
// 🧪 Teste les transformations PURES du DataExportService (backup JSON,
// lignes CSV, statistiques) — sans Firebase ni fichier.
import 'package:flutter_test/flutter_test.dart';
import 'package:noi_ohada_invoice_pro/models/client.dart';
import 'package:noi_ohada_invoice_pro/models/delivery.dart';
import 'package:noi_ohada_invoice_pro/models/invoice.dart';
import 'package:noi_ohada_invoice_pro/models/line_item.dart';
import 'package:noi_ohada_invoice_pro/models/product.dart';
import 'package:noi_ohada_invoice_pro/models/supplier.dart';
import 'package:noi_ohada_invoice_pro/services/data_export_service.dart';

void main() {
  final client = Client(
    userId: 'u1',
    name: 'Client SARL',
    address: 'Yaoundé',
    taxId: 'NUI1',
    phone: '691111111',
    email: 'client@test.cm',
  );
  final product = Product(
    userId: 'u1',
    name: 'Ciment 50kg',
    category: 'Matériaux',
    price: 5000,
    costPrice: 4000,
    quantity: 3,
    minStock: 5,
  );
  final delivery = Delivery(
    productId: product.id,
    productName: product.name,
    quantity: 10,
    type: 'incoming',
    status: 'completed',
  );
  final invoice = Invoice(
    companyId: 'c1',
    clientId: client.id,
    invoiceNumber: 'FA-2026-001',
    issueDate: DateTime(2026, 9, 1),
    dueDate: DateTime(2026, 10, 1),
    items: [LineItem(description: 'Ciment 50kg', quantity: 2, unitPrice: 5000)],
    subtotal: 10000,
    taxRate: 18,
    taxAmount: 1800,
    totalAmount: 11800,
    status: 'paid',
  );
  final supplier = Supplier(userId: 'u1', name: 'Fournisseur SA');

  test('buildBackupFromData produit un JSON complet et compté', () {
    final backup = DataExportService.buildBackupFromData(
      company: {'name': 'Ma SARL'},
      clients: [client.toMap()],
      products: [product.toMap()],
      deliveries: [delivery.toMap()],
      invoices: [invoice.toMap()],
      suppliers: [supplier.toMap()],
      statistics: DataExportService.computeStatistics(
        invoices: [invoice],
        products: [product],
        clients: [client],
      ),
    );

    expect(backup['app'], 'noi_ohada_invoice_pro');
    expect(backup['version'], 2);
    final counts = backup['counts'] as Map<String, dynamic>;
    expect(counts['clients'], 1);
    expect(counts['products'], 1);
    expect(counts['deliveries'], 1);
    expect(counts['invoices'], 1);
    expect(counts['suppliers'], 1);
    // Sections imbriquées présentes.
    expect((backup['stock'] as Map)['products'], isNotEmpty);
    expect((backup['stock'] as Map)['movements'], isNotEmpty);
    expect(backup['suppliers'], isNotEmpty);
    expect((backup['statistics'] as Map)['general'], isNotNull);
    // Sérialisable sans erreur.
    expect(
      DataExportService.encodeBackupJson(backup),
      contains('noi_ohada_invoice_pro'),
    );
  });

  test('computeStatistics calcule CA, top clients et indicateurs stock', () {
    final stats = DataExportService.computeStatistics(
      invoices: [invoice],
      products: [product],
      clients: [client],
    );
    final general = stats['general'] as Map<String, dynamic>;
    expect(general['totalInvoices'], 1);
    expect(general['totalRevenue'], 11800.0);
    expect(general['totalPaid'], 11800.0);
    expect(general['collectionRate'], 1.0);
    // Stock : 3 × 5000 = 15000 ; quantity 3 <= minStock 5 → stock bas.
    expect(general['stockValue'], 15000.0);
    expect(general['lowStockProducts'], 1);
    expect((stats['topClients'] as List).first['name'], 'Client SARL');
  });

  test('clientsRows / productsRows / deliveriesRows génèrent des CSV valides',
      () {
    final csv = DataExportService.toCsv(
        DataExportService.clientsRows([client]));
    expect(csv.split('\r\n').first, contains('Nom'));
    expect(csv, contains('Client SARL'));

    final productsCsv = DataExportService.toCsv(
        DataExportService.productsRows([product]));
    expect(productsCsv, contains('Ciment 50kg'));
    expect(productsCsv, contains('5000'));

    final deliveriesCsv = DataExportService.toCsv(
        DataExportService.deliveriesRows([delivery]));
    expect(deliveriesCsv, contains('incoming'));
    expect(deliveriesCsv, contains('10'));
  });

  test('invoicesRows + invoiceItemsRows couvrent facture et articles', () {
    final invoicesCsv = DataExportService.toCsv(
        DataExportService.invoicesRows([invoice]));
    expect(invoicesCsv, contains('FA-2026-001'));
    expect(invoicesCsv, contains('11800'));

    final itemsCsv = DataExportService.toCsv(
        DataExportService.invoiceItemsRows([invoice]));
    expect(itemsCsv, contains('Ciment 50kg'));
    expect(itemsCsv, contains('5000'));
    expect(itemsCsv, contains('11800'));
  });

  test('statisticsRows inclut les blocs général et mensuel', () {
    final stats = DataExportService.computeStatistics(
      invoices: [invoice],
      products: [product],
      clients: [client],
    );
    final csv = DataExportService.toCsv(DataExportService.statisticsRows(
      general: stats['general'] as Map<String, dynamic>,
      monthly: (stats['monthly'] as List).cast<Map<String, dynamic>>(),
    ));
    expect(csv, contains('STATISTIQUES GÉNÉRALES'));
    expect(csv, contains('Chiffre d\'affaires'));
    expect(csv, contains('STATISTIQUES MENSUELLES'));
    expect(csv, contains('2026-09'));
  });
}
