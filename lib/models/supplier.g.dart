// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SupplierAdapter extends TypeAdapter<Supplier> {
  @override
  final int typeId = 25;

  @override
  Supplier read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Supplier(
      id: fields[0] as String?,
      userId: fields[1] as String,
      name: fields[2] as String,
      email: fields[3] as String,
      phone: fields[4] as String,
      address: fields[5] as String,
      taxId: fields[6] as String,
      contactPerson: fields[7] as String,
      notes: fields[8] as String,
      isActive: fields[9] as bool,
      createdAt: fields[10] as DateTime?,
      updatedAt: fields[11] as DateTime?,
      isSynced: fields[12] as bool,
      companyId: fields[13] as String?,
      sharedWithUsers: (fields[14] as List).cast<String>(),
      sharedTeams: (fields[15] as List).cast<String>(),
      editableByUsers: (fields[16] as List).cast<String>(),
      editableTeams: (fields[17] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Supplier obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.phone)
      ..writeByte(5)
      ..write(obj.address)
      ..writeByte(6)
      ..write(obj.taxId)
      ..writeByte(7)
      ..write(obj.contactPerson)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.isActive)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.isSynced)
      ..writeByte(13)
      ..write(obj.companyId)
      ..writeByte(14)
      ..write(obj.sharedWithUsers)
      ..writeByte(15)
      ..write(obj.sharedTeams)
      ..writeByte(16)
      ..write(obj.editableByUsers)
      ..writeByte(17)
      ..write(obj.editableTeams);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
