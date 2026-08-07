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
