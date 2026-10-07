// lib/screens/admin/admin_templates_screen.dart
//
// CHANGELOG (v2) :
//   • 🐛 FIX MAJEUR : dédoublonnage des presets (getAllTemplates retourne déjà
//     les presets seedés par FirestoreInitializer → plus de doublons).
//   • Distinction visuelle : PRESET (système, lecture seule) vs ADMIN (création).
//   • Badge designVersion : signale les presets obsolètes (< v4).
//   • Badge prix : "GRATUIT" au lieu de "0 XAF".
//   • Trie par catégorie → preset système d'abord, custom ensuite.
//   • Pour les presets système : seul "Personnaliser" est proposé (pas de
//     "Supprimer" — l'admin perdrait les modifications au prochain seed).
//   • Bandeau info si presets obsolètes (invite à forcer la migration).
//
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_template.dart';
import '../../providers/theme_provider.dart';
import '../../services/template_service.dart';
import '../../widgets/template_thumbnail.dart';

class AdminTemplatesScreen extends StatefulWidget {
  const AdminTemplatesScreen({super.key});

  @override
  State<AdminTemplatesScreen> createState() => _AdminTemplatesScreenState();
}

class _AdminTemplatesScreenState extends State<AdminTemplatesScreen> {
  final TemplateService _templateService = TemplateService();
  List<InvoiceTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // ── Source : Firestore (source de vérité SaaS).
      final firestoreTemplates = await _templateService.getAllTemplates();

      // ── Fallback : presets en code si Firestore vide (premier boot).
      final baseList = firestoreTemplates.isEmpty
          ? InvoiceTemplate.getDefaultTemplates()
          : firestoreTemplates;

      // ── Dédoublonnage par id (Firestore peut contenir les presets).
      final byId = <String, InvoiceTemplate>{};
      for (final t in baseList) {
        byId[t.id] = t;
      }

      // ── S'assure que TOUS les presets code sont présents (même si
      //    FirestoreInitializer n'a pas encore tourné).
      for (final preset in InvoiceTemplate.getDefaultTemplates()) {
        byId.putIfAbsent(preset.id, () => preset);
      }

      // ── Tri : presets système (isDefault) d'abord, custom ensuite.
      final list = byId.values.toList()
        ..sort((a, b) {
          if (a.isDefault && !b.isDefault) return -1;
          if (!a.isDefault && b.isDefault) return 1;
          return a.name.compareTo(b.name);
        });

      if (!mounted) return;
      setState(() {
        _templates = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de chargement : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 🗑️ Suppression : UNIQUEMENT pour les modèles custom admin.
  /// Les presets système ne peuvent pas être supprimés (ils seraient
  /// re-seedés au prochain `FirestoreInitializer.initialize()`).
  Future<void> _delete(InvoiceTemplate t) async {
    if (t.isDefault) {
      _toast('Les presets système ne peuvent pas être supprimés.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Supprimer « ${t.name} » ?',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Le modèle sera désactivé. Les factures existantes ne seront pas affectées.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _templateService.deleteTemplate(t.id);
      if (!mounted) return;
      _toast('Modèle supprimé');
      _load();
    } catch (e) {
      if (!mounted) return;
      _toast('Erreur : $e', color: Colors.red);
    }
  }

  void _toast(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Vrai si un preset système est en retard sur la version courante.
  bool _needsUpgrade(InvoiceTemplate t) {
    if (!t.isDefault) return false;
    return t.designVersion < InvoiceTemplate.kRoyalDesignVersion;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final text = theme.textColor;
    final sub = theme.textColor.withValues(alpha: 0.6);
    final bg = theme.backgroundColor;
    final primary = theme.primaryColor;

    final systemCount = _templates.where((t) => t.isDefault).length;
    final customCount = _templates.length - systemCount;
    final outdated = _templates.where(_needsUpgrade).length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Modèles de factures',
              style: TextStyle(
                color: text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            if (!_loading)
              Text(
                '$systemCount preset(s) · $customCount custom',
                style: TextStyle(
                  color: sub,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Créer un modèle',
            icon: Icon(Icons.add_rounded, color: text, size: 22),
            onPressed: () => context.push('/admin/templates/create'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: primary,
              child: Column(
                children: [
                  // ── Bandeau info si presets obsolètes ──
                  if (outdated > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: Color(0xFFF59E0B), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$outdated preset(s) à mettre à jour vers '
                                'le design v${InvoiceTemplate.kRoyalDesignVersion}.',
                                style: TextStyle(
                                  color: text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // ── Liste ──
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      itemCount: _templates.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _buildCard(
                        _templates[index],
                        theme,
                        index: index,
                        primary: primary,
                        isDark: isDark,
                        text: text,
                        sub: sub,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCard(
    InvoiceTemplate t,
    ThemeProvider theme, {
    required int index,
    required Color primary,
    required bool isDark,
    required Color text,
    required Color sub,
  }) {
    final isSystem = t.isDefault;
    final needsUpgrade = _needsUpgrade(t);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/admin/templates/edit/${t.id}'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // ── Miniature ──
                  Container(
                    width: 54,
                    height: 68,
                    decoration: BoxDecoration(
                      color: t.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: t.primaryColor.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (t.fileData.isNotEmpty && t.fileType != 'pdf')
                        ? Image.memory(
                            base64Decode(t.fileData),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                TemplateThumbnail(template: t),
                          )
                        : TemplateThumbnail(template: t),
                  ),
                  const SizedBox(width: 14),

                  // ── Infos ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (needsUpgrade)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.warning_amber_rounded,
                                    color: Color(0xFFF59E0B), size: 16),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (isSystem)
                              _badge('SYSTÈME', const Color(0xFF4F46E5)),
                            if (!isSystem && (t.createdBy?.isNotEmpty ?? false))
                              _badge('ADMIN', const Color(0xFF8B5CF6)),
                            if (t.isPremium)
                              _badge('PREMIUM', const Color(0xFFF59E0B)),
                            if (t.price > 0)
                              _badge('${t.price.toStringAsFixed(0)} XAF',
                                  const Color(0xFF10B981))
                            else
                              _badge('GRATUIT', const Color(0xFF10B981)),
                            _badge(
                              'v${t.designVersion}',
                              needsUpgrade
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF6B7280),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Actions ──
                  IconButton(
                    tooltip: 'Personnaliser',
                    icon: Icon(Icons.tune_rounded, color: primary, size: 20),
                    onPressed: () =>
                        context.push('/templates/workspace', extra: t),
                  ),
                  IconButton(
                    tooltip: 'Modifier les métadonnées',
                    icon: Icon(Icons.edit_outlined, color: sub, size: 20),
                    onPressed: () =>
                        context.push('/admin/templates/edit/${t.id}'),
                  ),
                  // ⚠️ Pas de suppression pour les presets système.
                  if (!isSystem)
                    IconButton(
                      tooltip: 'Supprimer',
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 20),
                      onPressed: () => _delete(t),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 30 + (index * 30)),
          duration: 300.ms,
        )
        .slideY(
          begin: 0.05,
          end: 0,
          duration: 300.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}