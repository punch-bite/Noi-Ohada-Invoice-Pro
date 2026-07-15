// lib/screens/dashboard/analytics_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
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

  // Données agrégées
  double _totalRevenue = 0;
  double _totalOrders = 0;
  double _avgOrderValue = 0;
  String _bestMonth = '';
  double _bestRevenue = 0;
  double _growth = 0;
  Map<String, double> _monthlyRevenue = {};
  Map<String, double> _monthlyOrders = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _db.getInvoices(),
        _db.getClients(),
      ]);
      _invoices = results[0] as List<Invoice>? ?? [];
      _clients = results[1] as List<Client>? ?? [];
      _processData();
    } catch (e) {
      // En cas d'erreur, on garde des données vides
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData() {
    // Filtrer les factures payées (pour le CA)
    final paidInvoices = _invoices.where((inv) => inv.status == 'paid').toList();
    _totalRevenue = paidInvoices.fold(0, (sum, inv) => sum + inv.totalAmount);
    _totalOrders = paidInvoices.length.toDouble();

    // Panier moyen
    _avgOrderValue = _totalOrders > 0 ? _totalRevenue / _totalOrders : 0;

    // Regroupement par mois
    final monthlyData = <String, double>{};
    for (final inv in paidInvoices) {
      final monthKey = DateFormat('MMM yyyy').format(inv.issueDate);
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + inv.totalAmount;
    }

    // Meilleur mois
    if (monthlyData.isNotEmpty) {
      final best = monthlyData.entries.reduce((a, b) => a.value > b.value ? a : b);
      _bestMonth = best.key;
      _bestRevenue = best.value;
    }

    // Croissance (dernier mois vs premier mois)
    final months = monthlyData.keys.toList()..sort((a, b) {
      final dateA = DateFormat('MMM yyyy').parse(a);
      final dateB = DateFormat('MMM yyyy').parse(b);
      return dateA.compareTo(dateB);
    });
    if (months.length >= 2) {
      final first = monthlyData[months.first] ?? 0;
      final last = monthlyData[months.last] ?? 0;
      _growth = first > 0 ? ((last - first) / first * 100) : 0;
    }

    // Stocker les données pour les graphiques
    _monthlyRevenue = monthlyData;
    _monthlyOrders = {}; // On pourrait aussi compter les commandes par mois
    for (final inv in paidInvoices) {
      final monthKey = DateFormat('MMM yyyy').format(inv.issueDate);
      _monthlyOrders[monthKey] = (_monthlyOrders[monthKey] ?? 0) + 1;
    }
  }

  // Obtenir une liste triée des mois pour les graphiques
  List<String> get _sortedMonths {
    final months = _monthlyRevenue.keys.toList();
    months.sort((a, b) {
      final dateA = DateFormat('MMM yyyy').parse(a);
      final dateB = DateFormat('MMM yyyy').parse(b);
      return dateA.compareTo(dateB);
    });
    return months;
  }

  // Obtenir les données pour le graphique (par mois, ordre chronologique)
  List<double> get _revenueByMonth => _sortedMonths.map((m) => _monthlyRevenue[m] ?? 0).toList();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final bgColor = themeProvider.backgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          'Analyses',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: subTextColor, size: 20),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? _buildEmptyState(isDark, textColor, subTextColor, primaryColor)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== 4 CARTES RÉSUMÉ =====
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              context,
                              title: 'Chiffre d\'affaires',
                              value: '${NumberFormat('#,##0').format(_totalRevenue)} FCFA',
                              icon: Icons.trending_up,
                              color: primaryColor,
                              subText: '${_growth >= 0 ? '+' : ''}${_growth.toStringAsFixed(1)}% vs début',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              context,
                              title: 'Commandes',
                              value: _totalOrders.toStringAsFixed(0),
                              icon: Icons.shopping_bag,
                              color: Colors.orange,
                              subText: '${_invoices.where((inv) => inv.status == 'paid').length} payées',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              context,
                              title: 'Panier moyen',
                              value: '${NumberFormat('#,##0').format(_avgOrderValue)} FCFA',
                              icon: Icons.receipt,
                              color: Colors.green,
                              subText: '${_invoices.length} factures totales',
                            ),
                          ),
                          Expanded(
                            child: _buildSummaryCard(
                              context,
                              title: 'Meilleur mois',
                              value: _bestMonth.isNotEmpty ? _bestMonth : 'N/A',
                              icon: Icons.emoji_events,
                              color: Colors.amber,
                              subText: _bestRevenue > 0 ? '${NumberFormat('#,##0').format(_bestRevenue)} FCFA' : 'Aucune donnée',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ===== GRAPHIQUE BARRES : VENTES MENSUELLES =====
                      if (_monthlyRevenue.isNotEmpty) ...[
                        Text(
                          'Évolution des ventes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 220,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                              width: 0.5,
                            ),
                          ),
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: _revenueByMonth.isEmpty ? 1 : _revenueByMonth.reduce((a, b) => a > b ? a : b) * 1.2,
                              barTouchData: BarTouchData(enabled: false),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index >= 0 && index < _sortedMonths.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            _sortedMonths[index],
                                            style: TextStyle(
                                              fontSize: 10,
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
                                    reservedSize: 50,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        NumberFormat('compact').format(value),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: subTextColor,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              gridData: FlGridData(
                                show: true,
                                horizontalInterval: _revenueByMonth.isEmpty ? 1 : _revenueByMonth.reduce((a, b) => a > b ? a : b) / 4,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                                    strokeWidth: 0.5,
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
                                      color: primaryColor.withOpacity(0.7),
                                      width: 10,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          primaryColor.withOpacity(0.3),
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
                        const SizedBox(height: 24),
                      ],

                      // ===== TABLEAU RÉCAPITULATIF MENSUEL =====
                      if (_monthlyRevenue.isNotEmpty) ...[
                        Text(
                          'Détail mensuel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                              width: 0.5,
                            ),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingTextStyle: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              dataTextStyle: TextStyle(
                                color: textColor,
                                fontSize: 12,
                              ),
                              columnSpacing: 16,
                              horizontalMargin: 16,
                              columns: const [
                                DataColumn(label: Text('Mois')),
                                DataColumn(label: Text('CA (FCFA)'), numeric: true),
                                DataColumn(label: Text('Commandes'), numeric: true),
                                DataColumn(label: Text('Panier moyen'), numeric: true),
                              ],
                              rows: _sortedMonths.map((month) {
                                final revenue = _monthlyRevenue[month] ?? 0;
                                final orders = _monthlyOrders[month] ?? 0;
                                final avg = orders > 0 ? revenue / orders : 0;
                                return DataRow(
                                  cells: [
                                    DataCell(Text(month)),
                                    DataCell(Text(NumberFormat('#,##0').format(revenue))),
                                    DataCell(Text(orders.toStringAsFixed(0))),
                                    DataCell(Text(NumberFormat('#,##0').format(avg))),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor, Color subTextColor, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.analytics, size: 32, color: primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune donnée',
            style: TextStyle(fontSize: 18, color: textColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Créez des factures pour voir les analyses',
            style: TextStyle(fontSize: 14, color: subTextColor),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.push('/dashboard/invoices/create'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Créer une facture'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subText,
  }) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: subTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subText,
            style: TextStyle(
              fontSize: 9,
              color: subTextColor.withOpacity(0.7),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}