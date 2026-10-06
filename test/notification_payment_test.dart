// test/notification_payment_test.dart
//
// 🧪 Garde-fou des notifications de PAIEMENT :
//   • UNE SEULE notification par paiement (la double notification
//     « Facture payée » + « Paiement reçu » multipliait les alertes) ;
//   • le montant figure dans le CORPS (chiffres exacts, plus de « paiement
//     reçu » trompeur pour un paiement CASH qui ne crédite pas le
//     portefeuille) ;
//   • le type est bien `invoice_paid` (l'ancienne chaîne 'payment_success'
//     n'existait pas dans l'enum → icône/couleur génériques dans l'écran
//     des notifications).
import 'package:flutter_test/flutter_test.dart';
import 'package:noi_ohada_invoice_pro/models/notification.dart';

void main() {
  group('AppNotification.createInvoicePaid · notification unique', () {
    test('sans montant : titre « Facture payée », pas de chiffre inventé', () {
      final n = AppNotification.createInvoicePaid('FAC-001');
      expect(n.title, 'Facture payée');
      expect(n.type, NotificationType.invoice_paid.name);
      expect(n.notificationType, NotificationType.invoice_paid);
      expect(n.body, contains('FAC-001'));
      expect(n.body, isNot(contains('FCFA')));
      expect(n.referenceType, 'invoice');
      expect(n.referenceId, 'FAC-001');
    });

    test('avec montant : le montant exact figure dans le corps', () {
      final n = AppNotification.createInvoicePaid('FAC-002', amount: 29500);
      expect(n.title, 'Facture payée');
      expect(n.body, contains('29500 FCFA'));
      expect(n.data?['amount'], 29500);
      expect(n.data?['currency'], 'FCFA');
    });

    test('montant décimal formaté à 2 chiffres', () {
      final n = AppNotification.createInvoicePaid('FAC-003', amount: 1250.5);
      expect(n.body, contains('1250.50 FCFA'));
    });

    test(
        'le type facture payée est TOUJOURS résolu (jamais de repli générique)',
        () {
      // Régression : l'ancien service utilisait la chaîne 'payment_success'
      // qui ne fait pas partie de l'enum → repli sur system_update (icône
      // générique dans l'écran des notifications).
      final bogus = AppNotification(
        title: 't',
        body: 'b',
        type: 'payment_success',
      );
      expect(bogus.notificationType, NotificationType.system_update);

      final n = AppNotification.createInvoicePaid('FAC-004');
      expect(n.notificationType, isNot(NotificationType.system_update));
      expect(n.notificationType, NotificationType.invoice_paid);
    });

    test("l'aller-retour Firestore conserve le type et le montant", () {
      final n = AppNotification.createInvoicePaid('FAC-005', amount: 45000);
      final restored = AppNotification.fromMap(n.toMap(), documentId: n.id);
      expect(restored.type, NotificationType.invoice_paid.name);
      expect(restored.data?['amount'], 45000);
      expect(restored.body, contains('45000 FCFA'));
    });
  });
}
