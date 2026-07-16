// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppUserAdapter extends TypeAdapter<AppUser> {
  @override
  final int typeId = 9;

  @override
  AppUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppUser(
      id: fields[0] as String,
      email: fields[1] as String,
      displayName: fields[2] as String,
      phone: fields[3] as String?,
      companyName: fields[4] as String?,
      companyAddress: fields[5] as String?,
      taxId: fields[6] as String?,
      subscriptionId: fields[7] as String?,
      createdAt: fields[8] as DateTime,
      lastLoginAt: fields[9] as DateTime?,
      isActive: fields[10] as bool,
      roles: (fields[11] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, AppUser obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.displayName)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.companyName)
      ..writeByte(5)
      ..write(obj.companyAddress)
      ..writeByte(6)
      ..write(obj.taxId)
      ..writeByte(7)
      ..write(obj.subscriptionId)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.lastLoginAt)
      ..writeByte(10)
      ..write(obj.isActive)
      ..writeByte(11)
      ..write(obj.roles);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
