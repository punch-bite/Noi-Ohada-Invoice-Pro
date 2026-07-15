// lib/services/stock_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:noi_ohada_invoice_pro/models/notification.dart';
import '../models/product.dart';
import '../models/delivery.dart';
import '../services/notification_service.dart';

class StockService {
  static const String _productBox = 'products';
  static const String _deliveryBox = 'deliveries';

  late Box<Product> _productBoxInstance;
  late Box<Delivery> _deliveryBoxInstance;
  bool _isInitialized = false;

  // Cache pour éviter les notifications en double
  final Map<String, String> _notifiedStatuses = {}; // productId -> 'low_stock' | 'out_of_stock' | 'normal'

  final NotificationService _notificationService = NotificationService();

  // ===== INITIALISATION =====

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _productBoxInstance = await Hive.openBox<Product>(_productBox);
      _deliveryBoxInstance = await Hive.openBox<Delivery>(_deliveryBox);
      _isInitialized = true;
      await _notificationService.init();
      print('✅ StockService initialisé avec ${_productBoxInstance.length} produits');
    } catch (e) {
      print('❌ Erreur init StockService: $e');
      rethrow;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  // ===== VÉRIFICATION ET ENVOI DE NOTIFICATIONS =====

  Future<void> _checkAndNotifyStockStatus(Product product) async {
    if (!product.isActive) return;

    final currentStatus = product.isOutOfStock 
        ? 'out_of_stock' 
        : (product.isLowStock ? 'low_stock' : 'normal');

    final previousStatus = _notifiedStatuses[product.id] ?? 'normal';

    if (currentStatus == previousStatus) return;

    _notifiedStatuses[product.id] = currentStatus;

    if (currentStatus == 'out_of_stock') {
      final notification = AppNotification.createStockOut(product.name);
      await _notificationService.addNotification(notification);
      print('🔔 Notification rupture de stock pour ${product.name}');
    } else if (currentStatus == 'low_stock') {
      final notification = AppNotification.createLowStock(
        product.name,
        product.quantity,
        product.minStock,
      );
      await _notificationService.addNotification(notification);
      print('🔔 Notification stock faible pour ${product.name}');
    }
  }

  Future<void> checkAllProductsStockStatus() async {
    await _ensureInitialized();
    final products = await getProducts();
    for (final product in products) {
      await _checkAndNotifyStockStatus(product);
    }
  }

  // ===== PRODUCTS =====

  Future<List<Product>> getProducts() async {
    await _ensureInitialized();
    try {
      return _productBoxInstance.values.toList();
    } catch (e) {
      print('❌ Erreur getProducts: $e');
      return [];
    }
  }

  Future<List<Product>> getActiveProducts() async {
    await _ensureInitialized();
    try {
      return _productBoxInstance.values.where((p) => p.isActive).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Product?> getProduct(String id) async {
    await _ensureInitialized();
    try {
      return _productBoxInstance.values.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> addProduct(Product product) async {
    await _ensureInitialized();
    try {
      await _productBoxInstance.add(product);
      print('✅ Produit ajouté: ${product.name}');
      await _checkAndNotifyStockStatus(product);
    } catch (e) {
      print('❌ Erreur addProduct: $e');
      throw Exception('Erreur lors de l\'ajout du produit: $e');
    }
  }

  Future<void> updateProduct(Product product) async {
    await _ensureInitialized();
    try {
      final index = _productBoxInstance.values
          .toList()
          .indexWhere((p) => p.id == product.id);
      if (index != -1) {
        await _productBoxInstance.putAt(index, product);
        print('✅ Produit mis à jour: ${product.name}');
        await _checkAndNotifyStockStatus(product);
      } else {
        throw Exception('Produit non trouvé');
      }
    } catch (e) {
      print('❌ Erreur updateProduct: $e');
      throw Exception('Erreur lors de la mise à jour du produit: $e');
    }
  }

  Future<void> deleteProduct(String id) async {
    await _ensureInitialized();
    try {
      final index =
          _productBoxInstance.values.toList().indexWhere((p) => p.id == id);
      if (index != -1) {
        await _productBoxInstance.deleteAt(index);
        _notifiedStatuses.remove(id);
        print('✅ Produit supprimé: $id');
      }
    } catch (e) {
      print('❌ Erreur deleteProduct: $e');
      throw Exception('Erreur lors de la suppression du produit: $e');
    }
  }

  Future<void> updateStock(String productId, int quantity) async {
    await _ensureInitialized();
    final product = await getProduct(productId);
    if (product != null) {
      final updated = product.copyWith(
        quantity: quantity,
        updatedAt: DateTime.now(),
      );
      await updateProduct(updated);
    }
  }

  Future<List<Product>> getLowStockProducts() async {
    await _ensureInitialized();
    return _productBoxInstance.values
        .where((p) => p.isLowStock && p.isActive)
        .toList();
  }

  Future<List<Product>> getOutOfStockProducts() async {
    await _ensureInitialized();
    return _productBoxInstance.values
        .where((p) => p.isOutOfStock && p.isActive)
        .toList();
  }

  Future<double> getTotalStockValue() async {
    await _ensureInitialized();
    return _productBoxInstance.values
        .fold<double>(0.0, (sum, p) => sum + p.stockValue);
  }

  Future<int> getTotalItems() async {
    await _ensureInitialized();
    return _productBoxInstance.values
        .fold<int>(0, (sum, p) => sum + p.quantity);
  }

  // ===== DELIVERIES =====

  Future<List<Delivery>> getDeliveries() async {
    await _ensureInitialized();
    return _deliveryBoxInstance.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<Delivery?> getDelivery(String id) async {
    await _ensureInitialized();
    try {
      return _deliveryBoxInstance.values.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> addDelivery(Delivery delivery) async {
    await _ensureInitialized();
    final product = await getProduct(delivery.productId);
    if (product != null) {
      int newQuantity = product.quantity;
      if (delivery.isIncoming) {
        newQuantity += delivery.quantity;
      } else if (delivery.isOutgoing) {
        newQuantity -= delivery.quantity;
      }
      await updateStock(delivery.productId, newQuantity);
    }
    await _deliveryBoxInstance.add(delivery);
  }

  Future<void> updateDelivery(Delivery delivery) async {
    await _ensureInitialized();
    final index = _deliveryBoxInstance.values
        .toList()
        .indexWhere((d) => d.id == delivery.id);
    if (index != -1) {
      await _deliveryBoxInstance.putAt(index, delivery);
    }
  }

  Future<void> completeDelivery(String id) async {
    await _ensureInitialized();
    final delivery = await getDelivery(id);
    if (delivery != null && !delivery.isCompleted) {
      final updated = delivery.copyWith(
        status: DeliveryStatus.completed.toString(),
        completedAt: DateTime.now(),
      );
      await updateDelivery(updated);
    }
  }

  Future<void> cancelDelivery(String id) async {
    await _ensureInitialized();
    final delivery = await getDelivery(id);
    if (delivery != null && !delivery.isCompleted) {
      final product = await getProduct(delivery.productId);
      if (product != null) {
        int newQuantity = product.quantity;
        if (delivery.isIncoming) {
          newQuantity -= delivery.quantity;
        } else if (delivery.isOutgoing) {
          newQuantity += delivery.quantity;
        }
        await updateStock(delivery.productId, newQuantity);
      }
      final updated = delivery.copyWith(
        status: DeliveryStatus.cancelled.toString(),
      );
      await updateDelivery(updated);
    }
  }

  Future<List<Delivery>> getDeliveriesByProduct(String productId) async {
    await _ensureInitialized();
    return _deliveryBoxInstance.values
        .where((d) => d.productId == productId)
        .toList();
  }

  Future<List<Delivery>> getPendingDeliveries() async {
    await _ensureInitialized();
    return _deliveryBoxInstance.values.where((d) => d.isPending).toList();
  }

  Future<List<Delivery>> getRecentDeliveries({int limit = 10}) async {
    await _ensureInitialized();
    final deliveries = await getDeliveries();
    return deliveries.take(limit).toList();
  }

  Future<void> clearAll() async {
    await _ensureInitialized();
    await _productBoxInstance.clear();
    await _deliveryBoxInstance.clear();
  }

  Future<List<Product>> getProductsBySupplier(String supplierId) async {
    await _ensureInitialized();
    return _productBoxInstance.values
        .where((p) => p.supplierId == supplierId)
        .toList();
  }

  Future<bool> hasProductsForSupplier(String supplierId) async {
    await _ensureInitialized();
    return _productBoxInstance.values.any((p) => p.supplierId == supplierId);
  }
}