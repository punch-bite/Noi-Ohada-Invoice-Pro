// lib/models/team_message.dart
//
// CHANGELOG (SaaS) :
//   • Ajout `companyId` (audit SaaS — permet de scoper/filtrer côté serveur
//     si un jour on étend les règles Firestore pour vérifier la company).
//   • Ajout `updatedAt` (futur édition/suppression de message).
//   • Aucun changement de format : les anciens messages (sans ces champs)
//     restent valides via les valeurs par défaut.
//
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamMessage {
  final String id;
  final String teamId;
  final String senderId;
  final String senderName;

  /// 🔑 PROPRIÉTAIRE DU MESSAGE — estampillé à l'envoi :
  /// • par défaut, le PROPRIÉTAIRE de l'équipe (celui à qui appartiennent la
  ///   conversation et les fichiers partagés) ;
  /// • à défaut, l'expéditeur lui-même.
  /// Les messages antérieurs (sans ces champs) retombent sur [senderId] /
  /// [senderName] — aucune migration n'est nécessaire.
  final String ownerId;
  final String ownerName;

  /// 🔑 Entreprise propriétaire du message (audit SaaS).
  /// Optionnel — lu par les règles Firestore avancées le cas échéant.
  final String? companyId;

  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TeamMessage({
    required this.id,
    required this.teamId,
    required this.senderId,
    required this.senderName,
    this.ownerId = '',
    this.ownerName = '',
    this.companyId,
    required this.text,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'teamId': teamId,
        'senderId': senderId,
        'senderName': senderName,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'companyId': companyId,
        'text': text,
        // Timestamp stocké en millisecondes : sérialisable tel quel dans
        // Firestore ET dans la box Hive locale (aucune conversion perdue).
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
      };

  factory TeamMessage.fromMap(Map<String, dynamic> map, {String? documentId}) {
    final created = map['createdAt'];
    final updated = map['updatedAt'];
    final senderId = map['senderId']?.toString() ?? '';
    final senderName = map['senderName']?.toString() ?? 'Membre';
    return TeamMessage(
      id: documentId ?? map['id']?.toString() ?? '',
      teamId: map['teamId']?.toString() ?? '',
      senderId: senderId,
      senderName: senderName,
      // 🔁 Rétro-compatibilité : les messages envoyés AVANT l'ajout du
      // propriétaire retombent sur l'expéditeur (jamais vides).
      ownerId: map['ownerId']?.toString().isNotEmpty == true
          ? map['ownerId'].toString()
          : senderId,
      ownerName: map['ownerName']?.toString().isNotEmpty == true
          ? map['ownerName'].toString()
          : senderName,
      companyId: map['companyId']?.toString(),
      text: map['text']?.toString() ?? '',
      createdAt: _parseDate(created) ?? DateTime.now(),
      updatedAt: _parseDate(updated),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  TeamMessage copyWith({
    String? text,
    DateTime? updatedAt,
  }) {
    return TeamMessage(
      id: id,
      teamId: teamId,
      senderId: senderId,
      senderName: senderName,
      ownerId: ownerId,
      ownerName: ownerName,
      companyId: companyId,
      text: text ?? this.text,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}