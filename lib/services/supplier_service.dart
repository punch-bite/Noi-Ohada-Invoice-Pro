// lib/services/supplier_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../models/supplier.dart';

class SupplierService {
  static const String _supplierBox = 'suppliers';
  late Box<Supplier> _supplierBoxInstance;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _supplierBoxInstance = await Hive.openBox<Supplier>(_supplierBox);
    _isInitialized = true;
    print('✅ SupplierService initialisé avec ${_supplierBoxInstance.length} fournisseurs');
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await init();
  }

  // ===== CRUD =====

  Future<List<Supplier>> getSuppliers() async {
    await _ensureInitialized();
    final list = _supplierBoxInstance.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<List<Supplier>> getActiveSuppliers() async {
    await _ensureInitialized();
    return _supplierBoxInstance.values
        .where((s) => s.isActive)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<Supplier?> getSupplier(String id) async {
    await _ensureInitialized();
    try {
      return _supplierBoxInstance.values.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> addSupplier(Supplier supplier) async {
    await _ensureInitialized();
    await _supplierBoxInstance.add(supplier);
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await _ensureInitialized();
    final index = _supplierBoxInstance.values
        .toList()
        .indexWhere((s) => s.id == supplier.id);
    if (index != -1) {
      await _supplierBoxInstance.putAt(index, supplier);
    }
  }

  Future<void> deleteSupplier(String id) async {
    await _ensureInitialized();
    final index = _supplierBoxInstance.values
        .toList()
        .indexWhere((s) => s.id == id);
    if (index != -1) {
      await _supplierBoxInstance.deleteAt(index);
    }
  }

  Future<bool> hasProducts(String supplierId) async {
    // Vérifier si le fournisseur est lié à des produits
    // Nécessite une référence à StockService
    // On utilisera une injection ou une méthode séparée
    return false; // À implémenter avec un service croisé
  }
}