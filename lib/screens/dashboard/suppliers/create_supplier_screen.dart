// lib/screens/dashboard/suppliers/create_supplier_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/supplier_service.dart';
import '../../../models/supplier.dart';
import '../../../widgets/glass_widgets.dart';

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
          isActive: _isActive, userId: '',
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
          isActive: _isActive, updatedAt: DateTime.now(),
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
    final textColor = themeProvider.textColor;
    final primaryColor = themeProvider.primaryColor;
    final isEditing = widget.supplier != null;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Modifier fournisseur' : 'Nouveau fournisseur',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isEditing ? 'Enregistrer' : 'Ajouter',
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GlassTextField(
                      label: 'Nom *',
                      controller: _nameController,
                      prefixIcon: Icons.business_outlined,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          v?.trim().isEmpty ?? true ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 14),
                    GlassTextField(
                      label: 'Email',
                      controller: _emailController,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v?.isNotEmpty == true && !v!.contains('@')) {
                          return 'Email invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    GlassTextField(
                      label: 'Téléphone',
                      controller: _phoneController,
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    GlassTextField(
                      label: 'Adresse',
                      controller: _addressController,
                      prefixIcon: Icons.location_on_outlined,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 14),
                    GlassTextField(
                      label: 'NUI / RCCM',
                      controller: _taxIdController,
                      prefixIcon: Icons.assignment_outlined,
                    ),
                    const SizedBox(height: 14),
                    GlassTextField(
                      label: 'Personne de contact',
                      controller: _contactPersonController,
                      prefixIcon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 14),
                    GlassTextField(
                      label: 'Notes',
                      controller: _notesController,
                      prefixIcon: Icons.note_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // Sélecteur de statut (carte soft)
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      borderRadius: BorderRadius.circular(14),
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
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isActive
                                    ? 'Actif (associable aux produits)'
                                    : 'Inactif',
                                style: TextStyle(
                                  color: themeProvider.subTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: _isActive,
                            onChanged: (value) =>
                                setState(() => _isActive = value),
                            activeColor: primaryColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      label: isEditing
                          ? 'Sauvegarder le fournisseur'
                          : 'Ajouter le fournisseur',
                      icon: Icons.check_circle_outline_rounded,
                      height: 52,
                      onPressed: _saveSupplier,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}