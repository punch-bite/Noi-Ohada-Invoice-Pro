// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ActivityLogAdapter extends TypeAdapter<ActivityLog> {
  @override
  final int typeId = 17;

  @override
  ActivityLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ActivityLog(
      id: fields[0] as String,
      userId: fields[1] as String,
      userEmail: fields[2] as String,
      action: fields[3] as String,
      targetId: fields[4] as String?,
      targetType: fields[5] as String?,
      details: (fields[6] as Map?)?.cast<String, dynamic>(),
      timestamp: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ActivityLog obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.userEmail)
      ..writeByte(3)
      ..write(obj.action)
      ..writeByte(4)
      ..write(obj.targetId)
      ..writeByte(5)
      ..write(obj.targetType)
      ..writeByte(6)
      ..write(obj.details)
      ..writeByte(7)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActivityLog _$ActivityLogFromJson(Map<String, dynamic> json) => ActivityLog(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userEmail: json['userEmail'] as String,
      action: json['action'] as String,
      targetId: json['targetId'] as String?,
      targetType: json['targetType'] as String?,
      details: json['details'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$ActivityLogToJson(ActivityLog instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'userEmail': instance.userEmail,
      'action': instance.action,
      'targetId': instance.targetId,
      'targetType': instance.targetType,
      'details': instance.details,
      'timestamp': instance.timestamp.toIso8601String(),
    };
