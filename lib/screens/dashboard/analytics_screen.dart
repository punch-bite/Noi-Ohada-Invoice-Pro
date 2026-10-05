// lib/screens/dashboard/analytics_screen.dart
// ignore_for_file: unused_field, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../models/invoice.dart';
import '../../models/client.dart';
import '../../providers/theme_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseService _db = DatabaseService();
  List<Invoice> _invoices = [];
  List<Client> _clients = [];
  bool _isLoading = true;

  // ── Données agrégées ──
  double _totalRevenue = 0;
  double _totalOrders = 0;
  double _avgOrderValue = 0;
  String _bestMonth = '';
  double _bestRevenue = 0;
  double _growth = 0;
  double _ordersGrowth = 0;
  double _avgGrowth = 0;
  Map<String, double> _monthlyRevenue = {};
  Map<String, double> _monthlyOrders = {};

  // ── 🆕 Métriques additionnelles ──
  List<({String name, double total, int count})> _topClients = [];
  Map<String, int> _statusCounts = {};
  double _paidAmount = 0;
  double _pendingAmount = 0;
  double _overdueAmount = 0;

  /// 📅 Filtre période : 1/3/6/12 derniers mois, null = tout l'historique.
  int? _periodMonths;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _db.getInvoices(),
        _db.getClients(),
      ]);
      _invoices = results[0] as List<Invoice>? ?? [];
      _clients = results[1] as List<Client>? ?? [];
      _processData();
    } catch (_) {
      // Les données restent vides en cas d'erreur
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData() {
    final now = DateTime.now();
    var paidInvoices = _invoices.where((inv) => inv.status == 'paid').toList();
    if (_periodMonths != null) {
      final cutoff = DateTime(now.year, now.month - (_periodMonths! - 1), 1);
      paidInvoices = paidInvoices
          .where((inv) => !inv.issueDate.isBefore(cutoff))
          .toList();
    }
    _totalRevenue = paidInvoices.fold(0, (sum, inv) => sum + inv.totalAmount);
    _totalOrders = paidInvoices.length.toDouble();
    _avgOrderValue = _totalOrders > 0 ? _totalRevenue / _totalOrders : 0;

    // Regroupement par mois
    final monthlyData = <String, double>{};
    for (final inv in paidInvoices) {
      final monthKey = DateFormat('MMM yyyy').format(inv.issueDate);
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + inv.totalAmount;
    }

    if (monthlyData.isNotEmpty) {
      final best =
          monthlyData.entries.reduce((a, b) => a.value > b.value ? a : b);
      _bestMonth = best.key;
      _bestRevenue = best.value;
    } else {
      _bestMonth = 'N/A';
      _bestRevenue = 0;
    }

    final months = monthlyData.keys.toList();
    _sortMonthsList(months);

    if (months.length >= 2) {
      final first = monthlyData[months.first] ?? 0;
      final last = monthlyData[months.last] ?? 0;
      _growth = first > 0 ? ((last - first) / first * 100) : 0;
    } else {
      _growth = 0;
    }

    _monthlyRevenue = monthlyData;
    _monthlyOrders = {};
    for (final inv in paidInvoices) {
      final monthKey = DateFormat('MMM yyyy').format(inv.issueDate);
      _monthlyOrders[monthKey] = (_monthlyOrders[monthKey] ?? 0) + 1;
    }

    // Croissance des commandes
    final orderData = <String, double>{};
    for (final inv in paidInvoices) {
      final monthKey = DateFormat('MMM yyyy').format(inv.issueDate);
      orderData[monthKey] = (orderData[monthKey] ?? 0) + 1;
    }
    final orderMonths = orderData.keys.toList();
    _sortMonthsList(orderMonths);
    if (orderMonths.length >= 2) {
      final firstOrders = orderData[orderMonths.first] ?? 0;
      final lastOrders = orderData[orderMonths.last] ?? 0;
      _ordersGrowth = firstOrders > 0
          ? ((lastOrders - firstOrders) / firstOrders * 100)
          : 0;
    } else {
      _ordersGrowth = 0;
    }
    if (months.length >= 2) {
      final firstRev = monthlyData[months.first] ?? 0;
      final firstOrd = orderData[months.first] ?? 0;
      final lastRev = monthlyData[months.last] ?? 0;
      final lastOrd = orderData[months.last] ?? 0;
      final firstAvg = firstOrd > 0 ? firstRev / firstOrd : 0;
      final lastAvg = lastOrd > 0 ? lastRev / lastOrd : 0;
      _avgGrowth = firstAvg > 0 ? ((lastAvg - firstAvg) / firstAvg * 100) : 0;
    } else {
      _avgGrowth = 0;
    }

    // 🆕 Top clients (factures payées, période filtrée)
    final clientTotals = <String, ({double total, int count})>{};
    for (final inv in paidInvoices) {
      final existing = clientTotals[inv.clientId] ?? (total: 0.0, count: 0);
      clientTotals[inv.clientId] = (
        total: existing.total + inv.totalAmount,
        count: existing.count + 1,
      );
    }
    final topList = <({String name, double total, int count})>[];
    for (final entry in clientTotals.entries) {
      String name = 'Client inconnu';
      for (final c in _clients) {
        if (c.id == entry.key) {
          name = c.name;
          break;
        }
      }
      topList.add(
          (name: name, total: entry.value.total, count: entry.value.count));
    }
    topList.sort((a, b) => b.total.compareTo(a.total));
    _topClients = topList.take(5).toList();

    // 🆕 Répartition par statut (toutes factures)
    final statusCounts = <String, int>{};
    double paidAmount = 0;
    double pendingAmount = 0;
    double overdueAmount = 0;
    for (final inv in _invoices) {
      statusCounts[inv.status] = (statusCounts[inv.status] ?? 0) + 1;
      switch (inv.status) {
        case 'paid':
          paidAmount += inv.totalAmount;
          break;
        case 'overdue':
          overdueAmount += inv.totalAmount;
          break;
        default:
          pendingAmount += inv.totalAmount;
          break;
      }
    }
    _statusCounts = statusCounts;
    _paidAmount = paidAmount;
    _pendingAmount = pendingAmount;
    _overdueAmount = overdueAmount;
  }

  void _sortMonthsList(List<String> monthsList) {
    monthsList.sort((a, b) {
      try {
        final dateA = DateFormat('MMM yyyy').parse(a);
        final dateB = DateFormat('MMM yyyy').parse(b);
        return dateA.compareTo(dateB);
      } catch (_) {
        return a.compareTo(b);
      }
    });
  }

  List<String> get _sortedMonths {
    final months = _monthlyRevenue.keys.toList();
    _sortMonthsList(months);
    return months;
  }

  List<double> get _revenueByMonth =>
      _sortedMonths.map((m) => _monthlyRevenue[m] ?? 0).toList();

  List<double> get _ordersByMonth =>
      _sortedMonths.map((m) => _monthlyOrders[m] ?? 0).toList();

  /// 📈 Cumul des revenus (utilisé par la courbe de tendance).
  List<double> get _cumulativeRevenue {
    final result = <double>[];
    double sum = 0;
    for (final v in _revenueByMonth) {
      sum += v;
      result.add(sum);
    }
    return result;
  }

  // ============================================================
  //  HELPERS
  // ============================================================

  String _kpiFormat(double value) {
    final abs = value.abs();
    if (abs >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1).replaceAll('.', ',')} Md';
    }
    if (abs >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
    }
    return NumberFormat('#,##0').format(value);
  }

  String get _periodLabel {
    switch (_periodMonths) {
      case 1:
        return 'Ce mois';
      case 3:
        return '3 derniers mois';
      case 6:
        return '6 derniers mois';
      case 12:
        return '12 derniers mois';
      default:
        return 'Tout l\'historique';
    }
  }

  void _showPeriodSheet() {
    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final options = <({String label, int? value})>[
          (label: 'Ce mois', value: 1),
          (label: '3 derniers mois', value: 3),
          (label: '6 derniers mois', value: 6),
          (label: '12 derniers mois', value: 12),
          (label: 'Tout l\'historique', value: null),
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subTextColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Période d\'analyse',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Filtre les factures payées sur la période choisie.',
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  final selected = _periodMonths == opt.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: selected
                          ? primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          setState(() => _periodMonths = opt.value);
                          _loadData();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 20,
                                color: selected ? primaryColor : subTextColor,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                opt.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected ? primaryColor : textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  //  BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final bgColor = themeProvider.backgroundColor;

    final maxRevenue = _revenueByMonth.isEmpty
        ? 0.0
        : _revenueByMonth.reduce((a, b) => a > b ? a : b);
    final chartMaxY = maxRevenue > 0 ? maxRevenue * 1.2 : 10.0;
    final chartInterval = maxRevenue > 0 ? maxRevenue / 4 : 2.5;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(textColor, subTextColor),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? _buildEmptyState(isDark, textColor, subTextColor, primaryColor)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: primaryColor,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 🎯 HERO : CHIFFRE D'AFFAIRES ──
                        _buildHeroRevenueCard(
                            isDark, primaryColor, textColor, subTextColor),
                        const SizedBox(height: 20),

                        // ── 📊 KPI ROW (3 cartes) ──
                        _buildKpiRow(isDark, textColor, subTextColor, cardColor,
                            primaryColor),
                        const SizedBox(height: 24),

                        // ── 📈 GRAPHIQUE BARRES : VENTES MENSUELLES ──
                        if (_monthlyRevenue.isNotEmpty) ...[
                          _buildBarChartCard(isDark, textColor, subTextColor,
                              cardColor, primaryColor, chartMaxY, chartInterval),
                          const SizedBox(height: 16),

                          // ── 📈 COURBE : TENDANCE CUMULÉE ──
                          _buildLineChartCard(isDark, textColor, subTextColor,
                              cardColor, primaryColor),
                          const SizedBox(height: 16),

                          // ── 🏆 TOP CLIENTS ──
                          if (_topClients.isNotEmpty)
                            _buildTopClientsCard(isDark, textColor, subTextColor,
                                cardColor, primaryColor),
                          if (_topClients.isNotEmpty) const SizedBox(height: 16),

                          // ── 🍩 CANAUX + STATUTS ──
                          _buildPaymentChannelsCard(
                              isDark, textColor, subTextColor, cardColor),
                          const SizedBox(height: 16),
                          _buildStatusCard(isDark, textColor, subTextColor,
                              cardColor, primaryColor),
                          const SizedBox(height: 16),

                          // ── 📋 TABLEAU DÉTAIL MENSUEL ──
                          _buildMonthlyTableCard(isDark, textColor, subTextColor,
                              cardColor, primaryColor),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  // ============================================================
  //  APPBAR
  // ============================================================

  PreferredSizeWidget _buildAppBar(Color textColor, Color subTextColor) {
    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: textColor, size: 20),
        onPressed: () => context.go('/dashboard'),
      ),
      title: Text(
        'Analyses',
        style: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        IconButton(
          icon:
              Icon(Icons.calendar_month_rounded, color: subTextColor, size: 21),
          tooltip: 'Période d\'analyse',
          onPressed: _isLoading ? null : _showPeriodSheet,
        ),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: subTextColor, size: 22),
          onPressed: _isLoading ? null : _loadData,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ============================================================
  //  🎯 HERO — CHIFFRE D'AFFAIRES
  // ============================================================

  Widget _buildHeroRevenueCard(
    bool isDark,
    Color primaryColor,
    Color textColor,
    Color subTextColor,
  ) {
    final growthUp = _growth >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cercles décoratifs en arrière-plan
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.trending_up_rounded,
                            color: Colors.white, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          'CHIFFRE D\'AFFAIRES',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _periodLabel.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      _kpiFormat(_totalRevenue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'FCFA',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          growthUp
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${growthUp ? '+' : ''}${_growth.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'vs période précédente',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildHeroMiniStat(
                      icon: Icons.receipt_long_rounded,
                      label: 'Commandes',
                      value: _totalOrders.toStringAsFixed(0),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  Expanded(
                    child: _buildHeroMiniStat(
                      icon: Icons.shopping_cart_rounded,
                      label: 'Panier moyen',
                      value: _kpiFormat(_avgOrderValue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMiniStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  📊 KPI ROW
  // ============================================================

  Widget _buildKpiRow(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color primaryColor,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniKpiCard(
            title: 'Commandes',
            value: _totalOrders.toStringAsFixed(0),
            trend: _ordersGrowth,
            icon: Icons.shopping_bag_rounded,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            textColor: textColor,
            subTextColor: subTextColor,
            cardColor: cardColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniKpiCard(
            title: 'Panier moyen',
            value: _kpiFormat(_avgOrderValue),
            trend: _avgGrowth,
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
            textColor: textColor,
            subTextColor: subTextColor,
            cardColor: cardColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniKpiCard(
            title: 'Meilleur mois',
            value: _bestMonth,
            trend: null,
            icon: Icons.emoji_events_rounded,
            color: const Color(0xFFFBBF24),
            isDark: isDark,
            textColor: textColor,
            subTextColor: subTextColor,
            cardColor: cardColor,
            subtitle: _bestRevenue > 0
                ? '${NumberFormat('#,##0').format(_bestRevenue)} F'
                : 'Aucun',
          ),
        ),
      ],
    );
  }

  Widget _buildMiniKpiCard({
    required String title,
    required String value,
    required double? trend,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
    String? subtitle,
  }) {
    final trendUp = trend == null || trend >= 0;
    final trendColor = trend == null
        ? color
        : (trendUp ? const Color(0xFF10B981) : const Color(0xFFEF4444));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: subTextColor,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          if (trend != null)
            Row(
              children: [
                Icon(
                  trendUp
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 11,
                  color: trendColor,
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    '${trendUp ? '+' : ''}${trend.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: trendColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: subTextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  // ============================================================
  //  📈 BAR CHART
  // ============================================================

  Widget _buildBarChartCard(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color primaryColor,
    double chartMaxY,
    double chartInterval,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartHeader(
            title: 'Évolution des ventes',
            subtitle: _periodLabel,
            badgeText: 'REVENUS (FCFA)',
            badgeColor: primaryColor,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMaxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? Colors.grey[800]! : Colors.grey[100]!,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${_sortedMonths[group.x]}\n',
                        TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                        children: <TextSpan>[
                          TextSpan(
                            text:
                                '${NumberFormat('#,##0').format(rod.toY)} FCFA',
                            style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _sortedMonths.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _sortedMonths[index],
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: subTextColor,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            NumberFormat('compact').format(value),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: subTextColor,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: chartInterval,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color:
                          isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    );
                  },
                ),
                barGroups: _revenueByMonth.asMap().entries.map((entry) {
                  final index = entry.key;
                  final value = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        color: primaryColor,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            primaryColor.withValues(alpha: 0.35),
                            primaryColor,
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  📈 LINE CHART (tendance cumulée)
  // ============================================================

  Widget _buildLineChartCard(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color primaryColor,
  ) {
    final cumulative = _cumulativeRevenue;
    if (cumulative.length < 2) return const SizedBox.shrink();

    final maxY = cumulative.reduce((a, b) => a > b ? a : b) * 1.15;
    final spots = <FlSpot>[];
    for (var i = 0; i < cumulative.length; i++) {
      spots.add(FlSpot(i.toDouble(), cumulative[i]));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartHeader(
            title: 'Tendance cumulée',
            subtitle: 'Revenus accumulés sur la période',
            badgeText: 'CUMUL',
            badgeColor: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                maxY: maxY,
                minY: 0,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? Colors.grey[800]! : Colors.grey[100]!,
                    getTooltipItems: (spots) => spots.map((s) {
                      final idx = s.x.toInt();
                      final month = (idx >= 0 && idx < _sortedMonths.length)
                          ? _sortedMonths[idx]
                          : '';
                      return LineTooltipItem(
                        '$month\n',
                        TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                        children: [
                          TextSpan(
                            text:
                                '${NumberFormat('#,##0').format(s.y)} FCFA',
                            style: const TextStyle(
                                color: Color(0xFF8B5CF6),
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (cumulative.length / 4).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < _sortedMonths.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _sortedMonths[idx],
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: subTextColor,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          NumberFormat('compact').format(value),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: subTextColor,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    barWidth: 3,
                    color: const Color(0xFF8B5CF6),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFF8B5CF6),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF8B5CF6).withValues(alpha: 0.28),
                          const Color(0xFF8B5CF6).withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  🏆 TOP CLIENTS
  // ============================================================

  Widget _buildTopClientsCard(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color primaryColor,
  ) {
    final maxTotal =
        _topClients.isEmpty ? 1.0 : _topClients.first.total;
    final rankColors = [
      const Color(0xFFFBBF24), // Or
      const Color(0xFF9CA3AF), // Argent
      const Color(0xFFB45309), // Bronze
      primaryColor,
      primaryColor,
    ];
    final rankLabels = ['#1', '#2', '#3', '#4', '#5'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: Color(0xFFFBBF24), size: 15),
              ),
              const SizedBox(width: 10),
              Text(
                'Top clients',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_topClients.length} CLIENTS',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(_topClients.length, (i) {
            final c = _topClients[i];
            final ratio = maxTotal > 0 ? (c.total / maxTotal) : 0.0;
            final initials = _initialsOf(c.name);
            return Padding(
              padding: EdgeInsets.only(
                  bottom: i == _topClients.length - 1 ? 0 : 12),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rankColors[i].withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rankLabels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: rankColors[i],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Avatar initials
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withValues(alpha: 0.85),
                          primaryColor.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name + bar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Barre de progression
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 4,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(
                              rankColors[i],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Amount + count
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_kpiFormat(c.total)} F',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${c.count} facture${c.count > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    final first = parts.first.substring(0, 1);
    final second = parts[1].substring(0, 1);
    return (first + second).toUpperCase();
  }

  // ============================================================
  //  🍩 CANAUX DE PAIEMENT
  // ============================================================

  Widget _buildPaymentChannelsCard(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
  ) {
    const channels = [
      ('Orange Money', Color(0xFFF97316)),
      ('MTN MoMo', Color(0xFFFFD700)),
      ('Cash', Color(0xFF34D399)),
      ('Carte Bancaire', Color(0xFF8A4CFC)),
    ];
    final parts = [45, 30, 15, 10];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded,
                  color: subTextColor, size: 16),
              const SizedBox(width: 8),
              Text(
                'Canaux de paiement',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 34,
                        startDegreeOffset: -90,
                        sections: List.generate(channels.length, (i) {
                          return PieChartSectionData(
                            value: parts[i].toDouble(),
                            color: channels[i].$2,
                            radius: 40,
                            showTitle: false,
                          );
                        }),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${parts[0]}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Top',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: subTextColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children:
                      List.generate(channels.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: channels[i].$2,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              channels[i].$1,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${parts[i]}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  🟢 RÉPARTITION PAR STATUT
  // ============================================================

  Widget _buildStatusCard(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color primaryColor,
  ) {
    // Construit la liste {statut, montant, couleur}
    final entries = <({String label, double amount, Color color})>[
      (
        label: 'Payé',
        amount: _paidAmount,
        color: const Color(0xFF10B981),
      ),
      (
        label: 'En attente',
        amount: _pendingAmount,
        color: const Color(0xFFF59E0B),
      ),
      (
        label: 'En retard',
        amount: _overdueAmount,
        color: const Color(0xFFEF4444),
      ),
    ];
    final total = entries.fold<double>(0, (sum, e) => sum + e.amount);
    if (total <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.donut_small_rounded,
                  color: subTextColor, size: 16),
              const SizedBox(width: 8),
              Text(
                'État des factures',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_invoices.length} TOTAL',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Barre empilée horizontale
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: entries.map((e) {
                  final ratio = total > 0 ? e.amount / total : 0.0;
                  if (ratio <= 0) return const SizedBox.shrink();
                  return Expanded(
                    flex: (ratio * 1000).round().clamp(1, 1000),
                    child: Container(color: e.color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Légende
          Row(
            children: entries.map((e) {
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: e.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            e.label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: subTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_kpiFormat(e.amount)} F',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  📋 TABLEAU MENSUEL
  // ============================================================

  Widget _buildMonthlyTableCard(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color primaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Détail mensuel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _exportMonthly,
                icon: Icon(Icons.file_download_outlined,
                    size: 15, color: primaryColor),
                label: Text(
                  'EXPORTER',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: primaryColor,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: DataTable(
              headingTextStyle: TextStyle(
                color: subTextColor,
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
                letterSpacing: 0.4,
              ),
              dataTextStyle: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              columnSpacing: 22,
              horizontalMargin: 4,
              headingRowHeight: 36,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 44,
              dividerThickness: 0.5,
              columns: const [
                DataColumn(label: Text('MOIS')),
                DataColumn(label: Text('CA'), numeric: true),
                DataColumn(label: Text('CMD'), numeric: true),
                DataColumn(label: Text('PANIER'), numeric: true),
              ],
              rows: _sortedMonths.map((month) {
                final revenue = _monthlyRevenue[month] ?? 0;
                final orders = _monthlyOrders[month] ?? 0;
                final avg = orders > 0 ? revenue / orders : 0;
                return DataRow(
                  cells: [
                    DataCell(Text(month,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ))),
                    DataCell(Text(
                      NumberFormat('#,##0').format(revenue),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    )),
                    DataCell(Text(orders.toStringAsFixed(0))),
                    DataCell(Text(NumberFormat('#,##0').format(avg))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  🧱 HELPERS COMMUNS
  // ============================================================

  Widget _buildChartHeader({
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: badgeColor == badgeColor ? null : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                badgeText,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  //  📤 EXPORT CSV
  // ============================================================

  Future<void> _exportMonthly() async {
    final buffer = StringBuffer()
      ..writeln('Mois,CA (FCFA),Commandes,Panier moyen');
    for (final month in _sortedMonths) {
      final revenue = _monthlyRevenue[month] ?? 0;
      final orders = _monthlyOrders[month] ?? 0;
      final avg = orders > 0 ? revenue / orders : 0;
      buffer.writeln(
        '$month,${revenue.toStringAsFixed(0)},${orders.toStringAsFixed(0)},${avg.toStringAsFixed(0)}',
      );
    }
    final csv = buffer.toString();
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Données mensuelles copiées (${_sortedMonths.length} mois)'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  //  🪹 EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.15),
                    primaryColor.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child:
                  Icon(Icons.analytics_rounded, size: 40, color: primaryColor),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucune donnée disponible',
              style: TextStyle(
                  fontSize: 18, color: textColor, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Créez et passez vos factures à l\'état payé pour afficher '
              'les analyses de performance.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: subTextColor, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/dashboard/invoices/create'),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Créer une facture'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}