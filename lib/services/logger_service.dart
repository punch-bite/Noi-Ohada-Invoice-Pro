// lib/services/logger_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../services/admin_service.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LoggerService {
  static const String _logBox = 'app_logs';
  static Box? _box;

  static String? _currentUserId;
  static String? _currentUserEmail;
  static bool _remoteLoggingEnabled = true;
  static LogLevel _minLogLevel = LogLevel.debug; // Par défaut, tout est logué

  static final AdminService _adminService = AdminService();

  // ===== INITIALISATION =====

  static Future<void> init() async {
    _box = await Hive.openBox(_logBox);
    print('✅ LoggerService initialisé');
  }

  // ===== CONFIGURATION =====

  static void setUserContext({required String userId, required String userEmail}) {
    _currentUserId = userId;
    _currentUserEmail = userEmail;
  }

  static void setMinLogLevel(LogLevel level) {
    _minLogLevel = level;
  }

  static void enableRemoteLogging(bool enabled) {
    _remoteLoggingEnabled = enabled;
  }

  // ===== MÉTHODE PRINCIPALE DE LOG =====

  static Future<void> log({
    required String action,
    String? details,
    LogLevel level = LogLevel.info,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? extra,
  }) async {
    // Vérifier si le niveau est suffisant
    if (_shouldSkipLog(level)) return;

    final timestamp = DateTime.now();
    final logEntry = {
      'id': timestamp.millisecondsSinceEpoch.toString(),
      'action': action,
      'details': details ?? '',
      'level': level.name,
      'timestamp': timestamp.toIso8601String(),
      'userId': _currentUserId ?? '',
      'userEmail': _currentUserEmail ?? '',
      'targetId': targetId,
      'targetType': targetType,
      'extra': extra ?? {},
    };

    // 1. Log local
    await _saveLocalLog(logEntry);

    // 2. Log distant (Firestore)
    if (_remoteLoggingEnabled && _currentUserId != null && _currentUserEmail != null) {
      await _saveRemoteLog(logEntry);
    }

    // 3. Affichage console en développement
    if (LogLevel.debug == level) {
      print('📝 [${level.name.toUpperCase()}] $action : ${details ?? ''}');
    }
  }

  // ===== LOGS LOCAUX =====

  static Future<void> _saveLocalLog(Map<String, dynamic> logEntry) async {
    try {
      final logs = await getLocalLogs();
      logs.insert(0, logEntry);
      if (logs.length > 200) {
        logs.removeRange(200, logs.length);
      }
      await _box?.put('logs', logs);
    } catch (e) {
      print('❌ Erreur sauvegarde log local: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getLocalLogs() async {
    final logs = _box?.get('logs', defaultValue: []) as List? ?? [];
    return logs.cast<Map<String, dynamic>>();
  }

  static Future<void> clearLocalLogs() async {
    await _box?.put('logs', []);
  }

  // ===== LOGS DISTANTS =====

  static Future<void> _saveRemoteLog(Map<String, dynamic> logEntry) async {
    try {
      await _adminService.logActivity(
        userId: _currentUserId!,
        userEmail: _currentUserEmail!,
        action: logEntry['action'],
        targetId: logEntry['targetId'],
        targetType: logEntry['targetType'],
        details: {
          'details': logEntry['details'],
          'level': logEntry['level'],
          'extra': logEntry['extra'],
        },
      );
    } catch (e) {
      print('❌ Erreur sauvegarde log distant: $e');
    }
  }

  // ===== UTILITAIRES =====

  static bool _shouldSkipLog(LogLevel level) {
    const levels = LogLevel.values;
    final minIndex = levels.indexOf(_minLogLevel);
    final currentIndex = levels.indexOf(level);
    return currentIndex < minIndex;
  }

  // ===== MÉTHODES RACCOURCIS =====

  static Future<void> debug(String action, {String? details, String? targetId, String? targetType}) {
    return log(action: action, details: details, level: LogLevel.debug, targetId: targetId, targetType: targetType);
  }

  static Future<void> info(String action, {String? details, String? targetId, String? targetType}) {
    return log(action: action, details: details, level: LogLevel.info, targetId: targetId, targetType: targetType);
  }

  static Future<void> warning(String action, {String? details, String? targetId, String? targetType}) {
    return log(action: action, details: details, level: LogLevel.warning, targetId: targetId, targetType: targetType);
  }

  static Future<void> error(String action, {String? details, String? targetId, String? targetType}) {
    return log(action: action, details: details, level: LogLevel.error, targetId: targetId, targetType: targetType);
  }

  // ===== RÉCUPÉRATION DES LOGS FILTRÉS =====

  static Future<List<Map<String, dynamic>>> getFilteredLogs({
    String? userId,
    String? action,
    LogLevel? level,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    var logs = await getLocalLogs();

    if (userId != null) {
      logs = logs.where((l) => l['userId'] == userId).toList();
    }
    if (action != null) {
      logs = logs.where((l) => l['action'] == action).toList();
    }
    if (level != null) {
      logs = logs.where((l) => l['level'] == level.name).toList();
    }
    if (from != null) {
      logs = logs.where((l) => DateTime.parse(l['timestamp']).isAfter(from)).toList();
    }
    if (to != null) {
      logs = logs.where((l) => DateTime.parse(l['timestamp']).isBefore(to)).toList();
    }

    return logs.take(limit).toList();
  }
}