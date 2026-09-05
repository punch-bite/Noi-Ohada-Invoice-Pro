// lib/services/template_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/invoice_template.dart';
import 'config_service.dart';

class TemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'templates';

  // Récupérer tous les modèles actifs
  Future<List<InvoiceTemplate>> getAllTemplates() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return InvoiceTemplate.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('❌ Erreur getAllTemplates: $e');
      return [];
    }
  }

  /// Modèles achetés / disponibles pour l'utilisateur ("Mes modèles").
  /// Un modèle gratuit (prix admin = 0) est utilisable par tous.
  Future<List<InvoiceTemplate>> getMyTemplates(String userId) async {
    final all = await getAllTemplates();
    return all
        .where((t) => t.purchasedBy.contains(userId) || t.price <= 0)
        .toList();
  }

  /// 🔒 Achat sécurisé via le SERVEUR (`POST /template/purchase`).
  ///
  /// Le serveur vérifie (si total > 0) que la commande ENKAP est bien
  /// CONFIRMÉE avant de débloquer les modèles (ajout à `purchasedBy` via le
  /// SDK admin). Les modèles GRATUITS (prix = 0) sont débloqués SANS
  /// paiement. `reference` = null pour un panier 100 % gratuit.
  Future<bool> purchaseTemplates({
    required String userId,
    required List<String> templateIds,
    String? reference,
  }) async {
    if (userId.isEmpty || templateIds.isEmpty) return false;
    final apiBase = ConfigService.apiBaseUrl.trim();
    if (apiBase.isEmpty) return false;
    try {
      final resp = await http
          .post(
            Uri.parse('$apiBase/template/purchase'),
            headers: ConfigService.serverHeaders(),
            body: jsonEncode({
              'userId': userId,
              'templateIds': templateIds,
              'reference': reference,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final ok = resp.statusCode == 200;
      if (!ok) {
        debugPrint('⚠️ purchaseTemplates serveur: ${resp.statusCode} ${resp.body}');
      }
      return ok;
    } catch (e) {
      debugPrint('⚠️ purchaseTemplates (réseau): $e');
      return false;
    }
  }

  // Récupérer les modèles créés par un admin
  Future<List<InvoiceTemplate>> getTemplatesByAdmin(String adminId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('createdBy', isEqualTo: adminId)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return InvoiceTemplate.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('❌ Erreur getTemplatesByAdmin: $e');
      return [];
    }
  }

  // Récupérer un modèle par son ID
  Future<InvoiceTemplate?> getTemplateById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return InvoiceTemplate.fromMap(data);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur getTemplateById: $e');
      return null;
    }
  }

  // Créer un modèle (admin uniquement)
  Future<void> createTemplate(InvoiceTemplate template) async {
    try {
      await _firestore.collection(_collection).doc(template.id).set(template.toMap());
    } catch (e) {
      throw Exception('Erreur création modèle: $e');
    }
  }

  // Mettre à jour un modèle
  Future<void> updateTemplate(InvoiceTemplate template) async {
    try {
      await _firestore.collection(_collection).doc(template.id).update(template.toMap());
    } catch (e) {
      throw Exception('Erreur mise à jour modèle: $e');
    }
  }

  // Supprimer un modèle (soft delete)
  Future<void> deleteTemplate(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({'isActive': false});
    } catch (e) {
      throw Exception('Erreur suppression modèle: $e');
    }
  }

  // Supprimer définitivement
  Future<void> deletePermanently(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Erreur suppression définitive: $e');
    }
  }
}