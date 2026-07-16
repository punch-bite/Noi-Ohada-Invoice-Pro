// lib/screens/customization/templates_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/invoice_template.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final subProvider = context.watch<SubscriptionProvider>();
    final canAccessPremium = subProvider.canAccessPremiumTemplates;
    final templates = InvoiceTemplate.getDefaultTemplates();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: _buildAppBar(context, theme, canAccessPremium),
      body: GridView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: templates.length,
        itemBuilder: (context, index) {
          final template = templates[index];
          final isLocked = template.isPremium && !canAccessPremium;
          return TemplateCard(
            template: template,
            isLocked: isLocked,
            onTap: () => _handleTemplateTap(context, template, isLocked, theme),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ThemeProvider theme, bool canAccess) {
    return AppBar(
      title: Text(
        'Modèles de Facture', 
        style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      backgroundColor: theme.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: theme.textColor, size: 20),
        onPressed: () => context.pop(),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Icon(
                canAccess ? Icons.stars_rounded : Icons.lock_outline_rounded, 
                size: 18, 
                color: canAccess ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                canAccess ? 'Accès Premium activé' : 'Modèles Premium verrouillés',
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.w600,
                  color: canAccess ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTemplateTap(BuildContext context, InvoiceTemplate template, bool isLocked, ThemeProvider theme) {
    if (isLocked) {
      _showUpgradeDialog(context, theme);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${template.name} sélectionné comme modèle actif'), 
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showUpgradeDialog(BuildContext context, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '⭐ Accès Premium requis',
          style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Passez à la formule supérieure pour débloquer l\'intégralité des designs exclusifs.',
          style: TextStyle(color: theme.subTextColor, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Voir les offres', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class TemplateCard extends StatelessWidget {
  final InvoiceTemplate template;
  final bool isLocked;
  final VoidCallback onTap;

  const TemplateCard({
    super.key, 
    required this.template, 
    required this.isLocked, 
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return Card(
      color: theme.cardColor,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: template.backgroundColor,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: template.primaryColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.description_outlined, 
                            color: template.primaryColor, 
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    if (isLocked)
                      Container(
                        color: Colors.black.withOpacity(0.4),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_rounded, 
                              color: Colors.white, 
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Text(
                template.name, 
                style: TextStyle(
                  fontWeight: FontWeight.w600, 
                  color: theme.textColor,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          ],
        ),
      ),
    );
  }
}