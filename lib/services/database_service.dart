// lib/services/database_service.dart
//
// ✅ Base de données unifiée sur FIRESTORE.
// Cette classe est la SOURCE UNIQUE DE VÉRITÉ : plus de Hive.
// Toutes les ressources sont scopées par l'UID de l'utilisateur connecté.
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/invoice.dart';
import '../models/client.dart';
import '../models/company.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/reminder.dart';
import '../models/subscription.dart';
import '../models/plan.dart';
import '../models/notification.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  static const String userCol = 'users';
  static const String companyCol = 'companies';
  static const String clientCol = 'clients';
  static const String invoiceCol = 'invoices';
  static const String productCol = 'products';
  static const String supplierCol = 'suppliers';
  static const String reminderCol = 'reminders';
  static const String subscriptionCol = 'subscriptions';
  static const String planCol = 'plans';
  static const String notificationCol = 'notifications';

  static Future<void> init() async {
    debugPrint('DatabaseService initialise (Firestore)');
  }

  // ============ USER ============
  Future<AppUser?> getUser() async {
    final uid = currentUserId;
    if (uid == null) return null;
    final doc = await _db.collection(userCol).doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return AppUser.fromMap(data);
  }

  Future<void> saveUser(AppUser user) async {
    await _db.collection(userCol).doc(user.id).set({
      ...user.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUser(AppUser user) async {
    await saveUser(user);
  }

  Future<void> clearUser() async {
    // Session Auth effacee ; donnees conservees dans Firestore.
  }

  // ============ COMPANY ============
  Future<Company?> getCompany() async {
    final uid = currentUserId;
    if (uid == null) return null;
    final query = await _db
        .collection(companyCol)
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final data = query.docs.first.data();
    data['id'] = query.docs.first.id;
    return Company.fromMap(data);
  }

  Future<void> saveCompany(Company company) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifie');
    await _db.collection(companyCol).doc(company.id).set({
      ...company.toMap(),
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markCompanySynced() async {
    // Firestore est deja la source de verite.
  }

  // ============ CLIENTS ============
  Future<List<Client>> getClients() async {
    final uid = currentUserId;
    if (uid == null) return [];
    final snapshot = await _db
        .collection(clientCol)
        .where('userId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Client.fromMap(data);
    }).toList();
  }

  Future<Client?> getClient(String id) async {
    final doc = await _db.collection(clientCol).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return Client.fromMap(data);
  }

  Future<void> addClient(Client client) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifie');
    await _db.collection(clientCol).doc(client.id).set({
      ...client.toMap(),
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateClient(Client client) async {
    await addClient(client);
  }

  Future<void> deleteClient(String id) async {
    await _db.collection(clientCol).doc(id).delete();
  }

  // ============ INVOICES ============
  Future<List<Invoice>> getInvoices() async {
    final uid = currentUserId;
    if (uid == null) return [];
    final snapshot = await _db
        .collection(invoiceCol)
        .where('userId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Invoice.fromMap(data);
    }).toList();
  }

  Future<Invoice?> getInvoice(String id) async {
    final doc = await _db.collection(invoiceCol).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return Invoice.fromMap(data);
  }

  Future<void> addInvoice(Invoice invoice) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifie');
    await _db.collection(invoiceCol).doc(invoice.id).set({
      ...invoice.toMap(),
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateInvoice(Invoice invoice) async {
    await addInvoice(invoice);
  }

  Future<void> deleteInvoice(String id) async {
    await _db.collection(invoiceCol).doc(id).delete();
  }

  Future<String> getNextInvoiceNumber(bool isDevis) async {
    final uid = currentUserId;
    if (uid == null) return 'FA-${DateTime.now().year}-001';

    final prefix = isDevis ? 'DEV' : 'FA';
    final year = DateTime.now().year;
    // Compteur atomique par utilisateur : évite les doublons en concurrence.
    final counterRef = _db.collection('counters').doc(uid);
    final field = isDevis ? 'devisCount' : 'invoiceCount';

    try {
      final sequence = await _db.runTransaction((txn) async {
        final snap = await txn.get(counterRef);
        final current = (snap.data()?[field] as num?)?.toInt() ?? 0;
        final next = current + 1;
        txn.set(counterRef, {field: next}, SetOptions(merge: true));
        return next;
      });
      return '$prefix-$year-${sequence.toString().padLeft(3, '0')}';
    } catch (_) {
      // Fallback non atomique (règles sans `counters`) : compte réel.
      final snapshot = await _db
          .collection(invoiceCol)
          .where('userId', isEqualTo: uid)
          .where('isDevis', isEqualTo: isDevis)
          .get();
      final count = snapshot.docs.length + 1;
      return '$prefix-$year-${count.toString().padLeft(3, '0')}';
    }
  }

  Future<List<Invoice>> getInvoicesByStatus(String status) async {
    final all = await getInvoices();
    return all.where((inv) => inv.status == status).toList();
  }

  Future<List<Invoice>> getOverdueInvoices() async {
    final now = DateTime.now();
    final all = await getInvoices();
    return all
        .where((inv) =>
            inv.status != 'paid' &&
            inv.status != 'overdue' &&
            inv.dueDate.isBefore(now))
        .toList();
  }

  Future<List<Invoice>> getInvoicesByClient(String clientId) async {
    final all = await getInvoices();
    return all.where((inv) => inv.clientId == clientId).toList();
  }

  Future<void> updateInvoiceStatus(String id, String status) async {
    final invoice = await getInvoice(id);
    if (invoice != null) {
      await updateInvoice(invoice.copyWith(status: status, isSynced: true));
    }
  }

  // ============ PRODUCTS ============
  Future<List<Product>> getProducts() async {
    final uid = currentUserId;
    if (uid == null) return [];
    final snapshot = await _db
        .collection(productCol)
        .where('userId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Product.fromMap(data);
    }).toList();
  }

  Future<Product?> getProduct(String id) async {
    final doc = await _db.collection(productCol).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return Product.fromMap(data);
  }

  Future<void> saveProduct(Product product) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifie');
    await _db.collection(productCol).doc(product.id).set({
      ...product.toMap(),
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteProduct(String id) async {
    await _db.collection(productCol).doc(id).delete();
  }

  // ============ PLANS ============
  Future<List<Plan>> getPlans() async {
    final snapshot = await _db.collection(planCol).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Plan.fromMap(data);
    }).toList();
  }

  Future<Plan?> getPlan(String id) async {
    final doc = await _db.collection(planCol).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return Plan.fromMap(data);
  }

  Future<void> savePlan(Plan plan) async {
    await _db.collection(planCol).doc(plan.id).set(plan.toMap());
  }

  // ============ SUBSCRIPTIONS ============
  Future<List<Subscription>> getSubscriptions() async {
    final uid = currentUserId;
    if (uid == null) return [];
    final snapshot = await _db
        .collection(subscriptionCol)
        .where('userId', isEqualTo: uid)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Subscription.fromMap(data);
    }).toList();
  }

  Future<Subscription?> getSubscription(String id) async {
    final doc = await _db.collection(subscriptionCol).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return Subscription.fromMap(data);
  }

  Future<Subscription?> getUserActiveSubscription(String userId) async {
    final query = await _db
        .collection(subscriptionCol)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final data = query.docs.first.data();
    data['id'] = query.docs.first.id;
    return Subscription.fromMap(data);
  }

  Future<void> saveSubscription(Subscription subscription) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifie');
    await _db.collection(subscriptionCol).doc(subscription.id).set({
      ...subscription.toMap(),
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteSubscription(String id) async {
    await _db.collection(subscriptionCol).doc(id).delete();
  }

  // ============ SUPPLIERS ============
  Future<List<Supplier>> getSuppliers() async {
    final uid = currentUserId;
    if (uid == null) return [];
    final snapshot = await _db
        .collection(supplierCol)
        .where('userId', isEqualTo: uid)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Supplier.fromMap(data);
    }).toList();
  }

  Future<Supplier?> getSupplier(String id) async {
    final doc = await _db.collection(supplierCol).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return Supplier.fromMap(data);
  }

  Future<void> saveSupplier(Supplier supplier) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifie');
    await _db.collection(supplierCol).doc(supplier.id).set({
      ...supplier.toMap(),
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteSupplier(String id) async {
    await _db.collection(supplierCol).doc(id).delete();
  }

  // ============ REMINDERS ============
  Future<List<Reminder>> getReminders() async {
    final uid = currentUserId;
    if (uid == null) return [];
    final snapshot = await _db
        .collection(reminderCol)
        .where('userId', isEqualTo: uid)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Reminder.fromMap(data);
    }).toList();
  }

  Future<void> saveReminder(Reminder reminder) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifie');
    await _db.collection(reminderCol).doc(reminder.id).set({
      ...reminder.toMap(),
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteReminder(String id) async {
    await _db.collection(reminderCol).doc(id).delete();
  }

  // ============ NOTIFICATIONS ============
  Future<List<AppNotification>> getNotifications() async {
    final uid = currentUserId;
    if (uid == null) return [];
    final snapshot = await _db
        .collection(notificationCol)
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return AppNotification.fromMap(data);
    }).toList();
  }

  Future<void> saveNotification(AppNotification notification) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifie');
    await _db.collection(notificationCol).doc(notification.id).set({
      ...notification.toMap(),
      'userId': uid,
    }, SetOptions(merge: true));
  }

  Future<void> deleteNotification(String id) async {
    await _db.collection(notificationCol).doc(id).delete();
  }

  Future<void> clearNotifications() async {
    final notifs = await getNotifications();
    for (final n in notifs) {
      await _db.collection(notificationCol).doc(n.id).delete();
    }
  }

  // ============ CRUD GENERIQUE ============
  Future<List<T>> getAll<T>(String collectionPath) async {
    final snapshot = await _db.collection(collectionPath).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return _fromDoc<T>(collectionPath, data);
    }).toList();
  }

  Future<void> save<T>(String collectionPath, T item) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifie');
    final data = (item as dynamic).toMap() as Map<String, dynamic>;
    final id = (item as dynamic).id as String;
    await _db.collection(collectionPath).doc(id).set({
      ...data,
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> delete<T>(String collectionPath, String id) async {
    await _db.collection(collectionPath).doc(id).delete();
  }

  Future<T?> getById<T>(String collectionPath, String id) async {
    final doc = await _db.collection(collectionPath).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return _fromDoc<T>(collectionPath, data);
  }

  @protected
  T _fromDoc<T>(String collectionPath, Map<String, dynamic> data) {
    switch (collectionPath) {
      case clientCol:
        return Client.fromMap(data) as T;
      case productCol:
        return Product.fromMap(data) as T;
      case supplierCol:
        return Supplier.fromMap(data) as T;
      case invoiceCol:
        return Invoice.fromMap(data) as T;
      case reminderCol:
        return Reminder.fromMap(data) as T;
      case subscriptionCol:
        return Subscription.fromMap(data) as T;
      case planCol:
        return Plan.fromMap(data) as T;
      case notificationCol:
        return AppNotification.fromMap(data) as T;
      default:
        throw UnsupportedError('Collection non supportee: $collectionPath');
    }
  }

  // ============ NETTOYAGE ============
  /// Vide TOUTES les collections de l'utilisateur (métier + auxiliaires).
  /// Découpe en lots de <=450 écritures pour respecter la limite Firestore
  /// de 500 opérations par batch (marge de sécurité).
  Future<void> clearAllData() async {
    final uid = currentUserId;
    if (uid == null) return;

    const collections = [
      clientCol,
      productCol,
      invoiceCol,
      supplierCol,
      reminderCol,
      notificationCol,
      subscriptionCol,
    ];

    for (final col in collections) {
      final snapshot = await _db
          .collection(col)
          .where('userId', isEqualTo: uid)
          .get();
      final refs = snapshot.docs.map((d) => d.reference).toList();

      // Suppression par lots de 450 documents
      for (var i = 0; i < refs.length; i += 450) {
        final chunk = refs.sublist(
          i,
          i + 450 > refs.length ? refs.length : i + 450,
        );
        final batch = _db.batch();
        for (final ref in chunk) {
          batch.delete(ref);
        }
        await batch.commit();
      }
    }
  }
}
