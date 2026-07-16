// lib/screens/dashboard/widgets/dashboard_stats.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';

class DashboardStats extends StatelessWidget {
  final String revenue;
  final String orders;
  final String goal;
  final double revenueChange;
  final double ordersChange;

  const DashboardStats({
    super.key,
    required this.revenue,
    required this.orders,
    required this.goal,
    required this.revenueChange,
    required this.ordersChange,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final primaryColor = themeProvider.primaryColor;

    return Row(
      children: [
        _buildStatCard(
          label: 'Revenus',
          value: revenue,
          change: revenueChange,
          icon: Icons.account_balance_wallet_outlined,
          color: isDark ? const Color(0xFF9FA8DA) : const Color(0xFF1A237E), // Bleu contrasté
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
          cardColor: cardColor,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          label: 'Commandes',
          value: orders,
          change: ordersChange,
          icon: Icons.shopping_bag_outlined,
          color: const Color(0xFF4CAF50), // Vert stable
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
          cardColor: cardColor,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          label: 'Objectif',
          value: goal,
          change: 8.2, // Valeur fixe ou dynamique
          icon: Icons.track_changes_rounded,
          color: const Color(0xFFFF9800), // Orange stable
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
          cardColor: cardColor,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required double change,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
  }) {
    final isPositive = change >= 0;
    final badgeColor = isPositive ? Colors.green : Colors.red;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: subTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  icon,
                  size: 16,
                  color: color.withOpacity(0.8),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                // Utilisation d'une opacité dynamique pour s'adapter au Dark Mode sans délaver la couleur
                color: badgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: badgeColor,
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${change.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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