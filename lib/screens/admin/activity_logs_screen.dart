// lib/screens/admin/activity_logs_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';
import '../../models/activity_log.dart';

class ActivityLogsScreen extends StatefulWidget {
  final String? userId;
  const ActivityLogsScreen({super.key, this.userId});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final AdminService _adminService = AdminService();
  List<ActivityLog> _logs = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await _adminService.getActivityLogs(userId: widget.userId, limit: 200);
      if (mounted) {
        setState(() {
          _logs = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la récupération des logs : $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  List<ActivityLog> get _filteredLogs => _filter == 'all' 
      ? _logs 
      : _logs.where((l) => l.action == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final cardColor = theme.cardColor;
    
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Logs d\'activité',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textColor, size: 22), 
            onPressed: _fetchLogs,
          ),
          _buildFilterButton(textColor),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _filteredLogs.isEmpty 
          ? _buildEmptyState(textColor, subTextColor, theme.primaryColor)
          : RefreshIndicator(
              onRefresh: _fetchLogs,
              color: theme.primaryColor,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _filteredLogs.length,
                itemBuilder: (_, i) => LogTile(
                  log: _filteredLogs[i],
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  cardColor: cardColor,
                  primaryColor: theme.primaryColor,
                ),
              ),
            ),
    );
  }

  Widget _buildFilterButton(Color iconColor) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.filter_list_rounded, color: iconColor, size: 22),
      onSelected: (val) => setState(() => _filter = val),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'all', child: Text('Toutes les actions')),
        ...['login', 'create_invoice', 'create_client'].map(
          (a) => PopupMenuItem(
            value: a, 
            child: Text(a.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(Color textColor, Color subTextColor, Color primaryColor) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_rounded, size: 48, color: primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune activité trouvée', 
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Les actions d\'audit s\'afficheront à cet endroit.', 
            style: TextStyle(color: subTextColor, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// Widget de tuile de log optimisé et découplé du rebuild inutile de context.watch
class LogTile extends StatelessWidget {
  final ActivityLog log;
  final bool isDark;
  final Color textColor;
  final Color subTextColor;
  final Color cardColor;
  final Color primaryColor;

  const LogTile({
    super.key, 
    required this.log,
    required this.isDark,
    required this.textColor,
    required this.subTextColor,
    required this.cardColor,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
          width: 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: primaryColor.withOpacity(0.1),
          child: Icon(
            _getLogIcon(log.action), 
            color: primaryColor, 
            size: 18,
          ),
        ),
        title: Text(
          log.action.replaceAll('_', ' ').toUpperCase(), 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 13,
            color: textColor,
            letterSpacing: 0.3,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            log.userEmail, 
            style: TextStyle(color: subTextColor, fontSize: 12),
          ),
        ),
        trailing: Text(
          formattedDate,
          style: TextStyle(
            color: subTextColor.withOpacity(0.8),
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  IconData _getLogIcon(String action) {
    switch (action) {
      case 'login':
        return Icons.login_rounded;
      case 'create_invoice':
        return Icons.post_add_rounded;
      case 'create_client':
        return Icons.person_add_alt_1_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}