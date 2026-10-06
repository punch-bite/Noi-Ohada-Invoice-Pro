// lib/screens/stock/product_detail_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use
//
// 🎨 Détail produit épuré — hero, jauge animée, sections claires.
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      _deliveries =
          await _stockService.getDeliveriesByProduct(_product!.id);
      final sid = _product!.supplierId;
      if (sid != null && sid.isNotEmpty) {
        await _supplierService.init();
        _supplier = await _supplierService.getSupplier(sid);
      } else {
        _supplier = null;
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final card = theme.cardColor;
    final bg = theme.backgroundColor;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    if (_product == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: text),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    size: 40, color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              Text(
                'Produit introuvable',
                style: TextStyle(
                    color: text, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    final product = _product!;
    final isLow = product.isLowStock;
    final isOut = product.isOutOfStock;

    final statusColor = isOut
        ? const Color(0xFFEF4444)
        : (isLow ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Détails',
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: text, size: 22),
            tooltip: 'Modifier',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CreateProductScreen(product: product),
                ),
              );
              if (mounted) _loadData();
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: text, size: 22),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (v) {
              if (v == 'delete') {
                _showDeleteDialog(text, sub, card);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Supprimer',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero : photo ou avatar ──
            _buildHero(product, statusColor, isDark),
            const SizedBox(height: 24),

            // ── Carte principale : infos ──
            _buildMainCard(
              product, statusColor, isDark, text, sub, card, primary,
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

            const SizedBox(height: 16),

            // ── Carte tarification ──
            _buildPricingCard(product, isDark, text, sub, card)
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms),

            const SizedBox(height: 20),

            // ── Actions ──
            _buildActions(product, primary, text, sub, card)
                .animate()
                .fadeIn(delay: 300.ms, duration: 400.ms),

            const SizedBox(height: 20),

            // ── Historique ──
            _buildHistoryCard(product, isDark, text, sub, card, primary)
                .animate()
                .fadeIn(delay: 400.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  // ── Hero (photo ou gradient avec initiale) ──
  Widget _buildHero(Product product, Color statusColor, bool isDark) {
    if (product.imagePath != null && product.imagePath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.memory(
          _decodeImage(product.imagePath!),
          fit: BoxFit.cover,
          height: 200,
          width: double.infinity,
          errorBuilder: (_, __, ___) =>
              _buildHeroFallback(product, statusColor),
        ),
      );
    }
    return _buildHeroFallback(product, statusColor);
  }

  Widget _buildHeroFallback(Product product, Color statusColor) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: 0.18),
            statusColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Text(
          product.name.substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.w900,
            color: statusColor,
            letterSpacing: -2,
          ),
        ),
      ),
    );
  }

  // ── Carte principale ──
  Widget _buildMainCard(
    Product product,
    Color statusColor,
    bool isDark,
    Color text,
    Color sub,
    Color card,
    Color primary,
  ) {
    final isOut = product.isOutOfStock;
    final isLow = product.isLowStock;
    final stockRatio =
        (product.quantity / (product.minStock * 3)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
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
          // Nom + statut
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: text,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (product.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        product.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: sub,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isOut
                      ? 'RUPTURE'
                      : (isLow ? 'FAIBLE' : 'EN STOCK'),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Jauge animée
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.quantity}',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: text,
                  height: 1.0,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  product.unit,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: sub,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: stockRatio),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Seuil : ${product.minStock}',
                style: TextStyle(fontSize: 11, color: sub),
              ),
              Text(
                'Max : ${product.minStock * 3}',
                style: TextStyle(fontSize: 11, color: sub),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 20),

          // Détails
          _detailRow('RÉFÉRENCE', product.barcode?.isNotEmpty == true
              ? product.barcode!
              : '—', text, sub),
          const SizedBox(height: 12),
          _detailRow('FOURNISSEUR', _supplierName, text, sub),
          const SizedBox(height: 12),
          _detailRow('CATÉGORIE',
              product.category.isNotEmpty ? product.category : '—', text, sub),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, Color text, Color sub) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: sub,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ),
      ],
    );
  }

  // ── Carte tarification ──
  Widget _buildPricingCard(
    Product product,
    bool isDark,
    Color text,
    Color sub,
    Color card,
  ) {
    final margin = product.price - product.costPrice;
    final marginPct = product.price > 0 ? (margin / product.price * 100) : 0;
    final marginColor = margin >= 0
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
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
          Text(
            'Tarification',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: text,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _priceTile(
                  label: 'PRIX D\'ACHAT',
                  value: '${product.costPrice.toStringAsFixed(0)} F',
                  color: sub,
                  text: text,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _priceTile(
                  label: 'PRIX DE VENTE',
                  value: '${product.price.toStringAsFixed(0)} F',
                  color: const Color(0xFF10B981),
                  text: text,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _priceTile(
                  label: 'MARGE',
                  value:
                      '${margin.toStringAsFixed(0)} F (${marginPct.toStringAsFixed(0)}%)',
                  color: marginColor,
                  text: text,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _priceTile(
                  label: 'VALEUR STOCK',
                  value: '${product.stockValue.toStringAsFixed(0)} F',
                  color: const Color(0xFF4F46E5),
                  text: text,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceTile({
    required String label,
    required String value,
    required Color color,
    required Color text,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──
  Widget _buildActions(
    Product product,
    Color primary,
    Color text,
    Color sub,
    Color card,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CreateProductScreen(product: product),
                ),
              );
              if (mounted) _loadData();
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Modifier'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: BorderSide(color: primary.withValues(alpha: 0.4), width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showAdjustStockDialog(product, text, sub, card),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Ajuster'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Historique ──
  Widget _buildHistoryCard(
    Product product,
    bool isDark,
    Color text,
    Color sub,
    Color card,
    Color primary,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
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
          Row(
            children: [
              Text(
                'Historique',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: text,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Text(
                '${_deliveries.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: sub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_deliveries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Icon(Icons.history_rounded,
                      color: sub.withValues(alpha: 0.3), size: 36),
                  const SizedBox(height: 10),
                  Text(
                    'Aucun mouvement',
                    style: TextStyle(
                        color: sub, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount:
                  _deliveries.length > 10 ? 10 : _deliveries.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              itemBuilder: (context, i) =>
                  _buildDeliveryTile(_deliveries[i], isDark, text, sub),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveryTile(
    Delivery delivery,
    bool isDark,
    Color text,
    Color sub,
  ) {
    final isIncoming = delivery.isIncoming;
    final isCompleted = delivery.isCompleted;
    final isPending = delivery.isPending;

    final stateColor = isCompleted
        ? const Color(0xFF10B981)
        : (isPending ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: (isIncoming
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B))
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncoming
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isIncoming
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
              size: 16,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIncoming ? 'Réception' : 'Livraison',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Qté : ${delivery.quantity} ${_product?.unit ?? ''}'
                  '${delivery.clientName != null && delivery.clientName!.isNotEmpty ? ' · ${delivery.clientName}' : ''}',
                  style: TextStyle(fontSize: 11.5, color: sub),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: stateColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isCompleted
                  ? 'Terminé'
                  : (isPending ? 'En cours' : 'Annulé'),
              style: TextStyle(
                fontSize: 9.5,
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

  String get _supplierName {
    final sid = _product?.supplierId;
    if (sid == null || sid.isEmpty) return 'Non assigné';
    final name = _supplier?.name;
    if (name != null && name.isNotEmpty) return name;
    return sid.length > 14 ? 'Fournisseur #${sid.substring(0, 8)}' : sid;
  }

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

  Future<void> _showAdjustStockDialog(
      Product product, Color text, Color sub, Color card) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: sub.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Ajuster le stock',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: text),
            ),
            const SizedBox(height: 4),
            Text(
              '${product.name} · ${product.quantity} ${product.unit}s',
              style: TextStyle(fontSize: 12, color: sub),
            ),
            const SizedBox(height: 18),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_downward_rounded,
                    color: Color(0xFF10B981), size: 20),
              ),
              title: const Text('Réception',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Entrée de stock (achat, retour)'),
              onTap: () => Navigator.pop(context, 'incoming'),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_upward_rounded,
                    color: Color(0xFFF59E0B), size: 20),
              ),
              title: const Text('Livraison',
                  style: TextStyle(fontWeight: FontWeight.w700)),
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

  void _showDeleteDialog(Color text, Color sub, Color card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Supprimer ?',
          style: TextStyle(color: text, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Cette action est irréversible. Voulez-vous vraiment supprimer "${_product?.name}" ?',
          style: TextStyle(color: sub, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: sub, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_product != null) {
                await _stockService.deleteProduct(_product!.id);
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Supprimer',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}