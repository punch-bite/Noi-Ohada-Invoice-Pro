// lib/models/team_message.dart
//
// 💬 Message de la messagerie d'équipe — stocké dans Firestore
// (team_messages/{teamId}/messages/{id}) ET en cache local Hive
// (box `team_messages`) pour un affichage instantané / hors-ligne.

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

  final String text;
  final DateTime createdAt;

  const TeamMessage({
    required this.id,
    required this.teamId,
    required this.senderId,
    required this.senderName,
    this.ownerId = '',
    this.ownerName = '',
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'teamId': teamId,
        'senderId': senderId,
        'senderName': senderName,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'text': text,
        // Timestamp stocké en millisecondes : sérialisable tel quel dans
        // Firestore ET dans la box Hive locale (aucune conversion perdue).
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory TeamMessage.fromMap(Map<String, dynamic> map, {String? documentId}) {
    final created = map['createdAt'];
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
      text: map['text']?.toString() ?? '',
      createdAt: created is Timestamp
          ? created.toDate()
          : created is int
              ? DateTime.fromMillisecondsSinceEpoch(created)
              : DateTime.tryParse('${created ?? ''}') ?? DateTime.now(),
    );
  }
}
