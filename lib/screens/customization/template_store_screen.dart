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
import '../../services/template_service.dart';
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
    final canAccessPremium = subProvider.canAccessPremiumTemplates;
    final defaults = InvoiceTemplate.getDefaultTemplates();

    // Fusion : modèles par défaut, puis ceux créés par l'admin (sans doublons)
    final adminIds = _adminTemplates.map((e) => e.id).toSet();
    final merged = [
      ...defaults.where((d) => !adminIds.contains(d.id)),
      ..._adminTemplates,
    ];

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
                      itemCount: merged.length,
                      itemBuilder: (context, index) {
                        final template = merged[index];
                        final isLocked =
                            template.isPremium && !canAccessPremium;
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(InvoiceTemplate template, bool isLocked) {
    if (isLocked) {
      _showUpgradeDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${template.name} sélectionné comme modèle actif'),
          backgroundColor: Colors.green,
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
