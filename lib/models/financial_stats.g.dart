// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financial_stats.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FinancialStatsAdapter extends TypeAdapter<FinancialStats> {
  @override
  final int typeId = 4;

  @override
  FinancialStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinancialStats(
      totalRevenue: fields[0] as double,
      totalPaid: fields[1] as double,
      totalPending: fields[2] as double,
      totalOverdue: fields[3] as double,
      totalCancelled: fields[4] as double,
      totalInvoices: fields[5] as int,
      paidCount: fields[6] as int,
      pendingCount: fields[7] as int,
      overdueCount: fields[8] as int,
      cancelledCount: fields[9] as int,
      averageInvoiceValue: fields[10] as double,
    );
  }

  @override
  void write(BinaryWriter writer, FinancialStats obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.totalRevenue)
      ..writeByte(1)
      ..write(obj.totalPaid)
      ..writeByte(2)
      ..write(obj.totalPending)
      ..writeByte(3)
      ..write(obj.totalOverdue)
      ..writeByte(4)
      ..write(obj.totalCancelled)
      ..writeByte(5)
      ..write(obj.totalInvoices)
      ..writeByte(6)
      ..write(obj.paidCount)
      ..writeByte(7)
      ..write(obj.pendingCount)
      ..writeByte(8)
      ..write(obj.overdueCount)
      ..writeByte(9)
      ..write(obj.cancelledCount)
      ..writeByte(10)
      ..write(obj.averageInvoiceValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinancialStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinancialStats _$FinancialStatsFromJson(Map<String, dynamic> json) =>
    FinancialStats(
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0.0,
      totalPending: (json['totalPending'] as num?)?.toDouble() ?? 0.0,
      totalOverdue: (json['totalOverdue'] as num?)?.toDouble() ?? 0.0,
      totalCancelled: (json['totalCancelled'] as num?)?.toDouble() ?? 0.0,
      totalInvoices: (json['totalInvoices'] as num?)?.toInt() ?? 0,
      paidCount: (json['paidCount'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      overdueCount: (json['overdueCount'] as num?)?.toInt() ?? 0,
      cancelledCount: (json['cancelledCount'] as num?)?.toInt() ?? 0,
      averageInvoiceValue:
          (json['averageInvoiceValue'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$FinancialStatsToJson(FinancialStats instance) =>
    <String, dynamic>{
      'totalRevenue': instance.totalRevenue,
      'totalPaid': instance.totalPaid,
      'totalPending': instance.totalPending,
      'totalOverdue': instance.totalOverdue,
      'totalCancelled': instance.totalCancelled,
      'totalInvoices': instance.totalInvoices,
      'paidCount': instance.paidCount,
      'pendingCount': instance.pendingCount,
      'overdueCount': instance.overdueCount,
      'cancelledCount': instance.cancelledCount,
      'averageInvoiceValue': instance.averageInvoiceValue,
    };
