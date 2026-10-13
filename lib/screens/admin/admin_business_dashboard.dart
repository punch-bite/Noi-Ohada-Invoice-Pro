// lib/screens/admin/admin_business_dashboard.dart
//
// 📊 Tableau de bord business (admin) : abonnements + ventes.
//
// Regroupe :
//   • KPI : MRR, revenus cumulés, abonnés actifs, ventes du mois.
//   • Revenus des 6 derniers mois (BarChart).
//   • Répartition par statut d'abonnement (barres de progression).
//   • Répartition par plan (revenu par forfait).
//   • Liste des abonnements les plus récents.
//
// Design system : Glass/Indigo (ThemeProvider) + flutter_animate.
//
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';
import '../../models/subscription.dart';
import '../../models/plan.dart';

class AdminBusinessDashboard extends StatefulWidget {
  const AdminBusinessDashboard({super.key});

  @override
  State<AdminBusinessDashboard> createState() => _AdminBusinessDashboardState();
}

class _AdminBusinessDashboardState extends State<AdminBusinessDashboard> {
  final AdminService _adminService = AdminService();

  Map<String, dynamic> _stats = const {};
  List<Subscription> _recentSubs = const [];
  List<Plan> _plans = const [];
  bool _isLoading = true;

  // Palette cohérente avec le design system (indigo → violet → accents).
  static const Color _cIndigo = Color(0xFF4F46E5);
  static const Color _cEmerald = Color(0xFF10B981);
  static const Color _cAmber = Color(0xFFF59E0B);
  static const Color _cRose = Color(0xFFEF4444);
  static const Color _cViolet = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _adminService.getPlatformStats(),
        _adminService.getAllSubscriptions(),
        _adminService.getAllPlans(),
      ]);

      if (!mounted) return;
      final stats = results[0] as Map<String, dynamic>;
      final subs = results[1] as List<Subscription>;
      final plans = results[2] as List<Plan>;

      subs.sort((a, b) {
        final ad = a.createdAt ?? a.startDate;
        final bd = b.createdAt ?? b.startDate;
        return bd.compareTo(ad);
      });

      setState(() {
        _stats = stats;
        _recentSubs = subs.take(8).toList();
        _plans = plans;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de charger les données business : $e'),
          backgroundColor: _cRose,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String _planName(String planId) {
    for (final p in _plans) {
      if (p.id == planId) return p.name;
    }
    return planId;
  }

  String _fmtMoney(double amount) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    return fmt.format(amount);
  }

  String _fmtMoneyWithCurrency(double amount, String currency) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    final cur = currency.isEmpty ? 'XAF' : currency;
    return '${fmt.format(amount)} $cur';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Actif';
      case 'expired':
        return 'Expiré';
      case 'canceled':
        return 'Annulé';
      case 'pending':
        return 'En attente';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return _cEmerald;
      case 'expired':
        return _cAmber;
      case 'canceled':
        return _cRose;
      case 'pending':
        return _cIndigo;
      default:
        return _cViolet;
    }
  }

  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }


  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Business & Revenus',
          style: TextStyle(
            color: text,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : RefreshIndicator(
              onRefresh: _loadAll,
              color: primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Indicateurs clés', sub),
                    const SizedBox(height: 12),
                    _kpiGrid(isDark, text, sub),
                    const SizedBox(height: 24),
                    if ((_stats['expiringSoon'] as int? ?? 0) > 0) ...[
                      _expiringBanner(isDark, text),
                      const SizedBox(height: 24),
                    ],
                    _sectionLabel('Revenus (6 derniers mois)', sub),
                    const SizedBox(height: 12),
                    _revenueChartCard(isDark, text, sub),
                    const SizedBox(height: 24),
                    _sectionLabel('Répartition par statut', sub),
                    const SizedBox(height: 12),
                    _statusBreakdownCard(isDark, text, sub),
                    const SizedBox(height: 24),
                    _sectionLabel('Revenus par plan', sub),
                    const SizedBox(height: 12),
                    _planBreakdownCard(isDark, text, sub),
                    const SizedBox(height: 24),
                    _sectionLabel('Abonnements récents', sub),
                    const SizedBox(height: 12),
                    _recentSubsCard(isDark, text, sub),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String label, Color sub) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: sub,
      ),
    );
  }

  Widget _card({
    required bool isDark,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _kpiGrid(bool isDark, Color text, Color sub) {
    final mrr = (_stats['mrr'] as num? ?? 0).toDouble();
    final total = (_stats['totalRevenue'] as num? ?? 0).toDouble();
    final active = _stats['activeSubs'] as int? ?? 0;
    final month = (_stats['salesThisMonth'] as num? ?? 0).toDouble();

    return Column(
      children: [
        Row(
          children: [
            _kpiCard(
              label: 'MRR',
              value: _fmtMoney(mrr),
              icon: Icons.autorenew_rounded,
              color: _cIndigo,
              isDark: isDark,
              text: text,
              sub: sub,
            ),
            const SizedBox(width: 10),
            _kpiCard(
              label: 'Revenus cumulés',
              value: _fmtMoney(total),
              icon: Icons.payments_rounded,
              color: _cEmerald,
              isDark: isDark,
              text: text,
              sub: sub,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _kpiCard(
              label: 'Abonnés actifs',
              value: '$active',
              icon: Icons.workspace_premium_rounded,
              color: _cViolet,
              isDark: isDark,
              text: text,
              sub: sub,
            ),
            const SizedBox(width: 10),
            _kpiCard(
              label: 'Ventes du mois',
              value: _fmtMoney(month),
              icon: Icons.trending_up_rounded,
              color: _cAmber,
              isDark: isDark,
              text: text,
              sub: sub,
            ),
          ],
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.08, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color text,
    required Color sub,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D26) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: text,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: sub,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expiringBanner(bool isDark, Color text) {
    final count = _stats['expiringSoon'] as int? ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cAmber.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _cAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.schedule_rounded, color: _cAmber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count abonnement(s) expirent sous 7 jours',
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pensez à relancer ces clients pour le renouvellement.',
                  style: TextStyle(
                    color: text.withValues(alpha: 0.55),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }


  // ── Graphe revenus mensuels ──
  Widget _revenueChartCard(bool isDark, Color text, Color sub) {
    final monthly = (_stats['monthlyRevenue'] as List?) ?? [];
    if (monthly.isEmpty) {
      return _card(
        isDark: isDark,
        child: Center(
          child: Text('Aucune donnée de revenus',
              style: TextStyle(color: sub, fontSize: 12)),
        ),
      );
    }

    final bars = <BarChartGroupData>[];
    double maxY = 0;
    for (int i = 0; i < monthly.length; i++) {
      final rev = (monthly[i]['revenue'] as num? ?? 0).toDouble();
      if (rev > maxY) maxY = rev;
      bars.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: rev,
            color: _cIndigo,
            width: 18,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ));
    }
    if (maxY == 0) maxY = 1;

    return _card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Évolution',
                  style: TextStyle(
                      color: text, fontSize: 13, fontWeight: FontWeight.w700)),
              Text(
                'Cumul ${_fmtMoney((_stats['totalRevenue'] as num? ?? 0).toDouble())}',
                style: TextStyle(color: sub, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gi, rod, idx) {
                      return BarTooltipItem(
                        _fmtMoney(rod.toY),
                        TextStyle(
                          color: text,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= monthly.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            monthly[idx]['label']?.toString() ?? '',
                            style: TextStyle(color: sub, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: bars,
                gridData: const FlGridData(show: false),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  // ── Répartition par statut d'abonnement ──
  Widget _statusBreakdownCard(bool isDark, Color text, Color sub) {
    final byStatus =
        (_stats['byStatus'] as Map?)?.cast<String, double>() ?? {};

    const order = ['active', 'expired', 'canceled', 'pending'];
    const countKeys = <String, String>{
      'active': 'activeSubs',
      'expired': 'expiredSubs',
      'canceled': 'canceledSubs',
      'pending': 'pendingSubs',
    };

    double total = 0;
    for (final v in byStatus.values) {
      total += v;
    }
    if (total == 0) total = 1;

    final visible = order
        .where((st) =>
            (byStatus[st] ?? 0) > 0 ||
            (_stats[countKeys[st] ?? ''] as int? ?? 0) > 0)
        .toList();

    if (visible.isEmpty) {
      return _card(
        isDark: isDark,
        child: Center(
          child: Text('Aucun abonnement enregistré',
              style: TextStyle(color: sub, fontSize: 12)),
        ),
      );
    }

    return _card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final st in visible)
            _statusRow(
              label: _statusLabel(st),
              color: _statusColor(st),
              count: _stats[countKeys[st] ?? ''] as int? ?? 0,
              revenue: byStatus[st] ?? 0,
              ratio: (byStatus[st] ?? 0) / total,
              text: text,
              sub: sub,
            ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _statusRow({
    required String label,
    required Color color,
    required int count,
    required double revenue,
    required double ratio,
    required Color text,
    required Color sub,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$count • ${_fmtMoney(revenue)}',
                style: TextStyle(
                    color: sub, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }


  // ── Revenus par plan ──
  Widget _planBreakdownCard(bool isDark, Color text, Color sub) {
    final byPlan =
        (_stats['byPlan'] as Map?)?.cast<String, double>() ?? {};

    if (byPlan.isEmpty) {
      return _card(
        isDark: isDark,
        child: Center(
          child: Text('Aucun revenu par plan',
              style: TextStyle(color: sub, fontSize: 12)),
        ),
      );
    }

    final entries = byPlan.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    double total = 0;
    for (final v in byPlan.values) {
      total += v;
    }
    if (total == 0) total = 1;

    return _card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _planRow(
              name: _planName(entries[i].key),
              revenue: entries[i].value,
              ratio: entries[i].value / total,
              color: _planColor(i),
              text: text,
              sub: sub,
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Color _planColor(int i) {
    const palette = [_cIndigo, _cViolet, _cEmerald, _cAmber, _cRose];
    return palette[i % palette.length];
  }

  Widget _planRow({
    required String name,
    required double revenue,
    required double ratio,
    required Color color,
    required Color text,
    required Color sub,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(Icons.workspace_premium_rounded, color: color, size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(ratio * 100).toStringAsFixed(0)}% • ${_fmtMoney(revenue)}',
              style: TextStyle(
                  color: sub, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ── Abonnements récents ──
  Widget _recentSubsCard(bool isDark, Color text, Color sub) {
    if (_recentSubs.isEmpty) {
      return _card(
        isDark: isDark,
        child: Center(
          child: Text('Aucun abonnement récent',
              style: TextStyle(color: sub, fontSize: 12)),
        ),
      );
    }

    return _card(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (int i = 0; i < _recentSubs.length; i++) ...[
            _recentSubRow(_recentSubs[i], isDark, text, sub),
            if (i < _recentSubs.length - 1)
              Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
              ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _recentSubRow(
      Subscription s, bool isDark, Color text, Color sub) {
    final date = s.createdAt ?? s.startDate;
    final color = _statusColor(s.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.subscriptions_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _planName(s.planId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fmtDate(date),
                  style: TextStyle(color: sub, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmtMoneyWithCurrency(s.amount, s.currency),
                style: TextStyle(
                  color: text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _statusLabel(s.status),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



