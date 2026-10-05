// lib/screens/customization/templates_screen.dart
//
// 🎨 Sélecteur rapide de modèle de facture.
// Épuré : recherche inline, sélection par tap, cards uniformes.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/template_selection_service.dart';
import '../../services/template_service.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/template_thumbnail.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('« ${template.name} » est maintenant actif'),
          backgroundColor: RoyalColors.tertiary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
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
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Choisir un modèle',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 19,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Boutique',
            icon: Icon(Icons.storefront_rounded,
                color: goldAccent, size: 22),
            onPressed: () => context.push('/templates'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: goldAccent))
          : Column(
              children: [
                // ── Recherche ──
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
                        hintText: 'Rechercher…',
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

                // ── Accès rapides ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _quickAction(
                          icon: Icons.collections_bookmark_rounded,
                          label: 'Mes modèles',
                          onTap: () => context.push('/templates/mine'),
                          theme: theme,
                          textColor: textColor,
                          subTextColor: subTextColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _quickAction(
                          icon: Icons.shopping_bag_rounded,
                          label: 'Boutique',
                          onTap: () => context.push('/templates'),
                          theme: theme,
                          textColor: Colors.white,
                          subTextColor: Colors.white70,
                          filled: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Grille ──
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'Aucun modèle trouvé',
                            style: TextStyle(color: subTextColor),
                          ),
                        )
                      : GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final template = filtered[index];
                            final isSelected =
                                template.id == _selectedId;
                            return _buildSelectableCard(
                              template,
                              isSelected: isSelected,
                              canCustomize: _canCustomize(template),
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

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeProvider theme,
    required Color textColor,
    required Color subTextColor,
    bool filled = false,
  }) {
    final isDark = theme.isDarkMode;
    return Material(
      color: filled ? theme.primaryColor : theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: filled
                ? null
                : Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: filled ? Colors.white : subTextColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : textColor,
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
    required ThemeProvider theme,
    required Color textColor,
    required Color subTextColor,
    required Color goldAccent,
  }) {
    final isDark = theme.isDarkMode;
    return GestureDetector(
      onTap: () => _selectTemplate(template),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? goldAccent
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: goldAccent.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                      child: TemplateThumbnail(template: template),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: goldAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: goldAccent.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14),
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
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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
                        color: subTextColor,
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
                                      size: 13, color: goldAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Éditer',
                                    style: TextStyle(
                                      color: goldAccent,
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
                                  color: subTextColor.withValues(alpha: 0.5)),
                              const SizedBox(width: 4),
                              Text(
                                'Verrouillé',
                                style: TextStyle(
                                  color: subTextColor.withValues(alpha: 0.7),
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
                              color: subTextColor.withValues(alpha: 0.8),
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
      ),
    );
  }
}