// lib/services/security_service.dart
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/admin_service.dart';

class SecurityService {
  static const String _boxName = 'security_preferences';
  static const String _pinKey = 'app_pin';
  static const String _biometricKey = 'biometric_enabled';
  static const String _twoFactorKey = 'two_factor_enabled';
  static const String _twoFactorSecretKey = 'two_factor_secret';
  static const String _lockTimeoutKey = 'lock_timeout';
  static const String _lastActivityKey = 'last_activity';
  
  static Box? _box;
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Contexte utilisateur pour les logs Firestore
  static String? _currentUserId;
  static String? _currentUserEmail;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  // Définir le contexte utilisateur (appeler après authentification)
  static void setUserContext({required String userId, required String userEmail}) {
    _currentUserId = userId;
    _currentUserEmail = userEmail;
  }

  // Purger le contexte utilisateur (à appeler impérativement lors du logout)
  static void clearUserContext() {
    _currentUserId = null;
    _currentUserEmail = null;
  }

  // Utilitaire pour convertir en toute sécurité les types de retour de Hive
  static Map<String, dynamic> _castMap(Map<dynamic, dynamic> map) {
    return map.map((key, value) {
      if (value is Map) {
        return MapEntry(key.toString(), _castMap(value));
      }
      return MapEntry(key.toString(), value);
    });
  }

  // Méthode de log unifiée (local + Firestore)
  static Future<void> _logActivity({
    required String action,
    String? details,
    String? targetId,
    String? targetType,
  }) async {
    // 1. Log local
    await _addLocalLog(action: action, details: details);
    
    // 2. Log Firestore (si utilisateur connecté)
    if (_currentUserId != null && _currentUserEmail != null) {
      try {
        final adminService = AdminService();
        await adminService.logActivity(
          userId: _currentUserId!,
          userEmail: _currentUserEmail!,
          action: action,
          targetId: targetId,
          targetType: targetType,
          details: details != null ? {'details': details} : null, limit: 200,
        );
      } catch (e) {
        debugPrint('❌ Erreur log Firestore: $e');
      }
    }
  }

  // ===== LOGS LOCAUX =====
  static Future<void> _addLocalLog({
    required String action,
    String? details,
  }) async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé. Appelez await SecurityService.init() d\'abord.');
    
    final logs = await getActivityLogs();
    
    // ✅ CORRECTION : Insertion dans une nouvelle liste mutable pour éviter l'erreur d'immuabilité
    final updatedLogs = List<Map<String, dynamic>>.from(logs);
    
    updatedLogs.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'action': action,
      'details': details ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    if (updatedLogs.length > 100) {
      updatedLogs.removeRange(100, updatedLogs.length);
    }
    
    await _box!.put('activityLogs', updatedLogs);
  }

  static Future<List<Map<String, dynamic>>> getActivityLogs() async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    final rawLogs = _box!.get('activityLogs', defaultValue: []) as List;
    
    // ✅ CORRECTION : Conversion sécurisée pour éviter les conflits Map<dynamic, dynamic>
    return rawLogs.map((log) {
      if (log is Map) {
        return _castMap(log);
      }
      return <String, dynamic>{};
    }).toList();
  }

  static Future<void> clearActivityLogs() async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    await _box!.put('activityLogs', []);
  }

  // ===== BIOMETRIE =====
  static Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isBiometricEnabled() async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    return _box!.get(_biometricKey, defaultValue: false) as bool;
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    await _box!.put(_biometricKey, enabled);
    await _logActivity(
      action: enabled ? 'biometric_enabled' : 'biometric_disabled',
      details: 'Biométrie ${enabled ? 'activée' : 'désactivée'}',
    );
  }

  static Future<bool> authenticateWithBiometrics() async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        await _logActivity(
          action: 'biometric_authentication_failed',
          details: 'Biométrie non disponible',
        );
        return false;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authentifiez-vous pour accéder à l\'application',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      if (authenticated) {
        await _logActivity(
          action: 'biometric_authentication_success',
          details: 'Authentification biométrique réussie',
        );
      } else {
        await _logActivity(
          action: 'biometric_authentication_failed',
          details: 'Échec de l\'authentification biométrique',
        );
      }
      
      return authenticated;
    } catch (e) {
      await _logActivity(
        action: 'biometric_authentication_failed',
        details: 'Erreur: $e',
      );
      return false;
    }
  }

  // ===== PIN / MOT DE PASSE =====
  static Future<bool> isPinSet() async {
    final pin = await _secureStorage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  static Future<void> setPin(String pin) async {
    await _secureStorage.write(key: _pinKey, value: pin);
    await _logActivity(
      action: 'pin_set',
      details: 'Code PIN défini',
    );
  }

  static Future<void> removePin() async {
    await _secureStorage.delete(key: _pinKey);
    await _logActivity(
      action: 'pin_removed',
      details: 'Code PIN supprimé',
    );
  }

  static Future<bool> verifyPin(String pin) async {
    final storedPin = await _secureStorage.read(key: _pinKey);
    final isValid = storedPin == pin;
    if (isValid) {
      await _logActivity(
        action: 'pin_verified',
        details: 'PIN vérifié avec succès',
      );
    } else {
      await _logActivity(
        action: 'pin_verification_failed',
        details: 'Tentative de PIN incorrect',
      );
    }
    return isValid;
  }

  // ===== 2FA =====
  static Future<bool> isTwoFactorEnabled() async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    return _box!.get(_twoFactorKey, defaultValue: false) as bool;
  }

  static Future<void> setTwoFactorEnabled(bool enabled) async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    await _box!.put(_twoFactorKey, enabled);
    if (!enabled) {
      await _secureStorage.delete(key: _twoFactorSecretKey);
    }
    await _logActivity(
      action: enabled ? 'two_factor_enabled' : 'two_factor_disabled',
      details: '2FA ${enabled ? 'activée' : 'désactivée'}',
    );
  }

  static Future<void> setTwoFactorSecret(String secret) async {
    await _secureStorage.write(key: _twoFactorSecretKey, value: secret);
    await _logActivity(
      action: 'two_factor_secret_set',
      details: 'Secret 2FA enregistré',
    );
  }

  static Future<String?> getTwoFactorSecret() async {
    return await _secureStorage.read(key: _twoFactorSecretKey);
  }

  // ===== VERROUILLAGE =====
  static Future<int> getLockTimeout() async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    return _box!.get(_lockTimeoutKey, defaultValue: 5) as int;
  }

  static Future<void> setLockTimeout(int minutes) async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    await _box!.put(_lockTimeoutKey, minutes);
    await _logActivity(
      action: 'lock_timeout_changed',
      details: 'Délai de verrouillage modifié à $minutes minutes',
    );
  }

  static Future<void> updateLastActivity() async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    await _box!.put(_lastActivityKey, DateTime.now().toIso8601String());
  }

  static Future<bool> isAppLocked() async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    final lastActivityStr = _box!.get(_lastActivityKey) as String?;
    if (lastActivityStr == null) return false;

    final lastActivity = DateTime.parse(lastActivityStr);
    final timeout = await getLockTimeout();
    final difference = DateTime.now().difference(lastActivity);

    final locked = difference.inMinutes >= timeout;
    if (locked) {
      await _logActivity(
        action: 'app_auto_locked',
        details: 'Application verrouillée automatiquement (inactivité de $timeout minutes)',
      );
    }
    return locked;
  }

  // ===== SESSIONS =====
  static Future<void> addSession(String deviceName) async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    final sessions = await getSessions();
    
    // ✅ CORRECTION : Mutation d'une nouvelle liste pour éviter l'immuabilité
    final updatedSessions = List<Map<String, dynamic>>.from(sessions);
    
    updatedSessions.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'device': deviceName,
      'ip': '192.168.1.1', // À remplacer dynamiquement si nécessaire
      'lastActive': DateTime.now().toIso8601String(),
      'current': true,
    });
    
    await _box!.put('sessions', updatedSessions);
    await _logActivity(
      action: 'session_started',
      details: 'Nouvelle session depuis $deviceName',
    );
  }

  static Future<List<Map<String, dynamic>>> getSessions() async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    final rawSessions = _box!.get('sessions', defaultValue: []) as List;
    
    return rawSessions.map((s) {
      if (s is Map) {
        return _castMap(s);
      }
      return <String, dynamic>{};
    }).toList();
  }

  static Future<void> revokeSession(String sessionId) async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    final sessions = await getSessions();
    
    // ✅ CORRECTION : Mutation sécurisée
    final updated = sessions.where((s) => s['id'] != sessionId).toList();
    await _box!.put('sessions', updated);
    
    await _logActivity(
      action: 'session_revoked',
      details: 'Session révoquée',
    );
  }

  static Future<void> revokeAllSessions() async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    await _box!.put('sessions', []);
    await _logActivity(
      action: 'all_sessions_revoked',
      details: 'Toutes les sessions révoquées',
    );
  }

  // ===== VERROUILLAGE DE COMPTE =====
  static Future<void> lockAccount() async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    await _box!.put('account_locked', true);
    await _box!.put('lock_reason', 'Tentatives de connexion trop nombreuses');
    await _box!.put('lock_timestamp', DateTime.now().toIso8601String());
    await _logActivity(
      action: 'account_locked',
      details: 'Compte verrouillé pour cause de tentatives de connexion trop nombreuses',
    );
  }

  static Future<bool> isAccountLocked() async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    final locked = _box!.get('account_locked', defaultValue: false) as bool;
    if (!locked) return false;
    
    final lockTimestampStr = _box!.get('lock_timestamp') as String?;
    if (lockTimestampStr == null) return true;
    
    final lockTimestamp = DateTime.parse(lockTimestampStr);
    final difference = DateTime.now().difference(lockTimestamp);
    
    // Déverrouiller automatiquement après 30 minutes
    if (difference.inMinutes >= 30) {
      await unlockAccount();
      return false;
    }
    
    return true;
  }

  static Future<void> unlockAccount() async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    await _box!.put('account_locked', false);
    await _box!.delete('lock_reason');
    await _box!.delete('lock_timestamp');
    await _logActivity(
      action: 'account_unlocked',
      details: 'Compte déverrouillé automatiquement',
    );
  }

  static Future<String?> getLockReason() async {
    assert(_box != null, 'SecurityService n\'a pas été initialisé.');
    return _box!.get('lock_reason') as String?;
  }

  // ===== CHANGEMENT DE MOT DE PASSE =====
  static Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (newPassword != confirmPassword) {
      await _logActivity(
        action: 'password_change_failed',
        details: 'Les mots de passe ne correspondent pas',
      );
      throw Exception('Les mots de passe ne correspondent pas');
    }
    
    if (newPassword.length < 6) {
      await _logActivity(
        action: 'password_change_failed',
        details: 'Mot de passe trop court (< 6 caractères)',
      );
      throw Exception('Le mot de passe doit contenir au moins 6 caractères');
    }
    
    // Note: L'authentification Firebase doit être gérée au niveau de votre AuthProvider
    await _logActivity(
      action: 'password_changed',
      details: 'Mot de passe modifié avec succès',
    );
    
    return true;
  }
}