// lib/screens/admin/users_list_screen.dart
//
// 👥 Liste utilisateurs — épuré : recherche inline, chips rôle, tuiles animées.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final users = await _adminService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _applyFilters() {
    var list = _users;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((u) =>
              u.displayName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              (u.companyName?.toLowerCase().contains(q) ?? false))
          .toList();
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
          onPressed: () => context.go('/admin'),
        ),
        title: Text(
          'Utilisateurs',
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.w700,
            fontSize: 19,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: text, size: 22),
            tooltip: 'Ajouter un abonnement',
            onPressed: () => context.push('/admin/add-subscription'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher nom, email, entreprise…',
                  hintStyle: TextStyle(
                      color: sub.withValues(alpha: 0.7), fontSize: 13.5),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: sub, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: sub, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _searchQuery = '';
                            _applyFilters();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (v) {
                  _searchQuery = v;
                  _applyFilters();
                },
              ),
            ),
          ),

          // Filtres chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _chip('all', 'Tous', primary, text, isDark, card),
                const SizedBox(width: 8),
                _chip('user', 'Utilisateurs', primary, text, isDark, card),
                const SizedBox(width: 8),
                _chip('admin', 'Admins', primary, text, isDark, card),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primary))
                : _filteredUsers.isEmpty
                    ? _emptyState(text, sub)
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        color: primary,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (_, i) => _userTile(
                            _filteredUsers[i],
                            isDark,
                            text,
                            sub,
                            card,
                            primary,
                            index: i,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String value, String label, Color primary, Color text,
      bool isDark, Color card) {
    final selected = _filterRole == value;
    return GestureDetector(
      onTap: () {
        _filterRole = value;
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? primary : card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? primary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : text,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _userTile(
    AppUser user,
    bool isDark,
    Color text,
    Color sub,
    Color card,
    Color primary, {
    required int index,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/admin/users/${user.id}'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: user.isAdmin
                            ? const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.14)
                            : primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: user.isAdmin
                                ? const Color(0xFF8B5CF6)
                                : primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: text,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (user.isAdmin) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6)
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ADMIN',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      color: Color(0xFF8B5CF6),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: sub),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: user.isActive
                            ? const Color(0xFF10B981)
                            : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded,
                        color: sub.withValues(alpha: 0.5), size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(
            delay: Duration(milliseconds: 30 + (index * 30)),
            duration: 300.ms,
          )
          .slideY(
            begin: 0.05,
            end: 0,
            duration: 300.ms,
            curve: Curves.easeOut,
          ),
    );
  }

  Widget _emptyState(Color text, Color sub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded,
                size: 52, color: sub.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Aucun utilisateur',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ajustez votre recherche ou vos filtres.',
              style: TextStyle(fontSize: 12.5, color: sub),
            ),
          ],
        ),
      ),
    );
  }
}