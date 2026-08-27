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

  // Données agrégées
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

    // Croissance des commandes et du panier moyen (dernier vs premier mois)
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
      _ordersGrowth = firstOrders > 0 ? ((lastOrders - firstOrders) / firstOrders * 100) : 0;
    } else {
      _ordersGrowth = 0;
    }
    // Panier moyen : dernier mois vs premier mois
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
                            title: 'Chiffre d\'Affaires',
                            value: NumberFormat('#,##0').format(_totalRevenue),
                            unit: 'FCFA',
                            icon: Icons.trending_up_rounded,
                            color: primaryColor,
                            trend: _growth,
                            trendLabel: '${_growth >= 0 ? '+' : ''}${_growth.toStringAsFixed(0)}%',
                          ),
                          _buildSummaryCard(
                            context,
                            title: 'Commandes',
                            value: _totalOrders.toStringAsFixed(0),
                            unit: 'PAYÉES',
                            icon: Icons.shopping_bag_rounded,
                            color: Colors.orange,
                            trend: _ordersGrowth,
                            trendLabel: '${_ordersGrowth >= 0 ? '+' : ''}${_ordersGrowth.toStringAsFixed(0)}%',
                          ),
                          _buildSummaryCard(
                            context,
                            title: 'Panier Moyen',
                            value: NumberFormat('#,##0').format(_avgOrderValue),
                            unit: 'FCFA/CMD',
                            icon: Icons.receipt_long_rounded,
                            color: Colors.green,
                            trend: _avgGrowth,
                            trendLabel: '${_avgGrowth >= 0 ? '+' : ''}${_avgGrowth.toStringAsFixed(0)}%',
                          ),
                          _buildSummaryCard(
                            context,
                            title: 'Meilleur Mois',
                            value: _bestMonth,
                            unit: '',
                            icon: Icons.emoji_events_rounded,
                            color: Colors.amber,
                            trend: null,
                            trendLabel: _bestRevenue > 0
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
                          height: 260,
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
                                  getTooltipColor: (_) => isDark ? Colors.grey[800]! : Colors.grey[100]!,
                                  // tool: BorderRadius.circular(8),
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
                                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
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
                                          primaryColor.withValues(alpha: 0.4),
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

                      // ===== CANAUX DE PAIEMENT (DONUT) =====
                      Text(
                        'Canaux de Paiement',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPaymentChannelsCard(isDark, textColor, subTextColor, cardColor),
                      const SizedBox(height: 24),

                      // ===== TABLEAU RÉCAPITULATIF MENSUEL =====
                      if (_monthlyRevenue.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Détail mensuel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _exportMonthly(),
                              icon: const Icon(Icons.file_download_outlined, size: 16),
                              label: const Text('EXPORTER'),
                              style: TextButton.styleFrom(
                                foregroundColor: primaryColor,
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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

  /// 🍩 Canaux de paiement : donut chart + légende (maquette Stitch).
  Widget _buildPaymentChannelsCard(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
  ) {
    // Répartition par canal (repli sur la maquette si aucune donnée) :
    // Orange 45%, MTN 30%, Cash 15%, Carte 10%.
    const channels = [
      ('Orange Money', Color(0xFFF97316)),
      ('MTN MoMo', Color(0xFFFFD700)),
      ('Cash', Color(0xFF34D399)),
      ('Carte Bancaire', Color(0xFF8A4CFC)),
    ];
    final parts = [45, 30, 15, 10];
    // NB : ces parts sont des valeurs de démonstration (la plateforme n'expose
    // pas encore le canal par facture) — à remplacer par de vraies données
    // quand `paymentMethod` sera renseigné sur les factures.

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Donut chart
          SizedBox(
            width: 110,
            height: 110,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
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
          ),
          const SizedBox(width: 20),
          // Légende
          Expanded(
            child: Column(
              children: List.generate(channels.length, (i) {
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
                          fontWeight: FontWeight.w700,
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
    );
  }

  /// 📤 Exporte le détail mensuel en CSV (partage via la console / clipboard).
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
    // Copie dans le presse-papiers (meilleur effort)
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Données mensuelles copiées (${_sortedMonths.length} mois)'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
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
                color: primaryColor.withValues(alpha: 0.08),
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
    required String trendLabel,
    double? trend,
    String unit = '',
  }) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;

    // Couleur du badge de tendance : vert si ↑, rouge si ↓
    final trendUp = trend == null || trend >= 0;
    final trendColor = trend == null ? color : (trendUp ? const Color(0xFF34D399) : const Color(0xFFF87171));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (trend != null)
                      Icon(
                        trendUp ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 10,
                        color: trendColor,
                      ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        trendLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: trendColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}