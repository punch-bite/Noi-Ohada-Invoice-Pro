// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_stats.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DashboardStatsAdapter extends TypeAdapter<DashboardStats> {
  @override
  final int typeId = 2;

  @override
  DashboardStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DashboardStats(
      netRevenue: fields[0] as double,
      revenueChange: fields[1] as double,
      arr: fields[2] as double,
      arrChange: fields[3] as double,
      goalProgress: fields[4] as double,
      goalTarget: fields[5] as double,
      newOrders: fields[6] as int,
      ordersChange: fields[7] as double,
      totalProfit: fields[8] as double,
      totalSales: fields[9] as double,
    );
  }

  @override
  void write(BinaryWriter writer, DashboardStats obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.netRevenue)
      ..writeByte(1)
      ..write(obj.revenueChange)
      ..writeByte(2)
      ..write(obj.arr)
      ..writeByte(3)
      ..write(obj.arrChange)
      ..writeByte(4)
      ..write(obj.goalProgress)
      ..writeByte(5)
      ..write(obj.goalTarget)
      ..writeByte(6)
      ..write(obj.newOrders)
      ..writeByte(7)
      ..write(obj.ordersChange)
      ..writeByte(8)
      ..write(obj.totalProfit)
      ..writeByte(9)
      ..write(obj.totalSales);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CustomerAdapter extends TypeAdapter<Customer> {
  @override
  final int typeId = 13;

  @override
  Customer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Customer(
      name: fields[0] as String,
      deals: fields[1] as int,
      totalValue: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Customer obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.deals)
      ..writeByte(2)
      ..write(obj.totalValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
