// lib/services/supplier_service.dart
//
// ✅ Fournisseurs — FIRESTORE (plus de Hive).
// Les fournisseurs sont stockés dans la collection `suppliers`, scopée par UID.
//
import 'package:flutter/foundation.dart';
import '../models/supplier.dart';
import '../services/database_service.dart';
import '../services/stock_service.dart'; // Relation produits fournisseur

class SupplierService {
  final DatabaseService _db = DatabaseService();

  // Injection du StockService
  final StockService _stockService;

  SupplierService({StockService? stockService})
      : _stockService = stockService ?? StockService();

  Future<void> init() async {
    // Firestore ne nécessite aucune initialisation locale.
    debugPrint('✅ SupplierService (Firestore)');
  }

  // ===== CRUD (Firestore) =====

  Future<List<Supplier>> getSuppliers() async {
    final suppliers = await _db.getSuppliers();
    suppliers.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return suppliers;
  }

  Future<Supplier?> getSupplier(String id) async {
    return _db.getSupplier(id);
  }

  Future<void> addSupplier(Supplier supplier) async {
    await _db.saveSupplier(supplier);
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await _db.saveSupplier(supplier);
  }

  Future<void> deleteSupplier(String id) async {
    await _db.deleteSupplier(id);
  }

  // ===== Logique métier croisée =====

  Future<bool> hasProducts(String supplierId) async {
    final products = await _stockService.getProductsBySupplier(supplierId);
    return products.isNotEmpty;
  }

  Future<Supplier?> getActiveSupplier() async {
    final suppliers = await getSuppliers();
    for (final s in suppliers) {
      if (s.isActive) return s;
    }
    return null;
  }
}
