// lib/screens/dashboard/stock/create_product_screen.dart
// ignore_for_file: deprecated_member_use
//
// 🎨 Création / édition produit épurée — sections claires, photo centrée.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/subscription_provider.dart';
import '../../../services/stock_service.dart';
import '../../../services/supplier_service.dart';
import '../../../services/quota_enforcement_service.dart';
import '../../../models/product.dart';
import '../../../models/plan.dart';
import '../../../models/supplier.dart';
import '../../../widgets/glass_widgets.dart';
import '../../../widgets/logo_image.dart';
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
  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;

  String? _imageData;

  final List<String> _unitOptions = [
    'pièce',
    'kg',
    'litre',
    'mètre',
    'boîte',
    'sac',
    'carton',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _supplierService.init();
    final allSuppliers = await _supplierService.getSuppliers();
    if (!mounted) return;

    final activeSuppliers = allSuppliers.where((s) => s.isActive).toList();

    setState(() {
      _suppliers = activeSuppliers;
      _isLoadingSuppliers = false;
    });

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
      _imageData = widget.product!.imagePath;

      if (widget.product!.supplierId != null) {
        final matches =
            _suppliers.where((s) => s.id == widget.product!.supplierId);
        if (matches.isNotEmpty) {
          setState(() => _selectedSupplier = matches.first);
        }
      }
    } else {
      _unitController.text = 'pièce';
      _minStockController.text = '5';
      _selectedSupplier = null;
    }
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

    if (widget.product == null) {
      final sub = context.read<SubscriptionProvider>();
      final plan = sub.currentPlan ?? Plan.getFreePlan();
      final result = await QuotaEnforcementService().canAddProduct(plan);
      if (!result.isAllowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ??
                'Limite de produits atteinte. Passez au plan supérieur.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    }

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
      imagePath: _imageData,
      userId: '',
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
          imagePath: _imageData,
          supplierId: product.supplierId,
          updatedAt: DateTime.now(),
        );
        await _stockService.updateProduct(updated);
      } else {
        await _stockService.addProduct(product);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.product != null
              ? 'Produit modifié ✓'
              : 'Produit ajouté ✓'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshSuppliers() async {
    setState(() => _isLoadingSuppliers = true);
    final all = await _supplierService.getSuppliers();
    if (!mounted) return;
    setState(() {
      _suppliers = all.where((s) => s.isActive).toList();
      _isLoadingSuppliers = false;
    });
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 82,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final mime = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
      if (mounted) setState(() => _imageData = dataUri);
    } catch (e) {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        final f = result.files.first;
        final bytes = f.bytes;
        if (bytes == null) return;
        final ext = (f.extension ?? 'jpg').toLowerCase();
        final mime = ext == 'png'
            ? 'image/png'
            : ext == 'webp'
                ? 'image/webp'
                : 'image/jpeg';
        final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
        if (mounted) setState(() => _imageData = dataUri);
      } catch (e2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de charger l\'image : $e2'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;

    final isEditing = widget.product != null;

    return GlassScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: text, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditing ? 'Modifier le produit' : 'Nouveau produit',
          style: TextStyle(
            color: text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProduct,
            style: TextButton.styleFrom(
              foregroundColor: primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: primary),
                  )
                : Text(
                    isEditing ? 'Enregistrer' : 'Ajouter',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Photo centrée ──
              Center(
                child: _buildPhotoPicker(isDark, primary, sub),
              ),
              const SizedBox(height: 28),

              // ── Section : Informations de base ──
              _sectionLabel('Informations', sub),
              const SizedBox(height: 10),
              _field(
                controller: _nameController,
                label: 'Nom du produit',
                hint: 'Ex : Ordinateur portable',
                icon: Icons.inventory_2_outlined,
                isDark: isDark,
                text: text,
                sub: sub,
                primary: primary,
                validator: (v) => v?.trim().isEmpty == true ? 'Requis' : null,
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 12),
              _field(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Description courte du produit',
                icon: Icons.description_outlined,
                isDark: isDark,
                text: text,
                sub: sub,
                primary: primary,
                maxLines: 3,
              ).animate().fadeIn(delay: 50.ms, duration: 300.ms),
              const SizedBox(height: 24),

              // ── Section : Stock & prix ──
              _sectionLabel('Stock & prix', sub),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _quantityController,
                      label: 'Quantité',
                      hint: '0',
                      icon: Icons.numbers_outlined,
                      isDark: isDark,
                      text: text,
                      sub: sub,
                      primary: primary,
                      keyboard: TextInputType.number,
                      validator: (v) {
                        if (v?.trim().isEmpty == true) return 'Requis';
                        if (int.tryParse(v!) == null) return 'Invalide';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dropdown(
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
                  ),
                ],
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _priceController,
                      label: 'Prix de vente',
                      hint: '0 FCFA',
                      icon: Icons.attach_money_outlined,
                      isDark: isDark,
                      text: text,
                      sub: sub,
                      primary: primary,
                      keyboard: TextInputType.number,
                      validator: (v) {
                        if (v?.trim().isEmpty == true) return 'Requis';
                        if (double.tryParse(v!) == null) return 'Invalide';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _costPriceController,
                      label: 'Prix d\'achat',
                      hint: '0 FCFA',
                      icon: Icons.shopping_cart_outlined,
                      isDark: isDark,
                      text: text,
                      sub: sub,
                      primary: primary,
                      keyboard: TextInputType.number,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
              const SizedBox(height: 12),
              _field(
                controller: _minStockController,
                label: 'Stock minimal',
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
                  if (parsed == null || parsed < 0) return 'Invalide';
                  return null;
                },
              ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
              const SizedBox(height: 24),

              // ── Section : Organisation ──
              _sectionLabel('Organisation', sub),
              const SizedBox(height: 10),
              _field(
                controller: _categoryController,
                label: 'Catégorie',
                hint: 'Ex : Électronique',
                icon: Icons.category_outlined,
                isDark: isDark,
                text: text,
                sub: sub,
                primary: primary,
              ).animate().fadeIn(delay: 250.ms, duration: 300.ms),
              const SizedBox(height: 12),
              _supplierField(
                isDark: isDark,
                text: text,
                sub: sub,
                primary: primary,
                isLoading: _isLoadingSuppliers,
              ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
              const SizedBox(height: 12),
              _field(
                controller: _barcodeController,
                label: 'Code-barres',
                hint: 'Optionnel',
                icon: Icons.qr_code_outlined,
                isDark: isDark,
                text: text,
                sub: sub,
                primary: primary,
              ).animate().fadeIn(delay: 350.ms, duration: 300.ms),
              const SizedBox(height: 32),

              // ── Bouton ──
              GradientButton(
                label: isEditing
                    ? 'Enregistrer les modifications'
                    : 'Ajouter le produit',
                icon: Icons.check_circle_outline_rounded,
                height: 54,
                loading: _isLoading,
                onPressed: _saveProduct,
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String title, Color sub) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: sub,
      ),
    );
  }

  // ── Photo picker centré ──
  Widget _buildPhotoPicker(bool isDark, Color primary, Color sub) {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: _imageData != null
                      ? LogoImage(
                          path: _imageData,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        )
                      : Icon(
                          Icons.add_a_photo_outlined,
                          color: sub.withValues(alpha: 0.6),
                          size: 32,
                        ),
                ),
              ),
              Positioned(
                right: -6,
                bottom: -6,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _imageData != null
                        ? Icons.edit_rounded
                        : Icons.add_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _imageData != null
              ? () => setState(() => _imageData = null)
              : _pickImage,
          style: TextButton.styleFrom(
            foregroundColor: _imageData != null ? Colors.redAccent : primary,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            _imageData != null ? 'Supprimer la photo' : 'Ajouter une photo',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ── Champ épuré (underline au focus) ──
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
      style: TextStyle(color: text, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: sub,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: sub.withValues(alpha: 0.5),
          fontSize: 13.5,
        ),
        prefixIcon: Icon(icon, size: 20, color: primary.withValues(alpha: 0.7)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.025),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: primary.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.red.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.red.withValues(alpha: 0.8),
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        isDense: true,
      ),
    );
  }

  // ── Champ fournisseur ──
  Widget _supplierField({
    required bool isDark,
    required Color text,
    required Color sub,
    required Color primary,
    required bool isLoading,
  }) {
    if (isLoading) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return DropdownButtonFormField<Supplier?>(
      value: _selectedSupplier,
      isExpanded: true,
      style: TextStyle(color: text, fontSize: 14),
      dropdownColor: isDark ? const Color(0xFF1A1D26) : Colors.white,
      decoration: InputDecoration(
        labelText: 'Fournisseur',
        labelStyle: TextStyle(
          color: sub,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(Icons.business_outlined,
            size: 20, color: primary.withValues(alpha: 0.7)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.025),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: primary.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
        DropdownMenuItem<Supplier?>(
          value: null,
          child: Text('Aucun', style: TextStyle(color: sub)),
        ),
        ..._suppliers.map((s) => DropdownMenuItem<Supplier?>(
              value: s,
              child: Text(s.name, style: TextStyle(color: text)),
            )),
      ],
      onChanged: (v) => setState(() => _selectedSupplier = v),
    );
  }

  // ── Dropdown ──
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
    final currentValue =
        options.contains(controller.text) ? controller.text : null;

    return DropdownButtonFormField<String>(
      value: currentValue,
      isExpanded: true,
      style: TextStyle(color: text, fontSize: 14),
      dropdownColor: isDark ? const Color(0xFF1A1D26) : Colors.white,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: sub,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: sub.withValues(alpha: 0.5),
          fontSize: 13.5,
        ),
        prefixIcon: Icon(icon, size: 20, color: primary.withValues(alpha: 0.7)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.025),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: primary.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        isDense: true,
      ),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => controller.text = v);
      },
      validator: (v) => v == null ? 'Requis' : null,
    );
  }
}