// lib/screens/dashboard/stock/stock_screen.dart
//
// 📦 Gestion de stock épurée — cartes résumé, liste fluide, feedback animé.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:noi_ohada_invoice_pro/screens/dashboard/stock/create_product_screen.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/stock_service.dart';
import '../../../models/product.dart';
import '../../../widgets/logo_image.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final StockService _stockService = StockService();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  bool _isInitialized = false;
  String _searchQuery = '';
  String? _selectedCategory;
  String _sortOption = 'name';

  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  List<String> get _categories {
    final cats = _products
        .map((p) => p.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    cats.sort();
    return cats;
  }

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoad() async {
    if (!_isInitialized) {
      await _stockService.init();
      _isInitialized = true;
    }
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      _products = await _stockService.getProducts();
      _applyFiltersAndSort();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur chargement : $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() => _filteredProducts = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndSort() {
    var list = List<Product>.from(_products);

    if (_searchQuery.isNotEmpty) {
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (p.barcode?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                  false))
          .toList();
    }

    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      list = list.where((p) => p.category == _selectedCategory).toList();
    }

    switch (_sortOption) {
      case 'price':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'quantity':
        list.sort((a, b) => a.quantity.compareTo(b.quantity));
        break;
      case 'name':
      default:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }

    setState(() => _filteredProducts = list);
  }

  Future<void> _updateQuantity(Product product, int delta) async {
    final newQuantity = product.quantity + delta;
    if (newQuantity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('La quantité ne peut pas être négative'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    try {
      final updated = product.copyWith(
        quantity: newQuantity,
        updatedAt: DateTime.now(),
      );
      await _stockService.updateProduct(updated);
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = updated;
        _applyFiltersAndSort();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur mise à jour : $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Supprimer ?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Voulez-vous vraiment supprimer définitivement "${product.name}" ?'),
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
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _stockService.deleteProduct(product.id);
        await _loadProducts();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Produit supprimé'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur suppression : $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showLowStockDialog(List<Product> lowStock) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
            SizedBox(width: 10),
            Text('Stock critique', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: lowStock.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final p = lowStock[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: p.statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      p.name[0].toUpperCase(),
                      style: TextStyle(
                          color: p.statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                title: Text(p.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('En stock : ${p.quantity} (Seuil : ${p.minStock})'),
                trailing: Text(p.formattedPrice,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final bgColor = theme.backgroundColor;
    final primaryColor = theme.primaryColor;
    final cardColor = theme.cardColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(
        isDark: isDark,
        textColor: textColor,
        subTextColor: subTextColor,
        primaryColor: primaryColor,
      ),
      body: Column(
        children: [
          _buildStockAlertBanner(subTextColor),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : _filteredProducts.isEmpty
                    ? _buildEmptyState(
                        isDark, textColor, subTextColor, primaryColor)
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        color: primaryColor,
                        backgroundColor: cardColor,
                        strokeWidth: 2.5,
                        child: ListView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                          children: [
                            _buildSummaryCards(
                              isDark,
                              textColor,
                              subTextColor,
                              primaryColor,
                            ).animate().fadeIn(duration: 400.ms).slideY(
                                  begin: 0.1,
                                  end: 0,
                                  curve: Curves.easeOut,
                                  duration: 400.ms,
                                ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Text(
                                  'Inventaire',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${_filteredProducts.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(
                                  delay: 100.ms, duration: 400.ms),
                            const SizedBox(height: 12),
                            ..._filteredProducts.asMap().entries.map((entry) {
                              final index = entry.key;
                              final product = entry.value;
                              return _buildProductCard(
                                product,
                                isDark,
                                textColor,
                                subTextColor,
                                cardColor,
                                primaryColor,
                              )
                                  .animate()
                                  .fadeIn(
                                    delay: Duration(
                                        milliseconds: 150 + (index * 40)),
                                    duration: 400.ms,
                                  )
                                  .slideY(
                                    begin: 0.06,
                                    end: 0,
                                    curve: Curves.easeOut,
                                    duration: 400.ms,
                                  );
                            }),
                          ],
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CreateProductScreen()),
          );
          if (mounted) _loadProducts();
        },
        backgroundColor: primaryColor,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Produit',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color primaryColor,
  }) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: textColor, size: 20),
        onPressed: () => context.go('/dashboard'),
      ),
      title: _isSearching
          ? Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher…',
                  hintStyle: TextStyle(color: subTextColor, fontSize: 13.5),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search_rounded,
                      color: subTextColor, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: subTextColor, size: 18),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _isSearching = false;
                        _applyFiltersAndSort();
                      });
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (q) {
                  setState(() {
                    _searchQuery = q;
                    _applyFiltersAndSort();
                  });
                },
              ),
            )
          : Text(
              'Stock',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 19,
                letterSpacing: -0.3,
              ),
            ),
      actions: [
        if (!_isSearching)
          IconButton(
            icon: Icon(Icons.search_rounded, color: textColor, size: 22),
            onPressed: () => setState(() => _isSearching = true),
          ),
        PopupMenuButton<String>(
          icon: Icon(Icons.filter_list_rounded, color: textColor, size: 22),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          onSelected: (v) {
            setState(() {
              _selectedCategory = v.isEmpty ? null : v;
              _applyFiltersAndSort();
            });
          },
          itemBuilder: (context) {
            final items = <PopupMenuItem<String>>[
              const PopupMenuItem(
                  value: '', child: Text('Toutes les catégories')),
            ];
            for (final cat in _categories) {
              items.add(PopupMenuItem(
                value: cat,
                child: Row(
                  children: [
                    if (_selectedCategory == cat)
                      Icon(Icons.check_rounded,
                          color: primaryColor, size: 16),
                    if (_selectedCategory == cat) const SizedBox(width: 8),
                    Text(cat),
                  ],
                ),
              ));
            }
            return items;
          },
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.sort_rounded, color: textColor, size: 22),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          onSelected: (v) {
            setState(() {
              _sortOption = v;
              _applyFiltersAndSort();
            });
          },
          itemBuilder: (context) => [
            PopupMenuItem(
                value: 'name', child: _buildSortItem('name', 'Nom', primaryColor)),
            PopupMenuItem(
                value: 'price',
                child: _buildSortItem('price', 'Prix', primaryColor)),
            PopupMenuItem(
                value: 'quantity',
                child: _buildSortItem('quantity', 'Quantité', primaryColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildStockAlertBanner(Color subTextColor) {
    final lowStock = _products.where((p) => p.isLowStock).toList();
    if (lowStock.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: Color(0xFFF59E0B), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${lowStock.length} produit${lowStock.length > 1 ? 's' : ''} en alerte stock',
              style: const TextStyle(
                color: Color(0xFFB45309),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _showLowStockDialog(lowStock),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF59E0B),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Voir',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(
          begin: -0.3,
          end: 0,
          duration: 300.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildSummaryCards(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    final total = _products.length;
    final alertCount =
        _products.where((p) => p.isLowStock || p.isOutOfStock).length;
    final totalValue =
        _products.fold<double>(0, (sum, p) => sum + (p.price * p.quantity));

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.inventory_2_rounded,
                label: 'Produits',
                value: '$total',
                color: const Color(0xFF4F46E5),
                isDark: isDark,
                textColor: textColor,
                subTextColor: subTextColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.warning_amber_rounded,
                label: 'Alertes',
                value: '$alertCount',
                color: const Color(0xFFEF4444),
                isDark: isDark,
                textColor: textColor,
                subTextColor: subTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Valeur du stock',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${totalValue.toStringAsFixed(0)} FCFA',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D26) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: subTextColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortItem(String option, String title, Color primaryColor) {
    final isSelected = _sortOption == option;
    return Row(
      children: [
        if (isSelected)
          Icon(Icons.check_circle_rounded, color: primaryColor, size: 18)
        else
          const SizedBox(width: 18),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildProductCard(
    Product product,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color primaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await context.push('/dashboard/stock/products/${product.id}');
              if (mounted) _loadProducts();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              product.statusColor.withValues(alpha: 0.20),
                              product.statusColor.withValues(alpha: 0.06),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: product.imagePath != null &&
                                  product.imagePath!.isNotEmpty
                              ? LogoImage(
                                  path: product.imagePath,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                )
                              : Center(
                                  child: Text(
                                    product.name[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: product.statusColor,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Infos
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (product.barcode != null &&
                                product.barcode!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'RÉF · ${product.barcode}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: subTextColor,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (product.category.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          primaryColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      product.category.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: primaryColor,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: product.statusColor
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    product.statusLabel.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: product.statusColor,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Menu contextuel
                      SizedBox(
                        width: 30,
                        child: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded,
                              color: subTextColor, size: 20),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          onSelected: (v) {
                            if (v == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CreateProductScreen(product: product),
                                ),
                              ).then((_) => _loadProducts());
                            } else if (v == 'delete') {
                              _deleteProduct(product);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Modifier'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline,
                                      color: Colors.redAccent, size: 18),
                                  SizedBox(width: 8),
                                  Text('Supprimer',
                                      style: TextStyle(color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Ligne prix + valeur
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniInfo(
                          label: 'Prix',
                          value: product.formattedPrice,
                          color: primaryColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniInfo(
                          label: 'Valeur',
                          value: product.formattedStockValue,
                          color: product.statusColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Contrôle quantité
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_rounded,
                                  size: 16, color: subTextColor),
                              onPressed: () => _updateQuantity(product, -1),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 34, minHeight: 34),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                '${product.quantity}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: textColor,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_rounded,
                                  size: 16, color: primaryColor),
                              onPressed: () => _updateQuantity(product, 1),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 34, minHeight: 34),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniInfo({
    required String label,
    required String value,
    required Color color,
    required Color textColor,
    required Color subTextColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    final isFiltered = _searchQuery.isNotEmpty || _selectedCategory != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.15),
                    primaryColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(Icons.inventory_2_rounded,
                  size: 44, color: primaryColor),
            ).animate().scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                  duration: 500.ms,
                ),
            const SizedBox(height: 24),
            Text(
              isFiltered ? 'Aucun résultat' : 'Inventaire vide',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Essayez d\'autres mots-clés ou filtres.'
                  : 'Ajoutez votre premier produit pour commencer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: subTextColor, height: 1.5),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CreateProductScreen()),
                  );
                  if (mounted) _loadProducts();
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nouveau produit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}