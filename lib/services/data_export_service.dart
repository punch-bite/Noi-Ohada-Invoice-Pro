// lib/services/data_export_service.dart
//
// 📤 Export des données métier (clients, stock, factures, fournisseurs,
// statistiques) aux formats JSON et CSV.
//
// Architecture :
//   • Méthodes STATIQUES PURES (transformations listes → lignes CSV /
//     backup JSON) : testables sans Firebase ni Hive ;
//   • Méthodes d'ORCHESTRATION (fetch Firestore + écriture fichier +
//     partage) : accès paresseux aux services (jamais au constructeur).
//
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/client.dart';
import '../models/delivery.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import 'config_service.dart';
import 'database_service.dart';
import 'stock_service.dart';
import 'supplier_service.dart';

/// 📦 Sections exportables (cochables dans l'UI).
enum ExportSection { clients, stock, invoices, suppliers, statistics }

extension ExportSectionX on ExportSection {
  String get label => switch (this) {
        ExportSection.clients => 'Clients',
        ExportSection.stock => 'Stock (produits & mouvements)',
        ExportSection.invoices => 'Factures & devis',
        ExportSection.suppliers => 'Fournisseurs',
        ExportSection.statistics => 'Statistiques',
      };
}

class DataExportService {
  // ⚠️ Getters PARESSEUX : les services qui touchent Firebase ne doivent
  // JAMAIS être instanciés dans des champs finaux (cf. SettingsService).
  DatabaseService get _db => DatabaseService();
  StockService get _stockService => StockService();
  SupplierService get _supplierService => SupplierService();

  // ══════════════════════════════════════════════════════════════════
  //  1. MÉTHODES PURES (testables sans Firebase)
  // ══════════════════════════════════════════════════════════════════

  /// Backup JSON complet — source unique partagée avec le backup Drive.
  static Map<String, dynamic> buildBackupFromData({
    required Map<String, dynamic> company,
    required List<Map<String, dynamic>> clients,
    required List<Map<String, dynamic>> products,
    required List<Map<String, dynamic>> deliveries,
    required List<Map<String, dynamic>> invoices,
    required List<Map<String, dynamic>> suppliers,
    required Map<String, dynamic> statistics,
  }) {
    return {
      'app': 'noi_ohada_invoice_pro',
      'format': 'noi-ohada-export',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'appVersion': ConfigService.appVersion,
      // try/catch : FirebaseAuth.instance lève si Firebase n'est pas
      // initialisé (tests, usage purement local).
      'ownerEmail': _currentUserEmail(),
      'company': company,
      'counts': {
        'clients': clients.length,
        'products': products.length,
        'deliveries': deliveries.length,
        'invoices': invoices.length,
        'suppliers': suppliers.length,
      },
      'clients': clients,
      'stock': {
        'products': products,
        'movements': deliveries,
      },
      'invoices': invoices,
      'suppliers': suppliers,
      'statistics': statistics,
    };
  }

  static String encodeBackupJson(Map<String, dynamic> backup) =>
      const JsonEncoder.withIndent('  ', _toEncodable).convert(backup);

  /// 🔁 Rend les objets non natifs JSON encodables : les `toMap()` des
  /// modèles contiennent des `Timestamp` Firestore (createdAt/updatedAt…).
  /// Sans ce convertisseur, `jsonEncode` lève « Converting object to an
  /// encodable object failed: Instance of 'Timestamp' » → LE backup Drive
  /// échouait systématiquement dès qu'une donnée avait un horodatage.
  static Object? _toEncodable(Object? value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value == null) return null;
    return '$value';
  }

  /// Email de l'utilisateur courant, sans lever si Firebase est absent.
  static String _currentUserEmail() {
    try {
      return FirebaseAuth.instance.currentUser?.email ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Convertit des lignes en CSV (séparateur `;` lisible par Excel FR).
  static String toCsv(List<List<dynamic>> rows) =>
      const ListToCsvConverter(fieldDelimiter: ';', eol: '\r\n')
          .convert(rows);

  // ── Lignes CSV par section ──
  static List<List<dynamic>> clientsRows(List<Client> clients) {
    final rows = <List<dynamic>>[
      ['ID', 'Nom', 'Email', 'Téléphone', 'Adresse', 'NUI/TaxId', 'Créé le'],
    ];
    for (final c in clients) {
      final m = c.toMap();
      rows.add([
        c.id,
        m['name'] ?? '',
        m['email'] ?? '',
        m['phone'] ?? '',
        m['address'] ?? '',
        m['taxId'] ?? '',
        _fmtDate(m['createdAt']),
      ]);
    }
    return rows;
  }

  static List<List<dynamic>> productsRows(List<Product> products) {
    final rows = <List<dynamic>>[
      [
        'ID', 'Désignation', 'Catégorie', 'Quantité', 'Stock min',
        'Prix achat', 'Prix vente', 'Actif', 'Fournisseur ID',
      ],
    ];
    for (final p in products) {
      final m = p.toMap();
      rows.add([
        p.id,
        m['name'] ?? '',
        m['category'] ?? '',
        m['quantity'] ?? 0,
        m['minStock'] ?? 0,
        m['costPrice'] ?? '',
        m['price'] ?? '',
        (m['isActive'] ?? true) ? 'Oui' : 'Non',
        m['supplierId'] ?? '',
      ]);
    }
    return rows;
  }

  static List<List<dynamic>> deliveriesRows(List<Delivery> deliveries) {
    final rows = <List<dynamic>>[
      [
        'ID', 'Produit ID', 'Type', 'Quantité', 'Statut',
        'Date', 'Référence', 'Notes',
      ],
    ];
    for (final d in deliveries) {
      final m = d.toMap();
      rows.add([
        d.id,
        m['productId'] ?? '',
        m['type'] ?? '',
        m['quantity'] ?? 0,
        m['status'] ?? '',
        _fmtDate(m['createdAt'] ?? m['date']),
        m['reference'] ?? '',
        m['notes'] ?? '',
      ]);
    }
    return rows;
  }

  static List<List<dynamic>> invoicesRows(List<Invoice> invoices) {
    final rows = <List<dynamic>>[
      [
        'Numéro', 'Type', 'Client ID', 'Statut', 'Date émission',
        'Date échéance', 'Sous-total', 'TVA %', 'Montant TVA',
        'Remise', 'Total',
      ],
    ];
    for (final i in invoices) {
      rows.add([
        i.invoiceNumber,
        i.isDevis ? 'Devis' : 'Facture',
        i.clientId,
        i.status,
        _fmtDate(i.issueDate),
        _fmtDate(i.dueDate),
        i.subtotal,
        i.taxRate,
        i.taxAmount,
        i.discount,
        i.totalAmount,
      ]);
    }
    return rows;
  }

  /// Lignes d'articles (détail) — jointure logique par numéro de facture.
  static List<List<dynamic>> invoiceItemsRows(List<Invoice> invoices) {
    final rows = <List<dynamic>>[
      ['Facture', 'Description', 'Quantité', 'PU HT', 'TVA %', 'Total'],
    ];
    for (final i in invoices) {
      for (final item in i.items) {
        final m = item.toMap();
        rows.add([
          i.invoiceNumber,
          m['description'] ?? '',
          _fmtNum(m['quantity']),
          _fmtNum(m['unitPrice']),
          _fmtNum(m['taxRate']),
          _fmtNum(m['total']),
        ]);
      }
    }
    return rows;
  }

  static List<List<dynamic>> suppliersRows(List<Supplier> suppliers) {
    final rows = <List<dynamic>>[
      ['ID', 'Nom', 'Email', 'Téléphone', 'Adresse', 'Actif'],
    ];
    for (final s in suppliers) {
      final m = s.toMap();
      rows.add([
        s.id,
        m['name'] ?? '',
        m['email'] ?? '',
        m['phone'] ?? '',
        m['address'] ?? '',
        (m['isActive'] ?? true) ? 'Oui' : 'Non',
      ]);
    }
    return rows;
  }

  static List<List<dynamic>> statisticsRows({
    required Map<String, dynamic> general,
    required List<Map<String, dynamic>> monthly,
  }) {
    final rows = <List<dynamic>>[
      ['=== STATISTIQUES GÉNÉRALES ===', ''],
    ];
    general.forEach((k, v) => rows.add([_frKey(k), _fmtNum(v)]));
    rows.add(['', '']);
    rows.add(['=== STATISTIQUES MENSUELLES (12 derniers mois) ===', '']);
    rows.add(['Mois', 'Factures', 'CA', 'Payé', 'En attente', 'En retard']);
    for (final m in monthly) {
      rows.add([
        m['month'] ?? '',
        m['count'] ?? 0,
        _fmtNum(m['revenue']),
        _fmtNum(m['paid']),
        _fmtNum(m['pending']),
        _fmtNum(m['overdue']),
      ]);
    }
    return rows;
  }

  /// 📊 Statistiques calculées depuis les données (même logique que le
  /// dashboard) : CA global/par statut, par mois, top clients, stock.
  static Map<String, dynamic> computeStatistics({
    required List<Invoice> invoices,
    required List<Product> products,
    required List<Client> clients,
  }) {
    final now = DateTime.now();
    final totalRevenue =
        invoices.fold<double>(0, (s, i) => s + i.totalAmount);
    final paidRevenue = invoices
        .where((i) => i.status == 'paid')
        .fold<double>(0, (s, i) => s + i.totalAmount);

    // CA par mois (12 derniers mois).
    final Map<String, Map<String, dynamic>> monthly = {};
    for (final inv in invoices) {
      if (inv.issueDate
          .isBefore(DateTime(now.year, now.month - 11, 1))) {
        continue;
      }
      final key =
          '${inv.issueDate.year}-${inv.issueDate.month.toString().padLeft(2, '0')}';
      final data = monthly.putIfAbsent(key, () => {
            'month': key,
            'count': 0,
            'revenue': 0.0,
            'paid': 0.0,
            'pending': 0.0,
            'overdue': 0.0,
          });
      data['count'] = (data['count'] as int) + 1;
      data['revenue'] = (data['revenue'] as double) + inv.totalAmount;
      switch (inv.status) {
        case 'paid':
          data['paid'] = (data['paid'] as double) + inv.totalAmount;
          break;
        case 'sent':
          data['pending'] = (data['pending'] as double) + inv.totalAmount;
          break;
        case 'overdue':
          data['overdue'] = (data['overdue'] as double) + inv.totalAmount;
          break;
      }
    }
    final monthlyList = monthly.values.toList()
      ..sort((a, b) =>
          (a['month'] as String).compareTo(b['month'] as String));

    // Top 5 clients par CA.
    final Map<String, double> byClient = {};
    for (final inv in invoices) {
      byClient[inv.clientId] = (byClient[inv.clientId] ?? 0) + inv.totalAmount;
    }
    final topClients = byClient.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final clientName = {
      for (final c in clients) c.id: (c.toMap()['name'] ?? c.id).toString(),
    };

    final stockValue =
        products.fold<double>(0, (s, p) => s + (p.price * p.quantity));

    return {
      'generatedAt': now.toIso8601String(),
      'general': {
        'totalInvoices': invoices.length,
        'totalClients': clients.length,
        'totalProducts': products.length,
        'totalRevenue': totalRevenue,
        'totalPaid': paidRevenue,
        'totalPending': invoices
            .where((i) => i.status == 'sent')
            .fold<double>(0, (s, i) => s + i.totalAmount),
        'totalOverdue': invoices
            .where((i) => i.status == 'overdue')
            .fold<double>(0, (s, i) => s + i.totalAmount),
        'collectionRate': totalRevenue > 0 ? paidRevenue / totalRevenue : 0.0,
        'averageInvoiceValue':
            invoices.isNotEmpty ? totalRevenue / invoices.length : 0.0,
        'stockValue': stockValue,
        'lowStockProducts': products.where((p) => p.isLowStock).length,
        'outOfStockProducts': products.where((p) => p.isOutOfStock).length,
      },
      'monthly': monthlyList,
      'topClients': topClients.take(5).map((e) => {
            'clientId': e.key,
            'name': clientName[e.key] ?? e.key,
            'revenue': e.value,
          }).toList(),
    };
  }

  // ── Helpers de formatage ──
  static String _fmtDate(dynamic d) {
    if (d is DateTime) return d.toIso8601String().substring(0, 10);
    final parsed = DateTime.tryParse('$d');
    return parsed != null ? parsed.toIso8601String().substring(0, 10) : '$d';
  }

  static String _fmtNum(dynamic v) {
    if (v is num) {
      return v % 1 == 0
          ? v.toStringAsFixed(0)
          : v.toStringAsFixed(2).replaceAll('.', ',');
    }
    return '$v';
  }

  /// Clés techniques → libellés français lisibles dans le CSV.
  static String _frKey(String key) => switch (key) {
        'totalInvoices' => 'Total factures',
        'totalClients' => 'Total clients',
        'totalProducts' => 'Total produits',
        'totalRevenue' => "Chiffre d'affaires",
        'totalPaid' => 'Total payé',
        'totalPending' => 'Total en attente',
        'totalOverdue' => 'Total en retard',
        'collectionRate' => 'Taux de recouvrement',
        'averageInvoiceValue' => 'Panier moyen',
        'stockValue' => 'Valeur du stock',
        'lowStockProducts' => 'Produits en stock bas',
        'outOfStockProducts' => 'Produits en rupture',
        _ => key,
      };

  // ══════════════════════════════════════════════════════════════════
  //  2. ORCHESTRATION (Firestore + fichiers + partage)
  // ══════════════════════════════════════════════════════════════════

  /// 🗂️ Export JSON complet des sections cochées.
  Future<ExportResult> exportToJson(Set<ExportSection> sections) async {
    final data = await _fetchData(sections);
    final backup = buildBackupFromData(
      company: data.company,
      clients: data.clients.map((c) => c.toMap()).toList(),
      products: data.products.map((p) => p.toMap()).toList(),
      deliveries: data.deliveries.map((d) => d.toMap()).toList(),
      invoices: data.invoices.map((i) => i.toMap()).toList(),
      suppliers: data.suppliers.map((s) => s.toMap()).toList(),
      statistics: data.statistics,
    );
    final path = await _writeFile(
      'export_noi_ohada_${_stamp()}.json',
      encodeBackupJson(backup),
    );
    return ExportResult(
      files: [File(path)],
      summary:
          '${data.clients.length} clients · ${data.products.length} produits · '
          '${data.invoices.length} factures · ${data.suppliers.length} fournisseurs',
    );
  }

  // ── Récupération des données (Firestore) ──

  /// 🔎 Collecte publique des données (utilisée aussi par le backup Drive
  /// pour rester la source unique de vérité).
  Future<ExportData> fetchDataForBackup(Set<ExportSection> sections) async {
    return _fetchData(sections);
  }

  Future<ExportData> _fetchData(Set<ExportSection> sections) async {
    final company = await _db.getCompany();
    // Clients & factures : socle commun (factures + stats + top clients).
    final needInvoices = sections.contains(ExportSection.invoices) ||
        sections.contains(ExportSection.statistics);
    final clients = sections.contains(ExportSection.clients) ||
            sections.contains(ExportSection.statistics)
        ? await _db.getClients()
        : <Client>[];
    final invoices = needInvoices ? await _db.getInvoices() : <Invoice>[];

    final products = sections.contains(ExportSection.stock) ||
            sections.contains(ExportSection.statistics)
        ? await _db.getProducts()
        : <Product>[];
    final deliveries = sections.contains(ExportSection.stock)
        ? await _stockService.getDeliveries()
        : <Delivery>[];
    final suppliers = sections.contains(ExportSection.suppliers)
        ? await _supplierService.getSuppliers()
        : <Supplier>[];

    final statistics = sections.contains(ExportSection.statistics)
        ? computeStatistics(
            invoices: invoices, products: products, clients: clients)
        : <String, dynamic>{};

    return ExportData(
      company: company?.toMap() ?? <String, dynamic>{},
      clients: clients,
      products: products,
      deliveries: deliveries,
      invoices: invoices,
      suppliers: suppliers,
      statistics: statistics,
    );
  }

  static String _stamp() {
    final d = DateTime.now();
    return '${d.year}${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}_'
        '${d.hour.toString().padLeft(2, '0')}'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  // ── Export CSV : un fichier par section cochée ──
  Future<ExportResult> exportToCsv(Set<ExportSection> sections) async {
    final data = await _fetchData(sections);
    final files = <File>[];

    if (sections.contains(ExportSection.clients)) {
      files.add(File(await _writeFile(
          'clients_${_stamp()}.csv', toCsv(clientsRows(data.clients)))));
    }
    if (sections.contains(ExportSection.stock)) {
      files.add(File(await _writeFile('stock_produits_${_stamp()}.csv',
          toCsv(productsRows(data.products)))));
      files.add(File(await _writeFile('stock_mouvements_${_stamp()}.csv',
          toCsv(deliveriesRows(data.deliveries)))));
    }
    if (sections.contains(ExportSection.invoices)) {
      files.add(File(await _writeFile('factures_${_stamp()}.csv',
          toCsv(invoicesRows(data.invoices)))));
      files.add(File(await _writeFile('factures_articles_${_stamp()}.csv',
          toCsv(invoiceItemsRows(data.invoices)))));
    }
    if (sections.contains(ExportSection.suppliers)) {
      files.add(File(await _writeFile('fournisseurs_${_stamp()}.csv',
          toCsv(suppliersRows(data.suppliers)))));
    }
    if (sections.contains(ExportSection.statistics)) {
      final stats = data.statistics;
      files.add(File(await _writeFile(
          'statistiques_${_stamp()}.csv',
          toCsv(statisticsRows(
            general: (stats['general'] as Map<String, dynamic>? ?? {}),
            monthly: (stats['monthly'] as List? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList(),
          )))));
    }

    if (files.isEmpty) {
      throw Exception("Aucune section sélectionnée pour l'export");
    }
    return ExportResult(
      files: files,
      summary: '${files.length} fichier(s) CSV généré(s)',
    );
  }

  /// 🔗 Partage les fichiers générés (feuille de partage native).
  Future<void> shareFiles(List<File> files, {String? subject}) async {
    if (files.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [for (final f in files) XFile(f.path)],
        subject: subject ?? 'Export de données — NOI OHADA Invoice Pro',
      ),
    );
  }

  // ── Écriture fichier (Documents/exports) ──
  Future<String> _writeFile(String fileName, String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}${Platform.pathSeparator}exports');
    if (!exportDir.existsSync()) {
      exportDir.createSync(recursive: true);
    }
    final file = File('${exportDir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(content, flush: true);
    debugPrint('📤 Export écrit : ${file.path}');
    return file.path;
  }
}

/// 🗂️ Données collectées pour un export.
class ExportData {
  final Map<String, dynamic> company;
  final List<Client> clients;
  final List<Product> products;
  final List<Delivery> deliveries;
  final List<Invoice> invoices;
  final List<Supplier> suppliers;
  final Map<String, dynamic> statistics;

  const ExportData({
    required this.company,
    required this.clients,
    required this.products,
    required this.deliveries,
    required this.invoices,
    required this.suppliers,
    required this.statistics,
  });
}

/// Résultat d'un export : fichiers générés + résumé lisible.
class ExportResult {
  final List<File> files;
  final String summary;
  const ExportResult({required this.files, required this.summary});
}


