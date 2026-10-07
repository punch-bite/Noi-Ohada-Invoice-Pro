// lib/services/auth_service.dart
//
// CHANGELOG (SaaS — Option A) :
//   • `_ensureUserCompany()` renvoie désormais l'id de la company et
//     rattache automatiquement l'utilisateur (`users/{uid}.companyId`).
//   • Ajout `_linkUserToCompany()` — pose le companyId sur le profil (idempotent).
//   • Ajout `_refreshToken()` — force le refresh du jeton Firebase pour que
//     la Cloud Function `syncUserClaims` soit prise en compte immédiatement.
//   • `signInWithEmailPassword`, `signInWithGoogle`, `registerWithEmailPassword`
//     appellent `_refreshToken()` avant de retourner le profil.
//
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

  // ═══════════════════════════════════════════════════════════════════
  // PROFIL UTILISATEUR
  // ═══════════════════════════════════════════════════════════════════

  /// ✅ Garantit que le document utilisateur existe dans Firestore.
  /// - Document absent → création complète + rattachement company.
  /// - Document existant mais INCOMPLET → complétion + rattachement.
  /// - Document complet → retour tel quel (mais vérifie la company).
  Future<AppUser> _ensureUserDocument(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final firebaseUser = _auth.currentUser;

      // Cas 1 : document déjà présent
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        final email = data['email'];
        final isIncomplete = email == null || (email as String).trim().isEmpty;

        if (isIncomplete) {
          final completion = AppUser(
            id: userId,
            email: firebaseUser?.email ?? '',
            displayName: (data['displayName'] is String &&
                    (data['displayName'] as String).isNotEmpty)
                ? data['displayName'] as String
                : (firebaseUser?.displayName ?? 'Utilisateur'),
            phone: data['phone'] as String?,
            companyId: data['companyId'] as String?,
            createdAt: DateTime.now(),
            isActive: true,
            roles: const ['user'],
          ).toMap();

          await _firestore
              .collection('users')
              .doc(userId)
              .set(completion, SetOptions(merge: true));

          final createdCompanyId = await _ensureUserCompany(
            userId,
            name: completion['displayName'] as String?,
            email: completion['email'] as String?,
            phone: completion['phone'] as String?,
          );
          await _linkUserToCompany(userId, createdCompanyId);
          await _refreshToken();

          return AppUser.fromMap({
            ...completion,
            ...data,
            'companyId': createdCompanyId ?? data['companyId'],
          });
        }

        // ✅ Document complet → on vérifie que la company existe toujours.
        final linkedCompanyId = await _ensureUserCompany(
          userId,
          name: data['displayName'] as String?,
          email: data['email'] as String?,
          phone: data['phone'] as String?,
        );
        if (linkedCompanyId != null &&
            (data['companyId'] == null || data['companyId'] == '')) {
          await _linkUserToCompany(userId, linkedCompanyId);
          data['companyId'] = linkedCompanyId;
        }
        return AppUser.fromMap(data);
      }

      // Cas 2 : document inexistant → création
      final defaultUser = AppUser(
        id: userId,
        email: firebaseUser?.email ?? '',
        displayName: firebaseUser?.displayName ?? 'Utilisateur',
        createdAt: DateTime.now(),
        isActive: true,
        roles: const ['user'],
      );

      await _firestore.collection('users').doc(userId).set(defaultUser.toMap());

      final createdCompanyId = await _ensureUserCompany(
        userId,
        name: defaultUser.displayName,
        email: defaultUser.email,
      );
      if (createdCompanyId != null) {
        await _linkUserToCompany(userId, createdCompanyId);
      }
      await _refreshToken();

      return defaultUser.copyWith(companyId: createdCompanyId);
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

  /// ✅ Garantit l'existence de la company de l'utilisateur et renvoie son id.
  /// Idempotent : `company_$userId` est déterministe.
  Future<String?> _ensureUserCompany(
    String userId, {
    String? name,
    String? email,
    String? phone,
  }) async {
    if (userId.isEmpty) return null;
    try {
      final existing = await _firestore
          .collection('companies')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return existing.docs.first.id;
      }

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
        memberIds: [userId],
        adminIds: [userId],
      );

      await _firestore
          .collection('companies')
          .doc('company_$userId')
          .set(company.toMap());
      debugPrint('✅ Document entreprise créé pour $userId');
      return company.id;
    } catch (e) {
      debugPrint('❌ Erreur _ensureUserCompany: $e');
      return null;
    }
  }

  /// 🔗 Pose le `companyId` sur le profil utilisateur (idempotent).
  /// Déclenche la CF `syncUserClaims` côté serveur (custom claim).
  Future<void> _linkUserToCompany(String userId, String? companyId) async {
    if (companyId == null || companyId.isEmpty) return;
    try {
      await _firestore.collection('users').doc(userId).set({
        'companyId': companyId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ _linkUserToCompany: $e');
    }
  }

  /// 🔄 Force le refresh du jeton Firebase → la CF `syncUserClaims` sera
  /// visible immédiatement côté client (sinon latence jusqu'à 1h).
  Future<void> _refreshToken() async {
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (e) {
      debugPrint('⚠️ _refreshToken: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // LECTURE / INSCRIPTION / CONNEXION
  // ═══════════════════════════════════════════════════════════════════

  Future<AppUser?> getUserProfile(String userId) async {
    try {
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

      await _firestore
          .collection('users')
          .doc(createdAuthUser.uid)
          .set(appUser.toMap());

      final companyId = await _ensureUserCompany(
        createdAuthUser.uid,
        name: companyName ?? displayName,
        email: email.trim(),
        phone: phone,
      );
      await _linkUserToCompany(createdAuthUser.uid, companyId);
      await _refreshToken();

      final finalUser = appUser.copyWith(companyId: companyId);
      _cachedUser = finalUser;
      return finalUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Cet e-mail est déjà associé à un compte.');
      } else if (e.code == 'weak-password') {
        throw Exception(
            'Le mot de passe choisi est trop faible (6 caractères minimum).');
      }
      throw Exception(e.message ?? 'Erreur lors de l\'inscription.');
    } catch (e) {
      if (createdAuthUser != null) {
        try {
          await createdAuthUser.delete();
          debugPrint(
              '🧹 Compte Auth orphelin nettoyé après échec de création Firestore');
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

      final profile = await _ensureUserDocument(user.uid);

      await _firestore.collection('users').doc(user.uid).set({
        'lastLoginAt': Timestamp.now(),
      }, SetOptions(merge: true));

      await _refreshToken();
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
  /// - 🌐 Web : `signInWithPopup` avec GoogleAuthProvider (Firebase gère les
  ///   redirect URIs → plus fiable que google_sign_in_web).
  /// - 📱 Android/iOS : `google_sign_in` + échange du jeton avec Firebase.
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

      if (user.displayName == null || user.displayName!.isEmpty) {
        await user.updateDisplayName(
            googleDisplayName ?? 'Utilisateur Google');
      }

      final profile = await _ensureUserDocument(user.uid);
      await _refreshToken();
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
      final actionCodeSettings = ActionCodeSettings(
        url:
            'https://noi-ohada-invoice-pro.firebaseapp.com/__/auth/callback',
        handleCodeInApp: true,
        iOSBundleId: 'com.noi.ohada.invoicePro',
        androidPackageName: 'com.noi.ohada.invoice_pro',
        androidInstallApp: true,
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