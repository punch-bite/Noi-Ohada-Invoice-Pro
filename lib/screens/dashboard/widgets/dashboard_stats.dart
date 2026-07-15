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

    return Row(
      children: [
        _buildStatCard(
          label: 'Revenus',
          value: revenue,
          change: revenueChange,
          color: const Color(0xFF1A237E),
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
          color: const Color(0xFF4CAF50),
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
          cardColor: cardColor,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          label: 'Objectif',
          value: goal,
          change: 8.2,
          color: const Color(0xFFFF9800),
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
    required Color color,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
  }) {
    final isPositive = change >= 0;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isPositive ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isPositive ? Colors.green : Colors.red,
                    size: 10,
                  ),
                  Text(
                    '${change.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
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