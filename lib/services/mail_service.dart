// lib/services/mail_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'config_service.dart';

/// 📎 Pièce jointe d'e-mail (PDF de facture, export…) : nom de fichier +
/// octets du document. Envoyée via le serveur (base64) OU en SMTP direct.
class EmailAttachment {
  final String filename;
  final Uint8List bytes;
  final String? contentType;

  const EmailAttachment({
    required this.filename,
    required this.bytes,
    this.contentType,
  });

  Map<String, String> toWire() => {
        'filename': filename,
        'base64': base64Encode(bytes),
        if (contentType != null && contentType!.isNotEmpty)
          'contentType': contentType!,
      };
}

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
  ///
  /// 📎 [attachments] : pièces jointes (ex. le PDF de la facture) —
  /// transmises au serveur en base64 ou jointes en SMTP direct.
  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    String? cc,
    String? bcc,
    bool isHtml = false,
    List<EmailAttachment> attachments = const [],
  }) async {
    // 📱 Sur mobile (natif), on privilégie l'envoi via notre serveur
    // (SMTP côté serveur) : l'APK n'embarque PAS les secrets SMTP et le
    // SMTP direct est souvent bloqué par les opérateurs mobiles → c'est
    // pourquoi les mails « ne fonctionnaient pas » sur mobile.
    if (!kIsWeb) {
      final sent = await _sendViaServer(
        to: to,
        subject: subject,
        body: body,
        cc: cc,
        bcc: bcc,
        isHtml: isHtml,
        attachments: attachments,
      );
      if (sent) return true;
      // Sinon on retombe sur l'envoi local si la config SMTP existe.
      if (!isConfigured) {
        debugPrint('⚠️ MailService non configuré localement (serveur KO).');
        return false;
      }
    } else {
      if (!isConfigured) {
        debugPrint(
            '⚠️ MailService non configuré. Vérifiez vos variables SMTP.');
        return false;
      }
    }

    try {
      final message = Message()
        ..from = Address(_fromEmail, _fromName)
        ..recipients.add(Address(to.trim()))
        ..subject = subject
        ..html = isHtml ? body : null
        ..text = isHtml ? null : body;

      // 📎 Pièces jointes (SMTP direct) — ex. le PDF de la facture.
      for (final att in attachments) {
        message.attachments.add(
          StreamAttachment(
            Stream<List<int>>.value(att.bytes),
            att.contentType ?? 'application/octet-stream',
            fileName: att.filename,
          ),
        );
      }

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

  /// Envoi via notre serveur (endpoint /email/send, SMTP côté serveur).
  /// Best-effort : retourne false en cas d'échec réseau/serveur pour que
  /// l'app puisse basculer sur l'envoi local.
  static Future<bool> _sendViaServer({
    required String to,
    required String subject,
    required String body,
    String? cc,
    String? bcc,
    required bool isHtml,
    List<EmailAttachment> attachments = const [],
  }) async {
    final apiBase = ConfigService.apiBaseUrl.trim();
    if (apiBase.isEmpty) return false;
    try {
      final resp = await http
          .post(
            Uri.parse('$apiBase/email/send'),
            headers: await ConfigService.apiHeaders(),
            body: jsonEncode({
              'to': to,
              'subject': subject,
              if (isHtml) 'html': body else 'body': body,
              if (cc != null && cc.isNotEmpty) 'cc': cc,
              if (bcc != null && bcc.isNotEmpty) 'bcc': bcc,
              // 📎 Pièces jointes en base64 (PDF de facture…).
              if (attachments.isNotEmpty)
                'attachments': attachments.map((a) => a.toWire()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        debugPrint('✅ Email envoyé via serveur → $to');
        return true;
      }
      debugPrint('⚠️ Envoi serveur échoué (${resp.statusCode}) : ${resp.body}');
      return false;
    } catch (e) {
      debugPrint('⚠️ Envoi serveur échoué (réseau) : $e');
      return false;
    }
  }

  /// Envoyer un email en HTML
  ///
  /// 📎 [attachments] : pièces jointes (PDF de facture…), jointes que l'envoi
  /// passe par le serveur (base64) ou par le SMTP local.
  static Future<bool> sendHtmlEmail({
    required String to,
    required String subject,
    required String htmlBody,
    String? cc,
    String? bcc,
    List<EmailAttachment> attachments = const [],
  }) {
    return sendEmail(
      to: to,
      subject: subject,
      body: htmlBody,
      cc: cc,
      bcc: bcc,
      isHtml: true,
      attachments: attachments,
    );
  }

  // ===== TEMPLATES =====
  //
  // 🎨 TOUS les e-mails partagent la MÊME coque de marque « professionnelle
  // & marketiste » : bandeau dégradé indigo, carte blanche arrondie, CTA en
  // pilule, footer discret — design e-mail compatible clients (styles
  // inline, largeur bornée 600 px).

  static const String _brand = 'Noi OHADA Invoice Pro';
  static const String _supportUrl = 'https://invoicepro.noiconcept.com';

  /// Coque de marque commune de tous les e-mails.
  static String _emailShell({
    required String heroTitle,
    String accent = '#1A237E',
    String accent2 = '#3949AB',
    String? heroBadge,
    required String contentHtml,
  }) {
    return '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$_brand</title>
</head>
<body style="margin:0;padding:0;background:#f2f3f7;font-family:'Segoe UI',Arial,Helvetica,sans-serif;color:#1f2330;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f2f3f7;padding:28px 12px;">
    <tr>
      <td align="center">
        <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 6px 24px rgba(15,20,45,0.08);">
          <!-- Bandeau dégradé de marque -->
          <tr>
            <td style="background:linear-gradient(135deg,$accent 0%,$accent2 100%);background-color:$accent;padding:34px 36px;text-align:center;">
              $heroBadge
              <h1 style="margin:0;color:#ffffff;font-size:24px;font-weight:700;line-height:1.3;letter-spacing:0.2px;">$heroTitle</h1>
              <p style="margin:10px 0 0;color:#ffffff;opacity:0.85;font-size:13px;letter-spacing:1.4px;text-transform:uppercase;">$_brand</p>
            </td>
          </tr>
          <!-- Contenu -->
          <tr>
            <td style="padding:32px 36px;font-size:15px;line-height:1.7;color:#333a4d;">
              $contentHtml
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="padding:20px 36px;background:#fafbfe;border-top:1px solid #eceef5;text-align:center;">
              <p style="margin:0 0 6px;font-size:13px;color:#66708a;">
                Besoin d'aide ? <a href="$_supportUrl" style="color:$accent;font-weight:600;text-decoration:none;">Centre d'aide</a> ·
                <a href="mailto:contact@noiconcept.com" style="color:$accent;font-weight:600;text-decoration:none;">Support</a>
              </p>
              <p style="margin:0;font-size:11.5px;color:#98a0b3;">
                © 2026 $_brand — Facturation conforme aux normes OHADA & SYSCOHADA.<br>
                Cet e-mail a été envoyé depuis votre application de facturation.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  /// Bouton CTA en pilule (styles inline, compatible tous clients mail).
  static String _cta(String label, String url, String accent) => '''
<p style="text-align:center;margin:28px 0 8px;">
  <a href="$url" style="display:inline-block;background:$accent;color:#ffffff;padding:13px 34px;border-radius:999px;font-size:14.5px;font-weight:700;text-decoration:none;box-shadow:0 4px 12px rgba(26,35,126,0.18);">$label</a>
</p>
<p style="text-align:center;margin:0;font-size:12px;color:#98a0b3;word-break:break-all;">
  <a href="$url" style="color:#98a0b3;text-decoration:none;">$url</a>
</p>
''';

  /// Encadré « info » doux (délai, sécurité, montants…).
  static String _infoBox(String html) => '''
<div style="margin:20px 0;padding:14px 18px;background:#f6f7fb;border-radius:12px;border-left:4px solid #c9cfe3;font-size:13.5px;color:#4b5468;">$html</div>
''';

  /// 🎉 E-mail de BIENVENUE — ton marketiste : bénéfices concrets + CTA
  /// « première facture » pour activer l'utilisateur dès le 1er jour.
  static String getWelcomeTemplate(String name) {
    final content = '''
<h2 style="margin:0 0 6px;font-size:19px;color:#1f2330;">Bonjour $name 👋</h2>
<p style="margin:0 0 18px;">Bienvenue sur <strong>$_brand</strong> — la facturation
<strong>conforme aux normes OHADA & SYSCOHADA</strong>, pensée pour les entreprises
d'Afrique de l'Ouest. Votre compte est prêt : il ne reste qu'à créer votre
première facture.</p>

<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 18px;">
  <tr>
    <td style="padding:10px 14px;background:#f6f7fb;border-radius:12px;font-size:14px;color:#3c455c;">✅ &nbsp;Factures & devis A4 professionnels en 2 minutes</td>
  </tr>
  <tr><td style="height:8px;"></td></tr>
  <tr>
    <td style="padding:10px 14px;background:#f6f7fb;border-radius:12px;font-size:14px;color:#3c455c;">👥 &nbsp;Clients, fournisseurs et stock centralisés</td>
  </tr>
  <tr><td style="height:8px;"></td></tr>
  <tr>
    <td style="padding:10px 14px;background:#f6f7fb;border-radius:12px;font-size:14px;color:#3c455c;">📊 &nbsp;Encaissements, relances et statistiques en temps réel</td>
  </tr>
</table>

${_cta('Créer ma première facture', _supportUrl, '#1A237E')}
${_infoBox('Astuce : complétez d&#39;abord votre <strong>profil d&#39;entreprise</strong> — il s&#39;insérera automatiquement dans chaque facture, devis et e-mail envoyé à vos clients.')}
<p style="margin:22px 0 0;">À très vite,<br><strong>L'équipe $_brand</strong></p>
''';
    return _emailShell(
      heroTitle: 'Votre compte est prêt 🎉',
      heroBadge: '<p style="margin:0 0 12px;font-size:36px;">&#128640;</p>',
      contentHtml: content,
    );
  }

  /// 🔐 E-mail de RÉINITIALISATION — sobre et rassurant : sécurité explicite,
  /// lien unique à durée limitée.
  static String getResetPasswordTemplate(String name, String resetLink) {
    final content = '''
<h2 style="margin:0 0 6px;font-size:19px;color:#1f2330;">Bonjour $name,</h2>
<p style="margin:0 0 16px;">Vous avez demandé la réinitialisation du mot de passe de
votre compte <strong>$_brand</strong>. Cliquez sur le bouton ci-dessous pour en
définir un nouveau :</p>
${_cta('Réinitialiser mon mot de passe', resetLink, '#1A237E')}
${_infoBox('⏱️ &nbsp;Ce lien est valable <strong>1 heure</strong> et ne peut être utilisé qu&#39;une seule fois.<br>🔒 &nbsp;Pour votre sécurité, si vous n&#39;êtes pas à l&#39;origine de cette demande, ignorez simplement cet e-mail : votre mot de passe actuel restera inchangé.')}
<p style="margin:22px 0 0;">L'équipe sécurité <strong>$_brand</strong></p>
''';
    return _emailShell(
      heroTitle: 'Réinitialisation de mot de passe',
      heroBadge: '<p style="margin:0 0 12px;font-size:36px;">&#128274;</p>',
      contentHtml: content,
    );
  }

  /// 🧾 E-mail de FACTURE — professionnel : la facture PDF est **jointe à
  /// l'e-mail** ([attachments] de [sendHtmlEmail]). Le CTA de téléchargement
  /// n'apparaît QUE si un lien réel est fourni ([pdfLink]) — plus jamais de
  /// bouton pointant vers « # ».
  ///
  /// Paramètres optionnels (rétro-compatibles) : [companyName] pour la
  /// signature de l'émetteur, [amount] et [dueDate] pour le récap.
  static String getInvoiceTemplate(
    String clientName,
    String invoiceNumber,
    String pdfLink, {
    String? companyName,
    double? amount,
    String? dueDate,
  }) {
    final hasLink = pdfLink.trim().isNotEmpty && pdfLink.trim() != '#';
    final amountStr = amount == null
        ? null
        : (amount % 1 == 0
            ? amount.toStringAsFixed(0)
            : amount.toStringAsFixed(2));

    final summaryRows = StringBuffer();
    if (amountStr != null) {
      summaryRows.write('''
  <tr>
    <td style="padding:10px 14px;color:#66708a;font-size:13.5px;">Montant total</td>
    <td style="padding:10px 14px;text-align:right;font-weight:700;color:#1f2330;font-size:14px;">$amountStr FCFA</td>
  </tr>
''');
    }
    if (dueDate != null && dueDate.isNotEmpty) {
      summaryRows.write('''
  <tr style="border-top:1px solid #eceef5;">
    <td style="padding:10px 14px;color:#66708a;font-size:13.5px;">Échéance</td>
    <td style="padding:10px 14px;text-align:right;font-weight:600;color:#1f2330;font-size:14px;">$dueDate</td>
  </tr>
''');
    }
    final summary = summaryRows.isEmpty
        ? ''
        : '''
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:18px 0;background:#f6f7fb;border-radius:12px;">
  $summaryRows
</table>
''';

    final finalContent = '''
<h2 style="margin:0 0 6px;font-size:19px;color:#1f2330;">Bonjour $clientName,</h2>
<p style="margin:0 0 16px;">Veuillez trouver ci-joint votre facture
<strong>$invoiceNumber</strong>${companyName != null && companyName.isNotEmpty ? ' émise par <strong>$companyName</strong>' : ''}.
$summary
${hasLink ? _cta('Télécharger la facture (PDF)', pdfLink.trim(), '#1A237E') : _infoBox('📎 &nbsp;La facture <strong>$invoiceNumber</strong> est jointe à cet e-mail au format PDF — ouvrez-la directement depuis votre messagerie.')}
${_infoBox('Une question sur cette facture ? Répondez simplement à cet e-mail : votre réponse arrive directement dans notre messagerie.')}
<p style="margin:22px 0 0;">Cordialement,<br><strong>${companyName != null && companyName.isNotEmpty ? companyName : _brand}</strong></p>
''';
    return _emailShell(
      heroTitle: 'Facture $invoiceNumber',
      heroBadge: '<p style="margin:0 0 12px;font-size:36px;">&#129534;</p>',
      contentHtml: finalContent,
    );
  }

  /// 📣 E-mail de RELANCE de paiement — ferme mais courtois : montant et
  /// jours de retard en évidence, instructions de règlement claires.
  /// [payLink] : lien de paiement en ligne facultatif (sinon, on invite le
  /// client à répondre — plus jamais de bouton pointant vers « # »).
  static String getPaymentReminderTemplate(
    String clientName,
    String invoiceNumber,
    double amount,
    int daysOverdue, {
    String? payLink,
    String? companyName,
  }) {
    final amountStr =
        amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
    final paySection = (payLink != null && payLink.trim().isNotEmpty)
        ? _cta('Régler maintenant', payLink.trim(), '#C2410C')
        : _infoBox(
            '💡 &nbsp;Pour régler cette facture, répondez simplement à cet e-mail : nous vous enverrons les moyens de paiement disponibles (virement, Mobile Money, espèces).');

    final content = '''
<h2 style="margin:0 0 6px;font-size:19px;color:#1f2330;">Bonjour $clientName,</h2>
<p style="margin:0 0 16px;">Sauf erreur de notre part, la facture
<strong>$invoiceNumber</strong> reste impayée à ce jour. Voici le récapitulatif :</p>

<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:18px 0;background:#fff7ed;border-radius:12px;">
  <tr>
    <td style="padding:12px 14px;color:#9a6a3f;font-size:13.5px;">Facture</td>
    <td style="padding:12px 14px;text-align:right;font-weight:700;color:#1f2330;font-size:14px;">$invoiceNumber</td>
  </tr>
  <tr style="border-top:1px solid #fbe3d2;">
    <td style="padding:12px 14px;color:#9a6a3f;font-size:13.5px;">Montant dû</td>
    <td style="padding:12px 14px;text-align:right;font-weight:700;color:#C2410C;font-size:15px;">$amountStr FCFA</td>
  </tr>
  <tr style="border-top:1px solid #fbe3d2;">
    <td style="padding:12px 14px;color:#9a6a3f;font-size:13.5px;">Retard</td>
    <td style="padding:12px 14px;text-align:right;font-weight:600;color:#1f2330;font-size:14px;">$daysOverdue jour${daysOverdue > 1 ? 's' : ''}</td>
  </tr>
</table>

<p style="margin:0 0 8px;">Si le règlement est déjà parti, merci d'ignorer ce message
— et de nous transmettre la référence du paiement pour que nous mettions votre
facture à jour.</p>
$paySection
<p style="margin:22px 0 0;">Bien à vous,<br><strong>${companyName != null && companyName.isNotEmpty ? companyName : _brand}</strong></p>
''';
    return _emailShell(
      heroTitle: 'Rappel — facture $invoiceNumber',
      accent: '#C2410C',
      accent2: '#EA580C',
      heroBadge: '<p style="margin:0 0 12px;font-size:36px;">&#9200;</p>',
      contentHtml: content,
    );
  }

  /// 📣 E-mail de RELANCE GÉNÉRIQUE (module Relance) : enveloppe n'importe
  /// quel message commercial (nouveau produit, promotion…) dans la coque
  /// de marque. [messageHtml] : contenu déjà formaté en HTML.
  static String getRelanceTemplate({
    required String clientName,
    required String title,
    required String messageHtml,
    String accent = '#1A237E',
    String accent2 = '#3949AB',
  }) {
    final content = '''
<h2 style="margin:0 0 6px;font-size:19px;color:#1f2330;">Bonjour $clientName,</h2>
<div style="font-size:15px;line-height:1.7;color:#333a4d;">
$messageHtml
</div>
<p style="margin:22px 0 0;">À votre service,<br><strong>$_brand</strong></p>
''';
    return _emailShell(
      heroTitle: title,
      accent: accent,
      accent2: accent2,
      contentHtml: content,
    );
  }
}
