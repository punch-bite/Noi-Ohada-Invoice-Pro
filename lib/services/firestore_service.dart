import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/invoice.dart';
import '../models/subscription.dart';

class FirestoreService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;
  bool get isAuthenticated => _auth.currentUser != null;

  // ===== USERS =====
  Future<void> saveUser(Map<String, dynamic> userData) async {
    if (!isAuthenticated) throw Exception('Non authentifié');
    await _db.collection('users').doc(currentUserId).set(
      {...userData, 'updatedAt': FieldValue.serverTimestamp()}, 
      SetOptions(merge: true)
    );
  }

  // ===== INVOICES (Optimisés) =====

  Stream<List<Invoice>> getInvoicesStream() {
    if (!isAuthenticated) return Stream.value([]);
    
    return _db.collection('invoices')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return Invoice.fromMap(data, documentId: doc.id);
            }).toList());
  }

  Future<void> saveInvoice(Invoice invoice) async {
    if (!isAuthenticated) throw Exception('Non authentifié');
    
    await _db.collection('invoices').doc(invoice.id).set({
      ...invoice.toMap(), // Utilise toMap() pour une cohérence totale
      'userId': currentUserId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    notifyListeners();
  }

  // ===== SYNCHRONISATION (Chunked Batch) =====

  Future<void> syncLocalToCloud() async {
    if (!isAuthenticated) throw Exception('Non authentifié');

    try {
      final localInvoices = await DatabaseService().getInvoices();
      
      // Firestore limite les batchs à 500 écritures
      for (var i = 0; i < localInvoices.length; i += 500) {
        final chunk = localInvoices.skip(i).take(500);
        final batch = _db.batch();
        
        for (final invoice in chunk) {
          final ref = _db.collection('invoices').doc(invoice.id);
          batch.set(ref, {
            ...invoice.toMap(), 
            'userId': currentUserId,
            'updatedAt': FieldValue.serverTimestamp()
          }, SetOptions(merge: true));
        }
        await batch.commit();
      }
      
      debugPrint('✅ Synchronisation de ${localInvoices.length} factures terminée');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur de synchronisation: $e');
      rethrow;
    }
  }

  // ===== ABONNEMENTS =====

  Future<Subscription?> getActiveSubscription() async {
    if (!isAuthenticated) return null;
    
    final query = await _db.collection('subscriptions')
        .where('userId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    
    return query.docs.isNotEmpty 
        ? Subscription.fromMap(query.docs.first.data(), documentId: query.docs.first.id) 
        : null;
  }
}