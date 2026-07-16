// lib/screens/dashboard/create_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../services/stock_service.dart';
import '../../models/invoice.dart';
import '../../models/line_item.dart';
import '../../models/client.dart';
import '../../models/product.dart';
import '../../providers/theme_provider.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final DatabaseService _db = DatabaseService();
  final StockService _stockService = StockService();
  final _formKey = GlobalKey<FormState>();

  Client? _selectedClient;
  List<Client> _clients = [];
  final List<LineItem> _items = [];
  bool _isDevis = false;
  bool _isSaving = false;
  double _taxRate = 18;
  double _discount = 0;
  double _deliveryFee = 0;
  final String _terms = 'Paiement à 30 jours';

  final _clientController = TextEditingController();
  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _notesController = TextEditingController();
  final _deliveryFeeController = TextEditingController();

  List<Product> _stockProducts = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
    _loadStockProducts();
    _deliveryFeeController.addListener(() {
      setState(() =>
          _deliveryFee = double.tryParse(_deliveryFeeController.text) ?? 0);
    });
  }

  @override
  void dispose() {
    _clientController.dispose();
    _productController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _notesController.dispose();
    _deliveryFeeController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final clients = await _db.getClients();
      if (!mounted) return;
      setState(() => _clients = clients);
    } catch (_) {}
  }

  Future<void> _loadStockProducts() async {
    try {
      await _stockService.init();
      final products = await _stockService.getActiveProducts();
      if (!mounted) return;
      setState(() => _stockProducts = products);
    } catch (_) {}
  }

  double get _subtotal =>
      _items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice));
  double get _taxAmount => (_subtotal + _deliveryFee) * (_taxRate / 100);
  double get _total => _subtotal + _deliveryFee + _taxAmount - _discount;

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
      appBar: AppBar(
        title: Text(
          _isDevis ? 'Nouveau devis' : 'Nouvelle facture',
          style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: text),
          onPressed: () => context.pop(),
        ),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _saveInvoice,
                  child: Text(
                    'Enregistrer',
                    style: TextStyle(color: primary, fontWeight: FontWeight.bold),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Type Selector
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Facture'),
                    selected: !_isDevis,
                    onSelected: (_) => setState(() => _isDevis = false),
                    selectedColor: primary,
                    backgroundColor: isDark ? Colors.grey[850] : Colors.grey[100],
                    labelStyle: TextStyle(color: !_isDevis ? Colors.white : sub),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Devis'),
                    selected: _isDevis,
                    onSelected: (_) => setState(() => _isDevis = true),
                    selectedColor: primary,
                    backgroundColor: isDark ? Colors.grey[850] : Colors.grey[100],
                    labelStyle: TextStyle(color: _isDevis ? Colors.white : sub),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Client Selector Field
              TextFormField(
                controller: _clientController,
                readOnly: true,
                style: TextStyle(color: text, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Client',
                  hintText: 'Sélectionner un client',
                  labelStyle: TextStyle(color: sub, fontSize: 13),
                  hintStyle: TextStyle(color: sub.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.person_outline, color: sub),
                  suffixIcon: Icon(Icons.arrow_drop_down, color: sub),
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onTap: _selectClient,
              ),
              const SizedBox(height: 12),

              // Add Product Line
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _productController,
                      style: TextStyle(color: text, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Produit',
                        labelStyle: TextStyle(color: sub, fontSize: 13),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: text, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Qté',
                        labelStyle: TextStyle(color: sub, fontSize: 13),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _unitPriceController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: text, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Prix',
                        labelStyle: TextStyle(color: sub, fontSize: 13),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: primary, size: 28),
                    onPressed: _addProduct,
                  ),
                ],
              ),
              if (_stockProducts.isNotEmpty) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showStockProductsDialog,
                    child: Text('Depuis le stock', style: TextStyle(color: primary, fontSize: 12)),
                  ),
                ),
              ],

              // Product Items List
              if (_items.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._items.asMap().entries.map(
                    (e) => _productTile(e.value, e.key, isDark, text, sub)),
              ],
              const SizedBox(height: 12),

              // Delivery Fee
              TextFormField(
                controller: _deliveryFeeController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: text, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Frais de livraison',
                  hintText: '0',
                  labelStyle: TextStyle(color: sub, fontSize: 13),
                  hintStyle: TextStyle(color: sub.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.local_shipping, color: sub),
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),

              // Tax & Discount
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: text, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'TVA %',
                        labelStyle: TextStyle(color: sub, fontSize: 13),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      initialValue: _taxRate.toString(),
                      onChanged: (v) => setState(() => _taxRate = double.tryParse(v) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: text, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Remise',
                        labelStyle: TextStyle(color: sub, fontSize: 13),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      initialValue: _discount.toString(),
                      onChanged: (v) => setState(() => _discount = double.tryParse(v) ?? 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                style: TextStyle(color: text, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Notes',
                  labelStyle: TextStyle(color: sub, fontSize: 13),
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Total Summary Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _totalRow('Sous-total', '${_subtotal.toStringAsFixed(0)} FCFA', text, sub),
                    _totalRow('Livraison', '${_deliveryFee.toStringAsFixed(0)} FCFA', text, sub),
                    _totalRow('TVA ($_taxRate%)', '${_taxAmount.toStringAsFixed(0)} FCFA', text, sub),
                    if (_discount > 0)
                      _totalRow('Remise', '-${_discount.toStringAsFixed(0)} FCFA', Colors.red, sub),
                    const Divider(height: 8),
                    _totalRow('TOTAL TTC', '${_total.toStringAsFixed(0)} FCFA', primary, sub, bold: true, large: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Footer Submit Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveInvoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Enregistrer',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productTile(LineItem item, int index, bool isDark, Color text, Color sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description, style: TextStyle(color: text, fontSize: 13)),
                Text(
                  '${item.quantity} x ${item.unitPrice.toStringAsFixed(0)} FCFA',
                  style: TextStyle(color: sub, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
            onPressed: () => setState(() => _items.removeAt(index)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, Color color, Color sub,
      {bool bold = false, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: sub, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: large ? 17 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _addProduct() {
    final qty = int.tryParse(_quantityController.text);
    final price = double.tryParse(_unitPriceController.text);

    if (_productController.text.trim().isEmpty || qty == null || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisies invalides ou manquantes'), backgroundColor: Colors.orange),
      );
      return;
    }

    final item = LineItem(
      description: _productController.text.trim(),
      quantity: qty,
      unitPrice: price,
      taxRate: _taxRate,
    );

    setState(() {
      _items.add(item);
      _productController.clear();
      _quantityController.clear();
      _unitPriceController.clear();
    });
  }

  // ===== DIALOGUE PRODUIT DEPUIS LE STOCK AVEC QUANTITÉ =====
  void _showStockProductsDialog() {
    final theme = context.read<ThemeProvider>();
    Product? selectedProduct;
    int quantity = 1;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: theme.cardColor,
              title: Text('Ajouter depuis le stock', style: TextStyle(color: theme.textColor)),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    // Liste des produits
                    Expanded(
                      child: ListView.builder(
                        itemCount: _stockProducts.length,
                        itemBuilder: (subCtx, i) {
                          final p = _stockProducts[i];
                          final isSelected = selectedProduct?.id == p.id;
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: theme.primaryColor.withOpacity(0.1),
                              child: Text(p.name.isNotEmpty ? p.name[0] : 'P',
                                  style: TextStyle(color: theme.primaryColor)),
                            ),
                            title: Text(p.name, style: TextStyle(color: theme.textColor, fontSize: 14)),
                            subtitle: Text(
                              '${p.price.toStringAsFixed(0)} FCFA · Stock: ${p.quantity} ${p.unit}',
                              style: TextStyle(color: theme.subTextColor, fontSize: 12),
                            ),
                            trailing: isSelected ? Icon(Icons.check_circle, color: theme.primaryColor) : null,
                            onTap: () => setDialogState(() => selectedProduct = p),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Champ quantité
                    if (selectedProduct != null) ...[
                      Row(
                        children: [
                          const Text('Quantité :', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: '1',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                              onChanged: (v) {
                                final val = int.tryParse(v);
                                if (val != null && val > 0) quantity = val;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stock disponible : ${selectedProduct!.quantity} ${selectedProduct?.unit}',
                        style: TextStyle(color: theme.subTextColor, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Annuler', style: TextStyle(color: theme.subTextColor)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedProduct == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Sélectionnez un produit'), backgroundColor: Colors.orange),
                      );
                      return;
                    }
                    if (quantity <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Quantité invalide'), backgroundColor: Colors.orange),
                      );
                      return;
                    }
                    if (quantity > selectedProduct!.quantity) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text('Stock insuffisant (disponible : ${selectedProduct!.quantity})'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final item = LineItem(
                      description: selectedProduct!.name,
                      quantity: quantity,
                      unitPrice: selectedProduct!.price,
                      taxRate: _taxRate,
                    );
                    setState(() => _items.add(item));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===== SÉLECTION CLIENT =====
  Future<void> _selectClient() async {
    if (_clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun client enregistré'), backgroundColor: Colors.orange),
      );
      return;
    }
    final theme = context.read<ThemeProvider>();
    final client = await showDialog<Client>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: theme.cardColor,
        title: Text('Clients', style: TextStyle(color: theme.textColor)),
        content: SizedBox(
          width: double.maxFinite,
          height: 280,
          child: ListView.builder(
            itemCount: _clients.length,
            itemBuilder: (subCtx, i) => ListTile(
              title: Text(_clients[i].name, style: TextStyle(color: theme.textColor, fontSize: 14)),
              subtitle: Text(_clients[i].phone, style: TextStyle(color: theme.subTextColor, fontSize: 12)),
              onTap: () => Navigator.pop(subCtx, _clients[i]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: theme.subTextColor)),
          ),
        ],
      ),
    );
    if (client != null && mounted) {
      setState(() {
        _selectedClient = client;
        _clientController.text = client.name;
      });
    }
  }

  // ===== SAUVEGARDE AVEC MISE À JOUR DU STOCK =====
  Future<void> _saveInvoice() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un client'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un produit'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Vérifier la disponibilité du stock pour chaque produit (si c'est une facture, pas un devis)
    // On vérifie pour les produits issus du stock (on pourrait avoir ajouté des produits manuels sans lien avec le stock)
    // On va essayer de retrouver les produits par leur nom (approximation)
    if (!_isDevis) {
      // Récupérer les produits depuis le stock pour vérification
      final allProducts = await _stockService.getProducts();
      final productMap = {for (var p in allProducts) p.name: p};

      for (var item in _items) {
        final product = productMap[item.description];
        if (product != null) {
          if (item.quantity > product.quantity) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Stock insuffisant pour "${item.description}" (disponible : ${product.quantity})'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
        // Si le produit n'existe pas dans le stock, on ignore (produit manuel)
      }
    }

    setState(() => _isSaving = true);

    try {
      final company = await _db.getCompany();
      if (!mounted) return;

      if (company == null) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurez votre entreprise'), backgroundColor: Colors.orange),
        );
        return;
      }

      final nextNumber = await _db.getNextInvoiceNumber(_isDevis);
      final invoice = Invoice(
        companyId: company.id,
        clientId: _selectedClient!.id,
        invoiceNumber: nextNumber,
        issueDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        items: _items,
        subtotal: _subtotal,
        taxRate: _taxRate,
        taxAmount: _taxAmount,
        discount: _discount,
        totalAmount: _total,
        terms: _terms,
        isDevis: _isDevis,
        notes: _notesController.text.trim(),
      );

      await _db.addInvoice(invoice);

      // Mise à jour du stock (seulement pour les factures, pas les devis)
      if (!_isDevis) {
        final allProducts = await _stockService.getProducts();
        final productMap = {for (var p in allProducts) p.name: p};

        for (var item in _items) {
          final product = productMap[item.description];
          if (product != null) {
            final newQuantity = product.quantity - item.quantity;
            if (newQuantity >= 0) {
              await _stockService.updateStock(product.id, newQuantity);
            }
          }
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isDevis ? 'Devis créé !' : 'Facture créée et stock mis à jour !'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }
}