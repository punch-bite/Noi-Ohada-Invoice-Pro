// lib/models/reminder.dart

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
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

@HiveType(typeId: 5)
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
  final String type; // ReminderType en string
  
  @HiveField(7)
  final DateTime dueDate;
  
  @HiveField(8)
  final DateTime reminderDate;
  
  @HiveField(9)
  final String status; // ReminderStatus en string
  
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

  ReminderStatus get reminderStatus {
    return ReminderStatus.values.firstWhere(
      (e) => e.toString() == status,
      orElse: () => ReminderStatus.pending,
    );
  }

  ReminderType get reminderType {
    return ReminderType.values.firstWhere(
      (e) => e.toString() == type,
      orElse: () => ReminderType.first,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'invoiceNumber': invoiceNumber,
      'clientId': clientId,
      'clientName': clientName,
      'amount': amount,
      'type': type,
      'dueDate': dueDate.toIso8601String(),
      'reminderDate': reminderDate.toIso8601String(),
      'status': status,
      'sentAt': sentAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] ?? const Uuid().v4(),
      invoiceId: map['invoiceId'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      type: map['type'] ?? ReminderType.first.toString(),
      dueDate: DateTime.tryParse(map['dueDate'] ?? '') ?? DateTime.now(),
      reminderDate: DateTime.tryParse(map['reminderDate'] ?? '') ?? DateTime.now(),
      status: map['status'] ?? ReminderStatus.pending.toString(),
      sentAt: map['sentAt'] != null ? DateTime.tryParse(map['sentAt']) : null,
      errorMessage: map['errorMessage'],
    );
  }

  Reminder copyWith({
    String? status,
    DateTime? sentAt,
    String? errorMessage,
  }) {
    return Reminder(
      id: id,
      invoiceId: invoiceId,
      invoiceNumber: invoiceNumber,
      clientId: clientId,
      clientName: clientName,
      amount: amount,
      type: type,
      dueDate: dueDate,
      reminderDate: reminderDate,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

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
      type: ReminderType.first.toString(),
      dueDate: dueDate,
      reminderDate: dueDate.add(const Duration(days: 3)),
      status: ReminderStatus.pending.toString(),
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
      type: ReminderType.second.toString(),
      dueDate: dueDate,
      reminderDate: dueDate.add(const Duration(days: 10)),
      status: ReminderStatus.pending.toString(),
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
      type: ReminderType.final_warning.toString(),
      dueDate: dueDate,
      reminderDate: dueDate.add(const Duration(days: 20)),
      status: ReminderStatus.pending.toString(),
    );
  }
}