// lib/models/product.dart
import 'package:flutter/material.dart'; // ✅ AJOUTER CET IMPORT
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'product.g.dart';

@HiveType(typeId: 4)
class Product {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String category;

  @HiveField(4)
  final double price;

  @HiveField(5)
  final double costPrice;

  @HiveField(6)
  final int quantity;

  @HiveField(7)
  final int minStock;

  @HiveField(8)
  final String unit;

  @HiveField(9)
  final String? barcode;

  @HiveField(10)
  final String? imagePath;

  @HiveField(11)
  final bool isActive;

  @HiveField(12)
  final DateTime createdAt;

  @HiveField(13)
  final DateTime? updatedAt;

  @HiveField(14) // Nouveau champ
  final String? supplierId; // Référence vers un fournisseur

  Product({
    String? id,
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
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'supplierId': supplierId,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? const Uuid().v4(),
      supplierId: map['supplierId'],
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0,
      quantity: map['quantity'] ?? 0,
      minStock: map['minStock'] ?? 5,
      unit: map['unit'] ?? 'pièce',
      barcode: map['barcode'],
      imagePath: map['imagePath'],
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt:
          map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
    );
  }

  // ===== GETTERS =====

  bool get isLowStock => quantity <= minStock;
  bool get isOutOfStock => quantity <= 0;
  double get stockValue => quantity * price;

  String get formattedPrice => '$price FCFA';
  String get formattedCostPrice => '$costPrice FCFA';
  String get formattedStockValue => '${stockValue.toStringAsFixed(0)} FCFA';

  String get statusLabel {
    if (isOutOfStock) return 'Rupture';
    if (isLowStock) return 'Stock faible';
    return 'En stock';
  }

  // ✅ Maintenant Colors est disponible
  Color get statusColor {
    if (isOutOfStock) return Colors.red;
    if (isLowStock) return Colors.orange;
    return Colors.green;
  }

  bool get isValid {
    return name.isNotEmpty && price > 0 && quantity >= 0 && minStock >= 0;
  }

  // ===== COPY WITH =====
  Product copyWith({
    String? name,
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
    DateTime? updatedAt,
    String? supplierId,
  }) {
    return Product(
      id: id,
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
      updatedAt: updatedAt ?? DateTime.now(),
      supplierId: supplierId ?? this.supplierId,
    );
  }

  // ===== FACTORY =====

  factory Product.mock() {
    return Product(
      name: 'Produit exemple',
      description: 'Description du produit',
      category: 'Électronique',
      price: 1500,
      costPrice: 1000,
      quantity: 10,
      minStock: 3,
      unit: 'pièce',
    );
  }
}
