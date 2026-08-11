// lib/screens/customization/template_store_screen.dart
// ============================================================
//  Boutique de modèles de facture — écran utilisateur.
//  Affiche les modèles créés par l'admin (vendables) + les modèles
//  par défaut. Les modèles "Premium" sont verrouillés et redirigent
//  vers l'offre/abonnement.
//  Style : glassmorphisme (design system moderne).
// ============================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_template.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/template_cart.dart';
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

  /// Ordre d'affichage des sections de catégories (carousels).
  static const List<String> _categoryOrder = [
    'classique',
    'moderne',
    'elegant',
    'premium',
    'minimaliste',
    'entreprise',
  ];

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
    final isAdmin = authProvider.user?.isAdmin == true;
    final canAccessPremium = subProvider.canAccessPremiumTemplates;
    final cart = context.watch<TemplateCart>();
    final defaults = InvoiceTemplate.getDefaultTemplates();

    // Fusion : modèles par défaut, puis ceux créés par l'admin (sans doublons)
    final adminIds = _adminTemplates.map((e) => e.id).toSet();
    final merged = [
      ...defaults.where((d) => !adminIds.contains(d.id)),
      ..._adminTemplates,
    ];

    // 🏷️ Groupement des modèles par catégorie (sections en carousel).
    final Map<String, List<InvoiceTemplate>> byCategory = {};
    for (final t in merged) {
      final cat = t.category.isEmpty ? 'classique' : t.category;
      byCategory.putIfAbsent(cat, () => []).add(t);
    }

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
        actions: [
          IconButton(
            tooltip: 'Mes modèles',
            icon: Icon(Icons.folder_outlined, color: theme.textColor),
            onPressed: () => context.push('/templates/mine'),
          ),
          IconButton(
            tooltip: 'Panier',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.shopping_cart_outlined, color: theme.textColor),
                if (cart.count > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                          minWidth: 15, minHeight: 15),
                      child: Text(
                        '${cart.count}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => context.push('/templates/checkout'),
          ),
        ],
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
            // � Modèles classés par catégorie, chaque section en carousel.
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final cat in _categoryOrder)
                          if ((byCategory[cat] ?? []).isNotEmpty)
                            _buildCategorySection(
                              cat,
                              byCategory[cat]!,
                              currentUserId,
                              isAdmin,
                              canAccessPremium,
                              theme,
                            ),
                        // Catégories personnalisées non prédéfinies.
                        for (final cat in byCategory.keys)
                          if (!_categoryOrder.contains(cat) &&
                              byCategory[cat]!.isNotEmpty)
                            _buildCategorySection(
                              cat,
                              byCategory[cat]!,
                              currentUserId,
                              isAdmin,
                              canAccessPremium,
                              theme,
                            ),
                      ],
                    ),
            ),
            // 🛒 Barre de panier (récapitulatif + accès au checkout).
            if (cart.count > 0)
              _buildCartBar(cart, theme),
          ],
        ),
      ),
    );
  }

  /// Barre de panier affichée en bas de la boutique.
  Widget _buildCartBar(TemplateCart cart, ThemeProvider theme) {
    final total = cart.total;
    final fmt =
        '${total.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ')} XAF';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: theme.isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_cart_outlined,
              color: theme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${cart.count} modèle(s) • ${total > 0 ? fmt : 'Gratuit'}',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => context.push('/templates/checkout'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Commander'),
          ),
        ],
      ),
    );
  }

  /// Section de boutique : titre de catégorie + carousel horizontal de modèles.
  Widget _buildCategorySection(
    String category,
    List<InvoiceTemplate> templates,
    String currentUserId,
    bool isAdmin,
    bool canAccessPremium,
    ThemeProvider theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _categoryLabel(category),
            style: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: theme.textColor,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final template = templates[index];
              // 🔓 Déverrouillé si : abonnement actif (accès à tout),
              // OU template non premium, OU template déjà acheté
              // par l'utilisateur (achat possible sans abonnement).
              // 🔓 Accessible si : admin, modèle déjà acheté, ou modèle
              // GRATUIT (prix = 0 défini par l'admin). Sinon → à acheter.
              final isOwned = isAdmin ||
                  (currentUserId.isNotEmpty &&
                      template.purchasedBy.contains(currentUserId)) ||
                  template.price <= 0;
              final isLocked = !isOwned;
              return SizedBox(
                width: 190,
                child: _buildTemplateCard(
                  template,
                  isLocked,
                  theme,
                  currentUserId,
                  isAdmin,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTemplateCard(
    InvoiceTemplate template,
    bool isLocked,
    ThemeProvider theme,
    String currentUserId,
    bool isAdmin,
  ) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(20),
      // 👆 Cliquer sur la facture → aperçu.
      onTap: () => _openPreview(template),
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
                  // 🖼️ Affiche l'image téléversée (JPEG/PNG) si présente,
                  // sinon la vignette par défaut (icône document).
                  child: (template.fileData.isNotEmpty &&
                          template.fileType != 'pdf')
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(19)),
                          child: Image.memory(
                            base64Decode(template.fileData),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildStoreFallback(template),
                          ),
                        )
                      : _buildStoreFallback(template),
                ),
                // Badges Premium + Prix (en Wrap pour ne jamais déborder
                // sur les petits écrans — pas de chevauchement)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (template.isPremium)
                        GlassBadge(
                          label: 'Premium',
                          icon: Icons.stars_rounded,
                          color: const Color(0xFFE9B949),
                        ),
                      if (template.price > 0)
                        GlassBadge(
                          label:
                              '${template.price.toStringAsFixed(0)} XAF',
                          icon: Icons.sell_rounded,
                          color: const Color(0xFF16A34A),
                        ),
                    ],
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
                // 🎨 Personnaliser — réservé à l'admin ou aux acheteurs.
                Container(
                  width: double.infinity,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => _handleCustomize(
                        template,
                        isLocked,
                        currentUserId,
                        isAdmin,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.tune_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Personnaliser',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Vignette par défaut (icône document) quand le modèle n'a pas
  /// d'image téléversée ou que son fichier est un PDF.
  Widget _buildStoreFallback(InvoiceTemplate template) {
    return Center(
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
    );
  }

  /// Personnalisation réservée à l'admin et aux acheteurs du modèle.
  void _handleCustomize(
      InvoiceTemplate template, bool isLocked, String userId, bool isAdmin) {
    final isOwner = userId.isNotEmpty && template.purchasedBy.contains(userId);
    if (isAdmin || isOwner) {
      _selectAndOpen(template);
      return;
    }
    // 💳 Modèle payant non acheté → proposer l'achat pour personnaliser.
    if (template.price > 0 && !template.paid) {
      _showPurchaseDialog(template);
      return;
    }
    if (isLocked) {
      _showUpgradeDialog();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La personnalisation est réservée à l\'administrateur ou aux '
          'acheteurs de ce modèle.'),
        backgroundColor: Colors.orange,
      ),
    );
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

  /// 💳 Achat d'un modèle → ajout au PANIER puis checkout sécurisé.
  /// Le déblocage est vérifié côté SERVEUR (`POST /template/purchase`) :
  ///  - modèles gratuits (prix admin = 0) → débloqués SANS paiement ;
  ///  - modèles payants → règlement ENKAP avant déblocage.
  void _purchaseTemplate(InvoiceTemplate template) {
    final cart = TemplateCart.instance;
    if (cart.contains(template.id)) {
      context.push('/templates/checkout');
      return;
    }
    cart.add(template);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${template.name} ajouté au panier 🛒'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 1200),
      ),
    );
    context.push('/templates/checkout');
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
