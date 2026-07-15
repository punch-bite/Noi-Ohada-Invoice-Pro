// lib/services/mail_service.dart
import 'dart:async';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MailService {
  static String get _host => dotenv.env['SMTP_HOST'] ?? 'smtp.gmail.com';
  static int get _port => int.tryParse(dotenv.env['SMTP_PORT'] ?? '587') ?? 587;
  static String get _username => dotenv.env['SMTP_USERNAME'] ?? '';
  static String get _password => dotenv.env['SMTP_PASSWORD'] ?? '';
  static String get _fromEmail => dotenv.env['SMTP_FROM_EMAIL'] ?? '';
  static String get _fromName => dotenv.env['SMTP_FROM_NAME'] ?? 'OHADA Invoice Pro';
  static bool get _secure => dotenv.env['SMTP_SECURE']?.toLowerCase() == 'true';

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
      print('⚠️ MailService non configuré');
      return false;
    }

    try {
      final message = Message()
        ..from = Address(_fromEmail, _fromName)
        ..recipients.add(to)
        ..subject = subject
        ..html = isHtml ? body : null
        ..text = isHtml ? null : body;

      if (cc != null) message.cc.add(cc);
      if (bcc != null) message.bcc.add(bcc);

      final server = _getSmtpServer();
      final sendReport = await send(message, server);
      print('✅ Email envoyé: ${sendReport.recipients}');
      return true;
    } catch (e) {
      print('❌ Erreur envoi email: $e');
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

  /// Template de bienvenue
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
    <div class="header">
      <h1>Bienvenue sur OHADA Invoice Pro</h1>
    </div>
    <div class="content">
      <h2>Bonjour $name,</h2>
      <p>Nous sommes ravis de vous accueillir sur OHADA Invoice Pro, la solution de facturation conforme aux normes OHADA et SYSCOHADA.</p>
      <p>Voici ce que vous pouvez faire dès maintenant :</p>
      <ul>
        <li>Créer vos premières factures et devis</li>
        <li>Gérer vos clients et fournisseurs</li>
        <li>Suivre vos paiements</li>
        <li>Accéder à vos statistiques</li>
      </ul>
      <p style="text-align: center;">
        <a href="#" class="btn">Commencer maintenant</a>
      </p>
      <p>Si vous avez des questions, n'hésitez pas à contacter notre support.</p>
      <p>Cordialement,<br>L'équipe OHADA Invoice Pro</p>
    </div>
    <div class="footer">
      &copy; 2025 OHADA Invoice Pro - Tous droits réservés
    </div>
  </div>
</body>
</html>
''';
  }

  /// Template de réinitialisation de mot de passe
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
    <div class="header">
      <h1>Réinitialisation du mot de passe</h1>
    </div>
    <div class="content">
      <h2>Bonjour $name,</h2>
      <p>Vous avez demandé à réinitialiser votre mot de passe. Cliquez sur le lien ci-dessous pour créer un nouveau mot de passe :</p>
      <p style="text-align: center;">
        <a href="$resetLink" class="btn">Réinitialiser mon mot de passe</a>
      </p>
      <p>Ce lien expirera dans 1 heure.</p>
      <p>Si vous n'avez pas demandé cette réinitialisation, ignorez simplement cet email.</p>
      <p>Cordialement,<br>L'équipe OHADA Invoice Pro</p>
    </div>
    <div class="footer">
      &copy; 2025 OHADA Invoice Pro - Tous droits réservés
    </div>
  </div>
</body>
</html>
''';
  }

  /// Template de facture envoyée par email
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
    <div class="header">
      <h1>Votre facture $invoiceNumber</h1>
    </div>
    <div class="content">
      <h2>Bonjour $clientName,</h2>
      <p>Vous trouverez ci-joint votre facture <strong>$invoiceNumber</strong>.</p>
      <p>Pour toute question relative à cette facture, n'hésitez pas à nous contacter.</p>
      <p style="text-align: center;">
        <a href="$pdfLink" class="btn">Télécharger la facture</a>
      </p>
      <p>Cordialement,<br>L'équipe OHADA Invoice Pro</p>
    </div>
    <div class="footer">
      &copy; 2025 OHADA Invoice Pro - Tous droits réservés
    </div>
  </div>
</body>
</html>
''';
  }

  /// Template de rappel de paiement
  static String getPaymentReminderTemplate(
    String clientName,
    String invoiceNumber,
    double amount,
    int daysOverdue,
  ) {
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
    <div class="header">
      <h1>⚠️ Rappel de paiement</h1>
    </div>
    <div class="content">
      <h2>Bonjour $clientName,</h2>
      <p>Nous vous rappelons que votre facture <strong>$invoiceNumber</strong> d'un montant de <strong>${amount.toStringAsFixed(0)} FCFA</strong> est en retard de paiement depuis <strong>$daysOverdue jours</strong>.</p>
      <p>Merci de procéder au règlement dans les plus brefs délais.</p>
      <p style="text-align: center;">
        <a href="#" class="btn">Payer maintenant</a>
      </p>
      <p>Cordialement,<br>L'équipe OHADA Invoice Pro</p>
    </div>
    <div class="footer">
      &copy; 2025 OHADA Invoice Pro - Tous droits réservés
    </div>
  </div>
</body>
</html>
''';
  }
}