// lib/services/notification_service.dart
//
// CHANGELOG (v4 — SaaS) :
//   • `addNotificationForUser()` accepte désormais `teamId` — requis par les
//     règles Firestore pour valider qu'un émetteur ne notifie qu'un membre de
//     SA team (fail-closed).
//   • Conservation intégrale du comportement de toast live (invitations).
//   • `stopListening()` correctement appelé au logout (déjà géré par main.dart).
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/notification.dart';
import '../services/database_service.dart';
import '../widgets/app_toast.dart';

class NotificationService extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  // ── Cache mémoire (UI réactive).
  List<AppNotification> _notifications = [];

  // ── Écoute temps réel (toast des invitations d'équipe).
  StreamSubscription<List<AppNotification>>? _sub;
  String? _listeningUid;
  bool _firstEmission = true;
  final Set<String> _seenTeamInviteIds = {};

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  List<AppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  // ═══════════════════════════════════════════════════════════════
  //  INITIALISATION
  // ═══════════════════════════════════════════════════════════════
  Future<void> init() async {
    await refresh();
    startListening();
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final items = await _db.getNotifications();
      _notifications = items;
      notifyListeners();
      startListening();
    } catch (e) {
      debugPrint('⚠️ NotificationService.refresh: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  ÉCOUTE TEMPS RÉEL
  // ═══════════════════════════════════════════════════════════════
  void startListening() {
    final uid = _db.currentUserId;
    if (uid == null || uid.isEmpty) return;
    if (_listeningUid == uid && _sub != null) return;
    _sub?.cancel();
    _listeningUid = uid;
    try {
      _sub = _db.notificationsStream(uid).listen(
        (items) {
          _notifications = items;
          if (_firstEmission) {
            _firstEmission = false;
            _seenTeamInviteIds
              ..clear()
              ..addAll(items.map((n) => n.id));
          } else {
            for (final n in items) {
              if (!_seenTeamInviteIds.contains(n.id) &&
                  (n.type == 'team_invite' ||
                      n.type == 'team_invite_accepted')) {
                _seenTeamInviteIds.add(n.id);
                showAppToast('${n.title}\n${n.body}');
              }
            }
          }
          notifyListeners();
        },
        onError: (Object e) {
          debugPrint('⚠️ notificationsStream: $e');
        },
      );
    } catch (e) {
      debugPrint('⚠️ NotificationService.startListening: $e');
    }
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
    _listeningUid = null;
    _firstEmission = true;
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  CRUD PERSISTÉ
  // ═══════════════════════════════════════════════════════════════

  /// 🔔 Crée une notification pour l'UTILISATEUR CONNECTÉ.
  Future<void> addNotification(AppNotification notification) async {
    await _db.saveNotification(notification);
    _notifications.insert(0, notification);
    notifyListeners();
  }

  /// 🔔 Crée une notification pour un AUTRE utilisateur (mention @ dans un
  /// partage d'équipe, invitation, etc.).
  ///
  /// `teamId` est OBLIGATOIRE depuis la nouvelle règle Firestore : un
  /// émetteur ne peut notifier qu'un membre de SA team (fail-closed).
  Future<void> addNotificationForUser({
    required String userId,
    required AppNotification notification,
    String? createdBy,
    String? teamId,
  }) async {
    try {
      await _db.saveNotificationForUser(
        userId,
        notification,
        createdBy: createdBy,
        teamId: teamId,
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

  /// Réinitialise le service (appelé au logout).
  Future<void> clearAllForLogout() async {
    stopListening();
    _notifications.clear();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  //  NAVIGATION CONTEXTUELLE
  // ═══════════════════════════════════════════════════════════════

  Future<void> openNotification(
      BuildContext context, String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;

    final notification = _notifications[index];
    await markAsRead(notificationId);

    final Map<String, String> routes = {
      'invoice': notification.referenceId != null
          ? '/dashboard/invoices/${notification.referenceId}'
          : '/dashboard/invoices',
      'client': '/dashboard/clients',
      'product': '/dashboard/stock',
      'reminder': '/dashboard/reminders',
      'subscription': '/dashboard/subscription',
      'team_message': '/teams',
      'team_shared': '/teams/shared-with-me',
    };

    final route = routes[notification.referenceType] ?? '/dashboard';
    if (context.mounted) context.push(route);
  }

  // ═══════════════════════════════════════════════════════════════
  //  HELPERS FACTORY
  // ═══════════════════════════════════════════════════════════════

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

  /// 🔔 Notification de paiement : UNE seule notification par paiement.
  Future<void> notifyInvoicePaid(String invoiceNumber, {double? amount}) async {
    await addNotification(
      AppNotification.createInvoicePaid(invoiceNumber, amount: amount),
    );
  }
}