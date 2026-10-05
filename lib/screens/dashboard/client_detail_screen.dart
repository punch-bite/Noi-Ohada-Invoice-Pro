// lib/screens/dashboard/client_detail_screen.dart
// ignore_for_file: deprecated_member_use
//
// 👤 Détail client — héro gradient, onglets segmentés, cartes stats unifiées.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/client.dart';
import '../../models/invoice.dart';
import '../../providers/theme_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/glass_widgets.dart';
import 'create_client_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final String clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final DatabaseService _db = DatabaseService();
  Client? _client;
  List<Invoice> _invoices = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _client = await _db.getClient(widget.clientId);
    if (_client != null) {
      _invoices = await _db.getInvoicesByClient(_client!.id);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Color _colorForClient(String id) {
    const colors = [
      Color(0xFF4F46E5),
      Color(0xFF06B6D4),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
    ];
    return colors[id.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final primaryColor = theme.primaryColor;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final cardColor = theme.cardColor;
    final bgColor = theme.backgroundColor;

    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: textColor, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Client',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 19,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: textColor, size: 22),
            onPressed: () async {
              if (_client != null) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreateClientScreen(client: _client),
                  ),
                );
                if (mounted) _loadData();
              }
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: textColor, size: 22),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            onSelected: (v) {
              if (v == 'delete') _deleteClient();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Supprimer',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _client == null
              ? Center(
                  child: Text('Client non trouvé',
                      style: TextStyle(color: subTextColor)),
                )
              : Column(
                  children: [
                    // ── Héro client ──
                    _buildProfileHero(
                      _client!,
                      theme,
                      textColor,
                      subTextColor,
                      primaryColor,
                    ).animate().fadeIn(duration: 400.ms).slideY(
                          begin: -0.1,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(height: 8),

                    // ── Onglets ──
                    _buildTabs(theme, primaryColor, textColor),
                    const SizedBox(height: 8),

                    // ── Contenu ──
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _selectedTab == 0
                            ? _buildOverview(
                                theme, textColor, subTextColor, primaryColor)
                            : _buildInvoicesList(
                                theme, textColor, subTextColor, primaryColor),
                      ),
                    ),
                  ],
                ),
    );
  }

  // ── Héro ──
  Widget _buildProfileHero(
    Client client,
    ThemeProvider theme,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    final color = _colorForClient(client.id);
    final totalRevenue = _invoices
        .where((inv) => inv.status == 'paid')
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withValues(alpha: 0.72),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      client.name.isNotEmpty
                          ? client.name.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (client.taxId.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'NUI · ${client.taxId}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _heroStat(
                  icon: Icons.receipt_long_rounded,
                  label: 'Factures',
                  value: '${_invoices.length}',
                ),
                const SizedBox(width: 10),
                _heroStat(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Encaissé',
                  value: _kpi(totalRevenue),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (client.phone.isNotEmpty)
                  _heroContact(
                    icon: Icons.phone_rounded,
                    text: client.phone,
                  ),
              ],
            ),
            if (client.email.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _heroContact(
                  icon: Icons.mail_outline_rounded,
                  text: client.email,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _heroStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
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
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroContact({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ── Onglets segmentés ──
  Widget _buildTabs(
    ThemeProvider theme,
    Color primaryColor,
    Color textColor,
  ) {
    final isDark = theme.isDarkMode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _tabButton(
              label: 'Aperçu',
              index: 0,
              primaryColor: primaryColor,
              textColor: textColor,
            ),
            _tabButton(
              label: 'Factures · ${_invoices.length}',
              index: 1,
              primaryColor: primaryColor,
              textColor: textColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required int index,
    required Color primaryColor,
    required Color textColor,
  }) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : textColor,
            ),
          ),
        ),
      ),
    );
  }

  // ── Aperçu ──
  Widget _buildOverview(
    ThemeProvider theme,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    final isDark = theme.isDarkMode;
    final totalInvoices = _invoices.length;
    final totalAmount =
        _invoices.fold(0.0, (sum, inv) => sum + inv.totalAmount);
    final paidAmount = _invoices
        .where((inv) => inv.status == 'paid')
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);
    final unpaidAmount = totalAmount - paidAmount;

    return SingleChildScrollView(
      key: const ValueKey('overview'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stats grid
          Row(
            children: [
              _statTile(
                label: 'Total factures',
                value: '$totalInvoices',
                icon: Icons.receipt_long_rounded,
                color: primaryColor,
                textColor: textColor,
                subTextColor: subTextColor,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _statTile(
                label: 'Total TTC',
                value: _kpi(totalAmount),
                icon: Icons.summarize_rounded,
                color: const Color(0xFF4F46E5),
                textColor: textColor,
                subTextColor: subTextColor,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile(
                label: 'Encaissé',
                value: _kpi(paidAmount),
                icon: Icons.arrow_downward_rounded,
                color: const Color(0xFF10B981),
                textColor: textColor,
                subTextColor: subTextColor,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _statTile(
                label: 'En attente',
                value: _kpi(unpaidAmount),
                icon: Icons.schedule_rounded,
                color: const Color(0xFFF59E0B),
                textColor: textColor,
                subTextColor: subTextColor,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Adresse
          _section(
            title: 'Adresse',
            icon: Icons.location_on_outlined,
            textColor: textColor,
            subTextColor: subTextColor,
            isDark: isDark,
            child: Text(
              _client?.address.isNotEmpty == true
                  ? _client!.address
                  : 'Non renseignée',
              style: TextStyle(
                fontSize: 13.5,
                color: _client?.address.isNotEmpty == true
                    ? textColor
                    : subTextColor,
                height: 1.5,
                fontStyle: _client?.address.isNotEmpty == true
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Dernières factures
          _section(
            title: 'Dernières factures',
            icon: Icons.history_rounded,
            textColor: textColor,
            subTextColor: subTextColor,
            isDark: isDark,
            trailing: _invoices.isNotEmpty
                ? TextButton(
                    onPressed: () => setState(() => _selectedTab = 1),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Voir tout',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  )
                : null,
            child: _invoices.isEmpty
                ? _emptyMini(
                    icon: Icons.receipt_long_outlined,
                    text: 'Aucune facture',
                    subTextColor: subTextColor,
                  )
                : Column(
                    children: _invoices
                        .take(3)
                        .map((inv) => _buildInvoiceTile(
                              inv,
                              theme,
                              textColor,
                              subTextColor,
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color textColor,
    required Color subTextColor,
    required bool isDark,
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
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: -0.3,
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
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Color textColor,
    required Color subTextColor,
    required bool isDark,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D26) : Colors.white,
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
          Row(
            children: [
              Icon(icon, size: 16, color: subTextColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _emptyMini({
    required IconData icon,
    required String text,
    required Color subTextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          children: [
            Icon(icon,
                size: 30, color: subTextColor.withValues(alpha: 0.4)),
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
      ),
    );
  }

  // ── Factures ──
  Widget _buildInvoicesList(
    ThemeProvider theme,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    if (_invoices.isEmpty) {
      return Center(
        key: const ValueKey('empty-invoices'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 52, color: subTextColor.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Aucune facture',
              style: TextStyle(
                  fontSize: 15,
                  color: textColor,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Créez une facture pour ce client',
              style: TextStyle(fontSize: 12.5, color: subTextColor),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      key: const ValueKey('invoices-list'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: _invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildInvoiceCard(
          _invoices[index],
          theme,
          textColor,
          subTextColor,
        )
            .animate()
            .fadeIn(
              delay: Duration(milliseconds: 50 + (index * 40)),
              duration: 400.ms,
            )
            .slideY(
              begin: 0.06,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOut,
            );
      },
    );
  }

  Widget _buildInvoiceCard(
    Invoice invoice,
    ThemeProvider theme,
    Color textColor,
    Color subTextColor,
  ) {
    final isDark = theme.isDarkMode;
    final statusColors = _statusColors(invoice.status);
    final isExpense = invoice.status != 'paid' && invoice.status != 'cancelled';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D26) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                context.push('/dashboard/invoices/${invoice.id}'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: invoice.isDevis
                          ? Colors.orange.withValues(alpha: 0.14)
                          : Colors.blue.withValues(alpha: 0.14),
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
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${invoice.items.length} produit${invoice.items.length > 1 ? 's' : ''} · ${invoice.issueDate.day}/${invoice.issueDate.month}/${invoice.issueDate.year}',
                          style: TextStyle(
                              fontSize: 11.5, color: subTextColor),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${invoice.totalAmount.toStringAsFixed(0)} F',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isExpense
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
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
                          _statusLabel(invoice.status),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: statusColors['text'],
                            letterSpacing: 0.3,
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
      ),
    );
  }

  Widget _buildInvoiceTile(
    Invoice invoice,
    ThemeProvider theme,
    Color textColor,
    Color subTextColor,
  ) {
    final isDark = theme.isDarkMode;
    final statusColors = _statusColors(invoice.status);

    return InkWell(
      onTap: () => context.push('/dashboard/invoices/${invoice.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNumber,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${invoice.issueDate.day}/${invoice.issueDate.month}/${invoice.issueDate.year}',
                    style: TextStyle(fontSize: 11, color: subTextColor),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${invoice.totalAmount.toStringAsFixed(0)} F',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColors['bg'],
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(invoice.status),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
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

  Map<String, Color> _statusColors(String status) {
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

  String _statusLabel(String status) {
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

  Future<void> _deleteClient() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Voulez-vous vraiment supprimer « ${_client?.name} » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true && _client != null) {
      await _db.deleteClient(_client!.id);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client supprimé'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}