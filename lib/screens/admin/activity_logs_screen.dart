// lib/screens/admin/activity_logs_screen.dart
//
// 📜 Logs d'activité — épuré : recherche inline, filtres chips, tuiles animées.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/activity_log.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';

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
      final data = await _adminService.getActivityLogs(
        userId: widget.userId,
        limit: 200,
      );
      if (!mounted) return;
      setState(() {
        _logs = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la récupération : $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  List<String> get _availableActions {
    final set = <String>{'all'};
    for (final l in _logs) {
      set.add(l.action);
    }
    return set.toList();
  }

  List<ActivityLog> get _filteredLogs =>
      _filter == 'all' ? _logs : _logs.where((l) => l.action == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: text, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/admin'),
        ),
        title: Text(
          'Logs d\'activité',
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.w700,
            fontSize: 19,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: text, size: 22),
            onPressed: _fetchLogs,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Filtres chips
          if (_logs.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _availableActions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final action = _availableActions[i];
                  final selected = _filter == action;
                  final label = action == 'all'
                      ? 'Toutes'
                      : action.replaceAll('_', ' ');
                  return GestureDetector(
                    onTap: () => setState(() => _filter = action),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? primary : theme.cardColor,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? primary
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06)),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected ? Colors.white : text,
                          fontSize: 12.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),

          // Liste
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primary))
                : _filteredLogs.isEmpty
                    ? _buildEmptyState(text, sub, primary)
                    : RefreshIndicator(
                        onRefresh: _fetchLogs,
                        color: primary,
                        child: ListView.builder(
                          physics:
                              const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          itemCount: _filteredLogs.length,
                          itemBuilder: (_, i) => _logTile(
                            _filteredLogs[i],
                            isDark,
                            text,
                            sub,
                            theme.cardColor,
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

  Widget _logTile(
    ActivityLog log,
    bool isDark,
    Color text,
    Color sub,
    Color card,
    Color primary, {
    required int index,
  }) {
    final formattedDate =
        DateFormat('dd/MM/yyyy · HH:mm').format(log.timestamp);

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
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_logIcon(log.action),
                    color: primary, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.action.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: text,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      log.userEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 11, color: sub.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: sub.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(
            delay: Duration(milliseconds: 30 + (index * 20)),
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

  IconData _logIcon(String action) {
    switch (action) {
      case 'login':
        return Icons.login_rounded;
      case 'logout':
        return Icons.logout_rounded;
      case 'create_invoice':
        return Icons.post_add_rounded;
      case 'create_client':
        return Icons.person_add_alt_1_rounded;
      case 'create_product':
        return Icons.inventory_2_rounded;
      case 'create_team':
        return Icons.group_add_rounded;
      case 'delete_invoice':
        return Icons.delete_outline_rounded;
      case 'update_settings':
        return Icons.settings_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Widget _buildEmptyState(Color text, Color sub, Color primary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.history_rounded, size: 40, color: primary),
            ).animate().scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                  duration: 400.ms,
                ),
            const SizedBox(height: 22),
            Text(
              'Aucune activité',
              style: TextStyle(
                color: text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les actions d\'audit s\'afficheront à cet endroit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: sub, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}