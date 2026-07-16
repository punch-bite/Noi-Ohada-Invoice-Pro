// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InvoiceTemplateAdapter extends TypeAdapter<InvoiceTemplate> {
  @override
  final int typeId = 6;

  @override
  InvoiceTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InvoiceTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      showLogo: fields[6] as bool,
      showTaxDetails: fields[7] as bool,
      showPaymentTerms: fields[8] as bool,
      showPaymentQR: fields[9] as bool,
      isPremium: fields[10] as bool,
      isDefault: fields[11] as bool,
      fontFamily: fields[12] as String,
      fontSize: fields[13] as double,
      showBorder: fields[14] as bool,
      createdBy: fields[15] as String?,
      isActive: fields[16] as bool,
      createdAt: fields[17] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceTemplate obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.primaryColorValue)
      ..writeByte(4)
      ..write(obj.textColorValue)
      ..writeByte(5)
      ..write(obj.backgroundColorValue)
      ..writeByte(6)
      ..write(obj.showLogo)
      ..writeByte(7)
      ..write(obj.showTaxDetails)
      ..writeByte(8)
      ..write(obj.showPaymentTerms)
      ..writeByte(9)
      ..write(obj.showPaymentQR)
      ..writeByte(10)
      ..write(obj.isPremium)
      ..writeByte(11)
      ..write(obj.isDefault)
      ..writeByte(12)
      ..write(obj.fontFamily)
      ..writeByte(13)
      ..write(obj.fontSize)
      ..writeByte(14)
      ..write(obj.showBorder)
      ..writeByte(15)
      ..write(obj.createdBy)
      ..writeByte(16)
      ..write(obj.isActive)
      ..writeByte(17)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
