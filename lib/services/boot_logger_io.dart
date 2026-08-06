// lib/services/boot_logger_io.dart
// Implémentation NATIVE (mobile/desktop) : écriture dans un fichier.
//
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> writeBootLog(String message) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/app_log.txt');
    await file.writeAsString('${DateTime.now()}: $message\n',
        mode: FileMode.append);
  } catch (_) {}
}
