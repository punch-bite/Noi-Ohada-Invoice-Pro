// lib/screens/dashboard/dashboard_screen.dart
//
// 🎨 Coquille de navigation persistante (StatefulShellRoute).
//  - Mobile (<600px)   : bottom navigation persistante + drawer
//  - Tablette/Desktop : NavigationRail latéral + contenu centré
//
// La barre de navigation reste TOUJOURS visible car c'est cette coquille
// qui l'affiche ; les 5 onglets sont des branches d'un IndexedStack, donc
// leur état (scroll, formulaire…) est préservé quand on change d'onglet.
//
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/security_service.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/responsive_layout.dart';
import '../security/app_lock_screen.dart';

/// Coquille persistante du dashboard.
///
/// Reçoit le [StatefulNavigationShell] fourni par `StatefulShellRoute` :
/// elle dessine le chrome (drawer + barre de navigation ou rail) autour de
/// `navigationShell`, garantissant une navigation commune et persistante.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<String> _paths = [
    '/dashboard',
    '/dashboard/clients',
    '/dashboard/invoices',
    '/dashboard/analytics',
    '/dashboard/stock',
  ];

  void _onItemTapped(int index) {
    if (index < 0 || index >= _paths.length) return;
    // goBranch préserve l'état interne de chaque branche ; `initialLocation`
    // ramène à la racine de l'onglet si on retape sur l'onglet actif.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SecurityService.isAppProtectionEnabled(),
      builder: (context, snapshot) {
        final enabled = snapshot.data ?? false;
        if (enabled && !SecurityService.isUnlockedThisSession) {
          return AppLockScreen(onUnlocked: () {});
        }
        final isDesktop =
            MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;
        return isDesktop ? _buildDesktopLayout(context) : _buildMobileLayout(context);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MOBILE — bottom nav persistante + drawer
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final l10n = AppLocalizations.of(context);
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final cardColor = themeProvider.cardColor;
    final subTextColor = themeProvider.subTextColor;

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      drawer: const CustomDrawer(),
      body: navigationShell,
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
            backgroundColor: cardColor,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            height: 64,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onItemTapped,
            indicatorColor:
                primaryColor.withValues(alpha: isDark ? 0.22 : 0.14),
            indicatorShape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed) ||
                  states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)) {
                return primaryColor.withValues(alpha: 0.08);
              }
              return Colors.transparent;
            }),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              _navDestination(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: l10n.navHome,
                primaryColor: primaryColor,
                subTextColor: subTextColor,
              ),
              _navDestination(
                icon: Icons.people_outline,
                selectedIcon: Icons.people_rounded,
                label: l10n.navClients,
                primaryColor: primaryColor,
                subTextColor: subTextColor,
              ),
              _navDestination(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long_rounded,
                label: l10n.navInvoices,
                primaryColor: primaryColor,
                subTextColor: subTextColor,
              ),
              _navDestination(
                icon: Icons.trending_up_rounded,
                selectedIcon: Icons.trending_up_rounded,
                label: l10n.navAnalytics,
                primaryColor: primaryColor,
                subTextColor: subTextColor,
              ),
              _navDestination(
                icon: Icons.inventory_2_outlined,
                selectedIcon: Icons.inventory_2_rounded,
                label: l10n.navStock,
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
  //  DESKTOP — NavigationRail persistant
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final l10n = AppLocalizations.of(context);
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final cardColor = themeProvider.cardColor;
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
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
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onItemTapped,
              labelType: NavigationRailLabelType.all,
              indicatorColor: primaryColor.withValues(alpha: 0.14),
              selectedIconTheme: IconThemeData(color: primaryColor, size: 24),
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
                  tooltip: l10n.menuTooltip,
                  onPressed: () => scaffoldKey.currentState?.openDrawer(),
                ),
              ),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: Text(l10n.navHome),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.people_outline),
                  selectedIcon: const Icon(Icons.people_rounded),
                  label: Text(l10n.navClients),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.receipt_long_outlined),
                  selectedIcon: const Icon(Icons.receipt_long_rounded),
                  label: Text(l10n.navInvoices),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.trending_up_rounded),
                  selectedIcon: const Icon(Icons.trending_up_rounded),
                  label: Text(l10n.navAnalytics),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.inventory_2_outlined),
                  selectedIcon: const Icon(Icons.inventory_2_rounded),
                  label: Text(l10n.navStock),
                ),
              ],
            ),
          ),
          Expanded(child: navigationShell),
        ],
      ),
      drawer: const CustomDrawer(),
    );
  }
}
