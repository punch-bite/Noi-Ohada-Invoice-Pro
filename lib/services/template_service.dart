// lib/services/template_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice_template.dart';

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
      print('❌ Erreur getAllTemplates: $e');
      return [];
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
      print('❌ Erreur getTemplatesByAdmin: $e');
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
      print('❌ Erreur getTemplateById: $e');
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