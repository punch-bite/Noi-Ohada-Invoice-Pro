// lib/screens/support/support_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final bgColor = themeProvider.backgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Support',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSupportCard(
              context: context,
              icon: Icons.help_outline,
              title: 'FAQ',
              subtitle: 'Questions fréquemment posées',
              color: primaryColor,
              onTap: () => context.push('/support/faq'),
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              cardColor: cardColor,
            ),
            const SizedBox(height: 12),
            _buildSupportCard(
              context: context,
              icon: Icons.chat,
              title: 'Support en ligne',
              subtitle: 'Discuter avec notre équipe',
              color: const Color(0xFF4CAF50),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat support bientôt disponible'),
                  ),
                );
              },
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              cardColor: cardColor,
            ),
            const SizedBox(height: 12),
            _buildSupportCard(
              context: context,
              icon: Icons.email_outlined,
              title: 'Contacter le support',
              subtitle: 'support@ohada-invoice-pro.com',
              color: const Color(0xFF3949AB),
              onTap: () => context.push('/support/contact'),
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              cardColor: cardColor,
            ),
            const SizedBox(height: 12),
            _buildSupportCard(
              context: context,
              icon: Icons.feedback_outlined,
              title: 'Envoyer un retour',
              subtitle: 'Aidez-nous à améliorer l\'application',
              color: const Color(0xFFFF9800),
              onTap: () => context.push('/support/feedback'),
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              cardColor: cardColor,
            ),
            const SizedBox(height: 12),
            _buildSupportCard(
              context: context,
              icon: Icons.document_scanner_outlined,
              title: 'Guide d\'utilisation',
              subtitle: 'Télécharger le guide PDF',
              color: const Color(0xFF9C27B0),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Guide bientôt disponible'),
                  ),
                );
              },
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              cardColor: cardColor,
            ),
            const SizedBox(height: 12),
            _buildSupportCard(
              context: context,
              icon: Icons.check_circle_outline,
              title: 'Statut du service',
              subtitle: 'Tous les services sont opérationnels',
              color: Colors.green,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Tous les services sont opérationnels'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              cardColor: cardColor,
            ),
            const SizedBox(height: 24),

            // ===== DOCUMENTS LÉGAUX =====
            Row(
              children: [
                Icon(Icons.gavel_rounded, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Documents légaux',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSupportCard(
              context: context,
              icon: Icons.balance_rounded,
              title: 'Mentions légales',
              subtitle: 'Éditeur, hébergement, contact',
              color: const Color(0xFF546E7A),
              onTap: () => context.push('/support/legal/mentions'),
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              cardColor: cardColor,
            ),
            const SizedBox(height: 12),
            _buildSupportCard(
              context: context,
              icon: Icons.privacy_tip_outlined,
              title: 'Politique de confidentialité',
              subtitle: 'Données collectées et vos droits',
              color: const Color(0xFF00897B),
              onTap: () => context.push('/support/legal/privacy'),
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              cardColor: cardColor,
            ),
            const SizedBox(height: 12),
            _buildSupportCard(
              context: context,
              icon: Icons.description_outlined,
              title: 'Licence & Conditions',
              subtitle: 'Abonnement, CGU, garantie',
              color: const Color(0xFF6A1B9A),
              onTap: () => context.push('/support/legal/license'),
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              cardColor: cardColor,
            ),
            const SizedBox(height: 12),
            _buildSupportCard(
              context: context,
              icon: Icons.copyright_outlined,
              title: 'Propriété du produit digital',
              subtitle: 'Propriété intellectuelle et marques',
              color: const Color(0xFFC62828),
              onTap: () => context.push('/support/legal/ownership'),
              isDark: isDark,
              textColor: textColor,
              subTextColor: subTextColor,
              cardColor: cardColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
  }) {
    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: subTextColor,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: subTextColor,
        ),
        onTap: onTap,
      ),
    );
  }
}