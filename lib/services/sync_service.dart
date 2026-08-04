// lib/services/sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/cloud_access_service.dart';
import '../models/client.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/invoice.dart';
import '../models/company.dart';

class SyncService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();
  final CloudAccessService _cloudAccess = CloudAccessService();

  // 🔥 Map des constructeurs fromMap par collection
  final Map<String, dynamic Function(Map<String, dynamic>)> _fromMapMap = {
    'clients': (data) => Client.fromMap(data, documentId: data['id']),
    'products': (data) => Product.fromMap(data, documentId: data['id']),
    'suppliers': (data) => Supplier.fromMap(data, documentId: data['id']),
    'invoices': (data) => Invoice.fromMap(data, documentId: data['id']),
  };

  Future<void> syncAll() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint('⚠️ SyncService: utilisateur non authentifié');
      return;
    }

    if (!await _cloudAccess.hasAccess()) {
      debugPrint('ℹ️ SyncService: accès cloud non disponible');
      return;
    }

    debugPrint('🔄 SyncService: synchronisation en cours...');

    await Future.wait([
      _syncCollection('clients'),
      _syncCollection('products'),
      _syncCollection('suppliers'),
      _syncCollection('invoices'),
      _syncCompany(),
    ]);

    debugPrint('✅ SyncService: synchronisation terminée');
  }

    Future<void> _syncCollection(String collectionName) async {
    final userId = _auth.currentUser!.uid;

    // Récupération des données locales
    final localItems = await _db.getAll<dynamic>(collectionName);
    final localMap = {for (var item in localItems) _getId(item): item};

    // Récupération des données cloud depuis les collections racine
    final cloudSnapshot = await _firestore
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .get();

    final cloudItems = cloudSnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      // ✅ Utilisation du mapper
      return _fromMapMap[collectionName]!(data);
    }).toList();

    final cloudMap = {for (var item in cloudItems) _getId(item): item};

    // Upload
    for (var local in localItems) {
      final id = _getId(local);
      if (!cloudMap.containsKey(id)) {
        await _firestore
            .collection(collectionName)
            .doc(id)
            .set({
              ..._toMap(local),
              'userId': userId,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    }

    // Download
    for (var cloud in cloudItems) {
      final id = _getId(cloud);
      if (!localMap.containsKey(id)) {
        await _db.save<dynamic>(collectionName, cloud);
      }
    }
  }

  Future<void> _syncCompany() async {
    final userId = _auth.currentUser!.uid;
    final localCompany = await _db.getCompany();
    final cloudSnapshot = await _firestore
        .collection('companies')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (cloudSnapshot.docs.isEmpty && localCompany != null) {
      await _firestore.collection('companies').add({
        ...localCompany.toMap(),
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (cloudSnapshot.docs.isNotEmpty && localCompany == null) {
      final data = cloudSnapshot.docs.first.data();
      data['id'] = cloudSnapshot.docs.first.id;
      final company = Company.fromMap(data);
      await _db.saveCompany(company);
    }
  }

  String _getId(dynamic item) => (item as dynamic).id as String;

  Map<String, dynamic> _toMap(dynamic item) {
    return (item as dynamic).toMap();
  }
}