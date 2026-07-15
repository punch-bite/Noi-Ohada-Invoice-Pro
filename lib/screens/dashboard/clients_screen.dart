// lib/screens/dashboard/clients_screen.dart
// ignore_for_file: unused_local_variable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../models/client.dart';
import '../../providers/theme_provider.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final DatabaseService _db = DatabaseService();
  List<Client> _clients = [];
  bool _isLoading = true;
  final String _searchQuery = '';
  final String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    _clients = await _db.getClients();
    setState(() => _isLoading = false);
  }

  List<Client> get _filteredClients {
    var filtered = _clients;
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((client) =>
        client.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        client.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        client.phone.contains(_searchQuery)
      ).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    // onRefresh: _loadClients,
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final bgColor = themeProvider.backgroundColor;
    final dividerColor = themeProvider.dividerColor;
    final inputFillColor = themeProvider.inputFillColor;
    final inputBorderColor = themeProvider.inputBorderColor;
    final shadowColor = themeProvider.shadowColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        // 🔥 Ajout du bouton retour
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.go('/dashboard'), // Retour à la page précédente
        ),
        title: Text(
          'Clients',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.search,
              color: textColor,
            ),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _ClientSearchDelegate(_clients),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredClients.isEmpty
              ? _buildEmptyState(isDark, textColor, subTextColor, primaryColor)
              : RefreshIndicator(
                  onRefresh: _loadClients,
                  color: primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredClients.length,
                    itemBuilder: (context, index) {
                      final client = _filteredClients[index];
                      return _buildClientCard(
                        client,
                        isDark,
                        textColor,
                        subTextColor,
                        cardColor,
                        shadowColor,
                        primaryColor,
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/dashboard/clients/create');
        },
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildClientCard(
    Client client,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color shadowColor,
    Color primaryColor,
  ) {
    return GestureDetector(
      onTap: () {
        context.push('/dashboard/clients/${client.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getColorForClient(client.id),
                    _getColorForClient(client.id).withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
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
            const SizedBox(width: 14),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.phone,
                        size: 14,
                        color: subTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        client.phone,
                        style: TextStyle(
                          fontSize: 13,
                          color: subTextColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.email,
                        size: 14,
                        color: subTextColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          client.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: subTextColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_getClientDeals(client.id)} deals',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: subTextColor,
            ),
          ],
        ),
      ),
    );
  }

  int _getClientDeals(String clientId) {
    return clientId.hashCode.abs() % 10 + 5;
  }

  Color _getColorForClient(String id) {
    final colors = [
      const Color(0xFF1A237E),
      const Color(0xFF3949AB),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFF44336),
    ];
    final index = id.hashCode.abs() % colors.length;
    return colors[index];
  }

  Widget _buildEmptyState(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : const Color(0xFFE8EAF6),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.people_outline,
              size: 40,
              color: isDark ? Colors.grey[400] : primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun client',
            style: TextStyle(
              fontSize: 18,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre premier client',
            style: TextStyle(
              fontSize: 14,
              color: subTextColor,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.push('/dashboard/clients/create');
            },
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un client'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientSearchDelegate extends SearchDelegate<Client?> {
  final List<Client> clients;

  _ClientSearchDelegate(this.clients);

  @override
  List<Widget> buildActions(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;

    return [
      IconButton(
        icon: Icon(
          Icons.clear,
          color: textColor,
        ),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;

    return IconButton(
      icon: Icon(
        Icons.arrow_back,
        color: textColor,
      ),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final bgColor = themeProvider.backgroundColor;

    final results = clients.where((client) =>
      client.name.toLowerCase().contains(query.toLowerCase()) ||
      client.phone.contains(query)
    ).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final client = results[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getColorForClient(client.id),
              child: Text(
                client.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            title: Text(
              client.name,
              style: TextStyle(
                color: textColor,
              ),
            ),
            subtitle: Text(
              client.phone,
              style: TextStyle(
                color: subTextColor,
              ),
            ),
            onTap: () {
              close(context, client);
            },
          ),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final bgColor = themeProvider.backgroundColor;

    final results = clients.where((client) =>
      client.name.toLowerCase().contains(query.toLowerCase()) ||
      client.phone.contains(query)
    ).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final client = results[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getColorForClient(client.id),
              child: Text(
                client.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            title: Text(
              client.name,
              style: TextStyle(
                color: textColor,
              ),
            ),
            subtitle: Text(
              client.phone,
              style: TextStyle(
                color: subTextColor,
              ),
            ),
            onTap: () {
              close(context, client);
            },
          ),
        );
      },
    );
  }

  Color _getColorForClient(String id) {
    final colors = [
      const Color(0xFF1A237E),
      const Color(0xFF3949AB),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFF44336),
    ];
    final index = id.hashCode.abs() % colors.length;
    return colors[index];
  }
}