// lib/services/mail_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'config_service.dart';

class MailService {
  // Getters sécurisés via ConfigService (secrets = --dart-define, jamais
  // embarqués dans le bundle ; valeurs non sensibles via .env en dev).
  static String get _host => ConfigService.smtpHost;
  static int get _port => ConfigService.smtpPort;
  static String get _username => ConfigService.smtpUsername;
  static String get _password => ConfigService.smtpPassword;
  static String get _fromEmail => ConfigService.smtpFromEmail;
  static String get _fromName => ConfigService.smtpFromName;
  static bool get _secure => ConfigService.smtpSecure;

  static bool get isConfigured =>
      _username.isNotEmpty && _password.isNotEmpty && _fromEmail.isNotEmpty;

  static SmtpServer _getSmtpServer() {
    if (_host.contains('gmail')) {
      return gmail(_username, _password);
    }
    return SmtpServer(
      _host,
      port: _port,
      ssl: _secure,
      username: _username,
      password: _password,
    );
  }

  /// Envoyer un email
  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    String? cc,
    String? bcc,
    bool isHtml = false,
  }) async {
    if (!isConfigured) {
      debugPrint('⚠️ MailService non configuré. Vérifiez vos variables SMTP.');
      return false;
    }

    try {
      final message = Message()
        ..from = Address(_fromEmail, _fromName)
        ..recipients.add(Address(to.trim()))
        ..subject = subject
        ..html = isHtml ? body : null
        ..text = isHtml ? null : body;

      if (cc != null && cc.isNotEmpty) {
        message.ccRecipients.add(Address(cc.trim()));
      }
      if (bcc != null && bcc.isNotEmpty) {
        message.bccRecipients.add(Address(bcc.trim()));
      }

      final server = _getSmtpServer();
      final sendReport = await send(message, server);
      debugPrint('✅ Email envoyé à ${sendReport.mail}');
      return true;
    } on MailerException catch (e) {
      debugPrint('❌ Erreur Mailer: $e');
      return false;
    } catch (e) {
      debugPrint('❌ Erreur envoi email: $e');
      return false;
    }
  }

  /// Envoyer un email en HTML
  static Future<bool> sendHtmlEmail({
    required String to,
    required String subject,
    required String htmlBody,
    String? cc,
    String? bcc,
  }) {
    return sendEmail(
      to: to,
      subject: subject,
      body: htmlBody,
      cc: cc,
      bcc: bcc,
      isHtml: true,
    );
  }

  // ===== TEMPLATES =====

  static String getWelcomeTemplate(String name) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #1A237E; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { padding: 20px; border: 1px solid #ddd; border-top: none; border-radius: 0 0 8px 8px; }
    .footer { text-align: center; padding: 15px; color: #777; font-size: 12px; }
    .btn { background: #1A237E; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header"><h1>Bienvenue sur OHADA Invoice Pro</h1></div>
    <div class="content">
      <h2>Bonjour $name,</h2>
      <p>Nous sommes ravis de vous accueillir sur Noi OHADA Invoice Pro, la solution de facturation conforme aux normes OHADA et SYSCOHADA.</p>
      <ul>
        <li>Créer vos premières factures et devis</li>
        <li>Gérer vos clients et fournisseurs</li>
        <li>Suivre vos paiements</li>
        <li>Accéder à vos statistiques</li>
      </ul>
      <p style="text-align:center;"><a href="#" class="btn">Commencer maintenant</a></p>
      <p>Si vous avez des questions, contactez notre support.</p>
      <p>Cordialement,<br>L'équipe OHADA Invoice Pro</p>
    </div>
    <div class="footer">&copy; 2026 OHADA Invoice Pro - Tous droits réservés</div>
  </div>
</body>
</html>
''';
  }

  static String getResetPasswordTemplate(String name, String resetLink) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #1A237E; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { padding: 20px; border: 1px solid #ddd; border-top: none; border-radius: 0 0 8px 8px; }
    .footer { text-align: center; padding: 15px; color: #777; font-size: 12px; }
    .btn { background: #1A237E; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header"><h1>Réinitialisation du mot de passe</h1></div>
    <div class="content">
      <h2>Bonjour $name,</h2>
      <p>Vous avez demandé à réinitialiser votre mot de passe. Cliquez sur le lien ci-dessous pour créer un nouveau mot de passe :</p>
      <p style="text-align:center;"><a href="$resetLink" class="btn">Réinitialiser</a></p>
      <p>Ce lien expire dans 1 heure.</p>
      <p>Si vous n'avez pas fait cette demande, ignorez cet email.</p>
      <p>Cordialement,<br>L'équipe OHADA Invoice Pro</p>
    </div>
    <div class="footer">&copy; 2026 OHADA Invoice Pro - Tous droits réservés</div>
  </div>
</body>
</html>
''';
  }

  static String getInvoiceTemplate(String clientName, String invoiceNumber, String pdfLink) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #1A237E; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { padding: 20px; border: 1px solid #ddd; border-top: none; border-radius: 0 0 8px 8px; }
    .footer { text-align: center; padding: 15px; color: #777; font-size: 12px; }
    .btn { background: #1A237E; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header"><h1>Votre facture $invoiceNumber</h1></div>
    <div class="content">
      <h2>Bonjour $clientName,</h2>
      <p>Vous trouverez ci-joint votre facture <strong>$invoiceNumber</strong>.</p>
      <p style="text-align:center;"><a href="$pdfLink" class="btn">Télécharger</a></p>
      <p>Cordialement,<br>L'équipe OHADA Invoice Pro</p>
    </div>
    <div class="footer">&copy; 2026 OHADA Invoice Pro - Tous droits réservés</div>
  </div>
</body>
</html>
''';
  }

  static String getPaymentReminderTemplate(String clientName, String invoiceNumber, double amount, int daysOverdue) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #E53935; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { padding: 20px; border: 1px solid #ddd; border-top: none; border-radius: 0 0 8px 8px; }
    .footer { text-align: center; padding: 15px; color: #777; font-size: 12px; }
    .btn { background: #E53935; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header"><h1>⚠️ Rappel de paiement</h1></div>
    <div class="content">
      <h2>Bonjour $clientName,</h2>
      <p>Nous vous rappelons que votre facture <strong>$invoiceNumber</strong> d'un montant de <strong>${amount.toStringAsFixed(0)} FCFA</strong> est en retard de paiement depuis <strong>$daysOverdue jours</strong>.</p>
      <p style="text-align:center;"><a href="#" class="btn">Payer maintenant</a></p>
      <p>Cordialement,<br>L'équipe OHADA Invoice Pro</p>
    </div>
    <div class="footer">&copy; 2026 OHADA Invoice Pro - Tous droits réservés</div>
  </div>
</body>
</html>
''';
  }
}