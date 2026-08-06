// lib/services/reminder_service.dart
//
// ✅ Rappels de paiement — FIRESTORE (plus de Hive).
// Les rappels sont stockés dans la collection `reminders`, scopée par l'UID.
//
import 'package:flutter/foundation.dart';
import 'package:noi_ohada_invoice_pro/models/notification.dart';
import '../models/reminder.dart';
import '../models/invoice.dart';
import '../models/client.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class ReminderService {
  final DatabaseService _db = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  Future<void> init() async {
    // Firestore ne nécessite aucune initialisation locale.
    debugPrint('✅ ReminderService (Firestore)');
  }

  // ===== CRUD =====

  Future<List<Reminder>> getReminders() async {
    final reminders = await _db.getReminders();
    reminders.sort((a, b) => b.reminderDate.compareTo(a.reminderDate));
    return reminders;
  }

  Future<List<Reminder>> getPendingReminders() async {
    final all = await getReminders();
    return all
        .where((r) => r.reminderStatus == ReminderStatus.pending)
        .toList();
  }

  Future<List<Reminder>> getRemindersByInvoice(String invoiceId) async {
    final all = await getReminders();
    return all.where((r) => r.invoiceId == invoiceId).toList();
  }

  Future<Reminder?> getReminder(String id) async {
    final all = await getReminders();
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> addReminder(Reminder reminder) async {
    await _db.saveReminder(reminder);
    debugPrint('✅ Rappel ajouté pour la facture ${reminder.invoiceNumber}');
  }

  Future<void> updateReminder(Reminder reminder) async {
    await _db.saveReminder(reminder);
  }

  Future<void> deleteReminder(String id) async {
    await _db.deleteReminder(id);
  }

  // ===== CHECK ET ENVOI DES RAPPELS =====

  Future<void> checkAndSendReminders() async {
    final now = DateTime.now();
    final pendingReminders = await getPendingReminders();

    for (final reminder in pendingReminders) {
      // Vérifier si la date du rappel est atteinte
      if (reminder.reminderDate.isBefore(now) ||
          reminder.reminderDate.isAtSameMomentAs(now)) {
        await _sendReminder(reminder);
      }
    }
  }

  Future<void> _sendReminder(Reminder reminder) async {
    try {
      // Récupérer les informations de la facture
      final invoice = await _db.getInvoice(reminder.invoiceId);
      if (invoice == null) {
        throw Exception('Facture non trouvée');
      }

      // Vérifier si la facture est déjà payée
      if (invoice.status == 'paid') {
        // Marquer le rappel comme envoyé
        final updated = reminder.copyWith(
          status: ReminderStatus.sent.toString(),
          sentAt: DateTime.now(),
        );
        await updateReminder(updated);
        return;
      }

      // Récupérer le client
      final client = await _db.getClient(reminder.clientId);
      final clientName = client?.name ?? reminder.clientName;

      // Créer le message de rappel
      final message = _buildReminderMessage(reminder, clientName);

      // Envoyer la notification (Firestore)
      await _notificationService.addNotification(
        AppNotification(
          title: 'Rappel de paiement - ${reminder.invoiceNumber}',
          body: message,
          type: NotificationType.reminder.toString(),
          referenceId: reminder.invoiceId,
          referenceType: 'invoice',
        ),
      );

      // Marquer le rappel comme envoyé
      final updated = reminder.copyWith(
        status: ReminderStatus.sent.toString(),
        sentAt: DateTime.now(),
      );
      await updateReminder(updated);

      debugPrint('✅ Rappel envoyé pour la facture ${reminder.invoiceNumber}');
    } catch (e) {
      debugPrint('❌ Erreur envoi rappel: $e');
      final updated = reminder.copyWith(
        status: ReminderStatus.failed.toString(),
        errorMessage: e.toString(),
      );
      await updateReminder(updated);
    }
  }

  String _buildReminderMessage(Reminder reminder, String clientName) {
    final amount = reminder.amount.toStringAsFixed(0);
    final daysOverdue = DateTime.now().difference(reminder.dueDate).inDays;

    switch (reminder.reminderType) {
      case ReminderType.first:
        return '''
Bonjour $clientName,

Nous vous rappelons que la facture ${reminder.invoiceNumber} d'un montant de $amount FCFA est arrivée à échéance le ${_formatDate(reminder.dueDate)}.

Merci de procéder au règlement dans les plus brefs délais.

Cordialement,
OHADA Invoice Pro
''';
      case ReminderType.second:
        return '''
Bonjour $clientName,

Nous vous adressons un second rappel concernant la facture ${reminder.invoiceNumber} d'un montant de $amount FCFA.

Cette facture est en retard de $daysOverdue jours. Nous vous prions de régulariser votre situation dans les plus brefs délais.

Cordialement,
OHADA Invoice Pro
''';
      case ReminderType.final_warning:
        return '''
⚠️ DERNIER AVERTISSEMENT ⚠️

Bonjour $clientName,

Malgré nos précédents rappels, la facture ${reminder.invoiceNumber} d'un montant de $amount FCFA reste impayée.

Le retard est de $daysOverdue jours. Si nous ne recevons pas votre règlement sous 48h, nous serons dans l'obligation de prendre des mesures de recouvrement.

Cordialement,
OHADA Invoice Pro
''';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // ===== CRÉATION AUTOMATIQUE DE RAPPELS =====

  Future<void> createRemindersForInvoice(Invoice invoice, Client client) async {
    // Vérifier si la facture est impayée
    if (invoice.status == 'paid') return;

    // Vérifier si des rappels existent déjà
    final existingReminders = await getRemindersByInvoice(invoice.id);
    if (existingReminders.isNotEmpty) return;

    // Créer les rappels
    final reminders = [
      Reminder.createFirstReminder(
        invoiceId: invoice.id,
        invoiceNumber: invoice.invoiceNumber,
        clientId: invoice.clientId,
        clientName: client.name,
        amount: invoice.totalAmount,
        dueDate: invoice.dueDate,
      ),
      Reminder.createSecondReminder(
        invoiceId: invoice.id,
        invoiceNumber: invoice.invoiceNumber,
        clientId: invoice.clientId,
        clientName: client.name,
        amount: invoice.totalAmount,
        dueDate: invoice.dueDate,
      ),
      Reminder.createFinalWarning(
        invoiceId: invoice.id,
        invoiceNumber: invoice.invoiceNumber,
        clientId: invoice.clientId,
        clientName: client.name,
        amount: invoice.totalAmount,
        dueDate: invoice.dueDate,
      ),
    ];

    for (final reminder in reminders) {
      await addReminder(reminder);
    }

    debugPrint(
        '✅ ${reminders.length} rappels créés pour la facture ${invoice.invoiceNumber}');
  }

  // ===== NETTOYAGE =====

  Future<void> cleanSentReminders() async {
    final sentReminders =
        (await getReminders()).where((r) => r.reminderStatus == ReminderStatus.sent);

    for (final reminder in sentReminders) {
      // Supprimer les rappels envoyés après 30 jours
      if (reminder.sentAt != null &&
          DateTime.now().difference(reminder.sentAt!).inDays > 30) {
        await deleteReminder(reminder.id);
      }
    }
  }

  // ===== STATISTIQUES =====

  Future<int> getPendingCount() async {
    return (await getReminders())
        .where((r) => r.reminderStatus == ReminderStatus.pending)
        .length;
  }

  Future<int> getSentCount() async {
    return (await getReminders())
        .where((r) => r.reminderStatus == ReminderStatus.sent)
        .length;
  }

  Future<int> getFailedCount() async {
    return (await getReminders())
        .where((r) => r.reminderStatus == ReminderStatus.failed)
        .length;
  }
}
