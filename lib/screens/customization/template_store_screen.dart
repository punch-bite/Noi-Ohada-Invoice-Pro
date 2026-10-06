// lib/screens/customization/template_store_screen.dart
//
// 🏪 Boutique : catalogue officiel + créations admin.
// Épuré : recherche flottante, chips ronds, cartes uniformes.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/template_service.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/template_thumbnail.dart';

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
    final theme = context.watch<ThemeProvider>();
    final sub = context.watch<SubscriptionProvider>();
    final isDark = theme.isDarkMode;
    final goldAccent = theme.accentGold;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Boutique',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 19,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Mes modèles',
            icon: Icon(Icons.collections_bookmark_rounded,
                color: goldAccent, size: 22),
            onPressed: () => context.push('/templates/mine'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: goldAccent))
          : Column(
              children: [
                // ── Barre de recherche ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un style…',
                        hintStyle: TextStyle(
                            color: subTextColor.withValues(alpha: 0.7),
                            fontSize: 13.5),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: subTextColor, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded,
                                    color: subTextColor, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Chips catégories ──
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, idx) {
                      final cat = _categories[idx];
                      final isSelected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.primaryColor
                                : theme.cardColor,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isSelected
                                  ? theme.primaryColor
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black
                                          .withValues(alpha: 0.06)),
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : textColor,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // ── Grille ──
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState(textColor, subTextColor)
                      : GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.62,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final template = filtered[index];
                            final isOwned = hasPremiumAccess ||
                                _userPurchasedIds.contains(template.id) ||
                                template.price <= 0;
                            return _buildStoreCard(
                              template,
                              isOwned: isOwned,
                              theme: theme,
                              textColor: textColor,
                              subTextColor: subTextColor,
                              goldAccent: goldAccent,
                            )
                                .animate()
                                .fadeIn(
                                  delay: Duration(
                                      milliseconds: 50 + (index * 40)),
                                  duration: 400.ms,
                                )
                                .slideY(
                                  begin: 0.06,
                                  end: 0,
                                  duration: 400.ms,
                                  curve: Curves.easeOut,
                                );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStoreCard(
    InvoiceTemplate template, {
    required bool isOwned,
    required ThemeProvider theme,
    required Color textColor,
    required Color subTextColor,
    required Color goldAccent,
  }) {
    final isDark = theme.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                context.push('/templates/preview', extra: template),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Aperçu ──
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: TemplateThumbnail(template: template),
                      ),
                      // Badges haut
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: template.primaryColor,
                            borderRadius: BorderRadius.circular(6),
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
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOwned
                                ? RoyalColors.tertiary
                                : goldAccent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isOwned
                                ? 'POSSÉDÉ'
                                : '${template.price.toStringAsFixed(0)} F',
                            style: TextStyle(
                              color:
                                  isOwned ? Colors.white : Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
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
                          color: textColor,
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
                              color: subTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.visibility_outlined,
                              size: 12,
                              color: subTextColor.withValues(alpha: 0.7)),
                          const SizedBox(width: 3),
                          Text(
                            'Aperçu',
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: ElevatedButton(
                          onPressed: () {
                            if (isOwned) {
                              context.push('/templates/workspace',
                                  extra: template);
                            } else {
                              context.push('/templates/checkout',
                                  extra: template);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isOwned
                                ? theme.primaryColor
                                : goldAccent,
                            foregroundColor:
                                isOwned ? Colors.white : Colors.black,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                          child: Text(
                              isOwned ? 'Personnaliser' : 'Obtenir'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color subTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: subTextColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(Icons.search_off_rounded,
                  size: 42, color: subTextColor.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucun modèle trouvé',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Essayez une autre catégorie ou un autre mot-clé.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: subTextColor, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}