// lib/screens/dashboard/suppliers/supplier_detail_screen.dart
// ============================================================
//  Profil fournisseur (maquette Stitch « profil_fournisseur »).
//  Affiche : carte identité + badge statut, stats (volume / produits),
//  onglet Commandes → liste des produits liés au fournisseur.
// ============================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/product.dart';
import '../../../models/supplier.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/stock_service.dart';
import 'create_supplier_screen.dart';

class SupplierDetailScreen extends StatefulWidget {
  final Supplier supplier;
  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  final StockService _stockService = StockService();
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final products =
          await _stockService.getProductsBySupplier(widget.supplier.id);
      if (!mounted) return;
      setState(() => _products = products);
    } catch (_) {
      if (mounted) setState(() => _products = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _stockValue =>
      _products.fold(0, (sum, p) => sum + (p.costPrice * p.quantity));

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final card = theme.cardColor;
    final bg = theme.backgroundColor;
    final s = widget.supplier;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Fournisseur', style: TextStyle(color: text, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: text),
            tooltip: 'Modifier',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateSupplierScreen(supplier: s),
                ),
              ).then((_) => _loadProducts());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        color: primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(16),
          children: [
            // ===== Carte identité (profil) =====
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.address.isNotEmpty
                                  ? s.address
                                  : (s.email.isNotEmpty ? s.email : 'Adresse non renseignée'),
                              style: TextStyle(fontSize: 12, color: sub),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: s.isActive
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              s.isActive ? Icons.check_circle : Icons.block,
                              size: 12,
                              color: s.isActive ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              s.isActive ? 'Actif' : 'Inactif',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: s.isActive ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  // Coordonnées
                  if (s.phone.isNotEmpty)
                    _buildContactRow(Icons.phone_outlined, 'Téléphone', s.phone, text, sub),
                  if (s.email.isNotEmpty)
                    _buildContactRow(Icons.email_outlined, 'Email', s.email, text, sub),
                  if (s.contactPerson.isNotEmpty)
                    _buildContactRow(Icons.person_outline, 'Contact', s.contactPerson, text, sub),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ===== Stats (Volume / Produits) =====
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    label: 'VOLUME (YTD)',
                    value:
                        '${_stockValue.toStringAsFixed(0)} FCFA',
                    icon: Icons.trending_up_rounded,
                    color: primary,
                    text: text,
                    sub: sub,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    label: 'PRODUITS LIÉS',
                    value: '${_products.length}',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFFF59E0B),
                    text: text,
                    sub: sub,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ===== Onglet « Commandes » → produits du fournisseur =====
            Text(
              'Produits fournis',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_products.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 40, color: sub.withValues(alpha: 0.5)),
                    const SizedBox(height: 10),
                    Text(
                      'Aucun produit lié à ce fournisseur',
                      style: TextStyle(color: sub, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ..._products.map((p) => _buildProductTile(p, text, sub, card, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(
      IconData icon, String label, String value, Color text, Color sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: sub),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(fontSize: 13, color: sub)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: text, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color text,
    required Color sub,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2433) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: sub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(
      Product p, Color text, Color sub, Color card, bool isDark) {
    final isOut = p.isOutOfStock;
    final isLow = p.isLowStock;
    final statusColor = isOut
        ? Colors.redAccent
        : (isLow ? Colors.orange : Colors.green);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor.withValues(alpha: 0.2),
                  statusColor.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  p.barcode?.isNotEmpty == true
                      ? 'SKU: ${p.barcode}'
                      : (p.category.isNotEmpty ? p.category : 'Sans catégorie'),
                  style: TextStyle(fontSize: 11, color: sub),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${p.price.toStringAsFixed(0)} FCFA',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: text,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOut ? 'Rupture' : (isLow ? 'Stock faible' : 'En stock (${p.quantity})'),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
