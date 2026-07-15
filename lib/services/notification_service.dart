// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/notification.dart';

class NotificationService extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;

  bool get hasNotifications => _notifications.isNotEmpty;
  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  List<AppNotification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead).toList();
  }
  List<AppNotification> get readNotifications {
    return _notifications.where((n) => n.isRead).toList();
  }

  Future<void> init() async {
    // TODO: Charger les notifications depuis Hive ou SharedPreferences
    _notifications = [];
    _updateUnreadCount();
    notifyListeners();
  }

  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
  }

  Future<void> addNotification(AppNotification notification) async {
    _notifications.insert(0, notification);
    _updateUnreadCount();
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final notification = _notifications[index];
      if (!notification.isRead) {
        final updated = notification.copyWith(isRead: true);
        _notifications[index] = updated;
        _updateUnreadCount();
        notifyListeners();
      }
    }
  }

  Future<void> markAllAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    _updateUnreadCount();
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    _updateUnreadCount();
    notifyListeners();
  }

  Future<void> deleteAllNotifications() async {
    _notifications.clear();
    _updateUnreadCount();
    notifyListeners();
  }

  // ===== NAVIGATION DEPUIS UNE NOTIFICATION =====

  /// Ouvre la page correspondant au type de notification
  /// et marque la notification comme lue
  Future<void> openNotification(BuildContext context, String notificationId) async {
    final notification = _notifications.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => throw Exception('Notification non trouvée'),
    );

    // Marquer comme lue
    await markAsRead(notificationId);

    // Redirection selon le type de référence
    switch (notification.referenceType) {
      case 'invoice':
        // Rediriger vers le détail de la facture
        if (notification.referenceId != null) {
          context.push('/dashboard/invoices/${notification.referenceId}');
        } else {
          context.push('/dashboard/invoices');
        }
        break;
      case 'client':
        context.push('/dashboard/clients');
        break;
      case 'product':
        context.push('/dashboard/stock');
        break;
      case 'reminder':
        context.push('/dashboard/reminders');
        break;
      case 'subscription':
        context.push('/dashboard/subscription');
        break;
      default:
        // Redirection par défaut vers le tableau de bord
        context.push('/dashboard');
        break;
    }
  }

  // ===== NOTIFICATIONS AUTOMATIQUES =====

  // --- Factures ---
  Future<void> notifyInvoiceCreated(String invoiceNumber) async {
    final notification = AppNotification.createInvoiceCreated(invoiceNumber);
    await addNotification(notification);
  }

  Future<void> notifyInvoicePaid(String invoiceNumber) async {
    final notification = AppNotification.createInvoicePaid(invoiceNumber);
    await addNotification(notification);
  }

  Future<void> notifyInvoiceOverdue(String invoiceNumber) async {
    final notification = AppNotification.createInvoiceOverdue(invoiceNumber);
    await addNotification(notification);
  }

  Future<void> notifyInvoiceLongOverdue(String invoiceNumber, int days) async {
    final notification = AppNotification.createInvoiceLongOverdue(invoiceNumber, days);
    await addNotification(notification);
  }

  // --- Clients ---
  Future<void> notifyClientAdded(String clientName) async {
    final notification = AppNotification.createClientAdded(clientName);
    await addNotification(notification);
  }

  // --- Paiements ---
  Future<void> notifyPaymentReceived(double amount) async {
    final notification = AppNotification.createPaymentReceived(amount);
    await addNotification(notification);
  }

  // --- Abonnement ---
  Future<void> notifySubscriptionExpired() async {
    final notification = AppNotification.createSubscriptionExpired();
    await addNotification(notification);
  }

  // --- Système ---
  Future<void> notifySystemUpdate(String version) async {
    final notification = AppNotification.createSystemUpdate(version);
    await addNotification(notification);
  }

  // --- Rappels ---
  Future<void> notifyReminder(String message) async {
    final notification = AppNotification.createReminder(message);
    await addNotification(notification);
  }

  Future<void> notifyAutoReminder(String message, String invoiceNumber) async {
    final notification = AppNotification.createAutoReminder(message, invoiceNumber);
    await addNotification(notification);
  }

  // --- Stocks ---
  Future<void> notifyLowStock(String productName, int quantity, int minStock) async {
    final notification = AppNotification.createLowStock(productName, quantity, minStock);
    await addNotification(notification);
  }

  Future<void> notifyStockOut(String productName) async {
    final notification = AppNotification.createStockOut(productName);
    await addNotification(notification);
  }
}