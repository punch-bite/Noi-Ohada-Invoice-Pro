import 'package:hive_flutter/hive_flutter.dart';
import '../models/supplier.dart';
import '../services/stock_service.dart'; // Importez votre service de stock

class SupplierService {
  static const String _supplierBox = 'suppliers';
  late Box<Supplier> _supplierBoxInstance;
  bool _isInitialized = false;

  // Injection du StockService
  final StockService _stockService;

  SupplierService({StockService? stockService})
      : _stockService = stockService ?? StockService();

  Future<void> init() async {
    if (_isInitialized) return;
    if (!Hive.isBoxOpen(_supplierBox)) {
      _supplierBoxInstance = await Hive.openBox<Supplier>(_supplierBox);
    } else {
      _supplierBoxInstance = Hive.box<Supplier>(_supplierBox);
    }
    _isInitialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await init();
  }

  // ===== CRUD Optimisé =====

  Future<List<Supplier>> getSuppliers() async {
    await _ensureInitialized();
    return _supplierBoxInstance.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<Supplier?> getSupplier(String id) async {
    await _ensureInitialized();
    // Utilisation de .get si l'ID est la clé Hive, sinon firstWhere
    return _supplierBoxInstance.values
        .cast<Supplier?>()
        .firstWhere((s) => s?.id == id, orElse: () => null);
  }

  Future<void> addSupplier(Supplier supplier) async {
    await _ensureInitialized();
    // Si l'ID est la clé Hive, utilisez .put(supplier.id, supplier)
    await _supplierBoxInstance.put(supplier.id, supplier);
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await _ensureInitialized();
    // Utiliser la clé ID pour la mise à jour directe (plus performant que putAt)
    await _supplierBoxInstance.put(supplier.id, supplier);
  }

  Future<void> deleteSupplier(String id) async {
    await _ensureInitialized();
    await _supplierBoxInstance.delete(id);
  }

  // ===== Logique métier croisée =====

  Future<bool> hasProducts(String supplierId) async {
    await _ensureInitialized();
    // Utilisation du StockService injecté pour vérifier les relations
    final products = await _stockService.getProductsBySupplier(supplierId);
    return products.isNotEmpty;
  }

  Future<Supplier?> getActiveSupplier() async {
    final box = Hive.box<Supplier>(_supplierBox);
    // Recherche le premier fournisseur dont le champ isActive est vrai
    return box.values.cast<Supplier?>().firstWhere(
          (s) => s?.isActive == true,
          orElse: () => null,
        );
  }
}
