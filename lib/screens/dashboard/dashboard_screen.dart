// lib/screens/dashboard/dashboard_screen.dart
//
// 🎨 Navigation épurée et fluide.
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
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
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
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;

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

  // ═══════════════════════════════════════════════════════════════════
  //  MOBILE — bottom nav animé + drawer
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final cardColor = themeProvider.cardColor;
    final subTextColor = themeProvider.subTextColor;
    _syncIndexFromRoute(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: themeProvider.backgroundColor,
      drawer: const CustomDrawer(),
      body: const DashboardHome(),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 64,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            indicatorColor: primaryColor.withValues(alpha: 0.14),
            labelBehavior:
                NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              _navDestination(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Accueil',
                primaryColor: primaryColor,
                subTextColor: subTextColor,
              ),
              _navDestination(
                icon: Icons.people_outline,
                selectedIcon: Icons.people_rounded,
                label: 'Clients',
                primaryColor: primaryColor,
                subTextColor: subTextColor,
              ),
              _navDestination(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long_rounded,
                label: 'Factures',
                primaryColor: primaryColor,
                subTextColor: subTextColor,
              ),
              _navDestination(
                icon: Icons.trending_up_rounded,
                selectedIcon: Icons.trending_up_rounded,
                label: 'Analyses',
                primaryColor: primaryColor,
                subTextColor: subTextColor,
              ),
              _navDestination(
                icon: Icons.inventory_2_outlined,
                selectedIcon: Icons.inventory_2_rounded,
                label: 'Stock',
                primaryColor: primaryColor,
                subTextColor: subTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  NavigationDestination _navDestination({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required Color primaryColor,
    required Color subTextColor,
  }) {
    return NavigationDestination(
      icon: Icon(icon, color: subTextColor.withValues(alpha: 0.6)),
      selectedIcon: Icon(selectedIcon, color: primaryColor),
      label: label,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  DESKTOP — NavigationRail épuré
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final cardColor = themeProvider.cardColor;
    _syncIndexFromRoute(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: themeProvider.backgroundColor,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(
                right: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  width: 1,
                ),
              ),
            ),
            child: NavigationRail(
              backgroundColor: Colors.transparent,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              labelType: NavigationRailLabelType.all,
              indicatorColor: primaryColor.withValues(alpha: 0.14),
              selectedIconTheme:
                  IconThemeData(color: primaryColor, size: 24),
              unselectedIconTheme: IconThemeData(
                color: themeProvider.subTextColor.withValues(alpha: 0.6),
                size: 22,
              ),
              selectedLabelTextStyle: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: themeProvider.subTextColor,
                fontWeight: FontWeight.w500,
                fontSize: 11.5,
              ),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: IconButton(
                  icon: Icon(Icons.menu_rounded,
                      color: themeProvider.textColor),
                  tooltip: 'Menu',
                  onPressed: () =>
                      _scaffoldKey.currentState?.openDrawer(),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('Accueil'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people_rounded),
                  label: Text('Clients'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: Text('Factures'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.trending_up_rounded),
                  selectedIcon: Icon(Icons.trending_up_rounded),
                  label: Text('Analyses'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2_rounded),
                  label: Text('Stock'),
                ),
              ],
            ),
          ),
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
      // Reporté au prochain frame pour éviter setState pendant build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && idx != _selectedIndex) {
          setState(() => _selectedIndex = idx);
        }
      });
    }
  }
}