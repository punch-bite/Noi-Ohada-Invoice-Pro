import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/team_permission.dart';
import '../models/team.dart';
import '../services/logger_service.dart';

class TeamPermissionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> setPermission({
    required String teamId,
    required String userId,
    required String resourceType,
    required String permissionLevel,
  }) async {
    try {
      // Vérifier si une permission existe déjà
      final existing = await _db
          .collection('team_permissions')
          .where('teamId', isEqualTo: teamId)
          .where('userId', isEqualTo: userId)
          .where('resourceType', isEqualTo: resourceType)
          .get();

      if (existing.docs.isNotEmpty) {
        await _db
            .collection('team_permissions')
            .doc(existing.docs.first.id)
            .update({
          'permissionLevel': permissionLevel,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final permission = TeamPermission(
          teamId: teamId,
          userId: userId,
          resourceType: resourceType,
          permissionLevel: permissionLevel,
        );
        await _db.collection('team_permissions').doc(permission.id).set(permission.toMap());
      }

      await LoggerService.info(
        'set_permission',
        details: 'Permission $permissionLevel pour $resourceType définie pour $userId dans $teamId',
        targetId: teamId,
        targetType: 'team',
      );
    } catch (e) {
      throw Exception('Erreur définition permission: $e');
    }
  }

  Future<TeamPermission?> getPermission({
    required String teamId,
    required String userId,
    required String resourceType,
  }) async {
    try {
      final snapshot = await _db
          .collection('team_permissions')
          .where('teamId', isEqualTo: teamId)
          .where('userId', isEqualTo: userId)
          .where('resourceType', isEqualTo: resourceType)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return TeamPermission.fromMap(snapshot.docs.first.data(), documentId: snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur getPermission: $e');
      return null;
    }
  }

  Future<bool> canAccessResource({
    required String teamId,
    required String userId,
    required String resourceType,
    required String action, // 'read' ou 'write'
  }) async {
    try {
      // Vérifier d'abord si l'utilisateur est membre de l'équipe
      final teamDoc = await _db.collection('teams').doc(teamId).get();
      if (!teamDoc.exists) return false;
      final team = Team.fromMap(teamDoc.data()!, documentId: teamDoc.id);

      // Propriétaire a tous les droits
      if (team.isOwnerOf(userId)) return true;

      // Admin a tous les droits
      if (team.isAdmin(userId)) return true;

      // Vérifier les permissions spécifiques
      final permission = await getPermission(teamId: teamId, userId: userId, resourceType: resourceType);
      if (permission == null) return false;

      if (action == 'read') return permission.canRead;
      if (action == 'write') return permission.canWrite;
      return false;
    } catch (e) {
      debugPrint('❌ Erreur canAccessResource: $e');
      return false;
    }
  }

  Future<List<TeamPermission>> getTeamPermissions(String teamId) async {
    try {
      final snapshot = await _db
          .collection('team_permissions')
          .where('teamId', isEqualTo: teamId)
          .get();
      return snapshot.docs.map((doc) => TeamPermission.fromMap(doc.data(), documentId: doc.id)).toList();
    } catch (e) {
      debugPrint('❌ Erreur getTeamPermissions: $e');
      return [];
    }
  }

  Future<void> removePermission(String permissionId) async {
    try {
      await _db.collection('team_permissions').doc(permissionId).delete();
      await LoggerService.info(
        'remove_permission',
        details: 'Permission $permissionId supprimée',
        targetId: permissionId,
        targetType: 'team_permission',
      );
    } catch (e) {
      throw Exception('Erreur suppression permission: $e');
    }
  }
}