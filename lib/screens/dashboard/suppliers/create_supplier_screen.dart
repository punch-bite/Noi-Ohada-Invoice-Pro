// lib/screens/dashboard/suppliers/create_supplier_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/supplier_service.dart';
import '../../../models/supplier.dart';

class CreateSupplierScreen extends StatefulWidget {
  final Supplier? supplier;
  const CreateSupplierScreen({super.key, this.supplier});

  @override
  State<CreateSupplierScreen> createState() => _CreateSupplierScreenState();
}

class _CreateSupplierScreenState extends State<CreateSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupplierService _supplierService = SupplierService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _taxIdController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _supplierService.init();
    if (widget.supplier != null) {
      _nameController.text = widget.supplier!.name;
      _emailController.text = widget.supplier!.email;
      _phoneController.text = widget.supplier!.phone;
      _addressController.text = widget.supplier!.address;
      _taxIdController.text = widget.supplier!.taxId;
      _contactPersonController.text = widget.supplier!.contactPerson;
      _notesController.text = widget.supplier!.notes;
      _isActive = widget.supplier!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    _contactPersonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.supplier == null) {
        // Création
        final supplier = Supplier(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          taxId: _taxIdController.text.trim(),
          contactPerson: _contactPersonController.text.trim(),
          notes: _notesController.text.trim(),
          isActive: _isActive,
        );
        await _supplierService.addSupplier(supplier);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fournisseur ajouté avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Modification
        final updated = widget.supplier!.copyWith(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          taxId: _taxIdController.text.trim(),
          contactPerson: _contactPersonController.text.trim(),
          notes: _notesController.text.trim(),
          isActive: _isActive,
        );
        await _supplierService.updateSupplier(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fournisseur modifié avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          widget.supplier == null ? 'Nouveau fournisseur' : 'Modifier fournisseur',
          style: TextStyle(color: textColor),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSupplier,
            child: Text(
              widget.supplier == null ? 'Ajouter' : 'Enregistrer',
              style: TextStyle(color: primaryColor),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      label: 'Nom *',
                      controller: _nameController,
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v?.isNotEmpty == true && !v!.contains('@')) {
                          return 'Email invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Téléphone',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Adresse',
                      controller: _addressController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'NUI / RCCM',
                      controller: _taxIdController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Personne de contact',
                      controller: _contactPersonController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Notes',
                      controller: _notesController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    // Switch actif/inactif
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Fournisseur actif',
                          style: TextStyle(color: textColor),
                        ),
                        Switch(
                          value: _isActive,
                          onChanged: (value) => setState(() => _isActive = value),
                          activeThumbColor: primaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subTextColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: themeProvider.primaryColor,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }
}