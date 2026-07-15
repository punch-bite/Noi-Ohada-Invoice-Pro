// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream de l'utilisateur actuel
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Stream du profil utilisateur
  Stream<AppUser?> get userProfile {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return await getUserProfile(user.uid);
    });
  }

  // Récupérer le profil utilisateur
  Future<AppUser?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Erreur get user profile: $e');
      return null;
    }
  }

  // Inscription
  Future<AppUser> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
    String? companyName,
    String? phone,
  }) async {
    try {
      // Créer l'utilisateur Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user!;
      
      // Mettre à jour le displayName
      await user.updateDisplayName(displayName);

      // Créer le profil utilisateur
      final appUser = AppUser(
        id: user.uid,
        email: email,
        displayName: displayName,
        phone: phone,
        companyName: companyName,
        createdAt: DateTime.now(),
      );

      // Sauvegarder dans Firestore
      await _firestore.collection('users').doc(user.uid).set(appUser.toMap());

      return appUser;
    } catch (e) {
      throw Exception('Erreur d\'inscription: $e');
    }
  }

  // Connexion
  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user!;
      
      // Mettre à jour la date de dernière connexion
      await _firestore.collection('users').doc(user.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      final profile = await getUserProfile(user.uid);
      if (profile == null) {
        throw Exception('Profil utilisateur non trouvé');
      }
      return profile;
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Réinitialisation du mot de passe
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Vérification de l'email
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Supprimer le compte
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Supprimer le profil Firestore
      await _firestore.collection('users').doc(user.uid).delete();
      // Supprimer l'authentification
      await user.delete();
    }
  }

  // Vérifier si l'email est déjà utilisé
  Future<bool> isEmailInUse(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Récupérer l'utilisateur actuel
  AppUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    // Retourne un objet simplifié
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
      createdAt: DateTime.now(),
    );
  }

  String? get currentUserId => _auth.currentUser?.uid;
  bool get isAuthenticated => _auth.currentUser != null;
}