import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum NotificationType {
  invoice_created,
  invoice_paid,
  invoice_overdue,
  invoice_long_overdue,      // 🔥 NOUVEAU : impayé depuis longtemps
  invoice_cancelled,
  client_added,
  payment_received,
  subscription_expired,
  system_update,
  reminder,                  // 🔥 Rappel normal
  reminder_auto,             // 🔥 Rappel automatique (système)
  low_stock,                 // 🔥 NOUVEAU : stock faible
  stock_out, subscription_activated,                 // 🔥 NOUVEAU : rupture de stock
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime timestamp;
  final bool isRead;
  final String? referenceId;
  final String? referenceType;
  final Map<String, dynamic>? data;

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
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  NotificationType get notificationType {
    return NotificationType.values.firstWhere(
      (e) => e.toString() == type,
      orElse: () => NotificationType.system_update,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'referenceId': referenceId,
      'referenceType': referenceType,
      'data': data,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] ?? const Uuid().v4(),
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? NotificationType.system_update.toString(),
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      referenceId: map['referenceId'],
      referenceType: map['referenceType'],
      data: map['data'],
    );
  }

  AppNotification copyWith({
    String? title,
    String? body,
    bool? isRead,
  }) {
    return AppNotification(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      referenceId: referenceId,
      referenceType: referenceType,
      data: data,
    );
  }

  // ===== ICÔNES ET COULEURS =====
  IconData get icon {
    switch (notificationType) {
      case NotificationType.invoice_created:
        return Icons.receipt;
      case NotificationType.invoice_paid:
        return Icons.check_circle;
      case NotificationType.invoice_overdue:
      case NotificationType.invoice_long_overdue:
        return Icons.warning;
      case NotificationType.invoice_cancelled:
        return Icons.cancel;
      case NotificationType.client_added:
        return Icons.person_add;
      case NotificationType.payment_received:
        return Icons.payment;
      case NotificationType.subscription_expired:
        return Icons.timer_off;
      case NotificationType.system_update:
        return Icons.system_update;
      case NotificationType.reminder:
      case NotificationType.reminder_auto:
        return Icons.alarm;
      case NotificationType.low_stock:
        return Icons.warning_amber;
      case NotificationType.stock_out:
        return Icons.dangerous;
      default:
        return Icons.notifications;
    }
  }

  Color get color {
    switch (notificationType) {
      case NotificationType.invoice_created:
        return Colors.blue;
      case NotificationType.invoice_paid:
        return Colors.green;
      case NotificationType.invoice_overdue:
      case NotificationType.invoice_long_overdue:
        return Colors.red;
      case NotificationType.invoice_cancelled:
        return Colors.grey;
      case NotificationType.client_added:
        return Colors.purple;
      case NotificationType.payment_received:
        return Colors.orange;
      case NotificationType.subscription_expired:
        return Colors.red;
      case NotificationType.system_update:
        return Colors.indigo;
      case NotificationType.reminder:
      case NotificationType.reminder_auto:
        return Colors.amber;
      case NotificationType.low_stock:
        return Colors.orange;
      case NotificationType.stock_out:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get timeAgo {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 365) {
      return 'il y a ${(difference.inDays / 365).floor()} an${(difference.inDays / 365).floor() > 1 ? 's' : ''}';
    } else if (difference.inDays > 30) {
      return 'il y a ${(difference.inDays / 30).floor()} mois';
    } else if (difference.inDays > 7) {
      return 'il y a ${(difference.inDays / 7).floor()} semaines';
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

  // ===== MÉTHODES DE CRÉATION =====

  // --- Factures ---
  static AppNotification createInvoiceCreated(String invoiceNumber) {
    return AppNotification(
      title: 'Nouvelle facture créée',
      body: 'La facture $invoiceNumber a été créée avec succès.',
      type: NotificationType.invoice_created.toString(),
      referenceId: invoiceNumber,
      referenceType: 'invoice',
    );
  }

  static AppNotification createInvoicePaid(String invoiceNumber) {
    return AppNotification(
      title: 'Paiement reçu',
      body: 'La facture $invoiceNumber a été payée.',
      type: NotificationType.invoice_paid.toString(),
      referenceId: invoiceNumber,
      referenceType: 'invoice',
    );
  }

  static AppNotification createInvoiceOverdue(String invoiceNumber) {
    return AppNotification(
      title: 'Facture en retard',
      body: 'La facture $invoiceNumber est en retard de paiement.',
      type: NotificationType.invoice_overdue.toString(),
      referenceId: invoiceNumber,
      referenceType: 'invoice',
    );
  }

  // 🔥 NOUVEAU : impayé depuis longtemps (ex : > 30 jours)
  static AppNotification createInvoiceLongOverdue(String invoiceNumber, int days) {
    return AppNotification(
      title: '⚠️ Facture très en retard',
      body: 'La facture $invoiceNumber est impayée depuis $days jours. Une action est nécessaire.',
      type: NotificationType.invoice_long_overdue.toString(),
      referenceId: invoiceNumber,
      referenceType: 'invoice',
      data: {'days': days},
    );
  }

  // --- Clients ---
  static AppNotification createClientAdded(String clientName) {
    return AppNotification(
      title: 'Nouveau client',
      body: 'Le client $clientName a été ajouté.',
      type: NotificationType.client_added.toString(),
      referenceId: clientName,
      referenceType: 'client',
    );
  }

  // --- Paiements ---
  static AppNotification createPaymentReceived(double amount) {
    return AppNotification(
      title: 'Paiement reçu',
      body: 'Un paiement de ${amount.toStringAsFixed(0)} FCFA a été reçu.',
      type: NotificationType.payment_received.toString(),
      data: {'amount': amount},
    );
  }

  // --- Abonnement ---
  static AppNotification createSubscriptionExpired() {
    return AppNotification(
      title: 'Abonnement expiré',
      body: 'Votre abonnement est arrivé à expiration. Renouvelez-le maintenant.',
      type: NotificationType.subscription_expired.toString(),
    );
  }

  // --- Système ---
  static AppNotification createSystemUpdate(String version) {
    return AppNotification(
      title: 'Mise à jour disponible',
      body: 'La version $version de l\'application est disponible.',
      type: NotificationType.system_update.toString(),
      data: {'version': version},
    );
  }

  // --- Rappels ---
  static AppNotification createReminder(String message) {
    return AppNotification(
      title: '📌 Rappel',
      body: message,
      type: NotificationType.reminder.toString(),
    );
  }

  static AppNotification createAutoReminder(String message, String invoiceNumber) {
    return AppNotification(
      title: '🤖 Rappel automatique',
      body: message,
      type: NotificationType.reminder_auto.toString(),
      referenceId: invoiceNumber,
      referenceType: 'invoice',
    );
  }

  // ===== 🔥 NOUVEAU : GESTION DES STOCKS =====

  static AppNotification createLowStock(String productName, int quantity, int minStock) {
    return AppNotification(
      title: '⚠️ Stock faible',
      body: 'Le produit "$productName" n\'a plus que $quantity unités (seuil : $minStock).',
      type: NotificationType.low_stock.toString(),
      referenceId: productName,
      referenceType: 'product',
      data: {'quantity': quantity, 'minStock': minStock},
    );
  }

  static AppNotification createStockOut(String productName) {
    return AppNotification(
      title: '🚨 Rupture de stock',
      body: 'Le produit "$productName" est en rupture de stock !',
      type: NotificationType.stock_out.toString(),
      referenceId: productName,
      referenceType: 'product',
    );
  }
}