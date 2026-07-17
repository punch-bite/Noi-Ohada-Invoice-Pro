// lib/services/admin_plan_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:noi_ohada_invoice_pro/models/subscription.dart';
import '../models/plan.dart';

class AdminPlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Récupère tous les plans (par défaut + personnalisés)
  Future<List<Plan>> getAllPlans() async {
    final snapshot = await _firestore.collection('plans').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Plan.fromMap(data);
    }).toList();
  }

  // Crée un plan personnalisé
  Future<void> createPlan(Plan plan) async {
    await _firestore.collection('plans').doc(plan.id).set(plan.toMap());
  }

  // Met à jour un plan personnalisé
  Future<void> updatePlan(Plan plan) async {
    await _firestore.collection('plans').doc(plan.id).update(plan.toMap());
  }

  // Supprime un plan personnalisé
  Future<void> deletePlan(String planId) async {
    await _firestore.collection('plans').doc(planId).delete();
  }

  // Affecte un plan à un utilisateur (met à jour son abonnement)
  Future<void> assignPlanToUser(String userId, String planId, {int durationMonths = 1}) async {
    // Vérifier que l'utilisateur existe
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) throw Exception('Utilisateur introuvable');

    // Créer un abonnement actif pour cet utilisateur avec ce plan
    final subscription = Subscription(
      id: _firestore.collection('subscriptions').doc().id,
      userId: userId,
      planId: planId,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(Duration(days: durationMonths * 30)),
      status: 'active',
      paymentMethod: 'admin_assigned',
      paymentId: 'admin_${DateTime.now().millisecondsSinceEpoch}',
      amount: 0, // ou le prix du plan (peut être gratuit)
      currency: 'XAF', // à récupérer du plan
      autoRenew: false,
      isActive: true,
      createdAt: DateTime.now(),
      metadata: {'assignedByAdmin': true, 'adminId': '...'}, interval: '',
    );
    await _firestore.collection('subscriptions').doc(subscription.id).set(subscription.toMap());

    // Mettre à jour l'utilisateur avec l'ID de l'abonnement
    await _firestore.collection('users').doc(userId).update({
      'subscriptionId': subscription.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}