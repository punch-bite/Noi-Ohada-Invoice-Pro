// lib/models/line_item.dart
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'line_item.g.dart';

@JsonSerializable()
@HiveType(typeId: 3)
class LineItem {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String description;
  
  @HiveField(2)
  final int quantity;
  
  @HiveField(3)
  final double unitPrice; // Prix unitaire Hors Taxes (HT)
  
  @HiveField(4)
  final double taxRate; // Taux de TVA en pourcentage brut (ex: 18.0 ou 19.25)
  
  @HiveField(5)
  final double total; // Montant global Toutes Taxes Comprises (TTC) pour cette ligne

  LineItem({
    String? id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.taxRate = 18.0,
  })  : id = id ?? const Uuid().v4(),
        total = (quantity * unitPrice) * (1 + taxRate / 100);

  /// Prix total de la ligne Hors Taxes (HT)
  double get totalPrice => quantity * unitPrice;

  /// Montant de la taxe appliquée uniquement à cette ligne
  double get taxAmount => totalPrice * (taxRate / 100);

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
    final double uPrice = (map['unitPrice'] as num?)?.toDouble() ?? 0.0;
    final int qty = (map['quantity'] as num?)?.toInt() ?? 0;
    final double tRate = (map['taxRate'] as num?)?.toDouble() ?? 18.0;

    return LineItem(
      id: map['id'] ?? const Uuid().v4(),
      description: map['description'] ?? '',
      quantity: qty,
      unitPrice: uPrice,
      taxRate: tRate,
    );
  }

  LineItem copyWith({
    String? id,
    String? description,
    int? quantity,
    double? unitPrice,
    double? taxRate,
  }) {
    return LineItem(
      id: id ?? this.id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      taxRate: taxRate ?? this.taxRate,
    );
  }
}