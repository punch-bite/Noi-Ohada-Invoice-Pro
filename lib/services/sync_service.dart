// lib/services/sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/invoice.dart';
import '../models/client.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../services/logger_service.dart';
import 'cloud_access_service.dart'; // ⬅️ Nouvel import

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();
  final CloudAccessService _cloudAccess = CloudAccessService(); // ⬅️ Instance

  // Configuration des collections à synchroniser
  static final List<SyncCollection> _collections = [
    SyncCollection(
      name: 'invoices',
      localGetter: (db) => db.getInvoices(),
      localAdder: (db, data) => db.addInvoice(data as Invoice),
      localUpdater: (db, data) => db.updateInvoice(data as Invoice),
      fromFirestore: (data, id) => Invoice.fromMap(data, documentId: id),
      toFirestore: (data) => (data as Invoice).toMap(),
    ),
    SyncCollection(
      name: 'clients',
      localGetter: (db) => db.getClients(),
      localAdder: (db, data) => db.addClient(data as Client),
      localUpdater: (db, data) => db.updateClient(data as Client),
      fromFirestore: (data, id) => Client.fromMap(data, documentId: id),
      toFirestore: (data) => (data as Client).toMap(),
    ),
    SyncCollection(
      name: 'products',
      localGetter: (db) => db.getProducts(),
      localAdder: (db, data) => db.saveProduct(data as Product),
      localUpdater: (db, data) => db.saveProduct(data as Product),
      fromFirestore: (data, id) => Product.fromMap(data, documentId: id),
      toFirestore: (data) => (data as Product).toMap(),
    ),
  ];

  /// Synchronise toutes les collections configurées
  Future<void> syncAll() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      await LoggerService.warning('sync_all_failed', details: 'Utilisateur non authentifié');
      return;
    }

    // 🔐 Vérifier l'accès cloud avant toute synchronisation
    if (!await _cloudAccess.hasAccess()) {
      await LoggerService.warning('sync_all_blocked', details: 'Abonnement Pro requis pour la synchronisation cloud');
      throw Exception('Abonnement Pro requis pour la synchronisation cloud');
    }

    for (final config in _collections) {
      await _syncCollection(userId, config);
    }

    await LoggerService.info('sync_all_completed', details: 'Toutes les collections synchronisées');
  }

  /// Synchronise une collection spécifique
  Future<void> _syncCollection(String userId, SyncCollection config) async {
    try {
      final localItems = await config.localGetter(_db);
      final cloudSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(config.name)
          .get();

      final cloudItems = cloudSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return config.fromFirestore(data, doc.id);
      }).toList();

      // Mappes pour recherche rapide
      final localMap = {for (var item in localItems) _getId(item): item};
      final cloudMap = {for (var item in cloudItems) _getId(item): item};

      // 1. Upload vers Cloud (Local plus récent ou absent)
      int uploadCount = 0;
      for (var local in localItems) {
        final id = _getId(local);
        final cloud = cloudMap[id];
        if (cloud == null || _getUpdatedAt(local).isAfter(_getUpdatedAt(cloud))) {
          final data = config.toFirestore(local);
          await _firestore
              .collection('users')
              .doc(userId)
              .collection(config.name)
              .doc(id)
              .set({
            ...data,
            'userId': userId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          uploadCount++;
        }
      }

      // 2. Download vers Local (Cloud plus récent ou absent)
      int downloadCount = 0;
      for (var cloud in cloudItems) {
        final id = _getId(cloud);
        final local = localMap[id];
        if (local == null) {
          await config.localAdder(_db, cloud);
          downloadCount++;
        } else if (_getUpdatedAt(cloud).isAfter(_getUpdatedAt(local))) {
          await config.localUpdater(_db, cloud);
          downloadCount++;
        }
      }

      if (uploadCount > 0 || downloadCount > 0) {
        await LoggerService.info(
          'sync_collection_completed',
          details: '${config.name} : $uploadCount uploads, $downloadCount downloads',
        );
      }
    } catch (e) {
      await LoggerService.error(
        'sync_collection_failed',
        details: '${config.name} : $e',
      );
      rethrow;
    }
  }

  /// Synchronise les factures uniquement (méthode héritée pour compatibilité)
  Future<void> syncInvoices() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // 🔐 Vérifier l'accès cloud
    if (!await _cloudAccess.hasAccess()) {
      await LoggerService.warning('sync_invoices_blocked', details: 'Abonnement Pro requis');
      throw Exception('Abonnement Pro requis pour la synchronisation cloud');
    }

    final config = _collections.firstWhere((c) => c.name == 'invoices');
    await _syncCollection(userId, config);
  }

  // ===== UTILITAIRES =====

  /// Extrait l'ID d'un objet (suppose que l'objet a un champ `id`)
  String _getId(dynamic item) {
    // Tous nos modèles ont un champ 'id'
    return (item as dynamic).id as String;
  }

  /// Extrait la date de mise à jour d'un objet
  DateTime _getUpdatedAt(dynamic item) {
    // Tous nos modèles ont un champ 'updatedAt' ou 'createdAt'
    final obj = item as dynamic;
    return obj.updatedAt ?? obj.createdAt ?? DateTime.now();
  }
}

/// Configuration pour une collection à synchroniser
class SyncCollection {
  final String name;
  final Future<List<dynamic>> Function(DatabaseService) localGetter;
  final Future<void> Function(DatabaseService, dynamic) localAdder;
  final Future<void> Function(DatabaseService, dynamic) localUpdater;
  final dynamic Function(Map<String, dynamic>, String) fromFirestore;
  final Map<String, dynamic> Function(dynamic) toFirestore;

  const SyncCollection({
    required this.name,
    required this.localGetter,
    required this.localAdder,
    required this.localUpdater,
    required this.fromFirestore,
    required this.toFirestore,
  });
}