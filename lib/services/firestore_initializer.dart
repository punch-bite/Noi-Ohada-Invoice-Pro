// lib/services/firestore_initializer.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/invoice_template.dart';
import '../models/plan.dart';

class FirestoreInitializer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> initialize() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('ℹ️ Utilisateur non authentifié, initialisation Firestore ignorée.');
        return;
      }

      final idTokenResult = await user.getIdTokenResult();
      final isAdmin = idTokenResult.claims?['admin'] == true;

      if (!isAdmin) {
        debugPrint('ℹ️ Utilisateur non admin, création des collections par défaut ignorée.');
        return;
      }

      // ⚠️ NE PAS BLOQUER : exécuter en arrière-plan
      _ensurePlans().catchError((e) => debugPrint('⚠️ Erreur plans: $e'));
      _ensureCompany().catchError((e) => debugPrint('⚠️ Erreur company: $e'));
      _ensureSettings().catchError((e) => debugPrint('⚠️ Erreur settings: $e'));
      _ensureTemplates().catchError((e) => debugPrint('⚠️ Erreur templates: $e'));
      _ensureLogsPlaceholder().catchError((e) => debugPrint('⚠️ Erreur logs: $e'));

      debugPrint('✅ Firestore initialisé (non bloquant)');
    } catch (e) {
      debugPrint('⚠️ Erreur initialisation Firestore: $e');
    }
  }

  // ===== PLANS =====
  static Future<void> _ensurePlans() async {
    try {
      final snapshot = await _firestore.collection('plans').limit(1).get();
      if (snapshot.docs.isEmpty) {
        debugPrint('📋 Création des plans par défaut...');
        final plans = Plan.getDefaultPlans();
        final batch = _firestore.batch();
        for (final plan in plans) {
          final ref = _firestore.collection('plans').doc(plan.id);
          batch.set(ref, plan.toMap());
        }
        await batch.commit();
        debugPrint('✅ ${plans.length} plans créés');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur plans (ignorée): $e');
    }
  }

  // ===== COMPANY =====
  static Future<void> _ensureCompany() async {
    try {
      final snapshot = await _firestore.collection('companies').limit(1).get();
      if (snapshot.docs.isEmpty) {
        debugPrint('🏢 Création de l\'entreprise par défaut...');
        await _firestore.collection('companies').doc('default_company').set({
          'id': 'default_company',
          'name': 'OHADA Invoice Pro',
          'address': 'Douala, Cameroun',
          'taxId': 'RC123456789',
          'phone': '+237 6XX XX XX XX',
          'email': 'contact@ohada-invoice-pro.com',
          'logoPath': '',
          'currency': 'XAF',
          'defaultTaxRate': 18.0,
          'legalText': 'Conforme aux normes OHADA et SYSCOHADA',
          'website': 'https://ohada-invoice-pro.com',
          'rccm': 'RC/DLA/2023/1234',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Entreprise par défaut créée');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur entreprise (ignorée): $e');
    }
  }

  // ===== SETTINGS =====
  static Future<void> _ensureSettings() async {
    try {
      final snapshot = await _firestore.collection('settings').limit(1).get();
      if (snapshot.docs.isEmpty) {
        debugPrint('⚙️ Création des paramètres globaux...');
        await _firestore.collection('settings').doc('global').set({
          'id': 'global',
          'appName': 'OHADA Invoice Pro',
          'version': '1.0.0',
          'maintenanceMode': false,
          'contactEmail': 'support@ohada-invoice-pro.com',
          'contactPhone': '+237 6XX XX XX XX',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Paramètres globaux créés');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur settings (ignorée): $e');
    }
  }

  // ===== TEMPLATES =====
  /// 📄 Stocke TOUS les modèles prédéfinis « Royal Ledger » dans Firestore
  /// pour qu'ils soient lisibles par l'app ET modifiables par l'admin
  /// (`/admin/templates`).
  ///
  /// Stratégie d'upsert (elle ne fige pas les modifications de l'admin) :
  ///   • collection vide → création de TOUS les modèles par défaut ;
  ///   • modèle `default_*` absent → création ;
  ///   • modèle présent avec `designVersion < kRoyalDesignVersion`
  ///     → MISE À JOUR vers le nouveau design (v2) ;
  ///   • modèle présent avec `designVersion >= 2` → on n'y touche pas
  ///     (l'admin l'a peut-être personnalisé depuis la boutique).
  static Future<void> _ensureTemplates() async {
    try {
      final defaults = InvoiceTemplate.getDefaultTemplates();
      if (defaults.isEmpty) return;

      final snapshot = await _firestore.collection('templates').get();
      final existing = <String, Map<String, dynamic>>{
        for (final doc in snapshot.docs) doc.id: doc.data(),
      };

      final batch = _firestore.batch();
      var pending = 0;

      for (final template in defaults) {
        final ref = _firestore.collection('templates').doc(template.id);
        final current = existing[template.id];

        // Création (absent) OU mise à jour vers le nouveau design.
        final int currentVersion =
            (current?['designVersion'] as num?)?.toInt() ?? 1;
        final needsUpdate = current == null ||
            currentVersion < InvoiceTemplate.kRoyalDesignVersion;

        if (needsUpdate) {
          final map = template.toMap()
            ..['createdAt'] = current?['createdAt'] ??
                FieldValue.serverTimestamp()
            ..['updatedAt'] = FieldValue.serverTimestamp();
          batch.set(ref, map, SetOptions(merge: true));
          pending++;
        }
      }

      if (pending > 0) {
        await batch.commit();
        debugPrint('✅ $pending modèle(s) par défaut stocké(s) en base (design v2)');
      } else {
        debugPrint('✅ Les ${defaults.length} modèles par défaut sont à jour');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur templates (ignorée): $e');
    }
  }

  // ===== LOGS PLACEHOLDER =====
  static Future<void> _ensureLogsPlaceholder() async {
    try {
      final snapshot = await _firestore.collection('logs').limit(1).get();
      if (snapshot.docs.isEmpty) {
        debugPrint('📝 Création d\'un placeholder pour les logs...');
        await _firestore.collection('logs').doc('_placeholder').set({
          'message': 'Logs initialisés',
          'timestamp': FieldValue.serverTimestamp(),
        });
        await _firestore.collection('logs').doc('_placeholder').delete();
        debugPrint('✅ Logs prêts');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur logs (ignorée): $e');
    }
  }
}