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
    _clients = await _db.getClients();
    setState(() {});
  }

  Future<void> _loadStockProducts() async {
    await _stockService.init();
    _stockProducts = await _stockService.getActiveProducts();
    setState(() {});
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
        title: Text(_isDevis ? 'Nouveau devis' : 'Nouvelle facture',
            style: TextStyle(color: text, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: text),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saveInvoice,
            child: Text('Enregistrer', style: TextStyle(color: primary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Type
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Facture'),
                    selected: !_isDevis,
                    onSelected: (_) => setState(() => _isDevis = false),
                    selectedColor: primary,
                    backgroundColor:
                        isDark ? Colors.grey[850] : Colors.grey[100],
                    labelStyle:
                        TextStyle(color: !_isDevis ? Colors.white : sub),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Devis'),
                    selected: _isDevis,
                    onSelected: (_) => setState(() => _isDevis = true),
                    selectedColor: primary,
                    backgroundColor:
                        isDark ? Colors.grey[850] : Colors.grey[100],
                    labelStyle: TextStyle(color: _isDevis ? Colors.white : sub),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Client
              TextFormField(
                controller: _clientController,
                readOnly: true,
                style: TextStyle(color: text),
                decoration: InputDecoration(
                  labelText: 'Client',
                  hintText: 'Sélectionner un client',
                  labelStyle: TextStyle(color: sub),
                  hintStyle: TextStyle(color: sub.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.person_outline, color: sub),
                  suffixIcon: Icon(Icons.arrow_drop_down, color: sub),
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onTap: _selectClient,
              ),
              const SizedBox(height: 12),

              // Ligne produit
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _productController,
                      style: TextStyle(color: text),
                      decoration: InputDecoration(
                        labelText: 'Produit',
                        labelStyle: TextStyle(color: sub),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: text),
                      decoration: InputDecoration(
                        labelText: 'Qté',
                        labelStyle: TextStyle(color: sub),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _unitPriceController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: text),
                      decoration: InputDecoration(
                        labelText: 'Prix',
                        labelStyle: TextStyle(color: sub),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
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
                    child: Text('Depuis le stock',
                        style: TextStyle(color: primary, fontSize: 12)),
                  ),
                ),
              ],

              // Liste des produits
              if (_items.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._items.asMap().entries.map(
                    (e) => _productTile(e.value, e.key, isDark, text, sub)),
              ],

              const SizedBox(height: 12),

              // Livraison
              TextFormField(
                controller: _deliveryFeeController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: text),
                decoration: InputDecoration(
                  labelText: 'Frais de livraison',
                  hintText: '0',
                  labelStyle: TextStyle(color: sub),
                  hintStyle: TextStyle(color: sub.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.local_shipping, color: sub),
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),

              // TVA & Remise
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: text),
                      decoration: InputDecoration(
                        labelText: 'TVA %',
                        labelStyle: TextStyle(color: sub),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      initialValue: _taxRate.toString(),
                      onChanged: (v) =>
                          setState(() => _taxRate = double.tryParse(v) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: text),
                      decoration: InputDecoration(
                        labelText: 'Remise',
                        labelStyle: TextStyle(color: sub),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      initialValue: _discount.toString(),
                      onChanged: (v) =>
                          setState(() => _discount = double.tryParse(v) ?? 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                style: TextStyle(color: text),
                decoration: InputDecoration(
                  labelText: 'Notes',
                  labelStyle: TextStyle(color: sub),
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Totaux
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _totalRow('Sous-total',
                        '${_subtotal.toStringAsFixed(0)} FCFA', text, sub),
                    _totalRow('Livraison',
                        '${_deliveryFee.toStringAsFixed(0)} FCFA', text, sub),
                    _totalRow('TVA ($_taxRate%)',
                        '${_taxAmount.toStringAsFixed(0)} FCFA', text, sub),
                    if (_discount > 0)
                      _totalRow(
                          'Remise',
                          '-${_discount.toStringAsFixed(0)} FCFA',
                          Colors.red,
                          sub),
                    const Divider(height: 8),
                    _totalRow(
                      'TOTAL TTC',
                      '${_total.toStringAsFixed(0)} FCFA',
                      primary,
                      sub,
                      bold: true,
                      large: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bouton
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _saveInvoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text(
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

  Widget _productTile(
      LineItem item, int index, bool isDark, Color text, Color sub) {
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
                Text(item.description, style: TextStyle(color: text)),
                Text(
                  '${item.quantity} x ${item.unitPrice.toStringAsFixed(0)} FCFA',
                  style: TextStyle(color: sub, fontSize: 12),
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
    if (_productController.text.isEmpty ||
        _quantityController.text.isEmpty ||
        _unitPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Remplissez tous les champs'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    final item = LineItem(
      description: _productController.text,
      quantity: int.parse(_quantityController.text),
      unitPrice: double.parse(_unitPriceController.text),
      taxRate: _taxRate,
    );
    setState(() {
      _items.add(item);
      _productController.clear();
      _quantityController.clear();
      _unitPriceController.clear();
    });
  }

  void _showStockProductsDialog() {
    final theme = context.read<ThemeProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: theme.cardColor,
        title: Text('Stock', style: TextStyle(color: theme.textColor)),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: ListView.builder(
            itemCount: _stockProducts.length,
            itemBuilder: (ctx, i) {
              final p = _stockProducts[i];
              return ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  child: Text(p.name[0],
                      style: TextStyle(color: theme.primaryColor)),
                ),
                title: Text(p.name, style: TextStyle(color: theme.textColor)),
                subtitle: Text(
                  '${p.price.toStringAsFixed(0)} FCFA · Stock: ${p.quantity} ${p.unit}',
                  style: TextStyle(color: theme.subTextColor),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  final item = LineItem(
                    description: p.name,
                    quantity: 1,
                    unitPrice: p.price,
                    taxRate: _taxRate,
                  );
                  setState(() => _items.add(item));
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: theme.subTextColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _selectClient() async {
    if (_clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aucun client'), backgroundColor: Colors.orange),
      );
      return;
    }
    final client = await showDialog<Client>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.read<ThemeProvider>().cardColor,
        title: Text('Clients',
            style: TextStyle(color: context.read<ThemeProvider>().textColor)),
        content: SizedBox(
          width: double.maxFinite,
          height: 280,
          child: ListView.builder(
            itemCount: _clients.length,
            itemBuilder: (ctx, i) => ListTile(
              title: Text(_clients[i].name,
                  style: TextStyle(
                      color: context.read<ThemeProvider>().textColor)),
              subtitle: Text(_clients[i].phone,
                  style: TextStyle(
                      color: context.read<ThemeProvider>().subTextColor)),
              onTap: () => Navigator.pop(ctx, _clients[i]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler',
                style: TextStyle(
                    color: context.read<ThemeProvider>().subTextColor)),
          ),
        ],
      ),
    );
    if (client != null) {
      setState(() {
        _selectedClient = client;
        _clientController.text = client.name;
      });
    }
  }

  Future<void> _saveInvoice() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sélectionnez un client'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ajoutez au moins un produit'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final company = await _db.getCompany();
      if (company == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Configurez votre entreprise'),
              backgroundColor: Colors.orange),
        );
        return;
      }
      final invoice = Invoice(
        companyId: company.id,
        clientId: _selectedClient!.id,
        invoiceNumber: await _db.getNextInvoiceNumber(_isDevis),
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
        notes: _notesController.text,
      );
      await _db.addInvoice(invoice);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Facture créée !'), backgroundColor: Colors.green),
      );
      context.pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
