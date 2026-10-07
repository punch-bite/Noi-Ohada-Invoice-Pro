// lib/screens/dashboard/invoice_detail_screen.dart
//
// CHANGELOG v4 :
//   • 🛡️ Bandeau "Mode lecture seule admin" si l'admin ouvre la facture
//     d'un autre utilisateur (empêche les modifications accidentelles).
//   • Boutons Éditer/Personnaliser désactivés en mode lecture seule.
//
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/client.dart';
import '../../models/company.dart';
import '../../models/invoice.dart';
import '../../models/invoice_layout.dart';
import '../../models/invoice_settings.dart';
import '../../models/invoice_template.dart';
import '../../models/team.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/database_service.dart';
import '../../services/invoice_render_service.dart';
import '../../services/mail_service.dart';
import '../../services/printing_service.dart';
import '../../services/settings_service.dart';
import '../../services/signature_service.dart';
import '../../services/team_service.dart';
import '../../services/template_custom_service.dart';
import '../../services/template_selection_service.dart';
import '../../services/template_service.dart';
import '../../services/wallet_service.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/stitch_a4_invoice_preview.dart';
import '../../widgets/template_background_palette.dart';
// 🆕 Bandeau lecture seule.
import '../../widgets/admin_read_only_banner.dart';
import 'invoice_print_preview_screen.dart';

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
  final List<Team> _cachedTeams = [];

  Map<String, dynamic> _customPositions = const {};
  TemplateBackgroundSettings _backgroundSettings =
      const TemplateBackgroundSettings();
  Uint8List? _previewBackground;
  InvoiceSettings _invoiceSettings = InvoiceSettings.defaultSettings;

  double _zoom = 1.0;

  ThemeProvider get themeProvider => context.watch<ThemeProvider>();
  bool get isDark => themeProvider.isDarkMode;
  Color get textColor => themeProvider.textColor ?? Colors.black;
  Color get subTextColor => themeProvider.subTextColor ?? Colors.grey;
  Color get primaryColor => themeProvider.primaryColor ?? Colors.indigo;

  /// 🛡️ Vrai si l'utilisateur est admin MAIS pas propriétaire de la facture.
  bool get _isReadOnlyForAdmin {
    final auth = context.read<AppAuthProvider>();
    return shouldShowReadOnlyBanner(
      isAdmin: auth.isAdmin,
      currentUid: auth.user?.id ?? '',
      docOwnerUid: _invoice?.userId,
    );
  }

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
      debugPrint('⚠️ _loadData: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTemplates() async {
    final settings = await SettingsService.instance.loadSettings();
    final defaults = InvoiceTemplate.getDefaultTemplates();
    List<InvoiceTemplate> adminTemplates = [];
    try {
      adminTemplates = await TemplateService().getAllTemplates();
    } catch (_) {}
    if (!mounted) return;

    final adminIds = adminTemplates.map((e) => e.id).toSet();
    final merged = <InvoiceTemplate>[
      ...defaults.where((d) => !adminIds.contains(d.id)),
      ...adminTemplates,
    ];

    InvoiceTemplate? templateFromInvoice;
    if (_invoice?.templateId != null) {
      for (final t in merged) {
        if (t.id == _invoice!.templateId) {
          templateFromInvoice = t;
          break;
        }
      }
    }

    final activeId = await TemplateSelectionService.getActiveTemplateId();
    if (!mounted) return;

    InvoiceTemplate? selected;
    if (templateFromInvoice != null) {
      selected = templateFromInvoice;
    } else if (activeId != null && merged.any((t) => t.id == activeId)) {
      selected = merged.firstWhere((t) => t.id == activeId);
    } else if (merged.isNotEmpty) {
      selected = merged.firstWhere(
        (t) => t.isDefault,
        orElse: () => merged.first,
      );
    }

    InvoiceTemplate? applied;
    if (selected != null) {
      applied = await _applyCustomisation(selected, settings: settings);
    }
    if (!mounted) return;

    setState(() {
      _invoiceSettings = settings;
      _templates = merged;
      if (applied != null) _selectedTemplate = applied;
    });
  }

  Future<InvoiceTemplate> _applyCustomisation(
    InvoiceTemplate template, {
    required InvoiceSettings settings,
  }) async {
    final render = await InvoiceRenderService.resolveRenderState(
      template: template,
      invoiceSettings: settings,
    );

    final positions = Map<String, dynamic>.from(render.positions);

    if ((positions['signature_image'] as String?)?.isNotEmpty != true) {
      try {
        final sigBytes = await SignatureService().loadSignatureBytes();
        if (sigBytes != null && sigBytes.isNotEmpty) {
          positions['signature_image'] = base64Encode(sigBytes);
        }
      } catch (_) {}
    }

    _customPositions = positions;
    _backgroundSettings = render.backgroundSettings;

    final hasCustom = render.backgroundSettings.hasCustomImage;
    final hasPreset = render.backgroundSettings.presetId.isNotEmpty &&
        MultiBackgroundPreset.byId(render.backgroundSettings.presetId) != null;

    if (hasCustom) {
      _previewBackground = render.backgroundImage;
    } else if (hasPreset) {
      _previewBackground = null;
    } else {
      _previewBackground = _safeDecode(template.fileData);
    }

    return render.effectiveTemplate;
  }

  static Uint8List? _safeDecode(String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      var raw = data;
      if (raw.startsWith('data:image')) {
        final comma = raw.indexOf(',');
        if (comma == -1) return null;
        raw = raw.substring(comma + 1);
      }
      final b = base64Decode(raw);
      return b.isEmpty ? null : b;
    } catch (_) {
      return null;
    }
  }

  // ── Navigation ──
  Future<void> _openTemplatePicker() async {
    await context.push('/templates/select');
    if (mounted) await _loadTemplates();
  }

  bool _canCustomize() {
    final t = _selectedTemplate;
    if (t == null) return false;
    final auth = context.read<AppAuthProvider>();
    return t.canBeCustomizedBy(
      userId: auth.user?.id ?? '',
      isAdmin: auth.isAdmin,
      hasPremiumAccess:
          context.read<SubscriptionProvider>().canAccessPremiumTemplates,
    );
  }

  Future<void> _openWorkspace() async {
    final t = _selectedTemplate;
    if (t == null) return _openTemplatePicker();
    if (!_canCustomize()) {
      /* ... */ return;
    }
    if (_isReadOnlyForAdmin) {
      /* ... */ return;
    }
    await context.push('/templates/workspace', extra: t);
    if (mounted) {
      // 🔄 Force le reload complet pour refléter les modifications.
      await _loadData();
      await _loadTemplates();
    }
  }

  void _toast(String msg, [Color? color]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color ?? Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Impression / partage ──
  bool _isFreePlan() =>
      !context.read<SubscriptionProvider>().canAccessPremiumTemplates;

  Future<void> _shareInvoice() async {
    if (_invoice == null || _client == null || _company == null) return;
    if (_selectedTemplate == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pdfData = await PrintingService.generateInvoicePdf(
        invoice: _invoice!,
        client: _client!,
        company: _company!,
        template: _selectedTemplate!,
        customPositions: _customPositions,
        customBackground: _backgroundSettings,
        isFreePlan: _isFreePlan(),
        invoiceSettings: _invoiceSettings,
      );
      final fileName =
          '${_invoice!.isDevis ? 'Devis' : 'Facture'}_${_invoice!.invoiceNumber}.pdf';
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(pdfData, mimeType: 'application/pdf', name: fileName),
        ],
        fileNameOverrides: [fileName],
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Erreur de partage: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _previewAndPrint() async {
    if (_invoice == null || _client == null || _company == null) return;
    if (_selectedTemplate == null) return;
    await context.push(
      '/dashboard/invoices/${widget.invoiceId}/print',
      extra: InvoicePrintPreviewArgs(
        invoice: _invoice!,
        client: _client!,
        company: _company!,
        template: _selectedTemplate!,
        customPositions: _customPositions,
        background: _backgroundSettings,
        previewBackground: _previewBackground, // 🆕 AJOUTER CETTE LIGNE
        invoiceSettings: _invoiceSettings,
        isFreePlan: _isFreePlan(),
      ),
    );
  }

  Future<void> _sendEmail() async {
    if (_invoice == null || _client == null || _company == null) return;
    if (_selectedTemplate == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pdf = await PrintingService.generateInvoicePdf(
        invoice: _invoice!,
        client: _client!,
        company: _company!,
        template: _selectedTemplate!,
        customPositions: _customPositions,
        customBackground: _backgroundSettings,
        isFreePlan: _isFreePlan(),
        invoiceSettings: _invoiceSettings,
      );
      final html = MailService.getInvoiceTemplate(
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
        htmlBody: html,
        attachments: [
          EmailAttachment(
            filename: 'facture_${_invoice!.invoiceNumber}.pdf',
            bytes: pdf,
            contentType: 'application/pdf',
          ),
        ],
      );
      if (!mounted) return;
      _toast(sent ? 'Email envoyé avec succès' : 'Erreur lors de l\'envoi',
          sent ? Colors.green : Colors.red);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
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
        appBar: _appBar(c, title: 'Facture introuvable'),
        body: const Center(child: Text('Cette facture n\'existe plus.')),
      );
    }

    return Scaffold(
      backgroundColor: c.surface,
      appBar: _appBar(c,
          title: _invoice!.isDevis ? 'Aperçu Devis' : 'Aperçu Facture'),
      body: Column(
        children: [
          // 🛡️ Bandeau lecture seule si admin sur doc tiers
          if (_isReadOnlyForAdmin)
            AdminReadOnlyBanner(
              documentName: 'Cette facture',
              ownerName: _client?.name,
            ),
          Expanded(
            child: Stack(
              children: [
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
                Positioned(top: 10, right: 16, child: _zoomButton(c)),
              ],
            ),
          ),
          _buildBottomBar(c),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar(RoyalScheme c, {required String title}) {
    return AppBar(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
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
        title,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: c.onSurface,
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: c.onSurface, size: 22),
          onSelected: (v) {
            switch (v) {
              case 'share':
                _shareInvoice();
                break;
              case 'pdf':
                _previewAndPrint();
                break;
              case 'email':
                _sendEmail();
                break;
              case 'picker':
                if (!_isReadOnlyForAdmin) _openTemplatePicker();
                break;
              case 'delete':
                if (!_isReadOnlyForAdmin) _confirmDelete();
                break;
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'share', child: Text('Partager le PDF')),
            const PopupMenuItem(
                value: 'pdf', child: Text('Aperçu / Imprimer PDF')),
            const PopupMenuItem(
                value: 'email', child: Text('Envoyer par email')),
            if (!_isReadOnlyForAdmin)
              const PopupMenuItem(
                  value: 'picker', child: Text('Changer de modèle')),
            if (!_isReadOnlyForAdmin) const PopupMenuDivider(),
            if (!_isReadOnlyForAdmin)
              const PopupMenuItem(
                value: 'delete',
                child: Text('Supprimer',
                    style: TextStyle(color: Colors.redAccent)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInvoicePaper(RoyalScheme c) {
    final tpl = _selectedTemplate;
    final effective = tpl == null
        ? null
        : SettingsService.applyToTemplate(tpl, _invoiceSettings);

    final stitch = StitchPreviewDataX.fromInvoice(
      invoice: _invoice,
      client: _client,
      company: _company,
    );

    return Column(
      children: [
        if (tpl != null) _templateIndicator(c, tpl),
        StitchA4InvoicePreview(
          data: stitch,
          accentColor: effective?.primaryColor,
          pageColor: effective?.backgroundColor,
          showLogo: effective?.showLogo ?? true,
          showBorder: effective?.showBorder ?? false,
          showTaxDetails: effective?.showTaxDetails ?? true,
          showPaymentTerms: effective?.showPaymentTerms ?? true,
          showPaymentQR: effective?.showPaymentQR ?? false,
          fontFamily: effective?.fontFamily ?? 'WorkSans',
          fontScale: (effective?.fontSize ?? 12) / 12,
          layoutConfig: InvoiceLayoutConfig.defaultLayout(),
          backgroundSettings: _backgroundSettings,
          backgroundImage: _previewBackground,
          watermarkText: _invoiceSettings.watermarkText,
          showWatermark: _invoiceSettings.showWatermark,
          showPaidStamp: _invoice?.status == 'paid',
          customPositions: _customPositions,
        ),
      ],
    );
  }

  Widget _templateIndicator(RoyalScheme c, InvoiceTemplate t) {
    return GestureDetector(
      onTap: _isReadOnlyForAdmin ? null : _openTemplatePicker,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: t.primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Modèle : ${t.name}',
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
            Icon(Icons.swap_horiz_rounded, size: 16, color: c.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _zoomButton(RoyalScheme c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.6)),
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

  Widget _zoomIcon(RoyalScheme c, IconData i, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Icon(i, size: 15, color: c.onSurface),
      ),
    );
  }

  Widget _buildBottomBar(RoyalScheme c) {
    final readOnly = _isReadOnlyForAdmin;
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
            onTap: readOnly
                ? null
                : () => context
                        .push('/dashboard/invoices/${widget.invoiceId}/edit')
                        .then((_) {
                      if (mounted) {
                        _loadData();
                        _loadTemplates();
                      }
                    }),
          ),
          _bottomAction(
            c,
            icon: Icons.palette_outlined,
            label: 'Personnaliser',
            onTap: readOnly ? null : _openWorkspace,
          ),
        ],
      ),
    );
  }

  Widget _bottomAction(
    RoyalScheme c, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Icon(icon, size: 20, color: c.inverseOnSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'WorkSans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.inverseOnSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final inv = _invoice;
    if (inv == null) return;

    final uid = context.read<AppAuthProvider>().user?.id ?? '';
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer la facture ?'),
        content: Text(
            'La facture ${inv.invoiceNumber} sera définitivement supprimée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _db.deleteInvoice(inv.id);
      final reminders = await _db.getReminders();
      for (final r in reminders.where((r) => r.invoiceId == inv.id)) {
        await _db.deleteReminder(r.id);
      }
      if (uid.isNotEmpty) {
        await WalletService()
            .deleteInvoiceTransactions(userId: uid, invoiceId: inv.id);
      }
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Facture supprimée'),
        backgroundColor: Colors.green,
      ));
      if (router.canPop()) {
        router.pop(true);
      } else {
        router.go('/invoices');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }
}
