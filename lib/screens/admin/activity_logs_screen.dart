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
    setState(() => _isLoading = true);
    final data = await _adminService.getActivityLogs(userId: widget.userId, limit: 200);
    if (mounted) setState(() { _logs = data; _isLoading = false; });
  }

  List<ActivityLog> get _filteredLogs => _filter == 'all' 
      ? _logs 
      : _logs.where((l) => l.action == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('Logs d\'activité'),
        elevation: 0,
        backgroundColor: theme.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchLogs),
          _buildFilterButton(),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _filteredLogs.isEmpty 
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _filteredLogs.length,
              itemBuilder: (_, i) => LogTile(log: _filteredLogs[i]),
            ),
    );
  }

  Widget _buildFilterButton() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list),
      onSelected: (val) => setState(() => _filter = val),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'all', child: Text('Toutes les actions')),
        ...['login', 'create_invoice', 'create_client'].map((a) => 
          PopupMenuItem(value: a, child: Text(a.toUpperCase()))),
      ],
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.history, size: 64, color: Colors.grey),
      const SizedBox(height: 16),
      Text('Aucune activité trouvée', style: TextStyle(color: Colors.grey[600])),
    ]),
  );
}

// Widget séparé pour une meilleure performance
class LogTile extends StatelessWidget {
  final ActivityLog log;
  const LogTile({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: theme.cardColor,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.primaryColor.withOpacity(0.1),
          child: Icon(Icons.info_outline, color: theme.primaryColor, size: 20),
        ),
        title: Text(log.action, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(log.userEmail, style: TextStyle(color: theme.subTextColor)),
        trailing: Text(DateFormat('HH:mm').format(log.timestamp)),
      ),
    );
  }
}