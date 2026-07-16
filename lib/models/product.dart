// lib/models/product.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'product.g.dart';

@JsonSerializable()
@HiveType(typeId: 5) // Modifié à 5 pour éviter le conflit avec Notification (typeId: 4)
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
  final double price; // Prix de vente HT / TTC

  @HiveField(5)
  final double costPrice; // Prix d'achat / de revient

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

  @HiveField(14)
  final String? supplierId; // Référence vers un fournisseur

  Product({
    String? id,
    required this.name,
    this.description = '',
    this.category = '',
    required this.price,
    this.costPrice = 0.0,
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

  // ===== SÉRIALISATION COMPATIBLE HIVE & FIRESTORE =====

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
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'supplierId': supplierId,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Product(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      minStock: (map['minStock'] as num?)?.toInt() ?? 5,
      unit: map['unit'] ?? 'pièce',
      barcode: map['barcode'],
      imagePath: map['imagePath'],
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null ? _parseDateTime(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? _parseDateTime(map['updatedAt']) : null,
      supplierId: map['supplierId'],
    );
  }

  // ===== GETTERS METIER & RENTABILITE =====

  bool get isLowStock => quantity <= minStock;
  bool get isOutOfStock => quantity <= 0;
  double get stockValue => quantity * price;

  /// Calcul de la marge brute par unité
  double get margin => price - costPrice;

  /// Pourcentage de marge brute sur le prix de vente
  double get marginPercentage => price > 0 ? (margin / price) * 100 : 0.0;

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

  bool get isValid {
    return name.isNotEmpty && price > 0 && quantity >= 0 && minStock >= 0;
  }

  // ===== CLONAGE (copyWith) =====

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

  // ===== FACTORIES & MOCKS =====

  factory Product.mock() {
    return Product(
      name: 'Produit exemple',
      description: 'Description du produit',
      category: 'Électronique',
      price: 1500.0,
      costPrice: 1000.0,
      quantity: 10,
      minStock: 3,
      unit: 'pièce',
    );
  }

  /// Fonction d'aide pour parser les dates de manière ultra-robuste
  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }
}