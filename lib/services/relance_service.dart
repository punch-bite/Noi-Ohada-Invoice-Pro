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
    final phone = _normalizePhone(client.phone ?? '');
    switch (channel) {
      case RelanceChannel.email:
        return _sendEmail(client, subject, message);
      case RelanceChannel.whatsapp:
        return _launch('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
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

  /// Message de relance pour une facture impayée.
  String buildInvoiceReminder(Invoice invoice, String clientName) {
    return 'Bonjour $clientName,\n\n'
        'Nous vous rappelons que la facture ${invoice.invoiceNumber} '
        'd\'un montant de ${invoice.totalAmount.toStringAsFixed(0)} FCFA '
        'est arrivée à échéance le ${_fmt(invoice.dueDate)}.\n\n'
        'Merci de procéder au règlement.\n'
        '— OHADA Invoice Pro';
  }

  /// Message d'annonce d'un nouveau produit en stock.
  String buildNewProductMessage(Product product) {
    return '🆕 Nouveau produit disponible : ${product.name}\n'
        'Prix : ${product.price.toStringAsFixed(0)} FCFA\n\n'
        'Rendez-vous vite pour le découvrir ! — OHADA Invoice Pro';
  }

  // ===== HELPERS =====

  bool _sendEmail(Client client, String subject, String message) {
    final email = client.email ?? '';
    if (email.isEmpty) return false;
    // MailService.sendHtmlEmail est statique.
    MailService.sendHtmlEmail(
      to: email,
      subject: subject,
      htmlBody: '<p style="font-family:sans-serif">'
          '${message.replaceAll('\n', '<br/>')}</p>',
    );
    return true;
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
