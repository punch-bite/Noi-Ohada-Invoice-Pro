// lib/services/notification_service.dart
//
// ✅ Notifications — FIRESTORE (plus de Hive).
// Les notifications sont stockées dans la collection `notifications`,
// scopée par l'UID, et gardées en mémoire pour une UI réactive.
//
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/notification.dart';
import '../services/database_service.dart';

class NotificationService extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  // Utilisation d'une liste locale pour optimiser l'accès UI (cache mémoire)
  List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  List<AppNotification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead).toList();
  }

  Future<void> init() async {
    await refresh();
    notifyListeners();
  }

  /// Recharge les notifications depuis Firestore (mémoire + notify).
  Future<void> refresh() async {
    try {
      final items = await _db.getNotifications();
      _notifications = items;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ NotificationService.refresh: $e');
    }
  }

  // --- Opérations CRUD persistées (Firestore) ---

  Future<void> addNotification(AppNotification notification) async {
    await _db.saveNotification(notification);
    _notifications.insert(0, notification);
    notifyListeners();
  }

  /// Crée une notification pour un AUTRE utilisateur (mention @ dans un
  /// partage d'équipe). Ne l'ajoute PAS à la liste locale de l'émetteur.
  Future<void> addNotificationForUser({
    required String userId,
    required AppNotification notification,
    String? createdBy,
  }) async {
    try {
      await _db.saveNotificationForUser(
        userId,
        notification,
        createdBy: createdBy,
      );
    } catch (e) {
      debugPrint('⚠️ addNotificationForUser: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      final updated = _notifications[index].copyWith(isRead: true);
      _notifications[index] = updated;
      await _db.saveNotification(updated);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    final toUpdate = _notifications.where((n) => !n.isRead).toList();
    for (final n in toUpdate) {
      final updated = n.copyWith(isRead: true);
      await _db.saveNotification(updated);
    }
    _notifications =
        _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    await _db.deleteNotification(id);
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  Future<void> deleteAllNotifications() async {
    await _db.clearNotifications();
    _notifications.clear();
    notifyListeners();
  }

  /// Réinitialise le service (appelé au logout). Purge la mémoire.
  Future<void> clearAllForLogout() async {
    _notifications.clear();
    notifyListeners();
  }

  // --- Navigation contextuelle ---

  Future<void> openNotification(
      BuildContext context, String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;

    final notification = _notifications[index];
    await markAsRead(notificationId);

    // Utilisation d'un mapping pour simplifier le switch
    final Map<String, String> routes = {
      'invoice': notification.referenceId != null
          ? '/dashboard/invoices/${notification.referenceId}'
          : '/dashboard/invoices',
      'client': '/dashboard/clients',
      'product': '/dashboard/stock',
      'reminder': '/dashboard/reminders',
      'subscription': '/dashboard/subscription',
    };

    final route = routes[notification.referenceType] ?? '/dashboard';
    if (context.mounted) context.push(route);
  }

  // --- Helpers de notification (Factory Pattern) ---

  /// Notification générique (type en String, plus de dépendance Hive).
  Future<void> notify({
    required String type,
    String? title,
    String? body,
    String? refId,
    String? refType,
  }) async {
    await addNotification(AppNotification(
      title: title ?? '',
      body: body ?? '',
      referenceId: refId,
      referenceType: refType,
      timestamp: DateTime.now(),
      isRead: false,
      type: type,
    ));
  }

  /// Notification lors du paiement réussi d'une facture
  Future<void> notifyInvoicePaid(String invoiceNumber) async {
    await notify(
      type: 'payment_success',
      title: 'Facture payée',
      body: 'La facture n°$invoiceNumber a été réglée avec succès.',
      refId: invoiceNumber,
      refType: 'invoice',
    );
  }

  /// Notification lors de la réception d'un montant
  Future<void> notifyPaymentReceived(double amount) async {
    await notify(
      type: 'payment_received',
      title: 'Paiement reçu',
      body: 'Un paiement de ${amount.toStringAsFixed(0)} FCFA a été reçu.',
      refId: amount.toString(),
      refType: 'wallet',
    );
  }
}
