// lib/screens/admin/admin_templates_screen.dart
//
// 🎨 Modèles de factures — v3 « Soft Refined ».
//
// CHANGELOG v3 :
//   • 🎨 REFONTE VISUELLE : cartes aérées, ombres douces, typographie
//     hiérarchisée, espacement généreux.
//   • Badges réduits (2 max visibles : type + statut) — les infos
//     secondaires sont dans le menu contextuel.
//   • Menu contextuel `⋮` par carte (Personnaliser / Modifier / Supprimer)
//     au lieu de 3 IconButton alignés.
//   • Bandeau d'alerte upgrade compacté.
//   • Fond neutre avec cartes élevées (elevation douce).
//   • Aucun changement fonctionnel — toutes les actions restent identiques.
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
      final firestoreTemplates = await _templateService.getAllTemplates();
      final baseList = firestoreTemplates.isEmpty
          ? InvoiceTemplate.getDefaultTemplates()
          : firestoreTemplates;

      final byId = <String, InvoiceTemplate>{};
      for (final t in baseList) {
        byId[t.id] = t;
      }
      for (final preset in InvoiceTemplate.getDefaultTemplates()) {
        byId.putIfAbsent(preset.id, () => preset);
      }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  bool _needsUpgrade(InvoiceTemplate t) {
    if (!t.isDefault) return false;
    return t.designVersion < InvoiceTemplate.kRoyalDesignVersion;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final text = theme.textColor;
    final bg = theme.backgroundColor;
    final primary = theme.primaryColor;

    // Palette de gris adaptée au thème
    final sub = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.48);
    final surfaceTint = isDark
        ? const Color(0xFF14161B)
        : const Color(0xFFF7F8FA);

    final systemCount = _templates.where((t) => t.isDefault).length;
    final customCount = _templates.length - systemCount;
    final outdated = _templates.where(_needsUpgrade).length;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(
        text: text,
        sub: sub,
        primary: primary,
        total: _templates.length,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: primary,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  // ── Bandeau upgrade (si nécessaire) ──
                  if (outdated > 0)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: _buildUpgradeBanner(outdated, text, isDark),
                      ),
                    ),

                  // ── Statistiques compactes ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: _buildStats(
                        systemCount: systemCount,
                        customCount: customCount,
                        text: text,
                        sub: sub,
                        isDark: isDark,
                        primary: primary,
                      ),
                    ),
                  ),

                  // ── Liste des modèles ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList.separated(
                      itemCount: _templates.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildCard(
                          _templates[index],
                          index: index,
                          theme: theme,
                          isDark: isDark,
                          text: text,
                          sub: sub,
                          primary: primary,
                          surfaceTint: surfaceTint,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  APP BAR
  // ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar({
    required Color text,
    required Color sub,
    required Color primary,
    required int total,
  }) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          Text(
            'Modèles',
            style: TextStyle(
              color: text,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 10),
          if (!_loading && total > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$total',
                style: TextStyle(
                  color: primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => context.push('/admin/templates/create'),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Créer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  BANDEAU UPGRADE
  // ─────────────────────────────────────────────────────────────────
  Widget _buildUpgradeBanner(int count, Color text, bool isDark) {
    const accent = Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: accent,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count preset${count > 1 ? 's' : ''} à mettre à jour',
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Design v${InvoiceTemplate.kRoyalDesignVersion} disponible',
                  style: TextStyle(
                    color: text.withValues(alpha: 0.55),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  STATISTIQUES
  // ─────────────────────────────────────────────────────────────────
  Widget _buildStats({
    required int systemCount,
    required int customCount,
    required Color text,
    required Color sub,
    required bool isDark,
    required Color primary,
  }) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.verified_rounded,
            label: 'Presets système',
            value: '$systemCount',
            color: const Color(0xFF4F46E5),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.person_pin_rounded,
            label: 'Mes créations',
            value: '$customCount',
            color: const Color(0xFF8B5CF6),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.45),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  CARTE
  // ─────────────────────────────────────────────────────────────────
  Widget _buildCard(
    InvoiceTemplate t, {
    required int index,
    required ThemeProvider theme,
    required bool isDark,
    required Color text,
    required Color sub,
    required Color primary,
    required Color surfaceTint,
  }) {
    final isSystem = t.isDefault;
    final needsUpgrade = _needsUpgrade(t);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/templates/workspace', extra: t),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Miniature ──
                  _buildThumbnail(t),

                  const SizedBox(width: 14),

                  // ── Infos ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titre + warning
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
                                  letterSpacing: -0.3,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (needsUpgrade)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Color(0xFFF59E0B),
                                  size: 11,
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Description ou catégorie
                        Text(
                          t.description.isNotEmpty
                              ? t.description
                              : t.category,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: sub,
                            fontSize: 12,
                            height: 1.35,
                            letterSpacing: -0.1,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Badges compacts
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _badge(
                              isSystem ? 'Système' : 'Perso',
                              isSystem
                                  ? const Color(0xFF4F46E5)
                                  : const Color(0xFF8B5CF6),
                              isDark,
                            ),
                            _badge(
                              t.isPremium ? 'Premium' : 'Gratuit',
                              t.isPremium
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF10B981),
                              isDark,
                            ),
                            if (t.price > 0)
                              _badge(
                                '${t.price.toStringAsFixed(0)} XAF',
                                const Color(0xFF6B7280),
                                isDark,
                                subtle: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Menu contextuel ──
                  _buildMenu(t, text, primary, sub),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 30 + (index * 25)),
          duration: 320.ms,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.04,
          end: 0,
          duration: 320.ms,
          curve: Curves.easeOut,
        );
  }

  // ─────────────────────────────────────────────────────────────────
  //  MINIATURE
  // ─────────────────────────────────────────────────────────────────
  Widget _buildThumbnail(InvoiceTemplate t) {
    return Container(
      width: 68,
      height: 88,
      decoration: BoxDecoration(
        color: t.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: t.primaryColor.withValues(alpha: 0.20),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: t.primaryColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: (t.fileData.isNotEmpty && t.fileType != 'pdf')
          ? Image.memory(
              base64Decode(t.fileData),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => TemplateThumbnail(template: t),
            )
          : TemplateThumbnail(template: t),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  MENU CONTEXTUEL
  // ─────────────────────────────────────────────────────────────────
  Widget _buildMenu(
    InvoiceTemplate t,
    Color text,
    Color primary,
    Color sub,
  ) {
    final isSystem = t.isDefault;

    return PopupMenuButton<String>(
      tooltip: 'Options',
      icon: Icon(
        Icons.more_vert_rounded,
        color: sub.withValues(alpha: 0.7),
        size: 20,
      ),
      padding: EdgeInsets.zero,
      splashRadius: 20,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 6,
      onSelected: (value) {
        switch (value) {
          case 'customize':
            context.push('/templates/workspace', extra: t);
            break;
          case 'edit':
            context.push('/admin/templates/edit/${t.id}');
            break;
          case 'delete':
            _delete(t);
            break;
        }
      },
      itemBuilder: (ctx) => [
        _menuItem(
          value: 'customize',
          icon: Icons.tune_rounded,
          label: 'Personnaliser',
          color: primary,
          text: text,
        ),
        _menuItem(
          value: 'edit',
          icon: Icons.edit_outlined,
          label: 'Modifier',
          color: text,
          text: text,
        ),
        if (!isSystem)
          _menuItem(
            value: 'delete',
            icon: Icons.delete_outline_rounded,
            label: 'Supprimer',
            color: Colors.redAccent,
            text: text,
          ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem({
    required String value,
    required IconData icon,
    required String label,
    required Color color,
    required Color text,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  BADGE
  // ─────────────────────────────────────────────────────────────────
  Widget _badge(
    String label,
    Color color,
    bool isDark, {
    bool subtle = false,
  }) {
    final bg = subtle
        ? color.withValues(alpha: isDark ? 0.10 : 0.06)
        : color.withValues(alpha: isDark ? 0.16 : 0.10);
    final fg = subtle ? color.withValues(alpha: 0.75) : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          height: 1.2,
        ),
      ),
    );
  }
}