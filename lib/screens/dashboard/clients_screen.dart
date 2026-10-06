// lib/screens/dashboard/clients_screen.dart
// ignore_for_file: deprecated_member_use
//
// 👥 Clients — liste épurée : recherche inline, résumé stats, cartes aérées.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/client.dart';
import '../../models/invoice.dart';
import '../../providers/theme_provider.dart';
import '../../services/database_service.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<Client> _clients = [];
  List<Invoice> _invoices = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _db.getClients(),
      _db.getInvoices(),
    ]);
    if (!mounted) return;
    setState(() {
      _clients = results[0] as List<Client>;
      _invoices = results[1] as List<Invoice>;
      _isLoading = false;
    });
  }

  List<Client> get _filteredClients {
    if (_searchQuery.isEmpty) return _clients;
    final q = _searchQuery.toLowerCase();
    return _clients
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q) ||
            c.phone.contains(q))
        .toList();
  }

  int _invoiceCountOf(String clientId) =>
      _invoices.where((inv) => inv.clientId == clientId).length;

  double _totalRevenueOf(String clientId) => _invoices
      .where((inv) => inv.clientId == clientId && inv.status == 'paid')
      .fold(0.0, (sum, inv) => sum + inv.totalAmount);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final primaryColor = theme.primaryColor;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final cardColor = theme.cardColor;
    final bgColor = theme.backgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(theme, isDark, textColor, subTextColor),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _clients.isEmpty
              ? _buildEmptyState(theme)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: primaryColor,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Résumé ──
                        _buildSummaryRow(theme)
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(
                              begin: 0.1,
                              end: 0,
                              duration: 400.ms,
                              curve: Curves.easeOut,
                            ),
                        const SizedBox(height: 24),

                        // ── En-tête liste ──
                        Row(
                          children: [
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Résultats'
                                  : 'Tous les clients',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${_filteredClients.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── Liste ──
                        if (_filteredClients.isEmpty)
                          _buildNoResult(textColor, subTextColor)
                        else
                          ..._filteredClients.asMap().entries.map((entry) {
                            final i = entry.key;
                            final client = entry.value;
                            return _buildClientCard(
                              client,
                              isDark,
                              textColor,
                              subTextColor,
                              cardColor,
                              primaryColor,
                            )
                                .animate()
                                .fadeIn(
                                  delay:
                                      Duration(milliseconds: 50 + (i * 40)),
                                  duration: 400.ms,
                                )
                                .slideY(
                                  begin: 0.06,
                                  end: 0,
                                  duration: 400.ms,
                                  curve: Curves.easeOut,
                                );
                          }),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/dashboard/clients/create');
          if (mounted) _loadData();
        },
        backgroundColor: primaryColor,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Client',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13.5),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    ThemeProvider theme,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: textColor, size: 20),
        onPressed: () => context.go('/dashboard'),
      ),
      title: _isSearching
          ? Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher un client…',
                  hintStyle:
                      TextStyle(color: subTextColor, fontSize: 13.5),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search_rounded,
                      color: subTextColor, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: subTextColor, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _isSearching = false;
                      });
                    },
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            )
          : Text(
              'Clients',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 19,
                letterSpacing: -0.3,
              ),
            ),
      actions: [
        if (!_isSearching)
          IconButton(
            icon: Icon(Icons.search_rounded, color: textColor, size: 22),
            onPressed: () => setState(() => _isSearching = true),
          ),
        const SizedBox(width: 6),
      ],
    );
  }

  // ── Résumé : 3 tuiles ──
  Widget _buildSummaryRow(ThemeProvider theme) {
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final primaryColor = theme.primaryColor;

    final totalClients = _clients.length;
    final totalInvoices = _invoices.length;
    final totalRevenue = _invoices
        .where((inv) => inv.status == 'paid')
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);

    return Row(
      children: [
        Expanded(
          child: _summaryTile(
            label: 'Clients',
            value: '$totalClients',
            icon: Icons.people_rounded,
            color: primaryColor,
            textColor: textColor,
            subTextColor: subTextColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryTile(
            label: 'Factures',
            value: '$totalInvoices',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF4F46E5),
            textColor: textColor,
            subTextColor: subTextColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryTile(
            label: 'Encaissé',
            value: _kpi(totalRevenue),
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF10B981),
            textColor: textColor,
            subTextColor: subTextColor,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _summaryTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color textColor,
    required Color subTextColor,
    required bool isDark,
  }) {
    return Container(
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
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: subTextColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── Card client ──
  Widget _buildClientCard(
    Client client,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color primaryColor,
  ) {
    final invoiceCount = _invoiceCountOf(client.id);
    final revenue = _totalRevenueOf(client.id);
    final color = _colorForClient(client.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                context.push('/dashboard/clients/${client.id}'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Avatar gradient carré arrondi
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color,
                          color.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        client.name.isNotEmpty
                            ? client.name.substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Infos
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (client.phone.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.phone_rounded,
                                  size: 12, color: subTextColor),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  client.phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: subTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (client.email.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Icon(Icons.mail_outline_rounded,
                                    size: 12, color: subTextColor),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    client.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: subTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Stats
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$invoiceCount facture${invoiceCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      if (revenue > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          _kpi(revenue),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      color: subTextColor.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResult(Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                size: 44, color: subTextColor.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text(
              'Aucun résultat',
              style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Essayez un autre mot-clé',
              style: TextStyle(color: subTextColor, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final primaryColor = theme.primaryColor;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.15),
                    primaryColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(Icons.people_outline_rounded,
                  size: 44, color: primaryColor),
            ).animate().scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                  duration: 500.ms,
                ),
            const SizedBox(height: 24),
            Text(
              'Aucun client',
              style: TextStyle(
                fontSize: 18,
                color: textColor,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez votre premier client pour commencer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: subTextColor, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await context.push('/dashboard/clients/create');
                if (mounted) _loadData();
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ajouter un client'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──
  Color _colorForClient(String id) {
    const colors = [
      Color(0xFF4F46E5),
      Color(0xFF06B6D4),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
      Color(0xFF14B8A6),
      Color(0xFFEF4444),
    ];
    return colors[id.hashCode.abs() % colors.length];
  }

  String _kpi(double value) {
    final abs = value.abs();
    if (abs >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1).replaceAll('.', ',')} Md';
    }
    if (abs >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
    }
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ' ',
        );
  }
}