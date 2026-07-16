// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SubscriptionAdapter extends TypeAdapter<Subscription> {
  @override
  final int typeId = 7;

  @override
  Subscription read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Subscription(
      id: fields[0] as String,
      userId: fields[1] as String,
      planId: fields[2] as String,
      startDate: fields[3] as DateTime,
      endDate: fields[4] as DateTime,
      status: fields[5] as String,
      paymentMethod: fields[6] as String,
      paymentId: fields[7] as String,
      amount: fields[8] as double,
      currency: fields[9] as String,
      autoRenew: fields[10] as bool,
      canceledAt: fields[11] as DateTime?,
      metadata: (fields[12] as Map).cast<String, dynamic>(), isActive: true, createdAt: DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, Subscription obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.planId)
      ..writeByte(3)
      ..write(obj.startDate)
      ..writeByte(4)
      ..write(obj.endDate)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.paymentMethod)
      ..writeByte(7)
      ..write(obj.paymentId)
      ..writeByte(8)
      ..write(obj.amount)
      ..writeByte(9)
      ..write(obj.currency)
      ..writeByte(10)
      ..write(obj.autoRenew)
      ..writeByte(11)
      ..write(obj.canceledAt)
      ..writeByte(12)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
