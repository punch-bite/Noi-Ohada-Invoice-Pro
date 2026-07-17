// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_invitation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TeamInvitationAdapter extends TypeAdapter<TeamInvitation> {
  @override
  final int typeId = 22;

  @override
  TeamInvitation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TeamInvitation(
      id: fields[0] as String?,
      teamId: fields[1] as String,
      invitedBy: fields[2] as String,
      invitedEmail: fields[3] as String,
      invitedUserId: fields[4] as String,
      role: fields[5] as String,
      status: fields[6] as String,
      createdAt: fields[7] as DateTime?,
      respondedAt: fields[8] as DateTime?,
      expiresAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TeamInvitation obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.teamId)
      ..writeByte(2)
      ..write(obj.invitedBy)
      ..writeByte(3)
      ..write(obj.invitedEmail)
      ..writeByte(4)
      ..write(obj.invitedUserId)
      ..writeByte(5)
      ..write(obj.role)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.respondedAt)
      ..writeByte(9)
      ..write(obj.expiresAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamInvitationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TeamInvitation _$TeamInvitationFromJson(Map<String, dynamic> json) =>
    TeamInvitation(
      id: json['id'] as String?,
      teamId: json['teamId'] as String,
      invitedBy: json['invitedBy'] as String,
      invitedEmail: json['invitedEmail'] as String,
      invitedUserId: json['invitedUserId'] as String,
      role: json['role'] as String? ?? 'member',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      respondedAt: json['respondedAt'] == null
          ? null
          : DateTime.parse(json['respondedAt'] as String),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
    );

Map<String, dynamic> _$TeamInvitationToJson(TeamInvitation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'teamId': instance.teamId,
      'invitedBy': instance.invitedBy,
      'invitedEmail': instance.invitedEmail,
      'invitedUserId': instance.invitedUserId,
      'role': instance.role,
      'status': instance.status,
      'createdAt': instance.createdAt.toIso8601String(),
      'respondedAt': instance.respondedAt?.toIso8601String(),
      'expiresAt': instance.expiresAt.toIso8601String(),
    };
