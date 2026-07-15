// lib/models/subscription.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Subscription {
  final String id;
  final String userId;
  final String planId;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // active, expired, canceled, pending
  final String paymentMethod; // stripe, paystack, orange_money
  final String paymentId;
  final double amount;
  final String currency;
  final bool autoRenew;
  final DateTime? canceledAt;
  final Map<String, dynamic> metadata;

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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'planId': planId,
      'startDate': startDate,
      'endDate': endDate,
      'status': status,
      'paymentMethod': paymentMethod,
      'paymentId': paymentId,
      'amount': amount,
      'currency': currency,
      'autoRenew': autoRenew,
      'canceledAt': canceledAt,
      'metadata': metadata,
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      planId: map['planId'] ?? '',
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
      paymentMethod: map['paymentMethod'] ?? '',
      paymentId: map['paymentId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] ?? 'XAF',
      autoRenew: map['autoRenew'] ?? true,
      canceledAt: (map['canceledAt'] as Timestamp?)?.toDate(),
      metadata: map['metadata'] ?? {},
    );
  }

  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired' || endDate.isBefore(DateTime.now());
  bool get isCanceled => status == 'canceled';
  
  int get daysRemaining => endDate.difference(DateTime.now()).inDays;
  
  bool get willExpireSoon => daysRemaining <= 7 && daysRemaining > 0;
  
  bool get isTrial => status == 'pending' && amount == 0;

  Subscription copyWith({
    String? status,
    DateTime? endDate,
    bool? autoRenew,
    DateTime? canceledAt,
  }) {
    return Subscription(
      id: id,
      userId: userId,
      planId: planId,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      paymentMethod: paymentMethod,
      paymentId: paymentId,
      amount: amount,
      currency: currency,
      autoRenew: autoRenew ?? this.autoRenew,
      canceledAt: canceledAt ?? this.canceledAt,
      metadata: metadata,
    );
  }
}