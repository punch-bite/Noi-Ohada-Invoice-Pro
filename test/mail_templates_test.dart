// test/mail_templates_test.dart
//
// 🧪 Garde-fous des E-MAILS de l'application (MailService) :
//   • tous les e-mails partagent la coque de marque (bandeau + footer
//     « Noi OHADA Invoice Pro » + lien support) ;
//   • la facture est JOINTE à l'e-mail : sans lien réel, le template
//     n'affiche JAMAIS de bouton mort pointant vers « # » ;
//   • le rappel de paiement met le montant et le retard en évidence ;
//   • la relance générique enveloppe le message commercial dans la marque.
//   • AUCUN template ne contient d'apostrophe échappée `\'` (rétrogression
//     d'encodage HTML qui affichait « d\'abord » aux clients).
import 'package:flutter_test/flutter_test.dart';
import 'package:noi_ohada_invoice_pro/services/mail_service.dart';

void main() {
  group('MailService · coque de marque commune', () {
    final templates = [
      MailService.getWelcomeTemplate('Alice'),
      MailService.getResetPasswordTemplate('Alice', 'https://x/reset'),
      MailService.getInvoiceTemplate('Bob', 'FAC-1', '', companyName: 'ACME'),
      MailService.getPaymentReminderTemplate('Bob', 'FAC-1', 29500, 5),
      MailService.getRelanceTemplate(
        clientName: 'Bob',
        title: 'Nouveauté',
        messageHtml: '<p>Un nouveau produit est disponible.</p>',
      ),
    ];

    test('tous les templates embarquent la marque et le lien support', () {
      for (final html in templates) {
        expect(html.contains('Noi OHADA Invoice Pro'), isTrue);
        expect(html.contains('invoicepro.noiconcept.com'), isTrue);
        expect(html.contains('SYSCOHADA'), isTrue);
      }
    });

    test('aucun template ne contient d\'apostrophe échappée (bug encodage)',
        () {
      for (final html in templates) {
        expect(html.contains(r"\'"), isFalse,
            reason:
                'rétrogression d\'encodage : séquence `\\\'` rendue au client');
      }
    });
  });

  group('MailService.getInvoiceTemplate · facture jointe', () {
    test('sans lien : pas de bouton mort, mention de la pièce jointe', () {
      final html = MailService.getInvoiceTemplate('Bob', 'FAC-2026-01', '');
      expect(html.contains('href="#"'), isFalse);
      expect(html.contains('jointe à cet e-mail'), isTrue);
      expect(html.contains('FAC-2026-01'), isTrue);
      expect(html.contains('ACME'), isFalse); // pas de signature inventée
    });

    test('avec lien réel : CTA de téléchargement présent', () {
      final html = MailService.getInvoiceTemplate(
        'Bob',
        'FAC-2026-01',
        'https://exemple.com/fac.pdf',
        companyName: 'ACME SARL',
      );
      expect(html.contains('https://exemple.com/fac.pdf'), isTrue);
      expect(html.contains('Télécharger la facture'), isTrue);
      expect(html.contains('ACME SARL'), isTrue);
    });

    test('récap : montant et échéance mis en évidence', () {
      final html = MailService.getInvoiceTemplate(
        'Bob',
        'FAC-2026-01',
        '',
        amount: 29500,
        dueDate: '14/02/2026',
      );
      expect(html.contains('29500 FCFA'), isTrue);
      expect(html.contains('14/02/2026'), isTrue);
      expect(html.contains('Montant total'), isTrue);
    });

    test('montant décimal formaté à 2 chiffres', () {
      final html = MailService.getInvoiceTemplate(
        'Bob',
        'FAC-2026-01',
        '',
        amount: 1250.5,
      );
      expect(html.contains('1250.50 FCFA'), isTrue);
    });
  });

  group('MailService.getPaymentReminderTemplate · relance paiement', () {
    test('sans lien de paiement : instructions de réponse, pas de bouton mort',
        () {
      final html =
          MailService.getPaymentReminderTemplate('Bob', 'FAC-9', 45000, 3);
      expect(html.contains('href="#"'), isFalse);
      expect(html.contains('45000 FCFA'), isTrue);
      expect(html.contains('3 jours'), isTrue);
      expect(html.contains('Régler maintenant'), isFalse);
    });

    test('avec lien de paiement : CTA « Régler maintenant »', () {
      final html = MailService.getPaymentReminderTemplate(
        'Bob',
        'FAC-9',
        45000,
        3,
        payLink: 'https://pay.exemple.com',
      );
      expect(html.contains('Régler maintenant'), isTrue);
      expect(html.contains('https://pay.exemple.com'), isTrue);
    });

    test('un seul jour de retard : accord singulier', () {
      final html =
          MailService.getPaymentReminderTemplate('Bob', 'FAC-9', 45000, 1);
      expect(html.contains('1 jour'), isTrue);
      expect(html.contains('1 jours'), isFalse);
    });
  });

  group('MailService.getRelanceTemplate · message commercial', () {
    test('le message libre est enveloppé dans la marque', () {
      final html = MailService.getRelanceTemplate(
        clientName: 'Bob',
        title: 'Nouveauté en stock',
        messageHtml: '<p><strong>Modem 4G</strong> — 45 000 FCFA</p>',
      );
      expect(html.contains('Bonjour Bob'), isTrue);
      expect(html.contains('Modem 4G'), isTrue);
      expect(html.contains('Nouveauté en stock'), isTrue);
    });
  });
}
