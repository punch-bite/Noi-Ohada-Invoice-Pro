// lib/screens/dashboard/reminders_screen.dart
//
// 🔔 Écran des rappels de paiement.
// 🎨 Refonte moderne : hero card, filtres en chips, cards épurées,
// timeline visuelle, empty state illustré.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/reminder_service.dart';
import '../../models/reminder.dart';
import '../../providers/theme_provider.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final ReminderService _reminderService = ReminderService();
  List<Reminder> _reminders = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _reminderService.init();
      final loadedReminders = await _reminderService.getReminders();
      if (mounted) {
        setState(() {
          _reminders = loadedReminders;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la récupération des rappels : $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Reminder> get _filteredReminders {
    if (_filter == 'all') return _reminders;
    return _reminders.where((r) => r.status == _filter).toList();
  }

  int _countFor(String status) {
    if (status == 'all') return _reminders.length;
    return _reminders.where((r) => r.status == status).length;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final bgColor = themeProvider.backgroundColor;
    final primaryColor = themeProvider.primaryColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: textColor, size: 20),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          'Rappels de paiement',
          style: TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textColor, size: 22),
            onPressed: _loadReminders,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : Column(
              children: [
                // ── Hero header avec compteurs ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _buildHeroStats(themeProvider, isDark),
                ),

                // ── Filtres en chips horizontales ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildFilterChips(themeProvider, isDark),
                ),

                const SizedBox(height: 16),

                // ── Liste ──
                Expanded(
                  child: _filteredReminders.isEmpty
                      ? _buildEmptyState(
                          isDark, textColor, subTextColor, primaryColor)
                      : RefreshIndicator(
                          onRefresh: _loadReminders,
                          color: primaryColor,
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _filteredReminders.length,
                            itemBuilder: (context, index) {
                              final reminder = _filteredReminders[index];
                              return _buildReminderCard(
                                reminder,
                                isDark,
                                textColor,
                                subTextColor,
                                themeProvider.cardColor,
                                primaryColor,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  // ============================================================
  //  Hero stats (compteurs par statut)
  // ============================================================
  Widget _buildHeroStats(ThemeProvider theme, bool isDark) {
    final primary = theme.primaryColor;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  primary.withValues(alpha: 0.18),
                  primary.withValues(alpha: 0.06),
                ]
              : [
                  primary.withValues(alpha: 0.10),
                  primary.withValues(alpha: 0.02),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _heroStatItem(
            icon: Icons.notifications_active_rounded,
            label: 'Total',
            value: '${_countFor('all')}',
            color: primary,
            theme: theme,
          ),
          _heroDivider(theme),
          _heroStatItem(
            icon: Icons.schedule_rounded,
            label: 'En attente',
            value: '${_countFor('pending')}',
            color: const Color(0xFFF59E0B),
            theme: theme,
          ),
          _heroDivider(theme),
          _heroStatItem(
            icon: Icons.check_circle_rounded,
            label: 'Envoyés',
            value: '${_countFor('sent')}',
            color: const Color(0xFF10B981),
            theme: theme,
          ),
          _heroDivider(theme),
          _heroStatItem(
            icon: Icons.error_outline_rounded,
            label: 'Échoués',
            value: '${_countFor('failed')}',
            color: const Color(0xFFEF4444),
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _heroStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeProvider theme,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: theme.subTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider(ThemeProvider theme) {
    return Container(
      width: 1,
      height: 40,
      color: theme.dividerColor.withValues(alpha: 0.5),
    );
  }

  // ============================================================
  //  Filtres chips
  // ============================================================
  Widget _buildFilterChips(ThemeProvider theme, bool isDark) {
    final filters = [
      ('all', 'Tous', Icons.apps_rounded),
      ('pending', 'En attente', Icons.schedule_rounded),
      ('sent', 'Envoyés', Icons.check_circle_outline_rounded),
      ('failed', 'Échoués', Icons.error_outline_rounded),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (value, label, icon) = filters[i];
          final isSel = _filter == value;
          return GestureDetector(
            onTap: () => setState(() => _filter = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSel
                    ? theme.primaryColor
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSel
                      ? theme.primaryColor
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06)),
                  width: 1,
                ),
                boxShadow: isSel
                    ? [
                        BoxShadow(
                          color: theme.primaryColor.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSel ? Colors.white : theme.subTextColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                      color: isSel ? Colors.white : theme.textColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  //  Carte de rappel moderne
  // ============================================================
  Widget _buildReminderCard(
    Reminder reminder,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color primaryColor,
  ) {
    final formattedDueDate = DateFormat('dd/MM/yyyy').format(reminder.dueDate);
    final formattedReminderDate =
        DateFormat('dd/MM/yyyy').format(reminder.reminderDate);
    final statusColor = reminder.statusColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              if (reminder.invoiceId.isNotEmpty) {
                context.push('/dashboard/invoices/${reminder.invoiceId}');
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header : badges + montant ──
                  Row(
                    children: [
                      _statusBadge(
                        label: reminder.statusLabel,
                        color: statusColor,
                        icon: _statusIcon(reminder.status),
                      ),
                      const SizedBox(width: 6),
                      _typeBadge(reminder.typeLabel, primaryColor),
                      const Spacer(),
                      Text(
                        '${reminder.amount.toStringAsFixed(0)} FCFA',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Facture + client ──
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          size: 20,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Facture ${reminder.invoiceNumber}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Client : ${reminder.clientName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: subTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Dates ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _dateItem(
                            Icons.calendar_today_rounded,
                            'Échéance',
                            formattedDueDate,
                            subTextColor,
                            textColor,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                        Expanded(
                          child: _dateItem(
                            Icons.alarm_rounded,
                            'Rappel',
                            formattedReminderDate,
                            subTextColor,
                            textColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Erreur éventuelle ──
                  if (reminder.errorMessage != null &&
                      reminder.errorMessage!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reminder.errorMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.redAccent,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String label, Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync_rounded, size: 10, color: primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: primary,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateItem(
    IconData icon,
    String label,
    String value,
    Color subColor,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 11, color: subColor.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: subColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'sent':
        return Icons.check_circle_rounded;
      case 'failed':
        return Icons.error_outline_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  // ============================================================
  //  Empty state illustré
  // ============================================================
  Widget _buildEmptyState(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor.withValues(alpha: 0.18),
                    primaryColor.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 42,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun rappel',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les rappels de paiement programmés\ns\'afficheront ici',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: subTextColor,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    'Configurez vos relances automatiques',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}