// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:noi_ohada_invoice_pro/models/plan.dart';
import '../models/notification.dart';

class NotificationService extends ChangeNotifier {
  static const String _boxName = 'notifications';
  Box<AppNotification>? _box;
  bool _isInitializing = false;

  // Utilisation d'une liste locale pour optimiser l'accès UI
  List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  List<AppNotification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead).toList();
  }

  /// Garantit que la box Hive est ouverte avant toute opération.
  /// Idempotent : si la box est déjà ouverte ne refait rien.
  Future<Box<AppNotification>> _ensureBox() async {
    if (_box != null) return _box!;
    if (_isInitializing) {
      // Si une initialisation est en cours, on attend qu'elle se termine
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
      return _box!;
    }
    _isInitializing = true;
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox<AppNotification>(_boxName);
      } else {
        _box = Hive.box<AppNotification>(_boxName);
      }
      _notifications = _box!.values.toList().reversed.toList();
      return _box!;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> init() async {
    await _ensureBox();
    notifyListeners();
  }

  // --- Opérations CRUD persistées ---

  Future<void> addNotification(AppNotification notification) async {
    await (await _ensureBox()).put(notification.id, notification);
    _notifications.insert(0, notification);
    notifyListeners();
  }

      Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      final updated = _notifications[index].copyWith(isRead: true);
      _notifications[index] = updated;
      await (await _ensureBox()).put(id, updated);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    final box = await _ensureBox();
    for (var n in _notifications.where((n) => !n.isRead)) {
      final updated = n.copyWith(isRead: true);
      await box.put(updated.id, updated);
    }
    _notifications =
        _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    await (await _ensureBox()).delete(id);
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  // 4. Méthode pour tout supprimer (mémoire + persistance Hive)
  Future<void> deleteAllNotifications() async {
    await (await _ensureBox()).clear();
    _notifications.clear();
    notifyListeners();
  }

      /// Réinitialise le service de notification (appelé au logout).
  /// Purge la mémoire et la box Hive.
  Future<void> clearAllForLogout() async {
    if (Hive.isBoxOpen(_boxName)) {
      await Hive.box<AppNotification>(_boxName).clear();
    }
    _box = null;
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

  // Ajoutez cette méthode pour récupérer tous les plans disponibles
  Future<List<Plan>> getAllPlans(dynamic db) async {
    final querySnapshot = await db.collection('plans').get();
    return querySnapshot.docs.map((doc) {
      return Plan.fromMap({...doc.data(), 'id': doc.id});
    }).toList();
  }

  // --- Helpers de notification (Factory Pattern) ---

  Future<void> notify(AppNotificationAdapter type,
      {String? title, String? body, String? refId, String? refType}) async {
    // Ici, vous pouvez appeler vos méthodes spécifiques
    // ou centraliser la création via AppNotification.create...
    await addNotification(AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? '',
      body: body ?? '',
      referenceId: refId,
      referenceType: refType,
      timestamp: DateTime.now(),
      isRead: false,
      type: '',
    ));
  }

  /// Méthode 1 : Notification lors du paiement réussi d'une facture
  Future<void> notifyInvoicePaid(String invoiceNumber) async {
    final notification = AppNotification(
      title: 'Facture payée',
      body: 'La facture n°$invoiceNumber a été réglée avec succès.',
      type: 'payment_success',
      referenceId: invoiceNumber,
      referenceType: 'invoice',
    );
    await addNotification(notification);
  }

  /// Méthode 2 : Notification lors de la réception d'un montant
  Future<void> notifyPaymentReceived(double amount) async {
    final notification = AppNotification(
      title: 'Paiement reçu',
      body: 'Un paiement de ${amount.toStringAsFixed(0)} FCFA a été reçu.',
      type: 'payment_received',
      referenceId: amount.toString(),
      referenceType: 'wallet',
    );
    await addNotification(notification);
  }
}
