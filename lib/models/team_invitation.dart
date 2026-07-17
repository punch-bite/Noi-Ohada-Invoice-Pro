import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'team_invitation.g.dart';

enum InvitationStatus { pending, accepted, declined, expired }
@JsonSerializable()
@HiveType(typeId: 22)
class TeamInvitation {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String teamId;

  @HiveField(2)
  final String invitedBy;

  @HiveField(3)
  final String invitedEmail;

  @HiveField(4)
  final String invitedUserId; // Optionnel (si déjà inscrit)

  @HiveField(5)
  final String role; // 'member' ou 'admin'

  @HiveField(6)
  final String status; // pending, accepted, declined, expired

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime? respondedAt;

  @HiveField(9)
  final DateTime expiresAt;

  TeamInvitation({
    String? id,
    required this.teamId,
    required this.invitedBy,
    required this.invitedEmail,
    required this.invitedUserId,
    this.role = 'member',
    this.status = 'pending',
    DateTime? createdAt,
    this.respondedAt,
    DateTime? expiresAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        expiresAt = expiresAt ?? DateTime.now().add(const Duration(days: 7));

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teamId': teamId,
      'invitedBy': invitedBy,
      'invitedEmail': invitedEmail,
      'invitedUserId': invitedUserId,
      'role': role,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  factory TeamInvitation.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return TeamInvitation(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      teamId: map['teamId'] ?? '',
      invitedBy: map['invitedBy'] ?? '',
      invitedEmail: map['invitedEmail'] ?? '',
      invitedUserId: map['invitedUserId'],
      role: map['role'] ?? 'member',
      status: map['status'] ?? 'pending',
      createdAt: _parseDateTime(map['createdAt']),
      respondedAt: map['respondedAt'] != null ? _parseDateTime(map['respondedAt']) : null,
      expiresAt: map['expiresAt'] != null ? _parseDateTime(map['expiresAt']) : DateTime.now().add(const Duration(days: 7)),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  InvitationStatus get invitationStatus {
    return InvitationStatus.values.firstWhere(
      (e) => e.toString() == status,
      orElse: () => InvitationStatus.pending,
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isExpired => status == 'expired' || DateTime.now().isAfter(expiresAt);

  TeamInvitation copyWith({
    String? status,
    DateTime? respondedAt,
  }) {
    return TeamInvitation(
      id: id,
      teamId: teamId,
      invitedBy: invitedBy,
      invitedEmail: invitedEmail,
      invitedUserId: invitedUserId,
      role: role,
      status: status ?? this.status,
      createdAt: createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      expiresAt: expiresAt,
    );
  }
}