// lib/models/reminder.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'reminder.g.dart';

enum ReminderStatus {
  pending,
  sent,
  failed,
}

enum ReminderType {
  first,
  second,
  final_warning,
}

@JsonSerializable()
@HiveType(typeId: 12) // Modifié à 6 pour éviter la collision avec Product (typeId: 5)
class Reminder {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String invoiceId;
  
  @HiveField(2)
  final String invoiceNumber;
  
  @HiveField(3)
  final String clientId;
  
  @HiveField(4)
  final String clientName;
  
  @HiveField(5)
  final double amount;
  
  @HiveField(6)
  final String type; // Stocké sous forme de String simple (ex: 'first')
  
  @HiveField(7)
  final DateTime dueDate;
  
  @HiveField(8)
  final DateTime reminderDate;
  
  @HiveField(9)
  final String status; // Stocké sous forme de String simple (ex: 'pending')
  
  @HiveField(10)
  final DateTime? sentAt;
  
  @HiveField(11)
  final String? errorMessage;

  Reminder({
    String? id,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.clientId,
    required this.clientName,
    required this.amount,
    required this.type,
    required this.dueDate,
    required this.reminderDate,
    required this.status,
    this.sentAt,
    this.errorMessage,
  }) : id = id ?? const Uuid().v4();

  /// Parse la chaîne `status` de manière sécurisée vers l'enum [ReminderStatus]
  ReminderStatus get reminderStatus {
    return ReminderStatus.values.firstWhere(
      (e) => e.name == status || e.toString() == status,
      orElse: () => ReminderStatus.pending,
    );
  }

  /// Parse la chaîne `type` de manière sécurisée vers l'enum [ReminderType]
  ReminderType get reminderType {
    return ReminderType.values.firstWhere(
      (e) => e.name == type || e.toString() == type,
      orElse: () => ReminderType.first,
    );
  }

  // ===== SÉRIALISATION COMPATIBLE HIVE & FIRESTORE =====

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'invoiceNumber': invoiceNumber,
      'clientId': clientId,
      'clientName': clientName,
      'amount': amount,
      'type': type,
      'dueDate': Timestamp.fromDate(dueDate),
      'reminderDate': Timestamp.fromDate(reminderDate),
      'status': status,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'errorMessage': errorMessage,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Reminder(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      invoiceId: map['invoiceId'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] ?? ReminderType.first.name,
      dueDate: map['dueDate'] != null ? _parseDateTime(map['dueDate']) : DateTime.now(),
      reminderDate: map['reminderDate'] != null ? _parseDateTime(map['reminderDate']) : DateTime.now(),
      status: map['status'] ?? ReminderStatus.pending.name,
      sentAt: map['sentAt'] != null ? _parseDateTime(map['sentAt']) : null,
      errorMessage: map['errorMessage'],
    );
  }

  // ===== CLONAGE ULTRA-COMPLET (copyWith) =====

  Reminder copyWith({
    String? id,
    String? invoiceId,
    String? invoiceNumber,
    String? clientId,
    String? clientName,
    double? amount,
    String? type,
    DateTime? dueDate,
    DateTime? reminderDate,
    String? status,
    DateTime? sentAt,
    String? errorMessage,
  }) {
    return Reminder(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      dueDate: dueDate ?? this.dueDate,
      reminderDate: reminderDate ?? this.reminderDate,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // ===== LABELS ET COULEURS DE L'INTERFACE =====

  String get typeLabel {
    switch (reminderType) {
      case ReminderType.first:
        return '1er rappel';
      case ReminderType.second:
        return '2ème rappel';
      case ReminderType.final_warning:
        return 'Dernier avertissement';
    }
  }

  String get statusLabel {
    switch (reminderStatus) {
      case ReminderStatus.pending:
        return 'En attente';
      case ReminderStatus.sent:
        return 'Envoyé';
      case ReminderStatus.failed:
        return 'Échoué';
    }
  }

  Color get statusColor {
    switch (reminderStatus) {
      case ReminderStatus.pending:
        return Colors.orange;
      case ReminderStatus.sent:
        return Colors.green;
      case ReminderStatus.failed:
        return Colors.red;
    }
  }

  // ===== CONSTRUCTEURS SÉCURISÉS (Automatisés) =====

  static Reminder createFirstReminder({
    required String invoiceId,
    required String invoiceNumber,
    required String clientId,
    required String clientName,
    required double amount,
    required DateTime dueDate,
  }) {
    return Reminder(
      invoiceId: invoiceId,
      invoiceNumber: invoiceNumber,
      clientId: clientId,
      clientName: clientName,
      amount: amount,
      type: ReminderType.first.name,
      dueDate: dueDate,
      reminderDate: dueDate.add(const Duration(days: 3)),
      status: ReminderStatus.pending.name,
    );
  }

  static Reminder createSecondReminder({
    required String invoiceId,
    required String invoiceNumber,
    required String clientId,
    required String clientName,
    required double amount,
    required DateTime dueDate,
  }) {
    return Reminder(
      invoiceId: invoiceId,
      invoiceNumber: invoiceNumber,
      clientId: clientId,
      clientName: clientName,
      amount: amount,
      type: ReminderType.second.name,
      dueDate: dueDate,
      reminderDate: dueDate.add(const Duration(days: 10)),
      status: ReminderStatus.pending.name,
    );
  }

  static Reminder createFinalWarning({
    required String invoiceId,
    required String invoiceNumber,
    required String clientId,
    required String clientName,
    required double amount,
    required DateTime dueDate,
  }) {
    return Reminder(
      invoiceId: invoiceId,
      invoiceNumber: invoiceNumber,
      clientId: clientId,
      clientName: clientName,
      amount: amount,
      type: ReminderType.final_warning.name,
      dueDate: dueDate,
      reminderDate: dueDate.add(const Duration(days: 20)),
      status: ReminderStatus.pending.name,
    );
  }

  /// Fonction d'aide pour parser les dates de manière ultra-robuste
  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }
}