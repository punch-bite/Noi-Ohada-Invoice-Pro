// lib/screens/stock/products_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/stock_service.dart';
import '../../../models/product.dart';
import 'product_detail_screen.dart';
import 'create_product_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final StockService _stockService = StockService();
  List<Product> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filter = 'all'; // all, low, out

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    _products = await _stockService.getProducts();
    setState(() => _isLoading = false);
  }

  List<Product> get _filteredProducts {
    var filtered = _products;
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) =>
        p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p.category.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    switch (_filter) {
      case 'low':
        filtered = filtered.where((p) => p.isLowStock).toList();
        break;
      case 'out':
        filtered = filtered.where((p) => p.isOutOfStock).toList();
        break;
      default:
        break;
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final bgColor = themeProvider.backgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF151515) : Colors.white,
        elevation: 0,
        centerTitle: false,
        title: _isSearching
            ? Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un produit...',
                    hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search_rounded, color: subTextColor, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.close_rounded, color: subTextColor, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _isSearching = false;
                        });
                      },
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              )
            : Text(
                'Catalogue',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: Icon(Icons.search_rounded, color: textColor),
              onPressed: () => setState(() => _isSearching = true),
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list_rounded, color: textColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: _buildFilterItem('all', 'Tous les produits', primaryColor),
              ),
              PopupMenuItem(
                value: 'low',
                child: _buildFilterItem('low', 'Stock faible', primaryColor),
              ),
              PopupMenuItem(
                value: 'out',
                child: _buildFilterItem('out', 'Rupture de stock', primaryColor),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredProducts.isEmpty
              ? _buildEmptyState(isDark, textColor, subTextColor, primaryColor)
              : RefreshIndicator(
                  onRefresh: _loadProducts,
                  color: primaryColor,
                  strokeWidth: 2.5,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _buildProductCard(
                        product,
                        isDark,
                        textColor,
                        subTextColor,
                        primaryColor,
                        cardColor,
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateProductScreen()),
          ).then((_) => _loadProducts());
        },
        backgroundColor: primaryColor,
        elevation: 0,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Créer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFilterItem(String value, String label, Color primaryColor) {
    final isSelected = _filter == value;
    return Row(
      children: [
        if (isSelected)
          Icon(Icons.check_circle_rounded, color: primaryColor, size: 18)
        else
          const SizedBox(width: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(
    Product product,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    Color cardColor,
  ) {
    final isLow = product.isLowStock;
    final isOut = product.isOutOfStock;

    // Définition intelligente des couleurs thématiques du produit
    final Color statusColor = isOut 
        ? Colors.redAccent 
        : (isLow ? Colors.orange : Colors.green);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(0), // ✅ angles droits
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1.0,
        ),
        // ❌ boxShadow supprimé
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(productId: product.id),
            ),
          ).then((_) => _loadProducts());
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar stylisé avec dégradé doux de statut
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withOpacity(0.2),
                      statusColor.withOpacity(0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    product.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Détails textuels principaux
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
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                        ),
                      ),
                      child: Text(
                        product.category.isNotEmpty ? product.category.toUpperCase() : 'SANS CATÉGORIE',
                        style: TextStyle(
                          fontSize: 9,
                          color: subTextColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Section quantité et badge de statut
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${product.quantity} ${product.unit}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isOut ? 'RUPTURE' : (isLow ? 'STOCK FAIBLE' : 'EN STOCK'),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_rounded,
                size: 70,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun produit trouvé',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Aucun article ne correspond à votre recherche.'
                  : 'Enregistrez vos produits pour commencer à gérer votre stock avec précision.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: subTextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            if (_searchQuery.isEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateProductScreen()),
                  ).then((_) => _loadProducts());
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Créer un produit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}