// lib/models/subscription.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'subscription.g.dart'; // Généré par Hive

@JsonSerializable()
@HiveType(typeId: 13) // Ajout de l'annotation Hive avec un typeId dédié
class Subscription {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String planId;

  @HiveField(3)
  final DateTime startDate;

  @HiveField(4)
  final DateTime endDate;

  @HiveField(5)
  final String status; // active, expired, canceled, pending

  @HiveField(6)
  final String paymentMethod; // stripe, paystack, orange_money, mtn_momo

  @HiveField(7)
  final String paymentId;

  @HiveField(8)
  final double amount;

  @HiveField(9)
  final String currency;

  @HiveField(10)
  final bool autoRenew;

  @HiveField(11)
  final DateTime? canceledAt;

  @HiveField(12)
  final bool isActive;

  @HiveField(13)
  final DateTime? createdAt;

  @HiveField(14)
  final Map<String, dynamic> metadata;

  @HiveField(15) // 🔥 NOUVEAU : Intervalle de l'abonnement
  final String interval; // 'month' ou 'year'

  Subscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.paymentMethod,
    required this.paymentId,
    required this.amount,
    required this.currency,
    this.autoRenew = true,
    this.canceledAt,
    this.metadata = const {},
    required this.isActive,
    this.createdAt,
    required this.interval, // 🔥 NOUVEAU : rendu obligatoire
  });

  // ===== SÉRIALISATION COMPATIBLE HIVE & FIRESTORE =====

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'planId': planId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status,
      'paymentMethod': paymentMethod,
      'paymentId': paymentId,
      'amount': amount,
      'currency': currency,
      'autoRenew': autoRenew,
      'canceledAt': canceledAt != null ? Timestamp.fromDate(canceledAt!) : null,
      'metadata': metadata,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'interval': interval, // 🔥 NOUVEAU
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Subscription(
      id: documentId ?? map['id'] ?? '',
      userId: map['userId'] ?? '',
      planId: map['planId'] ?? '',
      startDate: map['startDate'] != null
          ? _parseDateTime(map['startDate'])
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? _parseDateTime(map['endDate'])
          : DateTime.now(),
      status: map['status'] ?? 'pending',
      paymentMethod: map['paymentMethod'] ?? '',
      paymentId: map['paymentId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'XAF',
      autoRenew: map['autoRenew'] ?? true,
      canceledAt: map['canceledAt'] != null
          ? _parseDateTime(map['canceledAt'])
          : null,
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : const {},
      isActive: map['isActive'] ?? false,
      createdAt: map['createdAt'] != null
          ? _parseDateTime(map['createdAt'])
          : null,
      interval: map['interval'] ?? 'month', // 🔥 NOUVEAU : fallback à 'month'
    );
  }

  // ===== GETTERS APPLICATIFS =====

  bool get _isActive => status == 'active' && !isExpired;
  bool get isExpired => status == 'expired' || endDate.isBefore(DateTime.now());
  bool get isCanceled => status == 'canceled';

  int get daysRemaining {
    final difference = endDate.difference(DateTime.now()).inDays;
    return difference < 0 ? 0 : difference;
  }

  bool get willExpireSoon => daysRemaining <= 7 && daysRemaining > 0;
  bool get isTrial => status == 'pending' && amount == 0;

  // ===== CLONAGE (copyWith) =====

  Subscription copyWith({
    String? id,
    String? userId,
    String? planId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? paymentMethod,
    String? paymentId,
    double? amount,
    String? currency,
    bool? autoRenew,
    DateTime? canceledAt,
    bool? isActive,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
    String? interval, // 🔥 NOUVEAU
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentId: paymentId ?? this.paymentId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      autoRenew: autoRenew ?? this.autoRenew,
      canceledAt: canceledAt ?? this.canceledAt,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      interval: interval ?? this.interval, // 🔥 NOUVEAU
    );
  }

  /// Fonction d'aide pour parser les dates de manière ultra-robuste (Firestore, Hive et JSON)
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