// lib/services/analytics_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../models/invoice.dart';
import '../services/database_service.dart';
import '../services/stock_service.dart';
import '../services/subscription_service.dart';

class AnalyticsService {
  final DatabaseService _db = DatabaseService();
  final StockService _stockService = StockService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  // ===== STATISTIQUES GÉNÉRALES (avec cache optionnel) =====

  Future<Map<String, dynamic>> getGeneralStats() async {
    try {
      final invoices = await _db.getInvoices();
      final clients = await _db.getClients();

      final totalRevenue = invoices.fold(0.0, (sum, inv) => sum + inv.totalAmount);
      final totalPaid = invoices
          .where((inv) => inv.status == 'paid')
          .fold(0.0, (sum, inv) => sum + inv.totalAmount);
      final totalPending = invoices
          .where((inv) => inv.status == 'sent')
          .fold(0.0, (sum, inv) => sum + inv.totalAmount);
      final totalOverdue = invoices
          .where((inv) => inv.status == 'overdue')
          .fold(0.0, (sum, inv) => sum + inv.totalAmount);
      final totalCancelled = invoices
          .where((inv) => inv.status == 'cancelled')
          .fold(0.0, (sum, inv) => sum + inv.totalAmount);

      return {
        'totalInvoices': invoices.length,
        'totalClients': clients.length,
        'totalRevenue': totalRevenue,
        'totalPaid': totalPaid,
        'totalPending': totalPending,
        'totalOverdue': totalOverdue,
        'totalCancelled': totalCancelled,
        'paidPercentage': totalRevenue > 0 ? (totalPaid / totalRevenue) * 100 : 0,
        'pendingPercentage': totalRevenue > 0 ? (totalPending / totalRevenue) * 100 : 0,
        'overduePercentage': totalRevenue > 0 ? (totalOverdue / totalRevenue) * 100 : 0,
        'cancelledPercentage': totalRevenue > 0 ? (totalCancelled / totalRevenue) * 100 : 0,
        'averageInvoiceValue': invoices.isNotEmpty ? totalRevenue / invoices.length : 0,
        'collectionRate': totalRevenue > 0 ? (totalPaid / totalRevenue) * 100 : 0,
      };
    } catch (e) {
      print('❌ Erreur getGeneralStats: $e');
      return {};
    }
  }

  // ===== STATISTIQUES MENSUELLES (12 derniers mois) =====

  Future<List<Map<String, dynamic>>> getMonthlyStats({int months = 12}) async {
    try {
      final invoices = await _db.getInvoices();
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month - months + 1, 1);
      final filtered = invoices.where((inv) => inv.issueDate.isAfter(monthStart) || inv.issueDate.isAtSameMomentAs(monthStart)).toList();

      final Map<String, Map<String, dynamic>> monthlyData = {};

      for (final invoice in filtered) {
        final monthKey = '${invoice.issueDate.year}-${invoice.issueDate.month.toString().padLeft(2, '0')}';
        final monthLabel = '${_getMonthName(invoice.issueDate.month)} ${invoice.issueDate.year}';

        monthlyData.putIfAbsent(monthKey, () => {
          'month': monthLabel,
          'revenue': 0.0,
          'count': 0,
          'paid': 0.0,
          'pending': 0.0,
          'overdue': 0.0,
          'paidCount': 0,
          'pendingCount': 0,
          'overdueCount': 0,
        });

        final data = monthlyData[monthKey]!;
        data['revenue'] = (data['revenue'] as double) + invoice.totalAmount;
        data['count'] = (data['count'] as int) + 1;

        switch (invoice.status) {
          case 'paid':
            data['paid'] = (data['paid'] as double) + invoice.totalAmount;
            data['paidCount'] = (data['paidCount'] as int) + 1;
            break;
          case 'sent':
            data['pending'] = (data['pending'] as double) + invoice.totalAmount;
            data['pendingCount'] = (data['pendingCount'] as int) + 1;
            break;
          case 'overdue':
            data['overdue'] = (data['overdue'] as double) + invoice.totalAmount;
            data['overdueCount'] = (data['overdueCount'] as int) + 1;
            break;
        }
      }

      // Remplir les mois manquants avec 0 pour avoir un graphique complet
      final allMonths = <String, Map<String, dynamic>>{};
      for (int i = months - 1; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        final label = '${_getMonthName(date.month)} ${date.year}';
        allMonths[key] = {
          'month': label,
          'revenue': 0.0,
          'count': 0,
          'paid': 0.0,
          'pending': 0.0,
          'overdue': 0.0,
          'paidCount': 0,
          'pendingCount': 0,
          'overdueCount': 0,
        };
      }

      // Fusionner avec les données réelles
      for (final entry in monthlyData.entries) {
        if (allMonths.containsKey(entry.key)) {
          allMonths[entry.key] = entry.value;
        }
      }

      return allMonths.values.toList();
    } catch (e) {
      print('❌ Erreur getMonthlyStats: $e');
      return [];
    }
  }

  // ===== STATISTIQUES PAR CATÉGORIE =====

  Future<List<Map<String, dynamic>>> getCategoryStats() async {
    try {
      final invoices = await _db.getInvoices();
      final Map<String, double> categoryData = {};

      for (final invoice in invoices) {
        for (final item in invoice.items) {
          final category = _getProductCategory(item.description);
          categoryData[category] = (categoryData[category] ?? 0) + (item.quantity * item.unitPrice);
        }
      }

      // Trier par valeur décroissante
      final sorted = categoryData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return sorted.map((entry) => {
        'category': entry.key,
        'value': entry.value,
      }).toList();
    } catch (e) {
      print('❌ Erreur getCategoryStats: $e');
      return [];
    }
  }

  // ===== STATISTIQUES DES CLIENTS =====

  Future<List<Map<String, dynamic>>> getClientStats() async {
    try {
      final invoices = await _db.getInvoices();
      final clients = await _db.getClients();
      final Map<String, Map<String, dynamic>> clientData = {};

      for (final invoice in invoices) {
        clientData.putIfAbsent(invoice.clientId, () => {
          'clientId': invoice.clientId,
          'totalAmount': 0.0,
          'invoiceCount': 0,
          'paidAmount': 0.0,
          'paidCount': 0,
        });

        final data = clientData[invoice.clientId]!;
        data['totalAmount'] = (data['totalAmount'] as double) + invoice.totalAmount;
        data['invoiceCount'] = (data['invoiceCount'] as int) + 1;

        if (invoice.status == 'paid') {
          data['paidAmount'] = (data['paidAmount'] as double) + invoice.totalAmount;
          data['paidCount'] = (data['paidCount'] as int) + 1;
        }
      }

      final clientMap = {for (var c in clients) c.id: c.name};

      return clientData.values.map((data) => {
        'clientId': data['clientId'],
        'clientName': clientMap[data['clientId']] ?? 'Client inconnu',
        'totalAmount': data['totalAmount'],
        'invoiceCount': data['invoiceCount'],
        'paidAmount': data['paidAmount'],
        'paidCount': data['paidCount'],
        'paymentRate': data['invoiceCount'] > 0 
            ? (data['paidCount'] / data['invoiceCount']) * 100 
            : 0,
      }).toList()
        ..sort((a, b) => (b['totalAmount'] as double).compareTo(a['totalAmount'] as double));
    } catch (e) {
      print('❌ Erreur getClientStats: $e');
      return [];
    }
  }

  // ===== STATISTIQUES DE PAIEMENT =====

  Future<Map<String, dynamic>> getPaymentStats() async {
    try {
      final invoices = await _db.getInvoices();
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));

      final monthlyRevenue = invoices
          .where((inv) => inv.issueDate.isAfter(monthStart) || inv.issueDate.isAtSameMomentAs(monthStart))
          .fold(0.0, (sum, inv) => sum + inv.totalAmount);

      final dailyRevenue = invoices
          .where((inv) => inv.issueDate.day == now.day && inv.issueDate.month == now.month)
          .fold(0.0, (sum, inv) => sum + inv.totalAmount);

      final weeklyRevenue = invoices
          .where((inv) => inv.issueDate.isAfter(weekStart) || inv.issueDate.isAtSameMomentAs(weekStart))
          .fold(0.0, (sum, inv) => sum + inv.totalAmount);

      // Calcul du délai moyen de paiement (jours entre émission et paiement)
      final paidInvoices = invoices.where((inv) => inv.status == 'paid');
      double avgDelay = 0;
      if (paidInvoices.isNotEmpty) {
        int totalDays = 0;
        for (final inv in paidInvoices) {
          // On simule un paiement 15 jours après l'émission (à remplacer par une date réelle)
          final paidDate = inv.issueDate.add(Duration(days: 15));
          totalDays += paidDate.difference(inv.issueDate).inDays;
        }
        avgDelay = totalDays / paidInvoices.length;
      }

      return {
        'monthlyRevenue': monthlyRevenue,
        'weeklyRevenue': weeklyRevenue,
        'dailyRevenue': dailyRevenue,
        'averagePaymentDelay': avgDelay,
        'averageProcessingTime': _calculateAverageProcessingTime(invoices),
      };
    } catch (e) {
      print('❌ Erreur getPaymentStats: $e');
      return {};
    }
  }

  // ===== STATISTIQUES DE PERFORMANCE =====

  Future<Map<String, dynamic>> getPerformanceStats() async {
    try {
      final invoices = await _db.getInvoices();
      final clients = await _db.getClients();

      final totalRevenue = invoices.fold(0.0, (sum, inv) => sum + inv.totalAmount);
      final paidCount = invoices.where((inv) => inv.status == 'paid').length;

      return {
        'totalRevenue': totalRevenue,
        'totalInvoices': invoices.length,
        'totalClients': clients.length,
        'paidInvoices': paidCount,
        'paymentRate': invoices.isNotEmpty ? (paidCount / invoices.length) * 100 : 0,
        'averageInvoiceValue': invoices.isNotEmpty ? totalRevenue / invoices.length : 0,
        'revenuePerClient': clients.isNotEmpty ? totalRevenue / clients.length : 0,
        'overdueRate': invoices.isNotEmpty 
            ? (invoices.where((inv) => inv.status == 'overdue').length / invoices.length) * 100 
            : 0,
      };
    } catch (e) {
      print('❌ Erreur getPerformanceStats: $e');
      return {};
    }
  }

  // ===== STATISTIQUES DES ABONNEMENTS =====

  Future<Map<String, dynamic>> getSubscriptionStats() async {
    try {
      final subscriptions = await _subscriptionService.getActiveSubscriptions(); // Récupère tous les abonnements (actifs/inactifs)
      final total = subscriptions.length;
      final active = subscriptions.where((s) => s.isActive).length;
      final expired = subscriptions.where((s) => s.isExpired).length;
      final canceled = subscriptions.where((s) => s.isCanceled).length;
      final trial = subscriptions.where((s) => s.isTrial).length;

      return {
        'total': total,
        'active': active,
        'expired': expired,
        'canceled': canceled,
        'trial': trial,
        'conversionRate': total > 0 ? (active / total) * 100 : 0,
        'churnRate': total > 0 ? ((canceled + expired) / total) * 100 : 0,
      };
    } catch (e) {
      print('❌ Erreur getSubscriptionStats: $e');
      return {};
    }
  }

  // ===== STATISTIQUES DU STOCK =====

  Future<Map<String, dynamic>> getStockStats() async {
    try {
      final products = await _stockService.getProducts();
      final totalItems = products.fold(0, (sum, p) => sum + p.quantity);
      final totalValue = products.fold(0.0, (sum, p) => sum + p.stockValue);
      final lowStock = products.where((p) => p.isLowStock).length;
      final outOfStock = products.where((p) => p.isOutOfStock).length;

      return {
        'totalProducts': products.length,
        'totalItems': totalItems,
        'totalStockValue': totalValue,
        'lowStockCount': lowStock,
        'outOfStockCount': outOfStock,
        'averagePrice': products.isNotEmpty 
            ? products.fold(0.0, (sum, p) => sum + p.price) / products.length 
            : 0,
      };
    } catch (e) {
      print('❌ Erreur getStockStats: $e');
      return {};
    }
  }

  // ===== STATISTIQUES POUR LES GRAPHIQUES =====

  /// Retourne les 12 derniers mois de revenus pour un graphique en barres
  Future<List<Map<String, dynamic>>> getRevenueTrend() async {
    final monthlyStats = await getMonthlyStats();
    return monthlyStats.map((m) => {
      'month': m['month'],
      'revenue': m['revenue'],
      'count': m['count'],
    }).toList();
  }

  /// Retourne la répartition des statuts des factures
  Future<Map<String, dynamic>> getInvoiceStatusDistribution() async {
    try {
      final invoices = await _db.getInvoices();
      final statusCount = {
        'paid': invoices.where((inv) => inv.status == 'paid').length,
        'sent': invoices.where((inv) => inv.status == 'sent').length,
        'overdue': invoices.where((inv) => inv.status == 'overdue').length,
        'cancelled': invoices.where((inv) => inv.status == 'cancelled').length,
        'draft': invoices.where((inv) => inv.status == 'draft').length,
      };
      final total = invoices.length;
      return {
        'distribution': statusCount,
        'total': total,
      };
    } catch (e) {
      print('❌ Erreur getInvoiceStatusDistribution: $e');
      return {};
    }
  }

  // ===== MÉTHODES PRIVÉES =====

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    return months[month - 1];
  }

  String _getProductCategory(String description) {
    final lower = description.toLowerCase();
    if (lower.contains('electronique') || lower.contains('ordinateur') || lower.contains('téléphone')) {
      return 'Électronique';
    } else if (lower.contains('meuble') || lower.contains('chaise') || lower.contains('table')) {
      return 'Mobilier';
    } else if (lower.contains('vêtement') || lower.contains('chaussure') || lower.contains('mode')) {
      return 'Mode';
    } else if (lower.contains('service') || lower.contains('consultation') || lower.contains('formation')) {
      return 'Services';
    } else if (lower.contains('aliment') || lower.contains('nourriture') || lower.contains('restaurant')) {
      return 'Alimentation';
    } else {
      return 'Autres';
    }
  }

  double _calculateAverageProcessingTime(List<Invoice> invoices) {
    final paidInvoices = invoices.where((inv) => inv.status == 'paid');
    if (paidInvoices.isEmpty) return 0;

    double totalDays = 0;
    int count = 0;

    for (final invoice in paidInvoices) {
      // Simuler un temps de traitement (à remplacer par des données réelles)
      final processingDays = (invoice.dueDate.difference(invoice.issueDate).inDays / 2).abs();
      totalDays += processingDays;
      count++;
    }

    return count > 0 ? totalDays / count : 0;
  }

  // ===== CACHE (optionnel avec Hive) =====

  Future<void> saveCacheStats(Map<String, dynamic> stats, {String key = 'analytics_cache'}) async {
    try {
      final box = await Hive.openBox('analytics_cache');
      await box.put(key, stats);
    } catch (e) {
      print('❌ Erreur sauvegarde cache: $e');
    }
  }

  Future<Map<String, dynamic>?> getCacheStats({String key = 'analytics_cache'}) async {
    try {
      final box = await Hive.openBox('analytics_cache');
      return box.get(key) as Map<String, dynamic>?;
    } catch (e) {
      print('❌ Erreur lecture cache: $e');
      return null;
    }
  }
}