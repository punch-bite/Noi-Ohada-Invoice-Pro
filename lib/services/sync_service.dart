// lib/services/sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/database_service.dart';
import '../services/cloud_access_service.dart';
import '../models/client.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/invoice.dart';
import '../models/company.dart';
import '../models/invoice_settings.dart';
import 'settings_service.dart';

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
      _syncSettings(),
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

  /// 🔄 Synchronise les paramètres de facture (`InvoiceSettings`) entre Hive
  /// (offline-first) et Firestore (`users/{uid}/invoice_settings/default`).
  Future<void> _syncSettings() async {
    final userId = _auth.currentUser!.uid;
    if (!await _cloudAccess.hasAccess()) return;

    final settingsService = SettingsService.instance;

    // Lecture locale (Hive)
    InvoiceSettings? localSettings;
    try {
      if (Hive.isBoxOpen('invoice_settings')) {
        localSettings =
            Hive.box<InvoiceSettings>('invoice_settings').get('default');
      }
    } catch (e) {
      debugPrint('⚠️ SyncSettings: lecture Hive échouée: $e');
    }
    if (localSettings == null) return; // rien à synchroniser

    // Lecture cloud
    final cloudDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('invoice_settings')
        .doc('default')
        .get();

    if (!cloudDoc.exists) {
      // Cloud vide → on pousse la version locale.
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('invoice_settings')
          .doc('default')
          .set({...localSettings.toFirestore(), 'updatedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
      return;
    }

    // Conflit : on compare les timestamps (local n'a pas de timestamp fiable
    // côté Hive, on utilise la stratégie « cloud lance » → on ramène le cloud
    // si présent et on le met à jour avec les éventuelles clés manquantes).
    final cloudData = cloudDoc.data()!;
    final cloudSettings = InvoiceSettings.fromFirestore(cloudData);
    final merged = _mergeSettings(localSettings, cloudSettings);
    await settingsService.saveSettings(merged);
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('invoice_settings')
        .doc('default')
        .set({...merged.toFirestore(), 'updatedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
  }

  /// Fusionne les settings locaux et cloud en conservant les valeurs locales
  /// non-null et en complétant avec le cloud pour les champs "par défaut".
  InvoiceSettings _mergeSettings(InvoiceSettings local, InvoiceSettings cloud) {
    return InvoiceSettings(
      showLogo: local.showLogo,
      showBorder: local.showBorder,
      showWatermark: local.showWatermark,
      showPaymentQR: local.showPaymentQR,
      primaryColor: local.primaryColorValue != InvoiceSettings.defaultSettings.primaryColorValue
          ? local.primaryColor
          : cloud.primaryColor,
      secondaryColor: local.secondaryColorValue != InvoiceSettings.defaultSettings.secondaryColorValue
          ? local.secondaryColor
          : cloud.secondaryColor,
      backgroundColor: local.backgroundColorValue != InvoiceSettings.defaultSettings.backgroundColorValue
          ? local.backgroundColor
          : cloud.backgroundColor,
      textColor: local.textColorValue != InvoiceSettings.defaultSettings.textColorValue
          ? local.textColor
          : cloud.textColor,
      fontFamily: local.fontFamily.isEmpty ? cloud.fontFamily : local.fontFamily,
      fontSize: local.fontSize == InvoiceSettings.defaultSettings.fontSize
          ? cloud.fontSize
          : local.fontSize,
      showCompanyInfo: local.showCompanyInfo,
      showClientInfo: local.showClientInfo,
      showPaymentTerms: local.showPaymentTerms,
      showTaxDetails: local.showTaxDetails,
      watermarkText: local.watermarkText != InvoiceSettings.defaultSettings.watermarkText
          ? local.watermarkText
          : cloud.watermarkText,
    );
  }


  String _getId(dynamic item) => (item as dynamic).id as String;

  Map<String, dynamic> _toMap(dynamic item) {
    return (item as dynamic).toMap();
  }
}