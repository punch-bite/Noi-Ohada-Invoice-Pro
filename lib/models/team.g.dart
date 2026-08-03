// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TeamAdapter extends TypeAdapter<Team> {
  @override
  final int typeId = 20;

  @override
  Team read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Team(
      id: fields[0] as String?,
      name: fields[1] as String,
      description: fields[2] as String,
      ownerId: fields[3] as String,
      memberIds: (fields[4] as List).cast<String>(),
      adminIds: (fields[5] as List).cast<String>(),
      logoPath: fields[6] as String?,
      createdAt: fields[7] as DateTime?,
      updatedAt: fields[8] as DateTime?,
      isActive: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Team obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.ownerId)
      ..writeByte(4)
      ..write(obj.memberIds)
      ..writeByte(5)
      ..write(obj.adminIds)
      ..writeByte(6)
      ..write(obj.logoPath)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Team _$TeamFromJson(Map<String, dynamic> json) => Team(
      id: json['id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      ownerId: json['ownerId'] as String,
      memberIds: (json['memberIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      adminIds: (json['adminIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      logoPath: json['logoPath'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$TeamToJson(Team instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'ownerId': instance.ownerId,
      'memberIds': instance.memberIds,
      'adminIds': instance.adminIds,
      'logoPath': instance.logoPath,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'isActive': instance.isActive,
    };
