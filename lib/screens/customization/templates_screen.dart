// lib/screens/customization/templates_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/template_selection_service.dart';
import '../../services/template_service.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/glass_widgets.dart';

/// 🎨 Sélecteur rapide de modèle de facture (Plein écran & BottomSheet modal).
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

  /// 👮 La personnalisation de la facture est réservée à l'administrateur
  /// et au propriétaire du modèle (créateur / acheteur / accès premium /
  /// modèle gratuit).
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Modèle "${template.name}" activé pour vos factures'),
          backgroundColor: RoyalColors.tertiary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    if (widget.isModal) {
      Navigator.of(context).pop(template);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final goldAccent = theme.accentGold;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;

    final filtered = _templates.where((t) {
      if (_searchQuery.isEmpty) return true;
      return t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Choisir un Modèle',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontFamily: 'Manrope',
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Boutique de Modèles',
            icon: Icon(Icons.storefront, color: goldAccent),
            onPressed: () => context.push('/templates'),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: goldAccent),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un modèle...',
                          hintStyle: TextStyle(color: subTextColor),
                          prefixIcon: Icon(Icons.search, color: goldAccent),
                          filled: true,
                          fillColor: theme.inputFillColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: theme.inputBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: theme.inputBorderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: goldAccent),
                          ),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/templates/mine'),
                              icon: Icon(Icons.collections_bookmark, size: 18, color: textColor),
                              label: Text('Mes Modèles', style: TextStyle(color: textColor)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: theme.dividerColor),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => context.push('/templates'),
                              icon: const Icon(Icons.shopping_bag, size: 18),
                              label: const Text('Boutique Pro'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'Aucun modèle trouvé',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final template = filtered[index];
                            final isSelected = template.id == _selectedId;

                            return GestureDetector(
                              onTap: () => _selectTemplate(template),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? goldAccent
                                        : Colors.white.withValues(alpha: 0.1),
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: goldAccent.withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : [],
                                ),
                                child: GlassCard(
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
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    width: 24,
                                                    height: 10,
                                                    decoration: BoxDecoration(
                                                      color: template.primaryColor,
                                                      borderRadius: BorderRadius.circular(3),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: template.primaryColor
                                                          .withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'FACTURE',
                                                      style: TextStyle(
                                                        color: template.primaryColor,
                                                        fontSize: 7,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Container(
                                                height: 4,
                                                color: template.textColor.withValues(alpha: 0.2),
                                              ),
                                              const SizedBox(height: 3),
                                              Container(
                                                height: 4,
                                                width: 60,
                                                color: template.textColor.withValues(alpha: 0.15),
                                              ),
                                              const Spacer(),
                                              Align(
                                                alignment: Alignment.bottomRight,
                                                child: Container(
                                                  width: 32,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: template.primaryColor,
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    template.name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Icon(
                                                    Icons.check_circle,
                                                    color: goldAccent,
                                                    size: 18,
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              template.description,
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.6),
                                                fontSize: 11,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                if (_canCustomize(template))
                                                  InkWell(
                                                    onTap: () {
                                                      context.push(
                                                          '/templates/workspace',
                                                          extra: template);
                                                    },
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.tune,
                                                            size: 14,
                                                            color: goldAccent),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Éditer',
                                                          style: TextStyle(
                                                            color: goldAccent,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                else
                                                  const Row(
                                                    children: [
                                                      Icon(Icons.lock_outline,
                                                          size: 12,
                                                          color: Colors.white24),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Verrouillé',
                                                        style: TextStyle(
                                                          color: Colors.white24,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                InkWell(
                                                  onTap: () {
                                                    context.push('/templates/preview',
                                                        extra: template);
                                                  },
                                                  child: Icon(
                                                    Icons.visibility,
                                                    size: 16,
                                                    color: subTextColor,
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
                              ),
                            ).animate().fade().scale(
                                  duration: Duration(milliseconds: 200 + (index * 40)),
                                );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
