// lib/screens/dashboard/reminders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
    setState(() => _isLoading = true);
    await _reminderService.init();
    _reminders = await _reminderService.getReminders();
    setState(() => _isLoading = false);
  }

  List<Reminder> get _filteredReminders {
    if (_filter == 'all') return _reminders;
    return _reminders.where((r) => r.status == _filter).toList();
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
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          'Rappels de paiement',
          style: TextStyle(color: textColor),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: _loadReminders,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: textColor),
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('Tous')),
              PopupMenuItem(value: 'pending', child: Text('En attente')),
              PopupMenuItem(value: 'sent', child: Text('Envoyés')),
              PopupMenuItem(value: 'failed', child: Text('Échoués')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredReminders.isEmpty
              ? _buildEmptyState(isDark, textColor, subTextColor, primaryColor)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredReminders.length,
                  itemBuilder: (context, index) {
                    final reminder = _filteredReminders[index];
                    return _buildReminderCard(reminder, isDark, textColor, subTextColor, primaryColor);
                  },
                ),
    );
  }

  Widget _buildReminderCard(
    Reminder reminder,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: reminder.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: reminder.statusColor),
                  ),
                  child: Text(
                    reminder.statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: reminder.statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Text(
                    reminder.typeLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${reminder.amount.toStringAsFixed(0)} FCFA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Facture ${reminder.invoiceNumber}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            Text(
              'Client: ${reminder.clientName}',
              style: TextStyle(
                fontSize: 13,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: subTextColor),
                const SizedBox(width: 4),
                Text(
                  'Échéance: ${reminder.dueDate.day}/${reminder.dueDate.month}/${reminder.dueDate.year}',
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
                const SizedBox(width: 16),
                Icon(Icons.alarm, size: 14, color: subTextColor),
                const SizedBox(width: 4),
                Text(
                  'Rappel: ${reminder.reminderDate.day}/${reminder.reminderDate.month}/${reminder.reminderDate.year}',
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
              ],
            ),
            if (reminder.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reminder.errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor, Color subTextColor, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 80, color: primaryColor),
          const SizedBox(height: 16),
          Text(
            'Aucun rappel',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les rappels de paiement apparaîtront ici',
            style: TextStyle(
              fontSize: 14,
              color: subTextColor,
            ),
          ),
        ],
      ),
    );
  }
}