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
import 'dart:ui' show ImageFilter;

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

  /// Applique les personnalisations locales (positions / mapping /
  /// arrière-plan) d'un modèle et met à jour l'aperçu.
  Future<InvoiceTemplate> _applyCustomisation(InvoiceTemplate template) async {
    final custom = await TemplateCustomService.loadCustom(template.id);
    final applied = template.copyWith(
      positions: custom.positions,
      mapping: {...template.mapping, ...custom.mapping},
    );

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
    } else if (template.fileData.isNotEmpty && template.fileType != 'pdf') {
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
    final bgColor = themeProvider.backgroundColor;

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
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 22),
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

  /// En-tête maquette : retour · n° + date · personnaliser · partager · ⋯
  Widget _buildHeader() {
    return Row(
      children: [
        _circleButton(Icons.arrow_back, () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/invoices');
          }
        }, tooltip: 'Retour'),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _invoice!.invoiceNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Créée le ${DateFormat('dd MMM yyyy').format(_invoice!.issueDate)}',
                style: TextStyle(fontSize: 11.5, color: subTextColor),
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
        _buildOverflowMenu(),
      ],
    );
  }

  /// Bouton circulaire translucide (style maquette).
  Widget _circleButton(IconData icon, VoidCallback onTap,
      {String? tooltip}) {
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.8);
    final btn = Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: textColor),
        ),
      ),
    );
    if (tooltip == null || tooltip.isEmpty) return btn;
    return Tooltip(message: tooltip, child: btn);
  }

  /// Menu « ⋯ » : email, partage équipe, boutique de modèles.
  Widget _buildOverflowMenu() {
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
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.8),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.more_horiz, size: 20, color: textColor),
      ),
    );
  }

  /// Section « MODÈLES » : libellé + puce « Cliquez pour changer » +
  /// carrousel horizontal de vignettes (maquette d_tail_facture).
  Widget _buildModelsSection(bool canAccessPremium) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'MODÈLES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: subTextColor,
                ),
              ),
            ),
            GestureDetector(
              onTap: _openTemplatePicker,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Cliquez pour changer',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            itemCount: _templates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final template = _templates[index];
              return _buildTemplateThumb(template, canAccessPremium);
            },
          ),
        ),
      ],
    );
  }

  /// Vignette d'un modèle : mini aperçu de page + badges
  /// (✓ sélectionné · ⭐ premium · 🔒 verrouillé).
  Widget _buildTemplateThumb(
    InvoiceTemplate template,
    bool canAccessPremium,
  ) {
    final isSelected = _selectedTemplate?.id == template.id;
    final isLocked = template.isPremium && !canAccessPremium;

    Widget thumb = Container(
      width: 78,
      height: 102,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: template.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? primaryColor
              : isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.grey.withValues(alpha: 0.35),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 22,
            decoration: BoxDecoration(
              color: template.primaryColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 6),
          _thumbLine(Colors.grey.withValues(alpha: 0.4), 1.0),
          const SizedBox(height: 4),
          _thumbLine(Colors.grey.withValues(alpha: 0.3), 0.7),
          const Spacer(),
          _thumbLine(template.primaryColor.withValues(alpha: 0.8), 0.55),
        ],
      ),
    );

    if (isLocked) {
      thumb = Stack(
        children: [
          Positioned.fill(child: thumb),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.lock_rounded, size: 20, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _selectTemplate(template, canAccessPremium),
      child: SizedBox(
        width: 78,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                thumb,
                if (template.isPremium && !isLocked)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star_rounded,
                          size: 13, color: Colors.white),
                    ),
                  ),
                if (isSelected)
                  Positioned(
                    bottom: -5,
                    right: -5,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 13, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isLocked ? 'Premium 🔒' : template.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primaryColor : subTextColor,
              ),
            ),
          ],
        ),
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
  Widget _buildInvoicePreviewCard() {
    final tmplBg = _selectedTemplate?.backgroundColor ?? Colors.white;
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.07) : tmplBg;
    final bool darkCard = cardBg.computeLuminance() < 0.45;
    final cText = isDark ? Colors.white : (darkCard ? Colors.white : textColor);
    final cSub = isDark
        ? (Colors.grey[300] ?? Colors.grey)
        : (darkCard ? Colors.white70 : subTextColor);
    final accent = _selectedTemplate?.primaryColor ?? primaryColor;

    Widget? backgroundLayer;
    if (_previewBackground != null) {
      Widget image = Image.memory(
        _previewBackground!,
        fit: _bgFit == 'contain' ? BoxFit.contain : BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
      );
      if (_bgBlur > 0) {
        image = ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: _bgBlur, sigmaY: _bgBlur),
          child: image,
        );
      }
      backgroundLayer = Positioned.fill(
        child: Opacity(opacity: _bgOpacity.clamp(0.0, 1.0), child: image),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            if (backgroundLayer != null) backgroundLayer,
            if (_previewBackground != null)
              Positioned.fill(
                child: ColoredBox(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.45),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCompanyBlock(cText, cSub, accent),
                  _cardDivider(cSub),
                  _buildClientDatesBlock(cText, cSub),
                  _cardDivider(cSub),
                  _buildItemsBlock(cText, cSub, accent),
                  const SizedBox(height: 14),
                  _buildTotalsBlock(cText, cSub, accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardDivider(Color cSub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(
          height: 1, thickness: 1, color: cSub.withValues(alpha: 0.18)),
    );
  }

  /// Bloc société : logo + coordonnées | badge statut + numéro (maquette).
  Widget _buildCompanyBlock(Color cText, Color cSub, Color accent) {
    final statusColor = _getStatusColor(_invoice!.status);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _companyLogoBox(accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_company != null) ...[
                Text(
                  _company!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: cText),
                ),
                if (_company!.address.isNotEmpty)
                  Text(
                    _company!.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: cSub),
                  ),
                if (_company!.phone.isNotEmpty)
                  Text(
                    _company!.phone,
                    style: TextStyle(fontSize: 10.5, color: cSub),
                  ),
              ] else
                Text(
                  'Mon entreprise',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: cText),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_statusIcon(_invoice!.status),
                      size: 11, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    _getStatusLabel(_invoice!.status).toUpperCase(),
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
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                _invoice!.invoiceNumber,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: cText),
              ),
            ),
          ],
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

  /// Bloc « FACTURE À » + dates d'émission / d'échéance (2 colonnes).
  Widget _buildClientDatesBlock(Color cText, Color cSub) {
    final client = _client;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(
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
              if (client != null && client.address.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  client.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: cSub),
                ),
              ],
              if (client != null && client.phone.isNotEmpty)
                Text(
                  client.phone,
                  style: TextStyle(fontSize: 10.5, color: cSub),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _miniLabel('DATE D\'ÉMISSION', cSub),
              const SizedBox(height: 3),
              Text(
                DateFormat('dd MMM yyyy').format(_invoice!.issueDate),
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600, color: cText),
              ),
              const SizedBox(height: 8),
              _miniLabel('DATE D\'ÉCHÉANCE', cSub),
              const SizedBox(height: 3),
              Text(
                DateFormat('dd MMM yyyy').format(_invoice!.dueDate),
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600, color: cText),
              ),
            ],
          ),
        ),
      ],
    );
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

  /// Totaux alignés à droite (Sous-total HT / TVA / TOTAL TTC accentué).
  Widget _buildTotalsBlock(Color cText, Color cSub, Color accent) {
    final discount = _invoice!.discount;
    const width = 215.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _totalLine('Sous-total HT', _money(_invoice!.subtotal), width, 11,
            FontWeight.w500, cSub),
        if (discount > 0) ...[
          const SizedBox(height: 4),
          _totalLine('Remise', '-${_money(discount)}', width, 11,
              FontWeight.w500, cSub),
        ],
        const SizedBox(height: 4),
        _totalLine(
          'TVA (${_invoice!.taxRate.toStringAsFixed(0)}%)',
          _money(_invoice!.taxAmount),
          width,
          11,
          FontWeight.w500,
          cSub,
        ),
        Container(
          height: 1,
          width: width,
          margin: const EdgeInsets.symmetric(vertical: 7),
          color: cSub.withValues(alpha: 0.25),
        ),
        SizedBox(
          width: width,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL TTC',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: accent),
              ),
              Text(
                _money(_invoice!.totalAmount),
                style: TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w800, color: accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Montant exprimé en FCFA',
          style: TextStyle(
            fontSize: 9.5,
            fontStyle: FontStyle.italic,
            color: cSub,
          ),
        ),
      ],
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

  /// Boutons d'action empilés : « Aperçu PDF » (dégradé) / « Imprimer ».
  Widget _buildActionButtons() {
    return Column(
      children: [
        Material(
          borderRadius: BorderRadius.circular(14),
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4338CA).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _previewAndPrint,
              child: Container(
                height: 54,
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
                        fontSize: 15,
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
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: _previewAndPrint,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.25),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.5),
            ),
            icon: Icon(Icons.print_rounded, size: 20, color: primaryColor),
            label: Text(
              'Imprimer',
              style: TextStyle(
                color: primaryColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
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











