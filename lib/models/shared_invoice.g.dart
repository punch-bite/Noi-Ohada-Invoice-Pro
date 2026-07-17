// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shared_invoice.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SharedInvoiceAdapter extends TypeAdapter<SharedInvoice> {
  @override
  final int typeId = 23;

  @override
  SharedInvoice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SharedInvoice(
      id: fields[0] as String?,
      invoiceId: fields[1] as String,
      teamId: fields[2] as String,
      sharedBy: fields[3] as String,
      sharedWith: (fields[4] as List).cast<String>(),
      permissionLevel: fields[6] as String,
      sharedAt: fields[5] as DateTime,
      expiresAt: fields[7] as DateTime?,
      isActive: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SharedInvoice obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.invoiceId)
      ..writeByte(2)
      ..write(obj.teamId)
      ..writeByte(3)
      ..write(obj.sharedBy)
      ..writeByte(4)
      ..write(obj.sharedWith)
      ..writeByte(5)
      ..write(obj.sharedAt)
      ..writeByte(6)
      ..write(obj.permissionLevel)
      ..writeByte(7)
      ..write(obj.expiresAt)
      ..writeByte(8)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedInvoiceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SharedInvoice _$SharedInvoiceFromJson(Map<String, dynamic> json) =>
    SharedInvoice(
      id: json['id'] as String?,
      invoiceId: json['invoiceId'] as String,
      teamId: json['teamId'] as String,
      sharedBy: json['sharedBy'] as String,
      sharedWith: (json['sharedWith'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      permissionLevel: json['permissionLevel'] as String,
      sharedAt: DateTime.parse(json['sharedAt'] as String),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$SharedInvoiceToJson(SharedInvoice instance) =>
    <String, dynamic>{
      'id': instance.id,
      'invoiceId': instance.invoiceId,
      'teamId': instance.teamId,
      'sharedBy': instance.sharedBy,
      'sharedWith': instance.sharedWith,
      'sharedAt': instance.sharedAt.toIso8601String(),
      'permissionLevel': instance.permissionLevel,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'isActive': instance.isActive,
    };
