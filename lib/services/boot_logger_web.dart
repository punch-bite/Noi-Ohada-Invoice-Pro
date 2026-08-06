// lib/services/boot_logger_web.dart
// Implémentation WEB : pas de système de fichiers, log console uniquement.
//
import 'package:flutter/foundation.dart';

Future<void> writeBootLog(String message) async {
  debugPrint('[boot] $message');
}
