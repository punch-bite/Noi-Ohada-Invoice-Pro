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
    } catch (e) {
      // Les données restent vides en cas d'erreur
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData() {
    // Filtrer uniquement les factures payées pour les métriques de revenus
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

    // Recherche du meilleur mois
    if (monthlyData.isNotEmpty) {
      final best = monthlyData.entries.reduce((a, b) => a.value > b.value ? a : b);
      _bestMonth = best.key;
      _bestRevenue = best.value;
    } else {
      _bestMonth = 'N/A';
      _bestRevenue = 0;
    }

    // Calcul de la croissance (dernier mois vs premier mois)
    final months = monthlyData.keys.toList();
    _sortMonthsList(months);

    if (months.length >= 2) {
      final first = monthlyData[months.first] ?? 0;
      final last = monthlyData[months.last] ?? 0;
      _growth = first > 0 ? ((last - first) / first * 100) : 0;
    } else {
      _growth = 0;
    }

    // Stocker les volumes par mois pour le graphique secondaire
    _monthlyRevenue = monthlyData;
    _monthlyOrders = {};
    for (final inv in paidInvoices) {
      final monthKey = DateFormat('MMM yyyy').format(inv.issueDate);
      _monthlyOrders[monthKey] = (_monthlyOrders[monthKey] ?? 0) + 1;
    }
  }

  // Tri robuste des clés de mois pour éviter les crashs sur formats mal formés
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

  // Obtenir une liste ordonnée des mois pour les graphiques
  List<String> get _sortedMonths {
    final months = _monthlyRevenue.keys.toList();
    _sortMonthsList(months);
    return months;
  }

  // Liste ordonnée des valeurs financières mensuelles
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

    // Métriques de calcul pour les axes fl_chart
    final maxRevenue = _revenueByMonth.isEmpty ? 0.0 : _revenueByMonth.reduce((a, b) => a > b ? a : b);
    final chartMaxY = maxRevenue > 0 ? maxRevenue * 1.2 : 10.0;
    final chartInterval = maxRevenue > 0 ? maxRevenue / 4 : 2.5;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
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
            icon: Icon(Icons.refresh_rounded, color: subTextColor, size: 22),
            onPressed: _isLoading ? null : _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? _buildEmptyState(isDark, textColor, subTextColor, primaryColor)
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== GRILLE DE CARTES RÉSUMÉ (ÉVITE L'OVERFLOW) =====
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        children: [
                          _buildSummaryCard(
                            context,
                            title: 'Chiffre d\'affaires',
                            value: '${NumberFormat('#,##0').format(_totalRevenue)} FCFA',
                            icon: Icons.trending_up_rounded,
                            color: primaryColor,
                            subText: '${_growth >= 0 ? '+' : ''}${_growth.toStringAsFixed(1)}% vs début',
                          ),
                          _buildSummaryCard(
                            context,
                            title: 'Commandes',
                            value: _totalOrders.toStringAsFixed(0),
                            icon: Icons.shopping_bag_rounded,
                            color: Colors.orange,
                            subText: '${_invoices.where((inv) => inv.status == 'paid').length} payées',
                          ),
                          _buildSummaryCard(
                            context,
                            title: 'Panier moyen',
                            value: '${NumberFormat('#,##0').format(_avgOrderValue)} FCFA',
                            icon: Icons.receipt_long_rounded,
                            color: Colors.green,
                            subText: '${_invoices.length} factures totales',
                          ),
                          _buildSummaryCard(
                            context,
                            title: 'Meilleur mois',
                            value: _bestMonth,
                            icon: Icons.emoji_events_rounded,
                            color: Colors.amber,
                            subText: _bestRevenue > 0 
                                ? '${NumberFormat('#,##0').format(_bestRevenue)} FCFA' 
                                : 'Aucun gain',
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
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 240,
                          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                              width: 1,
                            ),
                          ),
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: chartMaxY,
                              barTouchData: BarTouchData(
                                enabled: true,
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipColor: (_) => isDark ? Colors.grey[850]! : Colors.grey[100]!,
                                  tooltipRoundedRadius: 8,
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      '${_sortedMonths[group.x]}\n',
                                      TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11),
                                      children: <TextSpan>[
                                        TextSpan(
                                          text: '${NumberFormat('#,##0').format(rod.toY)} FCFA',
                                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
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
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              gridData: FlGridData(
                                show: true,
                                horizontalInterval: chartInterval,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
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
                                      width: 12,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          primaryColor.withOpacity(0.4),
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
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                              width: 1,
                            ),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: DataTable(
                              headingTextStyle: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              dataTextStyle: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              columnSpacing: 24,
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
                                    DataCell(Text(month, style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(NumberFormat('#,##0').format(revenue))),
                                    DataCell(Text(orders.toStringAsFixed(0))),
                                    DataCell(Text(NumberFormat('#,##0').format(avg))),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor, Color subTextColor, Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              child: Icon(Icons.analytics_rounded, size: 32, color: primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune donnée disponible',
              style: TextStyle(fontSize: 18, color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Créez et passez vos factures à l\'état payé pour afficher les analyses de performance.',
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: subTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subText,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: subTextColor.withOpacity(0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}