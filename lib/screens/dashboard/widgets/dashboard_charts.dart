// lib/screens/dashboard/widgets/dashboard_charts.dart

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

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        width: 1,
      ),
    );

    // Si aucune donnée, afficher un message d'absence de données propre
    if (data.isEmpty) {
      return Card(
        color: cardColor,
        elevation: 0,
        shape: cardShape,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bar_chart_outlined, color: subTextColor, size: 36),
                const SizedBox(height: 8),
                Text(
                  'Aucune donnée disponible',
                  style: TextStyle(
                    fontSize: 14,
                    color: subTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Trouver la valeur max pour normaliser les hauteurs de manière sécurisée
    final maxRevenue = data.fold<double>(
      0,
      (max, item) => item.revenue > max ? item.revenue : max,
    );

    return Card(
      color: cardColor,
      elevation: 0,
      shape: cardShape,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Évolution des revenus',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Icon(
                  Icons.trending_up_rounded,
                  color: primaryColor,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: data.map((item) {
                  final height = maxRevenue > 0
                      ? (item.revenue / maxRevenue) * 120
                      : 0.0;
                  
                  // Formatage simplifié du montant pour le Tooltip
                  final formattedValue = '${item.revenue.toStringAsFixed(0)} FCFA';

                  return Expanded(
                    child: Tooltip(
                      message: '$formattedValue en ${item.month}',
                      triggerMode: TooltipTriggerMode.tap,
                      preferBelow: false,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Valeur textuelle éphémère au-dessus de la barre
                          Text(
                            item.revenue > 0 ? '${(item.revenue / 1000).toStringAsFixed(0)}k' : '0',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: subTextColor.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 22,
                            height: height.clamp(4.0, 120.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  primaryColor,
                                  primaryColor.withOpacity(0.7),
                                ],
                              ),
                              // Arrondi uniquement sur le haut pour préserver l'alignement sur la base du graphique
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.month,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: subTextColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
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