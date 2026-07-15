// lib/screens/admin/users_list_screen.dart
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
    setState(() => _isLoading = true);
    _users = await _adminService.getAllUsers();
    _applyFilters();
    setState(() => _isLoading = false);
  }

  void _applyFilters() {
    var list = _users;

    // Recherche
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((u) =>
              u.displayName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              u.companyName?.toLowerCase().contains(q) == true)
          .toList();
    }

    // Filtre rôle
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
        title: Text(
          'Utilisateurs',
          style: TextStyle(color: text, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: text),
            onPressed: _exportCsv,
          ),
          IconButton(
            icon: Icon(Icons.add, color: text),
            onPressed: () => context.push('/admin/add-subscription'),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: text),
            onSelected: (value) {
              setState(() => _filterRole = value);
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
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _applyFilters();
              },
              style: TextStyle(color: text),
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                hintStyle: TextStyle(color: sub),
                prefixIcon: Icon(Icons.search, color: sub),
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredUsers.isEmpty
              ? _emptyState(isDark, text, sub, primary)
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  color: primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return _userTile(user, isDark, text, sub, card, primary);
                    },
                  ),
                ),
    );
  }

  Widget _userTile(AppUser user, bool isDark, Color text, Color sub, Color card,
      Color primary) {
    final isAdmin = user.isAdmin;

    return Card(
      color: card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[100]!, width: 0.5),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isAdmin
                ? Colors.purple.withOpacity(0.1)
                : primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              user.displayName.isNotEmpty
                  ? user.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isAdmin ? Colors.purple : primary,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              user.displayName,
              style: TextStyle(fontWeight: FontWeight.w500, color: text),
            ),
            if (isAdmin) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Admin',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.purple,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email, style: TextStyle(fontSize: 12, color: sub)),
            if (user.companyName?.isNotEmpty == true)
              Text(user.companyName!,
                  style: TextStyle(fontSize: 11, color: sub)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: user.isActive ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.arrow_forward_ios, size: 16, color: sub),
              onPressed: () => context.push('/admin/users/${user.id}'),
            ),
          ],
        ),
        onTap: () => context.push('/admin/users/${user.id}'),
      ),
    );
  }

  Widget _emptyState(bool isDark, Color text, Color sub, Color primary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: sub),
          const SizedBox(height: 16),
          Text(
            'Aucun utilisateur trouvé',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: text),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Essayez d\'autres critères'
                : 'Aucun utilisateur enregistré',
            style: TextStyle(fontSize: 14, color: sub),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    try {
      final file = await _adminService.exportUsersCsvToFile();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text('Exporté : ${file.path}'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur export: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
