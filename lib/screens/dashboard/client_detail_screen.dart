// lib/screens/dashboard/client_detail_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../models/client.dart';
import '../../models/invoice.dart';
import '../../providers/theme_provider.dart';
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
    setState(() => _isLoading = false);
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
    final dividerColor = themeProvider.dividerColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          _client?.name ?? 'Détail client',
          style: TextStyle(
            color: textColor,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: textColor,
            ),
            onPressed: () {
              if (_client != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateClientScreen(client: _client),
                  ),
                ).then((_) => _loadData());
              }
            },
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: textColor,
            ),
            onPressed: () => _showMoreMenu(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _client == null
              ? Center(
                  child: Text(
                    'Client non trouvé',
                    style: TextStyle(color: subTextColor),
                  ),
                )
              : Column(
                  children: [
                    // Profile Header
                    _buildProfileHeader(
                      _client!,
                      isDark,
                      primaryColor,
                      textColor,
                      subTextColor,
                      cardColor,
                    ),
                    // Tabs
                    _buildTabs(
                      isDark,
                      textColor,
                      primaryColor,
                    ),
                    // Content
                    Expanded(
                      child: _selectedTab == 0
                          ? _buildOverview(
                              isDark,
                              textColor,
                              subTextColor,
                              cardColor,
                              primaryColor,
                            )
                          : _buildInvoicesList(
                              isDark,
                              textColor,
                              subTextColor,
                              cardColor,
                              primaryColor,
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildProfileHeader(
    Client client,
    bool isDark,
    Color primaryColor,
    Color textColor,
    Color subTextColor,
    Color cardColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: cardColor,
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getColorForClient(client.id),
                  _getColorForClient(client.id).withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                client.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.phone,
                      size: 16,
                      color: subTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      client.phone,
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      Icons.email,
                      size: 16,
                      color: subTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      client.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
                if (client.taxId.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 16,
                        color: subTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'NUI: ${client.taxId}',
                        style: TextStyle(
                          fontSize: 14,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(
    bool isDark,
    Color textColor,
    Color primaryColor,
  ) {
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Row(
        children: [
          _buildTab('Aperçu', 0, textColor, primaryColor),
          _buildTab('Factures (${_invoices.length})', 1, textColor, primaryColor),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, Color textColor, Color primaryColor) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? primaryColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? primaryColor : textColor,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverview(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color primaryColor,
  ) {
    final totalInvoices = _invoices.length;
    final totalAmount = _invoices.fold(0.0, (sum, inv) => sum + inv.totalAmount);
    final paidAmount = _invoices
        .where((inv) => inv.status == 'paid')
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);
    final unpaidAmount = _invoices
        .where((inv) => inv.status != 'paid')
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatCard(
                'Total factures',
                totalInvoices.toString(),
                primaryColor,
                isDark,
                textColor,
                subTextColor,
                cardColor,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Total TTC',
                '${totalAmount.toStringAsFixed(0)} FCFA',
                Colors.green,
                isDark,
                textColor,
                subTextColor,
                cardColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard(
                'Payé',
                '${paidAmount.toStringAsFixed(0)} FCFA',
                Colors.green,
                isDark,
                textColor,
                subTextColor,
                cardColor,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Impayé',
                '${unpaidAmount.toStringAsFixed(0)} FCFA',
                Colors.red,
                isDark,
                textColor,
                subTextColor,
                cardColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Adresse
          Container(
            padding: const EdgeInsets.all(16),
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
                Text(
                  'Adresse',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _client?.address ?? 'Adresse non renseignée',
                  style: TextStyle(
                    fontSize: 14,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Recent Invoices
          Container(
            padding: const EdgeInsets.all(16),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dernières factures',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedTab = 1);
                      },
                      child: Text(
                        'Voir tout',
                        style: TextStyle(
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_invoices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Aucune facture pour ce client',
                        style: TextStyle(color: subTextColor),
                      ),
                    ),
                  )
                else
                  ..._invoices.take(3).map((invoice) =>
                    _buildInvoiceTile(invoice, isDark, textColor, subTextColor, primaryColor)
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
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
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceTile(
    Invoice invoice,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    final statusColors = _getStatusColors(invoice.status);
    
    return InkWell(
      onTap: () {
        context.push('/dashboard/invoices/${invoice.id}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '${invoice.issueDate.day}/${invoice.issueDate.month}/${invoice.issueDate.year}',
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
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColors['bg'],
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
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesList(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color primaryColor,
  ) {
    if (_invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune facture',
              style: TextStyle(
                fontSize: 18,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez une facture pour ce client',
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final invoice = _invoices[index];
        final statusColors = _getStatusColors(invoice.status);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: invoice.isDevis
                        ? Colors.orange[50]
                        : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      invoice.isDevis ? 'D' : 'F',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: invoice.isDevis
                            ? Colors.orange[700]
                            : Colors.blue[700],
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
                        invoice.invoiceNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${invoice.items.length} produits',
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
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColors['bg'],
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
              ],
            ),
          ),
        );
      },
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

  Color _getColorForClient(String id) {
    final colors = [
      const Color(0xFF1A237E),
      const Color(0xFF3949AB),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
    ];
    final index = id.hashCode.abs() % colors.length;
    return colors[index];
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuOption(
              icon: Icons.edit,
              label: 'Modifier',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                if (_client != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateClientScreen(client: _client),
                    ),
                  ).then((_) => _loadData());
                }
              },
            ),
            _buildMenuOption(
              icon: Icons.share,
              label: 'Partager',
              color: Colors.purple,
              onTap: () => Navigator.pop(context),
            ),
            _buildMenuOption(
              icon: Icons.delete_outline,
              label: 'Supprimer',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _deleteClient();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  Future<void> _deleteClient() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le client'),
        content: Text('Voulez-vous vraiment supprimer ${_client?.name} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true && _client != null) {
      await _db.deleteClient(_client!.id);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client supprimé')),
        );
      }
    }
  }
}