// lib/screens/dashboard/dashboard_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/custom_drawer.dart';
import 'dashboard_home.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/dashboard/clients');
        break;
      case 2:
        context.go('/dashboard/invoices');
        break;
      case 3:
        context.go('/dashboard/analytics');
        break;
      case 4:
        context.go('/dashboard/stock');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final cardColor = themeProvider.cardColor;

    final location = GoRouterState.of(context).uri.path;
    if (location == '/dashboard') {
      _selectedIndex = 0;
    } else if (location == '/dashboard/clients') {
      _selectedIndex = 1;
    } else if (location == '/dashboard/invoices') {
      _selectedIndex = 2;
    } else if (location == '/dashboard/analytics') {
      _selectedIndex = 3;
    } else if (location == '/dashboard/stock') {
      _selectedIndex = 4;
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: themeProvider.backgroundColor,
      drawer: const CustomDrawer(),
      // 🔥 AppBar supprimée (déplacée dans DashboardHome)
      body: const DashboardHome(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home,
                  label: 'Accueil',
                  index: 0,
                  selected: _selectedIndex == 0,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
                _buildNavItem(
                  icon: Icons.people,
                  label: 'Clients',
                  index: 1,
                  selected: _selectedIndex == 1,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
                _buildNavItem(
                  icon: Icons.receipt_long,
                  label: 'Factures',
                  index: 2,
                  selected: _selectedIndex == 2,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
                _buildNavItem(
                  icon: Icons.trending_up,
                  label: 'Analyses',
                  index: 3,
                  selected: _selectedIndex == 3,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
                _buildNavItem(
                  icon: Icons.inventory_2,
                  label: 'Stock',
                  index: 4,
                  selected: _selectedIndex == 4,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool selected,
    required bool isDark,
    required Color primaryColor,
  }) {
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected ? primaryColor.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: selected ? primaryColor : (isDark ? Colors.grey[500] : Colors.grey[400]),
              size: 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: selected ? primaryColor : (isDark ? Colors.grey[500] : Colors.grey[400]),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}