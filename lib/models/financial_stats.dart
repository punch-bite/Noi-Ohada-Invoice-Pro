// lib/models/financial_stats.dart
class FinancialStats {
  final double totalRevenue;
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
    this.totalRevenue = 0.0,  // ✅ Utiliser 0.0 pour double
    this.totalPaid = 0.0,
    this.totalPending = 0.0,
    this.totalOverdue = 0.0,
    this.totalCancelled = 0.0,
    this.totalInvoices = 0,
    this.paidCount = 0,
    this.pendingCount = 0,
    this.overdueCount = 0,
    this.cancelledCount = 0,
    this.averageInvoiceValue = 0.0,  // ✅ Utiliser 0.0 pour double
  });

  double get paidPercentage => totalRevenue > 0 ? (totalPaid / totalRevenue) * 100 : 0;
  double get pendingPercentage => totalRevenue > 0 ? (totalPending / totalRevenue) * 100 : 0;
  double get overduePercentage => totalRevenue > 0 ? (totalOverdue / totalRevenue) * 100 : 0;
  double get cancelledPercentage => totalRevenue > 0 ? (totalCancelled / totalRevenue) * 100 : 0;

  String get formattedTotalRevenue => _formatCurrency(totalRevenue);
  String get formattedTotalPaid => _formatCurrency(totalPaid);
  String get formattedTotalPending => _formatCurrency(totalPending);
  String get formattedTotalOverdue => _formatCurrency(totalOverdue);
  String get formattedTotalCancelled => _formatCurrency(totalCancelled);
  String get formattedAverageInvoice => _formatCurrency(averageInvoiceValue);

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M FCFA';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K FCFA';
    }
    return '${value.toStringAsFixed(0)} FCFA';
  }
}