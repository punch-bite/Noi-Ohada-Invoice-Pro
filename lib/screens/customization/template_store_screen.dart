// lib/screens/customization/template_store_screen.dart
//
// 🏪 Boutique : catalogue officiel + créations admin.
// Épuré : recherche flottante, chips ronds, cartes uniformes.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/template_service.dart';
import '../../services/template_cart.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/glass_widgets.dart';
import 'customization_ui.dart';

class TemplateStoreScreen extends StatefulWidget {
  const TemplateStoreScreen({super.key});

  @override
  State<TemplateStoreScreen> createState() => _TemplateStoreScreenState();
}

class _TemplateStoreScreenState extends State<TemplateStoreScreen> {
  final TemplateService _templateService = TemplateService();

  List<InvoiceTemplate> _allTemplates = [];
  List<String> _userPurchasedIds = [];
  bool _isLoading = true;
  String _selectedCategory = 'Tous';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'Tous',
    'Classique',
    'Moderne',
    'Élégant',
    'Premium',
    'Corporate',
  ];

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreData() async {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final userId = auth.user?.id ?? '';

    var storeTemplates = await _templateService.getAllTemplates();
    if (storeTemplates.isEmpty) {
      storeTemplates = InvoiceTemplate.getDefaultTemplates();
    }

    var myTemplates = await _templateService.getMyTemplates(userId);
    final purchasedIds = myTemplates.map((t) => t.id).toList();

    if (!mounted) return;
    setState(() {
      _allTemplates = storeTemplates;
      _userPurchasedIds = purchasedIds;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final hasPremiumAccess = sub.canAccessPremiumTemplates;

    final filtered = _allTemplates.where((t) {
      final matchesCat = _selectedCategory == 'Tous' ||
          t.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return GlassScaffold(
      appBar: CustomAppBar(
        title: 'Boutique',
        subtitle: 'Modèles officiels & créations',
        actions: [
          // 🛒 Panier d'achat (badge = nombre d'articles)
          ListenableBuilder(
            listenable: TemplateCart.instance,
            builder: (context, _) {
              final count = TemplateCart.instance.count;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Panier',
                    icon: const Icon(Icons.shopping_cart_outlined, size: 22),
                    onPressed: () {
                      if (TemplateCart.instance.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Votre panier est vide.'),
                          ),
                        );
                        return;
                      }
                      context.push('/templates/checkout',
                          extra: TemplateCart.instance.items);
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                            minWidth: 17, minHeight: 17),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Mes modèles',
            icon: const Icon(Icons.collections_bookmark_rounded, size: 22),
            onPressed: () => context.push('/templates/mine'),
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
                    hint: 'Rechercher un style…',
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Chips catégories ──
                CustomChipsRow(
                  items: _categories,
                  selected: _selectedCategory,
                  onSelected: (cat) =>
                      setState(() => _selectedCategory = cat),
                ),
                const SizedBox(height: 18),

                // ── Grille ──
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Aucun modèle trouvé',
                          message:
                              'Essayez une autre catégorie ou un autre mot-clé.',
                          actionLabel: 'Réinitialiser',
                          onAction: () {
                            setState(() {
                              _selectedCategory = 'Tous';
                              _searchQuery = '';
                            });
                            _searchController.clear();
                          },
                        )
                      : GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.62,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final template = filtered[index];
                            final isOwned = hasPremiumAccess ||
                                _userPurchasedIds.contains(template.id) ||
                                template.price <= 0;
                            return EntranceFade(
                              index: index,
                              child: StoreTemplateCard(
                                template: template,
                                isOwned: isOwned,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

}

/// Carte d'un modèle dans la boutique de modèles.
///
/// Extraite de `_TemplateStoreScreenState` pour être réutilisable et
/// testable isolément.
class StoreTemplateCard extends StatelessWidget {
  const StoreTemplateCard({
    super.key,
    required this.template,
    required this.isOwned,
  });

  final InvoiceTemplate template;

  /// Le modèle est-il déjà possédé (achat effectué, offre premium ou gratuit) ?
  /// Pilote le badge et le libellé du bouton.
  final bool isOwned;

  @override
  Widget build(BuildContext context) {
    final p = CustomPalette.of(context);
    return PressScale(
      onTap: () => context.push('/templates/preview', extra: template),
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(RoyalRadius.card),
          // 🚫 Pas de bordure : l'élévation suffit à détacher la carte du fond.
          boxShadow: RoyalElevation.surface(p.isDark),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Aperçu ──
            // Coins hauts seuls : le visuel est encastré dans la carte et se
            // prolonge à fleur du bloc infos, sans arrondi parasite en bas.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TemplateThumbFrame(
                    template: template,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(RoyalRadius.card),
                    ),
                  ),
                  // Badge catégorie (haut gauche)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: template.primaryColor,
                        borderRadius: BorderRadius.circular(RoyalRadius.full),
                      ),
                      child: Text(
                        template.category.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  // Badge prix / possédé (haut droite)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: isOwned
                        ? const OwnedPill()
                        : PricePill('${template.price.toStringAsFixed(0)} F'),
                  ),
                ],
              ),
            ),

            // ── Infos ──
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFBBF24), size: 13),
                      const SizedBox(width: 3),
                      Text(
                        template.rating > 0
                            ? template.rating.toStringAsFixed(1)
                            : '5.0',
                        style: TextStyle(
                          color: p.subText,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: FilledButton(
                      onPressed: () {
                        if (isOwned) {
                          context.push('/templates/workspace',
                              extra: template);
                        } else {
                          // 🛒 Ajoute au panier (le règlement se fait au checkout)
                          if (!TemplateCart.instance.contains(template.id)) {
                            TemplateCart.instance.add(template);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${template.name} ajouté au panier'),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: isOwned ? p.primary : p.gold,
                        foregroundColor: isOwned ? p.onPrimary : p.onGold,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                RoyalRadius.control)),
                      ),
                      child: Text(
                        isOwned ? 'Personnaliser' : 'Ajouter',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
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
