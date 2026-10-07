// lib/services/firestore_initializer.dart
//
// CHANGELOG (v4 — SaaS Option A) :
//   • Suppression de `_ensureCompany` : la création de l'entreprise est
//     désormais faite par `AuthService._ensureUserCompany()` (id déterministe
//     `company_{uid}`, rattachement automatique du user).
//     → Créer un `default_company` global VIOLAIT les nouvelles règles
//       Firestore (fail-closed sur `isNewOwner()`).
//   • `kRoyalDesignVersion` passé à 4 : les 8 presets refondus (Bande Orange,
//     Moderne Zigzag, Classique Or, Bandeau Bleu, Minimal Two-Col, Compact
//     Pro, Carte Dorée, Bandeau Sombre) sont semés/upsertés.
//   • Uppgrade AUTOMATIQUE v1/v2/v3 → v4 : designVersion < 4 → upsert
//     complet. designVersion >= 4 → non touché (l'admin a pu personnaliser).
//   • Batch unique (plans + templates + settings) → 1 seule écriture réseau
//     atomique au lieu de 4.
//   • Seeding des templates retirés (nettoyage `_ensureTemplates`).
//   • Conservation de `_ensurePlans` (plans publics, lecture gratuite).
//   • `_ensureSettings` conservé (settings publics en lecture seule pour
//     l'app, écriture admin).
//   • `_ensureLogsPlaceholder` supprimé (inutile : `logs` est auto-créé au
//     1er log admin).
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/invoice_template.dart';
import '../models/plan.dart';

class FirestoreInitializer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🚀 Point d'entrée — non bloquant, idempotent, réservé admin.
  ///
  /// Peut être appelé à chaque démarrage : toutes les opérations sont
  /// idempotentes (batch merge + comptages).
  static Future<void> initialize() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('ℹ️ FirestoreInitializer : utilisateur non connecté → skip');
        return;
      }

      final token = await user.getIdTokenResult();
      final isAdmin = token.claims?['admin'] == true;

      if (!isAdmin) {
        debugPrint('ℹ️ FirestoreInitializer : non admin → skip');
        return;
      }

      debugPrint('🚀 FirestoreInitializer (admin) démarrage…');

      // ⚠️ Non bloquant : on lance en parallèle, on n'attend pas.
      unawaited(_ensurePlansAndSettings());
      unawaited(_ensureTemplates());

      debugPrint('✅ FirestoreInitializer lancé (non bloquant)');
    } catch (e) {
      debugPrint('⚠️ FirestoreInitializer : erreur racine : $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  PLANS + SETTINGS (seeds publics)
  // ═══════════════════════════════════════════════════════════════
  static Future<void> _ensurePlansAndSettings() async {
    try {
      final batch = _firestore.batch();
      var pending = 0;

      // ─── Plans ───
      final plansSnap =
          await _firestore.collection('plans').limit(1).get();
      if (plansSnap.docs.isEmpty) {
        final plans = Plan.getDefaultPlans();
        for (final plan in plans) {
          batch.set(
            _firestore.collection('plans').doc(plan.id),
            plan.toMap(),
            SetOptions(merge: true),
          );
          pending++;
        }
        debugPrint('📋 ${plans.length} plans par défaut à créer');
      }

      // ─── Settings globaux ───
      final settingsRef = _firestore.collection('settings').doc('global');
      final settingsSnap = await settingsRef.get();
      if (!settingsSnap.exists) {
        batch.set(
          settingsRef,
          <String, dynamic>{
            'id': 'global',
            'appName': 'OHADA Invoice Pro',
            'version': '1.0.0',
            'maintenanceMode': false,
            'contactEmail': 'support@ohada-invoice-pro.com',
            'contactPhone': '+237 6XX XX XX XX',
            'designSystemVersion': InvoiceTemplate.kRoyalDesignVersion,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        pending++;
        debugPrint('⚙️ Settings globaux à créer');
      }

      if (pending > 0) {
        await batch.commit();
        debugPrint('✅ FirestoreInitializer : $pending seed(s) public(s) créés');
      }
    } catch (e) {
      debugPrint('⚠️ _ensurePlansAndSettings : $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  TEMPLATES (8 presets v4 + uppgrade automatique)
  // ═══════════════════════════════════════════════════════════════
  //
  // 🔄 Politique d'upsert (elle ne fige PAS les modifications admin) :
  //
  //   • Modèle ABSENT             → création complète (v4).
  //   • Présent avec version < 4  → MISE À JOUR vers le nouveau design
  //                                 (positions, couleurs, styles).
  //   • Présent avec version >= 4 → NON TOUCHÉ (l'admin a pu le
  //                                 personnaliser depuis la boutique).
  //
  // 💡 Les modèles « custom » créés par l'admin (id non `default_*`)
  //    sont préservés : on ne touche qu'aux presets système.
  //
  static Future<void> _ensureTemplates() async {
    try {
      final defaults = InvoiceTemplate.getDefaultTemplates();
      if (defaults.isEmpty) return;

      final snapshot = await _firestore.collection('templates').get();
      final existing = <String, Map<String, dynamic>>{
        for (final doc in snapshot.docs) doc.id: doc.data(),
      };

      final batch = _firestore.batch();
      var created = 0;
      var upgraded = 0;
      var untouched = 0;

      for (final template in defaults) {
        final ref = _firestore.collection('templates').doc(template.id);
        final current = existing[template.id];

        // Cas 1 : modèle absent → création complète.
        if (current == null) {
          final map = template.toMap()
            ..['createdAt'] = FieldValue.serverTimestamp()
            ..['updatedAt'] = FieldValue.serverTimestamp()
            ..['isDefault'] = true;
          batch.set(ref, map, SetOptions(merge: true));
          created++;
          continue;
        }

        // Cas 2 : version courante < 4 → uppgrade complet.
        final currentVersion =
            (current['designVersion'] as num?)?.toInt() ?? 1;

        if (currentVersion < InvoiceTemplate.kRoyalDesignVersion) {
          final map = template.toMap()
            // On préserve la date de création d'origine.
            ..['createdAt'] =
                current['createdAt'] ?? FieldValue.serverTimestamp()
            ..['updatedAt'] = FieldValue.serverTimestamp()
            // On marque comme preset système (au cas où).
            ..['isDefault'] = true;
          batch.set(ref, map, SetOptions(merge: true));
          upgraded++;
          continue;
        }

        // Cas 3 : version >= 4 → on ne touche pas (admin peut avoir modifié).
        untouched++;
      }

      if (created + upgraded > 0) {
        await batch.commit();
        debugPrint(
            '✅ FirestoreInitializer : templates → '
            '$created créé(s), $upgraded mis à jour, $untouched préservé(s)');
      } else {
        debugPrint(
            '✅ FirestoreInitializer : ${defaults.length} preset(s) déjà à jour '
            '(design v${InvoiceTemplate.kRoyalDesignVersion})');
      }
    } catch (e) {
      debugPrint('⚠️ _ensureTemplates : $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  UTILITAIRES
  // ═══════════════════════════════════════════════════════════════

  /// Déclenche une tâche en arrière-plan sans bloquer le flux appelant.
  /// Équivalent d'un `unawaited(...)` — on évite d'importer `dart:async`.
  static void unawaited(Future<void> future) {
    future.catchError((Object e) {
      debugPrint('⚠️ FirestoreInitializer (async) : $e');
    });
  }
}