// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlanAdapter extends TypeAdapter<Plan> {
  @override
  final int typeId = 10;

  @override
  Plan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Plan(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      price: fields[3] as double,
      currency: fields[4] as String,
      interval: fields[5] as String,
      maxInvoices: fields[6] as int,
      maxClients: fields[7] as int,
      hasPdfExport: fields[8] as bool,
      hasCloudSync: fields[9] as bool,
      hasTeamAccess: fields[10] as bool,
      features: (fields[11] as List).cast<String>(),
      isPopular: fields[12] as bool,
      isActive: fields[13] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Plan obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.currency)
      ..writeByte(5)
      ..write(obj.interval)
      ..writeByte(6)
      ..write(obj.maxInvoices)
      ..writeByte(7)
      ..write(obj.maxClients)
      ..writeByte(8)
      ..write(obj.hasPdfExport)
      ..writeByte(9)
      ..write(obj.hasCloudSync)
      ..writeByte(10)
      ..write(obj.hasTeamAccess)
      ..writeByte(11)
      ..write(obj.features)
      ..writeByte(12)
      ..write(obj.isPopular)
      ..writeByte(13)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Plan _$PlanFromJson(Map<String, dynamic> json) => Plan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
      interval: json['interval'] as String,
      maxInvoices: (json['maxInvoices'] as num?)?.toInt() ?? -1,
      maxClients: (json['maxClients'] as num?)?.toInt() ?? -1,
      hasPdfExport: json['hasPdfExport'] as bool? ?? true,
      hasCloudSync: json['hasCloudSync'] as bool? ?? true,
      hasTeamAccess: json['hasTeamAccess'] as bool? ?? false,
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isPopular: json['isPopular'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$PlanToJson(Plan instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'price': instance.price,
      'currency': instance.currency,
      'interval': instance.interval,
      'maxInvoices': instance.maxInvoices,
      'maxClients': instance.maxClients,
      'hasPdfExport': instance.hasPdfExport,
      'hasCloudSync': instance.hasCloudSync,
      'hasTeamAccess': instance.hasTeamAccess,
      'features': instance.features,
      'isPopular': instance.isPopular,
      'isActive': instance.isActive,
    };
