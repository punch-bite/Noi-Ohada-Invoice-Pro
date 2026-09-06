// lib/services/settings_service.dart
//
// 📦 Service unifié de persistance des `InvoiceSettings`
// (filigrane, couleurs, police, marges, affichage, etc.).
//
// Source de vérité OFFLINE : Hive (box `invoice_settings`, clé `'default'`).
// Source de vérité CLOUD    : Firestore (`users/{uid}/invoice_settings/default`).
//
// Stratégie :
//   - Lecture  : Hive → si vide, Firestore → si vide, `InvoiceSettings.defaultSettings`.
//   - Écriture : Hive toujours (offline-first) ; Firestore en parallèle si l'accès
//                cloud est disponible (best-effort, non bloquant).
//
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/invoice_settings.dart';
import 'cloud_access_service.dart';

class SettingsService {
  /// Instance partagée (injectable dans les providers si besoin).
  static final SettingsService instance = SettingsService._internal();
  SettingsService._internal();

  static const String _boxName = 'invoice_settings';
  static const String _hiveKey = 'default';
  static const String _collection = 'invoice_settings';

  // ⚠️ Getters PARESSEUX : ne JAMAIS toucher à Firebase dans le constructeur
  // (sinon tout accès au service plante si Firebase.initializeApp() n'a pas
  // encore été appelé — tests, cold start, mode dégradé).
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  // Paresseux aussi : CloudAccessService instancie Firestore dans ses champs.
  CloudAccessService get _cloudAccess => CloudAccessService();

  // ── Lecture locale (Hive) ─────────────────────────────────────────────

  /// Charge les settings depuis Hive, ou `null` s'absents.
  ///
  /// ⚠️ N'ouvre JAMAIS la box ici : c'est `HiveService.init()` qui possède le
  /// cycle de vie des boxes. Si la box n'est pas ouverte (tests, boot), on
  /// se dégrade silencieusement vers null → cloud → défauts.
  Future<InvoiceSettings?> _loadFromHive() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) return null;
      final box = Hive.box<InvoiceSettings>(_boxName);
      return box.get(_hiveKey);
    } catch (e) {
      debugPrint('⚠️ SettingsService: lecture Hive échouée: $e');
      return null;
    }
  }

  /// Sauvegarde les settings dans Hive (offline-first).
  /// Silencieux si la box n'est pas ouverte (voir [_loadFromHive]).
  Future<void> _saveToHive(InvoiceSettings settings) async {
    try {
      if (!Hive.isBoxOpen(_boxName)) return;
      final box = Hive.box<InvoiceSettings>(_boxName);
      await box.put(_hiveKey, settings);
    } catch (e) {
      debugPrint('⚠️ SettingsService: écriture Hive échouée: $e');
    }
  }

  // ── Lecture cloud (Firestore) ─────────────────────────────────────────

  /// Charge les settings depuis Firestore, ou `null` si absents / pas d'accès.
  Future<InvoiceSettings?> _loadFromFirestore() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;
      if (!await _cloudAccess.hasAccess()) return null;
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection(_collection)
          .doc(_hiveKey)
          .get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['id'] = doc.id;
      return InvoiceSettings.fromFirestore(data);
    } catch (e) {
      debugPrint('⚠️ SettingsService: lecture Firestore échouée: $e');
      return null;
    }
  }

  /// Sauvegarde les settings dans Firestore (best-effort).
  Future<void> _saveToFirestore(InvoiceSettings settings) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      if (!await _cloudAccess.hasAccess()) return;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection(_collection)
          .doc(_hiveKey)
          .set({
        ...settings.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ SettingsService: écriture Firestore échouée: $e');
    }
  }

  // ── API publique ──────────────────────────────────────────────────────

  /// Charge les settings avec fallback local → cloud → défaut.
  Future<InvoiceSettings> loadSettings() async {
    // 1️⃣ Locale (offline-first)
    InvoiceSettings? settings = await _loadFromHive();
    if (settings != null) return settings;

    // 2️⃣ Cloud (si disponible)
    settings = await _loadFromFirestore();
    if (settings != null) {
      // Cache immédiat localement.
      await _saveToHive(settings);
      return settings;
    }

    // 3️⃣ Valeurs par défaut
    final fallback = InvoiceSettings.defaultSettings;
    await _saveToHive(fallback);
    return fallback;
  }

  /// Persiste les settings (locale + cloud best-effort).
  Future<void> saveSettings(InvoiceSettings settings) async {
    // Toujours en local en premier (garantit l'offline-first).
    await _saveToHive(settings);
    // Ensuite en cloud (fire-and-forget, non bloquant).
    unawaited(_saveToFirestore(settings));
  }

  /// Met à jour partiellement les settings existants.
  Future<InvoiceSettings> updateSettings(InvoiceSettings Function(InvoiceSettings current) changes) async {
    final current = await loadSettings();
    final updated = changes(current);
    await saveSettings(updated);
    return updated;
  }

  /// Réinitialise les settings aux valeurs par défaut.
  Future<InvoiceSettings> resetSettings() async {
    final defaults = InvoiceSettings.defaultSettings;
    await saveSettings(defaults);
    return defaults;
  }

  /// Efface les settings locaux (reload forcé depuis le cloud ou défauts).
  Future<void> clearLocal() async {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        await Hive.box<InvoiceSettings>(_boxName).delete(_hiveKey);
      }
    } catch (e) {
      debugPrint('⚠️ SettingsService: clearLocal échoué: $e');
    }
  }
}
