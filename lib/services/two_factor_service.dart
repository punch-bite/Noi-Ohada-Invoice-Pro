// lib/services/two_factor_service.dart
import 'package:dart_dash_otp/dart_dash_otp.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TwoFactorService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _secretPrefix = '2fa_secret_';

  // Générer un secret aléatoire (Base32)
  static String generateSecret() {
    return OTP.randomSecret(); // méthode statique de dart_dash_otp
  }

  // Générer l'URI de provisionnement (pour QR Code)
  // static String getProvisioningUri(String secret, String email, {String? issuer}) {
  //   issuer ??= 'OHADA Invoice Pro';
  //   final totp = TOTP(secret: secret);
  //   return totp.generateUrl(
  //     user: email,
  //     issuer: issuer,
  //   );
  // }

  // Vérifier un code TOTP
  static bool verifyCode(String secret, String code) {
    final totp = TOTP(secret: secret);
    // window: 1 tolère un décalage d'un intervalle (30s) pour les horloges légèrement décalées
    return totp.verify(otp: code, window: 1);
  }

  // Récupérer le temps restant avant expiration du code (pour affichage)
  static int getRemainingSeconds(String secret) {
    final totp = TOTP(secret: secret);
    return totp.remainingSeconds();
  }

  // Stocker/récupérer/supprimer le secret (inchangé)
  static Future<void> storeSecret(String userId, String secret) async {
    await _storage.write(key: '$_secretPrefix$userId', value: secret);
  }

  static Future<String?> getSecret(String userId) async {
    return await _storage.read(key: '$_secretPrefix$userId');
  }

  static Future<void> deleteSecret(String userId) async {
    await _storage.delete(key: '$_secretPrefix$userId');
  }

  static Future<bool> isEnabled(String userId) async {
    final secret = await getSecret(userId);
    return secret != null && secret.isNotEmpty;
  }
}