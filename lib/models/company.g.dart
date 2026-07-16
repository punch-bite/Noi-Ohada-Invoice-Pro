// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CompanyAdapter extends TypeAdapter<Company> {
  @override
  final int typeId = 10;

  @override
  Company read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Company(
      id: fields[0] as String?,
      name: fields[1] as String,
      address: fields[2] as String,
      taxId: fields[3] as String,
      phone: fields[4] as String,
      email: fields[5] as String,
      logoPath: fields[6] as String,
      currency: fields[7] as String,
      defaultTaxRate: fields[8] as double,
      legalText: fields[9] as String,
      website: fields[10] as String,
      rccm: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Company obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.address)
      ..writeByte(3)
      ..write(obj.taxId)
      ..writeByte(4)
      ..write(obj.phone)
      ..writeByte(5)
      ..write(obj.email)
      ..writeByte(6)
      ..write(obj.logoPath)
      ..writeByte(7)
      ..write(obj.currency)
      ..writeByte(8)
      ..write(obj.defaultTaxRate)
      ..writeByte(9)
      ..write(obj.legalText)
      ..writeByte(10)
      ..write(obj.website)
      ..writeByte(11)
      ..write(obj.rccm);
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
