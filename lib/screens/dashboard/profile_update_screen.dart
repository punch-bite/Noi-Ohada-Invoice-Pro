// lib/screens/dashboard/profile_update_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/database_service.dart';

class ProfileUpdateScreen extends StatefulWidget {
  const ProfileUpdateScreen({super.key});

  @override
  State<ProfileUpdateScreen> createState() => _ProfileUpdateScreenState();
}

class _ProfileUpdateScreenState extends State<ProfileUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _companyController;
  late TextEditingController _addressController;
  
  final bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AppAuthProvider>();
    final user = authProvider.user;
    
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _companyController = TextEditingController(text: user?.companyName ?? '');
    _addressController = TextEditingController(text: user?.companyAddress ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final authProvider = context.read<AppAuthProvider>();
      final user = authProvider.user;
      
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Mettre à jour les informations
      final updatedUser = user.copyWith(
        displayName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        companyName: _companyController.text.trim(),
        companyAddress: _addressController.text.trim(),
      );

      // Sauvegarder dans la base de données
      await _db.updateUser(updatedUser);
      
      // Mettre à jour le provider
      await authProvider.refreshUser();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis à jour avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AppAuthProvider>();
    final user = authProvider.user;
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final primaryColor = themeProvider.primaryColor;
    final bgColor = themeProvider.backgroundColor;
    final cardColor = themeProvider.cardColor;
    final inputFillColor = themeProvider.inputFillColor;
    final inputBorderColor = themeProvider.inputBorderColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Modifier le profil',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: Text(
              'Enregistrer',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      user?.displayName.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Nom complet
              _buildTextField(
                controller: _nameController,
                label: 'Nom complet *',
                hint: 'Votre nom',
                icon: Icons.person_outline,
                isDark: isDark,
                textColor: textColor,
                subTextColor: subTextColor,
                primaryColor: primaryColor,
                inputFillColor: inputFillColor,
                inputBorderColor: inputBorderColor,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez saisir votre nom';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Téléphone
              _buildTextField(
                controller: _phoneController,
                label: 'Téléphone',
                hint: '+237 6XX XX XX XX',
                icon: Icons.phone_outlined,
                isDark: isDark,
                textColor: textColor,
                subTextColor: subTextColor,
                primaryColor: primaryColor,
                inputFillColor: inputFillColor,
                inputBorderColor: inputBorderColor,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Entreprise
              _buildTextField(
                controller: _companyController,
                label: 'Entreprise',
                hint: 'Nom de votre entreprise',
                icon: Icons.business_outlined,
                isDark: isDark,
                textColor: textColor,
                subTextColor: subTextColor,
                primaryColor: primaryColor,
                inputFillColor: inputFillColor,
                inputBorderColor: inputBorderColor,
              ),
              const SizedBox(height: 16),

              // Adresse
              _buildTextField(
                controller: _addressController,
                label: 'Adresse',
                hint: 'Votre adresse',
                icon: Icons.location_on_outlined,
                isDark: isDark,
                textColor: textColor,
                subTextColor: subTextColor,
                primaryColor: primaryColor,
                inputFillColor: inputFillColor,
                inputBorderColor: inputBorderColor,
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              // Bouton Enregistrer
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Enregistrer les modifications',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
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
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: subTextColor),
        hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
        prefixIcon: Icon(icon, color: primaryColor),
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
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}