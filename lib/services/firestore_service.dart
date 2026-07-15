// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:noi_ohada_invoice_pro/services/database_service.dart';
import '../models/invoice.dart';
import '../models/client.dart';
import '../models/subscription.dart';
import '../models/plan.dart';

class FirestoreService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ===== UTILITAIRES =====

  String? get currentUserId => _auth.currentUser?.uid;
  bool get isAuthenticated => _auth.currentUser != null;

  // ===== UTILISATEURS =====

  Future<void> saveUser(Map<String, dynamic> userData) async {
    if (!isAuthenticated) throw Exception('Non authentifié');
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .set(userData, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUser() async {
    if (!isAuthenticated) return null;
    final doc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .get();
    if (doc.exists) {
      return doc.data();
    }
    return null;
  }

  Stream<DocumentSnapshot> getUserStream() {
    if (!isAuthenticated) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .snapshots();
  }

  // ===== FACTURES =====

  Future<void> saveInvoice(Invoice invoice) async {
    if (!isAuthenticated) throw Exception('Non authentifié');
    
    final data = invoice.toFirestore();
    data['userId'] = currentUserId;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    
    await _firestore
        .collection('invoices')
        .doc(invoice.id)
        .set(data);
    
    notifyListeners();
  }

  Future<Invoice?> getInvoice(String invoiceId) async {
    if (!isAuthenticated) return null;
    
    final doc = await _firestore
        .collection('invoices')
        .doc(invoiceId)
        .get();
    
    if (doc.exists) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return Invoice.fromFirestore(data);
    }
    return null;
  }

  Stream<QuerySnapshot> getInvoicesStream() {
    if (!isAuthenticated) {
      return const Stream.empty();
    }
    return _firestore
        .collection('invoices')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<List<Invoice>> getInvoices() async {
    if (!isAuthenticated) return [];
    
    final query = await _firestore
        .collection('invoices')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .get();
    
    return query.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Invoice.fromFirestore(data);
    }).toList();
  }

  Future<void> deleteInvoice(String invoiceId) async {
    if (!isAuthenticated) throw Exception('Non authentifié');
    
    await _firestore
        .collection('invoices')
        .doc(invoiceId)
        .delete();
    
    notifyListeners();
  }

  Future<void> updateInvoiceStatus(String invoiceId, String status) async {
    if (!isAuthenticated) throw Exception('Non authentifié');
    
    await _firestore
        .collection('invoices')
        .doc(invoiceId)
        .update({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    
    notifyListeners();
  }

  // ===== CLIENTS =====

  Future<void> saveClient(Client client) async {
    if (!isAuthenticated) throw Exception('Non authentifié');
    
    final data = client.toMap();
    data['userId'] = currentUserId;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    
    await _firestore
        .collection('clients')
        .doc(client.id)
        .set(data);
    
    notifyListeners();
  }

  Future<Client?> getClient(String clientId) async {
    if (!isAuthenticated) return null;
    
    final doc = await _firestore
        .collection('clients')
        .doc(clientId)
        .get();
    
    if (doc.exists) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return Client.fromMap(data);
    }
    return null;
  }

  Stream<QuerySnapshot> getClientsStream() {
    if (!isAuthenticated) {
      return const Stream.empty();
    }
    return _firestore
        .collection('clients')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<List<Client>> getClients() async {
    if (!isAuthenticated) return [];
    
    final query = await _firestore
        .collection('clients')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .get();
    
    return query.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Client.fromMap(data);
    }).toList();
  }

  Future<void> deleteClient(String clientId) async {
    if (!isAuthenticated) throw Exception('Non authentifié');
    
    await _firestore
        .collection('clients')
        .doc(clientId)
        .delete();
    
    notifyListeners();
  }

  // ===== ABONNEMENTS =====

  Future<void> saveSubscription(Subscription subscription) async {
    if (!isAuthenticated) throw Exception('Non authentifié');
    
    final data = subscription.toMap();
    data['userId'] = currentUserId;
    data['createdAt'] = FieldValue.serverTimestamp();
    
    await _firestore
        .collection('subscriptions')
        .doc(subscription.id)
        .set(data);
    
    // Mettre à jour l'utilisateur
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .update({
          'subscriptionId': subscription.id,
        });
    
    notifyListeners();
  }

  Future<Subscription?> getActiveSubscription() async {
    if (!isAuthenticated) return null;
    
    final query = await _firestore
        .collection('subscriptions')
        .where('userId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    
    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      data['id'] = query.docs.first.id;
      return Subscription.fromMap(data);
    }
    return null;
  }

  // ===== PLANS =====

  Future<List<Plan>> getPlans() async {
    final query = await _firestore
        .collection('plans')
        .where('isActive', isEqualTo: true)
        .get();
    
    if (query.docs.isNotEmpty) {
      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Plan.fromMap(data);
      }).toList();
    }
    
    // Plans par défaut si pas dans Firestore
    return Plan.getDefaultPlans();
  }

  Future<Plan?> getPlan(String planId) async {
    final doc = await _firestore
        .collection('plans')
        .doc(planId)
        .get();
    
    if (doc.exists) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return Plan.fromMap(data);
    }
    return null;
  }

  // ===== INITIALISATION =====

  // Créer les plans par défaut dans Firestore
  Future<void> initializeDefaultPlans() async {
    try {
      final existing = await _firestore.collection('plans').get();
      if (existing.docs.isEmpty) {
        final plans = Plan.getDefaultPlans();
        for (final plan in plans) {
          await _firestore.collection('plans').doc(plan.id).set(plan.toMap());
        }
        print('✅ Plans par défaut créés avec succès');
      }
    } catch (e) {
      print('❌ Erreur création plans: $e');
    }
  }

  // ===== SYNC ENTRE LOCAL ET CLOUD =====

  Future<void> syncLocalToCloud() async {
    if (!isAuthenticated) throw Exception('Non authentifié');

    try {
      // 1. Récupérer les données locales
      final localInvoices = await DatabaseService().getInvoices();
      final localClients = await DatabaseService().getClients();

      // 2. Récupérer les données cloud
      final cloudInvoices = await getInvoices();
      final cloudClients = await getClients();

      final cloudInvoiceIds = cloudInvoices.map((i) => i.id).toSet();
      final cloudClientIds = cloudClients.map((c) => c.id).toSet();

      // 3. Uploader les données locales vers le cloud
      for (final invoice in localInvoices) {
        if (!cloudInvoiceIds.contains(invoice.id)) {
          await saveInvoice(invoice);
        }
      }

      for (final client in localClients) {
        if (!cloudClientIds.contains(client.id)) {
          await saveClient(client);
        }
      }

      // 4. Downloader les données cloud vers local
      for (final invoice in cloudInvoices) {
        // Vérifier si la facture existe déjà en local
        final localExists = localInvoices.any((i) => i.id == invoice.id);
        if (!localExists) {
          await DatabaseService().addInvoice(invoice);
        }
      }

      for (final client in cloudClients) {
        final localExists = localClients.any((c) => c.id == client.id);
        if (!localExists) {
          await DatabaseService().addClient(client);
        }
      }

      print('✅ Synchronisation terminée');
      notifyListeners();
    } catch (e) {
      print('❌ Erreur synchronisation: $e');
      throw Exception('Erreur de synchronisation: $e');
    }
  }

  // ===== ÉCOUTEUR EN TEMPS RÉEL =====

  // Écouter les changements de factures en temps réel
  void listenInvoices(Function(List<Invoice>) onUpdate) {
    if (!isAuthenticated) return;
    
    _firestore
        .collection('invoices')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .listen((snapshot) {
          final invoices = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return Invoice.fromFirestore(data);
          }).toList();
          onUpdate(invoices);
        });
  }

  // Écouter les changements de clients en temps réel
  void listenClients(Function(List<Client>) onUpdate) {
    if (!isAuthenticated) return;
    
    _firestore
        .collection('clients')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .listen((snapshot) {
          final clients = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return Client.fromMap(data);
          }).toList();
          onUpdate(clients);
        });
  }
}