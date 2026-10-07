// lib/screens/dashboard/create_client_screen.dart
//
// CHANGELOG v2 :
//   • 🆕 Import de contacts WEB (Chrome Android) via l'API Contact Picker.
//   • 🆕 Branchement automatique mobile (flutter_contacts) vs web
//     (contact_import_web).
//   • 🆕 Support complet du sélecteur natif PWA.
//   • 🎨 Reste inchangé : même UI, même design, mêmes animations.
//
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/client.dart';
import '../../models/plan.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/database_service.dart';
import '../../services/quota_enforcement_service.dart';
import '../../services/contact_import_types.dart';
// 🎯 Import conditionnel : en fonction de la plateforme, on tire
//    soit le stub (mobile) soit la vraie implémentation (web).
import '../../services/contact_import_web_stub.dart'
    if (dart.library.js_interop) '../../services/contact_import_web.dart';
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
  bool _isCompany = true;
  String _paymentTerms = '15 jours';

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

    if (widget.client == null) {
      final sub = context.read<SubscriptionProvider>();
      final plan = sub.currentPlan ?? Plan.getFreePlan();
      final result = await QuotaEnforcementService().canAddClient(plan);
      if (!result.isAllowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ??
                'Limite de clients atteinte. Passez au plan supérieur.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          taxId: _taxIdController.text.trim(),
          userId: '',
        );
        await _db.addClient(client);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              widget.client != null ? 'Client modifié ✓' : 'Client ajouté ✓'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  📇 IMPORT DE CONTACTS (branché mobile/web)
  // ═══════════════════════════════════════════════════════════════
  Future<void> _importFromContacts() async {
    if (kIsWeb) {
      await _importFromContactsWeb();
    } else {
      await _importFromContactsMobile();
    }
  }

  Future<void> _importFromContactsWeb() async {
    setState(() => _isLoadingContacts = true);

    try {
      final contacts = await pickContactsFromWeb(multiple: true);

      if (!mounted) return;
      setState(() => _isLoadingContacts = false);

      // 🛡️ Garde : si la liste est vide, on informe sans crash.
      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun contact sélectionné'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // 🛡️ Garde : ne cherche un contact utilisable QUE si la liste n'est pas vide.
      final usable = contacts.where((c) => c.isUsable).toList();
      final first = usable.isNotEmpty ? usable.first : contacts.first;

      setState(() {
        if (first.name.isNotEmpty) _nameController.text = first.name;
        if (first.phone != null && first.phone!.isNotEmpty) {
          _phoneController.text = first.phone!;
        }
        if (first.email != null && first.email!.isNotEmpty) {
          _emailController.text = first.email!;
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            contacts.length == 1
                ? 'Contact importé ✓'
                : '${contacts.length} contacts — le premier a été utilisé',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingContacts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 📱 Import MOBILE — flutter_contacts (sélecteur natif + sheet).
  Future<void> _importFromContactsMobile() async {
    final status =
        await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted &&
        status != PermissionStatus.limited) {
      final permanentlyDenied = status == PermissionStatus.permanentlyDenied ||
          status == PermissionStatus.restricted;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Permission d\'accès aux contacts refusée. Autorisez-la dans les paramètres.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
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
      final contacts = await FlutterContacts.getAll(
        properties: {
          ContactProperty.name,
          ContactProperty.phone,
          ContactProperty.email,
        },
      );

      if (!mounted) return;
      setState(() => _isLoadingContacts = false);

      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun contact trouvé'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      _showContactsSheet(contacts);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _isLoadingContacts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import non disponible sur cette plateforme.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingContacts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showContactsSheet(List<Contact> contacts) {
    final theme = context.read<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final primaryColor = theme.primaryColor;
    final searchCtrl = TextEditingController();
    String query = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = query.isEmpty
              ? contacts
              : contacts.where((c) {
                  final q = query.toLowerCase();
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

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D26) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: subTextColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        'Choisir un contact',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: subTextColor, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: searchCtrl,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Rechercher…',
                        hintStyle: TextStyle(
                            color: subTextColor.withValues(alpha: 0.7),
                            fontSize: 13.5),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: subTextColor, size: 20),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: (v) => setSheetState(() => query = v),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'Aucun contact ne correspond',
                            style: TextStyle(color: subTextColor),
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            final name = c.displayName ?? 'Sans nom';
                            final phone = c.phones.isNotEmpty
                                ? c.phones.first.number
                                : '';
                            final email = c.emails.isNotEmpty
                                ? c.emails.first.address
                                : '';

                            return InkWell(
                              onTap: () {
                                _fillFromContact(c);
                                Navigator.pop(ctx);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(
                                            alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: textColor,
                                            ),
                                          ),
                                          if (phone.isNotEmpty)
                                            Text(
                                              phone,
                                              style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: subTextColor),
                                            ),
                                          if (email.isNotEmpty)
                                            Text(
                                              email,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: subTextColor),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded,
                                        color: subTextColor.withValues(
                                            alpha: 0.5)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      searchCtrl.dispose();
    });
  }

  void _fillFromContact(Contact contact) {
    final displayName = contact.displayName ?? '';
    final phones = contact.phones;
    final emails = contact.emails;
    final addresses = contact.addresses;

    setState(() {
      if (displayName.isNotEmpty) _nameController.text = displayName;
      if (phones.isNotEmpty) _phoneController.text = phones.first.number;
      if (emails.isNotEmpty) _emailController.text = emails.first.address;
      if (addresses.isNotEmpty && addresses.first.formatted != null) {
        _addressController.text = addresses.first.formatted ?? '';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Données importées depuis le contact'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final primaryColor = theme.primaryColor;
    final isEditing = widget.client != null;

    // 🎯 Affiche le bouton d'import si :
    //    • mobile natif (toujours possible)
    //    • web + Chrome Android (API disponible)
    final showImportButton =
        !isEditing && (!kIsWeb || webContactPickerSupported());

    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textColor, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditing ? 'Modifier le client' : 'Nouveau client',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (showImportButton)
            IconButton(
              icon: _isLoadingContacts
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: primaryColor),
                    )
                  : Icon(Icons.contact_phone_outlined,
                      color: primaryColor, size: 22),
              onPressed: _isLoadingContacts ? null : _importFromContacts,
              tooltip: 'Importer depuis le répertoire',
            ),
          TextButton(
            onPressed: _isSaving ? null : _saveClient,
            style: TextButton.styleFrom(
              foregroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: primaryColor),
                  )
                : const Text(
                    'Enregistrer',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isEditing) ...[
                _typeSegment(theme, primaryColor),
                const SizedBox(height: 24),
              ],
              _sectionLabel('IDENTITÉ', subTextColor),
              const SizedBox(height: 10),
              _field(
                controller: _nameController,
                label: _isCompany ? 'Raison sociale' : 'Nom complet',
                icon: _isCompany
                    ? Icons.business_outlined
                    : Icons.person_outline_rounded,
                theme: theme,
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Veuillez saisir un nom' : null,
              ).animate().fadeIn(duration: 300.ms),
              if (_isCompany) ...[
                const SizedBox(height: 12),
                _field(
                  controller: _taxIdController,
                  label: 'NIF / IFU',
                  icon: Icons.numbers_outlined,
                  theme: theme,
                  textCapitalization: TextCapitalization.characters,
                ).animate().fadeIn(delay: 50.ms, duration: 300.ms),
              ],
              const SizedBox(height: 24),
              _sectionLabel('CONTACT', subTextColor),
              const SizedBox(height: 10),
              _field(
                controller: _emailController,
                label: 'Email',
                icon: Icons.mail_outline_rounded,
                theme: theme,
                keyboard: TextInputType.emailAddress,
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
              const SizedBox(height: 12),
              _field(
                controller: _phoneController,
                label: 'Téléphone',
                icon: Icons.phone_outlined,
                theme: theme,
                keyboard: TextInputType.phone,
                validator: (v) => v?.trim().isEmpty == true
                    ? 'Veuillez saisir un téléphone'
                    : null,
              ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
              const SizedBox(height: 24),
              _sectionLabel('LOCALISATION', subTextColor),
              const SizedBox(height: 10),
              _field(
                controller: _addressController,
                label: 'Adresse de facturation',
                icon: Icons.location_on_outlined,
                theme: theme,
                maxLines: 2,
                textCapitalization: TextCapitalization.words,
              ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
              const SizedBox(height: 24),
              _sectionLabel('PRÉFÉRENCES', subTextColor),
              const SizedBox(height: 10),
              _paymentTermsTile(theme, primaryColor)
                  .animate()
                  .fadeIn(delay: 250.ms, duration: 300.ms),
              const SizedBox(height: 32),
              GradientButton(
                label: isEditing
                    ? 'Enregistrer les modifications'
                    : 'Ajouter le client',
                icon: Icons.check_circle_outline_rounded,
                height: 54,
                loading: _isSaving,
                onPressed: _saveClient,
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, Color sub) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: sub,
      ),
    );
  }

  Widget _typeSegment(ThemeProvider theme, Color primaryColor) {
    final isDark = theme.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _typeBtn(true, 'ENTREPRISE', primaryColor, theme),
          _typeBtn(false, 'PARTICULIER', primaryColor, theme),
        ],
      ),
    );
  }

  Widget _typeBtn(
    bool value,
    String label,
    Color primaryColor,
    ThemeProvider theme,
  ) {
    final selected = _isCompany == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isCompany = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.25),
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
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: selected ? Colors.white : theme.subTextColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeProvider theme,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final primaryColor = theme.primaryColor;

    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      style: TextStyle(color: textColor, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: subTextColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: subTextColor.withValues(alpha: 0.5),
          fontSize: 13.5,
        ),
        prefixIcon:
            Icon(icon, size: 20, color: primaryColor.withValues(alpha: 0.7)),
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
            color: primaryColor.withValues(alpha: 0.7),
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

  Widget _paymentTermsTile(ThemeProvider theme, Color primaryColor) {
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;

    return GestureDetector(
      onTap: () => _showPaymentTermsDialog(theme, primaryColor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule_outlined,
                color: primaryColor.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Conditions de paiement',
                style: TextStyle(
                  fontSize: 13.5,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              _paymentTerms,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, color: subTextColor, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentTermsDialog(
      ThemeProvider theme, Color primaryColor) async {
    const options = [
      'À réception',
      '15 jours',
      '30 jours',
      '45 jours',
      '60 jours',
    ];
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D26) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: subTextColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Conditions de paiement',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor),
              ),
              const SizedBox(height: 12),
              ...options.map((opt) {
                final active = _paymentTerms == opt;
                return ListTile(
                  leading: Icon(
                    active
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: active
                        ? primaryColor
                        : subTextColor.withValues(alpha: 0.5),
                  ),
                  title: Text(
                    opt,
                    style: TextStyle(
                      color: active ? primaryColor : textColor,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, opt),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() => _paymentTerms = selected);
    }
  }
}
