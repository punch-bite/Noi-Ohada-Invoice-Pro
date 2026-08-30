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
      maxProducts: fields[11] as int,
      hasPdfExport: fields[8] as bool,
      hasCloudSync: fields[9] as bool,
      hasTeamAccess: fields[10] as bool,
      maxTeamMembers: fields[15] as int,
      hasGoogleDriveSync: fields[16] as bool,
      hasClientRelance: fields[17] as bool,
      // Champ 18 ajouté après coup : null-safe pour les données Hive existantes.
      maxSuppliers: (fields[18] as int?) ?? -1,
      features: (fields[12] as List).cast<String>(),
      isPopular: fields[13] as bool,
      isActive: fields[14] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Plan obj) {
    writer
      ..writeByte(19)
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
      ..write(obj.maxProducts)
      ..writeByte(12)
      ..write(obj.features)
      ..writeByte(13)
      ..write(obj.isPopular)
      ..writeByte(14)
      ..write(obj.isActive)
      ..writeByte(15)
      ..write(obj.maxTeamMembers)
      ..writeByte(16)
      ..write(obj.hasGoogleDriveSync)
      ..writeByte(17)
      ..write(obj.hasClientRelance)
      ..writeByte(18)
      ..write(obj.maxSuppliers);
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
