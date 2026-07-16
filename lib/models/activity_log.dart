// lib/models/activity_log.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

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
      // On sauvegarde en format Timestamp pour Firestore
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map, {String? documentId}) {
    // Gestion ultra-robuste du parsing de la date (Timestamp, String ISO ou int)
    DateTime parsedTimestamp = DateTime.now();
    final rawTimestamp = map['timestamp'];
    
    if (rawTimestamp is Timestamp) {
      parsedTimestamp = rawTimestamp.toDate();
    } else if (rawTimestamp is String) {
      parsedTimestamp = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else if (rawTimestamp is int) {
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    }

    return ActivityLog(
      // On utilise l'id passé (ex: document ID Firestore) ou celui du map, sinon vide ou généré
      id: documentId ?? map['id'] ?? '',
      userId: map['userId'] ?? '',
      userEmail: map['userEmail'] ?? '',
      action: map['action'] ?? '',
      targetId: map['targetId'],
      targetType: map['targetType'],
      details: map['details'] != null ? Map<String, dynamic>.from(map['details']) : null,
      timestamp: parsedTimestamp,
    );
  }

  factory ActivityLog.create({
    String? id,
    required String userId,
    required String userEmail,
    required String action,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? details,
  }) {
    return ActivityLog(
      // On génère un UUID client-side si aucun ID n'est fourni, évitant ainsi les IDs vides perturbants en UI
      id: id ?? const Uuid().v4(),
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