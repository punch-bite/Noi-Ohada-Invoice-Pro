// lib/models/analytics_data.dart
class SalesData {
  final String month;
  final double revenue;
  final double orders;

  SalesData({
    required this.month,
    required this.revenue,
    required this.orders,
  });

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
  final String color;

  CategoryData({
    required this.category,
    required this.value,
    this.color = '#1976D2',
  });

  static List<CategoryData> get sampleData => [
    CategoryData(category: 'Électronique', value: 55640, color: '#1976D2'),
    CategoryData(category: 'Mobilier', value: 11420, color: '#FF9800'),
    CategoryData(category: 'Vêtements', value: 1840, color: '#4CAF50'),
    CategoryData(category: 'Chaussures', value: 2120, color: '#9C27B0'),
    CategoryData(category: 'Accessoires', value: 980, color: '#F44336'),
  ];
}