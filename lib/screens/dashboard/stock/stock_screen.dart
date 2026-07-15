// lib/screens/dashboard/stock/stock_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:noi_ohada_invoice_pro/screens/dashboard/stock/create_product_screen.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/stock_service.dart';
import '../../../models/product.dart';

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
  String _sortOption = 'name'; // name, price, quantity

  final ScrollController _scrollController = ScrollController();

  // Catégories uniques
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur chargement: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _filteredProducts = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndSort() {
    var list = List<Product>.from(_products);

    // Filtre recherche (nom + référence)
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) =>
        p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (p.barcode?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    // Filtre catégorie
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      list = list.where((p) => p.category == _selectedCategory).toList();
    }

    // Tri
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

  // Mise à jour rapide de la quantité
  Future<void> _updateQuantity(Product product, int delta) async {
    final newQuantity = product.quantity + delta;
    if (newQuantity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La quantité ne peut pas être négative'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      final updatedProduct = product.copyWith(
        quantity: newQuantity,
        updatedAt: DateTime.now(),
      );
      await _stockService.updateProduct(updatedProduct);
      // Mettre à jour la liste locale
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = updatedProduct;
        _applyFiltersAndSort();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur mise à jour: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer le produit'),
        content: Text('Voulez-vous vraiment supprimer "${product.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _stockService.deleteProduct(product.id);
        await _loadProducts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produit supprimé'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLowStockDialog(List<Product> lowStock) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Produits en stock faible'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: lowStock.length,
            itemBuilder: (context, index) {
              final product = lowStock[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: product.statusColor,
                  child: Text(product.name[0].toUpperCase()),
                ),
                title: Text(product.name),
                subtitle: Text(
                  'Qté: ${product.quantity} • Seuil: ${product.minStock}',
                ),
                trailing: Text(
                  product.formattedPrice,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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

  Widget _buildStockAlertBanner() {
    final lowStock = _products.where((p) => p.isLowStock).toList();
    if (lowStock.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.orange.shade100,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${lowStock.length} produit(s) en stock faible',
              style: TextStyle(color: Colors.orange.shade800),
            ),
          ),
          TextButton(
            onPressed: () => _showLowStockDialog(lowStock),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange.shade800,
              padding: EdgeInsets.zero,
            ),
            child: const Text('Voir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final bgColor = themeProvider.backgroundColor;
    final primaryColor = themeProvider.primaryColor;
    final cardColor = themeProvider.cardColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.go('/dashboard'),
        ),
        title: TextField(
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Rechercher (nom, référence)',
            hintStyle: TextStyle(color: subTextColor),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: subTextColor),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          onChanged: (query) {
            setState(() {
              _searchQuery = query;
              _applyFiltersAndSort();
            });
          },
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        actions: [
          // Filtre par catégorie
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: textColor),
            onSelected: (value) {
              setState(() {
                _selectedCategory = value.isEmpty ? null : value;
                _applyFiltersAndSort();
              });
            },
            itemBuilder: (context) {
              final items = <PopupMenuItem<String>>[
                const PopupMenuItem(
                  value: '',
                  child: Text('Toutes les catégories'),
                ),
              ];
              for (final cat in _categories) {
                items.add(PopupMenuItem(
                  value: cat,
                  child: Row(
                    children: [
                      if (_selectedCategory == cat)
                        Icon(Icons.check, color: primaryColor, size: 16),
                      const SizedBox(width: 8),
                      Text(cat),
                    ],
                  ),
                ));
              }
              return items;
            },
          ),
          // Tri
          PopupMenuButton<String>(
            icon: Icon(Icons.sort, color: textColor),
            onSelected: (value) {
              setState(() {
                _sortOption = value;
                _applyFiltersAndSort();
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    if (_sortOption == 'name')
                      Icon(Icons.check, color: primaryColor, size: 16),
                    const SizedBox(width: 8),
                    const Text('Nom'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'price',
                child: Row(
                  children: [
                    if (_sortOption == 'price')
                      Icon(Icons.check, color: primaryColor, size: 16),
                    const SizedBox(width: 8),
                    const Text('Prix'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'quantity',
                child: Row(
                  children: [
                    if (_sortOption == 'quantity')
                      Icon(Icons.check, color: primaryColor, size: 16),
                    const SizedBox(width: 8),
                    const Text('Quantité'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStockAlertBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? _buildEmptyState(isDark, textColor, subTextColor, primaryColor)
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        color: primaryColor,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return _buildProductCard(
                              product,
                              isDark,
                              textColor,
                              subTextColor,
                              cardColor,
                              primaryColor,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateProductScreen()),
          ).then((_) => _loadProducts());
        },
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
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
    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar avec initiale et couleur de statut
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: product.statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  product.name[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: product.statusColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Infos produit
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (product.barcode != null && product.barcode!.isNotEmpty)
                    Text(
                      'Réf: ${product.barcode}',
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                  if (product.category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.category,
                        style: TextStyle(
                          fontSize: 10,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Contrôle de quantité
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: () => _updateQuantity(product, -1),
                        color: subTextColor,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        '${product.quantity}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: () => _updateQuantity(product, 1),
                        color: primaryColor,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      // Badge statut
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: product.statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: product.statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Prix et actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  product.formattedPrice,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  product.formattedStockValue,
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 20, color: subTextColor),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateProductScreen(product: product),
                          ),
                        ).then((_) => _loadProducts());
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      onPressed: () => _deleteProduct(product),
                    ),
                  ],
                ),
              ],
            ),
          ],
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2, size: 80, color: primaryColor),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != null
                ? 'Aucun résultat'
                : 'Aucun produit',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != null
                ? 'Essayez d\'autres critères'
                : 'Ajoutez votre premier produit',
            style: TextStyle(
              fontSize: 14,
              color: subTextColor,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateProductScreen()),
              ).then((_) => _loadProducts());
            },
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un produit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}