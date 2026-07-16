// lib/models/dashboard_stats.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart'; // Pour Hive (optionnel)
import 'package:json_annotation/json_annotation.dart';
import 'activity_log.dart';

part 'dashboard_stats.g.dart';
// ============================================================
//  DASHBOARD STATS (Stats globales du tableau de bord)
// ============================================================
@JsonSerializable()
@HiveType(typeId: 2) // À ajouter si tu veux stocker les stats en cache Hive
class DashboardStats {
  @HiveField(0)
  final double netRevenue;

  @HiveField(1)
  final double revenueChange; // ex: 0.4 → +40%

  @HiveField(2)
  final double arr; // Annual Recurring Revenue

  @HiveField(3)
  final double arrChange;

  @HiveField(4)
  final double goalProgress; // ex: 71 → 71%

  @HiveField(5)
  final double goalTarget;

  @HiveField(6)
  final int newOrders;

  @HiveField(7)
  final double ordersChange;

  @HiveField(8)
  final double totalProfit;

  @HiveField(9)
  final double totalSales;

  DashboardStats({
    this.netRevenue = 3131021,
    this.revenueChange = 0.4,
    this.arr = 1511121,
    this.arrChange = 32,
    this.goalProgress = 71,
    this.goalTarget = 1100000,
    this.newOrders = 18221,
    this.ordersChange = 11,
    this.totalProfit = 136755.77,
    this.totalSales = 71020,
  });

  // ===== FORMATAGE =====

  String getFormattedNetRevenue([String currency = 'FCFA']) => _formatCurrency(netRevenue, currency);
  String getFormattedARR([String currency = 'FCFA']) => _formatCurrency(arr, currency);
  String getFormattedGoalTarget([String currency = 'FCFA']) => _formatCurrency(goalTarget, currency);
  String getFormattedTotalProfit([String currency = 'FCFA']) => _formatCurrency(totalProfit, currency);
  String getFormattedTotalSales([String currency = 'FCFA']) => _formatCurrency(totalSales, currency);

  String _formatCurrency(double value, String currency) {
    if (value == 0) return currency == 'FCFA' ? '0 FCFA' : '$currency 0';

    String suffix = '';
    double formattedValue = value;

    if (value >= 1000000) {
      formattedValue = value / 1000000;
      suffix = 'M';
    } else if (value >= 1000) {
      formattedValue = value / 1000;
      suffix = 'K';
    }

    final numberStr = formattedValue % 1 == 0
        ? formattedValue.toStringAsFixed(0)
        : formattedValue.toStringAsFixed(1);

    if (currency == 'FCFA' || currency == 'XAF' || currency == 'XOF') {
      return '$numberStr$suffix $currency';
    }
    return '$currency$numberStr$suffix';
  }

  // ===== SÉRIALISATION =====

  Map<String, dynamic> toMap() {
    return {
      'netRevenue': netRevenue,
      'revenueChange': revenueChange,
      'arr': arr,
      'arrChange': arrChange,
      'goalProgress': goalProgress,
      'goalTarget': goalTarget,
      'newOrders': newOrders,
      'ordersChange': ordersChange,
      'totalProfit': totalProfit,
      'totalSales': totalSales,
    };
  }

  factory DashboardStats.fromMap(Map<String, dynamic> map) {
    return DashboardStats(
      netRevenue: (map['netRevenue'] as num?)?.toDouble() ?? 0.0,
      revenueChange: (map['revenueChange'] as num?)?.toDouble() ?? 0.0,
      arr: (map['arr'] as num?)?.toDouble() ?? 0.0,
      arrChange: (map['arrChange'] as num?)?.toDouble() ?? 0.0,
      goalProgress: (map['goalProgress'] as num?)?.toDouble() ?? 0.0,
      goalTarget: (map['goalTarget'] as num?)?.toDouble() ?? 0.0,
      newOrders: (map['newOrders'] as num?)?.toInt() ?? 0,
      ordersChange: (map['ordersChange'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (map['totalProfit'] as num?)?.toDouble() ?? 0.0,
      totalSales: (map['totalSales'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Constructeur Firestore (si tu stockes les stats dans Firestore)
  factory DashboardStats.fromFirestore(Map<String, dynamic> map, {String? documentId}) {
    return DashboardStats.fromMap(map);
  }

  // Instance par défaut
  static DashboardStats get empty => DashboardStats();
}

// ============================================================
//  CUSTOMER (Client pour les statistiques)
// ============================================================

@HiveType(typeId: 13)
class Customer {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final int deals;

  @HiveField(2)
  final double totalValue;

  Customer({
    required this.name,
    required this.deals,
    required this.totalValue,
  });

  // Formatage
  String getFormattedValue([String currency = 'FCFA']) {
    final valueStr = totalValue >= 1000
        ? '${(totalValue / 1000).toStringAsFixed(0)}K'
        : totalValue.toStringAsFixed(0);
    return currency == 'FCFA' || currency == 'XAF' || currency == 'XOF'
        ? '$valueStr $currency'
        : '$currency$valueStr';
  }

  // SÉRIALISATION
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'deals': deals,
      'totalValue': totalValue,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      name: map['name'] ?? '',
      deals: (map['deals'] as num?)?.toInt() ?? 0,
      totalValue: (map['totalValue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory Customer.fromFirestore(Map<String, dynamic> map) => Customer.fromMap(map);

  static List<Customer> get sampleCustomers => [
    Customer(name: 'Danny Liu', deals: 1023, totalValue: 37431),
    Customer(name: 'Bella Deviant', deals: 963, totalValue: 30423),
    Customer(name: 'Darrell Steward', deals: 843, totalValue: 28549),
    Customer(name: 'Sophia Chen', deals: 712, totalValue: 22150),
    Customer(name: 'Marcus Johnson', deals: 654, totalValue: 18920),
  ];
}

// ============================================================
//  NOTIFICATION ITEM (pour le centre de notifications)
// ============================================================

class NotificationItem {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool isUrgent;

  const NotificationItem({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.isUrgent = false,
  });

  static List<NotificationItem> get sampleNotifications => [
    const NotificationItem(
      title: '56 New users registered',
      icon: Icons.person_add,
      color: Colors.blue,
      isUrgent: true,
    ),
    const NotificationItem(
      title: '132 Orders placed',
      icon: Icons.shopping_cart,
      color: Colors.green,
    ),
    const NotificationItem(
      title: 'Funds have been withdrawn',
      icon: Icons.payment,
      color: Colors.orange,
    ),
    const NotificationItem(
      title: '5 Unread messages',
      icon: Icons.message,
      color: Colors.purple,
      isUrgent: true,
    ),
    const NotificationItem(
      title: '11% vs last quarter',
      icon: Icons.trending_up,
      color: Colors.teal,
    ),
  ];
}

// ============================================================
//  ACTIVITY ITEM (pour le flux d'activités)
// ============================================================

class ActivityItem {
  final String title;
  final String? detail;
  final DateTime timestamp;

  ActivityItem({
    required this.title,
    this.detail,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  // ✅ Constructeur depuis un ActivityLog (utiliser la date du log)
  factory ActivityItem.fromLog(ActivityLog log) {
    return ActivityItem(
      title: log.action,
      detail: log.userEmail,
      timestamp: log.timestamp,
    );
  }

  // Formatage de la date (ex: "Il y a 2h")
  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays > 0) {
      return 'Il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
    } else if (diff.inHours > 0) {
      return 'Il y a ${diff.inHours} heure${diff.inHours > 1 ? 's' : ''}';
    } else if (diff.inMinutes > 0) {
      return 'Il y a ${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'detail': detail,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ActivityItem.fromMap(Map<String, dynamic> map) {
    return ActivityItem(
      title: map['title'] ?? '',
      detail: map['detail'],
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static List<ActivityItem> get sampleActivities => [
    ActivityItem(title: 'Changed the style'),
    ActivityItem(title: '177 New products added'),
    ActivityItem(title: '11 Products have been archived'),
    ActivityItem(title: 'Page "Toys" has been removed'),
    ActivityItem(
      title: 'Contacts of your managers',
      detail: 'Daniel Craig, Kate Morrison, Nathaniel Donovan',
    ),
  ];
}

// ============================================================
//  SALES CATEGORY (pour les graphiques)
// ============================================================

class SalesCategory {
  final String name;
  final double value;
  final List<SalesSubCategory> subCategories;

  SalesCategory({
    required this.name,
    required this.value,
    this.subCategories = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'value': value,
      'subCategories': subCategories.map((sc) => sc.toMap()).toList(),
    };
  }

  factory SalesCategory.fromMap(Map<String, dynamic> map) {
    return SalesCategory(
      name: map['name'] ?? '',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      subCategories: (map['subCategories'] as List?)
              ?.map((sc) => SalesSubCategory.fromMap(Map<String, dynamic>.from(sc)))
              .toList() ??
          [],
    );
  }

  static List<SalesCategory> get sampleSales => [
    SalesCategory(
      name: 'Electronics',
      value: 55640,
      subCategories: [
        SalesSubCategory(name: 'Weekly Vitals', value: 55640),
        SalesSubCategory(name: 'Clothes', value: 1840),
      ],
    ),
    SalesCategory(
      name: 'Furniture',
      value: 11420,
      subCategories: [
        SalesSubCategory(name: 'Weekly Vitals', value: 11420),
        SalesSubCategory(name: 'Shoes', value: 2120),
      ],
    ),
  ];
}

class SalesSubCategory {
  final String name;
  final double value;

  SalesSubCategory({
    required this.name,
    required this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'value': value,
    };
  }

  factory SalesSubCategory.fromMap(Map<String, dynamic> map) {
    return SalesSubCategory(
      name: map['name'] ?? '',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}