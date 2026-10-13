// lib/screens/customization/my_templates_screen.dart
//
// 📁 Mes Modèles : bibliothèque des modèles acquis + gestion du modèle actif.
// Refonte épurée & animée (kit `customization_ui.dart`) : héros dégradé,
// cartes uniformes, états vides actionnables, hiérarchie typographique M3.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../services/template_custom_service.dart';
import '../../services/template_selection_service.dart';
import '../../services/template_service.dart';
import '../../widgets/glass_widgets.dart';
import 'customization_ui.dart';

class MyTemplatesScreen extends StatefulWidget {
  const MyTemplatesScreen({super.key});

  @override
  State<MyTemplatesScreen> createState() => _MyTemplatesScreenState();
}

class _MyTemplatesScreenState extends State<MyTemplatesScreen> {
  final TemplateService _templateService = TemplateService();

  List<InvoiceTemplate> _myTemplates = [];
  InvoiceTemplate? _activeTemplate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final userId = auth.user?.id ?? '';

    final activeId = await TemplateSelectionService.getActiveTemplateId();
    var list = await _templateService.getMyTemplates(userId);
    if (list.isEmpty) {
      list = InvoiceTemplate.getDefaultTemplates();
    }

    InvoiceTemplate? active;
    if (activeId != null) {
      active =
          list.firstWhere((t) => t.id == activeId, orElse: () => list.first);
    } else if (list.isNotEmpty) {
      active = list.first;
    }

    if (!mounted) return;
    setState(() {
      _myTemplates = list;
      _activeTemplate = active;
      _isLoading = false;
    });
  }

  Future<void> _setActiveTemplate(InvoiceTemplate template) async {
    await TemplateSelectionService.setActiveTemplateId(template.id);
    if (!mounted) return;
    setState(() => _activeTemplate = template);
    CustomSnack.show(
      context,
      '« ${template.name} » est désormais votre modèle actif',
      type: CustomSnackType.success,
    );
  }

  Future<void> _resetTemplateCustom(InvoiceTemplate template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Réinitialiser ?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Les personnalisations de « ${template.name} » seront perdues.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await TemplateCustomService.clearCustom(template.id);
    if (!mounted) return;
    CustomSnack.show(context, '« ${template.name} » réinitialisé');
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: CustomAppBar(
        title: 'Mes modèles',
        subtitle: _myTemplates.isEmpty
            ? 'Votre bibliothèque'
            : '${_myTemplates.length} modèle(s) acquis',
        actions: [
          IconButton(
            tooltip: 'Boutique',
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 22),
            onPressed: () => context.push('/templates'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? const TemplatesSkeleton()
          : RefreshIndicator(
              onRefresh: _loadTemplates,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_myTemplates.isEmpty) ...[
                      const SizedBox(height: 60),
                      EmptyState(
                        icon: Icons.collections_bookmark_outlined,
                        title: 'Aucun modèle pour l''instant',
                        message:
                            'Rendez-vous dans la boutique pour acquérir votre premier modèle.',
                        actionLabel: 'Explorer la boutique',
                        onAction: () => context.push('/templates'),
                      ),
                    ] else ...[
                      if (_activeTemplate != null)
                        EntranceFade(
                          index: 0,
                          child: _buildActiveHero(_activeTemplate!),
                        ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Text(
                            'Bibliothèque',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          _CountBadge(_myTemplates.length),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => context.push('/templates'),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Ajouter',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < _myTemplates.length; i++)
                        EntranceFade(
                          index: i + 1,
                          child: _buildTemplateCard(
                            _myTemplates[i],
                            isActive:
                                _myTemplates[i].id == _activeTemplate?.id,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // ── Héro : grande carte du modèle actif ──
  Widget _buildActiveHero(InvoiceTemplate template) {
    final accent = template.primaryColor;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: 0.78)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 13),
                SizedBox(width: 5),
                Text(
                  'MODÈLE ACTIF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            template.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Manrope',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            template.description.isNotEmpty
                ? template.description
                : template.category,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push('/templates/workspace',
                      extra: template),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Personnaliser'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: accent,
                    elevation: 0,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _HeroIconButton(
                icon: Icons.visibility_outlined,
                tooltip: 'Aperçu',
                onTap: () =>
                    context.push('/templates/preview', extra: template),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Carte uniforme d''un modèle ──
  Widget _buildTemplateCard(
    InvoiceTemplate t, {
    required bool isActive,
  }) {
    final p = CustomPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? p.gold : p.border,
          width: isActive ? 1.6 : 1,
        ),
      ),
      child: PressScale(
        onTap: () => context.push('/templates/preview', extra: t),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  TemplateThumbFrame(
                    template: t,
                    radius: 12,
                    border: Border.all(
                        color: t.primaryColor.withValues(alpha: 0.4)),
                  ),
                  const SizedBox(width: 14),
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
                                  color: p.text,
                                  fontFamily: 'Manrope',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (isActive) const ActivePill(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.description.isNotEmpty
                              ? t.description
                              : t.category,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.subText,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: p.border),
              const SizedBox(height: 8),
              Row(
                children: [
                  InkWell(
                    onTap: () => _resetTemplateCustom(t),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.refresh_rounded,
                              size: 15, color: p.subText),
                          const SizedBox(width: 4),
                          Text(
                            'Reset',
                            style: TextStyle(
                              color: p.subText,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Aperçu',
                    onPressed: () =>
                        context.push('/templates/preview', extra: t),
                    icon: Icon(Icons.visibility_outlined,
                        size: 19, color: p.subText),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: () =>
                        context.push('/templates/workspace', extra: t),
                    icon: const Icon(Icons.tune_rounded, size: 15),
                    label: const Text('Éditer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.primary,
                      foregroundColor: p.onPrimary,
                      elevation: 0,
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (!isActive) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _setActiveTemplate(t),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.onGold,
                        side: BorderSide(color: p.gold, width: 1.2),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Activer',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge numérique pour la section bibliothèque.
class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge(this.count);

  @override
  Widget build(BuildContext context) {
    final p = CustomPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: p.onGold,
        ),
      ),
    );
  }
}

/// Bouton icône translucide utilisé dans le héros (sur fond coloré).
class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeroIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 48,
            height: 46,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
