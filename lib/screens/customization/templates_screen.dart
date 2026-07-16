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
            onTap: () => _handleTemplateTap(context, template, isLocked),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ThemeProvider theme, bool canAccess) {
    return AppBar(
      title: Text('Modèles', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
      backgroundColor: theme.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: theme.textColor),
        onPressed: () => context.pop(),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(canAccess ? Icons.star : Icons.lock, size: 16, color: canAccess ? Colors.green : Colors.orange),
              const SizedBox(width: 8),
              Text(
                canAccess ? 'Accès Premium activé' : 'Modèles Premium verrouillés',
                style: TextStyle(fontSize: 12, color: canAccess ? Colors.green : Colors.orange),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTemplateTap(BuildContext context, InvoiceTemplate template, bool isLocked) {
    if (isLocked) {
      _showUpgradeDialog(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${template.name} sélectionné'), backgroundColor: Colors.green),
      );
    }
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accès Premium requis'),
        content: const Text('Passez à un abonnement supérieur pour débloquer tous les modèles.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            child: const Text('Voir les offres'),
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

  const TemplateCard({super.key, required this.template, required this.isLocked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.isDarkMode ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primaryColor.withOpacity(isLocked ? 0.1 : 0.3)),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: template.backgroundColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(child: Icon(Icons.receipt_long, color: template.primaryColor, size: 40)),
                  ),
                  if (isLocked)
                    Container(color: Colors.black45, child: const Center(child: Icon(Icons.lock, color: Colors.white, size: 30))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(template.name, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textColor)),
            )
          ],
        ),
      ),
    );
  }
}