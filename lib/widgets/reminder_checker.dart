// lib/widgets/reminder_checker.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Vérification immédiate
    _checkReminders();
    
    // Vérification toutes les 6 heures (Timer périodique)
    _timer = Timer.periodic(const Duration(hours: 6), (_) {
      if (mounted) _checkReminders();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkReminders() async {
    try {
      final reminderService = context.read<ReminderService>();
      await reminderService.checkAndSendReminders();
    } catch (e) {
      // Silencieux pour ne pas polluer la console en production
      if (kDebugMode) {
        print('❌ Erreur vérification rappels: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}