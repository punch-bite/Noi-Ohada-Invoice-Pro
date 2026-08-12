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
  bool _isCompany = true; // true = ENTREPRISE, false = PARTICULIER
  String _paymentTerms = '15 jours';

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
                                      primaryColor.withValues(alpha: 0.1),
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
          isEditing ? 'Modifier le client' : 'Nouveau Client',
          style: TextStyle(
              color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sous-titre explicatif
                Text(
                  'Ajoutez un contact pour simplifier votre facturation '
                  'conforme OHADA.',
                  style: TextStyle(
                    fontSize: 13,
                    color: themeProvider.subTextColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // ===== Type : ENTREPRISE / PARTICULIER =====
                if (!isEditing) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: themeProvider.isDarkMode
                            ? Colors.grey[800]!
                            : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildTypeSegment(true, 'ENTREPRISE', primaryColor),
                        _buildTypeSegment(false, 'PARTICULIER', primaryColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ===== IDENTITÉ =====
                _buildSectionTitle('IDENTITÉ', themeProvider.subTextColor),
                const SizedBox(height: 10),
                GlassTextField(
                  controller: _nameController,
                  label: _isCompany ? 'Raison Sociale *' : 'Nom complet *',
                  prefixIcon: _isCompany
                      ? Icons.business_outlined
                      : Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez saisir le nom';
                    }
                    return null;
                  },
                ),
                if (_isCompany) ...[
                  const SizedBox(height: 14),
                  GlassTextField(
                    controller: _taxIdController,
                    label: 'NIF / IFU *',
                    prefixIcon: Icons.numbers_outlined,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Requis pour la facturation OHADA B2B',
                    style: TextStyle(
                      fontSize: 11,
                      color: themeProvider.subTextColor,
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // ===== CONTACT =====
                _buildSectionTitle('CONTACT', themeProvider.subTextColor),
                const SizedBox(height: 10),
                GlassTextField(
                  controller: _emailController,
                  label: 'Email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
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
                const SizedBox(height: 20),

                // ===== LOCALISATION =====
                _buildSectionTitle('LOCALISATION', themeProvider.subTextColor),
                const SizedBox(height: 10),
                GlassTextField(
                  controller: _addressController,
                  label: 'Adresse de Facturation',
                  prefixIcon: Icons.location_on_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),

                // ===== PRÉFÉRENCES =====
                _buildSectionTitle('PRÉFÉRENCES', themeProvider.subTextColor),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () =>
                      _showPaymentTermsDialog(themeProvider, primaryColor),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: themeProvider.isDarkMode
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.04),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_outlined,
                            color: primaryColor.withValues(alpha: 0.7),
                            size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Conditions de Paiement',
                            style: TextStyle(
                              fontSize: 12,
                              color: themeProvider.subTextColor,
                            ),
                          ),
                        ),
                        Text(
                          _paymentTerms,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_drop_down,
                            color: themeProvider.subTextColor, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ===== Bouton d'enregistrement =====
                GradientButton(
                  label: isEditing ? 'Sauvegarder' : 'Enregistrer le client',
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

  /// Segment ENTREPRISE / PARTICULIER.
  Widget _buildTypeSegment(bool value, String label, Color primaryColor) {
    final selected = _isCompany == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isCompany = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF8A4CFC)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF8A4CFC).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: selected
                  ? Colors.white
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[300]
                      : Colors.grey[600]),
            ),
          ),
        ),
      ),
    );
  }

  /// Titre de section (maquette : MAJUSCULES gris).
  Widget _buildSectionTitle(String title, Color subColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: subColor,
      ),
    );
  }

  /// Dialogue de choix des conditions de paiement.
  Future<void> _showPaymentTermsDialog(
      ThemeProvider theme, Color primaryColor) async {
    const options = ['À réception', '15 jours', '30 jours', '45 jours', '60 jours'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Conditions de paiement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...options.map((opt) => ListTile(
                  leading: Icon(
                    _paymentTerms == opt
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: _paymentTerms == opt ? primaryColor : Colors.grey,
                  ),
                  title: Text(opt),
                  onTap: () => Navigator.pop(context, opt),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() => _paymentTerms = selected);
    }
  }
}
