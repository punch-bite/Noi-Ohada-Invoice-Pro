// lib/screens/admin/admin_dashboard.dart
// ignore_for_file: deprecated_member_use, unused_local_variable

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminService _adminService = AdminService();
  Map<String, int> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    _stats = await _adminService.getUserStats();
    setState(() => _isLoading = false);
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
          'Administration',
          style: TextStyle(color: text, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: primary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats
                    Row(
                      children: [
                        _statCard('Total', _stats['total'] ?? 0, Icons.people,
                            Colors.blue, isDark, card, text),
                        const SizedBox(width: 12),
                        _statCard(
                            'Actifs',
                            _stats['active'] ?? 0,
                            Icons.check_circle,
                            Colors.green,
                            isDark,
                            card,
                            text),
                        const SizedBox(width: 12),
                        _statCard('Inactifs', _stats['inactive'] ?? 0,
                            Icons.block, Colors.red, isDark, card, text),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _statCard(
                            'Admins',
                            _stats['admins'] ?? 0,
                            Icons.admin_panel_settings,
                            Colors.purple,
                            isDark,
                            card,
                            text),
                        const SizedBox(width: 12),
                        _statCard('Utilisateurs', _stats['users'] ?? 0,
                            Icons.person, Colors.orange, isDark, card, text),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Bouton gestion utilisateurs
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/admin/users'),
                        icon: const Icon(Icons.people_outline),
                        label: const Text('Gérer les utilisateurs'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/admin/logs'),
                        icon: const Icon(Icons.history),
                        label: const Text('Consulter les logs d\'activité'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(String label, int count, IconData icon, Color color,
      bool isDark, Color card, Color text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
              width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: text),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
