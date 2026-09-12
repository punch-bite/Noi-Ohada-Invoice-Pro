// test/team_shared_access_test.dart
//
// 🧪 Garde-fou du besoin « le membre qui adhère à la team accède aux fichiers
// partagés en lecture/écriture selon le rôle imposé aux membres » :
//   • Team.permissionFor / canWriteShared  → droit déduit du RÔLE ;
//   • SharedInvoice.canWrite / canRead     → droit effectif du membre ;
//   • TeamMessage.ownerId / ownerName      → PROPRIÉTAIRE du message, avec
//     rétro-compatibilité pour les messages antérieurs.
import 'package:flutter_test/flutter_test.dart';
import 'package:noi_ohada_invoice_pro/models/shared_invoice.dart';
import 'package:noi_ohada_invoice_pro/models/team.dart';
import 'package:noi_ohada_invoice_pro/models/team_message.dart';

void main() {
  Team buildTeam({
    String memberPermission = 'read',
    String adminPermission = 'write',
  }) {
    return Team(
      id: 't1',
      name: 'Équipe Test',
      description: '',
      ownerId: 'owner',
      memberIds: ['owner', 'member1'],
      adminIds: ['admin1'],
      createdAt: DateTime(2026),
      memberPermission: memberPermission,
      adminPermission: adminPermission,
    );
  }

  group('Team · politique d\'accès par rôle', () {
    test('un membre simple reçoit memberPermission', () {
      final team = buildTeam(memberPermission: 'read');
      expect(team.permissionFor('member1'), 'read');
      expect(team.canWriteShared('member1'), isFalse);
      expect(team.canReadShared('member1'), isTrue);
    });

    test('un membre simple peut ÉCRIRE si l\'équipe le permet', () {
      final team = buildTeam(memberPermission: 'write');
      expect(team.permissionFor('member1'), 'write');
      expect(team.canWriteShared('member1'), isTrue);
    });

    test('propriétaire et admin reçoivent adminPermission', () {
      final team = buildTeam(
        memberPermission: 'read',
        adminPermission: 'write',
      );
      expect(team.permissionFor('owner'), 'write');
      expect(team.permissionFor('admin1'), 'write');
      expect(team.canWriteShared('owner'), isTrue);
      expect(team.canWriteShared('admin1'), isTrue);
    });

    test('adminPermission peut être restreint si l\'équipe le décide', () {
      final team = buildTeam(adminPermission: 'read');
      expect(team.canWriteShared('admin1'), isFalse);
      expect(team.canReadShared('admin1'), isTrue);
    });

    test('normalizePermission retombe sur le défaut si la valeur est inconnue',
        () {
      expect(Team.normalizePermission(null), 'read');
      expect(Team.normalizePermission('WRITE'), 'write');
      expect(Team.normalizePermission('bogus', fallback: 'write'), 'write');
    });

    test('copyWith conserve / modifie la politique d\'accès', () {
      final team = buildTeam(memberPermission: 'read');
      final updated = team.copyWith(memberPermission: 'write');
      expect(updated.memberPermission, 'write');
      expect(updated.adminPermission, 'write');
      expect(updated.id, team.id);
      expect(updated.memberIds, team.memberIds);
    });

    test('sérialisation Firestore aller-retour', () {
      final team = buildTeam(memberPermission: 'write');
      final restored = Team.fromMap(team.toMap());
      expect(restored.memberPermission, 'write');
      expect(restored.adminPermission, 'write');
      expect(restored.canWriteShared('member1'), isTrue);
    });
  });

  group('SharedInvoice · droit effectif du membre', () {
    SharedInvoice buildShare({
      String permissionLevel = 'read',
      List<String> writeUsers = const [],
    }) {
      return SharedInvoice(
        invoiceId: 'inv1',
        teamId: 't1',
        sharedBy: 'owner',
        sharedWith: ['member1', 'member2'],
        permissionLevel: permissionLevel,
        sharedAt: DateTime(2026),
        writeUsers: writeUsers,
      );
    }

    test('partage en lecture seule : lecture oui, écriture non', () {
      final share = buildShare();
      expect(share.canRead('member1'), isTrue);
      expect(share.canWrite('member1'), isFalse);
    });

    test('membre ajouté à writeUsers par l\'adhésion : écriture accordée', () {
      final share = buildShare(writeUsers: ['member2']);
      expect(share.canWrite('member1'), isFalse);
      expect(share.canWrite('member2'), isTrue);
    });

    test('partage global en écriture : tous les destinataires peuvent écrire',
        () {
      final share = buildShare(permissionLevel: 'write');
      expect(share.canWrite('member1'), isTrue);
      expect(share.canWrite('member2'), isTrue);
    });

    test('un non-destinataire n\'a aucun accès', () {
      final share = buildShare();
      expect(share.canRead('stranger'), isFalse);
      expect(share.canWrite('stranger'), isFalse);
    });

    test('writeUsers survit à la sérialisation Firestore', () {
      final share = buildShare(writeUsers: ['member2']);
      final restored = SharedInvoice.fromMap(share.toMap());
      expect(restored.writeUsers, ['member2']);
      expect(restored.canWrite('member2'), isTrue);
    });
  });

  group('Team · titre de rôle (badge du chat)', () {
    test(
        'le propriétaire et les administrateurs sont « Propriétaire du groupe »',
        () {
      final team = buildTeam();
      expect(team.roleTitleFor('owner'), Team.ownerTitle);
      expect(team.roleTitleFor('admin1'), Team.ownerTitle);
      expect(Team.ownerTitle, 'Propriétaire du groupe');
    });

    test('un membre simple est « Membre »', () {
      final team = buildTeam();
      expect(team.roleTitleFor('member1'), Team.memberTitle);
      expect(Team.memberTitle, 'Membre');
    });

    test('un utilisateur inconnu (hors équipe) est « Membre »', () {
      final team = buildTeam();
      expect(team.roleTitleFor('stranger'), Team.memberTitle);
    });
  });

  group('TeamMessage · propriétaire du message', () {
    test('le propriétaire estampillé est conservé (sérialisation)', () {
      final message = TeamMessage(
        id: 'm1',
        teamId: 't1',
        senderId: 'member1',
        senderName: 'Alice',
        ownerId: 'owner',
        ownerName: 'Bob le patron',
        text: 'Bonjour',
        createdAt: DateTime(2026),
      );
      final restored = TeamMessage.fromMap(message.toMap(), documentId: 'm1');
      expect(restored.ownerId, 'owner');
      expect(restored.ownerName, 'Bob le patron');
      expect(restored.senderId, 'member1');
    });

    test('rétro-compatibilité : message sans propriétaire → expéditeur', () {
      final restored = TeamMessage.fromMap({
        'teamId': 't1',
        'senderId': 'member1',
        'senderName': 'Alice',
        'text': 'Ancien message',
      }, documentId: 'm0');
      expect(restored.ownerId, 'member1');
      expect(restored.ownerName, 'Alice');
    });
  });
}
