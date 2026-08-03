// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReminderAdapter extends TypeAdapter<Reminder> {
  @override
  final int typeId = 12;

  @override
  Reminder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Reminder(
      id: fields[0] as String?,
      invoiceId: fields[1] as String,
      invoiceNumber: fields[2] as String,
      clientId: fields[3] as String,
      clientName: fields[4] as String,
      amount: fields[5] as double,
      type: fields[6] as String,
      dueDate: fields[7] as DateTime,
      reminderDate: fields[8] as DateTime,
      status: fields[9] as String,
      sentAt: fields[10] as DateTime?,
      errorMessage: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Reminder obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.invoiceId)
      ..writeByte(2)
      ..write(obj.invoiceNumber)
      ..writeByte(3)
      ..write(obj.clientId)
      ..writeByte(4)
      ..write(obj.clientName)
      ..writeByte(5)
      ..write(obj.amount)
      ..writeByte(6)
      ..write(obj.type)
      ..writeByte(7)
      ..write(obj.dueDate)
      ..writeByte(8)
      ..write(obj.reminderDate)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.sentAt)
      ..writeByte(11)
      ..write(obj.errorMessage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Reminder _$ReminderFromJson(Map<String, dynamic> json) => Reminder(
      id: json['id'] as String?,
      invoiceId: json['invoiceId'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      clientId: json['clientId'] as String,
      clientName: json['clientName'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] as String,
      dueDate: DateTime.parse(json['dueDate'] as String),
      reminderDate: DateTime.parse(json['reminderDate'] as String),
      status: json['status'] as String,
      sentAt: json['sentAt'] == null
          ? null
          : DateTime.parse(json['sentAt'] as String),
      errorMessage: json['errorMessage'] as String?,
    );

Map<String, dynamic> _$ReminderToJson(Reminder instance) => <String, dynamic>{
      'id': instance.id,
      'invoiceId': instance.invoiceId,
      'invoiceNumber': instance.invoiceNumber,
      'clientId': instance.clientId,
      'clientName': instance.clientName,
      'amount': instance.amount,
      'type': instance.type,
      'dueDate': instance.dueDate.toIso8601String(),
      'reminderDate': instance.reminderDate.toIso8601String(),
      'status': instance.status,
      'sentAt': instance.sentAt?.toIso8601String(),
      'errorMessage': instance.errorMessage,
    };
