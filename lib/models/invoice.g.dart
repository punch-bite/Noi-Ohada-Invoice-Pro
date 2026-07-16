// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InvoiceAdapter extends TypeAdapter<Invoice> {
  @override
  final int typeId = 7;

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

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Invoice _$InvoiceFromJson(Map<String, dynamic> json) => Invoice(
      id: json['id'] as String?,
      companyId: json['companyId'] as String,
      clientId: json['clientId'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      issueDate: DateTime.parse(json['issueDate'] as String),
      dueDate: DateTime.parse(json['dueDate'] as String),
      status: json['status'] as String? ?? 'draft',
      items: (json['items'] as List<dynamic>)
          .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      taxRate: (json['taxRate'] as num).toDouble(),
      taxAmount: (json['taxAmount'] as num).toDouble(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      terms: json['terms'] as String? ?? 'Paiement à 30 jours',
      isDevis: json['isDevis'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
      syncedAt: json['syncedAt'] == null
          ? null
          : DateTime.parse(json['syncedAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$InvoiceToJson(Invoice instance) => <String, dynamic>{
      'id': instance.id,
      'companyId': instance.companyId,
      'clientId': instance.clientId,
      'invoiceNumber': instance.invoiceNumber,
      'issueDate': instance.issueDate.toIso8601String(),
      'dueDate': instance.dueDate.toIso8601String(),
      'status': instance.status,
      'items': instance.items,
      'subtotal': instance.subtotal,
      'taxRate': instance.taxRate,
      'taxAmount': instance.taxAmount,
      'discount': instance.discount,
      'totalAmount': instance.totalAmount,
      'terms': instance.terms,
      'isDevis': instance.isDevis,
      'notes': instance.notes,
      'syncedAt': instance.syncedAt?.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
