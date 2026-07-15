// lib/models/line_item.dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'line_item.g.dart';

@HiveType(typeId: 2)
class LineItem {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String description;
  
  @HiveField(2)
  final int quantity;
  
  @HiveField(3)
  final double unitPrice;
  
  @HiveField(4)
  final double taxRate;
  
  @HiveField(5)
  final double total;

  LineItem({
    String? id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.taxRate = 18,
  }) : id = id ?? const Uuid().v4(),
       total = (quantity * unitPrice) * (1 + taxRate / 100);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'taxRate': taxRate,
      'total': total,
    };
  }

  factory LineItem.fromMap(Map<String, dynamic> map) {
    return LineItem(
      id: map['id'] ?? const Uuid().v4(),
      description: map['description'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      taxRate: (map['taxRate'] as num?)?.toDouble() ?? 18,
    );
  }

  LineItem copyWith({
    String? description,
    int? quantity,
    double? unitPrice,
    double? taxRate,
  }) {
    return LineItem(
      id: id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      taxRate: taxRate ?? this.taxRate,
    );
  }
}
