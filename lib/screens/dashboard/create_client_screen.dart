// lib/screens/dashboard/create_client_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../services/database_service.dart';
import '../../services/quota_enforcement_service.dart';
import '../../models/client.dart';
import '../../models/plan.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/glass_widgets.dart';

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

  // 🔍 Recherche dans le dialogue d'import des contacts.
  final _contactSearchController = TextEditingController();
  String _contactQuery = '';

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
    _contactSearchController.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    // Blocage quota : uniquement pour un NOUVEAU client (pas en édition).
    if (widget.client == null) {
      final sub = context.read<SubscriptionProvider>();
      final plan = sub.currentPlan ?? Plan.getFreePlan();
      final result =
          await QuotaEnforcementService().canAddClient(plan);
      if (!result.isAllowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                result.message ?? 'Limite de clients atteinte. Passez au plan supérieur.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

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
          taxId: _taxIdController.text.trim(), userId: '',
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
    // Le plugin flutter_contacts ne supporte PAS le web (MethodChannel natif).
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Import des contacts disponible uniquement sur mobile/desktop'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Vérifier les permissions
    // 🔒 NB : on demande `PermissionType.read` (et non readWrite) car seul
    // `READ_CONTACTS` est déclaré dans le manifest Android — demander
    // readWrite échoue silencieusement et rend l'accès contacts impossible.
    final status =
        await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted &&
        status != PermissionStatus.limited) {
      // Si refusé définitivement, on propose d'ouvrir les réglages système.
      final permanentlyDenied = status == PermissionStatus.permanentlyDenied ||
          status == PermissionStatus.restricted;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Permission d\'accès aux contacts refusée. Autorisez-la dans les paramètres du téléphone.'),
          backgroundColor: Colors.orange,
          action: permanentlyDenied
              ? SnackBarAction(
                  label: 'Réglages',
                  onPressed: () => FlutterContacts.permissions.openSettings(),
                )
              : null,
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

      setState(() => _isLoadingContacts = false);
      _showContactsDialog(contacts);
    } on MissingPluginException {
      setState(() => _isLoadingContacts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Import des contacts non disponible sur cette plateforme. Saisissez le client manuellement.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      setState(() => _isLoadingContacts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des contacts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showContactsDialog(List<Contact> contacts) {
    final theme = context.read<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final primaryColor = theme.primaryColor;

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
          height: 440,
          child: StatefulBuilder(
            builder: (context, setState) {
              // 🔍 Filtre sur le nom, le téléphone et l'email.
              final filtered = _contactQuery.isEmpty
                  ? contacts
                  : contacts.where((c) {
                      final q = _contactQuery.toLowerCase();
                      final name = (c.displayName ?? '').toLowerCase();
                      final phone = c.phones.isNotEmpty
                          ? c.phones.first.number.toLowerCase()
                          : '';
                      final email = c.emails.isNotEmpty
                          ? c.emails.first.address.toLowerCase()
                          : '';
                      return name.contains(q) ||
                          phone.contains(q) ||
                          email.contains(q);
                    }).toList();

              return Column(
                children: [
                  // ===== Barre de recherche =====
                  TextField(
                    controller: _contactSearchController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un contact…',
                      hintStyle: TextStyle(color: subTextColor),
                      prefixIcon: Icon(Icons.search, color: primaryColor),
                      suffixIcon: _contactQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _contactSearchController.clear();
                                setState(() => _contactQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor:
                          isDark ? Colors.grey[800] : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    onChanged: (v) =>
                        setState(() => _contactQuery = v),
                  ),
                  const SizedBox(height: 10),
                  // ===== Liste filtrée =====
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              _contactQuery.isEmpty
                                  ? 'Aucun contact disponible'
                                  : 'Aucun contact ne correspond à la recherche',
                              style: TextStyle(color: subTextColor),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final contact = filtered[index];
                              final displayName =
                                  contact.displayName ?? 'Sans nom';
                              final phones = contact.phones;
                              final emails = contact.emails;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      primaryColor.withOpacity(0.1),
                                  child: Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  displayName,
                                  style: TextStyle(color: textColor),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    if (phones.isNotEmpty)
                                      Text(
                                        phones.first.number,
                                        style: TextStyle(
                                            color: subTextColor,
                                            fontSize: 12),
                                      ),
                                    if (emails.isNotEmpty)
                                      Text(
                                        emails.first.address,
                                        style: TextStyle(
                                            color: subTextColor,
                                            fontSize: 12),
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
                ],
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
    final textColor = themeProvider.textColor;
    final primaryColor = themeProvider.primaryColor;
    final isEditing = widget.client != null;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Modifier le client' : 'Nouveau client',
          style: TextStyle(
              color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!isEditing)
            IconButton(
              icon: Icon(Icons.contact_phone_outlined, color: primaryColor),
              onPressed: _isLoadingContacts ? null : _importFromContacts,
              tooltip: 'Importer depuis le répertoire',
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
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Raccourci d'import depuis le répertoire (carte soft)
                if (!isEditing)
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 14),
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      children: [
                        Icon(Icons.contact_phone,
                            color: primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Appuyez sur l\'icône en haut à droite pour importer depuis votre répertoire',
                            style: TextStyle(
                              fontSize: 12,
                              color: themeProvider.subTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _nameController,
                  label: 'Nom complet *',
                  prefixIcon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez saisir le nom';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                GlassTextField(
                  controller: _addressController,
                  label: 'Adresse *',
                  prefixIcon: Icons.location_on_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez saisir l\'adresse';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                GlassTextField(
                  controller: _phoneController,
                  label: 'Téléphone *',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez saisir le téléphone';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                GlassTextField(
                  controller: _emailController,
                  label: 'Email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                GlassTextField(
                  controller: _taxIdController,
                  label: 'NUI / RCCM',
                  prefixIcon: Icons.numbers_outlined,
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: isEditing ? 'Sauvegarder' : 'Ajouter le client',
                  icon: Icons.check_circle_outline_rounded,
                  height: 52,
                  loading: _isSaving,
                  onPressed: _saveClient,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
