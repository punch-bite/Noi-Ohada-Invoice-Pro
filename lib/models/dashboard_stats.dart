// lib/models/dashboard_stats.dart
import 'package:flutter/material.dart';

class DashboardStats {
  final double netRevenue;
  final double revenueChange;
  final double arr;
  final double arrChange;
  final double goalProgress;
  final double goalTarget;
  final int newOrders;
  final double ordersChange;
  final double totalProfit;
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

  // Getters formatés
  String get formattedNetRevenue => _formatCurrency(netRevenue);
  String get formattedARR => _formatCurrency(arr);
  String get formattedGoalTarget => _formatCurrency(goalTarget);
  String get formattedTotalProfit => _formatCurrency(totalProfit);
  String get formattedTotalSales => _formatCurrency(totalSales);

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}

class Customer {
  final String name;
  final int deals;
  final double totalValue;

  Customer({
    required this.name,
    required this.deals,
    required this.totalValue,
  });

  String get formattedValue => 
      totalValue >= 1000 
          ? '${(totalValue / 1000).toStringAsFixed(0)}K' 
          : totalValue.toStringAsFixed(0);

  static List<Customer> get sampleCustomers => [
    Customer(name: 'Danny Liu', deals: 1023, totalValue: 37431),
    Customer(name: 'Bella Deviant', deals: 963, totalValue: 30423),
    Customer(name: 'Darrell Steward', deals: 843, totalValue: 28549),
    Customer(name: 'Sophia Chen', deals: 712, totalValue: 22150),
    Customer(name: 'Marcus Johnson', deals: 654, totalValue: 18920),
  ];
}

class NotificationItem {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool isUrgent;

  NotificationItem({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.isUrgent = false,
  });

  static List<NotificationItem> get sampleNotifications => [
    NotificationItem(
      title: '56 New users registered',
      icon: Icons.person_add,
      color: Colors.blue,
      isUrgent: true,
    ),
    NotificationItem(
      title: '132 Orders placed',
      icon: Icons.shopping_cart,
      color: Colors.green,
    ),
    NotificationItem(
      title: 'Funds have been withdrawn',
      icon: Icons.payment,
      color: Colors.orange,
    ),
    NotificationItem(
      title: '5 Unread messages',
      icon: Icons.message,
      color: Colors.purple,
      isUrgent: true,
    ),
    NotificationItem(
      title: '11% vs last quarter',
      icon: Icons.trending_up,
      color: Colors.teal,
    ),
  ];
}

class ActivityItem {
  final String title;
  final String? detail;
  final DateTime timestamp;

  ActivityItem({
    required this.title,
    this.detail,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

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

class SalesCategory {
  final String name;
  final double value;
  final List<SalesSubCategory> subCategories;

  SalesCategory({
    required this.name,
    required this.value,
    this.subCategories = const [],
  });

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
}