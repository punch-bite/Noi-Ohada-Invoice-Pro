// lib/screens/admin/admin_audit_log_screen.dart
//
// 📝 Journal d'audit — vue admin.
//
// Affiche les N derniers logs avec filtres :
//   • Toutes les collections / Une collection
//   • Modifications normales / Écrasements uniquement
//
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/audit_log.dart';
import '../../providers/theme_provider.dart';
import '../../services/audit_log_service.dart';

class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  final AuditLogService _service = AuditLogService();

  String? _filterCollection;
  bool _onlyOwnershipChanges = false;
  bool _loading = true;
  List<AuditLogEntry> _logs = [];

  static const List<(String, String)> _collections = [
    ('clients', 'Clients'),
    ('invoices', 'Factures'),
    ('products', 'Produits'),
    ('suppliers', 'Fournisseurs'),
    ('reminders', 'Rappels'),
    ('companies', 'Entreprises'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await _service.getLogs(
      collection: _filterCollection,
      onlyOwnershipChanges: _onlyOwnershipChanges,
      limit: 200,
    );
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final text = theme.textColor;
    final sub = text.withValues(alpha: 0.55);
    final bg = theme.backgroundColor;
    final primary = theme.primaryColor;

    final ownershipCount = _logs.where((l) => l.ownershipChanged).length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Journal d\'audit',
                style: TextStyle(
                    color: text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3)),
            Text('${_logs.length} événement(s)',
                style: TextStyle(color: sub, fontSize: 11)),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Filtre collection ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _collections.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _chip(
                      label: 'Toutes',
                      selected: _filterCollection == null,
                      primary: primary,
                      text: text,
                      onTap: () {
                        setState(() => _filterCollection = null);
                        _load();
                      },
                    );
                  }
                  final c = _collections[i - 1];
                  return _chip(
                    label: c.$2,
                    selected: _filterCollection == c.$1,
                    primary: primary,
                    text: text,
                    onTap: () {
                      setState(() => _filterCollection = c.$1);
                      _load();
                    },
                  );
                },
              ),
            ),
          ),

          // ── Toggle "écrasements uniquement" ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                Switch(
                  value: _onlyOwnershipChanges,
                  activeThumbColor: const Color(0xFFEF4444),
                  onChanged: (v) {
                    setState(() => _onlyOwnershipChanges = v);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Écrasements de propriétaire uniquement'
                    '${ownershipCount > 0 ? ' ($ownershipCount)' : ''}',
                    style: TextStyle(
                      color: text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Liste ──
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: primary))
                : _logs.isEmpty
                    ? _buildEmpty(sub)
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _logCard(
                          _logs[i],
                          isDark: isDark,
                          text: text,
                          sub: sub,
                        )
                            .animate()
                            .fadeIn(
                              delay:
                                  Duration(milliseconds: 20 + (i * 15)),
                              duration: 220.ms,
                            ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required Color primary,
    required Color text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? primary : text.withValues(alpha: 0.15),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? primary : text.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(Color sub) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: sub.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('Aucun événement',
                style: TextStyle(color: sub, fontSize: 14)),
          ],
        ),
      );

  Widget _logCard(
    AuditLogEntry log, {
    required bool isDark,
    required Color text,
    required Color sub,
  }) {
    final isOverwrite = log.ownershipChanged;
    final accent = isOverwrite ? const Color(0xFFEF4444) : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverwrite
              ? const Color(0xFFEF4444).withValues(alpha: 0.4)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04)),
          width: isOverwrite ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (accent ?? _actionColor(log.action))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  log.actionLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: accent ?? _actionColor(log.action),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${log.collectionLabel} · ${log.docId.substring(0, log.docId.length > 12 ? 12 : log.docId.length)}…',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: text,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _fmtTime(log.timestamp),
                style: TextStyle(fontSize: 10.5, color: sub),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isOverwrite
                ? '🚨 Écrasement : ${_shortUid(log.ownerUidBefore)} → ${_shortUid(log.ownerUidAfter)}'
                : 'Par ${_shortUid(log.actorUid)}',
            style: TextStyle(
              fontSize: 11.5,
              color: accent ?? sub,
              fontWeight: isOverwrite ? FontWeight.w700 : FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'create':
        return const Color(0xFF10B981);
      case 'delete':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String _shortUid(String? uid) {
    if (uid == null || uid.isEmpty) return 'anonyme';
    return uid.length > 8 ? '${uid.substring(0, 8)}…' : uid;
  }

  String _fmtTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inHours < 1) return 'il y a ${diff.inMinutes}min';
    if (diff.inDays < 1) return 'il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
    return '${d.day}/${d.month}/${d.year}';
  }
}