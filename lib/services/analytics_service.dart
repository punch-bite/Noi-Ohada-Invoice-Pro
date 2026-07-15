// lib/services/analytics_service.dart
import '../models/invoice.dart';
import '../services/database_service.dart';

class AnalyticsService {
  final DatabaseService _db = DatabaseService();

  // ===== STATISTIQUES GÉNÉRALES =====
  Future<Map<String, dynamic>> getGeneralStats() async {
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
    };
  }

  // ===== STATISTIQUES MENSUELLES =====
  Future<List<Map<String, dynamic>>> getMonthlyStats() async {
    final invoices = await _db.getInvoices();
    final Map<String, Map<String, dynamic>> monthlyData = {};

    for (final invoice in invoices) {
      final monthKey = '${invoice.issueDate.year}-${invoice.issueDate.month.toString().padLeft(2, '0')}';
      final monthLabel = '${_getMonthName(invoice.issueDate.month)} ${invoice.issueDate.year}';

      if (!monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] = {
          'month': monthLabel,
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

      final data = monthlyData[monthKey]!;
      data['revenue'] = (data['revenue'] as double) + invoice.totalAmount;
      data['count'] = (data['count'] as int) + 1;

      if (invoice.status == 'paid') {
        data['paid'] = (data['paid'] as double) + invoice.totalAmount;
        data['paidCount'] = (data['paidCount'] as int) + 1;
      } else if (invoice.status == 'sent') {
        data['pending'] = (data['pending'] as double) + invoice.totalAmount;
        data['pendingCount'] = (data['pendingCount'] as int) + 1;
      } else if (invoice.status == 'overdue') {
        data['overdue'] = (data['overdue'] as double) + invoice.totalAmount;
        data['overdueCount'] = (data['overdueCount'] as int) + 1;
      }
    }

    return monthlyData.values.toList()
      ..sort((a, b) => a['month'].compareTo(b['month']));
  }

  // ===== STATISTIQUES PAR CATÉGORIE =====
  Future<List<Map<String, dynamic>>> getCategoryStats() async {
    final invoices = await _db.getInvoices();
    final Map<String, double> categoryData = {};

    for (final invoice in invoices) {
      // Simuler des catégories basées sur les produits
      for (final item in invoice.items) {
        final category = _getProductCategory(item.description);
        categoryData[category] = (categoryData[category] ?? 0) + (item.quantity * item.unitPrice);
      }
    }

    return categoryData.entries.map((entry) => {
      'category': entry.key,
      'value': entry.value,
    }).toList();
  }

  // ===== STATISTIQUES DES CLIENTS =====
  Future<List<Map<String, dynamic>>> getClientStats() async {
    final invoices = await _db.getInvoices();
    final Map<String, Map<String, dynamic>> clientData = {};

    for (final invoice in invoices) {
      if (!clientData.containsKey(invoice.clientId)) {
        clientData[invoice.clientId] = {
          'clientId': invoice.clientId,
          'totalAmount': 0.0,
          'invoiceCount': 0,
          'paidAmount': 0.0,
          'paidCount': 0,
        };
      }

      final data = clientData[invoice.clientId]!;
      data['totalAmount'] = (data['totalAmount'] as double) + invoice.totalAmount;
      data['invoiceCount'] = (data['invoiceCount'] as int) + 1;

      if (invoice.status == 'paid') {
        data['paidAmount'] = (data['paidAmount'] as double) + invoice.totalAmount;
        data['paidCount'] = (data['paidCount'] as int) + 1;
      }
    }

    // Ajouter les noms des clients
    final clients = await _db.getClients();
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
  }

  // ===== STATISTIQUES DE PAIEMENT =====
  Future<Map<String, dynamic>> getPaymentStats() async {
    final invoices = await _db.getInvoices();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final monthlyRevenue = invoices
        .where((inv) => inv.issueDate.isAfter(monthStart) || inv.issueDate.isAtSameMomentAs(monthStart))
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);

    final dailyRevenue = invoices
        .where((inv) => inv.issueDate.day == now.day && inv.issueDate.month == now.month)
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);

    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weeklyRevenue = invoices
        .where((inv) => inv.issueDate.isAfter(weekStart) || inv.issueDate.isAtSameMomentAs(weekStart))
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);

    return {
      'monthlyRevenue': monthlyRevenue,
      'weeklyRevenue': weeklyRevenue,
      'dailyRevenue': dailyRevenue,
      'averageProcessingTime': _calculateAverageProcessingTime(invoices),
    };
  }

  // ===== STATISTIQUES DE PERFORMANCE =====
  Future<Map<String, dynamic>> getPerformanceStats() async {
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
    };
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
}