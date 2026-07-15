// lib/screens/admin/activity_logs_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';
import '../../models/activity_log.dart';

class ActivityLogsScreen extends StatefulWidget {
  final String? userId; // optionnel pour filtrer par utilisateur
  const ActivityLogsScreen({super.key, this.userId});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final AdminService _adminService = AdminService();
  List<ActivityLog> _logs = [];
  bool _isLoading = true;
  String _filterAction = 'all';

  final Map<String, String> _actionLabels = {
    'login': 'Connexion',
    'logout': 'Déconnexion',
    'create_invoice': 'Création facture',
    'update_invoice': 'Modification facture',
    'delete_invoice': 'Suppression facture',
    'create_client': 'Création client',
    'update_client': 'Modification client',
    'delete_client': 'Suppression client',
    'create_user': 'Création utilisateur',
    'update_user': 'Modification utilisateur',
    'delete_user': 'Suppression utilisateur',
    'update_roles': 'Modification rôles',
    'activate_user': 'Activation utilisateur',
    'deactivate_user': 'Désactivation utilisateur',
    'admin_cancel_subscription': 'Annulation abonnement (admin)',
    'admin_extend_subscription': 'Prolongation abonnement (admin)',
    'admin_change_plan': 'Changement de plan (admin)',
  };

  final List<String> _actionKeys = [
    'all',
    'login',
    'logout',
    'create_invoice',
    'update_invoice',
    'delete_invoice',
    'create_client',
    'update_client',
    'delete_client',
    'create_user',
    'update_user',
    'delete_user',
    'update_roles',
    'activate_user',
    'deactivate_user',
    'admin_cancel_subscription',
    'admin_extend_subscription',
    'admin_change_plan',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    _logs = await _adminService.getActivityLogs(
      userId: widget.userId,
      limit: 200,
    );
    setState(() => _isLoading = false);
  }

  List<ActivityLog> get _filteredLogs {
    if (_filterAction == 'all') return _logs;
    return _logs.where((l) => l.action == _filterAction).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;
    final card = theme.cardColor;
    final primary = theme.primaryColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(widget.userId != null ? 'Logs de l\'utilisateur' : 'Logs d\'activité'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: text),
            onPressed: _loadLogs,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: text),
            onSelected: (value) => setState(() => _filterAction = value),
            itemBuilder: (context) => _actionKeys.map((key) {
              final label = key == 'all' ? 'Toutes les actions' : _actionLabels[key] ?? key;
              return PopupMenuItem(value: key, child: Text(label));
            }).toList(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? _emptyState(isDark, text, sub, primary)
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = _filteredLogs[index];
                    return _logTile(log, isDark, text, sub, card);
                  },
                ),
    );
  }

  Widget _logTile(ActivityLog log, bool isDark, Color text, Color sub, Color card) {
    final actionLabel = _actionLabels[log.action] ?? log.action;

    return Card(
      color: card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[100]!, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _getIconForAction(log.action),
              size: 20,
              color: _getColorForAction(log.action),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actionLabel,
                    style: TextStyle(fontWeight: FontWeight.w500, color: text),
                  ),
                  Text(
                    'Utilisateur : ${log.userEmail}',
                    style: TextStyle(fontSize: 12, color: sub),
                  ),
                  if (log.details != null) ...[
                    Text(
                      'Détails : ${log.details.toString()}',
                      style: TextStyle(fontSize: 11, color: sub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Text(
              DateFormat('dd/MM HH:mm').format(log.timestamp),
              style: TextStyle(fontSize: 11, color: sub),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForAction(String action) {
    if (action.startsWith('login')) return Icons.login;
    if (action.startsWith('logout')) return Icons.logout;
    if (action.contains('invoice')) return Icons.receipt;
    if (action.contains('client')) return Icons.person;
    if (action.contains('user')) return Icons.people;
    if (action.contains('subscription')) return Icons.subscriptions;
    return Icons.info;
  }

  Color _getColorForAction(String action) {
    if (action.startsWith('login')) return Colors.blue;
    if (action.startsWith('logout')) return Colors.orange;
    if (action.contains('invoice')) return Colors.purple;
    if (action.contains('client')) return Colors.green;
    if (action.contains('user')) return Colors.teal;
    if (action.contains('subscription')) return Colors.indigo;
    return Colors.grey;
  }

  Widget _emptyState(bool isDark, Color text, Color sub, Color primary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: sub),
          const SizedBox(height: 16),
          Text('Aucun log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: text)),
          const SizedBox(height: 8),
          Text('Les activités seront enregistrées ici', style: TextStyle(fontSize: 14, color: sub)),
        ],
      ),
    );
  }
}