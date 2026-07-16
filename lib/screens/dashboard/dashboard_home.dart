// lib/screens/dashboard/dashboard_home.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/database_service.dart';
import '../../models/client.dart';
import '../../models/invoice.dart';
import '../../models/financial_stats.dart';
import '../../widgets/notification_badge.dart';
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
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final clients = await _db.getClients();
    final invoices = await _db.getInvoices();
    final stats = _calculateFinancialStats(invoices);
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
    final averageInvoiceValue = totalInvoices > 0
        ? (totalRevenue / totalInvoices).toDouble()
        : 0.0;

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
      // 🔥 En-tête personnalisé
      body: Column(
        children: [
          // ===== EN-TÊTE PERSONNALISÉ =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Row(
              children: [
                const Text(
                  'Accueil',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Notification avec badge
                NotificationBadge(
                  onTap: () => context.push('/notifications'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: textColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Avatar
                Consumer<AppAuthProvider>(
                  builder: (context, authProvider, _) {
                    final user = authProvider.user;
                    return GestureDetector(
                      onTap: () => context.push('/dashboard/settings'),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, primaryColor.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            user?.displayName.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                // 🔥 Menu hamburger (ouvre le drawer)
                IconButton(
                  icon: Icon(Icons.menu, color: textColor),
                  onPressed: () {
                    // ✅ Ouverture simple du drawer grâce au Scaffold parent
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ],
            ),
          ),
          // Contenu de la page
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(
                      authProvider: authProvider,
                      subscriptionProvider: subscriptionProvider,
                      isDark: isDark,
                      primaryColor: primaryColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    const SizedBox(height: 20),

                    // Stats
                    _buildFinancialStats(
                      isDark: isDark,
                      primaryColor: primaryColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      cardColor: cardColor,
                    ),
                    const SizedBox(height: 16),

                    // Balance
                    _buildBalanceCard(
                      isDark: isDark,
                      primaryColor: primaryColor,
                      textColor: textColor,
                      cardColor: cardColor,
                    ),
                    const SizedBox(height: 24),

                    // Status
                    _buildInvoiceStatus(
                      isDark: isDark,
                      primaryColor: primaryColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      cardColor: cardColor,
                    ),
                    const SizedBox(height: 24),

                    // Recent Clients
                    _buildRecentClients(
                      isDark: isDark,
                      primaryColor: primaryColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      cardColor: cardColor,
                    ),
                    const SizedBox(height: 24),

                    // Recent Invoices
                    _buildRecentInvoices(
                      isDark: isDark,
                      primaryColor: primaryColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      cardColor: cardColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== HEADER (Avatar, bonjour, badge) =====
  Widget _buildHeader({
    required AppAuthProvider authProvider,
    required SubscriptionProvider subscriptionProvider,
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    final user = authProvider.user;
    final subscription = subscriptionProvider.subscription;
    final planName = subscription?.planId == 'pro' ? 'Pro'
        : subscription?.planId == 'business' ? 'Business'
        : 'Gratuit';
    final isActive = subscription?.isActive ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => context.push('/dashboard/settings'),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                user?.displayName.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '👋 Bonjour,',
                style: TextStyle(
                  fontSize: 13,
                  color: subTextColor,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    user?.displayName ?? 'Utilisateur',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.green.withOpacity(0.15)
                          : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? Colors.green.withOpacity(0.3)
                            : Colors.orange.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? Icons.check_circle : Icons.warning,
                          size: 12,
                          color: isActive ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          planName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isActive ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                user?.email ?? 'user@email.com',
                style: TextStyle(
                  fontSize: 12,
                  color: subTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===== FINANCIAL STATS =====
  Widget _buildFinancialStats({
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      children: [
        _buildStatCard(
          label: 'Revenus',
          value: _financialStats.getFormattedTotalRevenue(),
          color: primaryColor,
          icon: Icons.trending_up,
          isDark: isDark,
          cardColor: cardColor,
          textColor: textColor,
          subTextColor: subTextColor,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          label: 'Moyenne',
          value: _financialStats.getFormattedAverageInvoice(),
          color: const Color(0xFF4CAF50),
          icon: Icons.equalizer,
          isDark: isDark,
          cardColor: cardColor,
          textColor: textColor,
          subTextColor: subTextColor,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          label: 'Taux paiement',
          value: '${_financialStats.paidPercentage.toStringAsFixed(1)}%',
          color: const Color(0xFFFF9800),
          icon: Icons.percent,
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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: subTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== BALANCE CARD =====
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
          colors: [primaryColor, primaryColor.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total balance',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _financialStats.getFormattedAverageInvoice(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildBalanceItem(
                label: 'Payé',
                value: _financialStats.getFormattedTotalPaid(),
                color: Colors.greenAccent,
              ),
              _buildBalanceItem(
                label: 'En attente',
                value: _financialStats.getFormattedTotalPending(),
                color: Colors.orangeAccent,
              ),
              _buildBalanceItem(
                label: 'En retard',
                value: _financialStats.getFormattedTotalOverdue(),
                color: Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildActionButton(
                icon: Icons.add,
                label: 'Facture',
                color: Colors.white.withOpacity(0.2),
                textColor: Colors.white,
                onTap: () {
                  context.push('/dashboard/invoices/create');
                },
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.person_add,
                label: 'Client',
                color: Colors.white.withOpacity(0.2),
                textColor: Colors.white,
                onTap: () {
                  context.push('/dashboard/clients/create');
                },
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.payment,
                label: 'Payer',
                color: Colors.white.withOpacity(0.2),
                textColor: Colors.white,
                onTap: () {
                  _showPaymentDialog();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== INVOICE STATUS =====
  Widget _buildInvoiceStatus({
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Statut des factures',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatusCard(
              label: 'Payées',
              count: _financialStats.paidCount,
              amount: _financialStats.getFormattedTotalPaid(),
              color: Colors.green,
              icon: Icons.check_circle,
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
              color: Colors.orange,
              icon: Icons.hourglass_empty,
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
              color: Colors.red,
              icon: Icons.warning,
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
              color: Colors.grey,
              icon: Icons.cancel,
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: subTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ===== RECENT CLIENTS =====
  Widget _buildRecentClients({
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nouveaux clients',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            TextButton(
              onPressed: () {
                context.push('/dashboard/clients');
              },
              child: Text(
                'Voir tout',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _recentClients.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Aucun client pour le moment',
                    style: TextStyle(color: subTextColor),
                  ),
                ),
              )
            : SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentClients.length,
                  itemBuilder: (context, index) {
                    final client = _recentClients[index];
                    return _buildClientBubble(client, isDark);
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildClientBubble(Client client, bool isDark) {
    final colors = [
      const Color(0xFF1A237E),
      const Color(0xFF3949AB),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
    ];
    final colorIndex = client.id.hashCode.abs() % colors.length;
    final color = colors[colorIndex];

    return GestureDetector(
      onTap: () {
        context.push('/dashboard/clients/${client.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        width: 80,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.6)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  client.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              client.name.length > 10
                  ? '${client.name.substring(0, 10)}...'
                  : client.name,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ===== RECENT INVOICES =====
  Widget _buildRecentInvoices({
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Factures récentes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            TextButton(
              onPressed: () {
                context.push('/dashboard/invoices');
              },
              child: Text(
                'Voir tout',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _recentInvoices.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Aucune facture pour le moment',
                    style: TextStyle(color: subTextColor),
                  ),
                ),
              )
            : Column(
                children: _recentInvoices.map((invoice) =>
                    _buildTransactionItem(invoice, isDark, cardColor, textColor, subTextColor)
                ).toList(),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 5,
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          context.push('/dashboard/invoices/${invoice.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: invoice.isDevis ? Colors.orange[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                invoice.isDevis ? Icons.description_outlined : Icons.receipt_long,
                color: invoice.isDevis ? Colors.orange[700] : Colors.blue[700],
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
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Client #${invoice.clientId.substring(0, 6)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: subTextColor,
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isExpense ? Colors.red[700] : Colors.green[700],
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColors['bg'],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusLabel(invoice.status),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: statusColors['text'],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, Color> _getStatusColors(String status) {
    switch (status) {
      case 'paid':
        return {
          'bg': Colors.green[50]!,
          'text': Colors.green[700]!,
        };
      case 'sent':
        return {
          'bg': Colors.orange[50]!,
          'text': Colors.orange[700]!,
        };
      case 'overdue':
        return {
          'bg': Colors.red[50]!,
          'text': Colors.red[700]!,
        };
      case 'cancelled':
        return {
          'bg': Colors.grey[100]!,
          'text': Colors.grey[700]!,
        };
      default:
        return {
          'bg': Colors.grey[50]!,
          'text': Colors.grey[700]!,
        };
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'paid': return 'Payée';
      case 'sent': return 'En attente';
      case 'overdue': return 'En retard';
      case 'cancelled': return 'Annulée';
      default: return 'Brouillon';
    }
  }

  void _showPaymentDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PaymentBottomSheet(
        onPaymentComplete: _loadData,
      ),
    );
  }
}