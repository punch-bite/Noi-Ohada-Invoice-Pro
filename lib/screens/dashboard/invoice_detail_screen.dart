// lib/screens/dashboard/invoice_detail_screen.dart
//
// 🎨 Refonte « Détail facture » (maquette Stitch — d_tail_facture) :
//   • En-tête : retour + numéro + date + personnalisation + partage
//   • Carrousel horizontal de MODÈLES (sélection persistante, premium/verrou)
//   • Prévisualisation fidèle (couleurs du modèle + arrière-plan personnalisé)
//   • Totaux style maquette + « Aperçu PDF » (dégradé) / « Imprimer » (outline)
// ignore_for_file: dead_null_aware_expression, deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
import '../../theme/royal_ledger.dart';
import '../../widgets/logo_image.dart';
import '../../models/invoice_layout.dart';
import '../../widgets/template_background_palette.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final DatabaseService _db = DatabaseService();

  Invoice? _invoice;
  Client? _client;
  Company? _company;
  bool _isLoading = true;
  InvoiceTemplate? _selectedTemplate;
  List<InvoiceTemplate> _templates = [];

  // 🖼️ Arrière-plan personnalisé (workspace / modèle admin) pour l'aperçu.
  Uint8List? _previewBackground;
  double _bgOpacity = 1.0;
  double _bgBlur = 0;
  String _bgFit = 'fill';

  // 🧩 Layout drag & drop du modèle actif (blocs / colonnes / ordre) —
  // partagé avec le workspace et l'impression PDF (WYSIWYG).
  InvoiceLayoutConfig _layoutConfig = InvoiceLayoutConfig.defaultLayout();

  // 🎨 Réglages de fond du modèle actif (préréglage palette / image /…).
  TemplateBackgroundSettings _backgroundSettings =
      const TemplateBackgroundSettings();

  ThemeProvider get themeProvider => context.watch<ThemeProvider>();
  bool get isDark => themeProvider.isDarkMode;
  Color get textColor => themeProvider.textColor ?? Colors.black;
  Color get subTextColor => themeProvider.subTextColor ?? Colors.grey;
  Color get primaryColor => themeProvider.primaryColor ?? Colors.indigo;

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

    // ✅ Modèle actif choisi (carrousel / boutique) — sélection persistante.
    final activeId = await TemplateSelectionService.getActiveTemplateId();
    InvoiceTemplate? selected;
    if (activeId != null && _templates.any((t) => t.id == activeId)) {
      selected = _templates.firstWhere((t) => t.id == activeId);
    } else if (_templates.isNotEmpty) {
      selected = _templates.firstWhere(
        (t) => t.isDefault,
        orElse: () => _templates.first,
      );
    }
    if (selected != null) {
      _selectedTemplate = await _applyCustomisation(selected);
    }
    if (mounted) setState(() {});
  }

  /// Applique les personnalisations locales (positions drag & drop / mapping /
  /// arrière-plan) d'un modèle et met à jour l'aperçu.
  Future<InvoiceTemplate> _applyCustomisation(InvoiceTemplate template) async {
    final custom = await TemplateCustomService.loadCustom(template.id);
    final applied = template.copyWith(
      positions: custom.positions,
      mapping: {...template.mapping, ...custom.mapping},
    );

    // 🧩 Layout drag & drop : `fromMap` réinjecte les éléments manquants
    // depuis le layout par défaut (compat ascendante).
    _layoutConfig = custom.positions.isNotEmpty
        ? InvoiceLayoutConfig.fromMap(custom.positions)
        : InvoiceLayoutConfig.defaultLayout();
    _backgroundSettings = custom.background;

    Uint8List? bytes;
    double opacity = 1.0;
    double blur = 0;
    String fit = 'fill';
    if (custom.background.hasCustomImage) {
      // Priorité : arrière-plan uploadé dans le workspace.
      try {
        bytes = base64Decode(custom.background.fileData);
        opacity = custom.background.opacity.clamp(0.0, 1.0);
        blur = custom.background.blur.clamp(0.0, 20.0);
        fit = custom.background.fit;
      } catch (_) {
        bytes = null;
      }
    } else if (!custom.background.hasPreset &&
        template.fileData.isNotEmpty &&
        template.fileType != 'pdf') {
      // Repli : image téléversée directement sur le modèle (admin).
      try {
        bytes = base64Decode(template.fileData);
      } catch (_) {
        bytes = null;
      }
    }

    if (mounted) {
      setState(() {
        _previewBackground = bytes;
        _bgOpacity = opacity;
        _bgBlur = blur;
        _bgFit = fit;
      });
    }
    return applied;
  }

  /// Sélection d'un modèle du carrousel (persistée localement).
  Future<void> _selectTemplate(
    InvoiceTemplate template,
    bool canAccessPremium,
  ) async {
    if (template.isPremium && !canAccessPremium) {
      _showUpgradeDialog(context);
      return;
    }
    if (_selectedTemplate?.id == template.id) return;
    setState(() => _selectedTemplate = null);
    await TemplateSelectionService.setActiveTemplateId(template.id);
    final applied = await _applyCustomisation(template);
    if (mounted) setState(() => _selectedTemplate = applied);
  }

  /// Ouvre le sélecteur plein écran des modèles puis recharge l'actif.
  Future<void> _openTemplatePicker() async {
    await context.push('/templates/select');
    if (mounted) await _loadTemplates();
  }

  /// Ouvre l'espace de personnalisation (drag & drop) du modèle actif.
  Future<void> _openWorkspace() async {
    final template = _selectedTemplate;
    if (template == null) {
      await _openTemplatePicker();
      return;
    }
    await context.push('/templates/workspace', extra: template);
    if (mounted) await _loadTemplates();
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
      // TODO: Uploader le PDF (Firebase Storage…) pour obtenir un lien public.
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sent
              ? 'Facture envoyée par email avec succès'
              : 'Erreur lors de l\'envoi de l\'email'),
          backgroundColor: sent ? Colors.green : Colors.red,
        ),
      );
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous n\'appartenez à aucune équipe'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
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
                            value: selectedMembers.length == memberIds.length,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                selectedMembers.addAll(memberIds);
                              } else {
                                selectedMembers.clear();
                              }
                            }),
                            activeColor: Theme.of(context).colorScheme.primary,
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
                              activeColor: Theme.of(context).colorScheme.primary,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
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

  // ============================================================
  //  🎨 UI — Refonte maquette Stitch
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final canAccessPremium = subscriptionProvider.canAccessPremiumTemplates;
    final c = RoyalScheme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: c.surface,
        body: Center(child: CircularProgressIndicator(color: c.primary)),
      );
    }

    if (_invoice == null) {
      return Scaffold(
        backgroundColor: c.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: c.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 32,
                  color: c.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Facture non trouvée',
                style: RoyalText.headlineMd(c.onSurface),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.onPrimary,
                ),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 14),
              _buildToolbar(),
              const SizedBox(height: 18),
              _buildModelsSection(canAccessPremium),
              const SizedBox(height: 18),
              _buildInvoicePreviewCard(),
              const SizedBox(height: 20),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  /// En-tête moderne : retour · n° + date + statut · personnaliser · partager · ⋯
  Widget _buildHeader() {
    final c = RoyalScheme.of(context);
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/invoices');
            }
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back, size: 20, color: c.onSurface),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _invoice!.invoiceNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RoyalText.headlineMd(c.onSurface).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusBadge(c),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Créée le ${DateFormat('dd MMM yyyy').format(_invoice!.issueDate)}'
                ' · Échéance ${DateFormat('dd MMM yyyy').format(_invoice!.dueDate)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RoyalText.labelSm(c.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _circleButton(
          Icons.palette_outlined,
          _openWorkspace,
          tooltip: 'Personnaliser le modèle',
        ),
        const SizedBox(width: 8),
        _circleButton(
          Icons.ios_share,
          _shareInvoice,
          tooltip: 'Partager la facture (PDF)',
        ),
        const SizedBox(width: 8),
        _buildOverflowMenu(c),
      ],
    );
  }

  /// Petit badge de statut coloré (Payée / En attente / En retard / etc.).
  Widget _statusBadge(RoyalScheme c) {
    final status = _invoice!.status;
    final color = _getStatusColor(status);
    final label = _getStatusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(RoyalRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'WorkSans',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Bouton circulaire moderne (style maquette Royal Ledger).
  Widget _circleButton(IconData icon, VoidCallback onTap,
      {String? tooltip}) {
    final c = RoyalScheme.of(context);
    final btn = Material(
      color: c.surfaceContainer,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: c.onSurface),
        ),
      ),
    );
    if (tooltip == null || tooltip.isEmpty) return btn;
    return Tooltip(message: tooltip, child: btn);
  }

  /// Menu « ⋯ » : email, partage équipe, boutique de modèles.
  Widget _buildOverflowMenu(RoyalScheme c) {
    return PopupMenuButton<String>(
      tooltip: 'Plus d\'actions',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        switch (value) {
          case 'email':
            _sendInvoiceByEmail();
            break;
          case 'team':
            _showShareDialog();
            break;
          case 'store':
            context.push('/templates');
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'email',
          child: Row(children: [
            Icon(Icons.mail_outline, size: 18),
            SizedBox(width: 10),
            Text('Envoyer par email'),
          ]),
        ),
        PopupMenuItem(
          value: 'team',
          child: Row(children: [
            Icon(Icons.group_outlined, size: 18),
            SizedBox(width: 10),
            Text('Partager à l\'équipe'),
          ]),
        ),
        PopupMenuItem(
          value: 'store',
          child: Row(children: [
            Icon(Icons.storefront_outlined, size: 18),
            SizedBox(width: 10),
            Text('Boutique de modèles'),
          ]),
        ),
      ],
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.more_horiz, size: 20, color: c.onSurface),
      ),
    );
  }

  /// Section « MODÈLES » : libellé + puce « Cliquez pour changer » +
  /// carrousel horizontal de vignettes (maquette d_tail_facture).
  /// Section « Modèles applicables » : carrousel horizontal de vignettes
  /// dessinées aux couleurs de chaque modèle (clic = appliquer).
  Widget _buildModelsSection(bool canAccessPremium) {
    final c = RoyalScheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 26,
              decoration: BoxDecoration(
                gradient: RoyalGradients.royal,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Modèles applicables',
                style: RoyalText.headlineMd(c.onSurface).copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            GestureDetector(
              onTap: _openTemplatePicker,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: c.secondaryContainer,
                  borderRadius: BorderRadius.circular(RoyalRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.dashboard_customize_outlined,
                      size: 14,
                      color: c.onSecondaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Changer',
                      style: RoyalText.labelBold(c.onSecondaryContainer)
                          .copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 152,
          child: _templates.isEmpty
              ? Center(
                  child: Text(
                    'Aucun modèle disponible',
                    style: RoyalText.labelSm(c.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  itemCount: _templates.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: RoyalSpacing.gutter),
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return _buildTemplateThumb(template, canAccessPremium);
                  },
                ),
        ),
      ],
    );
  }

  /// Vignette d'un modèle : mini page dessinée + badges (✓ ⭐ 🔒).
  Widget _buildTemplateThumb(
    InvoiceTemplate template,
    bool canAccessPremium,
  ) {
    final c = RoyalScheme.of(context);
    final isSelected = _selectedTemplate?.id == template.id;
    final isLocked = template.isPremium && !canAccessPremium;
    final bool darkTmpl = template.backgroundColor.computeLuminance() < 0.45;
    final Color fg = darkTmpl ? Colors.white : template.textColor;

    Widget thumb = Container(
      width: 90,
      height: 128,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: template.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? c.primary : c.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSelected ? 0.22 : 0.10),
            blurRadius: isSelected ? 16 : 8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 34,
            color: template.primaryColor,
            padding: const EdgeInsets.all(7),
            child: Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
              ),
              const Spacer(),
              Text(
                'FACTURE',
                style: TextStyle(
                  fontSize: 5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: fg,
                ),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _thumbLine(fg.withValues(alpha: 0.35), 1.0),
                  const SizedBox(height: 3),
                  _thumbLine(fg.withValues(alpha: 0.22), 0.65),
                  const SizedBox(height: 5),
                  Container(
                    height: 2,
                    width: double.infinity,
                    color: template.primaryColor.withValues(alpha: 0.15),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: template.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 4.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (isLocked) {
      thumb = Stack(children: [
        Positioned.fill(child: thumb),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.lock_rounded, size: 18, color: Colors.white),
            ),
          ),
        ),
      ]);
    }

    return GestureDetector(
      onTap: () => _selectTemplate(template, canAccessPremium),
      child: SizedBox(
        width: 90,
        child: Column(children: [
          Stack(clipBehavior: Clip.none, children: [
            thumb,
            if (template.isPremium && !isLocked)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: c.tertiary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c.surfaceContainerLowest,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    size: 11,
                    color: c.onTertiary,
                  ),
                ),
              ),
            if (isSelected)
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c.surfaceContainerLowest,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text(
            isLocked ? 'Premium 🔒' : template.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'WorkSans',
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? c.primary : c.onSurfaceVariant,
            ),
          ),
        ]),
      ),
    );
  }

  /// Petite ligne grise (squelette de texte) dans la vignette.
  Widget _thumbLine(Color color, double widthFactor) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(height: 3, color: color),
    );
  }

  /// Carte d'aperçu de la facture — fidèle à la maquette, teintée par les
  /// couleurs du modèle actif et l'arrière-plan personnalisé (workspace).
  /// Carte « papier » de la facture — raffinée : bandeau supérieur, filigrane
  /// « PAYÉ » pivoté si la facture est payée, corps piloté par le layout
  /// drag & drop du modèle actif + arrière-plan personnalisé.
  Widget _buildInvoicePreviewCard() {
    final c = RoyalScheme.of(context);
    final tmplBg =
        _selectedTemplate?.backgroundColor ?? c.surfaceContainerLowest;
    final cardBg = isDark ? c.surfaceContainerLow : tmplBg;
    final bool darkCard = cardBg.computeLuminance() < 0.45;
    final cText =
        isDark ? Colors.white : (darkCard ? Colors.white : textColor);
    final cSub = isDark
        ? (Colors.grey[300] ?? Colors.grey)
        : (darkCard ? Colors.white70 : subTextColor);
    final accent = _selectedTemplate?.primaryColor ?? c.primary;
    final isPaid = _invoice?.status == 'paid';
    final radius = BorderRadius.circular(20);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: radius,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // 🎨 Fond : image personnalisée ou préréglage de la palette.
            TemplateBackgroundLayer(
              presetId: _backgroundSettings.hasCustomImage
                  ? ''
                  : _backgroundSettings.presetId,
              imageBytes: _previewBackground,
              opacity: _bgOpacity,
              blur: _bgBlur,
              fit: _bgFit,
            ),
            if (_previewBackground != null || _backgroundSettings.hasPreset)
              Positioned.fill(
                child: ColoredBox(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.45),
                ),
              ),
            // Filigrane « PAYÉ » (pivoté) si la facture est payée.
            if (isPaid)
              Positioned.fill(
                child: Center(
                  child: Transform.rotate(
                    angle: -0.2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: c.tertiaryFixedDim.withValues(alpha: 0.75),
                          width: 3,
                        ),
                      ),
                      child: Text(
                        'PAYÉ',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 5,
                          color: c.tertiaryFixedDim.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Contenu du document.
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _paperTopBar(accent, cText),
                  const SizedBox(height: 12),
                  _buildLayoutDrivenBody(cText, cSub, accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bandeau supérieur du papier : badge FACTURE/DEVIS + numéro.
  Widget _paperTopBar(Color accent, Color cText) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _invoice!.isDevis ? 'DEVIS' : 'FACTURE',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: accent,
            ),
          ),
        ),
        const Spacer(),
        Text(
          _invoice!.invoiceNumber,
          style: TextStyle(
            fontFamily: 'WorkSans',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: cText,
          ),
        ),
      ],
    );
  }

  Widget _cardDivider(Color cSub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(
          height: 1, thickness: 1, color: cSub.withValues(alpha: 0.18)),
    );
  }

  // ============================================================
  //  🧰 BARRE D'OUTILS SCROLLABLE — outils de personnalisation
  // ============================================================

  /// Barre d'outils horizontale : modèles, personnalisation drag & drop,
  /// image de fond, mention légale & conditions de la société.
  Widget _buildToolbar() {
    final c = RoyalScheme.of(context);
    return SizedBox(
      height: 42,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        child: Row(
          children: [
            _toolbarChip(c, Icons.dashboard_customize_outlined, 'Modèles',
                _openTemplatePicker),
            _toolbarChip(
                c, Icons.widgets_outlined, 'Personnaliser', _openWorkspace),
            _toolbarChip(c, Icons.wallpaper_outlined, 'Image de fond',
                _openBackgroundSheet),
            _toolbarChip(c, Icons.gavel_outlined, 'Mention légale',
                () => _showLegalEditor()),
          ],
        ),
      ),
    );
  }

  /// Puce de la barre d'outils (pill moderne sur fond surfaceContainer).
  Widget _toolbarChip(
    RoyalScheme c,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: BorderRadius.circular(RoyalRadius.full),
            border: Border.all(
              color: c.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: c.secondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: RoyalText.labelBold(c.onSurface).copyWith(
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  //  🧩 RENDU PILOTÉ PAR LE LAYOUT DRAG & DROP
  //  L'aperçu de la facture respecte blocs → rangées (ordre) → colonnes
  //  du modèle actif — même moteur que le workspace et l'impression PDF.
  // ============================================================

  /// Corps de l'aperçu : parcourt les éléments visibles du layout actif,
  /// groupés par bloc puis rangée (ordre) puis colonne.
  Widget _buildLayoutDrivenBody(Color cText, Color cSub, Color accent) {
    final visible = _layoutConfig.positions.entries
        .where((e) => _layoutConfig.styleOf(e.key).visible)
        .toList()
      ..sort((a, b) {
        final byBlock = a.value.blockIndex.compareTo(b.value.blockIndex);
        if (byBlock != 0) return byBlock;
        final byOrder = a.value.order.compareTo(b.value.order);
        if (byOrder != 0) return byOrder;
        return a.value.column.compareTo(b.value.column);
      });
    if (visible.isEmpty) {
      return Text(
        'Aucun élément visible — ouvrez « Personnaliser ».',
        style: TextStyle(fontSize: 12, color: cSub),
      );
    }

    final blocks = <int, List<MapEntry<LayoutElement, ElementPosition>>>{};
    for (final entry in visible) {
      blocks.putIfAbsent(entry.value.blockIndex, () => []).add(entry);
    }
    final sortedBlocks = blocks.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sortedBlocks.length; i++) ...[
          _buildLayoutBlock(blocks[sortedBlocks[i]]!, cText, cSub, accent),
          if (i < sortedBlocks.length - 1) _cardDivider(cSub),
        ],
      ],
    );
  }

  /// Regroupe les éléments d'un bloc par rangée (même valeur d'ordre).
  Widget _buildLayoutBlock(
    List<MapEntry<LayoutElement, ElementPosition>> entries,
    Color cText,
    Color cSub,
    Color accent,
  ) {
    final rows = <int, List<MapEntry<LayoutElement, ElementPosition>>>{};
    for (final entry in entries) {
      rows.putIfAbsent(entry.value.order, () => []).add(entry);
    }
    final sortedOrders = rows.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final order in sortedOrders) ...[
          _buildLayoutRow(rows[order]!, cText, cSub, accent),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  /// Rangée : un élément colSpan 2 → pleine largeur, sinon gauche/droite.
  Widget _buildLayoutRow(
    List<MapEntry<LayoutElement, ElementPosition>> row,
    Color cText,
    Color cSub,
    Color accent,
  ) {
    row.sort((a, b) => a.value.column.compareTo(b.value.column));
    if (row.length == 1 && row.first.value.colSpan == 2) {
      return _layoutElement(row.first.key, cText, cSub, accent);
    }
    final left = row.where((e) => e.value.column == 0).toList();
    final right = row.where((e) => e.value.column == 1).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: left.isEmpty
              ? const SizedBox()
              : _layoutElement(left.first.key, cText, cSub, accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: right.isEmpty
              ? const SizedBox()
              : _layoutElement(right.first.key, cText, cSub, accent),
        ),
      ],
    );
  }

  Widget _companyLogoBox(Color accent) {
    final hasLogo = (_company?.logoPath ?? '').isNotEmpty;
    return Container(
      width: 46,
      height: 46,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: hasLogo
          ? LogoImage(path: _company!.logoPath, width: 46, height: 46)
          : Icon(Icons.business_rounded, size: 22, color: accent),
    );
  }

  /// Widget d'aperçu d'un élément du layout (données réelles de la facture).
  Widget _layoutElement(
      LayoutElement element, Color cText, Color cSub, Color accent) {
    final invoice = _invoice!;
    final client = _client;
    final company = _company;
    switch (element) {
      case LayoutElement.logo:
        return _companyLogoBox(accent);
      case LayoutElement.companyName:
        return Text(
          company?.name ?? 'Mon entreprise',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 14.5, fontWeight: FontWeight.w800, color: cText),
        );
      case LayoutElement.companyAddress:
        return Text(
          company?.address ?? 'Adresse',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: cSub),
        );
      case LayoutElement.companyPhone:
        return Text(
          company?.phone ?? '',
          style: TextStyle(fontSize: 10.5, color: cSub),
        );
      case LayoutElement.companyEmail:
        return Text(
          company?.email ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: cSub),
        );
      case LayoutElement.invoiceTitle:
        final statusColor = _getStatusColor(invoice.status);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(invoice.status),
                          size: 11, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        _getStatusLabel(invoice.status).toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              invoice.isDevis ? 'DEVIS' : 'FACTURE',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              invoice.invoiceNumber,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: cText),
            ),
            const SizedBox(height: 4),
            Text(
              'Émise le ${DateFormat('dd MMM yyyy').format(invoice.issueDate)}'
              ' · Échéance le ${DateFormat('dd MMM yyyy').format(invoice.dueDate)}',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 9.5, color: cSub),
            ),
          ],
        );
      case LayoutElement.clientName:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _miniLabel('FACTURE À', cSub),
            const SizedBox(height: 5),
            Text(
              client?.name ?? 'Client inconnu',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: cText),
            ),
          ],
        );
      case LayoutElement.clientAddress:
        return Text(
          client?.address ?? '',
          style: TextStyle(fontSize: 10.5, color: cSub),
        );
      case LayoutElement.clientPhone:
        return Text(
          client?.phone ?? '',
          style: TextStyle(fontSize: 10.5, color: cSub),
        );
      case LayoutElement.clientEmail:
        return Text(
          client?.email ?? '',
          style: TextStyle(fontSize: 10.5, color: cSub),
        );
      case LayoutElement.itemsTable:
        return _buildItemsBlock(cText, cSub, accent);
      case LayoutElement.subtotal:
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: _totalLine('Sous-total HT', _money(invoice.subtotal), 215, 11,
              FontWeight.w500, cSub),
        );
      case LayoutElement.discount:
        if (invoice.discount <= 0) return const SizedBox.shrink();
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: _totalLine('Remise', '-${_money(invoice.discount)}', 215, 11,
              FontWeight.w500, Colors.red),
        );
      case LayoutElement.taxAmount:
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: _totalLine(
            'TVA (${invoice.taxRate.toStringAsFixed(0)}%)',
            _money(invoice.taxAmount),
            215,
            11,
            FontWeight.w500,
            cSub,
          ),
        );
      case LayoutElement.totalAmount:
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 215,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL TTC',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: accent),
                ),
                Text(
                  _money(invoice.totalAmount),
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: accent),
                ),
              ],
            ),
          ),
        );
      case LayoutElement.footerText:
        return Text(
          company?.legalText ?? 'Conforme aux normes OHADA',
          style: TextStyle(
              fontSize: 9.5, color: cSub, fontStyle: FontStyle.italic),
        );
      case LayoutElement.legalMention:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.05),
            border: Border(left: BorderSide(color: accent, width: 2)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _miniLabel('MENTION LÉGALE', accent),
              const SizedBox(height: 4),
              Text(
                'RCCM : ${(company?.rccm.isNotEmpty ?? false) ? company!.rccm : '—'}'
                '  ·  N° Contribuable : ${(company?.taxId.isNotEmpty ?? false) ? company!.taxId : '—'}',
                style: TextStyle(fontSize: 9.5, color: cSub),
              ),
              if (company != null && company.legalText.isNotEmpty)
                Text(
                  company.legalText,
                  style: TextStyle(
                      fontSize: 9.5,
                      color: cSub,
                      fontStyle: FontStyle.italic),
                ),
            ],
          ),
        );
      case LayoutElement.qrCode:
        if (_selectedTemplate?.showPaymentQR != true) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: cSub.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              Icon(Icons.qr_code_2, size: 40, color: accent),
              const SizedBox(height: 4),
              Text(
                'Paiement Mobile Money',
                style: TextStyle(fontSize: 9, color: cSub),
              ),
            ],
          ),
        );
      case LayoutElement.signature:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                width: 120, height: 1, color: cSub.withValues(alpha: 0.4)),
            const SizedBox(height: 4),
            Text('Signature', style: TextStyle(fontSize: 10, color: cSub)),
          ],
        );
    }
  }

  /// Liste des lignes : DÉSIGNATION / QTÉ (1ʳᵉ ligne surlignée, maquette).
  Widget _buildItemsBlock(Color cText, Color cSub, Color accent) {
    final items = _invoice!.items;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'Aucune ligne dans cette facture.',
          style: TextStyle(fontSize: 11.5, color: cSub),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(flex: 6, child: _miniLabel('DÉSIGNATION', cSub)),
            Expanded(
              flex: 2,
              child: Text(
                'QTÉ',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: cSub,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: i == 0
                  ? accent.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Text(
                    items[i].description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cText),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${items[i].quantity}',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: cText),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _miniLabel(String label, Color cSub) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: cSub,
      ),
    );
  }

  // ============================================================
  //  🎨 IMAGE DE FOND & 📜 MENTION LÉGALE — outils du détail facture
  // ============================================================

  /// Ouvre la palette d'image de fond (bottom sheet partagée avec le
  /// workspace) pour le modèle actif. Persiste à chaque changement.
  Future<void> _openBackgroundSheet() async {
    final template = _selectedTemplate;
    if (template == null || !mounted) return;
    await showBackgroundSettingsSheet(
      context,
      current: _backgroundSettings,
      onChanged: _persistBackground,
    );
  }

  /// Persiste le fond choisi (préréglage palette ou image galerie) pour le
  /// modèle actif — sans toucher aux positions / mapping existants.
  Future<void> _persistBackground(TemplateBackgroundSettings next) async {
    final template = _selectedTemplate;
    if (template == null) return;
    final custom = await TemplateCustomService.loadCustom(template.id);
    await TemplateCustomService.saveCustom(
      template.id,
      positions: custom.positions,
      mapping: custom.mapping,
      background: next,
    );
    if (!mounted) return;
    setState(() {
      _backgroundSettings = next;
      _previewBackground =
          next.hasCustomImage ? decodeBackgroundImage(next.fileData) : null;
      _bgOpacity = next.opacity;
      _bgBlur = next.blur;
      _bgFit = next.fit;
    });
  }

  /// 📜 Éditeur « Mention légale & conditions » de la société : texte légal
  /// (pied de facture), RCCM et N° contribuable — enregistrés dans Company.
  Future<void> _showLegalEditor() async {
    final company = _company;
    if (company == null || !mounted) return;
    final legalCtrl = TextEditingController(text: company.legalText);
    final rccmCtrl = TextEditingController(text: company.rccm);
    final taxCtrl = TextEditingController(text: company.taxId);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151722) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mention légale & conditions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ces informations apparaissent sur toutes vos factures.',
                style: TextStyle(fontSize: 11.5, color: subTextColor),
              ),
              const SizedBox(height: 12),
              _legalField('Texte légal (mentions, conditions de paiement…)',
                  legalCtrl, 3),
              _legalField('RCCM', rccmCtrl, 1),
              _legalField('N° Contribuable', taxCtrl, 1),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(sheetCtx);
                    final updated = company.copyWith(
                      legalText: legalCtrl.text.trim(),
                      rccm: rccmCtrl.text.trim(),
                      taxId: taxCtrl.text.trim(),
                    );
                    await _db.saveCompany(updated);
                    if (!mounted) return;
                    setState(() => _company = updated);
                    navigator.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Informations légales enregistrées'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    legalCtrl.dispose();
    rccmCtrl.dispose();
    taxCtrl.dispose();
  }

  /// Champ texte compact du formulaire légal.
  Widget _legalField(
      String label, TextEditingController controller, int maxLines) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: subTextColor,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(fontSize: 13, color: textColor),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalLine(String label, String value, double width, double fontSize,
      FontWeight weight, Color color) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: fontSize, color: color, fontWeight: weight)),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize, color: color, fontWeight: weight)),
        ],
      ),
    );
  }

  /// Boutons d'action : « Aperçu PDF » (dégradé royal) + Imprimer / Partager.
  Widget _buildActionButtons() {
    final c = RoyalScheme.of(context);
    return Column(
      children: [
        Material(
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: RoyalGradients.royal,
              boxShadow: [
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _previewAndPrint,
              child: Container(
                height: 56,
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Aperçu PDF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _secondaryAction(
                  c, Icons.print_rounded, 'Imprimer', _previewAndPrint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _secondaryAction(
                  c, Icons.ios_share, 'Partager', _shareInvoice),
            ),
          ],
        ),
      ],
    );
  }

  /// Bouton d'action secondaire (outline moderne).
  Widget _secondaryAction(
    RoyalScheme c,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: c.outlineVariant.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: c.surfaceContainerLow,
        minimumSize: const Size.fromHeight(50),
      ),
      icon: Icon(icon, size: 19, color: c.secondary),
      label: Text(
        label,
        style: TextStyle(
          color: c.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ===== HELPERS =====

  /// Montant formaté maquette : 448 400 (séparateur milliers = espace).
  static String _money(double value) =>
      NumberFormat('#,##0').format(value).replaceAll(',', ' ');

  IconData _statusIcon(String status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle_rounded;
      case 'sent':
        return Icons.schedule_rounded;
      case 'overdue':
        return Icons.warning_amber_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.edit_note_rounded;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return const Color(0xFF16A34A);
      case 'sent':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blueGrey;
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











