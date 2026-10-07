// lib/services/database_service.dart
//
// CHANGELOG (v6 — Audit + Mode lecture seule) :
//   • Fix v5 conservé : préserve userId/companyId sur toute mise à jour.
//   • 🆕 `isReadOnlyForMe()` : détecte si l'admin ouvre un document tiers
//     (l'UI doit alors passer en mode lecture seule).
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
import '../models/invoice_template.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  static const String userCol         = 'users';
  static const String companyCol      = 'companies';
  static const String clientCol       = 'clients';
  static const String invoiceCol      = 'invoices';
  static const String productCol      = 'products';
  static const String supplierCol     = 'suppliers';
  static const String reminderCol     = 'reminders';
  static const String subscriptionCol = 'subscriptions';
  static const String planCol         = 'plans';
  static const String notificationCol = 'notifications';

  static Future<void> init() async {
    debugPrint('DatabaseService initialisé (Firestore)');
  }

  // ═══════════════════════════════════════════════════════════════
  //  USER
  // ═══════════════════════════════════════════════════════════════
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

  Future<void> updateUser(AppUser user) => saveUser(user);

  Future<void> clearUser() async {
    // Session Auth effacée ; données conservées dans Firestore.
  }

  // ═══════════════════════════════════════════════════════════════
  //  COMPANY
  // ═══════════════════════════════════════════════════════════════
  Future<Company?> getCompany() async {
    final uid = currentUserId;
    if (uid == null) return null;

    final user = await getUser();
    final companyId = user?.companyId;

    if (companyId != null && companyId.isNotEmpty) {
      try {
        final doc = await _db.collection(companyCol).doc(companyId).get();
        if (doc.exists) {
          final data = doc.data()!;
          data['id'] = doc.id;
          return Company.fromMap(data);
        }
      } catch (e) {
        debugPrint('⚠️ getCompany($companyId): $e');
      }
    }

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
    if (uid == null) throw Exception('Non authentifié');
    await _db.collection(companyCol).doc(company.id).set({
      ...company.toMap(),
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final user = await getUser();
    if (user != null && user.companyId != company.id) {
      await saveUser(user.copyWith(companyId: company.id));
      try {
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
      } catch (_) {}
    }
  }

  Future<void> markCompanySynced() async {}

  // ═══════════════════════════════════════════════════════════════
  //  MULTI-TENANT SAAS QUERY HELPER
  // ═══════════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> _getSaaSQueryDocs(
      String collectionPath) async {
    final uid = currentUserId;
    if (uid == null) return [];

    final user = await getUser();
    final company = await getCompany();
    final companyId = company?.id;

    if (user != null && user.isAdmin) {
      try {
        final snapshot = await _db
            .collection(collectionPath)
            .orderBy('updatedAt', descending: true)
            .get();
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      } catch (e) {
        debugPrint('❌ admin query [$collectionPath] : $e');
        return [];
      }
    }

    final resultsMap = <String, Map<String, dynamic>>{};

    Future<void> run(String label, Query q) async {
      try {
        final snap = await q.get();
        for (final doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          resultsMap[doc.id] = data;
        }
      } catch (e, st) {
        debugPrint('❌ _getSaaSQueryDocs[$label] $collectionPath : $e\n$st');
      }
    }

    await run('owner',
        _db.collection(collectionPath).where('userId', isEqualTo: uid));
    await run('shared',
        _db.collection(collectionPath)
            .where('sharedWithUsers', arrayContains: uid));
    if (companyId != null && companyId.isNotEmpty) {
      await run('company',
          _db.collection(collectionPath)
              .where('companyId', isEqualTo: companyId));
    }

    final list = resultsMap.values.toList();
    list.sort((a, b) {
      final aTs = a['updatedAt'];
      final bTs = b['updatedAt'];
      final aDate = aTs is Timestamp
          ? aTs.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = bTs is Timestamp
          ? bTs.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return list;
  }

  Future<String?> _resolveCompanyId() async {
    final company = await getCompany();
    return company?.id;
  }

  // ═══════════════════════════════════════════════════════════════
  //  🔒 GARDE ÉCRITURE
  // ═══════════════════════════════════════════════════════════════
  Future<bool> canWriteOn(String collectionPath, String docId) async {
    final uid = currentUserId;
    if (uid == null) return false;

    final doc = await _db.collection(collectionPath).doc(docId).get();
    if (!doc.exists) return true;

    final data = doc.data()!;
    if (data['userId'] == uid) return true;

    final user = await getUser();
    final myCompanyId = user?.companyId;
    if (myCompanyId != null &&
        myCompanyId.isNotEmpty &&
        data['companyId'] == myCompanyId) {
      return true;
    }

    final editable = List<String>.from(data['editableByUsers'] ?? []);
    if (editable.contains(uid)) return true;

    if (user?.isAdmin == true) return true;

    return false;
  }

  /// 🛡️ Vrai si l'utilisateur courant est admin MAIS n'est pas le
  /// propriétaire du document → l'UI doit passer en mode lecture seule.
  Future<bool> isReadOnlyForMe(String collectionPath, String docId) async {
    final uid = currentUserId;
    if (uid == null) return true;

    final user = await getUser();
    if (user?.isAdmin != true) return false;

    final doc = await _db.collection(collectionPath).doc(docId).get();
    if (!doc.exists) return false;

    final owner = doc.data()?['userId'];
    return owner != null && owner != uid;
  }

  Future<Map<String, dynamic>> _buildOwnershipFields({
    required String collectionPath,
    required String docId,
    required Map<String, dynamic> incomingMap,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifié');

    final docRef = _db.collection(collectionPath).doc(docId);
    final existing = await docRef.get();

    if (existing.exists) {
      final original = existing.data()!;
      incomingMap['userId'] = original['userId'] ?? uid;
      incomingMap['companyId'] = original['companyId'];
      incomingMap['lastEditedBy'] = uid;
    } else {
      incomingMap['userId'] = uid;
      incomingMap['lastEditedBy'] = uid;
      final companyId = await _resolveCompanyId();
      final existingCompanyId = incomingMap['companyId'];
      if (existingCompanyId == null || (existingCompanyId as String).isEmpty) {
        incomingMap['companyId'] = companyId;
      }
    }
    incomingMap['updatedAt'] = FieldValue.serverTimestamp();
    return incomingMap;
  }

  // ═══════════════════════════════════════════════════════════════
  //  CLIENTS
  // ═══════════════════════════════════════════════════════════════
  Future<List<Client>> getClients() async {
    final docs = await _getSaaSQueryDocs(clientCol);
    return docs.map(Client.fromMap).toList();
  }

  Future<Client?> getClient(String id) async {
    final uid = currentUserId;
    if (uid == null) return null;
    final doc = await _db.collection(clientCol).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    final user = await getUser();
    if (user != null && user.isAdmin) {
      data['id'] = doc.id;
      return Client.fromMap(data);
    }
    final ownerId = data['userId'];
    final docCompanyId = data['companyId'];
    final company = await getCompany();
    final sharedList = List<String>.from(data['sharedWithUsers'] ?? []);
    if (ownerId != null &&
        ownerId != uid &&
        !sharedList.contains(uid) &&
        (company == null || docCompanyId != company.id)) {
      return null;
    }
    data['id'] = doc.id;
    return Client.fromMap(data);
  }

  Future<void> addClient(Client client) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifié');
    if (!await canWriteOn(clientCol, client.id)) {
      throw Exception('Vous n\'avez pas le droit de modifier ce client.');
    }
    final map = await _buildOwnershipFields(
      collectionPath: clientCol,
      docId: client.id,
      incomingMap: client.toMap(),
    );
    await _db
        .collection(clientCol)
        .doc(client.id)
        .set(map, SetOptions(merge: true));
  }

  Future<void> updateClient(Client client) => addClient(client);
  Future<void> deleteClient(String id) =>
      _db.collection(clientCol).doc(id).delete();

  // ═══════════════════════════════════════════════════════════════
  //  INVOICES
  // ═══════════════════════════════════════════════════════════════
  Future<List<Invoice>> getInvoices() async {
    final docs = await _getSaaSQueryDocs(invoiceCol);
    return docs.map(Invoice.fromMap).toList();
  }

  Future<Invoice?> getInvoice(String id) async {
    final uid = currentUserId;
    if (uid == null) return null;
    final doc = await _db.collection(invoiceCol).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    final user = await getUser();
    if (user != null && user.isAdmin) {
      data['id'] = doc.id;
      return Invoice.fromMap(data);
    }
    final ownerId = data['userId'];
    final docCompanyId = data['companyId'];
    final company = await getCompany();
    final sharedList = List<String>.from(data['sharedWithUsers'] ?? []);
    if (ownerId != null &&
        ownerId != uid &&
        !sharedList.contains(uid) &&
        (company == null || docCompanyId != company.id)) {
      return null;
    }
    data['id'] = doc.id;
    return Invoice.fromMap(data);
  }

  Future<void> addInvoice(Invoice invoice) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifié');
    if (!await canWriteOn(invoiceCol, invoice.id)) {
      throw Exception('Vous n\'avez pas le droit de modifier cette facture.');
    }
    final map = await _buildOwnershipFields(
      collectionPath: invoiceCol,
      docId: invoice.id,
      incomingMap: invoice.toMap(),
    );
    if (invoice.companyId.isNotEmpty) {
      final existing = await _db.collection(invoiceCol).doc(invoice.id).get();
      if (!existing.exists) {
        map['companyId'] = invoice.companyId;
      }
    }
    await _db
        .collection(invoiceCol)
        .doc(invoice.id)
        .set(map, SetOptions(merge: true));
  }

  Future<void> updateInvoice(Invoice invoice) => addInvoice(invoice);
  Future<void> deleteInvoice(String id) =>
      _db.collection(invoiceCol).doc(id).delete();

  Future<String> getNextInvoiceNumber(bool isDevis) async {
    final uid = currentUserId;
    if (uid == null) return 'FA-${DateTime.now().year}-001';

    final companyId = await _resolveCompanyId();
    final scopeId = companyId ?? uid;

    final prefix = isDevis ? 'DEV' : 'FA';
    final year = DateTime.now().year;
    final counterRef = _db.collection('counters').doc(scopeId);
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
    } catch (e) {
      debugPrint('⚠️ compteur ($scopeId) échec, fallback : $e');
      final docs = await _getSaaSQueryDocs(invoiceCol);
      final filtered = docs.where((d) => d['isDevis'] == isDevis).toList();
      final count = filtered.length + 1;
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

  // ═══════════════════════════════════════════════════════════════
  //  PRODUCTS
  // ═══════════════════════════════════════════════════════════════
  Future<List<Product>> getProducts() async {
    final docs = await _getSaaSQueryDocs(productCol);
    return docs.map(Product.fromMap).toList();
  }

  Future<Product?> getProduct(String id) async {
    final uid = currentUserId;
    if (uid == null) return null;
    final doc = await _db.collection(productCol).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    final user = await getUser();
    if (user != null && user.isAdmin) {
      data['id'] = doc.id;
      return Product.fromMap(data);
    }
    final ownerId = data['userId'];
    final docCompanyId = data['companyId'];
    final company = await getCompany();
    final sharedList = List<String>.from(data['sharedWithUsers'] ?? []);
    if (ownerId != null &&
        ownerId != uid &&
        !sharedList.contains(uid) &&
        (company == null || docCompanyId != company.id)) {
      return null;
    }
    data['id'] = doc.id;
    return Product.fromMap(data);
  }

  Future<void> saveProduct(Product product) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifié');
    if (!await canWriteOn(productCol, product.id)) {
      throw Exception('Vous n\'avez pas le droit de modifier ce produit.');
    }
    final map = await _buildOwnershipFields(
      collectionPath: productCol,
      docId: product.id,
      incomingMap: product.toMap(),
    );
    await _db
        .collection(productCol)
        .doc(product.id)
        .set(map, SetOptions(merge: true));
  }

  Future<void> deleteProduct(String id) =>
      _db.collection(productCol).doc(id).delete();

  // ═══════════════════════════════════════════════════════════════
  //  TEMPLATES
  // ═══════════════════════════════════════════════════════════════
  Future<List<InvoiceTemplate>> getTemplates() async {
    final snapshot = await _db.collection('templates').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return InvoiceTemplate.fromMap(data);
    }).toList();
  }

  Future<InvoiceTemplate?> getTemplate(String id) async {
    final doc = await _db.collection('templates').doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return InvoiceTemplate.fromMap(data);
  }

  // ═══════════════════════════════════════════════════════════════
  //  PLANS
  // ═══════════════════════════════════════════════════════════════
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

  Future<void> savePlan(Plan plan) =>
      _db.collection(planCol).doc(plan.id).set(plan.toMap());

  // ═══════════════════════════════════════════════════════════════
  //  SUBSCRIPTIONS
  // ═══════════════════════════════════════════════════════════════
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
    if (uid == null) throw Exception('Non authentifié');
    await _db.collection(subscriptionCol).doc(subscription.id).set({
      ...subscription.toMap(),
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteSubscription(String id) =>
      _db.collection(subscriptionCol).doc(id).delete();

  // ═══════════════════════════════════════════════════════════════
  //  SUPPLIERS
  // ═══════════════════════════════════════════════════════════════
  Future<List<Supplier>> getSuppliers() async {
    final docs = await _getSaaSQueryDocs(supplierCol);
    return docs.map(Supplier.fromMap).toList();
  }

  Future<Supplier?> getSupplier(String id) async {
    final uid = currentUserId;
    if (uid == null) return null;
    final doc = await _db.collection(supplierCol).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    final user = await getUser();
    if (user != null && user.isAdmin) {
      data['id'] = doc.id;
      return Supplier.fromMap(data);
    }
    final ownerId = data['userId'];
    final docCompanyId = data['companyId'];
    final company = await getCompany();
    final sharedList = List<String>.from(data['sharedWithUsers'] ?? []);
    if (ownerId != null &&
        ownerId != uid &&
        !sharedList.contains(uid) &&
        (company == null || docCompanyId != company.id)) {
      return null;
    }
    data['id'] = doc.id;
    return Supplier.fromMap(data);
  }

  Future<void> saveSupplier(Supplier supplier) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifié');
    if (!await canWriteOn(supplierCol, supplier.id)) {
      throw Exception('Vous n\'avez pas le droit de modifier ce fournisseur.');
    }
    final map = await _buildOwnershipFields(
      collectionPath: supplierCol,
      docId: supplier.id,
      incomingMap: supplier.toMap(),
    );
    await _db
        .collection(supplierCol)
        .doc(supplier.id)
        .set(map, SetOptions(merge: true));
  }

  Future<void> deleteSupplier(String id) =>
      _db.collection(supplierCol).doc(id).delete();

  // ═══════════════════════════════════════════════════════════════
  //  REMINDERS
  // ═══════════════════════════════════════════════════════════════
  Future<List<Reminder>> getReminders() async {
    final docs = await _getSaaSQueryDocs(reminderCol);
    return docs.map(Reminder.fromMap).toList();
  }

  Future<void> saveReminder(Reminder reminder) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifié');
    if (!await canWriteOn(reminderCol, reminder.id)) {
      throw Exception('Vous n\'avez pas le droit de modifier ce rappel.');
    }
    final map = await _buildOwnershipFields(
      collectionPath: reminderCol,
      docId: reminder.id,
      incomingMap: reminder.toMap(),
    );
    await _db
        .collection(reminderCol)
        .doc(reminder.id)
        .set(map, SetOptions(merge: true));
  }

  Future<void> deleteReminder(String id) =>
      _db.collection(reminderCol).doc(id).delete();

  // ═══════════════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════
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

  Stream<List<AppNotification>> notificationsStream(String uid) {
    return _db
        .collection(notificationCol)
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return AppNotification.fromMap(data);
            }).toList());
  }

  Future<void> saveNotification(AppNotification notification) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifié');
    await _db.collection(notificationCol).doc(notification.id).set({
      ...notification.toMap(),
      'userId': uid,
      'recipients': [uid],
      'createdBy': uid,
      'createdAt': Timestamp.fromDate(notification.timestamp),
    }, SetOptions(merge: true));
  }

  Future<void> saveNotificationForUser(
    String userId,
    AppNotification notification, {
    String? createdBy,
    String? teamId,
  }) async {
    final uid = currentUserId ?? createdBy ?? '';
    final data = <String, dynamic>{
      ...notification.toMap(),
      'userId': userId,
      'recipients': [userId],
      'createdBy': createdBy ?? uid,
      'createdAt': Timestamp.fromDate(notification.timestamp),
    };
    if (teamId != null && teamId.isNotEmpty) {
      data['teamId'] = teamId;
    }
    await _db
        .collection(notificationCol)
        .doc(notification.id)
        .set(data, SetOptions(merge: true));
  }

  Future<void> deleteNotification(String id) =>
      _db.collection(notificationCol).doc(id).delete();

  Future<void> clearNotifications() async {
    final notifs = await getNotifications();
    for (final n in notifs) {
      await _db.collection(notificationCol).doc(n.id).delete();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  CRUD GÉNÉRIQUE SÉCURISÉ
  // ═══════════════════════════════════════════════════════════════
  Future<List<T>> getAll<T>(String collectionPath) async {
    final uid = currentUserId;
    if (uid == null) return [];

    const publicCollections = [planCol, 'templates', 'settings'];
    if (publicCollections.contains(collectionPath)) {
      final snapshot = await _db.collection(collectionPath).get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return _fromDoc<T>(collectionPath, data);
      }).toList();
    }

    final docs = await _getSaaSQueryDocs(collectionPath);
    return docs.map((d) => _fromDoc<T>(collectionPath, d)).toList();
  }

  Future<void> save<T>(String collectionPath, T item) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Non authentifié');

    final id = (item as dynamic).id as String;
    if (!await canWriteOn(collectionPath, id)) {
      throw Exception('Vous n\'avez pas le droit de modifier ce document.');
    }

    final incomingMap = (item as dynamic).toMap() as Map<String, dynamic>;
    final map = await _buildOwnershipFields(
      collectionPath: collectionPath,
      docId: id,
      incomingMap: incomingMap,
    );

    await _db
        .collection(collectionPath)
        .doc(id)
        .set(map, SetOptions(merge: true));
  }

  Future<void> delete<T>(String collectionPath, String id) =>
      _db.collection(collectionPath).doc(id).delete();

  Future<T?> getById<T>(String collectionPath, String id) async {
    final doc = await _db.collection(collectionPath).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return _fromDoc<T>(collectionPath, data);
  }

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
        throw UnsupportedError('Collection non supportée: $collectionPath');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  NETTOYAGE
  // ═══════════════════════════════════════════════════════════════
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