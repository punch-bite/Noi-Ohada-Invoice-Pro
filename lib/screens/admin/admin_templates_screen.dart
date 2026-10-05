// lib/screens/admin/admin_templates_screen.dart
//
// 📋 Modèles (Admin) — épuré : header count, cards compactes, actions groupées.
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
    final custom = await _templateService.getAllTemplates();
    if (!mounted) return;
    setState(() {
      _templates = [...InvoiceTemplate.getDefaultTemplates(), ...custom];
      _loading = false;
    });
  }

  Future<void> _delete(InvoiceTemplate t) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modèle supprimé'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;
    final primary = theme.primaryColor;

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
        title: Text(
          'Modèles de factures',
          style: TextStyle(
            color: text,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
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
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
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
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (t.isDefault)
                              _badge('DÉFAUT', const Color(0xFF4F46E5)),
                            if (t.isPremium)
                              _badge('PREMIUM', const Color(0xFFF59E0B)),
                            if (t.price > 0)
                              _badge('${t.price.toStringAsFixed(0)} XAF',
                                  const Color(0xFF10B981)),
                            if (t.createdBy?.isNotEmpty ?? false)
                              _badge('ADMIN', const Color(0xFF8B5CF6)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Personnaliser',
                    icon: Icon(Icons.tune_rounded, color: primary, size: 20),
                    onPressed: () =>
                        context.push('/templates/workspace', extra: t),
                  ),
                  IconButton(
                    tooltip: 'Modifier',
                    icon: Icon(Icons.edit_outlined, color: sub, size: 20),
                    onPressed: () =>
                        context.push('/admin/templates/edit/${t.id}'),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 20),
                    onPressed: () => _delete(t),
                  ),
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