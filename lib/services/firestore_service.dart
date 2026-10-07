// lib/services/firestore_service.dart
//
// CHANGELOG (SaaS) :
//   • `getInvoicesStream()` : fusion de 3 flux (owner / sharedWithUsers /
//     companyId) → un membre d'équipe voit enfin les factures partagées en
//     temps réel, pas seulement celles qu'il a créées.
//   • `saveInvoice` : rattache automatiquement `companyId` (via DatabaseService).
//   • `syncLocalToCloud` : conserve la logique de batch, mais injecte companyId.
//
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/plan.dart';
import '../models/user.dart';
import '../models/invoice.dart';
import '../models/subscription.dart';
import '../services/database_service.dart';
import 'cloud_access_service.dart';
import 'logger_service.dart';

class FirestoreService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CloudAccessService _cloudAccess = CloudAccessService();

  String? get currentUserId => _auth.currentUser?.uid;
  bool get isAuthenticated => _auth.currentUser != null;

  // ═══════════════════════════════════════════════════════════════════
  // USERS
  // ═══════════════════════════════════════════════════════════════════
  Future<void> saveUser(Map<String, dynamic> userData) async {
    if (!isAuthenticated) throw Exception('Non authentifié');

    if (!await _cloudAccess.hasAccess()) {
      await DatabaseService().saveUser(AppUser.fromMap(userData));
      return;
    }

    await _db.collection('users').doc(currentUserId).set(
      {...userData, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    await LoggerService.info('save_user',
        details: 'Utilisateur sauvegardé dans le cloud');
  }

  // ═══════════════════════════════════════════════════════════════════
  // INVOICES — STREAM SaaS
  // ═══════════════════════════════════════════════════════════════════
  /// 📡 Stream temps réel des factures de l'utilisateur.
  ///
  /// Fusion de 3 flux :
  ///   1. Factures créées par l'utilisateur (`userId == uid`) ;
  ///   2. Factures partagées nominativement (`sharedWithUsers contains uid`) ;
  ///   3. Factures de SON ENTREPRISE (`companyId == user.companyId`).
  ///
  /// Les trois flux sont dédoublonnés par id, puis triés par `updatedAt desc`.
  Stream<List<Invoice>> getInvoicesStream() {
    if (!isAuthenticated) return Stream.value([]);

    final uid = currentUserId!;
    final controller = StreamController<List<Invoice>>();
    final buffers = <String, Map<String, Invoice>>{
      'owner': {},
      'shared': {},
      'company': {},
    };
    final subs = <StreamSubscription<QuerySnapshot>>[];

    void emit() {
      final seen = <String, Invoice>{};
      for (final b in buffers.values) {
        seen.addAll(b);
      }
      final list = seen.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (!controller.isClosed) controller.add(list);
    }

    Future<void> attach() async {
      // 1) Owner
      subs.add(_db
          .collection('invoices')
          .where('userId', isEqualTo: uid)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .listen((snap) {
        buffers['owner'] = {
          for (final d in snap.docs)
            d.id: Invoice.fromMap({...d.data(), 'id': d.id})
        };
        emit();
      }, onError: (e) => debugPrint('❌ invoices.owner stream: $e')));

      // 2) Shared
      subs.add(_db
          .collection('invoices')
          .where('sharedWithUsers', arrayContains: uid)
          .snapshots()
          .listen((snap) {
        buffers['shared'] = {
          for (final d in snap.docs)
            d.id: Invoice.fromMap({...d.data(), 'id': d.id})
        };
        emit();
      }, onError: (e) => debugPrint('❌ invoices.shared stream: $e')));

      // 3) Company
      final company = await DatabaseService().getCompany();
      if (company != null && company.id.isNotEmpty) {
        subs.add(_db
            .collection('invoices')
            .where('companyId', isEqualTo: company.id)
            .snapshots()
            .listen((snap) {
          buffers['company'] = {
            for (final d in snap.docs)
              d.id: Invoice.fromMap({...d.data(), 'id': d.id})
          };
          emit();
        }, onError: (e) => debugPrint('❌ invoices.company stream: $e')));
      }
    }

    attach();

    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
      await controller.close();
    };

    return controller.stream;
  }

  Future<void> saveInvoice(Invoice invoice) async {
    if (!isAuthenticated) throw Exception('Non authentifié');

    if (!await _cloudAccess.hasAccess()) {
      await DatabaseService().addInvoice(invoice);
      await LoggerService.info('save_invoice_local',
          details: 'Facture ${invoice.invoiceNumber} sauvegardée en local');
      return;
    }

    final companyId = invoice.companyId.isNotEmpty
        ? invoice.companyId
        : (await DatabaseService().getCompany())?.id;

    await _db.collection('invoices').doc(invoice.id).set({
      ...invoice.toMap(),
      'userId': currentUserId,
      if (companyId != null && companyId.isNotEmpty) 'companyId': companyId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await LoggerService.info('save_invoice',
        details: 'Facture ${invoice.invoiceNumber} sauvegardée dans le cloud');
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  // SYNCHRONISATION
  // ═══════════════════════════════════════════════════════════════════
  Future<void> syncLocalToCloud() async {
    if (!isAuthenticated) throw Exception('Non authentifié');

    if (!await _cloudAccess.hasAccess()) {
      throw Exception('Abonnement Pro requis pour la synchronisation cloud');
    }

    try {
      final localInvoices = await DatabaseService().getInvoices();
      if (localInvoices.isEmpty) {
        debugPrint('📭 Aucune facture locale à synchroniser');
        return;
      }

      final companyId = (await DatabaseService().getCompany())?.id;

      for (var i = 0; i < localInvoices.length; i += 500) {
        final chunk = localInvoices.skip(i).take(500);
        final batch = _db.batch();

        for (final invoice in chunk) {
          final ref = _db.collection('invoices').doc(invoice.id);
          batch.set(ref, {
            ...invoice.toMap(),
            'userId': currentUserId,
            if (companyId != null && companyId.isNotEmpty)
              'companyId': companyId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        await batch.commit();
      }

      debugPrint(
          '✅ Synchronisation de ${localInvoices.length} factures terminée');
      await LoggerService.info('sync_local_to_cloud',
          details: '${localInvoices.length} factures synchronisées');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur de synchronisation: $e');
      await LoggerService.error('sync_local_to_cloud_failed',
          details: e.toString());
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ABONNEMENTS
  // ═══════════════════════════════════════════════════════════════════
  Future<Subscription?> getActiveSubscription() async {
    if (!isAuthenticated) return null;

    if (!await _cloudAccess.hasAccess()) {
      return null;
    }

    final query = await _db
        .collection('subscriptions')
        .where('userId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final data = query.docs.first.data();
    data['id'] = query.docs.first.id;
    return Subscription.fromMap(data);
  }

  Future<void> saveSubscription(Subscription subscription) async {
    if (!isAuthenticated) throw Exception('Non authentifié');

    if (!await _cloudAccess.hasAccess()) {
      await DatabaseService().saveSubscription(subscription);
      await LoggerService.info('save_subscription_local',
          details: 'Abonnement sauvegardé en local');
      return;
    }

    try {
      await _db.collection('subscriptions').doc(subscription.id).set({
        ...subscription.toMap(),
        'userId': currentUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await LoggerService.info('save_subscription',
          details: 'Abonnement sauvegardé dans le cloud');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde souscription: $e');
      await LoggerService.error('save_subscription_failed',
          details: e.toString());
      rethrow;
    }
  }

  Stream<Subscription?> watchActiveSubscription() {
    if (!isAuthenticated) return Stream.value(null);

    return _db
        .collection('subscriptions')
        .where('userId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final data = snapshot.docs.first.data();
          data['id'] = snapshot.docs.first.id;
          return Subscription.fromMap(data);
        });
  }

  // ═══════════════════════════════════════════════════════════════════
  // PLANS
  // ═══════════════════════════════════════════════════════════════════
  Future<List<Plan>> getPublicPlans() async {
    try {
      final snapshot = await _db.collection('plans').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Plan.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint("❌ Erreur chargement des plans: $e");
      await LoggerService.error('get_public_plans_failed',
          details: e.toString());
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // UTILITAIRES
  // ═══════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> getDocument(
      String collectionPath, String docId) async {
    if (await _cloudAccess.hasAccess()) {
      try {
        final doc = await _db.collection(collectionPath).doc(docId).get();
        return doc.exists ? doc.data() : null;
      } catch (e) {
        debugPrint('❌ Erreur getDocument: $e');
        return null;
      }
    }
    return null;
  }

  Future<void> updateDocument(
      String collectionPath, String docId, Map<String, dynamic> data) async {
    if (!isAuthenticated) throw Exception('Non authentifié');

    if (!await _cloudAccess.hasAccess()) {
      await LoggerService.info('update_document_local',
          details: 'Document $docId mis à jour en local');
      return;
    }

    await _db.collection(collectionPath).doc(docId).update(data);
    await LoggerService.info('update_document',
        details: 'Document $docId mis à jour dans le cloud');
  }

  Future<void> deleteDocument(String collectionPath, String docId) async {
    if (!isAuthenticated) throw Exception('Non authentifié');

    if (!await _cloudAccess.hasAccess()) {
      await LoggerService.info('delete_document_local',
          details: 'Document $docId supprimé en local');
      return;
    }

    await _db.collection(collectionPath).doc(docId).delete();
    await LoggerService.info('delete_document',
        details: 'Document $docId supprimé du cloud');
  }
}