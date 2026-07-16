// lib/models/financial_stats.dart
class FinancialStats {
  final double totalRevenue; // Chiffre d'affaires total (facturé / émis)
  final double totalPaid;
  final double totalPending;
  final double totalOverdue;
  final double totalCancelled;
  final int totalInvoices;
  final int paidCount;
  final int pendingCount;
  final int overdueCount;
  final int cancelledCount;
  final double averageInvoiceValue;

  FinancialStats({
    this.totalRevenue = 0.0,
    this.totalPaid = 0.0,
    this.totalPending = 0.0,
    this.totalOverdue = 0.0,
    this.totalCancelled = 0.0,
    this.totalInvoices = 0,
    this.paidCount = 0,
    this.pendingCount = 0,
    this.overdueCount = 0,
    this.cancelledCount = 0,
    this.averageInvoiceValue = 0.0,
  });

  // Calculs de pourcentages sécurisés
  double get paidPercentage => totalRevenue > 0 ? (totalPaid / totalRevenue) * 100 : 0.0;
  double get pendingPercentage => totalRevenue > 0 ? (totalPending / totalRevenue) * 100 : 0.0;
  double get overduePercentage => totalRevenue > 0 ? (totalOverdue / totalRevenue) * 100 : 0.0;
  double get cancelledPercentage => totalRevenue > 0 ? (totalCancelled / totalRevenue) * 100 : 0.0;

  // Getters de formatage dynamique (permet d'injecter la devise de Company)
  String getFormattedTotalRevenue([String currency = 'FCFA']) => _formatCurrency(totalRevenue, currency);
  String getFormattedTotalPaid([String currency = 'FCFA']) => _formatCurrency(totalPaid, currency);
  String getFormattedTotalPending([String currency = 'FCFA']) => _formatCurrency(totalPending, currency);
  String getFormattedTotalOverdue([String currency = 'FCFA']) => _formatCurrency(totalOverdue, currency);
  String getFormattedTotalCancelled([String currency = 'FCFA']) => _formatCurrency(totalCancelled, currency);
  String getFormattedAverageInvoice([String currency = 'FCFA']) => _formatCurrency(averageInvoiceValue, currency);

  String _formatCurrency(double value, String currency) {
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
      'totalRevenue': totalRevenue,
      'totalPaid': totalPaid,
      'totalPending': totalPending,
      'totalOverdue': totalOverdue,
      'totalCancelled': totalCancelled,
      'totalInvoices': totalInvoices,
      'paidCount': paidCount,
      'pendingCount': pendingCount,
      'overdueCount': overdueCount,
      'cancelledCount': cancelledCount,
      'averageInvoiceValue': averageInvoiceValue,
    };
  }

  factory FinancialStats.fromMap(Map<String, dynamic> map) {
    return FinancialStats(
      totalRevenue: (map['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (map['totalPaid'] as num?)?.toDouble() ?? 0.0,
      totalPending: (map['totalPending'] as num?)?.toDouble() ?? 0.0,
      totalOverdue: (map['totalOverdue'] as num?)?.toDouble() ?? 0.0,
      totalCancelled: (map['totalCancelled'] as num?)?.toDouble() ?? 0.0,
      totalInvoices: (map['totalInvoices'] as num?)?.toInt() ?? 0,
      paidCount: (map['paidCount'] as num?)?.toInt() ?? 0,
      pendingCount: (map['pendingCount'] as num?)?.toInt() ?? 0,
      overdueCount: (map['overdueCount'] as num?)?.toInt() ?? 0,
      cancelledCount: (map['cancelledCount'] as num?)?.toInt() ?? 0,
      averageInvoiceValue: (map['averageInvoiceValue'] as num?)?.toDouble() ?? 0.0,
    );
  }
} 