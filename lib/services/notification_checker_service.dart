// lib/services/notification_checker_service.dart
import 'dart:async';
import '../services/stock_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/notification.dart';

class NotificationCheckerService {
  static final NotificationCheckerService _instance = NotificationCheckerService._internal();
  factory NotificationCheckerService() => _instance;
  NotificationCheckerService._internal();

  final StockService _stockService = StockService();
  final DatabaseService _db = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  Timer? _timer;
  bool _isRunning = false;
  final int checkIntervalSeconds = 60; // Vérification toutes les 60 secondes

  // Liste des produits déjà alertés pour éviter les doublons
  final Set<String> _alertedProducts = {};
  final Set<String> _alertedInvoices = {};

  /// Démarrer la surveillance automatique
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    // Initialiser les services
    await _stockService.init();
    await DatabaseService.init();
    await _notificationService.init();

    // Effectuer une première vérification immédiate
    await _checkAll();

    // Puis lancer le timer
    _timer = Timer.periodic(
      Duration(seconds: checkIntervalSeconds),
      (_) => _checkAll(),
    );
    print('✅ NotificationCheckerService démarré (intervalle: ${checkIntervalSeconds}s)');
  }

  /// Arrêter la surveillance
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    print('⏹️ NotificationCheckerService arrêté');
  }

  /// Vérification complète
  Future<void> _checkAll() async {
    try {
      await _checkStock();
      await _checkOverdueInvoices();
    } catch (e) {
      print('❌ Erreur dans _checkAll: $e');
    }
  }

  // ===== 1. VÉRIFICATION DES STOCKS =====
  Future<void> _checkStock() async {
    final products = await _stockService.getProducts();
    final now = DateTime.now();

    for (final product in products) {
      // Rupture de stock (quantité == 0)
      if (product.quantity == 0) {
        if (!_alertedProducts.contains('stock_out_${product.id}')) {
          final notification = AppNotification.createStockOut(product.name);
          await _notificationService.addNotification(notification);
          _alertedProducts.add('stock_out_${product.id}');
        }
      }
      // Stock faible (quantité <= seuil)
      else if (product.isLowStock) {
        if (!_alertedProducts.contains('low_stock_${product.id}')) {
          final notification = AppNotification.createLowStock(
            product.name,
            product.quantity,
            product.minStock,
          );
          await _notificationService.addNotification(notification);
          _alertedProducts.add('low_stock_${product.id}');
        }
      }
      // Si le stock est revenu à un niveau normal, on lève l'alerte
      else {
        _alertedProducts.remove('stock_out_${product.id}');
        _alertedProducts.remove('low_stock_${product.id}');
      }
    }
  }

  // ===== 2. VÉRIFICATION DES FACTURES EN RETARD =====
  Future<void> _checkOverdueInvoices() async {
    final invoices = await _db.getInvoices();
    final now = DateTime.now();

    for (final invoice in invoices) {
      // Ignorer les factures déjà payées ou annulées
      if (invoice.status == 'paid' || invoice.status == 'cancelled') {
        _alertedInvoices.remove('overdue_${invoice.id}');
        _alertedInvoices.remove('long_overdue_${invoice.id}');
        continue;
      }

      // Facture en retard (échéance dépassée)
      if (invoice.dueDate.isBefore(now)) {
        final daysLate = now.difference(invoice.dueDate).inDays;

        // 🔥 Facture très en retard (> 30 jours)
        if (daysLate >= 30) {
          if (!_alertedInvoices.contains('long_overdue_${invoice.id}')) {
            final notification = AppNotification.createInvoiceLongOverdue(
              invoice.invoiceNumber,
              daysLate,
            );
            await _notificationService.addNotification(notification);
            _alertedInvoices.add('long_overdue_${invoice.id}');
          }
        }
        // Facture en retard standard (1-29 jours)
        else if (daysLate >= 1) {
          if (!_alertedInvoices.contains('overdue_${invoice.id}')) {
            final notification = AppNotification.createInvoiceOverdue(invoice.invoiceNumber);
            await _notificationService.addNotification(notification);
            _alertedInvoices.add('overdue_${invoice.id}');
          }
        }
      }
    }
  }

  // ===== RÉINITIALISATION DES ALERTES (utile après un refresh) =====
  void resetAlerts() {
    _alertedProducts.clear();
    _alertedInvoices.clear();
    print('🔄 Alertes réinitialisées');
  }
}