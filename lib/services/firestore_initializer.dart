// lib/services/firestore_initializer.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/plan.dart';

class FirestoreInitializer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialise Firestore UNIQUEMENT si l'utilisateur est authentifié et admin.
  /// Sinon, ignore silencieusement les erreurs de permission.
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

      // Seul un admin peut créer/modifier les données globales
      await _ensurePlans();
      await _ensureCompany();
      await _ensureSettings();
      await _ensureTemplates();
      await _ensureLogsPlaceholder();

      debugPrint('✅ Firestore initialisé avec succès');
    } catch (e) {
      // Ignorer les erreurs de permission (l'application fonctionne en mode local)
      if (e.toString().contains('permission-denied')) {
        debugPrint('⚠️ Permission Firestore refusée (mode hors ligne/local).');
      } else {
        debugPrint('❌ Erreur initialisation Firestore: $e');
      }
      // Ne pas relancer l'exception pour ne pas bloquer le démarrage
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
  static Future<void> _ensureTemplates() async {
    try {
      final snapshot = await _firestore.collection('templates').limit(1).get();
      if (snapshot.docs.isEmpty) {
        debugPrint('📄 Création du modèle par défaut...');
        await _firestore.collection('templates').doc('default_1').set({
          'id': 'default_1',
          'name': 'Classique',
          'description': 'Modèle épuré et professionnel',
          'primaryColor': 0xFF1A237E,
          'textColor': 0xFF000000,
          'backgroundColor': 0xFFFFFFFF,
          'showLogo': true,
          'showTaxDetails': true,
          'showPaymentTerms': true,
          'showPaymentQR': false,
          'isPremium': false,
          'isDefault': true,
          'fontFamily': 'Roboto',
          'fontSize': 12.0,
          'showBorder': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Modèle par défaut créé');
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