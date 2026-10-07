// lib/models/notification.dart
//
// CHANGELOG :
//   • Ajout `userId` (destinataire), `createdBy` (émetteur), `teamId`
//     (équipe source — requis par les règles Firestore pour les notifs
//     d'équipe), `recipients` (liste — lu par les règles en lecture).
//   • `toMap()` / `fromMap()` / `copyWith()` étendus.
//
// ignore_for_file: unreachable_switch_default

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'notification.g.dart';

enum NotificationType {
  invoice_created, invoice_paid, invoice_overdue, invoice_long_overdue,
  invoice_cancelled, client_added, payment_received, subscription_expired,
  subscription_activated, system_update, reminder, reminder_auto,
  low_stock, stock_out, team_shared, team_invite, team_invite_accepted, team_message,
}

@HiveType(typeId: 9)
class AppNotification {
  @HiveField(0)  final String id;
  @HiveField(1)  final String title;
  @HiveField(2)  final String body;
  @HiveField(3)  final String type;
  @HiveField(4)  final DateTime timestamp;
  @HiveField(5)  final bool isRead;
  @HiveField(6)  final String? referenceId;
  @HiveField(7)  final String? referenceType;
  @HiveField(8)  final Map<String, dynamic>? data;

  // 🔑 NOUVEAU — ciblage + traçabilité équipe
  @HiveField(9)  final String? userId;      // destinataire
  @HiveField(10) final String? createdBy;   // émetteur
  @HiveField(11) final String? teamId;      // équipe source (règles)
  @HiveField(12) final List<String> recipients;

  AppNotification({
    String? id,
    required this.title,
    required this.body,
    required this.type,
    DateTime? timestamp,
    this.isRead = false,
    this.referenceId,
    this.referenceType,
    this.data,
    this.userId,
    this.createdBy,
    this.teamId,
    this.recipients = const [],
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  NotificationType get notificationType {
    return NotificationType.values.firstWhere(
      (e) => e.name == type || e.toString() == type,
      orElse: () => NotificationType.system_update,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'referenceId': referenceId,
      'referenceType': referenceType,
      'data': data,
      'userId': userId,
      'createdBy': createdBy,
      'teamId': teamId,
      'recipients': recipients.isEmpty && userId != null
          ? [userId]
          : recipients,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map,
      {String? documentId}) {
    return AppNotification(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? NotificationType.system_update.name,
      timestamp: _parseDateTime(map['timestamp']),
      isRead: map['isRead'] ?? false,
      referenceId: map['referenceId'],
      referenceType: map['referenceType'],
      data: map['data'] != null
          ? Map<String, dynamic>.from(map['data'])
          : null,
      userId: map['userId'],
      createdBy: map['createdBy'],
      teamId: map['teamId'],
      recipients: List<String>.from(map['recipients'] ?? const []),
    );
  }

  AppNotification copyWith({
    String? title,
    String? body,
    bool? isRead,
    String? referenceId,
    String? referenceType,
    Map<String, dynamic>? data,
    String? userId,
    String? createdBy,
    String? teamId,
    List<String>? recipients,
  }) {
    return AppNotification(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      data: data ?? this.data,
      userId: userId ?? this.userId,
      createdBy: createdBy ?? this.createdBy,
      teamId: teamId ?? this.teamId,
      recipients: recipients ?? this.recipients,
    );
  }

  // ─── ICÔNES / COULEURS / FACTORY (inchangés) ───

  IconData get icon {
    switch (notificationType) {
      case NotificationType.invoice_created: return Icons.receipt;
      case NotificationType.invoice_paid: return Icons.check_circle;
      case NotificationType.invoice_overdue:
      case NotificationType.invoice_long_overdue: return Icons.warning;
      case NotificationType.invoice_cancelled: return Icons.cancel;
      case NotificationType.client_added: return Icons.person_add;
      case NotificationType.payment_received: return Icons.payment;
      case NotificationType.subscription_expired: return Icons.timer_off;
      case NotificationType.subscription_activated: return Icons.card_membership;
      case NotificationType.system_update: return Icons.system_update;
      case NotificationType.reminder:
      case NotificationType.reminder_auto: return Icons.alarm;
      case NotificationType.low_stock: return Icons.warning_amber;
      case NotificationType.stock_out: return Icons.dangerous;
      case NotificationType.team_shared: return Icons.share;
      case NotificationType.team_invite: return Icons.mail_outline;
      case NotificationType.team_invite_accepted: return Icons.group_add;
      default: return Icons.notifications;
    }
  }

  Color get color {
    switch (notificationType) {
      case NotificationType.invoice_created: return Colors.blue;
      case NotificationType.invoice_paid: return Colors.green;
      case NotificationType.invoice_overdue:
      case NotificationType.invoice_long_overdue: return Colors.red;
      case NotificationType.invoice_cancelled: return Colors.grey;
      case NotificationType.client_added: return Colors.purple;
      case NotificationType.payment_received: return Colors.orange;
      case NotificationType.subscription_expired: return Colors.red;
      case NotificationType.subscription_activated: return Colors.teal;
      case NotificationType.system_update: return Colors.indigo;
      case NotificationType.reminder:
      case NotificationType.reminder_auto: return Colors.amber;
      case NotificationType.low_stock: return Colors.orange;
      case NotificationType.stock_out: return Colors.red;
      case NotificationType.team_shared: return Colors.teal;
      case NotificationType.team_invite: return Colors.indigo;
      case NotificationType.team_invite_accepted: return Colors.teal;
      default: return Colors.grey;
    }
  }

  String get timeAgo {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 365) {
      return 'il y a ${(difference.inDays / 365).floor()} an${(difference.inDays / 365).floor() > 1 ? 's' : ''}';
    } else if (difference.inDays > 30) {
      return 'il y a ${(difference.inDays / 30).floor()} mois';
    } else if (difference.inDays > 7) {
      return 'il y a ${(difference.inDays / 7).floor()} semaine${(difference.inDays / 7).floor() > 1 ? 's' : ''}';
    } else if (difference.inDays > 0) {
      return 'il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'à l\'instant';
    }
  }

  // ─── FACTORY HELPERS ───
  static AppNotification createInvoiceCreated(String invoiceNumber) =>
      AppNotification(
        title: 'Nouvelle facture créée',
        body: 'La facture $invoiceNumber a été créée avec succès.',
        type: NotificationType.invoice_created.name,
        referenceId: invoiceNumber,
        referenceType: 'invoice',
      );

  static AppNotification createInvoicePaid(String invoiceNumber,
      {double? amount}) {
    final amountStr = amount == null
        ? null
        : (amount % 1 == 0
            ? amount.toStringAsFixed(0)
            : amount.toStringAsFixed(2));
    return AppNotification(
      title: 'Facture payée',
      body: amountStr == null
          ? 'La facture $invoiceNumber a été réglée avec succès.'
          : 'La facture $invoiceNumber a été réglée avec succès ($amountStr FCFA).',
      type: NotificationType.invoice_paid.name,
      referenceId: invoiceNumber,
      referenceType: 'invoice',
      data: amount == null ? null : {'amount': amount, 'currency': 'FCFA'},
    );
  }

  static AppNotification createInvoiceOverdue(String invoiceNumber) =>
      AppNotification(
        title: 'Facture en retard',
        body: 'La facture $invoiceNumber est en retard de paiement.',
        type: NotificationType.invoice_overdue.name,
        referenceId: invoiceNumber,
        referenceType: 'invoice',
      );

  static AppNotification createInvoiceLongOverdue(
          String invoiceNumber, int days) =>
      AppNotification(
        title: '⚠️ Facture très en retard',
        body:
            'La facture $invoiceNumber est impayée depuis $days jours. Une action est nécessaire.',
        type: NotificationType.invoice_long_overdue.name,
        referenceId: invoiceNumber,
        referenceType: 'invoice',
        data: {'days': days},
      );

  static AppNotification createInvoiceCancelled(String invoiceNumber) =>
      AppNotification(
        title: 'Facture annulée',
        body: 'La facture $invoiceNumber a été annulée.',
        type: NotificationType.invoice_cancelled.name,
        referenceId: invoiceNumber,
        referenceType: 'invoice',
      );

  static AppNotification createClientAdded(String clientName) =>
      AppNotification(
        title: 'Nouveau client',
        body: 'Le client $clientName a été ajouté avec succès.',
        type: NotificationType.client_added.name,
        referenceId: clientName,
        referenceType: 'client',
      );

  static AppNotification createPaymentReceived(double amount,
      [String currency = 'FCFA']) {
    final amountStr = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return AppNotification(
      title: 'Paiement reçu',
      body: 'Un paiement de $amountStr $currency a été reçu.',
      type: NotificationType.payment_received.name,
      data: {'amount': amount, 'currency': currency},
    );
  }

  static AppNotification createSubscriptionExpired() => AppNotification(
        title: 'Abonnement expiré',
        body:
            'Votre abonnement est arrivé à expiration. Renouvelez-le maintenant.',
        type: NotificationType.subscription_expired.name,
      );

  static AppNotification createSubscriptionActivated(String planName) =>
      AppNotification(
        title: 'Abonnement activé',
        body: 'Votre abonnement au plan $planName est désormais actif !',
        type: NotificationType.subscription_activated.name,
      );

  static AppNotification createSystemUpdate(String version) =>
      AppNotification(
        title: 'Mise à jour disponible',
        body: 'La version $version de l\'application est disponible.',
        type: NotificationType.system_update.name,
        data: {'version': version},
      );

  static AppNotification createReminder(String message) => AppNotification(
        title: '📌 Rappel',
        body: message,
        type: NotificationType.reminder.name,
      );

  static AppNotification createAutoReminder(
          String message, String invoiceNumber) =>
      AppNotification(
        title: '🤖 Rappel automatique',
        body: message,
        type: NotificationType.reminder_auto.name,
        referenceId: invoiceNumber,
        referenceType: 'invoice',
      );

  static AppNotification createLowStock(
          String productName, int quantity, int minStock) =>
      AppNotification(
        title: '⚠️ Stock faible',
        body:
            'Le produit "$productName" n\'a plus que $quantity unités (seuil : $minStock).',
        type: NotificationType.low_stock.name,
        referenceId: productName,
        referenceType: 'product',
        data: {'quantity': quantity, 'minStock': minStock},
      );

  static AppNotification createStockOut(String productName) =>
      AppNotification(
        title: '🚨 Rupture de stock',
        body: 'Le produit "$productName" est en rupture de stock !',
        type: NotificationType.stock_out.name,
        referenceId: productName,
        referenceType: 'product',
      );

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return DateTime.now();
  }
}