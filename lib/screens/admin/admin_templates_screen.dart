// lib/screens/admin/admin_templates_screen.dart
// ============================================================
//  Gestion des modèles de facture (ADMIN).
//  Liste les modèles (par défaut + boutique), permet de créer,
//  modifier, supprimer (soft-delete) et personnaliser (drag & drop).
// ============================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_template.dart';
import '../../providers/theme_provider.dart';
import '../../services/template_service.dart';

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
    if (mounted) {
      setState(() {
        _templates = [...InvoiceTemplate.getDefaultTemplates(), ...custom];
        _loading = false;
      });
    }
  }

  Future<void> _delete(InvoiceTemplate t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Supprimer « ${t.name} » ?'),
        content: Text(
            'Le modèle sera désactivé (soft-delete). Les factures existantes '
            'ne seront pas affectées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _templateService.deleteTemplate(t.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modèle supprimé'),
            backgroundColor: Colors.green,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('Modèles de factures (Admin)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.textColor, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Créer un modèle',
            icon: Icon(Icons.add_rounded, color: theme.textColor),
            onPressed: () => context.push('/admin/templates/create'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _templates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final t = _templates[index];
                  return _buildCard(t, theme);
                },
              ),
            ),
    );
  }

  Widget _buildCard(InvoiceTemplate t, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: t.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (t.fileData.isNotEmpty && t.fileType != 'pdf')
                  ? Image.memory(
                      base64Decode(t.fileData),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.description_outlined,
                          color: t.primaryColor,
                          size: 24),
                    )
                  : Icon(Icons.description_outlined,
                      color: t.primaryColor, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.name,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (t.isDefault) 'Défaut',
                    if (t.isPremium) 'Premium',
                    if (t.price > 0) '${t.price.toStringAsFixed(0)} XAF',
                    if (t.createdBy?.isNotEmpty ?? false) 'Admin',
                  ].join(' • '),
                  style: TextStyle(color: theme.subTextColor, fontSize: 11),
                ),
              ],
            ),
          ),
          // Actions
          IconButton(
            tooltip: 'Personnaliser (drag & drop)',
            icon: Icon(Icons.tune_rounded, color: theme.primaryColor),
            onPressed: () => context.push('/templates/workspace', extra: t),
          ),
          IconButton(
            tooltip: 'Modifier',
            icon: Icon(Icons.edit_outlined, color: theme.subTextColor),
            onPressed: () => context.push('/admin/templates/edit/${t.id}'),
          ),
          IconButton(
            tooltip: 'Supprimer',
            icon: Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent),
            onPressed: () => _delete(t),
          ),
        ],
      ),
    );
  }
}
