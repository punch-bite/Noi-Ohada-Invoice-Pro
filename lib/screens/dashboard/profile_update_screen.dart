// lib/screens/dashboard/profile_update_screen.dart
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
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppAuthProvider>().user;
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
      
      if (user == null) throw Exception('Utilisateur non connecté');

      final updatedUser = user.copyWith(
        displayName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        companyName: _companyController.text.trim(),
        companyAddress: _addressController.text.trim(),
      );

      await _db.updateUser(updatedUser);
      await authProvider.refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profil mis à jour avec succès !'),
          backgroundColor: Colors.green,
        ));
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final user = context.select((AppAuthProvider p) => p.user);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        elevation: 0,
        backgroundColor: theme.backgroundColor,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: Text('Enregistrer', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProfileAvatar(name: user?.displayName ?? 'U'),
            const SizedBox(height: 32),
            _buildTextField(controller: _nameController, label: 'Nom complet', icon: Icons.person_outline),
            const SizedBox(height: 16),
            _buildTextField(controller: _phoneController, label: 'Téléphone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            _buildTextField(controller: _companyController, label: 'Entreprise', icon: Icons.business_outlined),
            const SizedBox(height: 16),
            _buildTextField(controller: _addressController, label: 'Adresse', icon: Icons.location_on_outlined, maxLines: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, TextInputType? keyboardType, int maxLines = 1}) {
    final theme = context.watch<ThemeProvider>();
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: theme.textColor),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: theme.primaryColor),
        filled: true,
        fillColor: theme.inputFillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String name;
  const _ProfileAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Center(
      child: CircleAvatar(
        radius: 40,
        backgroundColor: theme.primaryColor,
        child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}