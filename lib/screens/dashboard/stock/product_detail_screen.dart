// lib/screens/stock/product_detail_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/stock_service.dart';
import '../../../models/product.dart';
import '../../../models/delivery.dart';
import 'create_product_screen.dart';
import 'create_delivery_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final StockService _stockService = StockService();
  Product? _product;
  List<Delivery> _deliveries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _product = await _stockService.getProduct(widget.productId);
    if (_product != null) {
      _deliveries = await _stockService.getDeliveriesByProduct(_product!.id);
    }
    setState(() => _isLoading = false);
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_product == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Produit non trouvé',
                style: TextStyle(color: textColor),
              ),
            ],
          ),
        ),
      );
    }

    final product = _product!;
    final isLow = product.isLowStock;
    final isOut = product.isOutOfStock;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          product.name,
          style: TextStyle(color: textColor),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: textColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateProductScreen(product: product),
                ),
              ).then((_) => _loadData());
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textColor),
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteDialog();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                  value: 'delete',
                  child:
                      Text('Supprimer', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Infos générales
            Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: isLow
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              product.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isLow ? Colors.orange : Colors.green,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                product.category.isNotEmpty
                                    ? product.category
                                    : 'Sans catégorie',
                                style: TextStyle(color: subTextColor),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOut
                                      ? Colors.red.withOpacity(0.1)
                                      : (isLow
                                          ? Colors.orange.withOpacity(0.1)
                                          : Colors.green.withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isOut
                                      ? 'Rupture de stock'
                                      : (isLow ? 'Stock faible' : 'Stock OK'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isOut
                                        ? Colors.red
                                        : (isLow
                                            ? Colors.orange
                                            : Colors.green),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoTile(
                            'Quantité',
                            '${product.quantity} ${product.unit}',
                            isDark,
                            textColor,
                            subTextColor,
                          ),
                        ),
                        Expanded(
                          child: _buildInfoTile(
                            'Prix de vente',
                            '${product.price.toStringAsFixed(0)} FCFA',
                            isDark,
                            textColor,
                            subTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoTile(
                            'Stock minimum',
                            '${product.minStock} ${product.unit}',
                            isDark,
                            textColor,
                            subTextColor,
                          ),
                        ),
                        Expanded(
                          child: _buildInfoTile(
                            'Valeur stock',
                            '${product.stockValue.toStringAsFixed(0)} FCFA',
                            isDark,
                            textColor,
                            subTextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateDeliveryScreen(
                            productId: product.id,
                            productName: product.name,
                            type: DeliveryType.incoming,
                          ),
                        ),
                      ).then((_) => _loadData());
                    },
                    icon: const Icon(Icons.arrow_downward),
                    label: const Text('Réception'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateDeliveryScreen(
                            productId: product.id,
                            productName: product.name,
                            type: DeliveryType.outgoing,
                          ),
                        ),
                      ).then((_) => _loadData());
                    },
                    icon: const Icon(Icons.arrow_upward),
                    label: const Text('Livraison'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Historique des mouvements
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                border: Border.all(color: Colors.green, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Historique des mouvements',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${_deliveries.length} mouvements',
                        style: TextStyle(
                          fontSize: 12,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_deliveries.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Aucun mouvement pour ce produit',
                          style: TextStyle(color: subTextColor),
                        ),
                      ),
                    )
                  else
                    ..._deliveries.take(10).map((delivery) =>
                        _buildDeliveryTile(
                            delivery, isDark, textColor, subTextColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    String label,
    String value,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: subTextColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryTile(
    Delivery delivery,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    final isIncoming = delivery.isIncoming;
    final isCompleted = delivery.isCompleted;
    final isPending = delivery.isPending;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isIncoming
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncoming ? Colors.green : Colors.orange,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIncoming ? 'Réception' : 'Livraison',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                Text(
                  '${delivery.quantity} ${_product?.unit ?? ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                  ),
                ),
                if (delivery.clientName != null)
                  Text(
                    'Client: ${delivery.clientName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: subTextColor,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withOpacity(0.1)
                  : (isPending
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isCompleted ? 'Terminé' : (isPending ? 'En cours' : 'Annulé'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isCompleted
                    ? Colors.green
                    : (isPending ? Colors.orange : Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le produit'),
        content: Text('Voulez-vous vraiment supprimer ${_product?.name} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              if (_product != null) {
                await _stockService.deleteProduct(_product!.id);
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
