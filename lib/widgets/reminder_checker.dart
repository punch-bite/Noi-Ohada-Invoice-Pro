// lib/widgets/reminder_checker.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/reminder_service.dart';

class ReminderChecker extends StatefulWidget {
  final Widget child;

  const ReminderChecker({super.key, required this.child});

  @override
  State<ReminderChecker> createState() => _ReminderCheckerState();
}

class _ReminderCheckerState extends State<ReminderChecker> {
  @override
  void initState() {
    super.initState();
    _checkReminders();
    
    // Vérifier toutes les 6 heures
    Future.delayed(const Duration(hours: 6), () {
      if (mounted) _checkReminders();
    });
  }

  Future<void> _checkReminders() async {
    try {
      final reminderService = context.read<ReminderService>();
      await reminderService.checkAndSendReminders();
    } catch (e) {
      print('❌ Erreur vérification rappels: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}