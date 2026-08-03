// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeliveryAdapter extends TypeAdapter<Delivery> {
  @override
  final int typeId = 3;

  @override
  Delivery read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Delivery(
      id: fields[0] as String?,
      productId: fields[1] as String,
      productName: fields[2] as String,
      quantity: fields[3] as int,
      type: fields[4] as String,
      status: fields[5] as String,
      reference: fields[6] as String?,
      clientName: fields[7] as String?,
      notes: fields[8] as String?,
      createdAt: fields[9] as DateTime?,
      completedAt: fields[10] as DateTime?,
      createdBy: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Delivery obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.productName)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.reference)
      ..writeByte(7)
      ..write(obj.clientName)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.completedAt)
      ..writeByte(11)
      ..write(obj.createdBy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Delivery _$DeliveryFromJson(Map<String, dynamic> json) => Delivery(
      id: json['id'] as String?,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num).toInt(),
      type: json['type'] as String,
      status: json['status'] as String? ?? 'pending',
      reference: json['reference'] as String?,
      clientName: json['clientName'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      createdBy: json['createdBy'] as String?,
    );

Map<String, dynamic> _$DeliveryToJson(Delivery instance) => <String, dynamic>{
      'id': instance.id,
      'productId': instance.productId,
      'productName': instance.productName,
      'quantity': instance.quantity,
      'type': instance.type,
      'status': instance.status,
      'reference': instance.reference,
      'clientName': instance.clientName,
      'notes': instance.notes,
      'createdAt': instance.createdAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'createdBy': instance.createdBy,
    };
