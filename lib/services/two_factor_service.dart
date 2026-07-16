// lib/services/two_factor_service.dart
import 'package:dart_dash_otp/dart_dash_otp.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TwoFactorService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _secretPrefix = '2fa_secret_';

  /// Générer un secret aléatoire fort (encodé en Base32)
  static String generateSecret() {
    return OTP.randomSecret();
  }

  /// Générer l'URI de provisionnement pour que l'utilisateur puisse scanner le QR Code
  // static String getProvisioningUri(String secret, String email, {String? issuer}) {
  //   final cleanIssuer = issuer ?? 'NOI OHADA Invoice Pro';
  //   final totp = TOTP(secret: secret);
  //   return totp.generateUrl(
  //     placeholder: email,
  //     issuer: cleanIssuer,
  //   );
  // }
  /// Générer l'URI de provisionnement pour que l'utilisateur puisse scanner le QR Code
  static String getProvisioningUri(String secret, String email,
      {String? issuer}) {
    final cleanIssuer = Uri.encodeComponent(issuer ?? 'NOI OHADA Invoice Pro');
    final cleanEmail = Uri.encodeComponent(email);

    // ✅ Génération manuelle de l'URI standard TOTP (compatible Google/Microsoft Authenticator)
    return 'otpauth://totp/$cleanIssuer:$cleanEmail?secret=$secret&issuer=$cleanIssuer';
  }

  /// Vérifier un code TOTP saisi par l'utilisateur
  /// ✅ CORRECTION MAJEURE : Reçoit maintenant le [userId] (pour récupérer le secret en BDD sécurisée)
  /// ou accepte directement un secret temporaire si on est en phase de configuration initiale.
  static Future<bool> verifyCode(String userIdOrSecret, String code) async {
    String? secret = userIdOrSecret;

    // Si la chaîne fournie ne ressemble pas à un secret brut Base32 (longueur et caractères),
    // on considère que c'est un userId et on va lire dans le Secure Storage.
    if (!userIdOrSecret.contains(RegExp(r'^[A-Z2-7]+$')) ||
        userIdOrSecret.length < 16) {
      secret = await getSecret(userIdOrSecret);
    }

    if (secret == null || secret.isEmpty) {
      return false;
    }

    final totp = TOTP(secret: secret);

    // window: 1 tolère un décalage d'un intervalle de 30s (avant/après) pour contrer la désynchronisation horaire des téléphones.
    return totp.verify(otp: code.trim(), window: 1);
  }

  /// Récupérer le temps restant avant expiration du code (pour animer un indicateur visuel)
  static int getRemainingSeconds(String secret) {
    if (secret.isEmpty) return 0;
    final totp = TOTP(secret: secret);
    return totp.remainingSeconds();
  }

  /// Stocker de manière sécurisée le secret d'un utilisateur
  static Future<void> storeSecret(String userId, String secret) async {
    await _storage.write(key: '$_secretPrefix$userId', value: secret);
  }

  /// Récupérer le secret stocké
  static Future<String?> getSecret(String userId) async {
    return await _storage.read(key: '$_secretPrefix$userId');
  }

  /// Supprimer le secret stocké (lors de la désactivation du 2FA)
  static Future<void> deleteSecret(String userId) async {
    await _storage.delete(key: '$_secretPrefix$userId');
  }

  /// Vérifie si la double authentification est activée pour cet utilisateur
  static Future<bool> isEnabled(String userId) async {
    final secret = await getSecret(userId);
    return secret != null && secret.isNotEmpty;
  }
}
