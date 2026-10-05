// lib/screens/dashboard/invoice_detail_screen.dart
//
// 🎨 Refonte « Aperçu Facture » — maquette Stitch
//   • AppBar minimaliste : retour + « Aperçu » + bouton « sauver »
//   • Canvas sombre contenant la facture A4 (`StitchA4InvoicePreview`)
//   • Barre basse sombre : Éditer + Personnaliser (boutons ronds)
//   • Toutes les actions : PDF/impression, partage, email, mentions légales,
//     image de fond, modèles premium, suppression.
// ignore_for_file: dead_null_aware_expression, deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/database_service.dart';
import '../../services/mail_service.dart';
import '../../services/printing_service.dart';
import '../../services/template_service.dart';
import '../../services/template_selection_service.dart';
import '../../services/template_custom_service.dart';
import '../../services/signature_service.dart';
import '../../services/wallet_service.dart';
import '../../services/settings_service.dart';
import '../../models/invoice.dart';
import '../../models/invoice_settings.dart';
import '../../models/client.dart';
import '../../models/company.dart';
import '../../models/invoice_template.dart';
import '../../models/invoice_layout.dart';
import '../../models/team.dart';
import '../../providers/theme_provider.dart';
import '../../services/team_service.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/template_background_palette.dart';
import '../../widgets/stitch_a4_invoice_preview.dart';
import 'widgets/payment_bottom_sheet.dart';

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

  // Équipes chargées pour le bottom sheet « Partager la facture ».
  List<Team> _cachedTeams = [];

  // 🖼️ Arrière-plan personnalisé (workspace / modèle admin) pour l'aperçu.
  Uint8List? _previewBackground;
  TemplateBackgroundSettings _backgroundSettings =
      const TemplateBackgroundSettings();

  /// 📐 Positions drag & drop du modèle actif (WYSIWYG avec l'impression PDF).
  Map<String, dynamic> _customPositions = const {};

  // 🧩 Layout drag & drop du modèle actif — partagé avec le workspace.
  InvoiceLayoutConfig _layoutConfig = InvoiceLayoutConfig.defaultLayout();

  // 📦 Paramètres de facture (filigrane, couleurs…) — SettingsService.
  InvoiceSettings _invoiceSettings = InvoiceSettings.defaultSettings;

  // 🔍 Zoom de l'aperçu papier.
  double _zoom = 1.0;

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
    if (mounted) setState(() => _isLoading = true);
    try {
      final settings = await SettingsService.instance.loadSettings();
      final invoice = await _db.getInvoice(widget.invoiceId);
      if (!mounted) return;
      Client? client;
      Company? company;
      if (invoice != null) {
        client = await _db.getClient(invoice.clientId);
        company = await _db.getCompany();
      }
      if (!mounted) return;
      setState(() {
        _invoiceSettings = settings;
        _invoice = invoice;
        _client = client;
        _company = company;
        _isLoading = false;
      });
    } catch (e) {
      assert(() {
        debugPrint('⚠️ _loadData(invoice_detail): $e');
        return true;
      }());
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTemplates() async {
    // Fusion : templates par défaut + ceux créés par l'admin (boutique).
    final defaults = InvoiceTemplate.getDefaultTemplates();
    List<InvoiceTemplate> adminTemplates = [];
    try {
      adminTemplates = await TemplateService().getAllTemplates();
    } catch (e) {
      assert(() {
        debugPrint('⚠️ _loadTemplates: getAllTemplates a échoué: $e');
        return true;
      }());
    }
    if (!mounted) return;
    final adminIds = adminTemplates.map((e) => e.id).toSet();
    _templates = [
      ...defaults.where((d) => !adminIds.contains(d.id)),
      ...adminTemplates,
    ];

    // ✅ Modèle actif choisi (boutique / aperçu) — sélection persistante.
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
    if (!mounted) return;
    if (selected != null) {
      _selectedTemplate = await _applyCustomisation(selected);
    }
    if (!mounted) return;
    setState(() {});
  }

  /// Applique les personnalisations locales (positions / mapping / fond).
  Future<InvoiceTemplate> _applyCustomisation(InvoiceTemplate template) async {
    final custom = await TemplateCustomService.loadCustom(template.id);
    final basePositions = InvoiceTemplate.effectivePositions(
      customPositions: custom.positions,
      templatePositions: template.positions,
    );
    final applied = template.copyWith(
      positions: basePositions,
      mapping: {...template.mapping, ...custom.mapping},
    );

    // 🖊️ Signature de l'émetteur (repli si le modèle n'en a pas).
    final positions = Map<String, dynamic>.from(basePositions);
    if ((positions['signature_image'] as String?)?.isNotEmpty != true) {
      try {
        final signatureBytes = await SignatureService().loadSignatureBytes();
        if (signatureBytes != null && signatureBytes.isNotEmpty) {
          positions['signature_image'] = base64Encode(signatureBytes);
        }
      } catch (_) {
        // Signature illisible : la facture reste imprimable sans image.
      }
    }

    _layoutConfig = positions.isNotEmpty
        ? InvoiceLayoutConfig.fromMap(positions)
        : InvoiceLayoutConfig.defaultLayout();
    _backgroundSettings = custom.background;
    _customPositions = positions;
    _previewBackground = decodeBackgroundImage(custom.background.fileData);

    if (!custom.background.hasCustomImage &&
        !custom.background.hasPreset &&
        template.fileData.isNotEmpty &&
        template.fileType != 'pdf') {
      _previewBackground = decodeBackgroundImage(template.fileData);
    }
    return applied;
  }

  Future<void> _openTemplatePicker() async {
    await context.push('/templates/select');
    if (mounted) await _loadTemplates();
  }

  bool _canCustomizeActiveTemplate() {
    final template = _selectedTemplate;
    if (template == null) return false;
    final auth = context.read<AppAuthProvider>();
    return template.canBeCustomizedBy(
      userId: auth.user?.id ?? '',
      isAdmin: auth.isAdmin,
      hasPremiumAccess:
          context.read<SubscriptionProvider>().canAccessPremiumTemplates,
    );
  }

  void _showCustomizationRestricted() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            "Personnalisation réservée à l'administrateur et au propriétaire "
            "du modèle. Acquérez-le dans la boutique pour le personnaliser."),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openWorkspace() async {
    final template = _selectedTemplate;
    if (template == null) {
      await _openTemplatePicker();
      return;
    }
    if (!_canCustomizeActiveTemplate()) {
      _showCustomizationRestricted();
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
        customPositions: _customPositions,
        customMapping: _selectedTemplate!.mapping,
        customBackground: _backgroundSettings,
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
        customPositions: _customPositions,
        customMapping: _selectedTemplate!.mapping,
        customBackground: _backgroundSettings,
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
        customPositions: _customPositions,
        customMapping: _selectedTemplate!.mapping,
        customBackground: _backgroundSettings,
      );
      final htmlBody = MailService.getInvoiceTemplate(
        _client!.name,
        _invoice!.invoiceNumber,
        '',
        companyName: _company!.name,
        amount: _invoice!.totalAmount,
        dueDate: _fmtDate(_invoice!.dueDate),
      );
      final sent = await MailService.sendHtmlEmail(
        to: _client!.email,
        subject: 'Votre facture ${_invoice!.invoiceNumber} — ${_company!.name}',
        htmlBody: htmlBody,
        attachments: [
          EmailAttachment(
            filename: 'facture_${_invoice!.invoiceNumber}.pdf',
            bytes: pdfData,
            contentType: 'application/pdf',
          ),
        ],
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

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _showShareDialog() async {
    if (_invoice == null) return;

    final teamService = TeamService();
    final auth = context.read<AppAuthProvider>();
    final userId = auth.user?.id;
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être connecté pour partager.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final teams = await teamService.getUserTeams(userId);
    if (!mounted) return;
    _cachedTeams = teams;

    if (teams.isEmpty) {
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
      builder: (sheetCtx) {
        String? selectedTeamId;
        String permissionLevel = 'read';
        final Set<String> selectedMembers = {};
        Map<String, Map<String, String>> profiles = {};
        List<String> memberIds = [];
        bool loadingMembers = false;

        return StatefulBuilder(
          builder: (sheetCtx, sheetSetState) {
            Future<void> loadMembers(String teamId) async {
              sheetSetState(() => loadingMembers = true);
              final team = await teamService.getTeam(teamId);
              final profs = await teamService.getMemberProfiles(teamId);
              final ids = <String>{
                if (team != null) team.ownerId,
                ...?team?.adminIds,
                ...?team?.memberIds,
              }..remove(userId);
              selectedMembers.clear();
              sheetSetState(() {
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

            return _shareSheetBody(
              sheetCtx,
              sheetSetState,
              teamService,
              auth,
              selectedTeamId,
              permissionLevel,
              selectedMembers,
              memberIds,
              loadingMembers,
              memberLabel,
              (v) {
                sheetSetState(() => selectedTeamId = v);
                if (v != null) loadMembers(v);
              },
              (v) => sheetSetState(() => permissionLevel = v!),
              (v) => sheetSetState(() {
                if (v == true) {
                  selectedMembers.addAll(memberIds);
                } else {
                  selectedMembers.clear();
                }
              }),
              (uid, v) => sheetSetState(() {
                if (v == true) {
                  selectedMembers.add(uid);
                } else {
                  selectedMembers.remove(uid);
                }
              }),
            );
          },
        );
      },
    );
  }

  Widget _shareSheetBody(
    BuildContext sheetCtx,
    void Function(VoidCallback) sheetSetState,
    TeamService teamService,
    AppAuthProvider auth,
    String? selectedTeamId,
    String permissionLevel,
    Set<String> selectedMembers,
    List<String> memberIds,
    bool loadingMembers,
    String Function(String) memberLabel,
    ValueChanged<String?> onTeamChanged,
    ValueChanged<String?> onPermissionChanged,
    ValueChanged<bool> onToggleAll,
    void Function(String, bool) onToggleMember,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(sheetCtx).size.height * 0.8,
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
            items: _cachedTeams.map((team) {
              return DropdownMenuItem(value: team.id, child: Text(team.name));
            }).toList(),
            onChanged: onTeamChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Lecture seule'),
                  value: 'read',
                  groupValue: permissionLevel,
                  onChanged: onPermissionChanged,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Écriture'),
                  value: 'write',
                  groupValue: permissionLevel,
                  onChanged: onPermissionChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Mentionner (@) les membres',
            style: TextStyle(
              color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
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
                  color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
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
                    onChanged: (v) => onToggleAll(v == true),
                    activeColor: Theme.of(sheetCtx).colorScheme.primary,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  for (final uid in memberIds)
                    CheckboxListTile(
                      dense: true,
                      value: selectedMembers.contains(uid),
                      onChanged: (v) => onToggleMember(uid, v == true),
                      title: Text(
                        '@${memberLabel(uid)}',
                        style: TextStyle(
                          color: selectedMembers.contains(uid)
                              ? Theme.of(sheetCtx).colorScheme.primary
                              : null,
                          fontWeight: selectedMembers.contains(uid)
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      activeColor: Theme.of(sheetCtx).colorScheme.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _shareButton(sheetCtx, teamService, auth, selectedTeamId,
              permissionLevel, selectedMembers),
        ],
      ),
    );
  }

  Widget _shareButton(
    BuildContext sheetCtx,
    TeamService teamService,
    AppAuthProvider auth,
    String? selectedTeamId,
    String permissionLevel,
    Set<String> selectedMembers,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: selectedTeamId == null || selectedMembers.isEmpty
            ? null
            : () async {
                final invoiceId = _invoice?.id;
                final invoiceNumber = _invoice?.invoiceNumber ?? '';
                final sharedBy = auth.user?.id;
                if (invoiceId == null || sharedBy == null) return;
                await teamService.shareResource(
                  resourceId: invoiceId,
                  resourceType: 'invoice',
                  resourceName: invoiceNumber,
                  teamId: selectedTeamId,
                  sharedBy: sharedBy,
                  sharedWith: selectedMembers.toList(),
                  permissionLevel: permissionLevel,
                );
                if (!sheetCtx.mounted) return;
                Navigator.pop(sheetCtx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Facture partagée avec ${selectedMembers.length} membre(s) ✅'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(sheetCtx).colorScheme.primary,
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
    );
  }

  // ============================================================
  //  🎨 UI — Aperçu Facture (maquette Stitch)
  // ============================================================

  @override
  Widget build(BuildContext context) {
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
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/invoices');
                  }
                },
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
      appBar: _appBar(c),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Canvas scrollable contenant la facture A4.
                Positioned.fill(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    child: Center(
                      child: Transform.scale(
                        scale: _zoom,
                        alignment: Alignment.topCenter,
                        child: _buildInvoicePaper(c),
                      ),
                    ),
                  ),
                ),
                // Bouton zoom flottant (haut droite, sous la barre).
                Positioned(top: 10, right: 16, child: _zoomButton(c)),
              ],
            ),
          ),
          _buildBottomBar(c),
        ],
      ),
    );
  }

  /// AppBar maquette : retour fin + « Aperçu » + « sauver » à droite.
  PreferredSizeWidget _appBar(RoyalScheme c) {
    return AppBar(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: c.onSurface, size: 20),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/invoices');
          }
        },
      ),
      title: Text(
        'Aperçu',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: c.onSurface,
        ),
      ),
      actions: [
        // « sauver » (texte bleu — action principale de la maquette).
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton(
            onPressed: _previewAndPrint,
            style: TextButton.styleFrom(
              foregroundColor: c.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'sauver',
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: c.primary,
              ),
            ),
          ),
        ),
        // Menu contextuel « … ».
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: c.onSurface, size: 22),
          onSelected: (value) {
            switch (value) {
              case 'share':
                _shareInvoice();
                break;
              case 'pdf':
                _previewAndPrint();
                break;
              case 'email':
                _sendInvoiceByEmail();
                break;
              case 'team':
                _showShareDialog();
                break;
              case 'picker':
                _openTemplatePicker();
                break;
              case 'delete':
                _confirmDeleteInvoice();
                break;
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
                value: 'share', child: Text('Partager le PDF')),
            const PopupMenuItem(
                value: 'pdf', child: Text('Aperçu / Imprimer PDF')),
            const PopupMenuItem(
                value: 'email', child: Text('Envoyer par email')),
            const PopupMenuItem(
                value: 'team', child: Text('Partager avec l\'équipe')),
            const PopupMenuItem(
                value: 'picker', child: Text('Changer de modèle')),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Supprimer',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 🗑️ Suppression définitive de la facture.
  Future<void> _confirmDeleteInvoice() async {
    final invoice = _invoice;
    if (invoice == null) return;

    bool removeReminders = true;
    bool removeTransactions = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Supprimer la facture ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La facture ${invoice.invoiceNumber} sera définitivement '
                'supprimée. Cette action est irréversible.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: removeReminders,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Supprimer aussi les rappels liés',
                  style: TextStyle(fontSize: 13),
                ),
                onChanged: (v) => setDlg(() => removeReminders = v ?? false),
              ),
              CheckboxListTile(
                value: removeTransactions,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Supprimer aussi les encaissements liés '
                  '(transactions du portefeuille)',
                  style: TextStyle(fontSize: 13),
                ),
                onChanged: (v) =>
                    setDlg(() => removeTransactions = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final uid = context.read<AppAuthProvider>().user?.id ?? '';

      await _db.deleteInvoice(invoice.id);

      if (removeReminders) {
        final reminders = await _db.getReminders();
        for (final r in reminders.where((r) => r.invoiceId == invoice.id)) {
          await _db.deleteReminder(r.id);
        }
      }

      int removedTx = 0;
      if (removeTransactions && uid.isNotEmpty) {
        removedTx = await WalletService().deleteInvoiceTransactions(
          userId: uid,
          invoiceId: invoice.id,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removedTx > 0
                ? '✅ Facture supprimée ($removedTx encaissement(s) annulé(s))'
                : '✅ Facture supprimée',
          ),
          backgroundColor: RoyalColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/invoices');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors de la suppression : $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Papier A4 : widget Stitch partagé, alimenté par la facture réelle et
  /// les personnalisations sauvegardées du modèle actif.
  Widget _buildInvoicePaper(RoyalScheme c) {
    final template = _selectedTemplate;
    final effective = template == null
        ? null
        : SettingsService.applyToTemplate(template, _invoiceSettings);
    final stitchData = StitchPreviewDataX.fromInvoice(
      invoice: _invoice,
      client: _client,
      company: _company,
    );
    final bool hasDecoratedBg =
        _previewBackground != null || _backgroundSettings.hasPreset;

    return Column(
      children: [
        // Bandeau du modèle actif (tap = changer de modèle).
        if (template != null) ...[
          GestureDetector(
            onTap: _openTemplatePicker,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: c.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: template.primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Modèle : ${template.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'WorkSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.onSurface,
                      ),
                    ),
                  ),
                  Icon(Icons.swap_horiz_rounded,
                      size: 16, color: c.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
        // Papier de la facture.
        StitchA4InvoicePreview(
          data: stitchData,
          accentColor: effective?.primaryColor,
          pageColor: effective?.backgroundColor,
          showLogo: effective?.showLogo ?? true,
          showBorder: effective?.showBorder ?? false,
          showTaxDetails: effective?.showTaxDetails ?? true,
          showPaymentTerms: effective?.showPaymentTerms ?? true,
          showPaymentQR: effective?.showPaymentQR ?? false,
          fontFamily: effective?.fontFamily ?? 'WorkSans',
          fontScale: (effective?.fontSize ?? 12) / 12,
          layoutConfig: _layoutConfig,
          backgroundSettings: _backgroundSettings,
          backgroundImage: _previewBackground,
          watermarkText: _invoiceSettings.watermarkText,
          showWatermark: _invoiceSettings.showWatermark,
          customPositions: _customPositions,
        ),
        if (!hasDecoratedBg) ...[
          const SizedBox(height: 8),
          Text(
            'Personnalisez le fond (image / palette) depuis « Personnaliser ».',
            style: TextStyle(
              fontFamily: 'WorkSans',
              fontSize: 10.5,
              color: c.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// Bouton zoom flottant (pilule translucide bordée).
  Widget _zoomButton(RoyalScheme c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomIcon(c, Icons.remove, () {
            setState(() => _zoom = (_zoom - 0.1).clamp(0.5, 1.6));
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${(_zoom * 100).toInt()}%',
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.onSurface,
              ),
            ),
          ),
          _zoomIcon(c, Icons.add, () {
            setState(() => _zoom = (_zoom + 0.1).clamp(0.5, 1.6));
          }),
        ],
      ),
    );
  }

  Widget _zoomIcon(RoyalScheme c, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Icon(icon, size: 15, color: c.onSurface),
      ),
    );
  }

  /// Action de la barre basse : bouton rond + libellé.
  Widget _bottomAction(
    RoyalScheme c, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18), width: 1),
              ),
              child: Icon(icon,
                  size: 22, color: iconColor ?? c.inverseOnSurface),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.inverseOnSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Barre basse sombre : Éditer + Personnaliser.
  Widget _buildBottomBar(RoyalScheme c) {
    return Container(
      decoration: BoxDecoration(
        color: c.inverseSurface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 14 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _bottomAction(
            c,
            icon: Icons.edit_outlined,
            label: 'Éditer',
            onTap: () {
              if (_invoice?.status == 'draft') {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => PaymentBottomSheet(
                    onPaymentComplete: () {
                      _reloadAfterPayment();
                    },
                  ),
                );
              } else {
                _openTemplatePicker();
              }
            },
          ),
          _bottomAction(
            c,
            icon: Icons.palette_outlined,
            label: 'Personnaliser',
            onTap: _openCustomizationMenu,
          ),
        ],
      ),
    );
  }

  Future<void> _reloadAfterPayment() async {
    await _loadData();
  }

  /// Menu « Personnaliser » : workspace, image de fond, mention légale, modèles.
  void _openCustomizationMenu() {
    final c = RoyalScheme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151722) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              _menuTile(
                c,
                Icons.widgets_outlined,
                'Personnalisation drag & drop',
                'Blocs, ordre et styles du modèle actif',
                () => _openWorkspaceFromMenu(sheetCtx),
              ),
              _menuTile(
                c,
                Icons.wallpaper_outlined,
                'Image de fond & palette',
                'Image galerie ou préréglage décoratif',
                () => _openBackgroundSheetFromMenu(sheetCtx),
              ),
              _menuTile(
                c,
                Icons.gavel_outlined,
                'Mention légale & conditions',
                'Texte légal, RCCM et N° contribuable',
                () => _openLegalEditorFromMenu(sheetCtx),
              ),
              _menuTile(
                c,
                Icons.dashboard_customize_outlined,
                'Changer de modèle',
                'Boutique et modèles disponibles',
                () {
                  Navigator.pop(sheetCtx);
                  _openTemplatePicker();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile(
    RoyalScheme c,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: c.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: c.onSecondaryContainer),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'WorkSans',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: 'WorkSans',
          fontSize: 11.5,
          color: isDark ? Colors.white70 : subTextColor,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: c.onSurfaceVariant),
      onTap: onTap,
    );
  }

  void _openWorkspaceFromMenu(BuildContext sheetCtx) {
    Navigator.pop(sheetCtx);
    _openWorkspace();
  }

  void _openBackgroundSheetFromMenu(BuildContext sheetCtx) {
    Navigator.pop(sheetCtx);
    _openBackgroundSheet();
  }

  void _openLegalEditorFromMenu(BuildContext sheetCtx) {
    Navigator.pop(sheetCtx);
    _showLegalEditor();
  }

  Future<void> _openBackgroundSheet() async {
    final template = _selectedTemplate;
    if (template == null || !mounted) return;
    if (!_canCustomizeActiveTemplate()) {
      _showCustomizationRestricted();
      return;
    }
    await showBackgroundSettingsSheet(
      context,
      current: _backgroundSettings,
      onChanged: _persistBackground,
    );
  }

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
      final bytes = next.fileData;
      _previewBackground = next.hasCustomImage && bytes.isNotEmpty
          ? decodeBackgroundImage(bytes)
          : null;
    });
  }

  /// 📜 Éditeur « Mention légale & conditions » — texte légal, RCCM, N° contrib.
  Future<void> _showLegalEditor() async {
    final company = _company;
    if (company == null || !mounted) return;
    final legalCtrl = TextEditingController(text: company.legalText);
    final rccmCtrl = TextEditingController(text: company.rccm);
    final taxCtrl = TextEditingController(text: company.taxId);

    try {
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
    } finally {
      // ✅ Dispose garanti même si le sheet se ferme par swipe / tap extérieur.
      legalCtrl.dispose();
      rccmCtrl.dispose();
      taxCtrl.dispose();
    }
  }

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
}