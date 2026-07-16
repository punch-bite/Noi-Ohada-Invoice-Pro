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

  // Accesseurs sécurisés : on vérifie que les boxes sont ouvertes avant de les retourner
  Box<Product> get _productBox {
    if (!Hive.isBoxOpen(_productBoxName)) {
      throw StateError('StockService not initialized. Call init() first.');
    }
    return Hive.box<Product>(_productBoxName);
  }

  Box<Delivery> get _deliveryBox {
    if (!Hive.isBoxOpen(_deliveryBoxName)) {
      throw StateError('StockService not initialized. Call init() first.');
    }
    return Hive.box<Delivery>(_deliveryBoxName);
  }

  // ===== INITIALISATION =====

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      if (!Hive.isBoxOpen(_productBoxName)) {
        await Hive.openBox<Product>(_productBoxName);
        debugPrint('✅ Box "$_productBoxName" ouverte.');
      }
      if (!Hive.isBoxOpen(_deliveryBoxName)) {
        await Hive.openBox<Delivery>(_deliveryBoxName);
        debugPrint('✅ Box "$_deliveryBoxName" ouverte.');
      }
      await _notificationService.init();
      _isInitialized = true;
      debugPrint('✅ StockService initialisé avec succès.');
    } catch (e) {
      debugPrint('❌ Erreur critique lors de l\'initialisation de StockService: $e');
      rethrow;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
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
      await _notificationService.addNotification(
        AppNotification.createStockOut(product.name)
      );
      debugPrint('🔔 Notification rupture de stock pour ${product.name}');
    } else if (currentStatus == 'low_stock') {
      await _notificationService.addNotification(
        AppNotification.createLowStock(product.name, product.quantity, product.minStock)
      );
      debugPrint('🔔 Notification stock faible pour ${product.name}');
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
    if (!_productBox.containsKey(product.id)) {
      throw Exception('Produit avec ID "${product.id}" introuvable.');
    }
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
    if (product == null) {
      throw Exception('Produit avec ID "$productId" introuvable.');
    }
    await updateProduct(product.copyWith(quantity: quantity, updatedAt: DateTime.now()));
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
    final list = _deliveryBox.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<Delivery?> getDelivery(String id) async {
    await _ensureInitialized();
    return _deliveryBox.get(id);
  }

  Future<void> addDelivery(Delivery delivery) async {
    await _ensureInitialized();
    final product = await getProduct(delivery.productId);
    if (product == null) {
      throw Exception('Produit associé (ID: ${delivery.productId}) introuvable.');
    }

    int newQuantity = product.quantity;
    if (delivery.isIncoming) {
      newQuantity += delivery.quantity;
    } else if (delivery.isOutgoing) {
      if (product.quantity < delivery.quantity) {
        throw Exception('Stock insuffisant (${product.quantity}) pour la sortie de ${delivery.quantity}');
      }
      newQuantity -= delivery.quantity;
    }

    // Enregistrer la livraison
    await _deliveryBox.put(delivery.id, delivery);
    // Mettre à jour le stock
    await updateStock(delivery.productId, newQuantity);
  }

  Future<void> updateDelivery(Delivery delivery) async {
    await _ensureInitialized();
    if (!_deliveryBox.containsKey(delivery.id)) {
      throw Exception('Livraison avec ID "${delivery.id}" introuvable.');
    }
    await _deliveryBox.put(delivery.id, delivery);
  }

  Future<void> completeDelivery(String id) async {
    await _ensureInitialized();
    final delivery = await getDelivery(id);
    if (delivery == null) {
      throw Exception('Livraison avec ID "$id" introuvable.');
    }
    if (delivery.isCompleted) {
      debugPrint('ℹ️ La livraison $id est déjà complétée.');
      return;
    }
    await updateDelivery(
      delivery.copyWith(
        status: DeliveryStatus.completed.toString(),
        completedAt: DateTime.now(),
      )
    );
  }

  Future<void> cancelDelivery(String id) async {
    await _ensureInitialized();
    final delivery = await getDelivery(id);
    if (delivery == null) {
      throw Exception('Livraison avec ID "$id" introuvable.');
    }
    if (delivery.isCompleted) {
      throw Exception('Impossible d\'annuler une livraison déjà complétée.');
    }
    if (delivery.status == DeliveryStatus.cancelled.toString()) {
      debugPrint('ℹ️ La livraison $id est déjà annulée.');
      return;
    }

    // Récupérer le produit pour ajuster le stock
    final product = await getProduct(delivery.productId);
    if (product != null) {
      int newQuantity = product.quantity;
      if (delivery.isIncoming) {
        // Annuler une entrée => on retire les quantités ajoutées
        newQuantity -= delivery.quantity;
      } else if (delivery.isOutgoing) {
        // Annuler une sortie => on remet les quantités sorties
        newQuantity += delivery.quantity;
      }
      await updateStock(delivery.productId, newQuantity);
    }

    await updateDelivery(
      delivery.copyWith(status: DeliveryStatus.cancelled.toString())
    );
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
    debugPrint('🧹 StockService: toutes les données effacées.');
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