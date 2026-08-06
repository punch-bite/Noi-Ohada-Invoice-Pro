// lib/services/env_loader.dart
//
// Charge le fichier `.env` de manière compatible toutes plateformes :
//  - assets (dotenv.load) si l'asset existe (mobile/desktop)
//  - système de fichiers (desktop) sinon
//  - web : uniquement via asset (ou --dart-define)
//
export 'env_loader_io.dart' if (dart.library.js_interop) 'env_loader_web.dart';
