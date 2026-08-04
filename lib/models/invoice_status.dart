// lib/models/invoice_status.dart
import 'package:flutter/material.dart';

/// Énumération du cycle de vie d'une facture.
///
/// Contrairement aux paiements en ligne (NochPay réservé aux abonnements),
/// le cycle de facturation est validé **manuellement** par le commerçant :
///   brouillon → envoyée → en retard → payée
/// Chaque transition est effectuée à la main via une validation énumérée.
enum InvoiceStatus {
  /// Brouillon : facture créée mais pas encore envoyée au client.
  draft('draft', 'Brouillon'),

  /// Envoyée (en attente) : facture remise au client, en attente de paiement.
  sent('sent', 'En attente'),

  /// En retard : la date d'échéance est dépassée sans paiement reçu.
  overdue('overdue', 'En retard'),

  /// Payée : le commerçant a confirmé manuellement la réception du paiement.
  paid('paid', 'Payée'),

  /// Annulée : la facture a été annulée.
  cancelled('cancelled', 'Annulée');

  const InvoiceStatus(this.value, this.label);

  /// Valeur persistée (compatible avec le champ `status` du modèle Invoice).
  final String value;

  /// Libellé affiché à l'utilisateur.
  final String label;

  /// Convertit une valeur stockée (String) en énumération.
  static InvoiceStatus fromValue(String? value) {
    for (final status in InvoiceStatus.values) {
      if (status.value == value) return status;
    }
    return InvoiceStatus.draft;
  }

  /// Convertit une valeur stockée (String) en libellé.
  static String labelFromValue(String? value) => fromValue(value).label;

  bool get isPaid => this == InvoiceStatus.paid;
  bool get isCancelled => this == InvoiceStatus.cancelled;
  bool get isOverdue => this == InvoiceStatus.overdue;

  /// Couleur associée au statut (utilisée dans les badges UI).
  Color get color {
    switch (this) {
      case InvoiceStatus.paid:
        return Colors.green;
      case InvoiceStatus.sent:
        return Colors.orange;
      case InvoiceStatus.overdue:
        return Colors.red;
      case InvoiceStatus.cancelled:
        return Colors.grey;
      case InvoiceStatus.draft:
        return Colors.blueGrey;
    }
  }
}
