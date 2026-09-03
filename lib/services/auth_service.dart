// lib/services/auth_service.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../models/company.dart';

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

  /// ✅ Garantit que le document utilisateur existe dans Firestore.
  /// - Document absent → création complète.
  /// - Document existant mais INCOMPLET (ex: créé jadis avec le seul champ
  ///   `lastLoginAt`) → complétion des champs manquants via un `set` en merge.
  /// - Document complet → retour tel quel.
  Future<AppUser> _ensureUserDocument(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final firebaseUser = _auth.currentUser;

      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        final email = data['email'];
        final isIncomplete = email == null || (email as String).trim().isEmpty;

        if (isIncomplete) {
          // 🔥 Document partiel → on le complète avec les infos Firebase Auth
          // sans écraser les champs déjà présents (lastLoginAt, etc.).
          final completion = AppUser(
            id: userId,
            email: firebaseUser?.email ?? '',
            displayName: (data['displayName'] is String &&
                    (data['displayName'] as String).isNotEmpty)
                ? data['displayName'] as String
                : (firebaseUser?.displayName ?? 'Utilisateur'),
            phone: data['phone'] as String?,
            createdAt: DateTime.now(),
            isActive: true,
            roles: const ['user'],
          ).toMap();

          await _firestore
              .collection('users')
              .doc(userId)
              .set(completion, SetOptions(merge: true));

          unawaited(_ensureUserCompany(
            userId,
            name: completion['displayName'] as String?,
            email: completion['email'] as String?,
            phone: completion['phone'] as String?,
          ));
          return AppUser.fromMap({...completion, ...data});
        }

        // 🔥 Même quand le profil existe déjà, on s'assure que le document
        // ENTREPRISE de l'utilisateur existe aussi (utilisateurs créés avant
        // ce correctif : la « company » n'était jamais créée à l'inscription).
        unawaited(_ensureUserCompany(
          userId,
          name: data['displayName'] as String?,
          email: data['email'] as String?,
          phone: data['phone'] as String?,
        ));
        return AppUser.fromMap(data);
      }

      // 🔥 Document inexistant → création avec les infos Firebase Auth
      final defaultUser = AppUser(
        id: userId,
        email: firebaseUser?.email ?? '',
        displayName: firebaseUser?.displayName ?? 'Utilisateur',
        createdAt: DateTime.now(),
        isActive: true,
        roles: const ['user'],
      );

      await _firestore.collection('users').doc(userId).set(defaultUser.toMap());
      await _ensureUserCompany(
        userId,
        name: defaultUser.displayName,
        email: defaultUser.email,
      );
      return defaultUser;
    } catch (e) {
      debugPrint('❌ Erreur _ensureUserDocument: $e');
      return AppUser(
        id: userId,
        email: '',
        displayName: 'Utilisateur',
        createdAt: DateTime.now(),
        isActive: true,
        roles: const ['user'],
      );
    }
  }

  /// ✅ Garantit l'existence du document ENTREPRISE (« company ») de
  /// l'utilisateur. Ce document est indispensable à la création de factures
  /// (getCompany → companies/{userId}) et n'était PAS créé à l'inscription.
  ///
  /// Idempotent : vérifie d'abord si une société existe déjà pour cet
  /// utilisateur (requête `where userId == uid`, limite 1) avant d'en créer
  /// une nouvelle. L'id déterministe `company_$userId` évite les doublons.
  Future<void> _ensureUserCompany(
    String userId, {
    String? name,
    String? email,
    String? phone,
  }) async {
    if (userId.isEmpty) return;
    try {
      final existing = await _firestore
          .collection('companies')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) return; // ✅ Déjà créée

      final companyName = (name == null || name.trim().isEmpty)
          ? 'Mon entreprise'
          : name.trim();
      final company = Company(
        id: 'company_$userId',
        userId: userId,
        name: companyName,
        address: '',
        taxId: '',
        phone: phone ?? '',
        email: email ?? '',
        logoPath: '',
        currency: 'XAF',
        defaultTaxRate: 18,
        legalText: 'Conforme aux normes OHADA et SYSCOHADA',
        website: '',
        rccm: '',
      );

      // 🔥 Création (règles Firestore : un utilisateur authentifié peut
      // créer son propre document company avec `userId == auth.uid`).
      await _firestore
          .collection('companies')
          .doc('company_$userId')
          .set(company.toMap());
      debugPrint('✅ Document entreprise créé pour $userId');
    } catch (e) {
      debugPrint('❌ Erreur _ensureUserCompany: $e');
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
    User? createdAuthUser;
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      createdAuthUser = userCredential.user!;
      await createdAuthUser.updateDisplayName(displayName);

      final appUser = AppUser(
        id: createdAuthUser.uid,
        email: email.trim(),
        displayName: displayName,
        phone: phone,
        companyName: companyName,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(createdAuthUser.uid).set(appUser.toMap());
      // ✅ Créer immédiatement le document ENTREPRISE de l'utilisateur
      // (indispensable aux factures) — idempotent.
      await _ensureUserCompany(
        createdAuthUser.uid,
        name: companyName ?? displayName,
        email: email.trim(),
        phone: phone,
      );
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
      // ⚠️ Si la création du document Firestore échoue alors que l'utilisateur Auth a été créé,
      // on tente de nettoyer le compte Auth orphelin pour éviter un compte Auth sans document Firestore.
      if (createdAuthUser != null) {
        try {
          await createdAuthUser.delete();
          debugPrint('🧹 Compte Auth orphelin nettoyé après échec de création Firestore');
        } catch (cleanupErr) {
          debugPrint('⚠️ Impossible de nettoyer le compte Auth: $cleanupErr');
        }
      }
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

      // 🔥 Garantit d'abord l'existence du document profil COMPLET dans
      // Firestore (création si absent, complétion si partiel). On le fait
      // AVANT la mise à jour de `lastLoginAt` pour éviter qu'un `set` avec
      // merge ne crée un document ne contenant QUE `lastLoginAt`.
      final profile = await _ensureUserDocument(user.uid);

      // ✅ Met à jour ensuite lastLoginAt (merge sur le document complet).
      await _firestore.collection('users').doc(user.uid).set({
        'lastLoginAt': Timestamp.now(),
      }, SetOptions(merge: true));

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
      // 🔗 ActionCodeSettings : configure le lien de réinitialisation pour qu'il
      // redirige vers l'application (deep link) après la réinitialisation.
      // - handleCodeInApp : true → le lien ouvre l'app si installée
      // - url : deep link de l'app (schéma personnalisé) pour la redirection
      final actionCodeSettings = ActionCodeSettings(
        // URL de continuation : deep link vers l'application
        // Format : https://<domain}/__/auth/callback ou schéma personnalisé
        url: 'https://noi-ohada-invoice-pro.firebaseapp.com/__/auth/callback',
        handleCodeInApp: true,
        // Bundle ID iOS / Package Name Android (pour les liens universels)
        iOSBundleId: 'com.noi.ohada.invoicePro',
        androidPackageName: 'com.noi.ohada.invoice_pro',
        // Installer l'app Android si elle n'est pas installée
        androidInstallApp: true,
        // Version minimale de l'app Android
        androidMinimumVersion: '1.0.0',
      );

      await _auth.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings: actionCodeSettings,
      );
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
