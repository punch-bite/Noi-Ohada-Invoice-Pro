// lib/services/team_chat_service.dart
//
// 💬 MESSAGERIE INSTANTANÉE D'ÉQUIPE.
//
// • Distant  : Firestore `team_messages/{teamId}/messages` — flux temps réel.
// • MÉMOIRE LOCALE : chaque message (reçu ou envoyé) est mis en cache dans une
//   box Hive `team_messages` (clé `teamId#msgId` + index ordonné par équipe),
//   si bien que l'historique s'affiche INSTANTANÉMENT à l'ouverture du chat —
//   même hors connexion — et persiste entre les sessions.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/notification.dart';
import '../models/team_message.dart';
import 'notification_service.dart';

class TeamChatService {
  static const String _boxName = 'team_messages';
  static const int _maxRemoteMessages = 200;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  Future<Box> _box() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  // ===== MÉMOIRE LOCALE (Hive) =====

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

  // ===== FIRESTORE (temps réel) =====

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
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => TeamMessage.fromMap(doc.data(), documentId: doc.id))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final message in messages) {
        _cacheMessage(message);
      }
      return messages;
    });
  }

  /// Envoie un message : écrit dans Firestore + cache local + notification
  /// in-app pour les autres membres de l'équipe.
  Future<TeamMessage> sendMessage({
    required String teamId,
    required String senderId,
    required String senderName,
    required String text,
    List<String> memberIds = const [],
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw Exception('Le message est vide');
    }

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

    // 🔔 Notification in-app pour chaque autre membre (jamais bloquante).
    final preview =
        trimmed.length > 80 ? '${trimmed.substring(0, 80)}…' : trimmed;
    for (final uid in memberIds) {
      if (uid.isEmpty || uid == senderId) continue;
      try {
        await _notificationService.addNotificationForUser(
          userId: uid,
          createdBy: senderId,
          notification: AppNotification(
            title: '💬 Nouveau message d\'équipe',
            body: '$senderName : $preview',
            type: NotificationType.team_shared.toString(),
            referenceId: teamId,
            referenceType: 'team_message',
            data: {'teamId': teamId, 'senderId': senderId},
          ),
        );
      } catch (_) {
        // Ignoré : une notification manquée ne doit pas faire échouer l'envoi.
      }
    }
    return message;
  }
}
