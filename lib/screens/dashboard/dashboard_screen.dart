// lib/screens/dashboard/dashboard_screen.dart
//
// 🎨 Refonte minimaliste responsive.
//  - Mobile (<600px)   : bottom navigation + drawer
//  - Tablette/Desktop : NavigationRail latéral + contenu centré
//
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/security_service.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/responsive_layout.dart';
import '../security/app_lock_screen.dart';
import 'dashboard_home.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const List<String> _paths = [
    '/dashboard',
    '/dashboard/clients',
    '/dashboard/invoices',
    '/dashboard/analytics',
    '/dashboard/stock',
  ];

  void _onItemTapped(int index) {
    if (index < 0 || index >= _paths.length) return;
    context.go(_paths[index]);
  }

  Future<bool>? _lockCheck;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lockCheck = SecurityService.isAppProtectionEnabled();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;

    return FutureBuilder<bool>(
      future: _lockCheck,
      builder: (context, snapshot) {
        final enabled = snapshot.data ?? false;
        if (enabled && !SecurityService.isUnlockedThisSession) {
          return AppLockScreen(onUnlocked: () => setState(() {}));
        }
        return isDesktop
            ? _buildDesktopLayout(context)
            : _buildMobileLayout(context);
      },
    );
  }

  // ===== MOBILE : bottom nav + drawer =====
  Widget _buildMobileLayout(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final cardColor = themeProvider.cardColor;
    _syncIndexFromRoute(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: themeProvider.backgroundColor,
      drawer: const CustomDrawer(),
      body: const DashboardHome(),
      bottomNavigationBar: NavigationBar(
        backgroundColor: cardColor,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        indicatorColor: primaryColor.withValues(alpha: 0.14),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined,
                color: isDark ? Colors.grey[500] : Colors.grey[400]),
            selectedIcon: Icon(Icons.home, color: primaryColor),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline,
                color: isDark ? Colors.grey[500] : Colors.grey[400]),
            selectedIcon: Icon(Icons.people, color: primaryColor),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined,
                color: isDark ? Colors.grey[500] : Colors.grey[400]),
            selectedIcon: Icon(Icons.receipt_long, color: primaryColor),
            label: 'Factures',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up,
                color: isDark ? Colors.grey[500] : Colors.grey[400]),
            selectedIcon: Icon(Icons.trending_up, color: primaryColor),
            label: 'Analyses',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined,
                color: isDark ? Colors.grey[500] : Colors.grey[400]),
            selectedIcon: Icon(Icons.inventory_2, color: primaryColor),
            label: 'Stock',
          ),
        ],
      ),
    );
  }

  // ===== DESKTOP : NavigationRail + Drawer =====
  Widget _buildDesktopLayout(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final primaryColor = themeProvider.primaryColor;
    _syncIndexFromRoute(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: themeProvider.backgroundColor,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            labelType: NavigationRailLabelType.all,
            leading: IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Accueil'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Clients'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Factures'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.trending_up),
                label: Text('Analyses'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Stock'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          const Expanded(child: DashboardHome()),
        ],
      ),
      drawer: const CustomDrawer(),
    );
  }

  void _syncIndexFromRoute(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final idx = _paths.indexOf(location);
    if (idx >= 0 && idx != _selectedIndex) {
      _selectedIndex = idx;
    }
  }
}
