// lib/services/update_service.dart
//
// 🚀 MISE À JOUR DE L'APPLICATION
//
// Vérifie la version publiée côté SERVEUR (GET /app/version → variable
// APP_LATEST_VERSION sur Vercel) et la compare à la version réellement
// installée (package_info_plus). Si une version plus récente existe, on
// propose le téléchargement (lien serveur /download → APP_UPDATE_URL).
//
// Utilisé par :
//   • Réglages → « Vérifier les mises à jour »   (manuel)
//   • Dashboard → détection automatique au démarrage (1× / session)
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config_service.dart';

/// Dernière version publiée, renvoyée par `GET /app/version`.
class AppUpdateInfo {
  final String version; // ex. "1.2.3" — vide si non configuré côté serveur
  final String downloadUrl;
  final String notes;
  final String updatedAt;

  const AppUpdateInfo({
    this.version = '',
    this.downloadUrl = '',
    this.notes = '',
    this.updatedAt = '',
  });

  /// Vrai si le serveur a bien renseigné une version à comparer.
  bool get isConfigured => version.trim().isNotEmpty;
}

class UpdateService {
  UpdateService._(); // classe utilitaire (statique)

  static const Duration _timeout = Duration(seconds: 8);

  /// ⏱️ Garde-fou : on ne propose la mise à jour automatiquement qu'UNE
  /// fois par session (l'utilisateur a dit « Plus tard » → pas de harcèlement).
  static bool _autoPrompted = false;

  static bool get hasAutoPrompted => _autoPrompted;

  // ===== VERSION INSTALLÉE =====

  /// Version réellement installée (versionName Android, ex. "1.0.0").
  /// Repli sur ConfigService.appVersion si le plugin est indisponible (tests).
  static Future<String> installedVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version.trim();
      if (v.isNotEmpty) return v;
    } catch (_) {
      /* plugin indispo (tests / web sans manifest) */
    }
    final fallback = ConfigService.appVersion.trim();
    return fallback.isEmpty ? '0.0.0' : fallback;
  }

  // ===== VERSION DISTANTE =====

  /// Interroge `GET /app/version` sur le serveur. Ne lève JAMAIS : en cas
  /// d'échec réseau ou de réponse invalide, renvoie une info « non
  /// configurée » (version vide) → l'app ne harcèle pas.
  static Future<AppUpdateInfo> fetchLatest() async {
    final base = ConfigService.apiBaseUrl.trim();
    if (base.isEmpty) return const AppUpdateInfo();
    try {
      final resp = await http
          .get(Uri.parse('$base/app/version'))
          .timeout(_timeout);
      if (resp.statusCode != 200) return const AppUpdateInfo();
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return AppUpdateInfo(
        version: (data['version'] as String? ?? '').trim(),
        downloadUrl: (data['downloadUrl'] as String? ?? '$base/download').trim(),
        notes: (data['notes'] as String? ?? '').trim(),
        updatedAt: (data['updatedAt'] as String? ?? '').trim(),
      );
    } catch (e) {
      debugPrint('⚠️ UpdateService: vérification impossible ($e)');
      return const AppUpdateInfo();
    }
  }

  // ===== COMPARAISON (sémantique x.y.z) =====

  /// `true` si la version [latest] est STRICTEMENT plus récente que [current].
  /// Robuste aux préfixes (v1.2, 1.2.3-beta… on compare les nombres).
  static bool isNewer(String latest, String current) {
    final l = _numericParts(latest);
    final c = _numericParts(current);
    for (var i = 0; i < 3; i++) {
      final a = l[i];
      final b = c[i];
      if (a != b) return a > b;
    }
    return false;
  }

  static List<int> _numericParts(String v) {
    final parts = <int>[];
    for (final m in RegExp(r'\d+').allMatches(v)) {
      parts.add(int.tryParse(m.group(0)!) ?? 0);
      if (parts.length >= 3) break;
    }
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  // ===== OUVERTURE DU LIEN DE TÉLÉCHARGEMENT =====

  static Future<void> openDownload(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) debugPrint('⚠️ UpdateService: impossible d\'ouvrir $url');
    } catch (e) {
      debugPrint('⚠️ UpdateService: erreur d\'ouverture ($e)');
    }
  }

  // ===== VÉRIFICATION + DIALOGUES =====

  /// Vérifie la disponibilité d'une mise à jour et réagit :
  ///   • [manual] = true (Réglages) : affiche TOUJOURS un retour (à jour OU
  ///     nouvelle version OU impossible de vérifier).
  ///   • [manual] = false (démarrage) : n'affiche la nouvelle version qu'une
  ///     fois par session, et seulement si elle existe (jamais de bruit).
  static Future<void> checkAndPrompt(
    BuildContext context, {
    bool manual = false,
  }) async {
    final latest = await fetchLatest();
    if (!context.mounted) return;
    final current = await installedVersion();
    if (!context.mounted) return;

    final available = latest.isConfigured && isNewer(latest.version, current);
    if (available) {
      _autoPrompted = true;
      _showUpdateDialog(context, latest, current);
      return;
    }

    if (manual) {
      if (latest.isConfigured) {
        _showUpToDateDialog(context, current);
      } else {
        _showCheckFailed(context);
      }
    }
  }

  // ---- Nouvelle version disponible ----
  static void _showUpdateDialog(
    BuildContext context,
    AppUpdateInfo info,
    String current,
  ) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: scheme.surface,
        icon: Icon(Icons.system_update_alt, size: 44, color: scheme.primary),
        title: Text(
          'Nouvelle version disponible',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Version $current → ${info.version}',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurface),
              ),
              if (info.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    info.notes,
                    style: TextStyle(color: scheme.onSurface, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Une mise à jour améliore l\'application et sa sécurité.\n'
                'Vous pouvez la télécharger maintenant.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: scheme.primary),
            onPressed: () {
              Navigator.pop(ctx);
              openDownload(info.downloadUrl.isNotEmpty
                  ? info.downloadUrl
                  : '${ConfigService.apiBaseUrl.trim()}/download');
            },
            icon: const Icon(Icons.download),
            label: const Text('Télécharger'),
          ),
        ],
      ),
    );
  }

  // ---- Déjà à jour ----
  static void _showUpToDateDialog(BuildContext context, String current) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: scheme.surface,
        icon: Icon(Icons.check_circle_outline, size: 44, color: Colors.green),
        title: Text(
          'Application à jour',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Vous utilisez la dernière version disponible (v$current).',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.primary),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---- Impossible de vérifier ----
  static void _showCheckFailed(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Impossible de vérifier les mises à jour (serveur injoignable).',
        ),
        backgroundColor: scheme.error,
      ),
    );
  }
}
