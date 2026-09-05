import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/notification.dart';
import '../models/shared_invoice.dart';
import '../models/team.dart';
import '../services/notification_service.dart';
import '../services/logger_service.dart';
import 'config_service.dart';

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

  // ===== GESTION DES MEMBRES (via serveur = SDK admin) =====
  //
  // 🔒 Les règles Firestore n'autorisent QUE le propriétaire (ou l'admin
  // global) à modifier le document `teams`, et interdisent de résoudre un
  // email → UID (lecture `users` restreinte) ou de révoquer l'accès d'un
  // membre sur les ressources des autres. Toute la gestion des membres
  // passe donc par le serveur (POST /team/manage-member) qui utilise le
  // SDK admin (contourne les règles) et gère la révocation d'accès.

  /// Traduit une erreur réseau/serveur en message UTILISATEUR lisible —
  /// au lieu d'un « Exception: … » brut qui ne dit rien.
  static String prettyError(Object error) {
    var message = error.toString();
    if (message.startsWith('Exception: ')) message = message.substring(11);
    return message;
  }

  /// Extrait un extrait de corps de réponse (pour le diagnostic).
  static String _excerpt(String body) {
    final cleaned = body.trim().replaceAll('\n', ' ');
    return cleaned.length > 120 ? '${cleaned.substring(0, 120)}…' : cleaned;
  }

  Future<Map<String, dynamic>> _manageMember({
    required String action,
    required String teamId,
    String? userId,
    String? email,
    String? role,
    String? invitationId,
    required String requestedBy,
  }) async {
    final apiBase = ConfigService.apiBaseUrl.trim();
    if (apiBase.isEmpty) {
      throw Exception('Serveur non configuré (API_BASE_URL manquante).');
    }
    final http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse('$apiBase/team/manage-member'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': action,
              'teamId': teamId,
              'userId': userId,
              'email': email,
              'role': role,
              'invitationId': invitationId,
              'requestedBy': requestedBy,
            }),
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw Exception(
          'Le serveur met trop de temps à répondre — réessayez dans un instant.');
    } catch (e) {
      // SocketException / ClientException / DNS… → réseau indisponible.
      throw Exception(
          'Serveur injoignable — vérifiez votre connexion internet et réessayez.');
    }
    Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>? ?? {};
    } catch (_) {
      // Réponse non-JSON (page d'erreur HTML du serveur, proxy…) : on la
      // remonte tronquée pour permettre un vrai diagnostic.
      throw Exception(
          'Réponse serveur invalide (HTTP ${resp.statusCode}) : ${_excerpt(resp.body)}');
    }
    if (resp.statusCode != 200) {
      throw Exception(_serverErrorText(action, resp.statusCode, body));
    }
    return body;
  }

  /// Traduit une erreur HTTP du serveur en message UTILISATEUR actionnable.
  /// Les messages serveur déjà explicites (404 « Aucun compte… », 403…) sont
  /// renvoyés tels quels ; les 500 génériques (« Erreur interne du serveur »)
  /// reçoivent un contexte selon l'action + la cause la plus probable —
  /// notamment le SMTP d'invitation non configuré côté Vercel, qui fait
  /// echo en `500 Erreur interne du serveur` sur `/team/manage-member`.
  static String _serverErrorText(
      String action, int statusCode, Map<String, dynamic> body) {
    final serverMsg = (body['error']?.toString() ?? '').trim();
    final isGeneric500 = statusCode >= 500 &&
        (serverMsg.isEmpty ||
            serverMsg.contains('Erreur interne du serveur') ||
            serverMsg.contains('Internal Server Error'));
    if (!isGeneric500) {
      return serverMsg.isEmpty ? 'Erreur serveur (HTTP $statusCode)' : serverMsg;
    }
    switch (action) {
      case 'invite':
        return 'Le serveur n\'a pas pu créer l\'invitation (envoi d\'email en '
            'erreur côté serveur). Vérifiez que SMTP_USERNAME / SMTP_PASSWORD '
            'sont renseignés dans les variables d\'environnement Vercel, '
            'redéployez le serveur, puis réessayez.';
      case 'accept':
        return 'L\'acceptation de l\'invitation a échoué côté serveur. '
            'Vérifiez votre connexion puis réessayez.';
      case 'decline':
        return 'Le refus de l\'invitation a échoué côté serveur. Réessayez.';
      case 'get-invitations':
        return 'Impossible de récupérer vos invitations : le serveur rencontre '
            'un problème. Réessayez dans quelques instants.';
      case 'remove':
        return 'Impossible de retirer ce membre (erreur serveur). Réessayez.';
      default:
        return 'L\'action « $action » a échoué côté serveur. Réessayez dans un '
            'instant.';
    }
  }

  /// Invite un membre par EMAIL. Le serveur crée une invitation EN ATTENTE,
  /// envoie une notification (toast) à l'invité et un EMAIL ; l'invité devra
  /// l'accepter pour rejoindre l'équipe.
  Future<Map<String, dynamic>> inviteMember({
    required String teamId,
    required String email,
    required String role,
    required String requestedBy,
  }) {
    // Validation précoce : évite un aller-retour serveur inutile (et une
    // invitation HS) quand l'adresse est mal formée.
    final normalized = email.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      throw Exception('Adresse email invalide : "$email"');
    }
    return _manageMember(
      action: 'invite',
      teamId: teamId,
      email: normalized,
      role: role,
      requestedBy: requestedBy,
    );
  }

  /// L'invité ACCEPTE une invitation → devient membre de l'équipe.
  /// Le propriétaire est prévenu par notification (+ email).
  Future<void> acceptInvitation({
    required String invitationId,
    required String requestedBy,
  }) async {
    try {
      await _manageMember(
        action: 'accept',
        teamId: '',
        invitationId: invitationId,
        requestedBy: requestedBy,
      );
    } catch (e) {
      debugPrint('⚠️ Server accept invitation failed, trying direct Firestore acceptance: $e');
      final invDoc = await _db.collection('team_invitations').doc(invitationId).get();
      if (invDoc.exists) {
        final data = invDoc.data() ?? {};
        final teamId = data['teamId']?.toString() ?? '';
        if (teamId.isNotEmpty) {
          await _db.collection('teams').doc(teamId).update({
            'memberIds': FieldValue.arrayUnion([requestedBy]),
          });
          await _db.collection('team_invitations').doc(invitationId).update({
            'status': 'accepted',
          });
          return;
        }
      }
      rethrow;
    }
  }

  /// L'invité REFUSE une invitation.
  Future<void> declineInvitation({
    required String invitationId,
    required String requestedBy,
  }) async {
    try {
      await _manageMember(
        action: 'decline',
        teamId: '',
        invitationId: invitationId,
        requestedBy: requestedBy,
      );
    } catch (e) {
      debugPrint('⚠️ Server decline invitation failed, trying direct Firestore decline: $e');
      final invDoc = await _db.collection('team_invitations').doc(invitationId).get();
      if (invDoc.exists) {
        await _db.collection('team_invitations').doc(invitationId).update({
          'status': 'declined',
        });
        return;
      }
      rethrow;
    }
  }

  /// Liste les invitations EN ATTENTE d'un utilisateur.
  /// Retourne une liste de maps : {id, teamId, teamName, inviterName,
  /// inviterUid, role, createdAt}.
  Future<List<Map<String, dynamic>>> getMyInvitations(String userId) async {
    try {
      final body = await _manageMember(
        action: 'get-invitations',
        teamId: '',
        userId: userId,
        requestedBy: userId,
      );
      final list = body['invitations'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ Server get-invitations failed, using Firestore fallback: $e');
      try {
        final snap = await _db
            .collection('team_invitations')
            .where('targetUserId', isEqualTo: userId)
            .where('status', isEqualTo: 'pending')
            .get();
        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } catch (err) {
        debugPrint('⚠️ Firestore get-invitations fallback error: $err');
      }
    }
    return [];
  }

  /// Retire un membre (propriétaire/admin) et révoque son accès aux
  /// données partagées de l'équipe.
  Future<void> removeMember({
    required String teamId,
    required String userId,
    required String requestedBy,
  }) async {
    await _manageMember(
      action: 'remove',
      teamId: teamId,
      userId: userId,
      requestedBy: requestedBy,
    );
  }

  Future<void> promoteToAdmin({
    required String teamId,
    required String userId,
    required String requestedBy,
  }) async {
    await _manageMember(
      action: 'promote',
      teamId: teamId,
      userId: userId,
      requestedBy: requestedBy,
    );
  }

  Future<void> demoteFromAdmin({
    required String teamId,
    required String userId,
    required String requestedBy,
  }) async {
    await _manageMember(
      action: 'demote',
      teamId: teamId,
      userId: userId,
      requestedBy: requestedBy,
    );
  }

  /// Un membre quitte l'équipe (et perd l'accès aux données partagées).
  Future<void> leaveTeam({
    required String teamId,
    required String userId,
  }) async {
    await _manageMember(
      action: 'leave',
      teamId: teamId,
      userId: userId,
      requestedBy: userId,
    );
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
      final ref = _db.collection('shared_invoices').doc(sharedId);
      final snap = await ref.get();
      final data = snap.data() ?? {};
      await ref.update({
        'isActive': false,
        'expiresAt': FieldValue.serverTimestamp(),
      });

      // 🔒 Révocation complète : retire aussi les destinataires de la
      // ressource (sharedWithUsers), sans quoi ils conserveraient l'accès
      // lecture Firestore même après désactivation du partage.
      final resourceType = data['resourceType']?.toString() ?? 'invoice';
      final resourceId = data['invoiceId']?.toString() ?? '';
      final users = (data['sharedWith'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
      final collection = _collectionFor(resourceType);
      if (resourceId.isNotEmpty && users.isNotEmpty) {
        try {
          await _db.collection(collection).doc(resourceId).update({
            'sharedWithUsers': FieldValue.arrayRemove(users),
          });
        } catch (_) {
          // Doc introuvable / déjà nettoyé : le partage est déjà désactivé.
        }
      }

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
