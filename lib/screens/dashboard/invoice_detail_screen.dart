// lib/screens/dashboard/invoice_detail_screen.dart
// ignore_for_file: dead_null_aware_expression, deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/mail_service.dart';
import '../../services/printing_service.dart';
import '../../services/template_service.dart';
import '../../services/template_selection_service.dart';
import '../../services/template_custom_service.dart';
import '../../models/invoice.dart';
import '../../models/client.dart';
import '../../models/company.dart';
import '../../models/invoice_template.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/team_service.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/logo_image.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final DatabaseService _db = DatabaseService();
  final GlobalKey _menuKey =
      GlobalKey(); // Permet d'ouvrir le menu par programmation

  Invoice? _invoice;
  Client? _client;
  Company? _company;
  bool _isLoading = true;
  InvoiceTemplate? _selectedTemplate;
  List<InvoiceTemplate> _templates = [];

   ThemeProvider get themeProvider => context.watch<ThemeProvider>();
    bool get isDark => themeProvider.isDarkMode;
    late final textColor = themeProvider.textColor ?? Colors.black;
    Color get primaryColor => themeProvider.primaryColor ?? Colors.blue;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadTemplates();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _invoice = await _db.getInvoice(widget.invoiceId);
    if (_invoice != null) {
      _client = await _db.getClient(_invoice!.clientId);
      _company = await _db.getCompany();
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTemplates() async {
    // Fusion : templates par défaut + ceux créés par l'admin (boutique).
    final defaults = InvoiceTemplate.getDefaultTemplates();
    List<InvoiceTemplate> adminTemplates = [];
    try {
      adminTemplates = await TemplateService().getAllTemplates();
    } catch (_) {}
    final adminIds = adminTemplates.map((e) => e.id).toSet();
    _templates = [
      ...defaults.where((d) => !adminIds.contains(d.id)),
      ...adminTemplates,
    ];

    // ✅ Modèle actif choisi dans la boutique (sélection persistante).
    final activeId = await TemplateSelectionService.getActiveTemplateId();
    if (activeId != null && _templates.any((t) => t.id == activeId)) {
      _selectedTemplate = _templates.firstWhere((t) => t.id == activeId);
    } else {
      _selectedTemplate = _templates.firstWhere(
        (t) => t.isDefault,
        orElse: () => _templates.first,
      );
    }

    // Applique les personnalisations locales (positions/mapping) si présentes.
    if (_selectedTemplate != null) {
      final custom = await TemplateCustomService.loadCustom(_selectedTemplate!.id);
      if (custom.positions.isNotEmpty || custom.mapping.isNotEmpty) {
        _selectedTemplate = _selectedTemplate!.copyWith(
          positions: custom.positions,
          mapping: {..._selectedTemplate!.mapping, ...custom.mapping},
        );
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ===== LOGO WIDGET =====
  Widget _buildCompanyLogo() {
    if (_company == null) return const SizedBox.shrink();
    return LogoImage(
      path: _company!.logoPath,
      width: 80,
      height: 80,
    );
  }

  // ===== EN-TÊTE AVEC LOGO =====
  Widget _buildCompanyHeader() {
    if (_company == null) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompanyLogo(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _company!.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_company!.address.isNotEmpty)
                Text(
                  _company!.address,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              if (_company!.phone.isNotEmpty)
                Text(
                  'Tél: ${_company!.phone}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              if (_company!.email.isNotEmpty)
                Text(
                  'Email: ${_company!.email}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              if (_company!.rccm.isNotEmpty)
                Text(
                  'RCCM: ${_company!.rccm}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ===== IMPRESSION & PARTAGE =====
  Future<void> _previewAndPrint() async {
    if (_invoice == null || _client == null || _company == null) return;
    if (_selectedTemplate == null) return;

    try {
      await PrintingService.printInvoice(
        invoice: _invoice!,
        client: _client!,
        company: _company!,
        template: _selectedTemplate!,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur d\'impression: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareInvoice() async {
    if (_invoice == null || _client == null || _company == null) return;
    if (_selectedTemplate == null) return;

    try {
      final pdfData = await PrintingService.generateInvoicePdf(
        invoice: _invoice!,
        client: _client!,
        company: _company!,
        template: _selectedTemplate!,
      );

      final tempDir = await getTemporaryDirectory();
      final file =
          File('${tempDir.path}/facture_${_invoice!.invoiceNumber}.pdf');
      await file.writeAsBytes(pdfData);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Facture ${_invoice!.invoiceNumber} - OHADA Invoice Pro',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de partage: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendInvoiceByEmail() async {
    if (_invoice == null || _client == null || _company == null) return;
    if (_selectedTemplate == null) return;

    try {
      final pdfData = await PrintingService.generateInvoicePdf(
        invoice: _invoice!,
        client: _client!,
        company: _company!,
        template: _selectedTemplate!,
      );

      // TODO: Uploader le PDF quelque part (Firebase Storage, etc.) pour obtenir un lien
      const pdfLink = '#';

      final htmlBody = MailService.getInvoiceTemplate(
        _client!.name,
        _invoice!.invoiceNumber,
        pdfLink,
      );

      final sent = await MailService.sendHtmlEmail(
        to: _client!.email,
        subject: 'Facture ${_invoice!.invoiceNumber}',
        htmlBody: htmlBody,
      );

      if (!mounted) return;
      if (sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Facture envoyée par email avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'envoi de l\'email'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showShareDialog() async {
    if (_invoice == null) return;

    final teamService = TeamService();
    final auth = context.read<AppAuthProvider>();
    final teams = await teamService.getUserTeams(auth.user!.id);

    if (teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous n\'appartenez à aucune équipe'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String? selectedTeamId;
        String permissionLevel = 'read';
        final Set<String> selectedMembers = {};
        Map<String, Map<String, String>> profiles = {};
        List<String> memberIds = [];
        bool loadingMembers = false;

        Future<void> loadMembers(String teamId) async {
          setState(() => loadingMembers = true);
          final team = await teamService.getTeam(teamId);
          final profs = await teamService.getMemberProfiles(teamId);
          final ids = <String>{
            if (team != null) team.ownerId,
            ...?team?.adminIds,
            ...?team?.memberIds,
          }..remove(auth.user!.id);
          selectedMembers.clear();
          if (!mounted) return;
          setState(() {
            memberIds = ids.toList();
            profiles = profs;
            loadingMembers = false;
          });
        }

        String memberLabel(String uid) {
          final name = profiles[uid]?['name'] ?? '';
          if (name.isNotEmpty) return name;
          final email = profiles[uid]?['email'] ?? '';
          if (email.isNotEmpty) return email;
          return 'Membre #${uid.substring(0, 6)}';
        }

        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(24),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Partager la facture',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Sélection de l'équipe
                  DropdownButtonFormField<String>(
                    value: selectedTeamId,
                    hint: const Text('Sélectionner une équipe'),
                    items: teams.map((team) {
                      return DropdownMenuItem(
                        value: team.id,
                        child: Text(team.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedTeamId = value);
                      if (value != null) loadMembers(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Permission
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Lecture seule'),
                          value: 'read',
                          groupValue: permissionLevel,
                          onChanged: (v) =>
                              setState(() => permissionLevel = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Écriture'),
                          value: 'write',
                          groupValue: permissionLevel,
                          onChanged: (v) =>
                              setState(() => permissionLevel = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Membres (@mention)
                  Text(
                    'Mentionner (@) les membres',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (loadingMembers)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (memberIds.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Aucun autre membre dans cette équipe.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 210),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          CheckboxListTile(
                            dense: true,
                            title: const Text('Tous les membres'),
                            value:
                                selectedMembers.length == memberIds.length,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                selectedMembers.addAll(memberIds);
                              } else {
                                selectedMembers.clear();
                              }
                            }),
                            activeColor:
                                Theme.of(context).colorScheme.primary,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          for (final uid in memberIds)
                            CheckboxListTile(
                              dense: true,
                              value: selectedMembers.contains(uid),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  selectedMembers.add(uid);
                                } else {
                                  selectedMembers.remove(uid);
                                }
                              }),
                              title: Text(
                                '@${memberLabel(uid)}',
                                style: TextStyle(
                                  color: selectedMembers.contains(uid)
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                  fontWeight: selectedMembers.contains(uid)
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              activeColor:
                                  Theme.of(context).colorScheme.primary,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Bouton Partager
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                          selectedTeamId == null || selectedMembers.isEmpty
                              ? null
                              : () async {
                                  await teamService.shareResource(
                                    resourceId: _invoice!.id,
                                    resourceType: 'invoice',
                                    resourceName: _invoice!.invoiceNumber,
                                    teamId: selectedTeamId!,
                                    sharedBy: auth.user!.id,
                                    sharedWith: selectedMembers.toList(),
                                    permissionLevel: permissionLevel,
                                  );
                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Facture partagée avec ${selectedMembers.length} membre(s) ✅'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        selectedMembers.isEmpty
                            ? 'Partager'
                            : 'Partager avec ${selectedMembers.length} membre(s)',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('⭐ Template Premium'),
        content: const Text(
          'Ce template est réservé aux abonnés Pro et Business.\n\n'
          'Passez à un plan supérieur pour débloquer :\n'
          '• Tous les templates premium\n'
          '• Factures illimitées\n'
          '• Synchronisation cloud\n'
          '• Support prioritaire',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Voir les offres'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final bgColor = themeProvider.backgroundColor;
    final canAccessPremium = subscriptionProvider.canAccessPremiumTemplates;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_invoice == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: isDark ? Colors.grey[400] : Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Facture non trouvée',
                style: TextStyle(color: textColor),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

        return GlassScaffold(
      appBar: AppBar(
        title: Text(
          _invoice!.invoiceNumber,
          style: TextStyle(color: textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Sélection du modèle
          PopupMenuButton<InvoiceTemplate>(
            key: _menuKey,
            icon: Icon(Icons.style, color: textColor),
            onSelected: (template) {
              if (template.isPremium && !canAccessPremium) {
                _showUpgradeDialog(context);
                return;
              }
              setState(() => _selectedTemplate = template);
            },
            itemBuilder: (context) {
              return _templates.map((template) {
                final isLocked = template.isPremium && !canAccessPremium;
                final isSelected = _selectedTemplate?.id == template.id;

                return PopupMenuItem<InvoiceTemplate>(
                  value:
                      template, // On transmet l'objet pour gérer le dialog de verrouillage
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: template.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          template.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isLocked ? Colors.grey : textColor,
                          ),
                        ),
                      ),
                      if (isLocked)
                        const Icon(Icons.lock, size: 16, color: Colors.grey),
                      if (isSelected && !isLocked)
                        Icon(Icons.check, color: primaryColor, size: 16),
                      if (template.isPremium && !isLocked)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child:
                              Icon(Icons.star, color: Colors.amber, size: 14),
                        ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          IconButton(
            icon: Icon(Icons.share, color: textColor),
            onPressed: _shareInvoice,
            tooltip: 'Partager la facture',
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: textColor),
            onPressed: _previewAndPrint,
            tooltip: 'Aperçu PDF / Impression',
          ),
          IconButton(
            icon: Icon(Icons.email_outlined, color: textColor),
            onPressed: _sendInvoiceByEmail,
            tooltip: 'Envoyer par email',
          ),
          IconButton(
            icon: Icon(Icons.share_outlined, color: textColor),
            onPressed: _showShareDialog,
            tooltip: 'Partager avec l\'équipe',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Rendu de la prévisualisation cliquable pour changer de modèle
            GestureDetector(
              onTap: () {
                // Déclenche dynamiquement l'ouverture du menu PopupButton de l'AppBar
                final dynamic state = _menuKey.currentState;
                state?.showButtonMenu();
              },
              child: _buildTemplatePreview(
                isDark,
                textColor,
                subTextColor,
                primaryColor,
                canAccessPremium,
              ),
            ),
            const SizedBox(height: 16),
                        Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCompanyHeader(),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _invoice!.invoiceNumber,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_invoice!.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusLabel(_invoice!.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'Date',
                    DateFormat('dd/MM/yyyy').format(_invoice!.issueDate),
                    isDark,
                    textColor,
                    subTextColor,
                  ),
                  _buildInfoRow(
                    'Échéance',
                    DateFormat('dd/MM/yyyy').format(_invoice!.dueDate),
                    isDark,
                    textColor,
                    subTextColor,
                  ),
                  _buildInfoRow(
                    'Client',
                    _client?.name ?? 'Client inconnu',
                    isDark,
                    textColor,
                    subTextColor,
                  ),
                  const Divider(height: 24),
                  Text(
                    'Produits',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._invoice!.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.description,
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            Text(
                              '${item.quantity} x ',
                              style: TextStyle(color: textColor),
                            ),
                            Text(
                              '${item.unitPrice.toStringAsFixed(0)} FCFA',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      )),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${_invoice!.totalAmount.toStringAsFixed(0)} FCFA',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _previewAndPrint,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Aperçu PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _previewAndPrint,
                          icon: Icon(Icons.print, color: primaryColor),
                          label: Text(
                            'Imprimer',
                            style: TextStyle(color: primaryColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatePreview(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    bool canAccessPremium,
  ) {
    if (_selectedTemplate == null) return const SizedBox.shrink();

    final isLocked = _selectedTemplate!.isPremium && !canAccessPremium;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _selectedTemplate!.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedTemplate!.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _selectedTemplate!.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.receipt_long, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Modèle: ${_selectedTemplate!.name}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (_selectedTemplate!.isPremium) ...[
                      const SizedBox(width: 6),
                      Icon(
                        isLocked ? Icons.lock : Icons.star,
                        size: 14,
                        color: isLocked ? Colors.grey : Colors.amber,
                      ),
                    ],
                  ],
                ),
                Text(
                  _selectedTemplate!.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _selectedTemplate!.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isLocked ? '🔒 Premium' : 'Cliquez pour changer',
              style: TextStyle(
                fontSize: 10,
                color: isLocked ? Colors.grey : _selectedTemplate!.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: subTextColor)),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'sent':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Payée';
      case 'sent':
        return 'En attente';
      case 'overdue':
        return 'En retard';
      case 'cancelled':
        return 'Annulée';
      default:
        return 'Brouillon';
    }
  }
}
