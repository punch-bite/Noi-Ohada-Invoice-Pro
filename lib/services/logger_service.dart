import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/admin_service.dart';

enum LogLevel { debug, info, warning, error }

class LoggerService {
  static const String _logBox = 'app_logs';
  static Box? _box;

  static String? _currentUserId;
  static String? _currentUserEmail;
  static bool _remoteLoggingEnabled = true;
  static LogLevel _minLogLevel = LogLevel.debug;

  static final AdminService _adminService = AdminService();

  // Initialisation du service
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_logBox)) {
      _box = await Hive.openBox(_logBox);
    } else {
      _box = Hive.box(_logBox);
    }
    debugPrint('✅ LoggerService initialisé');
  }

  // Configuration contextuelle
  static void setUserContext({required String userId, required String userEmail}) {
    _currentUserId = userId;
    _currentUserEmail = userEmail;
  }

  static void setMinLogLevel(LogLevel level) => _minLogLevel = level;

  static void enableRemoteLogging(bool enabled) => _remoteLoggingEnabled = enabled;

  // Méthode principale de log
  static Future<void> log({
    required String action,
    String? details,
    LogLevel level = LogLevel.info,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? extra,
  }) async {
    if (_shouldSkipLog(level)) return;

    final logEntry = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'action': action,
      'details': details ?? '',
      'level': level.name,
      'timestamp': DateTime.now().toIso8601String(),
      'userId': _currentUserId ?? '',
      'userEmail': _currentUserEmail ?? '',
      'targetId': targetId,
      'targetType': targetType,
      'extra': extra ?? {},
    };

    // Exécution asynchrone sans bloquer le flux principal
    await Future.wait([
      _saveLocalLog(logEntry),
      if (_remoteLoggingEnabled && _currentUserId != null) _saveRemoteLog(logEntry),
    ]);

    if (kDebugMode) {
      debugPrint('📝 [${level.name.toUpperCase()}] $action : ${details ?? ''}');
    }
  }

  // Stockage local optimisé (Buffer circulaire 200 entrées)
  static Future<void> _saveLocalLog(Map<String, dynamic> entry) async {
    final int count = _box?.get('count', defaultValue: 0) ?? 0;
    final int index = count % 200;
    
    await _box?.put('log_$index', entry);
    await _box?.put('count', count + 1);
  }

  // Récupération des logs (du plus récent au plus ancien)
  static Future<List<Map<String, dynamic>>> getLocalLogs() async {
    final int count = _box?.get('count', defaultValue: 0) ?? 0;
    final int limit = count > 200 ? 200 : count;
    final List<Map<String, dynamic>> logs = [];

    for (int i = 0; i < limit; i++) {
      final int index = (count - 1 - i) % 200;
      final entry = _box?.get('log_$index');
      if (entry != null) {
        logs.add(Map<String, dynamic>.from(entry as Map));
      }
    }
    return logs;
  }

  // Envoi vers le service distant (Admin)
  static Future<void> _saveRemoteLog(Map<String, dynamic> log) async {
    try {
      await _adminService.logActivity(
        userId: _currentUserId!,
        userEmail: _currentUserEmail!,
        action: log['action'],
        targetId: log['targetId'],
        targetType: log['targetType'],
        details: {
          'details': log['details'], 
          'level': log['level'], 
          'extra': log['extra']
        }, limit: 200,
      );
    } catch (e) {
      debugPrint('❌ Erreur log distant: $e');
    }
  }

  static bool _shouldSkipLog(LogLevel level) => level.index < _minLogLevel.index;

  // Méthodes raccourcies
  static Future<void> debug(String a, {String? d, String? ti, String? tt}) => log(action: a, details: d, level: LogLevel.debug, targetId: ti, targetType: tt);
  static Future<void> info(String a, {String? d, String? ti, String? tt, required String details, String? targetId, required String targetType}) => log(action: a, details: d, level: LogLevel.info, targetId: ti, targetType: tt);
  static Future<void> warning(String a, {String? d, String? ti, String? tt, required String details}) => log(action: a, details: d, level: LogLevel.warning, targetId: ti, targetType: tt);
  static Future<void> error(String a, {String? d, String? ti, String? tt, required String details}) => log(action: a, details: d, level: LogLevel.error, targetId: ti, targetType: tt);
}