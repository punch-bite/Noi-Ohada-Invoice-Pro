// lib/screens/customization/template_store_screen.dart
// ============================================================
//  Boutique de modèles de facture — écran utilisateur.
//  Affiche les modèles créés par l'admin (vendables) + les modèles
//  par défaut. Les modèles "Premium" sont verrouillés et redirigent
//  vers l'offre/abonnement.
//  Style : glassmorphisme (design system moderne).
// ============================================================
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_template.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/template_service.dart';
import '../../services/template_selection_service.dart';
import '../../widgets/glass_widgets.dart';

class TemplateStoreScreen extends StatefulWidget {
  const TemplateStoreScreen({super.key});

  @override
  State<TemplateStoreScreen> createState() => _TemplateStoreScreenState();
}

class _TemplateStoreScreenState extends State<TemplateStoreScreen> {
  final TemplateService _templateService = TemplateService();
  List<InvoiceTemplate> _adminTemplates = [];
  bool _loading = true;
  String _selectedCategory = 'Tous';

  /// Libellé lisible d'une catégorie (ex. 'elegant' → 'Élégant').
  static String _categoryLabel(String c) {
    switch (c) {
      case 'classique':
        return 'Classique';
      case 'moderne':
        return 'Moderne';
      case 'elegant':
        return 'Élégant';
      case 'premium':
        return 'Premium';
      case 'minimaliste':
        return 'Minimaliste';
      case 'entreprise':
        return 'Entreprise';
      default:
        return c.isEmpty ? 'Autre' : c[0].toUpperCase() + c.substring(1);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final result = await _templateService.getAllTemplates();
    if (mounted) {
      setState(() {
        _adminTemplates = result;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final subProvider = context.watch<SubscriptionProvider>();
    final authProvider = context.watch<AppAuthProvider>();
    final currentUserId = authProvider.user?.id ?? '';
    final canAccessPremium = subProvider.canAccessPremiumTemplates;
    final defaults = InvoiceTemplate.getDefaultTemplates();

    // Fusion : modèles par défaut, puis ceux créés par l'admin (sans doublons)
    final adminIds = _adminTemplates.map((e) => e.id).toSet();
    final merged = [
      ...defaults.where((d) => !adminIds.contains(d.id)),
      ..._adminTemplates,
    ];

    // 🏷️ Catégories distinctes (pour les filtres de la boutique)
    final categories = <String>{'Tous'};
    for (final t in merged) {
      categories.add(t.category.isEmpty ? 'classique' : t.category);
    }
    final filtered = _selectedCategory == 'Tous'
        ? merged
        : merged.where((t) =>
            (t.category.isEmpty ? 'classique' : t.category) ==
            _selectedCategory).toList();

    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          'Modèles de Facture',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: theme.textColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.textColor, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bandeau d'accès premium (marketing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: GlassCard(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      canAccessPremium ? Icons.stars_rounded : Icons.storefront_rounded,
                      color: canAccessPremium ? Colors.green : const Color(0xFFE9B949),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        canAccessPremium
                            ? 'Accès Premium activé — profitez de tous les designs'
                            : 'Boutique Premium — débloquez des designs exclusifs',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: canAccessPremium ? Colors.green : theme.subTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 🏷️ Filtres par catégorie
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_categoryLabel(c)),
                        selected: _selectedCategory == c,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = c),
                        selectedColor: const Color(0xFF4338CA),
                        backgroundColor: theme.cardColor,
                        labelStyle: TextStyle(
                          color: _selectedCategory == c
                              ? Colors.white
                              : theme.textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color: _selectedCategory == c
                              ? const Color(0xFF4338CA)
                              : theme.dividerColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        showCheckmark: false,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Grille de modèles
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final template = filtered[index];
                        // 🔓 Déverrouillé si : abonnement actif (accès à tout),
                        // OU template non premium, OU template déjà acheté
                        // par l'utilisateur (achat possible sans abonnement).
                        final isOwned = currentUserId.isNotEmpty &&
                            template.purchasedBy.contains(currentUserId);
                        final isLocked = template.isPremium &&
                            !canAccessPremium &&
                            !isOwned;
                        return _buildTemplateCard(
                          template, isLocked, theme);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(
      InvoiceTemplate template, bool isLocked, ThemeProvider theme) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(20),
      onTap: () => _handleTap(template, isLocked),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: template.backgroundColor,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(19)),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: template.primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        color: template.primaryColor,
                        size: 30,
                      ),
                    ),
                  ),
                ),
                // Badge premium / boutique
                if (template.isPremium)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: GlassBadge(
                      label: 'Premium',
                      icon: Icons.stars_rounded,
                      color: const Color(0xFFE9B949),
                    ),
                  ),
                // 💰 Badge prix de vente (template payant)
                if (template.price > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GlassBadge(
                      label:
                          '${template.price.toStringAsFixed(0)} XAF',
                      icon: Icons.sell_rounded,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                if (isLocked)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(19)),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              children: [
                Text(
                  template.name,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w600,
                    color: theme.textColor,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (template.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    template.description,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 10,
                      color: theme.subTextColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                // 👁️ Aperçu + 🎨 Personnaliser (espace de travail drag & drop)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: isLocked
                                ? theme.subTextColor.withValues(alpha: 0.4)
                                : theme.primaryColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () => _openPreview(template),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.visibility_outlined,
                                    color: isLocked
                                        ? theme.subTextColor
                                        : theme.primaryColor,
                                    size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Aperçu',
                                  style: TextStyle(
                                    color: isLocked
                                        ? theme.subTextColor
                                        : theme.primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isLocked
                                ? [theme.subTextColor.withValues(alpha: 0.5)]
                                : [
                                    const Color(0xFF4338CA),
                                    const Color(0xFF7C3AED)
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () {
                              if (isLocked) {
                                _showUpgradeDialog();
                              } else {
                                _openWorkspace(template);
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.tune_rounded,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Personnaliser',
                                  style: TextStyle(
                                    color: isLocked
                                        ? Colors.white70
                                        : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
    );
  }

  void _handleTap(InvoiceTemplate template, bool isLocked) {
    // 💳 Template payant non acheté → propose l'achat.
    if (template.price > 0 && !template.paid) {
      _showPurchaseDialog(template);
      return;
    }
    if (isLocked) {
      _showUpgradeDialog();
    } else {
      _selectAndOpen(template);
    }
  }

  /// Sélectionne le modèle comme actif (persistance locale) puis ouvre
  /// l'espace de travail de personnalisation (drag & drop).
  Future<void> _selectAndOpen(InvoiceTemplate template) async {
    await TemplateSelectionService.setActiveTemplateId(template.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${template.name} défini comme modèle actif'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 1200),
      ),
    );
    _openWorkspace(template);
  }

  /// Ouvre l'espace de travail drag & drop pour ce modèle.
  void _openWorkspace(InvoiceTemplate template) {
    context.push('/templates/workspace', extra: template);
  }

  /// Ouvre l'aperçu du modèle (rendu avec données d'exemple).
  void _openPreview(InvoiceTemplate template) {
    context.push('/templates/preview', extra: template);
  }

  /// Dialog d'achat d'un template payant (vendu sur la plateforme).
  void _showPurchaseDialog(InvoiceTemplate template) {
    final theme = context.watch<ThemeProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '💰 ${template.name}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Ce modèle est vendu à ${template.price.toStringAsFixed(0)} XAF.\n\n'
          'Après achat, il sera disponible dans vos factures.',
          style: TextStyle(color: theme.subTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _purchaseTemplate(template);
            },
            icon: const Icon(Icons.lock_open, size: 18),
            label: Text('Acheter ${template.price.toStringAsFixed(0)} XAF'),
          ),
        ],
      ),
    );
  }

  /// 💳 Achète un template payant : ajoute l'UID à `purchasedBy` et marque
  /// `paid`. Un utilisateur en plan gratuit peut acheter (aucun abonnement
  /// requis) ; l'abonnement actif donne accès à tous sans achat.
  Future<void> _purchaseTemplate(InvoiceTemplate template) async {
    final authProvider = context.read<AppAuthProvider>();
    final userId = authProvider.user?.id ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous pour acheter ce modèle'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final updated = template.copyWith(
        purchasedBy: [...template.purchasedBy, userId],
        paid: true,
      );
      await _templateService.updateTemplate(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Modèle acheté avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
      _loadTemplates();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur d\'achat : $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showUpgradeDialog() {
    final theme = context.watch<ThemeProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '⭐ Modèle Premium',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Débloquez la boutique premium pour utiliser ce design exclusif '
          'sur vos factures.',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            height: 1.4,
            color: theme.subTextColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: theme.subTextColor),
            ),
          ),
          GradientButton(
            label: 'Voir les offres',
            icon: Icons.arrow_forward_rounded,
            height: 46,
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
          ),
        ],
      ),
    );
  }
}
