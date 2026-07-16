// lib/screens/dashboard/company_config_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/database_service.dart';
import '../../models/company.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/logo_image.dart';
import 'dart:convert';

class CompanyConfigScreen extends StatefulWidget {
  const CompanyConfigScreen({super.key});

  @override
  State<CompanyConfigScreen> createState() => _CompanyConfigScreenState();
}

class _CompanyConfigScreenState extends State<CompanyConfigScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _taxIdController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _legalTextController;
  late TextEditingController _websiteController;
  late TextEditingController _rccmController;
  late TextEditingController _taxRateController; // ✅ Correctement déclaré ici

  String _currency = 'XAF';
  double _defaultTaxRate = 18.0;
  String? _logoPath;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _taxIdController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _legalTextController = TextEditingController();
    _websiteController = TextEditingController();
    _rccmController = TextEditingController();
    _taxRateController = TextEditingController(text: _defaultTaxRate.toString()); // ✅ Initialisé
    _loadCompany();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _legalTextController.dispose();
    _websiteController.dispose();
    _rccmController.dispose();
    _taxRateController.dispose(); // ✅ Libéré
    super.dispose();
  }

  Future<void> _loadCompany() async {
    setState(() => _isLoading = true);
    final company = await _db.getCompany();
    if (!mounted) return;

    if (company != null) {
      _nameController.text = company.name;
      _addressController.text = company.address;
      _taxIdController.text = company.taxId;
      _phoneController.text = company.phone;
      _emailController.text = company.email;
      _legalTextController.text = company.legalText;
      _websiteController.text = company.website;
      _rccmController.text = company.rccm;
      _currency = company.currency;
      _defaultTaxRate = company.defaultTaxRate;
      _taxRateController.text = _defaultTaxRate.toString(); // ✅ Met à jour le contrôleur
      _logoPath = company.logoPath;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final ext = image.path.split('.').last.toLowerCase();
        final mimeType = ext == 'jpg' || ext == 'jpeg' ? 'jpeg' : 'png';
        final dataUri = 'data:image/$mimeType;base64,$base64String';
        
        if (!mounted) return;
        setState(() => _logoPath = dataUri);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Logo chargé'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {}
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    // Récupération sécurisée du taux de taxe
    _defaultTaxRate = double.tryParse(_taxRateController.text) ?? 18.0;

    final company = Company(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      taxId: _taxIdController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      logoPath: _logoPath ?? '',
      currency: _currency,
      defaultTaxRate: _defaultTaxRate,
      legalText: _legalTextController.text.trim(),
      website: _websiteController.text.trim(),
      rccm: _rccmController.text.trim(),
    );

    await _db.saveCompany(company);
    
    if (!mounted) return;
    setState(() => _isSaving = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Entreprise configurée'),
          backgroundColor: Colors.green),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;
    final card = theme.cardColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Entreprise',
            style: TextStyle(
                color: text, fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save_outlined, color: primary),
            onPressed: _saveCompany,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo
                    _logoSection(isDark, text, sub, primary),
                    const SizedBox(height: 20),

                    // Général
                    _sectionTitle('Général', text),
                    const SizedBox(height: 8),
                    _input(_nameController, 'Nom *', Icons.business_outlined,
                        isDark, text, sub, primary,
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Requis' : null),
                    const SizedBox(height: 12),
                    _input(_addressController, 'Adresse *',
                        Icons.location_on_outlined, isDark, text, sub, primary,
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Requis' : null),

                    const SizedBox(height: 20),

                    // Contact
                    _sectionTitle('Contact', text),
                    const SizedBox(height: 8),
                    _input(_phoneController, 'Téléphone *',
                        Icons.phone_outlined, isDark, text, sub, primary,
                        keyboard: TextInputType.phone,
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Requis' : null),
                    const SizedBox(height: 12),
                    _input(_emailController, 'Email *', Icons.email_outlined,
                        isDark, text, sub, primary,
                        keyboard: TextInputType.emailAddress,
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'Requis'
                            : (!v!.contains('@') ? 'Email invalide' : null)),
                    const SizedBox(height: 12),
                    _input(_websiteController, 'Site web',
                        Icons.language_outlined, isDark, text, sub, primary,
                        keyboard: TextInputType.url),

                    const SizedBox(height: 20),

                    // Légal
                    _sectionTitle('Légal', text),
                    const SizedBox(height: 8),
                    _input(_taxIdController, 'NUI / Identifiant fiscal',
                        Icons.numbers_outlined, isDark, text, sub, primary),
                    const SizedBox(height: 12),
                    _input(_rccmController, 'RCCM', Icons.description_outlined,
                        isDark, text, sub, primary),
                    const SizedBox(height: 12),
                    _input(_legalTextController, 'Mentions légales',
                        Icons.gavel_outlined, isDark, text, sub, primary,
                        maxLines: 3),

                    const SizedBox(height: 20),

                    // Fiscal
                    _sectionTitle('Fiscal', text),
                    const SizedBox(height: 8),
                    _currencyDropdown(isDark, text, sub, primary),
                    const SizedBox(height: 12),
                    _input(
                      _taxRateController, // ✅ Utilise désormais le contrôleur persistant
                      'TVA (%)',
                      Icons.percent_outlined,
                      isDark,
                      text,
                      sub,
                      primary,
                      keyboard: const TextInputType.numberWithOptions(decimal: true),
                    ),

                    const SizedBox(height: 32),

                    // Bouton enregistrer
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveCompany,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Enregistrer',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGETS ---

  Widget _sectionTitle(String title, Color text) {
    return Text(
      title,
      style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: text.withOpacity(0.7)),
    );
  }

  Widget _logoSection(bool isDark, Color text, Color sub, Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickLogo,
            child: LogoImage(
              path: _logoPath,
              width: 64,
              height: 64,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Logo',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: text)),
                Text('Appuyez pour modifier',
                    style: TextStyle(fontSize: 12, color: sub)),
              ],
            ),
          ),
          if (_logoPath != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              onPressed: () => setState(() => _logoPath = null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _input(
    TextEditingController c,
    String label,
    IconData icon,
    bool isDark,
    Color text,
    Color sub,
    Color primary, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      style: TextStyle(color: text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: sub, fontSize: 13),
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

  Widget _currencyDropdown(bool isDark, Color text, Color sub, Color primary) {
    return DropdownButtonFormField<String>(
      value: _currency, // Utilisation de 'value' au lieu de 'initialValue' pour un comportement dynamique robuste
      isExpanded: true,
      style: TextStyle(color: text, fontSize: 14),
      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
      decoration: InputDecoration(
        labelText: 'Devise',
        labelStyle: TextStyle(color: sub, fontSize: 13),
        prefixIcon: Icon(Icons.monetization_on_outlined,
            size: 20, color: primary.withOpacity(0.5)),
        filled: true,
        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(value: 'XAF', child: Text('FCFA (XAF)')),
        DropdownMenuItem(value: 'XOF', child: Text('FCFA (XOF)')),
        DropdownMenuItem(value: 'USD', child: Text('Dollar (USD)')),
        DropdownMenuItem(value: 'EUR', child: Text('Euro (EUR)')),
      ],
      onChanged: (v) {
        if (v != null) {
          setState(() => _currency = v);
        }
      },
    );
  }
}