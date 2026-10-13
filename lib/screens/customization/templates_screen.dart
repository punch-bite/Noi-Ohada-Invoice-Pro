// lib/screens/customization/templates_screen.dart
//
// 🎨 Sélecteur rapide de modèle de facture.
// Refonte épurée & animée (kit `customization_ui.dart`) : recherche inline,
// accès rapides uniformes, cartes sélectionnables avec état doré cohérent.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:noi_ohada_invoice_pro/theme/royal_ledger.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/template_selection_service.dart';
import '../../services/template_service.dart';
import '../../widgets/glass_widgets.dart';
import 'customization_ui.dart';

class TemplatesScreen extends StatefulWidget {
  final bool isModal;
  final String? currentTemplateId;
  final ValueChanged<InvoiceTemplate>? onSelect;

  const TemplatesScreen({
    super.key,
    this.isModal = false,
    this.currentTemplateId,
    this.onSelect,
  });

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final TemplateService _templateService = TemplateService();
  final TextEditingController _searchController = TextEditingController();

  List<InvoiceTemplate> _templates = [];
  String? _selectedId;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentTemplateId;
    _loadTemplates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _canCustomize(InvoiceTemplate template) {
    final auth = context.read<AppAuthProvider>();
    return template.canBeCustomizedBy(
      userId: auth.user?.id ?? '',
      isAdmin: auth.isAdmin,
      hasPremiumAccess:
          context.read<SubscriptionProvider>().canAccessPremiumTemplates,
    );
  }

  Future<void> _loadTemplates() async {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final userId = auth.user?.id ?? '';

    _selectedId ??= await TemplateSelectionService.getActiveTemplateId();

    var list = await _templateService.getMyTemplates(userId);
    if (list.isEmpty) {
      list = InvoiceTemplate.getDefaultTemplates();
    }

    if (!mounted) return;
    setState(() {
      _templates = list;
      _isLoading = false;
    });
  }

  Future<void> _selectTemplate(InvoiceTemplate template) async {
    setState(() => _selectedId = template.id);
    await TemplateSelectionService.setActiveTemplateId(template.id);

    if (!mounted) return;
    if (widget.onSelect != null) {
      widget.onSelect!(template);
    } else {
      CustomSnack.show(
        context,
        '« ${template.name} » est maintenant actif',
        type: CustomSnackType.success,
      );
    }

    if (widget.isModal) {
      Navigator.of(context).pop(template);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CustomPalette.of(context);

    final filtered = _templates.where((t) {
      if (_searchQuery.isEmpty) return true;
      return t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return GlassScaffold(
      appBar: CustomAppBar(
        title: 'Choisir un modèle',
        subtitle: 'Modèle appliqué à vos factures',
        actions: [
          IconButton(
            tooltip: 'Boutique',
            icon: const Icon(Icons.storefront_rounded, size: 22),
            onPressed: () => context.push('/templates'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? const TemplatesSkeleton()
          : Column(
              children: [
                // ── Recherche ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: CustomSearchField(
                    controller: _searchController,
                    hint: 'Rechercher…',
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Accès rapides ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _quickAction(
                          icon: Icons.collections_bookmark_rounded,
                          label: 'Mes modèles',
                          onTap: () => context.push('/templates/mine'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _quickAction(
                          icon: Icons.shopping_bag_rounded,
                          label: 'Boutique',
                          filled: true,
                          onTap: () => context.push('/templates'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Grille ──
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Aucun modèle trouvé',
                          message:
                              'Ajustez votre recherche pour afficher vos modèles.',
                        )
                      : GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final template = filtered[index];
                            final isSelected = template.id == _selectedId;
                            return EntranceFade(
                              index: index,
                              child: _buildSelectableCard(
                                template,
                                isSelected: isSelected,
                                canCustomize: _canCustomize(template),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final p = CustomPalette.of(context);
    return Material(
      color: filled ? p.primary : p.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: filled ? null : Border.all(color: p.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 17, color: filled ? p.onPrimary : p.subText),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: filled ? p.onPrimary : p.text,
                  fontFamily: 'WorkSans',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableCard(
    InvoiceTemplate template, {
    required bool isSelected,
    required bool canCustomize,
  }) {
    final p = CustomPalette.of(context);
    return PressScale(
      onTap: () => _selectTemplate(template),
      child: AnimatedContainer(
        duration: RoyalMotion.base,
        curve: RoyalMotion.standard,
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? p.gold : p.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: p.gold.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TemplateThumbFrame(
                    template: template,
                    radius: 18,
                    border: Border.all(color: Colors.transparent),
                  ),
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: p.gold,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: p.gold.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(Icons.check_rounded,
                            color: p.onGold, size: 14),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.text,
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    template.description.isNotEmpty
                        ? template.description
                        : template.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.subText,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (canCustomize)
                        InkWell(
                          onTap: () => context.push(
                              '/templates/workspace',
                              extra: template),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 2, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.tune_rounded,
                                    size: 13, color: p.gold),
                                const SizedBox(width: 4),
                                Text(
                                  'Éditer',
                                  style: TextStyle(
                                    color: p.gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 12,
                                color: p.subText.withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Text(
                              'Verrouillé',
                              style: TextStyle(
                                color: p.subText.withValues(alpha: 0.7),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      const Spacer(),
                      InkWell(
                        onTap: () => context.push(
                            '/templates/preview', extra: template),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.visibility_outlined,
                            size: 15,
                            color: p.subText.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
