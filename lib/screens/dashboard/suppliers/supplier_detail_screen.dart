// lib/screens/dashboard/suppliers/supplier_detail_screen.dart
// ============================================================
//  🎨 Profil fournisseur — refonte moderne.
//  Hero card premium, stats gradient, produits épurés.
//  Logique inchangée.
// ============================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart'; 
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

  int get _outOfStockCount => _products.where((p) => p.isOutOfStock).length;
  int get _lowStockCount => _products.where((p) => p.isLowStock).length;

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
      body: SafeArea(
        child: Column(
          children: [
            // AppBar minimal
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  _iconBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    color: text,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  _iconBtn(
                    icon: Icons.edit_outlined,
                    color: text,
                    tooltip: 'Modifier',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CreateSupplierScreen(supplier: s),
                        ),
                      ).then((_) => _loadProducts());
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadProducts,
                color: primary,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _buildHeroCard(s, isDark, primary, text, sub),
                    const SizedBox(height: 16),
                    _buildStatsRow(
                        isDark, primary, text, sub, card),
                    const SizedBox(height: 20),
                    _buildSectionTitle(
                      'Produits fournis',
                      subtitle:
                          '${_products.length} référence${_products.length > 1 ? 's' : ''}',
                      text: text,
                      sub: sub,
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(
                          child: CircularProgressIndicator(color: primary),
                        ),
                      )
                    else if (_products.isEmpty)
                      _buildEmptyProducts(isDark, text, sub, card)
                    else
                      ..._products.asMap().entries.map((e) => _buildProductTile(
                            e.value,
                            e.key,
                            text,
                            sub,
                            card,
                            isDark,
                          )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: button) : button;
  }

  // ======================================================================
  //  HERO CARD
  // ======================================================================
  Widget _buildHeroCard(
    Supplier s,
    bool isDark,
    Color primary,
    Color text,
    Color sub,
  ) {
    final initial = s.name.isNotEmpty ? s.name[0].toUpperCase() : '?';
    final isActive = s.isActive;
    final statusColor =
        isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  primary.withValues(alpha: 0.16),
                  primary.withValues(alpha: 0.04),
                ]
              : [
                  primary.withValues(alpha: 0.08),
                  primary.withValues(alpha: 0.02),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primary,
                      primary.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isActive ? 'Actif' : 'Inactif',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Contacts
          if (s.phone.isNotEmpty || s.email.isNotEmpty || s.contactPerson.isNotEmpty || s.address.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(height: 1, color: primary.withValues(alpha: 0.10)),
            const SizedBox(height: 16),
            if (s.phone.isNotEmpty)
              _buildContactRow(
                Icons.phone_rounded,
                'Téléphone',
                s.phone,
                text,
                sub,
                primary,
              ),
            if (s.email.isNotEmpty)
              _buildContactRow(
                Icons.mail_rounded,
                'Email',
                s.email,
                text,
                sub,
                primary,
              ),
            if (s.contactPerson.isNotEmpty)
              _buildContactRow(
                Icons.person_rounded,
                'Contact',
                s.contactPerson,
                text,
                sub,
                primary,
              ),
            if (s.address.isNotEmpty)
              _buildContactRow(
                Icons.location_on_rounded,
                'Adresse',
                s.address,
                text,
                sub,
                primary,
                isLast: true,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactRow(
    IconData icon,
    String label,
    String value,
    Color text,
    Color sub,
    Color primary, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: primary),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: sub,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  //  STATS ROW
  // ======================================================================
  Widget _buildStatsRow(
    bool isDark,
    Color primary,
    Color text,
    Color sub,
    Color card,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'VOLUME YTD',
            value: _formatMoney(_stockValue),
            icon: Icons.trending_up_rounded,
            color: primary,
            isDark: isDark,
            text: text,
            sub: sub,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            label: 'PRODUITS',
            value: '${_products.length}',
            icon: Icons.inventory_2_rounded,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            text: text,
            sub: sub,
          ),
        ),
      ],
    );
  }

  String _formatMoney(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)} M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)} K';
    }
    return value.toStringAsFixed(0);
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color text,
    required Color sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.10)
            : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.20 : 0.14),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? Colors.white : text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.6)
                  : sub,
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  //  SECTION TITLE
  // ======================================================================
  Widget _buildSectionTitle(
    String title, {
    String? subtitle,
    required Color text,
    required Color sub,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: text,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: sub,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_outOfStockCount > 0 || _lowStockCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 12, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  '${_outOfStockCount + _lowStockCount} alerte${(_outOfStockCount + _lowStockCount) > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ======================================================================
  //  EMPTY PRODUCTS
  // ======================================================================
  Widget _buildEmptyProducts(
    bool isDark,
    Color text,
    Color sub,
    Color card,
  ) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 36,
            color: sub.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),
          Text(
            'Aucun produit lié',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: text,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Associez des produits à ce fournisseur\ndepuis la gestion du stock.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: sub,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  //  PRODUCT TILE
  // ======================================================================
  Widget _buildProductTile(
    Product p,
    int index,
    Color text,
    Color sub,
    Color card,
    bool isDark,
  ) {
    final isOut = p.isOutOfStock;
    final isLow = p.isLowStock;
    final statusColor = isOut
        ? const Color(0xFFEF4444)
        : (isLow ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
    final statusLabel = isOut
        ? 'Rupture'
        : (isLow ? 'Stock faible' : 'En stock (${p.quantity})');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    statusColor.withValues(alpha: 0.18),
                    statusColor.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Text(
                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.barcode?.isNotEmpty == true
                        ? 'SKU: ${p.barcode}'
                        : (p.category.isNotEmpty
                            ? p.category
                            : 'Sans catégorie'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: sub,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${p.price.toStringAsFixed(0)} F',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: text,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: 40 * index),
          duration: 280.ms,
        );
  }
}