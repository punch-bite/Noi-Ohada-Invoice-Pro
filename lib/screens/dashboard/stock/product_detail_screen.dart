// lib/screens/stock/product_detail_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/stock_service.dart';
import '../../../services/supplier_service.dart';
import '../../../models/product.dart';
import '../../../models/supplier.dart';
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
  final SupplierService _supplierService = SupplierService();
  Product? _product;
  Supplier? _supplier;
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
      // ✅ Résout le fournisseur assigné au produit (nom réel affiché).
      final sid = _product!.supplierId;
      if (sid != null && sid.isNotEmpty) {
        await _supplierService.init();
        _supplier = await _supplierService.getSupplier(sid);
      } else {
        _supplier = null;
      }
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
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF151515) : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              Text(
                'Produit introuvable',
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    final product = _product!;
    final isLow = product.isLowStock;
    final isOut = product.isOutOfStock;

    final Color statusColor = isOut 
        ? Colors.redAccent 
        : (isLow ? Colors.orange : Colors.green);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF151515) : Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Détails du produit',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: textColor),
            tooltip: 'Modifier',
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
            icon: Icon(Icons.more_vert_rounded, color: textColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteDialog(textColor, subTextColor, cardColor);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Supprimer', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero image (photo du produit si présente)
            if (product.imagePath != null && product.imagePath!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.memory(
                  _decodeImage(product.imagePath!),
                  fit: BoxFit.cover,
                  height: 180,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => _buildHeroFallback(product, statusColor),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Fiche produit principale (maquette : héro + infos)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.grey[900]! : Colors.grey[100]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withValues(alpha: 0.22),
                              statusColor.withValues(alpha: 0.06),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text(
                            product.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
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
                            const SizedBox(height: 4),
                            Text(
                              product.description.isNotEmpty
                                  ? product.description
                                  : (product.category.isNotEmpty ? product.category : 'Sans catégorie'),
                              style: TextStyle(
                                fontSize: 13,
                                color: subTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isOut 
                                    ? 'RUPTURE DE STOCK' 
                                    : (isLow ? 'STOCK FAIBLE' : 'EN STOCK'),
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
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, thickness: 1),
                  ),
                  // RÉFÉRENCE (SKU) + Fournisseur
                  _buildLabelValueRow('RÉFÉRENCE (SKU)',
                      product.barcode?.isNotEmpty == true ? product.barcode! : '—'),
                  const SizedBox(height: 12),
                  _buildLabelValueRow('FOURNISSEUR', _supplierName),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 12,
                          color: primaryColor.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Voir le profil',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, thickness: 1),
                  ),
                  // État du Stock : jauge (quantité / seuil / max)
                  Text(
                    'État du Stock',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: subTextColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${product.quantity}',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            product.unit,
                            style: TextStyle(fontSize: 11, color: subTextColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isOut ? 'RUPTURE' : (isLow ? 'SEUIL' : 'EN STOCK'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (product.quantity / (product.minStock * 3))
                          .clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Seuil: ${product.minStock} ${product.unit}',
                        style: TextStyle(fontSize: 11, color: subTextColor),
                      ),
                      Text(
                        'Max: ${product.minStock * 3} ${product.unit}',
                        style: TextStyle(fontSize: 11, color: subTextColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Grille des valeurs clés
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoTile(
                          'Stock actuel',
                          '${product.quantity} ${product.unit}',
                          textColor,
                          subTextColor,
                          isDark,
                        ),
                      ),
                      Expanded(
                        child: _buildInfoTile(
                          'Point de commande',
                          '${product.minStock} ${product.unit}s',
                          textColor,
                          subTextColor,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoTile(
                          'Unité de mesure',
                          product.unit,
                          textColor,
                          subTextColor,
                          isDark,
                        ),
                      ),
                      Expanded(
                        child: _buildInfoTile(
                          'Valeur théorique',
                          '${product.stockValue.toStringAsFixed(0)} FCFA',
                          textColor,
                          subTextColor,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Tarification (maquette : achat HT / vente HT / marge / TVA)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.grey[900]! : Colors.grey[100]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tarification',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildLabelValueRow(
                      'Prix d\'achat unitaire (HT)',
                      '${product.costPrice.toStringAsFixed(0)} FCFA'),
                  const SizedBox(height: 10),
                  _buildLabelValueRow(
                      'Prix de vente unitaire (HT)',
                      '${product.price.toStringAsFixed(0)} FCFA'),
                  const SizedBox(height: 10),
                  _buildMarginRow(product),
                  const SizedBox(height: 10),
                  _buildLabelValueRow('TVA Applicable', 'Normale (18%)'),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Boutons d'action (maquette : Modifier / Ajuster le stock)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CreateProductScreen(product: product),
                        ),
                      ).then((_) => _loadData());
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Modifier',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAdjustStockDialog(
                        product, textColor, subTextColor, cardColor),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Ajuster le stock',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Historique des mouvements
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.grey[900]! : Colors.grey[100]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Historique',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'VOIR TOUT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_deliveries.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(Icons.history_rounded, color: subTextColor.withValues(alpha: 0.4), size: 44),
                            const SizedBox(height: 10),
                            Text(
                              'Aucun mouvement pour le moment.',
                              style: TextStyle(color: subTextColor, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _deliveries.length > 10 ? 10 : _deliveries.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final delivery = _deliveries[index];
                        return _buildDeliveryTile(delivery, isDark, textColor, subTextColor);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nom du fournisseur (repli : libellé générique si absent).
  String get _supplierName {
    final sid = _product?.supplierId;
    if (sid == null || sid.isEmpty) return 'Non assigné';
    // ✅ Nom réel résolu via SupplierService (chargé dans _loadData).
    final name = _supplier?.name;
    if (name != null && name.isNotEmpty) return name;
    return sid.length > 14 ? 'Fournisseur #${sid.substring(0, 8)}' : sid;
  }

  /// Décode une image base64 (donnée URI) en bytes.
  Uint8List _decodeImage(String dataUri) {
    try {
      final idx = dataUri.indexOf(',');
      if (dataUri.startsWith('data:') && idx != -1) {
        return base64Decode(dataUri.substring(idx + 1));
      }
      return base64Decode(dataUri);
    } catch (_) {
      return Uint8List(0);
    }
  }

  Widget _buildHeroFallback(Product product, Color statusColor) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.15),
            statusColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Icon(Icons.inventory_2_outlined, color: statusColor, size: 56),
      ),
    );
  }

  /// Ligne « label en MAJUSCULES gris + valeur » (style fiche maquette).
  Widget _buildLabelValueRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF14161C),
            ),
          ),
        ),
      ],
    );
  }

  /// Ligne de marge bénéficiaire (achat → vente) avec pourcentage.
  Widget _buildMarginRow(Product product) {
    final margin = product.price - product.costPrice;
    final marginPct = product.price > 0 ? (margin / product.price * 100) : 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'Marge bénéficiaire',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            '${margin.toStringAsFixed(0)} FCFA (${marginPct.toStringAsFixed(1)}%)',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF16A34A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    String label,
    String value,
    Color textColor,
    Color subTextColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900]!.withValues(alpha: 0.3) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[900]! : Colors.grey[100]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: subTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
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

    final Color stateColor = isCompleted
        ? Colors.green
        : (isPending ? Colors.orange : Colors.redAccent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isIncoming
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncoming ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isIncoming ? Colors.green : Colors.orange,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIncoming ? 'Réception de stock' : 'Livraison client',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Quantité : ${delivery.quantity} ${_product?.unit ?? ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                  ),
                ),
                if (delivery.clientName != null && delivery.clientName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Bénéficiaire : ${delivery.clientName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: subTextColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: stateColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isCompleted ? 'Terminé' : (isPending ? 'En cours' : 'Annulé'),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: stateColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dialogue « Ajuster le stock » : choix Réception (+) / Livraison (−).
  Future<void> _showAdjustStockDialog(Product product, Color textColor,
      Color subTextColor, Color cardColor) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Ajuster le stock',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${product.name} — ${product.quantity} ${product.unit}s',
              style: TextStyle(fontSize: 12, color: subTextColor),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF16A34A),
                child: Icon(Icons.arrow_downward, color: Colors.white),
              ),
              title: const Text('Réception', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Entrée de stock (achat, retour)'),
              onTap: () => Navigator.pop(context, 'incoming'),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF59E0B),
                child: Icon(Icons.arrow_upward, color: Colors.white),
              ),
              title: const Text('Livraison', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Sortie de stock (vente, ajustement)'),
              onTap: () => Navigator.pop(context, 'outgoing'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null) return;
    final type =
        choice == 'incoming' ? DeliveryType.incoming : DeliveryType.outgoing;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateDeliveryScreen(
          productId: product.id,
          productName: product.name,
          type: type,
        ),
      ),
    );
    if (mounted) await _loadData();
  }

  void _showDeleteDialog(Color textColor, Color subTextColor, Color cardColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Supprimer le produit ?',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Cette action est irréversible. Voulez-vous vraiment supprimer définitivement le produit "${_product?.name}" ?',
          style: TextStyle(color: subTextColor, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: subTextColor, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_product != null) {
                await _stockService.deleteProduct(_product!.id);
                if (mounted) {
                  Navigator.pop(context); // Ferme la boîte de dialogue
                  Navigator.pop(context, true); // Revient à la page précédente en notifiant la suppression
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}