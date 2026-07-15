// lib/services/sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/invoice.dart';
import '../models/client.dart';
import 'database_service.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();

  Future<void> syncInvoices() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Récupérer les factures locales
      final localInvoices = await _db.getInvoices();
      final localInvoiceIds = localInvoices.map((i) => i.id).toSet();

      // Récupérer les factures cloud
      final cloudSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('invoices')
          .get();

      final cloudInvoices = cloudSnapshot.docs.map((doc) {
        return Invoice.fromFirestore(doc.data());
      }).toList();

      final cloudInvoiceIds = cloudInvoices.map((i) => i.id).toSet();

      // Synchronisation bidirectionnelle simplifiée
      for (var invoice in localInvoices) {
        if (!cloudInvoiceIds.contains(invoice.id)) {
          // Upload local invoice to cloud
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('invoices')
              .doc(invoice.id)
              .set(invoice.toFirestore());
        }
      }

      for (var invoice in cloudInvoices) {
        if (!localInvoiceIds.contains(invoice.id)) {
          // Download cloud invoice to local
          await _db.addInvoice(invoice);
        }
      }

      // Mettre à jour les timestamps de synchronisation
      for (var invoice in localInvoices) {
        if (cloudInvoiceIds.contains(invoice.id)) {
          await _db.updateInvoice(invoice);
        }
      }
    } catch (e) {
      print('Erreur de synchronisation: $e');
    }
  }

  Future<void> syncClients() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final localClients = await _db.getClients();
      final localClientIds = localClients.map((c) => c.id).toSet();

      final cloudSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('clients')
          .get();

      final cloudClients = cloudSnapshot.docs.map((doc) {
        return Client.fromMap(doc.data());
      }).toList();

      final cloudClientIds = cloudClients.map((c) => c.id).toSet();

      // Upload local clients
      for (var client in localClients) {
        if (!cloudClientIds.contains(client.id)) {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('clients')
              .doc(client.id)
              .set(client.toMap());
        }
      }

      // Download cloud clients
      for (var client in cloudClients) {
        if (!localClientIds.contains(client.id)) {
          await _db.addClient(client);
        }
      }
    } catch (e) {
      print('Erreur de synchronisation des clients: $e');
    }
  }
}
