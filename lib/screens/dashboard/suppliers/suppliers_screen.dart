// lib/screens/dashboard/suppliers/suppliers_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/supplier_service.dart';
import '../../../services/stock_service.dart';
import '../../../models/supplier.dart';
import 'create_supplier_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final SupplierService _supplierService = SupplierService();
  final StockService _stockService = StockService();
  List<Supplier> _suppliers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    await _supplierService.init();
    await _stockService.init();
    _suppliers = await _supplierService.getSuppliers();
    setState(() => _isLoading = false);
  }

  List<Supplier> get _filteredSuppliers {
    if (_searchQuery.isEmpty) return _suppliers;
    return _suppliers.where((s) =>
      s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      s.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      s.phone.contains(_searchQuery)
    ).toList();
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    // Vérifier si le fournisseur a des produits
    final hasProducts = await _stockService.hasProductsForSupplier(supplier.id);
    if (hasProducts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de supprimer ce fournisseur car il est lié à des produits'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer le fournisseur'),
        content: Text('Voulez-vous vraiment supprimer "${supplier.name}" ?'),
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
      await _supplierService.deleteSupplier(supplier.id);
      await _loadSuppliers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fournisseur supprimé'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
            hintText: 'Rechercher un fournisseur...',
            hintStyle: TextStyle(color: subTextColor),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: subTextColor),
          ),
          onChanged: (query) => setState(() => _searchQuery = query),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: _loadSuppliers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredSuppliers.isEmpty
              ? _buildEmptyState(isDark, textColor, subTextColor, primaryColor)
              : RefreshIndicator(
                  onRefresh: _loadSuppliers,
                  color: primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredSuppliers.length,
                    itemBuilder: (context, index) {
                      final supplier = _filteredSuppliers[index];
                      return _buildSupplierCard(
                        supplier,
                        isDark,
                        textColor,
                        subTextColor,
                        cardColor,
                        primaryColor,
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateSupplierScreen()),
          ).then((_) => _loadSuppliers());
        },
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSupplierCard(
    Supplier supplier,
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
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  supplier.name[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        supplier.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!supplier.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Inactif',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (supplier.phone.isNotEmpty)
                    Text(
                      'Tél: ${supplier.phone}',
                      style: TextStyle(fontSize: 13, color: subTextColor),
                    ),
                  if (supplier.email.isNotEmpty)
                    Text(
                      'Email: ${supplier.email}',
                      style: TextStyle(fontSize: 13, color: subTextColor),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 20, color: subTextColor),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateSupplierScreen(supplier: supplier),
                      ),
                    ).then((_) => _loadSuppliers());
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _deleteSupplier(supplier),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor, Color subTextColor, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business, size: 80, color: primaryColor),
          const SizedBox(height: 16),
          Text(
            'Aucun fournisseur',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre premier fournisseur',
            style: TextStyle(fontSize: 14, color: subTextColor),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateSupplierScreen()),
              ).then((_) => _loadSuppliers());
            },
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un fournisseur'),
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