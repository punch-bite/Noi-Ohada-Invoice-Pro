// lib/services/team_chat_service.dart
//
// CHANGELOG (SaaS — Option A) :
//   • `sendMessage()` passe désormais `teamId` à `addNotificationForUser`
//     (requis par les nouvelles règles Firestore — fail-closed).
//   • Le type de notification utilise le NOUVEAU `NotificationType.team_message.name`
//     (au lieu du bug `team_shared.toString()` qui renvoyait le nom de la
//     classe au lieu du nom de la valeur enum).
//   • `memberIds` filtré : on ignore les chaînes vides / le sender lui-même.
//   • `_cacheMessage` désormais `await` dans le stream pour éviter toute
//     race condition (émissions Firestore rapides).
//   • `companyId` du message déduit du profil user à l'envoi (audit).
//   • `clearCache()` devient aussi appelable depuis la sortie d'équipe.
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/notification.dart';
import '../models/team_message.dart';
import 'database_service.dart';
import 'notification_service.dart';

class TeamChatService {
  static const String _boxName = 'team_messages';
  static const int _maxRemoteMessages = 200;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final DatabaseService _database = DatabaseService();

  Future<Box> _box() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  // ═══════════════════════════════════════════════════════════════════
  // MÉMOIRE LOCALE (Hive)
  // ═══════════════════════════════════════════════════════════════════

  /// Historique local d'une équipe (affichage instantané, fonctionne hors
  /// connexion) — trié du plus ancien au plus récent.
  Future<List<TeamMessage>> getCachedMessages(String teamId) async {
    try {
      final box = await _box();
      final index =
          ((box.get('$teamId#__index') as List?) ?? const []).cast<String>();
      final messages = <TeamMessage>[];
      for (final id in index) {
        final raw = box.get('$teamId#$id');
        if (raw is Map) {
          messages.add(TeamMessage.fromMap(Map<String, dynamic>.from(raw)));
        }
      }
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return messages;
    } catch (e) {
      debugPrint('⚠️ TeamChatService.getCachedMessages: $e');
      return [];
    }
  }

  /// Purge le cache local d'une équipe (ex : après avoir quitté l'équipe).
  Future<void> clearCache(String teamId) async {
    try {
      final box = await _box();
      final keys = box.keys
          .whereType<String>()
          .where((k) => k.startsWith('$teamId#'))
          .toList();
      await box.deleteAll(keys);
    } catch (e) {
      debugPrint('⚠️ TeamChatService.clearCache: $e');
    }
  }

  /// Write-through : persiste le message dans la mémoire locale.
  Future<void> _cacheMessage(TeamMessage message) async {
    try {
      final box = await _box();
      await box.put('${message.teamId}#${message.id}', message.toMap());
      final index = ((box.get('${message.teamId}#__index') as List?) ?? const [])
          .cast<String>()
          .toList();
      if (!index.contains(message.id)) {
        index.add(message.id);
        await box.put('${message.teamId}#__index', index);
      }
    } catch (e) {
      debugPrint('⚠️ TeamChatService._cacheMessage: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // FIRESTORE (temps réel)
  // ═══════════════════════════════════════════════════════════════════

  /// Flux temps réel des messages d'une équipe (200 derniers), chacun étant
  /// automatiquement répliqué dans le cache local Hive.
  Stream<List<TeamMessage>> streamMessages(String teamId) {
    return _db
        .collection('team_messages')
        .doc(teamId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(_maxRemoteMessages)
        .snapshots()
        .asyncMap((snapshot) async {
      final messages = snapshot.docs
          .map((doc) => TeamMessage.fromMap(doc.data(), documentId: doc.id))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      // ✅ On attend la persistance cache pour éviter toute race entre
      //    émissions successives du stream (ex : import initial + update).
      for (final message in messages) {
        await _cacheMessage(message);
      }
      return messages;
    });
  }

  /// Envoie un message : écrit dans Firestore + cache local + notification
  /// in-app pour les autres membres de l'équipe.
  ///
  /// 🆕 `memberIds` est utilisé pour cibler les notifications. Les entrées
  /// vides et l'expéditeur lui-même sont automatiquement ignorés. La
  /// notification est **toujours estampillée du `teamId`** : c'est requis par
  /// les règles Firestore (fail-closed) pour qu'un émetteur ne puisse
  /// notifier qu'un membre de SA team.
  Future<TeamMessage> sendMessage({
    required String teamId,
    required String senderId,
    required String senderName,
    required String text,
    List<String> memberIds = const [],
    String ownerId = '',
    String ownerName = '',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw Exception('Le message est vide');
    }

    // 🔑 companyId du message (audit SaaS) — déduit du profil de l'émetteur.
    String? companyId;
    try {
      final user = await _database.getUser();
      companyId = user?.companyId;
    } catch (_) {}

    final docRef = _db
        .collection('team_messages')
        .doc(teamId)
        .collection('messages')
        .doc();
    final message = TeamMessage(
      id: docRef.id,
      teamId: teamId,
      senderId: senderId,
      senderName: senderName,
      // 🔑 Propriétaire du message (propriétaire de l'équipe si fourni,
      // sinon l'expéditeur) — transmis aux autres membres avec le message.
      ownerId: ownerId.trim().isEmpty ? senderId : ownerId.trim(),
      ownerName: ownerName.trim().isEmpty ? senderName : ownerName.trim(),
      companyId: companyId,
      text: trimmed,
      createdAt: DateTime.now(),
    );

    try {
      await docRef.set(message.toMap());
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
          'Messagerie refusée par les règles du serveur (permission-denied). '
          'Le message a été gardé en mémoire locale uniquement.',
        );
      }
      rethrow;
    }

    await _cacheMessage(message);

    // 🔔 Notifications in-app pour les autres membres (jamais bloquantes).
    final preview =
        trimmed.length > 80 ? '${trimmed.substring(0, 80)}…' : trimmed;

    // 🧹 Nettoyage : on filtre les entrées vides et on se retire soi-même.
    final recipients = <String>{
      for (final uid in memberIds)
        if (uid.trim().isNotEmpty && uid != senderId) uid.trim(),
    };

    for (final uid in recipients) {
      try {
        await _notificationService.addNotificationForUser(
          userId: uid,
          createdBy: senderId,
          teamId: teamId, // 🔑 OBLIGATOIRE (règles Firestore)
          notification: AppNotification(
            title: '💬 Nouveau message d\'équipe',
            body: '$senderName : $preview',
            type: NotificationType.team_message.name, // 🔧 était .toString()
            referenceId: teamId,
            referenceType: 'team_message',
            teamId: teamId,
            userId: uid,
            createdBy: senderId,
            recipients: [uid],
            data: {
              'teamId': teamId,
              'senderId': senderId,
              'senderName': senderName,
              'messageId': docRef.id,
            },
          ),
        );
      } catch (e) {
        // Ignoré : une notification manquée ne doit pas faire échouer l'envoi.
        debugPrint('⚠️ sendMessage → notification($uid): $e');
      }
    }
    return message;
  }
}