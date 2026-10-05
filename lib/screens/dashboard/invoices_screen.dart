// lib/screens/dashboard/invoices_screen.dart
//
// 🧾 Factures — design épuré : héro avec totaux, onglets statut inline,
// cards aérées, recherche flottante, animations douces.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/client.dart';
import '../../models/invoice.dart';
import '../../providers/theme_provider.dart';
import '../../services/database_service.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<Invoice> _invoices = [];
  List<Client> _clients = [];
  Map<String, String> _clientNames = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'all';

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
    try {
      final results = await Future.wait([
        _db.getInvoices(),
        _db.getClients(),
      ]);
      if (!mounted) return;
      setState(() {
        _invoices = (results[0] as List<Invoice>?) ?? [];
        _clients = (results[1] as List<Client>?) ?? [];
        _clientNames = {for (var c in _clients) c.id: c.name};
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _invoices = [];
        _clients = [];
        _clientNames = {};
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de chargement : $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  List<Invoice> get _filteredInvoices {
    var filtered = _invoices;
    if (_filterStatus != 'all') {
      filtered = filtered.where((i) => i.status == _filterStatus).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      filtered = filtered.where((i) {
        final matchNumber = i.invoiceNumber.toLowerCase().contains(query);
        final clientName = _clientNames[i.clientId]?.toLowerCase() ?? '';
        final matchClient = clientName.contains(query);
        final matchAmount = i.totalAmount.toString().contains(query);
        final formattedDate = DateFormat('dd/MM/yyyy').format(i.issueDate);
        final matchDate = formattedDate.contains(query);
        return matchNumber || matchClient || matchAmount || matchDate;
      }).toList();
    }
    return filtered;
  }

  String _getClientName(String clientId) {
    if (clientId.isEmpty) return 'Client inconnu';
    return _clientNames[clientId] ??
        'Client #${clientId.length > 6 ? clientId.substring(0, 6) : clientId}';
  }

  // Totaux rapides
  int get _countPaid =>
      _invoices.where((i) => i.status == 'paid').length;
  int get _countPending =>
      _invoices.where((i) => i.status == 'sent').length;
  int get _countOverdue =>
      _invoices.where((i) => i.status == 'overdue').length;
  double get _totalPaid => _invoices
      .where((i) => i.status == 'paid')
      .fold(0.0, (s, i) => s + i.totalAmount);
  double get _totalPending => _invoices
      .where((i) => i.status == 'sent' || i.status == 'draft')
      .fold(0.0, (s, i) => s + i.totalAmount);
  double get _totalOverdue => _invoices
      .where((i) => i.status == 'overdue')
      .fold(0.0, (s, i) => s + i.totalAmount);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final card = theme.cardColor;
    final bg = theme.backgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: text, size: 20),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          'Factures',
          style: TextStyle(
            color: text,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Nouvelle facture',
            icon: Icon(Icons.add_rounded, color: primary, size: 24),
            onPressed: () async {
              await context.push('/dashboard/invoices/create');
              if (mounted) _loadData();
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ══════════════════════════════════════════════
                    //  HÉRO : total payé
                    // ══════════════════════════════════════════════
                    _buildHero(theme, primary, text)
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(
                          begin: 0.1,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(height: 20),

                    // ══════════════════════════════════════════════
                    //  Recherche flottante
                    // ══════════════════════════════════════════════
                    _buildSearchField(theme, isDark, primary, text, sub)
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 400.ms),
                    const SizedBox(height: 16),

                    // ══════════════════════════════════════════════
                    //  Filtres statut (chips)
                    // ══════════════════════════════════════════════
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _statusChip('all', 'Toutes',
                              _invoices.length, primary, text, isDark, card),
                          const SizedBox(width: 8),
                          _statusChip('paid', 'Payées', _countPaid,
                              const Color(0xFF10B981), text, isDark, card),
                          const SizedBox(width: 8),
                          _statusChip('sent', 'En attente', _countPending,
                              const Color(0xFFF59E0B), text, isDark, card),
                          const SizedBox(width: 8),
                          _statusChip('overdue', 'En retard', _countOverdue,
                              const Color(0xFFEF4444), text, isDark, card),
                        ],
                      ),
                    ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
                    const SizedBox(height: 20),

                    // ══════════════════════════════════════════════
                    //  Liste
                    // ══════════════════════════════════════════════
                    if (_filteredInvoices.isEmpty)
                      _buildEmptyState(theme)
                    else
                      ..._filteredInvoices.asMap().entries.map((entry) {
                        final i = entry.key;
                        final invoice = entry.value;
                        return _buildInvoiceCard(
                          invoice,
                          isDark,
                          text,
                          sub,
                          card,
                          primary,
                          index: i,
                        );
                      }),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/dashboard/invoices/create');
          if (mounted) _loadData();
        },
        backgroundColor: primary,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Facture',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13.5),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  HÉRO — Total encaissé + 2 sous-cartes (en attente / en retard)
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildHero(ThemeProvider theme, Color primary, Color text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary,
            primary.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cercles décoratifs
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
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
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.trending_up_rounded,
                            color: Colors.white, size: 12),
                        SizedBox(width: 5),
                        Text(
                          'TOTAL ENCAISSÉ',
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
                  Text(
                    '${_invoices.length} factures',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
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
                      _fmtAmount(_totalPaid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
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
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _heroMiniStat(
                      icon: Icons.schedule_rounded,
                      label: 'En attente',
                      value: _fmtAmount(_totalPending),
                      count: _countPending,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _heroMiniStat(
                      icon: Icons.warning_rounded,
                      label: 'En retard',
                      value: _fmtAmount(_totalOverdue),
                      count: _countOverdue,
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

  Widget _heroMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Recherche
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSearchField(
    ThemeProvider theme,
    bool isDark,
    Color primary,
    Color text,
    Color sub,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(color: text, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'N° facture, client, montant…',
          hintStyle: TextStyle(
            color: sub.withValues(alpha: 0.6),
            fontSize: 13.5,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: sub, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: sub, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Chips statut
  // ═══════════════════════════════════════════════════════════════════
  Widget _statusChip(
    String value,
    String label,
    int count,
    Color accent,
    Color text,
    bool isDark,
    Color card,
  ) {
    final selected = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent : card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : text,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.24)
                      : accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? Colors.white : accent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Card facture
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildInvoiceCard(
    Invoice invoice,
    bool isDark,
    Color text,
    Color sub,
    Color card,
    Color primary, {
    required int index,
  }) {
    final sc = _statusColors(invoice.status);
    final clientName = _getClientName(invoice.clientId);
    final isDevis = invoice.isDevis;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: card,
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
              onTap: () async {
                await context.push('/dashboard/invoices/${invoice.id}');
                if (mounted) _loadData();
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Ligne haute : type + n° + statut ──
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isDevis
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF4F46E5))
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isDevis ? 'DEVIS' : 'FACT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isDevis
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF4F46E5),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            invoice.invoiceNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: text,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: sc['bg'],
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _statusLabel(invoice.status),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: sc['text'],
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Ligne basse : client + montant ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person_outline_rounded,
                                      size: 12, color: sub),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      clientName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: text,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.event_outlined,
                                      size: 11, color: sub),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Échéance · ${DateFormat('dd MMM yyyy').format(invoice.dueDate)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: sub,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${invoice.totalAmount.toStringAsFixed(0)} F',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: primary,
                            letterSpacing: -0.4,
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
      )
          .animate()
          .fadeIn(
            delay: Duration(milliseconds: 50 + (index * 40)),
            duration: 350.ms,
          )
          .slideY(
            begin: 0.06,
            end: 0,
            duration: 350.ms,
            curve: Curves.easeOut,
          ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Empty state
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildEmptyState(ThemeProvider theme) {
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;

    final isFiltered = _searchQuery.isNotEmpty || _filterStatus != 'all';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary.withValues(alpha: 0.15),
                    primary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 44, color: primary),
            ).animate().scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                  duration: 400.ms,
                ),
            const SizedBox(height: 22),
            Text(
              isFiltered ? 'Aucun résultat' : 'Aucune facture',
              style: TextStyle(
                fontSize: 17,
                color: text,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Essayez un autre mot-clé ou un autre filtre.'
                  : 'Créez votre première facture pour commencer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: sub, height: 1.4),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await context.push('/dashboard/invoices/create');
                  if (mounted) _loadData();
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Créer une facture'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Helpers
  // ═══════════════════════════════════════════════════════════════════
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

  String _fmtAmount(double value) {
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