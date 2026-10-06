// lib/screens/dashboard/suppliers/suppliers_screen.dart
//
// 🎨 Refonte moderne de la liste des fournisseurs.
// Logique inchangée — UI repensée (hero header, search premium,
// chips animées, cards avec avatars, FAB gradient).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart'; 
import '../../../providers/theme_provider.dart';
import '../../../services/supplier_service.dart';
import '../../../services/stock_service.dart';
import '../../../models/supplier.dart';
import 'create_supplier_screen.dart';
import 'supplier_detail_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final SupplierService _supplierService = SupplierService();
  final StockService _stockService = StockService();
  final TextEditingController _searchController = TextEditingController();
  List<Supplier> _suppliers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool? _filterActive;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    await _supplierService.init();
    await _stockService.init();
    final suppliers = await _supplierService.getSuppliers();

    if (!mounted) return;
    setState(() {
      _suppliers = suppliers;
      _isLoading = false;
    });
  }

  List<Supplier> get _filteredSuppliers {
    var result = _suppliers;
    if (_filterActive != null) {
      result = result.where((s) => s.isActive == _filterActive).toList();
    }
    if (_searchQuery.isEmpty) return result;
    final query = _searchQuery.toLowerCase().trim();
    return result
        .where((s) =>
            s.name.toLowerCase().contains(query) ||
            s.email.toLowerCase().contains(query) ||
            s.phone.contains(query))
        .toList();
  }

  int get _activeCount => _suppliers.where((s) => s.isActive).length;
  int get _inactiveCount => _suppliers.length - _activeCount;

  // ======================================================================
  //  BUILD
  // ======================================================================
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(theme, isDark, text, sub, primary),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: primary))
                  : _filteredSuppliers.isEmpty
                      ? _buildEmptyState(
                          isDark, text, sub, primary, theme.cardColor)
                      : RefreshIndicator(
                          onRefresh: _loadSuppliers,
                          color: primary,
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            children: [
                              _buildStatsRow(
                                  isDark, text, sub, primary, theme.cardColor),
                              const SizedBox(height: 16),
                              _buildFilterChips(
                                  isDark, text, sub, primary, theme.cardColor),
                              const SizedBox(height: 16),
                              for (var i = 0;
                                  i < _filteredSuppliers.length;
                                  i++)
                                _buildSupplierCard(
                                  _filteredSuppliers[i],
                                  i,
                                  isDark,
                                  text,
                                  sub,
                                  theme.cardColor,
                                  primary,
                                ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(primary),
    );
  }

  // ======================================================================
  //  TOP BAR moderne
  // ======================================================================
  Widget _buildTopBar(
    ThemeProvider theme,
    bool isDark,
    Color text,
    Color sub,
    Color primary,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Ligne : retour + titre + refresh
          Row(
            children: [
              _iconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                color: text,
                onTap: () => context.go('/dashboard'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fournisseurs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_suppliers.length} partenaire${_suppliers.length > 1 ? 's' : ''} enregistré${_suppliers.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: sub,
                      ),
                    ),
                  ],
                ),
              ),
              _iconBtn(
                icon: Icons.refresh_rounded,
                color: text,
                onTap: _loadSuppliers,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Barre de recherche premium
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
                width: 1,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: text,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: primary,
              onChanged: (q) => setState(() => _searchQuery = q),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, email ou téléphone…',
                hintStyle: TextStyle(
                  color: sub.withValues(alpha: 0.7),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: sub,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: sub,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  // ======================================================================
  //  STATS ROW
  // ======================================================================
  Widget _buildStatsRow(
    bool isDark,
    Color text,
    Color sub,
    Color primary,
    Color card,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniStat(
            label: 'Total',
            value: '${_suppliers.length}',
            color: primary,
            icon: Icons.business_rounded,
            isDark: isDark,
            text: text,
            sub: sub,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStat(
            label: 'Actifs',
            value: '$_activeCount',
            color: const Color(0xFF10B981),
            icon: Icons.check_circle_outline_rounded,
            isDark: isDark,
            text: text,
            sub: sub,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStat(
            label: 'Inactifs',
            value: '$_inactiveCount',
            color: const Color(0xFF94A3B8),
            icon: Icons.pause_circle_outline_rounded,
            isDark: isDark,
            text: text,
            sub: sub,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required bool isDark,
    required Color text,
    required Color sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.10)
            : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.20 : 0.14),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : text,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.65)
                  : sub,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  //  FILTRES CHIPS
  // ======================================================================
  Widget _buildFilterChips(
    bool isDark,
    Color text,
    Color sub,
    Color primary,
    Color card,
  ) {
    final filters = [
      ('Tous', null, Icons.apps_rounded, _suppliers.length),
      ('Actifs', true, Icons.check_circle_rounded, _activeCount),
      ('Inactifs', false, Icons.pause_circle_rounded, _inactiveCount),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, value, icon, count) = filters[i];
          final isSel = _filterActive == value;
          return GestureDetector(
            onTap: () => setState(() => _filterActive = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSel
                    ? primary
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSel
                      ? primary
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06)),
                  width: 1,
                ),
                boxShadow: isSel
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: isSel ? Colors.white : sub,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      color: isSel ? Colors.white : text,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSel
                          ? Colors.white.withValues(alpha: 0.22)
                          : primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isSel ? Colors.white : primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ======================================================================
  //  CARTE FOURNISSEUR
  // ======================================================================
  Widget _buildSupplierCard(
    Supplier supplier,
    int index,
    bool isDark,
    Color text,
    Color sub,
    Color card,
    Color primary,
  ) {
    final isActive = supplier.isActive;
    final initial = supplier.name.isNotEmpty
        ? supplier.name[0].toUpperCase()
        : '?';
    final accentColor = isActive
        ? primary
        : const Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SupplierDetailScreen(supplier: supplier),
              ),
            ).then((_) => _loadSuppliers());
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
                width: 1,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Avatar premium
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor,
                        accentColor.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Contenu
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              supplier.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: text,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (!isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Inactif',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: sub,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Ligne contact
                      if (supplier.phone.isNotEmpty || supplier.email.isNotEmpty)
                        Row(
                          children: [
                            if (supplier.phone.isNotEmpty) ...[
                              Icon(
                                Icons.phone_rounded,
                                size: 11,
                                color: sub,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  supplier.phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: sub,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            if (supplier.phone.isNotEmpty &&
                                supplier.email.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '•',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: sub.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            if (supplier.email.isNotEmpty)
                              Expanded(
                                child: Text(
                                  supplier.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: sub,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        )
                      else
                        Text(
                          'Aucun contact renseigné',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: sub.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),

                // Menu actions
                _buildSupplierMenu(supplier, text, sub),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: 40 * index),
          duration: 300.ms,
        );
  }

  Widget _buildSupplierMenu(Supplier supplier, Color text, Color sub) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: sub, size: 20),
      onSelected: (value) {
        if (value == 'edit') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CreateSupplierScreen(supplier: supplier),
            ),
          ).then((_) => _loadSuppliers());
        } else if (value == 'delete') {
          _deleteSupplier(supplier);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 10),
              Text('Modifier'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }

  // ======================================================================
  //  FAB gradient
  // ======================================================================
  Widget _buildFAB(Color primary) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary,
            primary.withValues(alpha: 0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CreateSupplierScreen()),
            ).then((_) => _loadSuppliers());
          },
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 58,
            height: 58,
            child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }

  // ======================================================================
  //  DELETE
  // ======================================================================
  Future<void> _deleteSupplier(Supplier supplier) async {
    final hasProducts =
        await _stockService.hasProductsForSupplier(supplier.id);
    if (!mounted) return;

    if (hasProducts) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Impossible de supprimer : fournisseur lié à des produits',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer le fournisseur'),
        content: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black87,
            ),
            children: [
              const TextSpan(text: 'Voulez-vous vraiment supprimer '),
              TextSpan(
                text: '"${supplier.name}"',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: ' ?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supplierService.deleteSupplier(supplier.id);
      await _loadSuppliers();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Fournisseur supprimé'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ======================================================================
  //  EMPTY STATE
  // ======================================================================
  Widget _buildEmptyState(
    bool isDark,
    Color text,
    Color sub,
    Color primary,
    Color card,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primary.withValues(alpha: 0.18),
                    primary.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business_rounded,
                size: 46,
                color: primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun fournisseur',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: text,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Ajoutez votre premier fournisseur\npour l\'associer à vos produits.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: sub,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withValues(alpha: 0.75)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CreateSupplierScreen()),
                  ).then((_) => _loadSuppliers());
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Ajouter un fournisseur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}