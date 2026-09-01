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
  final String text;
  final DateTime createdAt;

  const TeamMessage({
    required this.id,
    required this.teamId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'teamId': teamId,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        // Timestamp stocké en millisecondes : sérialisable tel quel dans
        // Firestore ET dans la box Hive locale (aucune conversion perdue).
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory TeamMessage.fromMap(Map<String, dynamic> map, {String? documentId}) {
    final created = map['createdAt'];
    return TeamMessage(
      id: documentId ?? map['id']?.toString() ?? '',
      teamId: map['teamId']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? 'Membre',
      text: map['text']?.toString() ?? '',
      createdAt: created is Timestamp
          ? created.toDate()
          : created is int
              ? DateTime.fromMillisecondsSinceEpoch(created)
              : DateTime.tryParse('${created ?? ''}') ?? DateTime.now(),
    );
  }
}
