// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InvoiceSettingsAdapter extends TypeAdapter<InvoiceSettings> {
  @override
  final int typeId = 5;

  @override
  InvoiceSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InvoiceSettings(
      showLogo: fields[0] as bool,
      showBorder: fields[1] as bool,
      showWatermark: fields[2] as bool,
      showPaymentQR: fields[3] as bool,
      fontFamily: fields[8] as String,
      fontSize: fields[9] as double,
      showCompanyInfo: fields[10] as bool,
      showClientInfo: fields[11] as bool,
      showPaymentTerms: fields[12] as bool,
      showTaxDetails: fields[13] as bool,
      watermarkText: fields[14] as String,
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceSettings obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.showLogo)
      ..writeByte(1)
      ..write(obj.showBorder)
      ..writeByte(2)
      ..write(obj.showWatermark)
      ..writeByte(3)
      ..write(obj.showPaymentQR)
      ..writeByte(4)
      ..write(obj.primaryColorValue)
      ..writeByte(5)
      ..write(obj.secondaryColorValue)
      ..writeByte(6)
      ..write(obj.backgroundColorValue)
      ..writeByte(7)
      ..write(obj.textColorValue)
      ..writeByte(8)
      ..write(obj.fontFamily)
      ..writeByte(9)
      ..write(obj.fontSize)
      ..writeByte(10)
      ..write(obj.showCompanyInfo)
      ..writeByte(11)
      ..write(obj.showClientInfo)
      ..writeByte(12)
      ..write(obj.showPaymentTerms)
      ..writeByte(13)
      ..write(obj.showTaxDetails)
      ..writeByte(14)
      ..write(obj.watermarkText);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
