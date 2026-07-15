// lib/models/activity_log.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLog {
  final String id;
  final String userId;
  final String userEmail;
  final String action; // 'login', 'logout', 'create_invoice', etc.
  final String? targetId;
  final String? targetType; // 'invoice', 'client', 'user', 'subscription'
  final Map<String, dynamic>? details;
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.action,
    this.targetId,
    this.targetType,
    this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'action': action,
      'targetId': targetId,
      'targetType': targetType,
      'details': details,
      'timestamp': timestamp,
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userEmail: map['userEmail'] ?? '',
      action: map['action'] ?? '',
      targetId: map['targetId'],
      targetType: map['targetType'],
      details: map['details'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory ActivityLog.create({
    required String userId,
    required String userEmail,
    required String action,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? details,
  }) {
    return ActivityLog(
      id: '', // Sera défini par Firestore
      userId: userId,
      userEmail: userEmail,
      action: action,
      targetId: targetId,
      targetType: targetType,
      details: details,
      timestamp: DateTime.now(),
    );
  }
}