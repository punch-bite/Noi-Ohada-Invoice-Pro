import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'product.g.dart';

@HiveType(typeId: 5)
class Product {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String userId;
  @HiveField(2)
  final String name;
  @HiveField(3)
  final String description;
  @HiveField(4)
  final String category;
  @HiveField(5)
  final double price;
  @HiveField(6)
  final double costPrice;
  @HiveField(7)
  final int quantity;
  @HiveField(8)
  final int minStock;
  @HiveField(9)
  final String unit;
  @HiveField(10)
  final String? barcode;
  @HiveField(11)
  final String? imagePath;
  @HiveField(12)
  final bool isActive;
  @HiveField(13)
  final DateTime createdAt;
  @HiveField(14)
  final DateTime? updatedAt;
  @HiveField(15)
  final String? supplierId;
  @HiveField(16)
  final bool isSynced;

  Product({
    String? id,
    required this.userId,
    required this.name,
    this.description = '',
    this.category = '',
    required this.price,
    this.costPrice = 0,
    this.quantity = 0,
    this.minStock = 5,
    this.unit = 'pièce',
    this.barcode,
    this.imagePath,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
    this.supplierId,
    this.isSynced = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'costPrice': costPrice,
      'quantity': quantity,
      'minStock': minStock,
      'unit': unit,
      'barcode': barcode,
      'imagePath': imagePath,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'supplierId': supplierId,
      'isSynced': isSynced,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Product(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      minStock: (map['minStock'] as num?)?.toInt() ?? 5,
      unit: map['unit'] ?? 'pièce',
      barcode: map['barcode'],
      imagePath: map['imagePath'],
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null
          ? _parseDateTime(map['createdAt'])
          : DateTime.now(),
      updatedAt:
          map['updatedAt'] != null ? _parseDateTime(map['updatedAt']) : null,
      supplierId: map['supplierId'],
      isSynced: map['isSynced'] ?? false,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  bool get isLowStock => quantity <= minStock;
  bool get isOutOfStock => quantity <= 0;
  double get stockValue => quantity * price;

  Product copyWith(
      {String? name,
      String? description,
      String? category,
      double? price,
      double? costPrice,
      int? quantity,
      int? minStock,
      String? unit,
      String? barcode,
      String? imagePath,
      bool? isActive,
      String? supplierId,
      bool? isSynced,
      required DateTime updatedAt}) {
    return Product(
      id: id,
      userId: userId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      quantity: quantity ?? this.quantity,
      minStock: minStock ?? this.minStock,
      unit: unit ?? this.unit,
      barcode: barcode ?? this.barcode,
      imagePath: imagePath ?? this.imagePath,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      supplierId: supplierId ?? this.supplierId,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  String get formattedPrice => '$price FCFA';
  String get formattedCostPrice => '$costPrice FCFA';
  String get formattedStockValue => '${stockValue.toStringAsFixed(0)} FCFA';

  String get statusLabel {
    if (isOutOfStock) return 'Rupture';
    if (isLowStock) return 'Stock faible';
    return 'En stock';
  }

  Color get statusColor {
    if (isOutOfStock) return Colors.red;
    if (isLowStock) return Colors.orange;
    return Colors.green;
  }

  IconData get statusIcon {
    if (isOutOfStock) return Icons.dangerous;
    if (isLowStock) return Icons.warning_amber;
    return Icons.check_circle;
  }
}
