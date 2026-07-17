import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import '../models/shared_invoice.dart';
import '../models/team.dart';
import '../models/team_invitation.dart';
import '../services/notification_service.dart';
import '../services/logger_service.dart';

class TeamService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // ===== CRUD ÉQUIPES =====

  Future<Team> createTeam({
    required String name,
    required String description,
    required String ownerId,
    String? logoPath,
  }) async {
    try {
      final team = Team(
        name: name,
        description: description,
        ownerId: ownerId,
        memberIds: [ownerId],
        adminIds: [ownerId],
        logoPath: logoPath,
      );

      await _db.collection('teams').doc(team.id).set(team.toMap());

      await LoggerService.info(
        'create_team',
        details: 'Équipe $name créée par $ownerId',
        targetId: team.id,
        targetType: 'team',
      );

      return team;
    } catch (e) {
      throw Exception('Erreur création équipe: $e');
    }
  }

  Future<Team?> getTeam(String teamId) async {
    try {
      final doc = await _db.collection('teams').doc(teamId).get();
      if (doc.exists) {
        return Team.fromMap(doc.data()!, documentId: doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur getTeam: $e');
      return null;
    }
  }

  Future<void> updateTeam(Team team) async {
    try {
      await _db.collection('teams').doc(team.id).update(team.toMap());
      await LoggerService.info(
        'update_team',
        details: 'Équipe ${team.name} mise à jour',
        targetId: team.id,
        targetType: 'team',
      );
    } catch (e) {
      throw Exception('Erreur mise à jour équipe: $e');
    }
  }

  Future<void> deleteTeam(String teamId) async {
    try {
      await _db.collection('teams').doc(teamId).update({'isActive': false});
      await LoggerService.info(
        'delete_team',
        details: 'Équipe $teamId désactivée',
        targetId: teamId,
        targetType: 'team',
      );
    } catch (e) {
      throw Exception('Erreur suppression équipe: $e');
    }
  }

  // ===== GESTION DES MEMBRES =====

  Future<void> addMember(String teamId, String userId,
      {String role = 'member'}) async {
    try {
      final team = await getTeam(teamId);
      if (team == null) throw Exception('Équipe non trouvée');

      List<String> newMembers = List.from(team.memberIds);
      if (!newMembers.contains(userId)) {
        newMembers.add(userId);
      }

      List<String> newAdmins = List.from(team.adminIds);
      if (role == 'admin' && !newAdmins.contains(userId)) {
        newAdmins.add(userId);
      }

      await _db.collection('teams').doc(teamId).update({
        'memberIds': newMembers,
        'adminIds': newAdmins,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await LoggerService.info(
        'add_member',
        details: 'Utilisateur $userId ajouté à l\'équipe ${team.name}',
        targetId: teamId,
        targetType: 'team',
      );
    } catch (e) {
      throw Exception('Erreur ajout membre: $e');
    }
  }

  Future<void> removeMember(String teamId, String userId) async {
    try {
      final team = await getTeam(teamId);
      if (team == null) throw Exception('Équipe non trouvée');

      if (team.ownerId == userId) {
        throw Exception('Le propriétaire ne peut pas être retiré');
      }

      List<String> newMembers = List.from(team.memberIds)..remove(userId);
      List<String> newAdmins = List.from(team.adminIds)..remove(userId);

      await _db.collection('teams').doc(teamId).update({
        'memberIds': newMembers,
        'adminIds': newAdmins,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await LoggerService.info(
        'remove_member',
        details: 'Utilisateur $userId retiré de l\'équipe ${team.name}',
        targetId: teamId,
        targetType: 'team',
      );
    } catch (e) {
      throw Exception('Erreur retrait membre: $e');
    }
  }

  Future<void> promoteToAdmin(String teamId, String userId) async {
    try {
      final team = await getTeam(teamId);
      if (team == null) throw Exception('Équipe non trouvée');

      List<String> newAdmins = List.from(team.adminIds);
      if (!newAdmins.contains(userId)) {
        newAdmins.add(userId);
      }

      await _db.collection('teams').doc(teamId).update({
        'adminIds': newAdmins,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erreur promotion admin: $e');
    }
  }

  Future<void> demoteFromAdmin(String teamId, String userId) async {
    try {
      final team = await getTeam(teamId);
      if (team == null) throw Exception('Équipe non trouvée');

      if (team.ownerId == userId) {
        throw Exception('Le propriétaire ne peut pas être rétrogradé');
      }

      List<String> newAdmins = List.from(team.adminIds)..remove(userId);

      await _db.collection('teams').doc(teamId).update({
        'adminIds': newAdmins,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erreur rétrogradation admin: $e');
    }
  }

  // ===== INVITATIONS =====

  Future<TeamInvitation> inviteMember({
    required String teamId,
    required String invitedBy,
    required String invitedEmail,
    String role = 'member',
  }) async {
    try {
      final team = await getTeam(teamId);
      if (team == null) throw Exception('Équipe non trouvée');

      // Vérifier si une invitation existe déjà
      final existing = await _db
          .collection('team_invitations')
          .where('teamId', isEqualTo: teamId)
          .where('invitedEmail', isEqualTo: invitedEmail)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception('Une invitation est déjà en attente pour cet email');
      }

      final invitation = TeamInvitation(
        teamId: teamId,
        invitedBy: invitedBy,
        invitedEmail: invitedEmail,
        role: role,
        invitedUserId: '',
      );

      await _db
          .collection('team_invitations')
          .doc(invitation.id)
          .set(invitation.toMap());

      // Notification
      await _notificationService.addNotification(
        AppNotification(
          title: '📨 Invitation à rejoindre une équipe',
          body: 'Vous avez été invité à rejoindre l\'équipe ${team.name}',
          type: NotificationType.system_update.toString(),
          referenceId: invitation.id,
          referenceType: 'team_invitation',
        ),
      );

      await LoggerService.info(
        'invite_member',
        details:
            'Invitation envoyée à $invitedEmail pour l\'équipe ${team.name}',
        targetId: invitation.id,
        targetType: 'team_invitation',
      );

      return invitation;
    } catch (e) {
      throw Exception('Erreur invitation: $e');
    }
  }

  Future<void> acceptInvitation(String invitationId, String userId) async {
    try {
      final doc =
          await _db.collection('team_invitations').doc(invitationId).get();
      if (!doc.exists) throw Exception('Invitation non trouvée');

      final invitation =
          TeamInvitation.fromMap(doc.data()!, documentId: doc.id);

      if (invitation.isExpired) {
        await _db.collection('team_invitations').doc(invitationId).update({
          'status': 'expired',
          'respondedAt': FieldValue.serverTimestamp(),
        });
        throw Exception('Cette invitation a expiré');
      }

      if (!invitation.isPending) {
        throw Exception('Cette invitation a déjà été traitée');
      }

      // Mettre à jour l'invitation
      await _db.collection('team_invitations').doc(invitationId).update({
        'status': 'accepted',
        'invitedUserId': userId,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Ajouter le membre à l'équipe
      await addMember(invitation.teamId, userId, role: invitation.role);

      await LoggerService.info(
        'accept_invitation',
        details: 'Invitation $invitationId acceptée par $userId',
        targetId: invitationId,
        targetType: 'team_invitation',
      );
    } catch (e) {
      throw Exception('Erreur acceptation invitation: $e');
    }
  }

  Future<void> declineInvitation(String invitationId) async {
    try {
      await _db.collection('team_invitations').doc(invitationId).update({
        'status': 'declined',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      await LoggerService.info(
        'decline_invitation',
        details: 'Invitation $invitationId déclinée',
        targetId: invitationId,
        targetType: 'team_invitation',
      );
    } catch (e) {
      throw Exception('Erreur déclinaison invitation: $e');
    }
  }

  // ===== RÉCUPÉRATION =====

  Future<List<Team>> getUserTeams(String userId) async {
    try {
      final snapshot = await _db
          .collection('teams')
          .where('memberIds', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => Team.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getUserTeams: $e');
      return [];
    }
  }

  Future<List<TeamInvitation>> getUserInvitations(String userId) async {
    try {
      final snapshot = await _db
          .collection('team_invitations')
          .where('invitedEmail', isEqualTo: userId) // Ou email
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs
          .map((doc) => TeamInvitation.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getUserInvitations: $e');
      return [];
    }
  }

  Future<List<TeamInvitation>> getTeamInvitations(String teamId) async {
    try {
      final snapshot = await _db
          .collection('team_invitations')
          .where('teamId', isEqualTo: teamId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TeamInvitation.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getTeamInvitations: $e');
      return [];
    }
  }

  // Dans TeamService
  Future<List<TeamInvitation>> getSentInvitations(String userId) async {
    try {
      final snapshot = await _db
          .collection('team_invitations')
          .where('invitedBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => TeamInvitation.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getSentInvitations: $e');
      return [];
    }
  }

// Dans TeamService

  Future<void> shareInvoice({
    required String invoiceId,
    required String teamId,
    required String sharedBy,
    required List<String> sharedWith,
    String permissionLevel = 'read',
    DateTime? expiresAt,
  }) async {
    try {
      final sharedInvoice = SharedInvoice(
        invoiceId: invoiceId,
        teamId: teamId,
        sharedBy: sharedBy,
        sharedWith: sharedWith,
        permissionLevel: permissionLevel,
        expiresAt: expiresAt, sharedAt: DateTime.now(),
      );

      await _db
          .collection('shared_invoices')
          .doc(sharedInvoice.id)
          .set(sharedInvoice.toMap());

      await LoggerService.info(
        'share_invoice',
        details:
            'Facture $invoiceId partagée avec ${sharedWith.length} membres',
        targetId: invoiceId,
        targetType: 'invoice',
      );
    } catch (e) {
      throw Exception('Erreur partage facture: $e');
    }
  }

  Future<List<SharedInvoice>> getSharedInvoicesForUser(String userId) async {
    try {
      final snapshot = await _db
          .collection('shared_invoices')
          .where('sharedWith', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => SharedInvoice.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getSharedInvoicesForUser: $e');
      return [];
    }
  }

  Future<List<SharedInvoice>> getSharedInvoicesByTeam(String teamId) async {
    try {
      final snapshot = await _db
          .collection('shared_invoices')
          .where('teamId', isEqualTo: teamId)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => SharedInvoice.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getSharedInvoicesByTeam: $e');
      return [];
    }
  }

  Future<void> revokeSharedInvoice(String sharedId) async {
    try {
      await _db.collection('shared_invoices').doc(sharedId).update({
        'isActive': false,
        'expiresAt': FieldValue.serverTimestamp(),
      });

      await LoggerService.info(
        'revoke_shared_invoice',
        details: 'Partage de facture $sharedId révoqué',
        targetId: sharedId,
        targetType: 'shared_invoice',
      );
    } catch (e) {
      throw Exception('Erreur révocation partage: $e');
    }
  }

  
}
