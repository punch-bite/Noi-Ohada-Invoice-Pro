// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CompanyAdapter extends TypeAdapter<Company> {
  @override
  final int typeId = 1;

  @override
  Company read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Company(
      id: fields[0] as String?,
      userId: fields[1] as String,
      name: fields[2] as String,
      address: fields[3] as String,
      taxId: fields[4] as String,
      phone: fields[5] as String,
      email: fields[6] as String,
      logoPath: fields[7] as String,
      currency: fields[8] as String,
      defaultTaxRate: fields[9] as double,
      legalText: fields[10] as String,
      website: fields[11] as String,
      rccm: fields[12] as String,
      createdAt: fields[13] as DateTime?,
      updatedAt: fields[14] as DateTime?,
      isActive: fields[15] as bool,
      isSynced: fields[16] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Company obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.taxId)
      ..writeByte(5)
      ..write(obj.phone)
      ..writeByte(6)
      ..write(obj.email)
      ..writeByte(7)
      ..write(obj.logoPath)
      ..writeByte(8)
      ..write(obj.currency)
      ..writeByte(9)
      ..write(obj.defaultTaxRate)
      ..writeByte(10)
      ..write(obj.legalText)
      ..writeByte(11)
      ..write(obj.website)
      ..writeByte(12)
      ..write(obj.rccm)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt)
      ..writeByte(15)
      ..write(obj.isActive)
      ..writeByte(16)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
