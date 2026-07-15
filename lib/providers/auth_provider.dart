// lib/providers/auth_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:noi_ohada_invoice_pro/services/logger_service.dart';
import 'package:noi_ohada_invoice_pro/services/security_service.dart';
import 'package:noi_ohada_invoice_pro/services/two_factor_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class AppAuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AppUser? _user;
  bool _isLoading = false;
  String? _error;
  bool _needsTwoFactor = false; // Indique si le 2FA est requis pour la connexion
  AppUser? _pendingUser; // Utilisateur temporaire en attente de vérification 2FA
  UserCredential? _pendingCredential;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get needsTwoFactor => _needsTwoFactor;

  AppAuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((firebaseUser) {
      if (firebaseUser != null) {
        _loadUserProfile(firebaseUser.uid);
      } else {
        _user = null;
        _needsTwoFactor = false;
        _pendingUser = null;
        _pendingCredential = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserProfile(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.getUserProfile(userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    String? companyName,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.registerWithEmailPassword(
        email: email,
        password: password,
        displayName: displayName,
        companyName: companyName,
        phone: phone,
      );
      _isLoading = false;
      notifyListeners();

      // Log d'inscription
      await LoggerService.info(
        'register',
        details: 'Nouvel utilisateur inscrit: ${_user?.email}',
        targetId: _user?.id,
        targetType: 'user',
      );

      // Dans la méthode register, après création du compte :
      if (_user != null) {
        final welcomeHtml = MailService.getWelcomeTemplate(displayName);
        await MailService.sendHtmlEmail(
          to: email,
          subject: 'Bienvenue sur NOI OHADA Invoice Pro',
          htmlBody: welcomeHtml,
        );
      }
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    _needsTwoFactor = false;
    _pendingUser = null;
    _pendingCredential = null;
    notifyListeners();

    try {
      // 1. Connexion Firebase
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) throw Exception('Utilisateur non trouvé');

      // 2. Récupérer le profil utilisateur depuis Firestore
      final appUser = await _authService.getUserProfile(firebaseUser.uid);
      if (appUser == null) throw Exception('Profil utilisateur manquant');

      // 3. Vérifier si le 2FA est activé pour cet utilisateur
      final is2FAEnabled = await SecurityService.isTwoFactorEnabled();

      if (is2FAEnabled) {
        // Stocker l'utilisateur en attente et les identifiants
        _pendingUser = appUser;
        _pendingCredential = userCredential;
        _needsTwoFactor = true;
        _isLoading = false;
        notifyListeners();
        return true; // Connexion initiée, en attente du code 2FA
      }

      // 4. Pas de 2FA : connexion directe
      _user = appUser;
      _isLoading = false;
      notifyListeners();

      // Log de connexion
      await LoggerService.info(
        'login',
        details: 'Utilisateur connecté: ${appUser.email}',
        targetId: appUser.id,
        targetType: 'user',
      );
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();

      // Log d'échec de connexion
      await LoggerService.warning(
        'login_failed',
        details: 'Tentative de connexion échouée: $e',
      );
      return false;
    }
  }

  // Vérification du code 2FA après que l'utilisateur l'a saisi
  Future<bool> verifyTwoFactorCode(String code) async {
    if (_pendingUser == null || _pendingCredential == null) {
      _error = 'Aucune session en attente';
      notifyListeners();
      return false;
    }

    try {
      final isValid = TwoFactorService.verifyCode(_pendingUser!.id, code);
      if (!isValid) {
        _error = 'Code invalide';
        notifyListeners();
        return false;
      }

      // Code valide : finaliser la connexion
      _user = _pendingUser;
      _needsTwoFactor = false;
      _pendingUser = null;
      _pendingCredential = null;
      _isLoading = false;
      notifyListeners();

      // Log de connexion réussie avec 2FA
      await LoggerService.info(
        'login_2fa_success',
        details: 'Authentification 2FA réussie pour ${_user?.email}',
        targetId: _user?.id,
        targetType: 'user',
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Annuler la tentative de connexion 2FA
  void cancelTwoFactorLogin() {
    _pendingUser = null;
    _pendingCredential = null;
    _needsTwoFactor = false;
    notifyListeners();
  }

  Future<void> logout() async {
    final userId = _user?.id;
    final userEmail = _user?.email;

    // Log de déconnexion avant de sign out
    if (userId != null && userEmail != null) {
      await LoggerService.info(
        'logout',
        details: 'Utilisateur déconnecté: $userEmail',
        targetId: userId,
        targetType: 'user',
      );
    }

    await _authService.signOut();
    _user = null;
    _needsTwoFactor = false;
    _pendingUser = null;
    _pendingCredential = null;
    notifyListeners();
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
      await LoggerService.info(
        'reset_password',
        details: 'Demande de réinitialisation de mot de passe pour $email',
      );
      if (_user != null) {
        final welcomeHtml = MailService.getResetPasswordTemplate(_user!.displayName);
        await MailService.sendHtmlEmail(
          to: email,
          subject: 'Bienvenue sur NOI OHADA Invoice Pro',
          htmlBody: welcomeHtml,
        );
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      await LoggerService.error(
        'reset_password_failed',
        details: 'Échec de la réinitialisation pour $email: $e',
      );
      return false;
    }
  }

  Future<void> refreshUser() async {
    if (_user != null) {
      final updatedUser = await _authService.getUserProfile(_user!.id);
      if (updatedUser != null) {
        _user = updatedUser;
        notifyListeners();
      }
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}