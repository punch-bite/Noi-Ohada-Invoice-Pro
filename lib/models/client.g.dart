// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClientAdapter extends TypeAdapter<Client> {
  @override
  final int typeId = 0;

  @override
  Client read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Client(
      id: fields[0] as String?,
      userId: fields[1] as String,
      name: fields[2] as String,
      address: fields[3] as String,
      taxId: fields[4] as String,
      phone: fields[5] as String,
      email: fields[6] as String,
      createdAt: fields[7] as DateTime?,
      updatedAt: fields[8] as DateTime?,
      isActive: fields[9] as bool,
      isSynced: fields[10] as bool,
      companyId: fields[11] as String?,
      sharedWithUsers: (fields[12] as List).cast<String>(),
      sharedTeams: (fields[13] as List).cast<String>(),
      editableByUsers: (fields[14] as List).cast<String>(),
      editableTeams: (fields[15] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Client obj) {
    writer
      ..writeByte(16)
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
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.isActive)
      ..writeByte(10)
      ..write(obj.isSynced)
      ..writeByte(11)
      ..write(obj.companyId)
      ..writeByte(12)
      ..write(obj.sharedWithUsers)
      ..writeByte(13)
      ..write(obj.sharedTeams)
      ..writeByte(14)
      ..write(obj.editableByUsers)
      ..writeByte(15)
      ..write(obj.editableTeams);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
