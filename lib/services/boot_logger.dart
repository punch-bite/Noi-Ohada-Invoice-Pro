// lib/services/boot_logger.dart
//
// 📝 Log de démarrage compatible Web + Mobile (conditional import).
// La bonne implémentation (fichier ou debugPrint) est choisie à la compilation.
//
export 'boot_logger_io.dart' if (dart.library.js_interop) 'boot_logger_web.dart';
