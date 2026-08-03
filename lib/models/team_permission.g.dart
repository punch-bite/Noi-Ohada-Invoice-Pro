// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_permission.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TeamPermissionAdapter extends TypeAdapter<TeamPermission> {
  @override
  final int typeId = 21;

  @override
  TeamPermission read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TeamPermission(
      id: fields[0] as String?,
      teamId: fields[1] as String,
      userId: fields[2] as String,
      resourceType: fields[3] as String,
      permissionLevel: fields[4] as String,
      createdAt: fields[5] as DateTime?,
      updatedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TeamPermission obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.teamId)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.resourceType)
      ..writeByte(4)
      ..write(obj.permissionLevel)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamPermissionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TeamPermission _$TeamPermissionFromJson(Map<String, dynamic> json) =>
    TeamPermission(
      id: json['id'] as String?,
      teamId: json['teamId'] as String,
      userId: json['userId'] as String,
      resourceType: json['resourceType'] as String,
      permissionLevel: json['permissionLevel'] as String,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$TeamPermissionToJson(TeamPermission instance) =>
    <String, dynamic>{
      'id': instance.id,
      'teamId': instance.teamId,
      'userId': instance.userId,
      'resourceType': instance.resourceType,
      'permissionLevel': instance.permissionLevel,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
