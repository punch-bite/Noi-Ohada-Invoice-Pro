// lib/services/plan_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/plan.dart';
import '../models/subscription.dart';

class PlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Récupérer tous les plans (actifs)
  Future<List<Plan>> getPlans() async {
    try {
      final snapshot = await _firestore.collection('plans').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Plan.fromMap(data);
      }).toList();
    } catch (e) {
      print('❌ Erreur getPlans: $e');
      return [];
    }
  }

  // Récupérer un plan par ID
  Future<Plan?> getPlan(String id) async {
    try {
      final doc = await _firestore.collection('plans').doc(id).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return Plan.fromMap(data);
      }
      return null;
    } catch (e) {
      print('❌ Erreur getPlan: $e');
      return null;
    }
  }

  // Créer un plan
  Future<void> createPlan(Plan plan) async {
    try {
      await _firestore.collection('plans').doc(plan.id).set(plan.toMap());
    } catch (e) {
      throw Exception('Erreur création plan: $e');
    }
  }

  // Mettre à jour un plan
  Future<void> updatePlan(Plan plan) async {
    try {
      await _firestore.collection('plans').doc(plan.id).update(plan.toMap());
    } catch (e) {
      throw Exception('Erreur mise à jour plan: $e');
    }
  }

  // Supprimer un plan (soft delete)
  Future<void> deletePlan(String id) async {
    try {
      await _firestore.collection('plans').doc(id).update({'isActive': false});
    } catch (e) {
      throw Exception('Erreur suppression plan: $e');
    }
  }

  // Assigner un plan à un utilisateur (créer un abonnement)
  Future<void> assignPlanToUser({
    required String userId,
    required String planId,
    required int durationMonths,
  }) async {
    try {
      // Récupérer le plan
      final plan = await getPlan(planId);
      if (plan == null) throw Exception('Plan non trouvé');

      // Créer l'abonnement
      final subscription = Subscription(
        id: _firestore.collection('subscriptions').doc().id,
        userId: userId,
        planId: planId,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(Duration(days: durationMonths * 30)),
        status: 'active',
        paymentMethod: 'admin',
        paymentId: 'admin_${DateTime.now().millisecondsSinceEpoch}',
        amount: plan.price,
        currency: plan.currency,
        autoRenew: false, // Les plans personnalisés ne se renouvellent pas automatiquement
        isActive: true,
        createdAt: DateTime.now(),
        metadata: {'assignedByAdmin': true, 'durationMonths': durationMonths}, interval: '',
      );

      await _firestore
          .collection('subscriptions')
          .doc(subscription.id)
          .set(subscription.toMap());

      // Mettre à jour l'utilisateur avec l'ID de l'abonnement
      await _firestore.collection('users').doc(userId).update({
        'subscriptionId': subscription.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erreur assignation plan: $e');
    }
  }
}