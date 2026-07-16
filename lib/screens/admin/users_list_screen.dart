import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';
import '../../models/user.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final AdminService _adminService = AdminService();
  List<AppUser> _users = [];
  List<AppUser> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterRole = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final users = await _adminService.getAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _applyFilters() {
    var list = _users;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) =>
          u.displayName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (u.companyName?.toLowerCase().contains(q) ?? false)).toList();
    }

    if (_filterRole != 'all') {
      list = list.where((u) => u.roles.contains(_filterRole)).toList();
    }

    setState(() => _filteredUsers = list);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;
    final card = theme.cardColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Utilisateurs', style: TextStyle(color: text, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          IconButton(icon: Icon(Icons.download, color: text), onPressed: _exportCsv),
          IconButton(icon: Icon(Icons.add, color: text), onPressed: () => context.push('/admin/add-subscription')),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: text),
            onSelected: (value) {
              _filterRole = value;
              _applyFilters();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('Tous')),
              PopupMenuItem(value: 'user', child: Text('Utilisateurs')),
              PopupMenuItem(value: 'admin', child: Text('Administrateurs')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (v) {
                _searchQuery = v;
                _applyFilters();
              },
              style: TextStyle(color: text),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, email ou entreprise...',
                hintStyle: TextStyle(color: sub, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: sub),
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredUsers.isEmpty
              ? _emptyState(text, sub, primary)
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) => _userTile(_filteredUsers[index], isDark, text, sub, card, primary),
                  ),
                ),
    );
  }

  Widget _userTile(AppUser user, bool isDark, Color text, Color sub, Color card, Color primary) {
    return Card(
      color: card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey[850]! : Colors.grey[200]!, width: 0.5),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isAdmin ? Colors.purple.withOpacity(0.1) : primary.withOpacity(0.1),
          child: Text(
            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
            style: TextStyle(fontWeight: FontWeight.bold, color: user.isAdmin ? Colors.purple : primary),
          ),
        ),
        title: Row(
          children: [
            Text(user.displayName, style: TextStyle(fontWeight: FontWeight.w600, color: text)),
            if (user.isAdmin) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: const Text('ADMIN', style: TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.bold)),
              ),
            ]
          ],
        ),
        subtitle: Text(user.email, style: TextStyle(fontSize: 12, color: sub)),
        trailing: Icon(Icons.circle, size: 10, color: user.isActive ? Colors.green : Colors.redAccent),
        onTap: () => context.push('/admin/users/${user.id}'),
      ),
    );
  }

  Widget _emptyState(Color text, Color sub, Color primary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 64, color: sub.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('Aucun résultat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: text)),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    try {
      final file = await _adminService.exportUsersCsvToFile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export réussi : ${file.path.split('/').last}'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur export: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}