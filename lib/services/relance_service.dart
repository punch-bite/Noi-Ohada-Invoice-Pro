// lib/services/relance_service.dart
//
// 📣 Module marketing payant : relance des clients (factures impayées,
// nouveau produit en stock, etc.) par notification toast, email,
// WhatsApp ou SMS. Réservé aux plans Pro / Business (`hasClientRelance`).
//
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import 'mail_service.dart';
import 'notification_service.dart';

enum RelanceChannel {
  email,
  whatsapp,
  sms,
  toast,
}

class RelanceService {
  final NotificationService _notificationService = NotificationService();

  // ===== ENVOI =====

  /// Relance un client par le canal choisi.
  /// [message] : texte personnalisé (facture, nouveau produit…).
  Future<bool> relanceClient({
    required Client client,
    required RelanceChannel channel,
    required String subject,
    required String message,
    Invoice? invoice,
  }) async {
    final phone = _normalizePhone(client.phone);
    switch (channel) {
      case RelanceChannel.email:
        return _sendEmail(client, subject, message);
      case RelanceChannel.whatsapp:
        return _launch(
            'https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
      case RelanceChannel.sms:
        return _launch('sms:$phone?body=${Uri.encodeComponent(message)}');
      case RelanceChannel.toast:
        await _notificationService.notify(
          type: 'relance',
          title: subject,
          body: message,
          refId: client.id,
          refType: 'client',
        );
        return true;
    }
  }

  /// Relance plusieurs clients à la fois (sélection multiple).
  Future<({int success, int failed})> relanceMany({
    required List<Client> clients,
    required RelanceChannel channel,
    required String subject,
    required String message,
  }) async {
    var success = 0;
    var failed = 0;
    for (final client in clients) {
      final ok = await relanceClient(
        client: client,
        channel: channel,
        subject: subject,
        message: message,
      );
      if (ok) {
        success++;
      } else {
        failed++;
      }
    }
    return (success: success, failed: failed);
  }

  // ===== MESSAGES PRÉDÉFINIS =====

  /// Message de relance pour une facture impayée (texte brut — WhatsApp/SMS).
  String buildInvoiceReminder(Invoice invoice, String clientName) {
    final days = DateTime.now().difference(invoice.dueDate).inDays;
    return 'Bonjour $clientName,\n\n'
        'Sauf erreur de notre part, la facture ${invoice.invoiceNumber} '
        'd\'un montant de ${invoice.totalAmount.toStringAsFixed(0)} FCFA '
        'est arrivée à échéance le ${_fmt(invoice.dueDate)}'
        '${days > 0 ? ' (soit $days jour${days > 1 ? 's' : ''} de retard)' : ''}.\n\n'
        'Si le règlement est déjà parti, merci de nous transmettre la '
        'référence du paiement pour mettre votre facture à jour.\n\n'
        'Bien à vous,\n'
        '— Noi OHADA Invoice Pro';
  }

  /// Message d'annonce d'un nouveau produit en stock (texte brut).
  String buildNewProductMessage(Product product) {
    return '🆕 Nouveauté disponible\n'
        '${product.name} — ${product.price.toStringAsFixed(0)} FCFA\n\n'
        'Découvrez-le en priorité : les stocks partent vite.\n\n'
        '— Noi OHADA Invoice Pro';
  }

  // ===== HELPERS =====

  /// 📣 Enveloppe le message dans la coque de marque professionnelle :
  /// l'e-mail de relance ressort au même design que les autres e-mails
  /// de l'application (bandeau, carte, footer).
  Future<bool> _sendEmail(Client client, String subject, String message,
      {String? title}) async {
    final email = client.email;
    if (email.isEmpty) return false;
    final html = MailService.getRelanceTemplate(
      clientName: client.name,
      title: (title != null && title.trim().isNotEmpty)
          ? title.trim()
          : subject.trim(),
      messageHtml: message.replaceAll('\n', '<br/>'),
    );
    // 🔄 Attend l'envoi réel : l'ancien code retournait true sans savoir si
    // l'e-mail était parti (succès fantôme dans le rapport de relance).
    return MailService.sendHtmlEmail(
      to: email,
      subject: subject,
      htmlBody: html,
    );
  }

  Future<bool> _launch(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Relance: $e');
      return false;
    }
  }

  /// Normalise un numéro de téléphone pour WhatsApp (format international).
  String _normalizePhone(String phone) {
    var p = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (p.startsWith('00')) p = '+${p.substring(2)}';
    if (!p.startsWith('+')) p = '+$p';
    return p;
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Partage un message via la feuille de partage (repli universel).
  Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
