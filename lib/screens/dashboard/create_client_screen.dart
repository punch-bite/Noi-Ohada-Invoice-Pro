// lib/screens/dashboard/create_client_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../services/database_service.dart';
import '../../models/client.dart';
import '../../providers/theme_provider.dart';

class CreateClientScreen extends StatefulWidget {
  final Client? client;
  const CreateClientScreen({super.key, this.client});

  @override
  State<CreateClientScreen> createState() => _CreateClientScreenState();
}

class _CreateClientScreenState extends State<CreateClientScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isSaving = false;
  bool _isLoadingContacts = false;

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _nameController.text = widget.client!.name;
      _addressController.text = widget.client!.address;
      _taxIdController.text = widget.client!.taxId;
      _phoneController.text = widget.client!.phone;
      _emailController.text = widget.client!.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (widget.client != null) {
        final updated = widget.client!.copyWith(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          taxId: _taxIdController.text.trim(),
        );
        await _db.updateClient(updated);
      } else {
        final client = Client(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          taxId: _taxIdController.text.trim(),
        );
        await _db.addClient(client);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              widget.client != null ? 'Client modifié !' : 'Client ajouté !'),
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

  // ===== IMPORTER DEPUIS LE RÉPERTOIRE (flutter_contacts) =====

  Future<void> _importFromContacts() async {
    // Vérifier les permissions
    final status =
        await FlutterContacts.permissions.request(PermissionType.readWrite);
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission d\'accès aux contacts refusée'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoadingContacts = true);

    try {
      final List<Contact> contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.photoThumbnail, ContactProperty.phone, ContactProperty.email},
        // filter: ContactFilter.name('John'),
        // limit: 100,
      );

      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun contact trouvé'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isLoadingContacts = false);
        return;
      }

      _showContactsDialog(contacts);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des contacts: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoadingContacts = false);
    }
  }

  void _showContactsDialog(List<Contact> contacts) {
    final theme = context.read<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Sélectionner un contact',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: contacts.isEmpty
              ? Center(
                  child: Text(
                    'Aucun contact disponible',
                    style: TextStyle(color: subTextColor),
                  ),
                )
              : ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final displayName = contact.displayName ?? 'Sans nom';
                    final phones = contact.phones;
                    final emails = contact.emails;
                    final addresses = contact.addresses;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.primaryColor.withOpacity(0.1),
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        displayName,
                        style: TextStyle(color: textColor),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (phones.isNotEmpty)
                            Text(
                              phones.first.number ?? '',
                              style:
                                  TextStyle(color: subTextColor, fontSize: 12),
                            ),
                          if (emails.isNotEmpty)
                            Text(
                              emails.first.address ?? '',
                              style:
                                  TextStyle(color: subTextColor, fontSize: 12),
                            ),
                        ],
                      ),
                      onTap: () {
                        _fillClientFromContact(contact);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: subTextColor),
            ),
          ),
        ],
      ),
    );

    setState(() => _isLoadingContacts = false);
  }

  void _fillClientFromContact(Contact contact) {
    final displayName = contact.displayName ?? '';
    final phones = contact.phones;
    final emails = contact.emails;
    final addresses = contact.addresses;

    setState(() {
      if (displayName.isNotEmpty) {
        _nameController.text = displayName;
      }
      if (phones.isNotEmpty) {
        _phoneController.text = phones.first.number;
      }
      if (emails.isNotEmpty) {
        _emailController.text = emails.first.address;
      }
      if (addresses.isNotEmpty && addresses.first.formatted != null) {
        _addressController.text = addresses.first.formatted ?? '';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Données importées depuis le contact'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final bgColor = themeProvider.backgroundColor;
    final primaryColor = themeProvider.primaryColor;
    final isEditing = widget.client != null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Modifier le client' : 'Nouveau client',
          style: TextStyle(
              color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!isEditing)
            IconButton(
              icon: Icon(
                Icons.contact_phone_outlined,
                color: primaryColor,
              ),
              onPressed: _isLoadingContacts ? null : _importFromContacts,
              tooltip: 'Importer depuis les contacts',
            ),
          if (_isLoadingContacts)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveClient,
              child: Text(
                'Enregistrer',
                style:
                    TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Icône d'import (raccourci visuel)
                if (!isEditing)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.contact_phone,
                          color: primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Appuyez sur l\'icône 📇 en haut à droite pour importer depuis vos contacts',
                            style: TextStyle(
                              fontSize: 12,
                              color: subTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildField(
                  controller: _nameController,
                  label: 'Nom complet *',
                  icon: Icons.person_outline,
                  isDark: isDark,
                  textColor: textColor,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez saisir le nom';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _addressController,
                  label: 'Adresse *',
                  icon: Icons.location_on_outlined,
                  isDark: isDark,
                  textColor: textColor,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez saisir l\'adresse';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _phoneController,
                  label: 'Téléphone *',
                  icon: Icons.phone_outlined,
                  isDark: isDark,
                  textColor: textColor,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez saisir le téléphone';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  isDark: isDark,
                  textColor: textColor,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _taxIdController,
                  label: 'NUI / RCCM',
                  icon: Icons.numbers_outlined,
                  isDark: isDark,
                  textColor: textColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color textColor,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
        prefixIcon: Icon(icon,
            color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
