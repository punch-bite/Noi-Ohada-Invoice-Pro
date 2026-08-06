// lib/services/stock_service.dart
//
// ✅ Stock — FIRESTORE (plus de Hive).
//  - Produits   : collection `products` via DatabaseService
//  - Livraisons : collection `deliveries` (scopée par UID)
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/delivery.dart';
import '../models/notification.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class StockService {
  static const String _deliveryCol = 'deliveries';

  final DatabaseService _db = DatabaseService();
  final NotificationService _notificationService = NotificationService();
  final Map<String, String> _notifiedStatuses = {};

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> init() async {
    // Firestore ne nécessite aucune initialisation locale.
    debugPrint('✅ StockService (Firestore)');
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
        AppNotification.createStockOut(product.name),
      );
    } else if (currentStatus == 'low_stock') {
      await _notificationService.addNotification(
        AppNotification.createLowStock(
            product.name, product.quantity, product.minStock),
      );
    }
  }

  Future<void> checkAllProductsStockStatus() async {
    for (final product in await getProducts()) {
      await _checkAndNotifyStockStatus(product);
    }
  }

  // ===== PRODUITS (Firestore) =====

  Future<List<Product>> getProducts() async {
    return _db.getProducts();
  }

  Future<List<Product>> getActiveProducts() async {
    final all = await getProducts();
    return all.where((p) => p.isActive).toList();
  }

  Future<Product?> getProduct(String id) async {
    return _db.getProduct(id);
  }

  Future<void> addProduct(Product product) async {
    await _db.saveProduct(product);
    await _checkAndNotifyStockStatus(product);
  }

  Future<void> updateProduct(Product product) async {
    await _db.saveProduct(product);
    await _checkAndNotifyStockStatus(product);
  }

  Future<void> deleteProduct(String id) async {
    await _db.deleteProduct(id);
    _notifiedStatuses.remove(id);
  }

  Future<void> updateStock(String productId, int quantity) async {
    final product = await getProduct(productId);
    if (product == null) {
      throw Exception('Produit avec ID "$productId" introuvable.');
    }
    await updateProduct(
        product.copyWith(quantity: quantity, updatedAt: DateTime.now()));
  }

  // ===== FILTRES =====

  Future<List<Product>> getLowStockProducts() async {
    final all = await getProducts();
    return all.where((p) => p.isLowStock && p.isActive).toList();
  }

  Future<List<Product>> getOutOfStockProducts() async {
    final all = await getProducts();
    return all.where((p) => p.isOutOfStock && p.isActive).toList();
  }

  Future<double> getTotalStockValue() async {
    final all = await getProducts();
    return all.fold<double>(0.0, (total, p) => total + p.stockValue);
  }

  Future<int> getTotalItems() async {
    final all = await getProducts();
    return all.fold<int>(0, (total, p) => total + p.quantity);
  }

  // ===== LIVRAISONS (Firestore) =====

  Future<List<Delivery>> getDeliveries() async {
    final uid = _uid;
    if (uid == null) return [];
    final snapshot = await FirebaseFirestore.instance
        .collection(_deliveryCol)
        .where('userId', isEqualTo: uid)
        .get();
    final list = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Delivery.fromMap(data);
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<Delivery?> getDelivery(String id) async {
    final doc = await FirebaseFirestore.instance
        .collection(_deliveryCol)
        .doc(id)
        .get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return Delivery.fromMap(data);
  }

  Future<void> _saveDelivery(Delivery delivery) async {
    final uid = _uid;
    if (uid == null) throw Exception('Non authentifié');
    await FirebaseFirestore.instance.collection(_deliveryCol).doc(delivery.id).set({
      ...delivery.toMap(),
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addDelivery(Delivery delivery) async {
    final product = await getProduct(delivery.productId);
    if (product == null) {
      throw Exception('Produit associé (ID: ${delivery.productId}) introuvable.');
    }

    int newQuantity = product.quantity;
    if (delivery.isIncoming) {
      newQuantity += delivery.quantity;
    } else if (delivery.isOutgoing) {
      if (product.quantity < delivery.quantity) {
        throw Exception(
            'Stock insuffisant (${product.quantity}) pour la sortie de ${delivery.quantity}');
      }
      newQuantity -= delivery.quantity;
    } else if (delivery.isLoss) {
      if (product.quantity < delivery.quantity) {
        throw Exception(
            'Stock insuffisant (${product.quantity}) pour la perte de ${delivery.quantity}');
      }
      newQuantity -= delivery.quantity;
    }

    // Enregistrer la livraison puis mettre à jour le stock
    await _saveDelivery(delivery);
    await updateStock(delivery.productId, newQuantity);
  }

  Future<void> updateDelivery(Delivery delivery) async {
    await _saveDelivery(delivery);
  }

  Future<void> completeDelivery(String id) async {
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
      ),
    );
  }

  Future<void> cancelDelivery(String id) async {
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
        newQuantity -= delivery.quantity;
      } else if (delivery.isOutgoing || delivery.isLoss) {
        newQuantity += delivery.quantity;
      }
      await updateStock(delivery.productId, newQuantity);
    }

    await updateDelivery(
      delivery.copyWith(status: DeliveryStatus.cancelled.toString()),
    );
  }

  Future<List<Delivery>> getDeliveriesByProduct(String productId) async {
    final all = await getDeliveries();
    return all.where((d) => d.productId == productId).toList();
  }

  Future<List<Delivery>> getPendingDeliveries() async {
    final all = await getDeliveries();
    return all.where((d) => d.isPending).toList();
  }

  Future<List<Delivery>> getRecentDeliveries({int limit = 10}) async {
    final deliveries = await getDeliveries();
    return deliveries.take(limit).toList();
  }

  // ===== LIENS FOURNISSEURS =====

  Future<List<Product>> getProductsBySupplier(String supplierId) async {
    final all = await getProducts();
    return all.where((p) => p.supplierId == supplierId).toList();
  }

  Future<bool> hasProductsForSupplier(String supplierId) async {
    final all = await getProducts();
    return all.any((p) => p.supplierId == supplierId);
  }
}
