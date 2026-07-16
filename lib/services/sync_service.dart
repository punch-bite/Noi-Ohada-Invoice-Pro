// lib/services/sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/invoice.dart';
import 'database_service.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();

  Future<void> syncAll() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Synchronisation des factures
    final localInvoices = await _db.getInvoices();
    final cloudSnapshot = await _firestore.collection('users').doc(userId).collection('invoices').get();
    final cloudInvoices = cloudSnapshot.docs.map((d) => Invoice.fromMap(d.data(), documentId: d.id)).toList();

    final localMap = {for (var i in localInvoices) i.id: i};
    final cloudMap = {for (var i in cloudInvoices) i.id: i};

    // 1. Upload vers Cloud (Local plus récent)
    for (var local in localInvoices) {
      final cloud = cloudMap[local.id];
      if (cloud == null || local.updatedAt.isAfter(cloud.updatedAt)) {
        await _firestore.collection('users').doc(userId).collection('invoices').doc(local.id).set(local.toMap());
      }
    }

    // 2. Download vers Local (Cloud plus récent)
    for (var cloud in cloudInvoices) {
      final local = localMap[cloud.id];
      if (local == null) {
        await _db.addInvoice(cloud);
      } else if (cloud.updatedAt.isAfter(local.updatedAt)) {
        await _db.updateInvoice(cloud);
      }
    }
  }
}