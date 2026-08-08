// lib/services/auth_service.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _cachedUser;

  int _loginAttempts = 0;
  DateTime? _lockoutUntil;
  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 5);

  AuthService() {
    userProfile.listen((profile) {
      _cachedUser = profile;
    });
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Stream<AppUser?> get userProfile {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) {
        _cachedUser = null;
        return null;
      }
      return await _ensureUserDocument(user.uid);
    });
  }

  /// ✅ Garantit que le document utilisateur existe dans Firestore
  Future<AppUser> _ensureUserDocument(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return AppUser.fromMap(doc.data()!);
      }

      // 🔥 Document inexistant → création avec les infos Firebase Auth
      final firebaseUser = _auth.currentUser;
      final defaultUser = AppUser(
        id: userId,
        email: firebaseUser?.email ?? '',
        displayName: firebaseUser?.displayName ?? 'Utilisateur',
        createdAt: DateTime.now(),
        isActive: true,
        roles: ['user'],
      );

      await _firestore.collection('users').doc(userId).set(defaultUser.toMap());
      return defaultUser;
    } catch (e) {
      debugPrint('❌ Erreur _ensureUserDocument: $e');
      // En cas d'erreur, on retourne un utilisateur minimal
      return AppUser(
        id: userId,
        email: '',
        displayName: 'Utilisateur',
        createdAt: DateTime.now(),
        isActive: true,
        roles: ['user'],
      );
    }
  }

  // Récupérer le profil utilisateur (Firestore ou Local)
  Future<AppUser?> getUserProfile(String userId) async {
    try {
      // 🔥 Utiliser _ensureUserDocument pour garantir l'existence
      return await _ensureUserDocument(userId);
    } catch (e) {
      debugPrint('❌ Erreur getUserProfile: $e');
      return null;
    }
  }

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

      await _firestore.collection('users').doc(user.uid).set(appUser.toMap());
      _cachedUser = appUser;
      return appUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Cet e-mail est déjà associé à un compte.');
      } else if (e.code == 'weak-password') {
        throw Exception(
            'Le mot de passe choisi est trop faible (6 caractères minimum).');
      }
      throw Exception(e.message ?? 'Erreur lors de l\'inscription.');
    } catch (e) {
      throw Exception('Erreur d\'inscription: $e');
    }
  }

  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now());
      if (remaining.inMinutes > 0) {
        throw Exception(
            'Trop de tentatives infructueuses. Réessayez dans ${remaining.inMinutes + 1} minute(s).');
      } else {
        throw Exception(
            'Trop de tentatives infructueuses. Réessayez dans ${remaining.inSeconds} seconde(s).');
      }
    }

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user!;
      _loginAttempts = 0;
      _lockoutUntil = null;

      // ✅ Utiliser set avec merge pour mettre à jour lastLoginAt
      await _firestore.collection('users').doc(user.uid).set({
        'lastLoginAt': Timestamp.now(),
      }, SetOptions(merge: true));

      // 🔥 Récupérer le profil (il sera créé s'il n'existe pas)
      final profile = await _ensureUserDocument(user.uid);
      _cachedUser = profile;
      return profile;
    } on FirebaseAuthException catch (e) {
      _loginAttempts++;
      if (_loginAttempts >= maxAttempts) {
        _lockoutUntil = DateTime.now().add(lockoutDuration);
        _loginAttempts = 0;
        throw Exception(
            'Trop de tentatives échouées. Compte bloqué temporairement pour 5 minutes.');
      }

      String messageError = 'Adresse e-mail ou mot de passe incorrect.';
      if (e.code == 'user-disabled') {
        messageError = 'Ce compte utilisateur a été désactivé.';
      }
      final remainingAttempts = maxAttempts - _loginAttempts;
      throw Exception(
          '$messageError (Tentatives restantes : $remainingAttempts)');
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

    /// Se connecte avec un compte Google.
  /// - 🌐 Web : on laisse FIREBASE gérer le popup OAuth (`signInWithPopup`
  ///   avec GoogleAuthProvider). C'est beaucoup plus fiable que le plugin
  ///   `google_sign_in_web` qui exige un client OAuth manuel + redirect URIs
  ///   autorisés (sinon erreur « popup_closed »). Firebase utilise ses
  ///   propres redirect URIs (firebaseapp.com) automatiquement.
  /// - 📱 Android/iOS : `google_sign_in` SANS clientId (google-services.json /
  ///   Info.plist), puis échange du jeton avec Firebase.
  Future<AppUser> signInWithGoogle() async {
    try {
      final UserCredential userCredential;
      String? googleDisplayName;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Connexion Google annulée.');
        }
        googleDisplayName = googleUser.displayName;
        final googleAuth = await googleUser.authentication;
        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          throw Exception('Authentification Google incomplète. Réessayez.');
        }
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      final user = userCredential.user!;

      // ✅ Mise à jour du nom affiché si absent
      if (user.displayName == null || user.displayName!.isEmpty) {
        await user.updateDisplayName(
            googleDisplayName ?? 'Utilisateur Google');
      }

      // 🔥 Garantit la création du document profil dans Firestore
      final profile = await _ensureUserDocument(user.uid);
      _cachedUser = profile;
      return profile;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request' ||
          e.code == 'user-cancelled') {
        throw Exception('Connexion Google annulée.');
      }
      throw Exception('Erreur de connexion Google: ${e.message ?? e.code}');
    } catch (e) {
      if (e is Exception && e.toString().contains('annulée')) {
        rethrow;
      }
      throw Exception('Erreur de connexion Google: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _cachedUser = null;
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('Aucun utilisateur ne correspond à cet e-mail.');
      }
      throw Exception(
          e.message ?? 'Impossible d\'envoyer le mail de réinitialisation.');
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).delete();
        await user.delete();
        _cachedUser = null;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          throw Exception(
              'Veuillez vous reconnecter avant de supprimer votre compte.');
        }
        throw Exception(
            e.message ?? 'Erreur lors de la suppression du compte.');
      }
    }
  }

  Future<bool> isEmailInUse(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Erreur vérification email: $e');
      return false;
    }
  }

  AppUser? get currentUser => _cachedUser;
  String? get currentUserId => _auth.currentUser?.uid;
  bool get isAuthenticated => _auth.currentUser != null;
}
