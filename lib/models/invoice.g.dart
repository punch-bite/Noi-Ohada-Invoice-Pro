// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InvoiceAdapter extends TypeAdapter<Invoice> {
  @override
  final int typeId = 2;

  @override
  Invoice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Invoice(
      id: fields[0] as String?,
      companyId: fields[1] as String,
      clientId: fields[2] as String,
      invoiceNumber: fields[3] as String,
      issueDate: fields[4] as DateTime,
      dueDate: fields[5] as DateTime,
      status: fields[6] as String,
      items: (fields[7] as List).cast<LineItem>(),
      subtotal: fields[8] as double,
      taxRate: fields[9] as double,
      taxAmount: fields[10] as double,
      discount: fields[11] as double,
      totalAmount: fields[12] as double,
      terms: fields[13] as String,
      isDevis: fields[14] as bool,
      notes: fields[15] as String,
      syncedAt: fields[16] as DateTime?,
      updatedAt: fields[17] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Invoice obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.companyId)
      ..writeByte(2)
      ..write(obj.clientId)
      ..writeByte(3)
      ..write(obj.invoiceNumber)
      ..writeByte(4)
      ..write(obj.issueDate)
      ..writeByte(5)
      ..write(obj.dueDate)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.items)
      ..writeByte(8)
      ..write(obj.subtotal)
      ..writeByte(9)
      ..write(obj.taxRate)
      ..writeByte(10)
      ..write(obj.taxAmount)
      ..writeByte(11)
      ..write(obj.discount)
      ..writeByte(12)
      ..write(obj.totalAmount)
      ..writeByte(13)
      ..write(obj.terms)
      ..writeByte(14)
      ..write(obj.isDevis)
      ..writeByte(15)
      ..write(obj.notes)
      ..writeByte(16)
      ..write(obj.syncedAt)
      ..writeByte(17)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
