// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppNotificationAdapter extends TypeAdapter<AppNotification> {
  @override
  final int typeId = 9;

  @override
  AppNotification read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppNotification(
      id: fields[0] as String?,
      title: fields[1] as String,
      body: fields[2] as String,
      type: fields[3] as String,
      timestamp: fields[4] as DateTime?,
      isRead: fields[5] as bool,
      referenceId: fields[6] as String?,
      referenceType: fields[7] as String?,
      data: (fields[8] as Map?)?.cast<String, dynamic>(),
      userId: fields[9] as String?,
      createdBy: fields[10] as String?,
      teamId: fields[11] as String?,
      recipients: (fields[12] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, AppNotification obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.body)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.isRead)
      ..writeByte(6)
      ..write(obj.referenceId)
      ..writeByte(7)
      ..write(obj.referenceType)
      ..writeByte(8)
      ..write(obj.data)
      ..writeByte(9)
      ..write(obj.userId)
      ..writeByte(10)
      ..write(obj.createdBy)
      ..writeByte(11)
      ..write(obj.teamId)
      ..writeByte(12)
      ..write(obj.recipients);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotificationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
