// lib/screens/dashboard/data_export_screen.dart
//
// 📤 Écran d'export des données : clients, stock (produits & mouvements),
// factures, fournisseurs et statistiques — formats JSON et CSV.
// Fichiers écrits dans Documents/exports puis partagés via la feuille
// de partage native (email, WhatsApp, Drive, …).
//
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/data_export_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/glass_widgets.dart';

class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  final DataExportService _exportService = DataExportService();

  /// ✅ Toutes les sections cochées par défaut.
  final Set<ExportSection> _sections = ExportSection.values.toSet();

  bool _busy = false;

  Future<void> _runExport({required bool asJson}) async {
    if (_sections.isEmpty) {
      _toast('Sélectionnez au moins une section',
          backgroundColor: Colors.orange);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final result = asJson
          ? await _exportService.exportToJson(_sections)
          : await _exportService.exportToCsv(_sections);
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Export réussi — ${result.summary}')),
          ]),
          backgroundColor: ThemeService.primaryLight,
          duration: const Duration(seconds: 3),
        ),
      );
      await _exportService.shareFiles(
        result.files,
        subject: 'Export de données — NOI OHADA Invoice Pro',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text("Échec de l'export : $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _toast(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: const Text('Exporter mes données',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choisissez les données à exporter, puis générez un fichier '
              'JSON (sauvegarde complète) ou CSV (Excel).',
              style: TextStyle(
                  fontSize: 13, color: onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            _glassCard(
              cardColor,
              isDark,
              Column(
                children: [
                  for (final s in ExportSection.values)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(s.label,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      value: _sections.contains(s),
                      activeColor: ThemeService.primaryLight,
                      onChanged: (checked) => setState(() {
                        checked == true
                            ? _sections.add(s)
                            : _sections.remove(s);
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _exportButton(
              label: 'EXPORTER EN JSON (SAUVEGARDE COMPLÈTE)',
              icon: Icons.data_object_rounded,
              onPressed: _busy ? null : () => _runExport(asJson: true),
            ),
            const SizedBox(height: 12),
            _exportButton(
              label: 'EXPORTER EN CSV (EXCEL)',
              icon: Icons.table_view_rounded,
              onPressed: _busy ? null : () => _runExport(asJson: false),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_rounded,
                    size: 14, color: onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Les fichiers sont enregistrés dans Documents/exports '
                    'puis ouverts dans la feuille de partage.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: onSurface.withValues(alpha: 0.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeService.primaryLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 18),
        label: Text(_busy ? 'GÉNÉRATION...' : label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _glassCard(Color cardColor, bool isDark, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12, width: 1),
      ),
      child: child,
    );
  }
}

