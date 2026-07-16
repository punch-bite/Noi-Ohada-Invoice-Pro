// lib/screens/dashboard/suppliers/create_supplier_screen.dart

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
    _initServiceAndData();
  }

  Future<void> _initServiceAndData() async {
    await _supplierService.init();
    if (widget.supplier != null) {
      if (!mounted) return;
      setState(() {
        _nameController.text = widget.supplier!.name;
        _emailController.text = widget.supplier!.email;
        _phoneController.text = widget.supplier!.phone;
        _addressController.text = widget.supplier!.address;
        _taxIdController.text = widget.supplier!.taxId;
        _contactPersonController.text = widget.supplier!.contactPerson;
        _notesController.text = widget.supplier!.notes;
        _isActive = widget.supplier!.isActive;
      });
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
        
        if (!mounted) return;
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
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fournisseur modifié avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    final inputFillColor = themeProvider.inputFillColor;
    final inputBorderColor = themeProvider.inputBorderColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          widget.supplier == null ? 'Nouveau fournisseur' : 'Modifier fournisseur',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSupplier,
            child: _isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue,
                    ),
                  )
                : Text(
                    widget.supplier == null ? 'Ajouter' : 'Enregistrer',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
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
                      icon: Icons.business,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      primaryColor: primaryColor,
                      inputFillColor: inputFillColor,
                      inputBorderColor: inputBorderColor,
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Email',
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      primaryColor: primaryColor,
                      inputFillColor: inputFillColor,
                      inputBorderColor: inputBorderColor,
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
                      icon: Icons.phone_outlined,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      primaryColor: primaryColor,
                      inputFillColor: inputFillColor,
                      inputBorderColor: inputBorderColor,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Adresse',
                      controller: _addressController,
                      icon: Icons.location_on_outlined,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      primaryColor: primaryColor,
                      inputFillColor: inputFillColor,
                      inputBorderColor: inputBorderColor,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'NUI / RCCM',
                      controller: _taxIdController,
                      icon: Icons.assignment_outlined,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      primaryColor: primaryColor,
                      inputFillColor: inputFillColor,
                      inputBorderColor: inputBorderColor,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Personne de contact',
                      controller: _contactPersonController,
                      icon: Icons.person_outline,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      primaryColor: primaryColor,
                      inputFillColor: inputFillColor,
                      inputBorderColor: inputBorderColor,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Notes',
                      controller: _notesController,
                      icon: Icons.note_outlined,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      primaryColor: primaryColor,
                      inputFillColor: inputFillColor,
                      inputBorderColor: inputBorderColor,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    
                    // Sélecteur d'état (Actif / Inactif) enveloppé pour l'esthétique
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: inputFillColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: inputBorderColor, width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Statut du fournisseur',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isActive ? 'Actif (Peut être associé aux produits)' : 'Inactif',
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: _isActive,
                            onChanged: (value) => setState(() => _isActive = value),
                            activeColor: primaryColor,
                          ),
                        ],
                      ),
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
    required IconData icon,
    required Color textColor,
    required Color subTextColor,
    required Color primaryColor,
    required Color inputFillColor,
    required Color inputBorderColor,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subTextColor, fontSize: 13),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        filled: true,
        fillColor: inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        isDense: true,
      ),
      validator: validator,
    );
  }
}