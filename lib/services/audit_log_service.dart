// lib/services/audit_log_service.dart
//
// 📝 Service d'audit côté client.
//
// Les écritures réelles sont loggées automatiquement par les Cloud Functions
// (`functions/audit_log.js`). Ce service permet :
//   • de consulter les logs (écran admin)
//   • de logger des actions non couvertes par les triggers CF
//     (ex : actions de sécurité, migrations manuelles)
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/audit_log.dart';

class AuditLogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _col = 'admin_audit_log';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// 📖 Récupère les N derniers logs (admin uniquement).
  ///
  /// Filtres optionnels :
  ///   • [collection] : 'clients', 'invoices', ...
  ///   • [onlyOwnershipChanges] : ne montrer que les écrasements.
  ///   • [limit] : 100 par défaut.
  Future<List<AuditLogEntry>> getLogs({
    String? collection,
    bool onlyOwnershipChanges = false,
    int limit = 100,
  }) async {
    try {
      Query query = _db.collection(_col);

      if (collection != null && collection.isNotEmpty) {
        query = query.where('collection', isEqualTo: collection);
      }
      if (onlyOwnershipChanges) {
        query = query.where('ownershipChanged', isEqualTo: true);
      }

      query = query.orderBy('timestamp', descending: true).limit(limit);

      final snap = await query.get();
      return snap.docs
          .map((d) => AuditLogEntry.fromMap(d.data() as Map<String, dynamic>,
              documentId: d.id))
          .toList();
    } catch (e) {
      debugPrint('⚠️ AuditLogService.getLogs : $e');
      return [];
    }
  }

  /// 📡 Stream temps réel des logs (admin uniquement).
  Stream<List<AuditLogEntry>> watchLogs({
    String? collection,
    bool onlyOwnershipChanges = false,
    int limit = 50,
  }) {
    Query query = _db.collection(_col);

    if (collection != null && collection.isNotEmpty) {
      query = query.where('collection', isEqualTo: collection);
    }
    if (onlyOwnershipChanges) {
      query = query.where('ownershipChanged', isEqualTo: true);
    }

    query = query.orderBy('timestamp', descending: true).limit(limit);

    return query.snapshots().map((snap) => snap.docs
        .map((d) => AuditLogEntry.fromMap(d.data() as Map<String, dynamic>,
            documentId: d.id))
        .toList());
  }

  /// 📝 Enregistre manuellement un log (pour les actions client-only).
  Future<void> log({
    required String collection,
    required String docId,
    required String action,
    Map<String, dynamic>? diff,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final docRef = _db.collection(_col).doc();
      await docRef.set({
        'id': docRef.id,
        'collection': collection,
        'docId': docId,
        'action': action,
        'actorUid': uid,
        'companyId': null,
        'diff': diff,
        'ownershipChanged': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ AuditLogService.log : $e');
    }
  }

  /// 🧹 Supprime tous les logs (admin uniquement, action destructrice).
  Future<void> clearAll() async {
    try {
      final snap = await _db.collection(_col).limit(500).get();
      for (final d in snap.docs) {
        await d.reference.delete();
      }
    } catch (e) {
      debugPrint('⚠️ AuditLogService.clearAll : $e');
    }
  }
}