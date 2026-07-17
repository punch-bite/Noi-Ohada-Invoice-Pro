// lib/models/analytics_data.dart
import 'package:flutter/material.dart';

class SalesData {
  final String month;
  final double revenue;
  final int orders; // Changement en int car un nombre de commande est un entier

  SalesData({
    required this.month,
    required this.revenue,
    required this.orders,
  });

  /// Getter utilitaire pour les librairies de graphiques nécessitant des doubles
  double get ordersAsDouble => orders.toDouble();

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'revenue': revenue,
      'orders': orders,
    };
  }

  factory SalesData.fromMap(Map<String, dynamic> map) {
    return SalesData(
      month: map['month'] ?? '',
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
      orders: (map['orders'] as num?)?.toInt() ?? 0,
    );
  }

  static List<SalesData> get sampleData => [
        SalesData(month: 'Jan', revenue: 32000, orders: 45),
        SalesData(month: 'Fév', revenue: 28000, orders: 38),
        SalesData(month: 'Mar', revenue: 35000, orders: 52),
        SalesData(month: 'Avr', revenue: 31000, orders: 48),
        SalesData(month: 'Mai', revenue: 38000, orders: 61),
        SalesData(month: 'Juin', revenue: 42000, orders: 73),
        SalesData(month: 'Juil', revenue: 39000, orders: 68),
        SalesData(month: 'Aoû', revenue: 45000, orders: 82),
        SalesData(month: 'Sep', revenue: 47000, orders: 91),
        SalesData(month: 'Oct', revenue: 51000, orders: 105),
        SalesData(month: 'Nov', revenue: 49000, orders: 98),
        SalesData(month: 'Déc', revenue: 56000, orders: 120),
      ];
}

class CategoryData {
  final String category;
  final double value;
  final String colorHex; // Renommé pour plus de clarté technique

  CategoryData({
    required this.category,
    required this.value,
    this.colorHex = '#1976D2',
  });


  /// Convertit la chaîne Hexadécimale (#RRGGBB ou #AARRGGBB) en objet [Color] Flutter utilisable directement
  Color get color {
    String hex = colorHex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex'; // Ajout de l'opacité à 100% par défaut
    }
    final intColor = int.tryParse(hex, radix: 16);
    return intColor != null ? Color(intColor) : Colors.blue;
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'value': value,
      'colorHex': colorHex,
    };
  }

  factory CategoryData.fromMap(Map<String, dynamic> map) {
    return CategoryData(
      category: map['category'] ?? '',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      colorHex: map['colorHex'] ?? '#1976D2',
    );
  }

  static List<CategoryData> get sampleData => [
        CategoryData(
            category: 'Électronique', value: 55640, colorHex: '#1976D2'),
        CategoryData(category: 'Mobilier', value: 11420, colorHex: '#FF9800'),
        CategoryData(category: 'Vêtements', value: 1840, colorHex: '#4CAF50'),
        CategoryData(category: 'Chaussures', value: 2120, colorHex: '#9C27B0'),
        CategoryData(category: 'Accessoires', value: 980, colorHex: '#F44336'),
      ];

  // ignore: recursive_getters
  get month => month;

  // ignore: recursive_getters
  get revenue => revenue;

  // ignore: recursive_getters
  get orders => orders;

  
@override
String toString() => 'SalesData(month: $month, revenue: $revenue, orders: $orders)';
  
}
