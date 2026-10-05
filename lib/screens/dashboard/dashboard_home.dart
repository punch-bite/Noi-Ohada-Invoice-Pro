// lib/screens/dashboard/dashboard_home.dart
//
// 🎨 Dashboard épuré, animé et fluide.
//    • Entrées en cascade (flutter_animate) : header, solde, stats, listes
//    • Transitions douces sur les cartes (AnimatedContainer)
//    • Hiérarchie claire : gros solde gradient, stats discrètes, listes aérées
//    • Aucune donnée modifiée — mêmes API (DatabaseService / FinancialStats).
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/database_service.dart';
import '../../services/update_service.dart';
import '../../models/client.dart';
import '../../models/invoice.dart';
import '../../models/financial_stats.dart';
import '../../widgets/notification_badge.dart';
import '../../widgets/cloud_storage_info_banner.dart';
import '../../widgets/marketing_carousel.dart';
import '../../widgets/promo_section.dart';
import 'widgets/payment_bottom_sheet.dart';

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  final DatabaseService _db = DatabaseService();
  List<Client> _recentClients = [];
  List<Invoice> _recentInvoices = [];
  FinancialStats _financialStats = FinancialStats();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _maybeCheckForUpdate();
  }

  /// 🚀 Détection automatique de mise à jour différée.
  Future<void> _maybeCheckForUpdate() async {
    if (UpdateService.hasAutoPrompted) return;
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    await UpdateService.checkAndPrompt(context, manual: false);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final clients = await _db.getClients();
    final invoices = await _db.getInvoices();
    final stats = _calculateFinancialStats(invoices);
    if (!mounted) return;
    setState(() {
      _recentClients = clients.take(5).toList();
      _recentInvoices = invoices.take(4).toList();
      _financialStats = stats;
      _isLoading = false;
    });
  }

  FinancialStats _calculateFinancialStats(List<Invoice> invoices) {
    double totalRevenue = 0;
    double totalPaid = 0;
    double totalPending = 0;
    double totalOverdue = 0;
    double totalCancelled = 0;
    int paidCount = 0;
    int pendingCount = 0;
    int overdueCount = 0;
    int cancelledCount = 0;

    for (final invoice in invoices) {
      totalRevenue += invoice.totalAmount;
      switch (invoice.status) {
        case 'paid':
          totalPaid += invoice.totalAmount;
          paidCount++;
          break;
        case 'sent':
          totalPending += invoice.totalAmount;
          pendingCount++;
          break;
        case 'overdue':
          totalOverdue += invoice.totalAmount;
          overdueCount++;
          break;
        case 'cancelled':
          totalCancelled += invoice.totalAmount;
          cancelledCount++;
          break;
        default:
          totalPending += invoice.totalAmount;
          pendingCount++;
      }
    }

    final totalInvoices = invoices.length;
    final averageInvoiceValue =
        totalInvoices > 0 ? (totalRevenue / totalInvoices).toDouble() : 0.0;

    return FinancialStats(
      totalRevenue: totalRevenue,
      totalPaid: totalPaid,
      totalPending: totalPending,
      totalOverdue: totalOverdue,
      totalCancelled: totalCancelled,
      totalInvoices: totalInvoices,
      paidCount: paidCount,
      pendingCount: pendingCount,
      overdueCount: overdueCount,
      cancelledCount: cancelledCount,
      averageInvoiceValue: averageInvoiceValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final bgColor = themeProvider.backgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: primaryColor,
        backgroundColor: cardColor,
        displacement: 40,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // ── Header (avatar + bonjour + actions) ──
              _buildHeader(
                authProvider: authProvider,
                subscriptionProvider: subscriptionProvider,
                isDark: isDark,
                primaryColor: primaryColor,
                textColor: textColor,
                subTextColor: subTextColor,
              ).animate().fadeIn(duration: 400.ms).slideY(
                    begin: -0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: 24),

              // ── Carrousel marketing abonnement ──
              MarketingCarousel(
                slides: buildSubscriptionSlides(subscriptionProvider),
              ).animate().fadeIn(
                    delay: 100.ms,
                    duration: 500.ms,
                  ),
              const SizedBox(height: 16),

              // ── Bannière cloud (plan gratuit) ──
              if (!_hasCloudSubscription(subscriptionProvider)) ...[
                CloudStorageInfoBanner(isFreePlan: true, compact: true)
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 500.ms),
                const SizedBox(height: 16),
              ],

              // ── Solde ──
              _buildBalanceCard(
                isDark: isDark,
                primaryColor: primaryColor,
                textColor: textColor,
                cardColor: cardColor,
              ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(
                    begin: 0.1,
                    end: 0,
                    curve: Curves.easeOut,
                    duration: 500.ms,
                  ),
              const SizedBox(height: 24),

              // ── Statistiques ──
              _buildFinancialStats(
                isDark: isDark,
                primaryColor: primaryColor,
                textColor: textColor,
                subTextColor: subTextColor,
                cardColor: cardColor,
              ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
              const SizedBox(height: 28),

              // ── Statut des factures ──
              _buildInvoiceStatus(
                isDark: isDark,
                primaryColor: primaryColor,
                textColor: textColor,
                subTextColor: subTextColor,
                cardColor: cardColor,
              ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
              const SizedBox(height: 28),

              // ── Promo ──
              const PromoSection()
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 500.ms),
              const SizedBox(height: 28),

              // ── Clients récents ──
              _buildRecentClients(
                isDark: isDark,
                primaryColor: primaryColor,
                textColor: textColor,
                subTextColor: subTextColor,
                cardColor: cardColor,
              ).animate().fadeIn(delay: 600.ms, duration: 500.ms),
              const SizedBox(height: 28),

              // ── Factures récentes ──
              _buildRecentInvoices(
                isDark: isDark,
                primaryColor: primaryColor,
                textColor: textColor,
                subTextColor: subTextColor,
                cardColor: cardColor,
              ).animate().fadeIn(delay: 700.ms, duration: 500.ms),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  HEADER — Avatar + bienvenue + actions (épuré)
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildHeader({
    required AppAuthProvider authProvider,
    required SubscriptionProvider subscriptionProvider,
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    final user = authProvider.user;

    return Row(
      children: [
        // Avatar
        GestureDetector(
          onTap: () => context.push('/dashboard/settings'),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor,
                  primaryColor.withValues(alpha: 0.65),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                (user?.displayName.isNotEmpty == true)
                    ? user!.displayName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Bienvenue
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Bonjour',
                style: TextStyle(
                  fontSize: 12.5,
                  color: subTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user?.displayName ?? 'Utilisateur',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),

        // Actions : notification + menu
        NotificationBadge(
          onTap: () => context.push('/notifications'),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: textColor,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: Icon(Icons.menu_rounded, color: textColor, size: 26),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  STATS — 3 cartes épurées
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildFinancialStats({
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
  }) {
    if (_isLoading) {
      return const SizedBox(
        height: 90,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Row(
      children: [
        _buildStatCard(
          label: 'Revenus',
          value: _financialStats.getFormattedTotalRevenue(),
          color: primaryColor,
          icon: Icons.trending_up_rounded,
          isDark: isDark,
          cardColor: cardColor,
          textColor: textColor,
          subTextColor: subTextColor,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          label: 'Moyenne',
          value: _financialStats.getFormattedAverageInvoice(),
          color: const Color(0xFF10B981),
          icon: Icons.show_chart_rounded,
          isDark: isDark,
          cardColor: cardColor,
          textColor: textColor,
          subTextColor: subTextColor,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          label: 'Taux paiement',
          value: '${_financialStats.paidPercentage.toStringAsFixed(0)}%',
          color: const Color(0xFFF59E0B),
          icon: Icons.percent_rounded,
          isDark: isDark,
          cardColor: cardColor,
          textColor: textColor,
          subTextColor: subTextColor,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: subTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BALANCE — Grande carte gradient
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildBalanceCard({
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color cardColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cercles décoratifs (fond)
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
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
                        const Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.white, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          'SOLDE TOTAL',
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
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      _financialStats.getFormattedTotalRevenue(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.2,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'FCFA',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // 3 mini-stats : encaissé / en attente / en retard
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildBalanceItem(
                      label: 'Encaissé',
                      value: _financialStats.getFormattedTotalPaid(),
                      color: const Color(0xFF34D399),
                    ),
                    _balanceDivider(),
                    _buildBalanceItem(
                      label: 'En attente',
                      value: _financialStats.getFormattedTotalPending(),
                      color: const Color(0xFFFBBF24),
                    ),
                    _balanceDivider(),
                    _buildBalanceItem(
                      label: 'En retard',
                      value: _financialStats.getFormattedTotalOverdue(),
                      color: const Color(0xFFF87171),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Actions rapides
              Row(
                children: [
                  _buildActionButton(
                    icon: Icons.add_rounded,
                    label: 'Facture',
                    onTap: () => context.push('/dashboard/invoices/create'),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Client',
                    onTap: () => context.push('/dashboard/clients/create'),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.payments_rounded,
                    label: 'Payer',
                    onTap: _showPaymentDialog,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceDivider() => Container(
        width: 1,
        height: 24,
        color: Colors.white.withValues(alpha: 0.14),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  Widget _buildBalanceItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 17),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  STATUT DES FACTURES — 4 mini-cartes
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildInvoiceStatus({
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
  }) {
    if (_isLoading) {
      return const SizedBox(
        height: 90,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Statut des factures',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            Text(
              '${_financialStats.totalInvoices} factures',
              style: TextStyle(
                fontSize: 12,
                color: subTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildStatusCard(
              label: 'Payées',
              count: _financialStats.paidCount,
              amount: _financialStats.getFormattedTotalPaid(),
              color: const Color(0xFF10B981),
              icon: Icons.check_circle_rounded,
              isDark: isDark,
              cardColor: cardColor,
              textColor: textColor,
              subTextColor: subTextColor,
            ),
            const SizedBox(width: 8),
            _buildStatusCard(
              label: 'En attente',
              count: _financialStats.pendingCount,
              amount: _financialStats.getFormattedTotalPending(),
              color: const Color(0xFFF59E0B),
              icon: Icons.schedule_rounded,
              isDark: isDark,
              cardColor: cardColor,
              textColor: textColor,
              subTextColor: subTextColor,
            ),
            const SizedBox(width: 8),
            _buildStatusCard(
              label: 'En retard',
              count: _financialStats.overdueCount,
              amount: _financialStats.getFormattedTotalOverdue(),
              color: const Color(0xFFEF4444),
              icon: Icons.warning_rounded,
              isDark: isDark,
              cardColor: cardColor,
              textColor: textColor,
              subTextColor: subTextColor,
            ),
            const SizedBox(width: 8),
            _buildStatusCard(
              label: 'Annulées',
              count: _financialStats.cancelledCount,
              amount: _financialStats.getFormattedTotalCancelled(),
              color: const Color(0xFF6B7280),
              icon: Icons.cancel_rounded,
              isDark: isDark,
              cardColor: cardColor,
              textColor: textColor,
              subTextColor: subTextColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required String label,
    required int count,
    required String amount,
    required Color color,
    required IconData icon,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                color: subTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CLIENTS RÉCENTS — bulles horizontales
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildRecentClients({
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
  }) {
    if (_isLoading) {
      return const SizedBox(
        height: 90,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Nouveaux clients',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/dashboard/clients'),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Voir tout',
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _recentClients.isEmpty
            ? _emptyMini(
                icon: Icons.people_outline,
                text: 'Aucun client pour le moment',
                subTextColor: subTextColor,
              )
            : SizedBox(
                height: 96,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _recentClients.length,
                  itemBuilder: (context, index) {
                    return _buildClientBubble(
                        _recentClients[index], isDark);
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildClientBubble(Client client, bool isDark) {
    final colors = [
      const Color(0xFF4F46E5),
      const Color(0xFF06B6D4),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
    ];
    final colorIndex = client.id.hashCode.abs() % colors.length;
    final color = colors[colorIndex];

    return GestureDetector(
      onTap: () => context.push('/dashboard/clients/${client.id}'),
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        width: 76,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    color.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  client.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              client.name.length > 10
                  ? '${client.name.substring(0, 10)}…'
                  : client.name,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  FACTURES RÉCENTES — liste épurée
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildRecentInvoices({
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
  }) {
    if (_isLoading) {
      return const SizedBox(
        height: 90,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Factures récentes',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/dashboard/invoices'),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Voir tout',
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _recentInvoices.isEmpty
            ? _emptyMini(
                icon: Icons.receipt_long_outlined,
                text: 'Aucune facture pour le moment',
                subTextColor: subTextColor,
              )
            : Column(
                children: _recentInvoices
                    .map((invoice) => _buildTransactionItem(
                          invoice,
                          isDark,
                          cardColor,
                          textColor,
                          subTextColor,
                        ))
                    .toList(),
              ),
      ],
    );
  }

  Widget _buildTransactionItem(
    Invoice invoice,
    bool isDark,
    Color cardColor,
    Color textColor,
    Color subTextColor,
  ) {
    final statusColors = _getStatusColors(invoice.status);
    final isExpense = invoice.status != 'paid' && invoice.status != 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () =>
              context.push('/dashboard/invoices/${invoice.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: invoice.isDevis
                        ? Colors.orange.withValues(alpha: 0.12)
                        : Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    invoice.isDevis
                        ? Icons.description_outlined
                        : Icons.receipt_long_rounded,
                    color: invoice.isDevis
                        ? Colors.orange[700]
                        : Colors.blue[700],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.invoiceNumber,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Client #${invoice.clientId.substring(0, 6)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: subTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${invoice.totalAmount.toStringAsFixed(0)} FCFA',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color:
                            isExpense ? Colors.red[700] : Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColors['bg'],
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _getStatusLabel(invoice.status),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: statusColors['text'],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyMini({
    required IconData icon,
    required String text,
    required Color subTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 32, color: subTextColor.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              color: subTextColor.withValues(alpha: 0.7),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, Color> _getStatusColors(String status) {
    switch (status) {
      case 'paid':
        return {
          'bg': const Color(0xFF10B981).withValues(alpha: 0.14),
          'text': const Color(0xFF047857),
        };
      case 'sent':
        return {
          'bg': const Color(0xFFF59E0B).withValues(alpha: 0.14),
          'text': const Color(0xFFB45309),
        };
      case 'overdue':
        return {
          'bg': const Color(0xFFEF4444).withValues(alpha: 0.14),
          'text': const Color(0xFFB91C1C),
        };
      case 'cancelled':
        return {
          'bg': const Color(0xFF6B7280).withValues(alpha: 0.14),
          'text': const Color(0xFF374151),
        };
      default:
        return {
          'bg': const Color(0xFF6B7280).withValues(alpha: 0.10),
          'text': const Color(0xFF4B5563),
        };
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Payée';
      case 'sent':
        return 'En attente';
      case 'overdue':
        return 'En retard';
      case 'cancelled':
        return 'Annulée';
      default:
        return 'Brouillon';
    }
  }

  bool _hasCloudSubscription(SubscriptionProvider subscriptionProvider) {
    final subscription = subscriptionProvider.subscription;
    final plan = subscriptionProvider.currentPlan;
    return subscription?.isActive == true && (plan?.isFree ?? true) == false;
  }

  void _showPaymentDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => PaymentBottomSheet(
        onPaymentComplete: _loadData,
      ),
    );
  }
}