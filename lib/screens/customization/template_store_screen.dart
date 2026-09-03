// lib/screens/customization/template_store_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../services/template_service.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/glass_widgets.dart';

/// 🏪 Boutique de modèles de facture (Modèles officiels, OHADA Pro & Créations Admin).
class TemplateStoreScreen extends StatefulWidget {
  const TemplateStoreScreen({super.key});

  @override
  State<TemplateStoreScreen> createState() => _TemplateStoreScreenState();
}

class _TemplateStoreScreenState extends State<TemplateStoreScreen> {
  static const Color goldAccent = Color(0xFFC9A227);
  static const Color bgSurface = Color(0xFF1E1A24);
  static const Color bgBackground = Color(0xFF120F17);

  final TemplateService _templateService = TemplateService();

  List<InvoiceTemplate> _allTemplates = [];
  List<String> _userPurchasedIds = [];
  bool _isLoading = true;
  String _selectedCategory = 'Tous';
  String _searchQuery = '';

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
    final filtered = _allTemplates.where((t) {
      final matchesCat = _selectedCategory == 'Tous' ||
          t.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: bgBackground,
      appBar: AppBar(
        backgroundColor: bgSurface,
        elevation: 0,
        title: const Text(
          'Boutique de Modèles Pro',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Manrope',
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Mes Modèles',
            icon: const Icon(Icons.collections_bookmark, color: goldAccent),
            onPressed: () => context.push('/templates/mine'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: goldAccent),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un style (ex: Améthyste, Exécutif)...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                          prefixIcon: const Icon(Icons.search, color: goldAccent),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: goldAccent),
                          ),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
                          itemBuilder: (ctx, idx) {
                            final cat = _categories[idx];
                            final isSelected = _selectedCategory == cat;
                            return ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedCategory = cat);
                                }
                              },
                              selectedColor: RoyalColors.primary,
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? goldAccent
                                    : Colors.white.withValues(alpha: 0.1),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'Aucun modèle dans cette catégorie',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final template = filtered[index];
                            final isOwned = _userPurchasedIds.contains(template.id) || template.price <= 0;

                            return GlassCard(
                              padding: EdgeInsets.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: template.backgroundColor,
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(16),
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: template.primaryColor,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  template.category.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isOwned
                                                      ? RoyalColors.tertiary
                                                      : goldAccent,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  isOwned
                                                      ? 'POSSÉDÉ'
                                                      : '${template.price.toStringAsFixed(0)} FCFA',
                                                  style: TextStyle(
                                                    color: isOwned ? Colors.white : Colors.black,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          Container(
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: template.primaryColor,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            height: 4,
                                            width: 70,
                                            decoration: BoxDecoration(
                                              color: template.textColor.withValues(alpha: 0.3),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          const Spacer(),
                                        ],
                                      ),
                                    ),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          template.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.star,
                                                color: Colors.amber, size: 12),
                                            const SizedBox(width: 4),
                                            Text(
                                              template.rating > 0
                                                  ? template.rating.toStringAsFixed(1)
                                                  : '5.0',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.7),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 32,
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
                                                  ? RoyalColors.primary
                                                  : goldAccent,
                                              foregroundColor:
                                                  isOwned ? Colors.white : Colors.black,
                                              padding: EdgeInsets.zero,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              isOwned ? 'Personnaliser' : 'Obtenir',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fade().scale(
                                  duration: Duration(milliseconds: 150 + (index * 30)),
                                );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
