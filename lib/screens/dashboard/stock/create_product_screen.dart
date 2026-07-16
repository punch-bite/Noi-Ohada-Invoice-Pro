// lib/screens/dashboard/stock/create_product_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/stock_service.dart';
import '../../../services/supplier_service.dart';
import '../../../models/product.dart';
import '../../../models/supplier.dart';
import '../suppliers/create_supplier_screen.dart';

class CreateProductScreen extends StatefulWidget {
  final Product? product;
  const CreateProductScreen({super.key, this.product});

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _minStockController = TextEditingController();
  final _categoryController = TextEditingController();
  final _unitController = TextEditingController();
  final _barcodeController = TextEditingController();

  final StockService _stockService = StockService();
  final SupplierService _supplierService = SupplierService();

  bool _isLoading = false;
  bool _isLoadingSuppliers = true;
  List<Supplier> _suppliers = []; // ✅ Toujours une liste, jamais null
  Supplier? _selectedSupplier;

  final List<String> _unitOptions = [
    'pièce',
    'kg',
    'litre',
    'mètre',
    'boîte',
    'sac',
    'carton'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // ===== INITIALISATION ROBUSTE =====
  Future<void> _initializeData() async {
    await _supplierService.init();
    final activeSuppliers = await _supplierService.getActiveSupplier();

    if (!mounted) return;

    // ✅ Conversion sécurisée en List<Supplier>
    final List<Supplier> supplierList = _safeCastToList(activeSuppliers);

    setState(() {
      _suppliers = supplierList;
      _isLoadingSuppliers = false;
    });

    // Remplir les champs si modification
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _descriptionController.text = widget.product!.description;
      _quantityController.text = widget.product!.quantity.toString();
      _priceController.text = widget.product!.price.toString();
      _costPriceController.text = widget.product!.costPrice.toString();
      _minStockController.text = widget.product!.minStock.toString();
      _categoryController.text = widget.product!.category;
      _unitController.text = widget.product!.unit;
      _barcodeController.text = widget.product!.barcode ?? '';

      if (widget.product!.supplierId != null) {
        setState(() {
          _selectedSupplier = _suppliers.firstWhere(
            (s) => s.id == widget.product!.supplierId,
            orElse: () => null as Supplier,
          );
        });
      }
    } else {
      _unitController.text = 'pièce';
      _minStockController.text = '5';
      _selectedSupplier = null;
    }
  }

  // ===== UTILITAIRE DE CAST SÉCURISÉ =====
  List<Supplier> _safeCastToList(dynamic data) {
    if (data == null) return [];
    if (data is List<Supplier>) return data;
    if (data is Iterable) {
      try {
        return data.map((e) => e as Supplier).toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _minStockController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final product = Product(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      quantity: int.tryParse(_quantityController.text) ?? 0,
      price: double.tryParse(_priceController.text) ?? 0.0,
      costPrice: double.tryParse(_costPriceController.text) ?? 0.0,
      minStock: int.tryParse(_minStockController.text) ?? 5,
      category: _categoryController.text.trim().isEmpty
          ? 'Autres'
          : _categoryController.text.trim(),
      unit: _unitController.text.trim().isEmpty
          ? 'pièce'
          : _unitController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      supplierId: _selectedSupplier?.id,
    );

    try {
      if (widget.product != null) {
        final updated = widget.product!.copyWith(
          name: product.name,
          description: product.description,
          quantity: product.quantity,
          price: product.price,
          costPrice: product.costPrice,
          minStock: product.minStock,
          category: product.category,
          unit: product.unit,
          barcode: product.barcode,
          supplierId: product.supplierId,
        );
        await _stockService.updateProduct(updated);
      } else {
        await _stockService.addProduct(product);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              widget.product != null ? 'Produit modifié' : 'Produit ajouté'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshSuppliers() async {
    setState(() => _isLoadingSuppliers = true);
    final activeSuppliers = await _supplierService.getActiveSupplier();
    if (!mounted) return;
    setState(() {
      _suppliers = _safeCastToList(activeSuppliers);
      _isLoadingSuppliers = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;

    final isEditing = widget.product != null;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditing ? 'Modifier produit' : 'Nouveau produit',
          style:
              TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProduct,
            child: Text(
              isEditing ? 'Modifier' : 'Ajouter',
              style: TextStyle(color: primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Nom ---
              _field(
                controller: _nameController,
                label: 'Nom du produit *',
                hint: 'Ex: Ordinateur portable',
                icon: Icons.inventory_2_outlined,
                isDark: isDark,
                text: text,
                sub: sub,
                primary: primary,
                validator: (v) => v?.trim().isEmpty == true ? 'Requis' : null,
              ),
              const SizedBox(height: 12),

              // --- Description ---
              _field(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Description du produit',
                icon: Icons.description_outlined,
                isDark: isDark,
                text: text,
                sub: sub,
                primary: primary,
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              // --- Quantité & Prix ---
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _quantityController,
                      label: 'Quantité *',
                      hint: '0',
                      icon: Icons.numbers_outlined,
                      isDark: isDark,
                      text: text,
                      sub: sub,
                      primary: primary,
                      keyboard: TextInputType.number,
                      validator: (v) {
                        if (v?.trim().isEmpty == true) return 'Requis';
                        if (int.tryParse(v!) == null) return 'Nombre valide';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _priceController,
                      label: 'Prix de vente *',
                      hint: '0 FCFA',
                      icon: Icons.attach_money_outlined,
                      isDark: isDark,
                      text: text,
                      sub: sub,
                      primary: primary,
                      keyboard: TextInputType.number,
                      validator: (v) {
                        if (v?.trim().isEmpty == true) return 'Requis';
                        if (double.tryParse(v!) == null) return 'Prix valide';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // --- Prix d'achat & Stock minimal ---
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _costPriceController,
                      label: "Prix d'achat",
                      hint: '0 FCFA',
                      icon: Icons.shopping_cart_outlined,
                      isDark: isDark,
                      text: text,
                      sub: sub,
                      primary: primary,
                      keyboard: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _minStockController,
                      label: 'Stock minimal *',
                      hint: '5',
                      icon: Icons.warning_amber_outlined,
                      isDark: isDark,
                      text: text,
                      sub: sub,
                      primary: primary,
                      keyboard: TextInputType.number,
                      validator: (v) {
                        if (v?.trim().isEmpty == true) return 'Requis';
                        final parsed = int.tryParse(v!);
                        if (parsed == null || parsed < 0) {
                          return 'Nombre valide';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // --- Catégorie ---
              _field(
                controller: _categoryController,
                label: 'Catégorie',
                hint: 'Ex: Électronique',
                icon: Icons.category_outlined,
                isDark: isDark,
                text: text,
                sub: sub,
                primary: primary,
              ),
              const SizedBox(height: 12),

              // --- Fournisseur ---
              _supplierField(
                isDark: isDark,
                text: text,
                sub: sub,
                primary: primary,
                isLoading: _isLoadingSuppliers,
              ),
              const SizedBox(height: 12),

              // --- Unité ---
              _dropdown(
                controller: _unitController,
                label: 'Unité',
                hint: 'pièce',
                icon: Icons.scale_outlined,
                options: _unitOptions,
                isDark: isDark,
                text: text,
                sub: sub,
                primary: primary,
              ),
              const SizedBox(height: 12),

              // --- Code-barres ---
              _field(
                controller: _barcodeController,
                label: 'Code-barres',
                hint: 'Optionnel',
                icon: Icons.qr_code_outlined,
                isDark: isDark,
                text: text,
                sub: sub,
                primary: primary,
              ),
              const SizedBox(height: 24),

              // --- Bouton ---
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          isEditing
                              ? 'Modifier le produit'
                              : 'Ajouter le produit',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Champ simple ---
  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color text,
    required Color sub,
    required Color primary,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(color: text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: sub, fontSize: 13),
        hintStyle: TextStyle(color: sub.withOpacity(0.6), fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: primary.withOpacity(0.5)),
        filled: true,
        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
  }

  // --- Champ fournisseur ---
  Widget _supplierField({
    required bool isDark,
    required Color text,
    required Color sub,
    required Color primary,
    required bool isLoading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: LinearProgressIndicator(),
          )
        else
          DropdownButtonFormField<Supplier?>(
            value: _selectedSupplier,
            isExpanded: true,
            style: TextStyle(color: text, fontSize: 14),
            dropdownColor: isDark ? Colors.grey[850] : Colors.white,
            decoration: InputDecoration(
              labelText: 'Fournisseur (optionnel)',
              hintText: 'Sélectionner',
              labelStyle: TextStyle(color: sub, fontSize: 13),
              hintStyle: TextStyle(color: sub.withOpacity(0.6), fontSize: 13),
              prefixIcon: Icon(Icons.business_outlined,
                  size: 20, color: primary.withOpacity(0.5)),
              filled: true,
              fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(Icons.add_circle_outline, color: primary, size: 20),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreateSupplierScreen()),
                  );
                  if (result == true) await _refreshSuppliers();
                },
              ),
            ),
            items: [
              const DropdownMenuItem<Supplier?>(
                value: null,
                child: Text('Aucun'),
              ),
              ..._suppliers.map((s) => DropdownMenuItem<Supplier?>(
                    value: s,
                    child: Text(s.name, style: TextStyle(color: text)),
                  )),
            ],
            onChanged: (v) => setState(() => _selectedSupplier = v),
          ),
      ],
    );
  }

  // --- Dropdown unité ---
  Widget _dropdown({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required List<String> options,
    required bool isDark,
    required Color text,
    required Color sub,
    required Color primary,
  }) {
    final String? currentValue =
        options.contains(controller.text) ? controller.text : null;

    return DropdownButtonFormField<String>(
      value: currentValue,
      isExpanded: true,
      style: TextStyle(color: text, fontSize: 14),
      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: sub, fontSize: 13),
        hintStyle: TextStyle(color: sub.withOpacity(0.6), fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: primary.withOpacity(0.5)),
        filled: true,
        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        isDense: true,
      ),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          setState(() => controller.text = v);
        }
      },
      validator: (v) => v == null ? 'Requis' : null,
    );
  }
}