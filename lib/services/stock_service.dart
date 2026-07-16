import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:noi_ohada_invoice_pro/models/notification.dart';
import '../models/product.dart';
import '../models/delivery.dart';
import '../services/notification_service.dart';

class StockService {
  static const String _productBoxName = 'products';
  static const String _deliveryBoxName = 'deliveries';

  final NotificationService _notificationService = NotificationService();
  final Map<String, String> _notifiedStatuses = {};

  bool _isInitialized = false;

  // Accesseurs sécurisés
  Box<Product> get _productBox => Hive.box<Product>(_productBoxName);
  Box<Delivery> get _deliveryBox => Hive.box<Delivery>(_deliveryBoxName);

  // ===== INITIALISATION =====

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      if (!Hive.isBoxOpen(_productBoxName)) await Hive.openBox<Product>(_productBoxName);
      if (!Hive.isBoxOpen(_deliveryBoxName)) await Hive.openBox<Delivery>(_deliveryBoxName);
      await _notificationService.init();
      _isInitialized = true;
      debugPrint('✅ StockService initialisé.');
    } catch (e) {
      debugPrint('❌ Erreur critique init StockService: $e');
      rethrow;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await init();
  }

  // ===== SYSTÈME D'ALERTES =====

  Future<void> _checkAndNotifyStockStatus(Product product) async {
    if (!product.isActive) return;

    final currentStatus = product.isOutOfStock
        ? 'out_of_stock'
        : (product.isLowStock ? 'low_stock' : 'normal');

    if (_notifiedStatuses[product.id] == currentStatus) return;

    _notifiedStatuses[product.id] = currentStatus;

    if (currentStatus == 'out_of_stock') {
      await _notificationService.addNotification(AppNotification.createStockOut(product.name));
    } else if (currentStatus == 'low_stock') {
      await _notificationService.addNotification(AppNotification.createLowStock(
        product.name, product.quantity, product.minStock));
    }
  }

  Future<void> checkAllProductsStockStatus() async {
    await _ensureInitialized();
    for (final product in _productBox.values) {
      await _checkAndNotifyStockStatus(product);
    }
  }

  // ===== PRODUITS =====

  Future<List<Product>> getProducts() async {
    await _ensureInitialized();
    return _productBox.values.toList();
  }

  Future<List<Product>> getActiveProducts() async {
    await _ensureInitialized();
    return _productBox.values.where((p) => p.isActive).toList();
  }

  Future<Product?> getProduct(String id) async {
    await _ensureInitialized();
    return _productBox.get(id);
  }

  Future<void> addProduct(Product product) async {
    await _ensureInitialized();
    await _productBox.put(product.id, product);
    await _checkAndNotifyStockStatus(product);
  }

  Future<void> updateProduct(Product product) async {
    await _ensureInitialized();
    if (!_productBox.containsKey(product.id)) throw Exception("Produit introuvable");
    await _productBox.put(product.id, product);
    await _checkAndNotifyStockStatus(product);
  }

  Future<void> deleteProduct(String id) async {
    await _ensureInitialized();
    await _productBox.delete(id);
    _notifiedStatuses.remove(id);
  }

  Future<void> updateStock(String productId, int quantity) async {
    final product = await getProduct(productId);
    if (product != null) {
      await updateProduct(product.copyWith(quantity: quantity, updatedAt: DateTime.now()));
    }
  }

  // ===== FILTRES =====

  Future<List<Product>> getLowStockProducts() async {
    await _ensureInitialized();
    return _productBox.values.where((p) => p.isLowStock && p.isActive).toList();
  }

  Future<List<Product>> getOutOfStockProducts() async {
    await _ensureInitialized();
    return _productBox.values.where((p) => p.isOutOfStock && p.isActive).toList();
  }

  Future<double> getTotalStockValue() async {
    await _ensureInitialized();
    return _productBox.values.fold<double>(0.0, (sum, p) => sum + p.stockValue);
  }

  Future<int> getTotalItems() async {
    await _ensureInitialized();
    return _productBox.values.fold<int>(0, (sum, p) => sum + p.quantity);
  }

  // ===== LIVRAISONS =====

  Future<List<Delivery>> getDeliveries() async {
    await _ensureInitialized();
    return _deliveryBox.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<Delivery?> getDelivery(String id) async {
    await _ensureInitialized();
    return _deliveryBox.get(id);
  }

  Future<void> addDelivery(Delivery delivery) async {
    await _ensureInitialized();
    final product = await getProduct(delivery.productId);
    if (product == null) throw Exception('Produit associé introuvable.');

    int newQuantity = product.quantity;
    if (delivery.isIncoming) newQuantity += delivery.quantity;
    if (delivery.isOutgoing) newQuantity -= delivery.quantity;

    await _deliveryBox.put(delivery.id, delivery);
    await updateStock(delivery.productId, newQuantity);
  }

  Future<void> updateDelivery(Delivery delivery) async {
    await _ensureInitialized();
    await _deliveryBox.put(delivery.id, delivery);
  }

  Future<void> completeDelivery(String id) async {
    await _ensureInitialized();
    final delivery = await getDelivery(id);
    if (delivery != null && !delivery.isCompleted) {
      await updateDelivery(delivery.copyWith(status: DeliveryStatus.completed.toString(), completedAt: DateTime.now()));
    }
  }

  Future<void> cancelDelivery(String id) async {
    await _ensureInitialized();
    final delivery = await getDelivery(id);
    if (delivery != null && !delivery.isCompleted) {
      final product = await getProduct(delivery.productId);
      if (product != null) {
        int newQuantity = product.quantity;
        if (delivery.isIncoming) newQuantity -= delivery.quantity;
        if (delivery.isOutgoing) newQuantity += delivery.quantity;
        await updateStock(delivery.productId, newQuantity);
      }
      await updateDelivery(delivery.copyWith(status: DeliveryStatus.cancelled.toString()));
    }
  }

  Future<List<Delivery>> getDeliveriesByProduct(String productId) async {
    await _ensureInitialized();
    return _deliveryBox.values.where((d) => d.productId == productId).toList();
  }

  Future<List<Delivery>> getPendingDeliveries() async {
    await _ensureInitialized();
    return _deliveryBox.values.where((d) => d.isPending).toList();
  }

  Future<List<Delivery>> getRecentDeliveries({int limit = 10}) async {
    await _ensureInitialized();
    final deliveries = await getDeliveries();
    return deliveries.take(limit).toList();
  }

  Future<void> clearAll() async {
    await _ensureInitialized();
    await _productBox.clear();
    await _deliveryBox.clear();
    _notifiedStatuses.clear();
  }

  // ===== LIENS FOURNISSEURS =====

  Future<List<Product>> getProductsBySupplier(String supplierId) async {
    await _ensureInitialized();
    return _productBox.values.where((p) => p.supplierId == supplierId).toList();
  }

  Future<bool> hasProductsForSupplier(String supplierId) async {
    await _ensureInitialized();
    return _productBox.values.any((p) => p.supplierId == supplierId);
  }
}