// lib/screens/admin/admin_dashboard.dart
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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final stats = await _adminService.getUsersStats();

      if (mounted) {
        setState(() {
          _stats = stats.map((key, value) => MapEntry(key, value as int));
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur lors du chargement des statistiques : $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de charger les statistiques : $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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
          style: TextStyle(
            color: text,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Première ligne : 3 cartes (Total, Actifs, Inactifs)
                    Row(
                      children: [
                        _statCard(
                            'Total',
                            _stats['total'] ?? 0,
                            Icons.people_rounded,
                            Colors.blue,
                            isDark,
                            card,
                            text),
                        const SizedBox(width: 8),
                        _statCard(
                            'Actifs',
                            _stats['active'] ?? 0,
                            Icons.check_circle_rounded,
                            Colors.green,
                            isDark,
                            card,
                            text),
                        const SizedBox(width: 8),
                        _statCard(
                            'Inactifs',
                            _stats['inactive'] ?? 0,
                            Icons.block_rounded,
                            Colors.redAccent,
                            isDark,
                            card,
                            text),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Deuxième ligne : 2 cartes (Admins, Utilisateurs)
                    Row(
                      children: [
                        _statCard(
                            'Admins',
                            _stats['admins'] ?? 0,
                            Icons.admin_panel_settings_rounded,
                            Colors.purple,
                            isDark,
                            card,
                            text),
                        const SizedBox(width: 8),
                        _statCard(
                            'Utilisateurs',
                            _stats['users'] ?? 0,
                            Icons.person_rounded,
                            Colors.orange,
                            isDark,
                            card,
                            text),
                      ],
                    ),
                    const SizedBox(height: 32),

                    Text(
                      'Actions rapides d\'administration',
                      style: TextStyle(
                        color: text,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bouton gestion utilisateurs
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/admin/users'),
                        icon: const Icon(Icons.people_alt_rounded, size: 20),
                        label: const Text(
                          'Gérer les utilisateurs',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Bouton consultation des logs
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/admin/logs'),
                        icon: const Icon(Icons.history_toggle_off_rounded,
                            size: 20),
                        label: const Text(
                          'Consulter les logs d\'activité',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? Colors.grey[850] : Colors.grey[200],
                          foregroundColor:
                              isDark ? Colors.grey[200] : Colors.grey[800],
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.grey[800]!
                                  : Colors.grey[300]!,
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/admin/plans/create'),
                        icon: const Icon(Icons.add),
                        label: const Text('Créer un plan personnalisé'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
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
                        onPressed: () => context.push('/admin/assign-plan'),
                        icon: const Icon(Icons.assignment_ind),
                        label: const Text('Affecter un plan à un utilisateur'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
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

  Widget _statCard(
    String label,
    int count,
    IconData icon,
    Color color,
    bool isDark,
    Color card,
    Color text,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
