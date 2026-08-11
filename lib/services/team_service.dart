import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import '../models/shared_invoice.dart';
import '../models/team.dart';
import '../models/team_invitation.dart';
import '../services/notification_service.dart';
import '../services/logger_service.dart';
import '../services/mail_service.dart';

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

      // 📧 Email d'invitation (best-effort) : envoi via MailService (SMTP
      // local ou serveur /email/send). Un échec d'email ne doit PAS
      // annuler l'invitation (elle reste accessible in-app).
      try {
        // Lien d'acceptation : l'invité devra être connecté pour rejoindre
        // l'équipe ; on cible la liste des invitations de son compte.
        const acceptLink =
            'https://ohada-invoice-pro.com/teams/invitations';
        await MailService.sendHtmlEmail(
          to: invitedEmail,
          subject: '📨 Invitation à rejoindre l\'équipe ${team.name}',
          htmlBody: MailService.getTeamInvitationTemplate(
            inviterName: 'Un administrateur',
            teamName: team.name,
            acceptLink: acceptLink,
            roleLabel: role == 'admin' ? 'Administrateur' : 'Membre',
          ),
        );
      } catch (e) {
        debugPrint('⚠️ Envoi email d\'invitation échoué (best-effort) : $e');
      }

      // Notification in-app
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

  /// Partage une ressource (facture / produit / client) avec des membres de
  /// l'équipe. Écrit un enregistrement `shared_invoices` (compatibilité avec
  /// l'existant, champ `resourceType`), marque la ressource comme partagée
  /// (lecture autorisée pour les membres via les règles Firestore) et envoie
  /// une notification @mention à chaque destinataire.
  Future<SharedInvoice> shareResource({
    required String resourceId,
    required String resourceType, // 'invoice' | 'product' | 'client'
    required String resourceName,
    required String teamId,
    required String sharedBy,
    required List<String> sharedWith,
    String permissionLevel = 'read',
    DateTime? expiresAt,
  }) async {
    final sharedInvoice = SharedInvoice(
      invoiceId: resourceId,
      teamId: teamId,
      sharedBy: sharedBy,
      sharedWith: sharedWith,
      permissionLevel: permissionLevel,
      expiresAt: expiresAt,
      sharedAt: DateTime.now(),
      resourceType: resourceType,
      resourceName: resourceName,
    );

    await _db
        .collection('shared_invoices')
        .doc(sharedInvoice.id)
        .set(sharedInvoice.toMap());

    // Marque la ressource pour que les membres puissent la lire.
    await _markResourceShared(
      resourceType,
      resourceId,
      sharedWith,
      teamId,
    );

    // Notifications @mention aux destinataires.
    await _notifyMentioned(
      resourceType: resourceType,
      resourceName: resourceName,
      teamId: teamId,
      sharedBy: sharedBy,
      sharedWith: sharedWith,
      resourceId: resourceId,
    );

    await LoggerService.info(
      'share_resource',
      details:
          '$resourceType $resourceId partagé avec ${sharedWith.length} membres',
      targetId: resourceId,
      targetType: resourceType,
    );

    return sharedInvoice;
  }

  /// Wrapper rétro-compatible : partage d'une facture.
  Future<void> shareInvoice({
    required String invoiceId,
    required String teamId,
    required String sharedBy,
    required List<String> sharedWith,
    String permissionLevel = 'read',
    DateTime? expiresAt,
  }) async {
    await shareResource(
      resourceId: invoiceId,
      resourceType: 'invoice',
      resourceName: invoiceId,
      teamId: teamId,
      sharedBy: sharedBy,
      sharedWith: sharedWith,
      permissionLevel: permissionLevel,
      expiresAt: expiresAt,
    );
  }

  /// Met à jour le document ressource (invoices/products/clients) avec les
  /// listes `sharedWithUsers` / `sharedTeams` pour que les règles Firestore
  /// autorisent la lecture par les membres.
  Future<void> _markResourceShared(
    String resourceType,
    String resourceId,
    List<String> userIds,
    String teamId,
  ) async {
    final collection = _collectionFor(resourceType);
    if (collection.isEmpty) return;
    try {
      final ref = _db.collection(collection).doc(resourceId);
      final snap = await ref.get();
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final users = Set<String>.from(data['sharedWithUsers'] ?? const [])
        ..addAll(userIds);
      final teams = Set<String>.from(data['sharedTeams'] ?? const [])
        ..add(teamId);
      await ref.update({
        'sharedWithUsers': users.toList(),
        'sharedTeams': teams.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ _markResourceShared: $e');
    }
  }

  /// Notifications @mention pour chaque membre mentionné dans le partage.
  Future<void> _notifyMentioned({
    required String resourceType,
    required String resourceName,
    required String teamId,
    required String sharedBy,
    required List<String> sharedWith,
    required String resourceId,
  }) async {
    final sharerName = await _userDisplayName(sharedBy);
    final team = await getTeam(teamId);
    final teamName = team?.name ?? 'votre équipe';
    final label = _resourceLabel(resourceType);

    for (final uid in sharedWith) {
      if (uid.isEmpty || uid == sharedBy) continue;
      await _notificationService.addNotificationForUser(
        userId: uid,
        createdBy: sharedBy,
        notification: AppNotification(
          title: '🔗 Donnée partagée avec vous',
          body:
              '$sharerName vous a partagé « $resourceName » ($label) dans $teamName.',
          type: NotificationType.team_shared.toString(),
          referenceId: resourceId,
          referenceType: resourceType,
          data: {
            'teamId': teamId,
            'resourceType': resourceType,
            'sharedBy': sharedBy,
            'sharedByName': sharerName,
          },
        ),
      );
    }
  }

  /// Récupère les partages reçus par un utilisateur, tous types confondus
  /// (ou filtrés par [resourceType]).
  Future<List<SharedInvoice>> getSharedResourcesForUser(
    String userId, {
    String? resourceType,
  }) async {
    try {
      var query = _db
          .collection('shared_invoices')
          .where('sharedWith', arrayContains: userId)
          .where('isActive', isEqualTo: true);
      if (resourceType != null) {
        query = query.where('resourceType', isEqualTo: resourceType);
      }
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => SharedInvoice.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getSharedResourcesForUser: $e');
      return [];
    }
  }

  /// Récupère les partages d'une équipe, tous types (ou filtrés par
  /// [resourceType]).
  Future<List<SharedInvoice>> getSharedResourcesByTeam(
    String teamId, {
    String? resourceType,
  }) async {
    try {
      var query = _db
          .collection('shared_invoices')
          .where('teamId', isEqualTo: teamId)
          .where('isActive', isEqualTo: true);
      if (resourceType != null) {
        query = query.where('resourceType', isEqualTo: resourceType);
      }
      final snapshot = await query
          .orderBy('sharedAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => SharedInvoice.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getSharedResourcesByTeam: $e');
      return [];
    }
  }

  /// Statistiques de partage d'une équipe (par type + montant total des
  /// factures partagées lisible par l'appelant).
  Future<Map<String, dynamic>> getTeamShareStats(String teamId) async {
    final shares = await getSharedResourcesByTeam(teamId);
    final byType = <String, int>{};
    final distinctIds = <String, Set<String>>{};
    for (final s in shares) {
      final t = s.resourceType;
      byType[t] = (byType[t] ?? 0) + 1;
      distinctIds.putIfAbsent(t, () => {}).add(s.invoiceId);
    }

    // Montant total des factures partagées (les docs sont lisibles par les
    // membres grâce à sharedWithUsers).
    double totalAmount = 0;
    final invoiceIds = distinctIds['invoice'] ?? {};
    for (final id in invoiceIds) {
      try {
        final doc =
            await _db.collection('invoices').doc(id).get();
        if (!doc.exists) continue;
        final data = doc.data() ?? {};
        final amt = (data['total'] as num?)?.toDouble() ??
            (data['totalAmount'] as num?)?.toDouble() ??
            0;
        totalAmount += amt;
      } catch (_) {
        // Ignoré : doc non lisible (pas encore marqué partagé).
      }
    }

    return {
      'totalShares': shares.length,
      'invoices': byType['invoice'] ?? 0,
      'products': byType['product'] ?? 0,
      'clients': byType['client'] ?? 0,
      'distinctInvoices': distinctIds['invoice']?.length ?? 0,
      'distinctProducts': distinctIds['product']?.length ?? 0,
      'distinctClients': distinctIds['client']?.length ?? 0,
      'totalAmount': totalAmount,
    };
  }

  /// Profils des membres d'une équipe : { uid → {email, name} }.
  Future<Map<String, Map<String, String>>> getMemberProfiles(
    String teamId,
  ) async {
    final team = await getTeam(teamId);
    final result = <String, Map<String, String>>{};
    if (team == null) return result;
    final ids = <String>{
      team.ownerId,
      ...team.adminIds,
      ...team.memberIds,
    };
    for (final uid in ids) {
      if (uid.isEmpty || result.containsKey(uid)) continue;
      try {
        final doc = await _db.collection('users').doc(uid).get();
        final data = doc.data() ?? {};
        result[uid] = {
          'email': data['email']?.toString() ?? '',
          'name': data['displayName']?.toString() ??
              data['name']?.toString() ??
              '',
        };
      } catch (_) {
        result[uid] = {'email': '', 'name': ''};
      }
    }
    return result;
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

  // ===== HELPERS =====

  String _collectionFor(String resourceType) {
    switch (resourceType) {
      case 'product':
        return 'products';
      case 'client':
        return 'clients';
      case 'invoice':
      default:
        return 'invoices';
    }
  }

  String _resourceLabel(String resourceType) {
    switch (resourceType) {
      case 'product':
        return 'produit';
      case 'client':
        return 'client';
      case 'invoice':
      default:
        return 'facture';
    }
  }

  Future<String> _userDisplayName(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      final data = doc.data();
      return data?['displayName']?.toString() ??
          data?['name']?.toString() ??
          'Un membre';
    } catch (_) {
      return 'Un membre';
    }
  }
}
