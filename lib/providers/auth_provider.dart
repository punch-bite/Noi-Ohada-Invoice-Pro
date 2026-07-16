// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:noi_ohada_invoice_pro/services/logger_service.dart';
import 'package:noi_ohada_invoice_pro/services/security_service.dart';
import 'package:noi_ohada_invoice_pro/services/two_factor_service.dart';
import '../router/app_router.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../services/mail_service.dart';

class AppAuthProvider extends ChangeNotifier {
  final AuthService _authService;
  StreamSubscription<User?>? _authStateSubscription;

  AppUser? _user;
  bool _isLoading = false;
  String? _error;
  bool _needsTwoFactor = false;
  AppUser? _pendingUser;
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
    _authStateSubscription = _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        if (!_needsTwoFactor) {
          await _loadUserProfile(firebaseUser.uid);
        }
      } else {
        _user = null;
        _needsTwoFactor = false;
        _pendingUser = null;
        _pendingCredential = null;
        SecurityService.clearUserContext();
        notifyListeners();
        notifyRouter();
      }
    });
  }

  void notifyRouter() {
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    (AppRouter.authChangeNotifier as ValueNotifier).notifyListeners();
  }

  Future<void> _loadUserProfile(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.getUserProfile(userId);
      _error = null;
      if (_user != null) {
        SecurityService.setUserContext(userId: _user!.id, userEmail: _user!.email);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
      notifyRouter();
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
      
      if (_user != null) {
        SecurityService.setUserContext(userId: _user!.id, userEmail: _user!.email);
      }

      _isLoading = false;
      notifyListeners();
      notifyRouter();

      await LoggerService.info(
        'register',
        details: 'Nouvel utilisateur inscrit: ${_user?.email}',
        targetId: _user?.id,
        targetType: 'user',
      );

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
      final appUser = await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );

      final is2FAEnabled = await SecurityService.isTwoFactorEnabled();

      if (is2FAEnabled) {
        _pendingUser = appUser;
        _needsTwoFactor = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _user = appUser;
      SecurityService.setUserContext(userId: appUser.id, userEmail: appUser.email);
      
      _isLoading = false;
      notifyListeners();
      notifyRouter();

      await LoggerService.info(
        'login',
        details: 'Utilisateur connecté: ${appUser.email}',
        targetId: appUser.id,
        targetType: 'user',
      );
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();

      await LoggerService.warning(
        'login_failed',
        details: 'Tentative de connexion échouée pour $email: $e',
      );
      return false;
    }
  }

  Future<bool> verifyTwoFactorCode(String code) async {
    if (_pendingUser == null) {
      _error = 'Aucune session en attente d\'authentification';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final isValid = await TwoFactorService.verifyCode(_pendingUser!.id, code);
      if (!isValid) {
        _error = 'Code de sécurité invalide';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _user = _pendingUser;
      SecurityService.setUserContext(userId: _user!.id, userEmail: _user!.email);

      _needsTwoFactor = false;
      _pendingUser = null;
      _pendingCredential = null;
      _error = null;
      _isLoading = false;
      
      notifyListeners();
      notifyRouter();

      await LoggerService.info(
        'login_2fa_success',
        details: 'Authentification 2FA réussie pour ${_user?.email}',
        targetId: _user?.id,
        targetType: 'user',
      );
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void cancelTwoFactorLogin() async {
    _pendingUser = null;
    _pendingCredential = null;
    _needsTwoFactor = false;
    _isLoading = false;
    SecurityService.clearUserContext();
    await _authService.signOut();
    notifyListeners();
    notifyRouter();
  }

  Future<void> logout() async {
    final userId = _user?.id;
    final userEmail = _user?.email;

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
    SecurityService.clearUserContext();
    
    notifyListeners();
    notifyRouter();
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.resetPassword(email);
      await LoggerService.info(
        'reset_password',
        details: 'Demande de réinitialisation de mot de passe pour $email',
        targetType: '',
      );

      String targetName = "Utilisateur";
      if (_user != null) {
        targetName = _user!.displayName;
      }

      final resetHtml = MailService.getResetPasswordTemplate(
        targetName,
        "https://invoicepro.noiconcept.com/reset-password?email=$email", 
      );

      await MailService.sendHtmlEmail(
        to: email.trim(),
        subject: 'Réinitialisation de votre mot de passe - NOI OHADA Invoice Pro',
        htmlBody: resetHtml,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
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

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}