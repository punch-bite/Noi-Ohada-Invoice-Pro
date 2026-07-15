// lib/screens/dashboard/widgets/dashboard_charts.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../models/analytics_data.dart';

class DashboardCharts extends StatelessWidget {
  final List<SalesData> data;

  const DashboardCharts({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final primaryColor = themeProvider.primaryColor;

    // Si aucune donnée, afficher un message
    if (data.isEmpty) {
      return Card(
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Aucune donnée disponible',
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
              ),
            ),
          ),
        ),
      );
    }

    // Trouver la valeur max pour normaliser les hauteurs
    final maxRevenue = data.fold<double>(
      0,
      (max, item) => item.revenue > max ? item.revenue : max,
    );

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Évolution des revenus',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: Row(
                children: data.map((item) {
                  final height = maxRevenue > 0
                      ? (item.revenue / maxRevenue) * 120
                      : 0.0;
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 20,
                          height: height.clamp(0.0, 120.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                primaryColor,
                                primaryColor.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.month,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: subTextColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}