// lib/screens/dashboard/invoices_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../models/invoice.dart';
import '../../models/client.dart';
import '../../providers/theme_provider.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final DatabaseService _db = DatabaseService();
  List<Invoice> _invoices = [];
  List<Client> _clients = [];
  Map<String, String> _clientNames = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'all';
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchFocusNode.addListener(_onSearchFocusChange);
  }

  void _onSearchFocusChange() {
    setState(() {
      _isSearchFocused = _searchFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchFocusNode.dispose();
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
      _invoices = (results[0] as List<Invoice>?) ?? [];
      _clients = (results[1] as List<Client>?) ?? [];
      _clientNames = {for (var c in _clients) c.id: c.name};
    } catch (e) {
      _invoices = [];
      _clients = [];
      _clientNames = {};
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement : $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          'Factures',
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
          PopupMenuButton<String>(
            icon: Icon(Icons.tune, color: textColor, size: 22),
            onSelected: (value) => setState(() => _filterStatus = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('Toutes')),
              PopupMenuItem(value: 'paid', child: Text('Payées')),
              PopupMenuItem(value: 'sent', child: Text('En attente')),
              PopupMenuItem(value: 'overdue', child: Text('En retard')),
              PopupMenuItem(value: 'cancelled', child: Text('Annulées')),
              PopupMenuItem(value: 'draft', child: Text('Brouillons')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              focusNode: _searchFocusNode,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: 'Rechercher une facture...',
                hintStyle: TextStyle(
                  color: subTextColor.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: _isSearchFocused ? primaryColor : subTextColor.withOpacity(0.5),
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: subTextColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: subTextColor,
                            size: 14,
                          ),
                        ),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _searchFocusNode.unfocus();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredInvoices.isEmpty
              ? _buildEmptyState(isDark, textColor, subTextColor, primaryColor)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: _filteredInvoices.length,
                    itemBuilder: (context, index) {
                      final invoice = _filteredInvoices[index];
                      return _buildInvoiceCard(
                        invoice,
                        isDark,
                        textColor,
                        subTextColor,
                        cardColor,
                        primaryColor,
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/dashboard/invoices/create'),
        backgroundColor: primaryColor,
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildInvoiceCard(
    Invoice invoice,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color primaryColor,
  ) {
    final statusColors = _getStatusColors(invoice.status);
    final clientName = _getClientName(invoice.clientId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/dashboard/invoices/${invoice.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: invoice.isDevis 
                            ? Colors.orange.withOpacity(0.1) 
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        invoice.isDevis ? 'DEVIS' : 'FACT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: invoice.isDevis ? Colors.orange[700] : Colors.blue[700],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        invoice.invoiceNumber,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColors['bg']!.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusLabel(invoice.status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: statusColors['text'],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clientName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            DateFormat('dd MMM yyyy').format(invoice.dueDate),
                            style: TextStyle(
                              fontSize: 11,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${invoice.totalAmount.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
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
            child: Icon(Icons.receipt_long_outlined, size: 32, color: primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'Aucune facture trouvée' : 'Aucune facture',
            style: TextStyle(fontSize: 18, color: textColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty ? 'Essayez d\'autres mots-clés' : 'Créez votre première facture',
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

  Map<String, Color> _getStatusColors(String status) {
    switch (status) {
      case 'paid':
        return {'bg': Colors.green, 'text': Colors.green};
      case 'sent':
        return {'bg': Colors.orange, 'text': Colors.orange};
      case 'overdue':
        return {'bg': Colors.red, 'text': Colors.red};
      case 'cancelled':
        return {'bg': Colors.grey, 'text': Colors.grey};
      default:
        return {'bg': Colors.grey, 'text': Colors.grey};
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
}