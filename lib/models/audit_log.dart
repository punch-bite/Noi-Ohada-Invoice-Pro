// lib/models/audit_log.dart
//
// 📝 Modèle du journal d'audit.
//
import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogEntry {
  final String id;
  final String collection;
  final String docId;
  final String action; // 'create' | 'update' | 'delete'
  final String? actorUid;
  final String? ownerUidBefore;
  final String? ownerUidAfter;
  final bool ownershipChanged;
  final String? companyId;
  final Map<String, dynamic>? diff;
  final DateTime timestamp;

  const AuditLogEntry({
    required this.id,
    required this.collection,
    required this.docId,
    required this.action,
    this.actorUid,
    this.ownerUidBefore,
    this.ownerUidAfter,
    this.ownershipChanged = false,
    this.companyId,
    this.diff,
    required this.timestamp,
  });

  factory AuditLogEntry.fromMap(Map<String, dynamic> map,
      {String? documentId}) {
    return AuditLogEntry(
      id: documentId ?? map['id'] ?? '',
      collection: map['collection'] ?? '',
      docId: map['docId'] ?? '',
      action: map['action'] ?? 'update',
      actorUid: map['actorUid'],
      ownerUidBefore: map['ownerUidBefore'],
      ownerUidAfter: map['ownerUidAfter'],
      ownershipChanged: map['ownershipChanged'] == true,
      companyId: map['companyId'],
      diff: map['diff'] != null
          ? Map<String, dynamic>.from(map['diff'])
          : null,
      timestamp: _parseDate(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'collection': collection,
        'docId': docId,
        'action': action,
        'actorUid': actorUid,
        'ownerUidBefore': ownerUidBefore,
        'ownerUidAfter': ownerUidAfter,
        'ownershipChanged': ownershipChanged,
        'companyId': companyId,
        'diff': diff,
        'timestamp': Timestamp.fromDate(timestamp),
      };

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return DateTime.now();
  }

  String get actionLabel {
    switch (action) {
      case 'create':
        return 'Création';
      case 'delete':
        return 'Suppression';
      default:
        return 'Modification';
    }
  }

  String get collectionLabel {
    switch (collection) {
      case 'clients':
        return 'Client';
      case 'invoices':
        return 'Facture';
      case 'products':
        return 'Produit';
      case 'suppliers':
        return 'Fournisseur';
      case 'reminders':
        return 'Rappel';
      case 'companies':
        return 'Entreprise';
      case 'users':
        return 'Utilisateur';
      default:
        return collection;
    }
  }
}