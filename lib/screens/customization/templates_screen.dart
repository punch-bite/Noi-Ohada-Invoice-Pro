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
    final themeProvider = context.watch<ThemeProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final primaryColor = themeProvider.primaryColor;
    final bgColor = themeProvider.backgroundColor;
    final canAccessPremium = subscriptionProvider.canAccessPremiumTemplates;
    
    final templates = InvoiceTemplate.getDefaultTemplates();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Modèles de factures',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  canAccessPremium ? Icons.star : Icons.lock,
                  color: canAccessPremium ? Colors.amber : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  canAccessPremium
                      ? 'Tous les modèles sont débloqués'
                      : 'Abonnez-vous pour débloquer les modèles premium ⭐',
                  style: TextStyle(
                    fontSize: 12,
                    color: canAccessPremium ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: templates.length,
        itemBuilder: (context, index) {
          final template = templates[index];
          final isLocked = template.isPremium && !canAccessPremium;
          
          return _buildTemplateCard(
            context,
            template,
            isLocked,
            isDark,
            textColor,
            subTextColor,
            primaryColor,
          );
        },
      ),
    );
  }

  Widget _buildTemplateCard(
    BuildContext context,
    InvoiceTemplate template,
    bool isLocked,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    return GestureDetector(
      onTap: isLocked
          ? () => _showUpgradeDialog(context)
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Modèle ${template.name} sélectionné'),
                  backgroundColor: Colors.green,
                ),
              );
            },
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: template.isDefault
                    ? primaryColor
                    : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
                width: template.isDefault ? 2 : 1,
              ),
              boxShadow: [
                if (template.isDefault)
                  BoxShadow(
                    color: primaryColor.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Aperçu
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: template.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.receipt_long,
                        color: template.primaryColor,
                        size: 48,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        template.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (template.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'DÉFAUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  template.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // 🔥 Correction : suppression de secondaryColor, remplacement par une couleur dérivée
                    _buildColorDot(template.primaryColor),
                    const SizedBox(width: 4),
                    _buildColorDot(template.primaryColor.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    _buildColorDot(template.backgroundColor),
                    const SizedBox(width: 4),
                    _buildColorDot(template.textColor),
                    const Spacer(),
                    if (template.isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isLocked ? Colors.grey : Colors.amber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLocked ? Icons.lock : Icons.star,
                              size: 10,
                              color: isLocked ? Colors.white : Colors.black,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Premium',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: isLocked ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (isLocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('⭐ Template Premium'),
        content: const Text(
          'Ce template est réservé aux abonnés Pro et Business.\n\n'
          'Passez à un plan supérieur pour débloquer :\n'
          '• Tous les templates premium\n'
          '• Factures illimitées\n'
          '• Synchronisation cloud\n'
          '• Support prioritaire',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Voir les offres'),
          ),
        ],
      ),
    );
  }
}