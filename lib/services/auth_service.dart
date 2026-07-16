// lib/services/auth_service.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache mémoire du profil riche de l'utilisateur actuel
  AppUser? _cachedUser;

  // Variables de limitation des tentatives de connexion
  int _loginAttempts = 0;
  DateTime? _lockoutUntil;
  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 5);

  AuthService() {
    // Écoute automatique pour maintenir à jour le profil utilisateur en mémoire
    userProfile.listen((profile) {
      _cachedUser = profile;
    });
  }

  // Stream de l'utilisateur Firebase Auth brut
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Stream du profil utilisateur riche (Firestore)
  Stream<AppUser?> get userProfile {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) {
        _cachedUser = null;
        return null;
      }
      return await getUserProfile(user.uid);
    });
  }

  // Récupérer le profil utilisateur (Firestore ou Local)
  Future<AppUser?> getUserProfile(String userId) async {
    try {
      // Tente d'obtenir le profil depuis Firestore
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final profile = AppUser.fromMap(doc.data()!);
        
        // TODO: Sauvegarder dans le cache local (Hive) ici lorsque le StorageService sera prêt
        // await _storageService.saveUser(profile);
        
        return profile;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération du profil: $e');
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
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      final user = userCredential.user!;
      await user.updateDisplayName(displayName);

      final appUser = AppUser(
        id: user.uid,
        email: email.trim(),
        displayName: displayName,
        phone: phone,
        companyName: companyName,
        createdAt: DateTime.now(),
      );

      // Sauvegarde Firestore
      await _firestore.collection('users').doc(user.uid).set(appUser.toMap());
      
      // TODO: Sauvegarder dans le cache local (Hive) ici

      _cachedUser = appUser;
      return appUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Cet e-mail est déjà associé à un compte.');
      } else if (e.code == 'weak-password') {
        throw Exception('Le mot de passe choisi est trop faible (6 caractères minimum).');
      }
      throw Exception(e.message ?? 'Une erreur est survenue lors de l\'inscription.');
    } catch (e) {
      throw Exception('Erreur d\'inscription: $e');
    }
  }

  // Connexion avec limitation des tentatives
  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    // 1. Vérification du verrouillage temporaire
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now());
      if (remaining.inMinutes > 0) {
        throw Exception(
          'Trop de tentatives infructueuses. Veuillez réessayer dans ${remaining.inMinutes + 1} minute(s).'
        );
      } else {
        throw Exception(
          'Trop de tentatives infructueuses. Veuillez réessayer dans ${remaining.inSeconds} seconde(s).'
        );
      }
    }

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      final user = userCredential.user!;
      
      // Réinitialiser les compteurs
      _loginAttempts = 0;
      _lockoutUntil = null;
      
      // Mettre à jour la date de dernière connexion sur Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'lastLoginAt': Timestamp.now(), // Utilisation de Timestamp pour éviter les conflits locaux
      });

      final profile = await getUserProfile(user.uid);
      if (profile == null) {
        throw Exception('Profil utilisateur introuvable dans la base de données.');
      }

      _cachedUser = profile;
      return profile;
    } on FirebaseAuthException catch (e) {
      _loginAttempts++;
      
      if (_loginAttempts >= maxAttempts) {
        _lockoutUntil = DateTime.now().add(lockoutDuration);
        _loginAttempts = 0; // Réinitialise pour le prochain cycle
        throw Exception(
          'Trop de tentatives de connexion échouées. Compte bloqué temporairement pour 5 minutes.'
        );
      }

      String messageError = 'Adresse e-mail ou mot de passe incorrect.';
      if (e.code == 'user-disabled') {
        messageError = 'Ce compte utilisateur a été désactivé.';
      }
      
      final remainingAttempts = maxAttempts - _loginAttempts;
      throw Exception('$messageError (Tentatives restantes : $remainingAttempts)');
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
    _cachedUser = null;
    // TODO: Vider le cache local (Hive) de l'utilisateur ici si nécessaire
  }

  // Réinitialisation du mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('Aucun utilisateur ne correspond à cet e-mail.');
      }
      throw Exception(e.message ?? 'Impossible d\'envoyer le mail de réinitialisation.');
    }
  }

  // Vérification de l'email
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Supprimer le compte (avec gestion de la reconnexion obligatoire)
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Supprimer d'abord le profil Firestore
        await _firestore.collection('users').doc(user.uid).delete();
        
        // TODO: Nettoyer toutes les données locales Hive ici
        
        // Supprimer de Firebase Auth
        await user.delete();
        _cachedUser = null;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          throw Exception('Cette action est sensible. Veuillez vous reconnecter avant de supprimer votre compte.');
        }
        throw Exception(e.message ?? 'Erreur lors de la suppression du compte.');
      }
    }
  }

  // Vérification rapide d'existence de l'e-mail dans Firestore
  Future<bool> isEmailInUse(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Erreur lors de la vérification de l\'email: $e');
      return false;
    }
  }

  // Récupérer de manière synchrone le profil utilisateur complet (riche)
  AppUser? get currentUser => _cachedUser;

  String? get currentUserId => _auth.currentUser?.uid;
  bool get isAuthenticated => _auth.currentUser != null;
}