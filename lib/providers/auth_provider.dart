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
  bool _needsTwoFactor = false; // Indique si le 2FA est requis
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
    _authStateSubscription = _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        // Sécurité : Ne pas charger automatiquement le profil si une procédure 2FA est en cours
        if (!_needsTwoFactor) {
          await _loadUserProfile(firebaseUser.uid);
        }
      } else {
        _user = null;
        _needsTwoFactor = false;
        _pendingUser = null;
        _pendingCredential = null;
        SecurityService.clearUserContext(); // Purge du contexte de sécurité à la fermeture
        notifyListeners();
        notifyRouter(); // ✅ Notifie GoRouter du changement d'état d'accès
      }
    });
  }

  /// Force GoRouter à réévaluer les droits d'accès des pages (redirections automatiques)
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
        // ✅ On synchronise le contexte pour les logs sécurisés
        SecurityService.setUserContext(userId: _user!.id, userEmail: _user!.email);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
      notifyRouter(); // ✅ On force la redirection automatique après chargement du profil
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
        // Synchroniser le contexte de sécurité
        SecurityService.setUserContext(userId: _user!.id, userEmail: _user!.email);
      }

      _isLoading = false;
      notifyListeners();
      notifyRouter(); // ✅ Redirection automatique vers le dashboard

      // Log d'inscription
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
      // 1. Connexion avec limitation de tentative intégrée dans AuthService
      final appUser = await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );

      // 2. Vérifier si le 2FA est activé pour cet utilisateur
      final is2FAEnabled = await SecurityService.isTwoFactorEnabled();

      if (is2FAEnabled) {
        // Stocker l'utilisateur en attente
        _pendingUser = appUser;
        _needsTwoFactor = true;
        _isLoading = false;
        notifyListeners();
        return true; // Connexion initiée, l'UI affichera l'écran 2FA (pas de redirection automatique encore)
      }

      // 3. Pas de 2FA : connexion directe
      _user = appUser;
      SecurityService.setUserContext(userId: appUser.id, userEmail: appUser.email);
      
      _isLoading = false;
      notifyListeners();
      notifyRouter(); // ✅ Déclenche la transition vers le Dashboard

      // Log de connexion
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

      // Log d'échec de connexion
      await LoggerService.warning(
        'login_failed',
        details: 'Tentative de connexion échouée pour $email: $e',
      );
      return false;
    }
  }

  // Vérification du code 2FA après saisie de l'utilisateur
  Future<bool> verifyTwoFactorCode(String code) async {
    if (_pendingUser == null) {
      _error = 'Aucune session en attente d\'authentification';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Vérification asynchrone du code
      final isValid = await TwoFactorService.verifyCode(_pendingUser!.id, code);
      if (!isValid) {
        _error = 'Code de sécurité invalide';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Code valide : Finalisation de la session utilisateur
      _user = _pendingUser;
      SecurityService.setUserContext(userId: _user!.id, userEmail: _user!.email);

      _needsTwoFactor = false;
      _pendingUser = null;
      _pendingCredential = null;
      _error = null;
      _isLoading = false;
      
      notifyListeners();
      notifyRouter(); // ✅ Redirection automatique vers le Dashboard

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
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Annuler la tentative de connexion 2FA
  void cancelTwoFactorLogin() async {
    _pendingUser = null;
    _pendingCredential = null;
    _needsTwoFactor = false;
    _isLoading = false;
    SecurityService.clearUserContext();
    await _authService.signOut(); // Déconnecte la session Firebase incomplète
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
    notifyRouter(); // ✅ Redirection vers la Landing/Login forcée
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.resetPassword(email);
      await LoggerService.info(
        'reset_password',
        details: 'Demande de réinitialisation de mot de passe pour $email', targetType: '',
      );

      // On tente de récupérer le profil pour personnaliser l'e-mail (optionnel)
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