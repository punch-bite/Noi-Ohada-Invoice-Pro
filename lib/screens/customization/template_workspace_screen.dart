// lib/screens/customization/template_workspace_screen.dart
//
// 🎨 Atelier visuel de personnalisation — Design Stitch Refined.
//
// 🔄 v5 — TOUTES les fonctionnalités restaurées + corrections drag & drop :
//   • 📝 Gestion multi-paragraphes accessible depuis l'éditeur de bloc.
//   • ✏️ Édition directe du contenu texte dans le sheet de bloc.
//   • 🔤 Taille de police par bloc (slider 60-180%).
//   • 🎨 Police par bloc (dropdown), couleurs fond/texte.
//   • 📐 Largeur de colonne par bloc (slider).
//   • ✅ Drag & drop header ↔ corps FONCTIONNEL (rebuild garanti).
//   • ✅ Styles PRO (header_style, table_style, footer_style, etc.).
//
// ignore_for_file: dead_null_aware_expression, deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/company.dart';
import '../../models/invoice_layout.dart';
import '../../models/invoice_settings.dart';
import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../services/signature_service.dart';
import '../../services/template_custom_service.dart';
import '../../widgets/template_background_palette.dart';

class TemplateWorkspaceScreen extends StatefulWidget {
  final InvoiceTemplate template;
  const TemplateWorkspaceScreen({super.key, required this.template});

  @override
  State<TemplateWorkspaceScreen> createState() =>
      _TemplateWorkspaceScreenState();
}

class _TemplateWorkspaceScreenState extends State<TemplateWorkspaceScreen>
    with TickerProviderStateMixin {
  // ── 🎨 THÈME ──
  ThemeProvider get _tp => Provider.of<ThemeProvider>(context, listen: false);
  Color get _primary => _tp.primaryColor;
  Color get _bgSurface => _tp.backgroundColor;
  Color get _surfaceVariant => _tp.cardColor;
  Color get _onSurface => _tp.textColor;
  Color get _onSurfaceVariant => _tp.subTextColor;
  Color get _tertiaryContainer => _tp.accentGold;
  Color get _outline => _tp.dividerColor;

  final DatabaseService _db = DatabaseService();
  Company? _company;
  late InvoiceLayoutConfig _layoutConfig;
  late InvoiceTemplate _workingTemplate;
  TemplateBackgroundSettings _background = const TemplateBackgroundSettings();
  InvoiceSettings _invoiceSettings = InvoiceSettings.defaultSettings;

  bool _isLoading = true;
  bool _accessChecked = false;
  bool _canCustomize = false;
  double _zoom = 0.82;
  double _shadowBlur = 24.0;
  double _paperRadius = 14.0;
  double _logoSize = 46.0;
  Uint8List? _customLogoBytes;

  String _selectedCategory = 'Recommandé';
  String _activeTool = '';
  double _customFontSize = 12.0;

  bool _panelCollapsed = false;

  /// 📝 Texte plat par clé (pour compatibilité ascendante).
  final Map<String, String> _customTexts = {};

  /// 📝 Paragraphes structurés (multi-paragraphes + gras/italique/alignement).
  final Map<String, List<_Paragraph>> _paragraphs = {};

  int _textSeq = 0;

  // ✨ Styles PRO
  String _headerStyle = 'flat';
  String _tableStyle = 'plain';
  String _footerStyle = 'simple';
  String _accentBorder = '';
  bool _showThankYou = false;
  String _thankYouText = 'Merci pour votre confiance !';
  String _bankName = '';
  String _bankAccount = '';

  bool _isTextBlock(String key) => _customTexts.containsKey(key);

  String _textBlockTitle(String key) {
    final flat = (_customTexts[key] ?? '').replaceAll('\n', ' ').trim();
    if (flat.isEmpty) return 'Texte libre';
    return flat.length > 18 ? '${flat.substring(0, 18)}…' : flat;
  }

  late List<List<String>> _headerSections;
  List<String> _titleExtraKeys = [];

  List<String> get _headerElements {
    final out = <String>[];
    for (final row in _headerSections) {
      for (final k in row) {
        out.add(k);
      }
    }
    return out;
  }

  static const List<String> _nativeHeaderKeys = [
    'logo',
    'company_info',
    'invoice_title',
  ];
  final Map<String, double> _headerWidth = {};
  final Map<String, TextAlign> _headerAlign = {};

  double _headerWidthOf(String key) =>
      (_headerWidth[key] ?? (key == 'company_info' ? 2.0 : 1.0))
          .clamp(0.4, 3.0);

  int _headerFlexOf(String key) =>
      (_headerWidthOf(key) * 10).round().clamp(4, 30);

  TextAlign _headerAlignOf(String key) =>
      _headerAlign[key] ??
      (key == 'invoice_title' ? TextAlign.right : TextAlign.left);

  final Map<String, bool> _headerVisibility = {};

  bool _headerVisibleOf(String key) => _headerVisibility[key] ?? true;
  String? _draggingHeaderKey;
  String? _dragOverHeaderKey;
  String? _selectedHeaderKey;

  static const int _maxPerSection = 3;
  static const String _emptyColumnKey = 'empty_column';
  List<List<String>> _sectionsLayout = [
    ['billing_info', 'invoice_meta'],
    ['items_table'],
    ['totals'],
    ['legal_mentions', 'signature_block', 'qr_block'],
  ];
  final Map<String, bool> _blockVisibility = {
    'billing_info': true,
    'invoice_meta': true,
    'items_table': true,
    'totals': true,
    'legal_mentions': true,
    'signature_block': true,
    'qr_block': true,
  };
  final Map<String, TextAlign> _blockAlignment = {
    'billing_info': TextAlign.left,
    'invoice_meta': TextAlign.right,
    'items_table': TextAlign.left,
    'totals': TextAlign.right,
    'legal_mentions': TextAlign.left,
    'signature_block': TextAlign.center,
    'qr_block': TextAlign.center,
  };

  /// ✅ LARGEUR DES COLONNES DU CORPS.
  final Map<String, double> _blockWidth = {};

  double _widthOf(String key) => (_blockWidth[key] ?? 1.0).clamp(0.3, 3.0);

  /// ✅ POLICE PAR BLOC.
  final Map<String, String> _blockFonts = {};

  /// ✅ TAILLE DE POLICE PAR BLOC.
  final Map<String, double> _blockFontScales = {};

  double _blockFontScaleOf(String key) =>
      (_blockFontScales[key] ?? 1.0).clamp(0.6, 1.8);

  Widget _wrapBlockTypo(String key, Widget child) {
    var wrapped = child;
    final font = _blockFonts[key];
    if (font != null && font.isNotEmpty) {
      wrapped = DefaultTextStyle(
        style: TextStyle(fontFamily: font),
        child: wrapped,
      );
    }
    final scale = _blockFontScaleOf(key);
    if (scale != 1.0) {
      final mq = MediaQuery.of(context);
      wrapped = MediaQuery(
        data: mq.copyWith(textScaler: TextScaler.linear(scale)),
        child: wrapped,
      );
    }
    return wrapped;
  }

  int _flexOf(String key) => (_widthOf(key) * 10).round().clamp(3, 30);

  /// ✅ COULEUR DE FOND ET DE TEXTE PAR BLOC.
  final Map<String, int> _blockBg = {};
  final Map<String, int> _blockText = {};

  Color? _bgOf(String key) {
    final v = _blockBg[key];
    return (v == null || v == 0) ? null : Color(v);
  }

  Color? _textColorOf(String key) {
    final v = _blockText[key];
    return (v == null || v == 0) ? null : Color(v);
  }

  Widget _tintBlock(String key, Widget child) {
    final bg = _bgOf(key);
    if (bg == null) return child;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bg.withValues(alpha: 0.45), width: 1),
      ),
      child: child,
    );
  }

  String? _draggingKey;
  String? _dragOverKey;
  int? _dragOverSection;
  String? _selectedBlockKey;

  bool _showPaidStamp = true;
  String _stampText = 'PAYÉ';
  final Color _stampColor = const Color(0xFFBAAB6D);
  bool _showSignatureLine = true;
  String _signatoryTitle = 'Direction Générale';

  String _customLegalText =
      'Paiement sous 30 jours net. Pénalités de retard applicables selon normes SYSCOHADA.';
  String _qrPosition = 'totals';

  String _companyName = '';
  String _companyAddress = '';
  String _companyPhone = '';
  String _companyEmail = '';
  String _clientName = 'Client Exemple SARL';
  final String _clientAddress = 'N° RCCM: CM-DOU-2024-B123\nDouala, Cameroun';
  String _invoiceTitleText = 'FACTURE';
  String _invoiceSubtitle = '';

  Uint8List? _signatureImageBytes;

  final List<String> _categories = const [
    'Recommandé',
    'Simple',
    'Classique',
    'Professionnel',
  ];

  final List<Color> _paletteColors = const [
    Color(0xFF300546),
    Color(0xFF4A148C),
    Color(0xFF1E1E2C),
    Color(0xFF0D47A1),
    Color(0xFF004D40),
    Color(0xFFB78103),
    Color(0xFF880E4F),
    Color(0xFF1B5E20),
  ];

  List<InvoiceTemplate> _availableTemplates = [];
  late List<_InvoiceBlock> _invoiceBlocks;

  @override
  void initState() {
    super.initState();
    _headerSections = <List<String>>[
      <String>['logo', 'company_info', 'invoice_title'],
    ];
    _workingTemplate = widget.template;
    _customFontSize = widget.template.fontSize;
    _layoutConfig = InvoiceLayoutConfig.defaultLayout();
    _initBlocks();
    _checkAccess();
    _loadData();
  }

  Future<void> _checkAccess() async {
    final auth = context.read<AppAuthProvider>();
    final sub = context.read<SubscriptionProvider>();
    final allowed = widget.template.canBeCustomizedBy(
      userId: auth.user?.id ?? '',
      isAdmin: auth.isAdmin,
      hasPremiumAccess: sub.canAccessPremiumTemplates,
    );
    if (!mounted) return;
    setState(() {
      _canCustomize = allowed;
      _accessChecked = true;
    });
  }

  void _initBlocks() {
    final Map<String, _InvoiceBlock> allBlocks = {
      'billing_info': _InvoiceBlock(
        key: 'billing_info',
        title: 'Infos Client (Facturé à)',
        builder: _buildBillingInfoBlock,
      ),
      'invoice_meta': _InvoiceBlock(
        key: 'invoice_meta',
        title: 'Méta Facture (N°, Date, Échéance)',
        builder: _buildInvoiceMetaBlock,
      ),
      'items_table': _InvoiceBlock(
        key: 'items_table',
        title: 'Tableau des Articles',
        builder: _buildItemsTableBlock,
      ),
      'totals': _InvoiceBlock(
        key: 'totals',
        title: 'Bloc Totaux (HT, TVA, TTC)',
        builder: _buildTotalsBlock,
      ),
      'legal_mentions': _InvoiceBlock(
        key: 'legal_mentions',
        title: 'Mentions Légales & Conditions',
        builder: _buildLegalMentionsBlock,
      ),
      'signature_block': _InvoiceBlock(
        key: 'signature_block',
        title: 'Ligne de Signature & Cachet',
        builder: _buildSignatureBlock,
      ),
      'qr_block': _InvoiceBlock(
        key: 'qr_block',
        title: 'QR Code de Paiement',
        builder: _buildQRBlock,
      ),
    };

    for (final key in _customTexts.keys) {
      allBlocks[key] = _InvoiceBlock(
        key: key,
        title: _textBlockTitle(key),
        builder: (align) => _buildStaticTextBlock(key, align),
      );
    }

    _invoiceBlocks = allBlocks.values.toList();

    final knownKeys = allBlocks.keys.toSet();
    final seen = <String>{};
    final sections = <List<String>>[];
    for (final section in _sectionsLayout) {
      final cleaned = <String>[];
      for (final key in section) {
        if (key == _emptyColumnKey) {
          if (cleaned.length >= _maxPerSection) continue;
          cleaned.add(key);
          continue;
        }
        if (!knownKeys.contains(key)) continue;
        if (cleaned.length >= _maxPerSection) continue;
        if (seen.add(key)) cleaned.add(key);
      }
      if (cleaned.isNotEmpty) sections.add(cleaned);
    }
    for (final key in knownKeys) {
      if (seen.contains(key)) continue;
      if (_headerElements.contains(key) || _titleExtraKeys.contains(key)) {
        continue;
      }
      if (sections.isEmpty || sections.last.length >= _maxPerSection) {
        sections.add([key]);
      } else {
        sections.last.add(key);
      }
    }
    if (sections.isEmpty) sections.add(<String>[]);
    _sectionsLayout = sections;
  }

  Future<void> _loadData() async {
    final company = await _db.getCompany();
    final loaded = await TemplateCustomService.loadCustom(widget.template.id);

    final mergedPositions = <String, dynamic>{
      ...widget.template.positions,
      ...loaded.positions,
    };

    final templates = InvoiceTemplate.getDefaultTemplates();
    Uint8List? storedSignature;
    try {
      storedSignature = await SignatureService().loadSignatureBytes();
    } catch (_) {
      storedSignature = null;
    }
    if (!mounted) return;

    setState(() {
      _company = company;
      _companyName = company?.name ?? 'Noi Concept digital';
      _companyAddress = company?.address ?? 'Doww Essos Yaoundé Cameroun';
      _companyPhone = company?.phone ?? '+237620409383';
      _companyEmail = company?.email ?? 'contact@noiconcept.com';

      if (mergedPositions.isNotEmpty) {
        _layoutConfig = InvoiceLayoutConfig.fromMap(mergedPositions);

        // ── Header ──
        if (mergedPositions['header_sections'] is List) {
          final raw = mergedPositions['header_sections'] as List;
          final parsed = <List<String>>[];
          for (final r in raw) {
            if (r is List) {
              parsed.add(List<String>.from(r.whereType<String>()));
            }
          }
          if (parsed.isNotEmpty) _headerSections = parsed;
        } else if (mergedPositions['header_elements_order'] is List) {
          _headerSections = [
            List<String>.from(mergedPositions['header_elements_order']),
          ];
        }

        // ── Body sections ──
        if (mergedPositions['blocks_sections'] is List) {
          final decoded =
              InvoiceTemplate.decodeSections(mergedPositions['blocks_sections']);
          if (decoded.isNotEmpty) _sectionsLayout = decoded;
        } else if (mergedPositions['blocks_layout'] is List) {
          _sectionsLayout = [
            for (final s in mergedPositions['blocks_layout'] as List)
              if (s is List)
                List<String>.from(s.whereType<String>())
              else
                <String>[],
          ];
        } else if (mergedPositions['blocks_order'] is List) {
          _sectionsLayout = [
            for (final key
                in (mergedPositions['blocks_order'] as List).whereType<String>())
              [key],
          ];
        }

        // ── Visibility / alignement ──
        if (mergedPositions['block_visibility'] is Map) {
          final Map<String, dynamic> visMap =
              mergedPositions['block_visibility'];
          visMap.forEach((k, v) {
            if (v is bool) _blockVisibility[k] = v;
          });
        }
        if (mergedPositions['block_alignment'] is Map) {
          (mergedPositions['block_alignment'] as Map).forEach((k, v) {
            final key = k.toString();
            for (final t in TextAlign.values) {
              if (t.name == v) _blockAlignment[key] = t;
            }
          });
        }

        // ✅ Largeur des colonnes.
        if (mergedPositions['block_widths'] is Map) {
          (mergedPositions['block_widths'] as Map).forEach((k, v) {
            if (v is num) _blockWidth[k.toString()] = v.toDouble();
          });
        }

        // ✅ Couleur fond.
        if (mergedPositions['block_bg_colors'] is Map) {
          (mergedPositions['block_bg_colors'] as Map).forEach((k, v) {
            if (v is num) _blockBg[k.toString()] = v.toInt();
          });
        }

        // ✅ Couleur texte.
        if (mergedPositions['block_text_colors'] is Map) {
          (mergedPositions['block_text_colors'] as Map).forEach((k, v) {
            if (v is num) _blockText[k.toString()] = v.toInt();
          });
        }

        // ✅ Police par bloc.
        if (mergedPositions['block_fonts'] is Map) {
          (mergedPositions['block_fonts'] as Map).forEach((k, v) {
            if (v is String && v.isNotEmpty) _blockFonts[k.toString()] = v;
          });
        }

        // ✅ Taille police par bloc.
        if (mergedPositions['block_font_scales'] is Map) {
          (mergedPositions['block_font_scales'] as Map).forEach((k, v) {
            if (v is num) {
              _blockFontScales[k.toString()] = (v.toDouble()).clamp(0.6, 1.8);
            }
          });
        }

        // ── Header : largeurs / alignements / visibilité ──
        if (mergedPositions['header_widths'] is Map) {
          (mergedPositions['header_widths'] as Map).forEach((k, v) {
            if (v is num) _headerWidth[k.toString()] = v.toDouble();
          });
        }
        if (mergedPositions['header_alignments'] is Map) {
          (mergedPositions['header_alignments'] as Map).forEach((k, v) {
            final key = k.toString();
            for (final t in TextAlign.values) {
              if (t.name == v) _headerAlign[key] = t;
            }
          });
        }
        if (mergedPositions['header_visibility'] is Map) {
          (mergedPositions['header_visibility'] as Map).forEach((k, v) {
            if (v is bool) _headerVisibility[k.toString()] = v;
          });
        }

        // ── Textes / QR ──
        if (mergedPositions['qr_position'] != null) {
          _qrPosition = mergedPositions['qr_position'] as String;
        }
        if (mergedPositions['custom_legal_text'] != null) {
          _customLegalText = mergedPositions['custom_legal_text'] as String;
        }
        if (mergedPositions['stamp_text'] != null) {
          _stampText = mergedPositions['stamp_text'] as String;
        }
        if (mergedPositions['signatory_title'] != null) {
          _signatoryTitle = mergedPositions['signatory_title'] as String;
        }
        if (mergedPositions['company_name'] != null) {
          _companyName = mergedPositions['company_name'] as String;
        }
        if (mergedPositions['client_name'] != null) {
          _clientName = mergedPositions['client_name'] as String;
        }
        if (mergedPositions['invoice_title_text'] != null) {
          _invoiceTitleText =
              mergedPositions['invoice_title_text'] as String;
        }
        if (mergedPositions['invoice_subtitle'] != null) {
          _invoiceSubtitle = mergedPositions['invoice_subtitle'] as String;
        }
        if (mergedPositions['signature_image'] != null) {
          try {
            _signatureImageBytes =
                base64Decode(mergedPositions['signature_image'] as String);
          } catch (_) {
            _signatureImageBytes = null;
          }
        }
        if (mergedPositions['show_paid_stamp'] != null) {
          _showPaidStamp = mergedPositions['show_paid_stamp'] as bool;
        }
        if (mergedPositions['show_signature_line'] != null) {
          _showSignatureLine =
              mergedPositions['show_signature_line'] as bool;
          _blockVisibility['signature_block'] = _showSignatureLine;
        }
        if (mergedPositions['logo_size'] != null) {
          _logoSize = (mergedPositions['logo_size'] as num).toDouble();
        }
        if (mergedPositions['custom_logo_base64'] != null) {
          try {
            _customLogoBytes = base64Decode(
                mergedPositions['custom_logo_base64'] as String);
          } catch (_) {}
        }

        // ✨ Styles PRO
        if (mergedPositions['header_style'] != null) {
          _headerStyle = mergedPositions['header_style'] as String;
        }
        if (mergedPositions['table_style'] != null) {
          _tableStyle = mergedPositions['table_style'] as String;
        }
        if (mergedPositions['footer_style'] != null) {
          _footerStyle = mergedPositions['footer_style'] as String;
        }
        if (mergedPositions['accent_border'] != null) {
          _accentBorder = mergedPositions['accent_border'] as String;
        }
        if (mergedPositions['show_thank_you'] != null) {
          _showThankYou = mergedPositions['show_thank_you'] as bool;
        }
        if (mergedPositions['thank_you_text'] != null) {
          _thankYouText = mergedPositions['thank_you_text'] as String;
        }
        if (mergedPositions['bank_name'] != null) {
          _bankName = mergedPositions['bank_name'] as String;
        }
        if (mergedPositions['bank_account'] != null) {
          _bankAccount = mergedPositions['bank_account'] as String;
        }
      }

      if (_signatureImageBytes == null || _signatureImageBytes!.isEmpty) {
        if (storedSignature != null && storedSignature.isNotEmpty) {
          _signatureImageBytes = storedSignature;
        }
      }

      // ── Textes libres ──
      if (mergedPositions['custom_texts'] is Map) {
        _customTexts.clear();
        (mergedPositions['custom_texts'] as Map).forEach((k, v) {
          final key = k.toString();
          if (!key.startsWith('text_')) return;
          _customTexts[key] = v?.toString() ?? '';
          final seq = int.tryParse(key.substring('text_'.length));
          if (seq != null && seq > _textSeq) _textSeq = seq;
        });
      }

      // ✅ Paragraphes structurés — AVANT _initBlocks().
      _paragraphs.clear();
      if (mergedPositions['custom_paragraphs'] is Map) {
        final rawParas = mergedPositions['custom_paragraphs'] as Map;
        rawParas.forEach((k, v) {
          if (v is List) {
            _paragraphs[k.toString()] = v
                .whereType<Map>()
                .map((m) => _Paragraph.fromMap(Map<String, dynamic>.from(m)))
                .toList();
          }
        });
        _paragraphs.forEach((key, list) {
          _customTexts[key] = list.map((p) => p.text).join('\n\n');
        });
      }

      _titleExtraKeys = mergedPositions['title_extra_keys'] is List
          ? (mergedPositions['title_extra_keys'] as List)
              .whereType<String>()
              .where((k) => k.startsWith('text_'))
              .toList()
          : <String>[];

      _background = loaded.background;
      _availableTemplates = templates;
      _initBlocks();
      _isLoading = false;
    });

    try {
      final s = await SettingsService.instance.loadSettings();
      if (mounted) setState(() => _invoiceSettings = s);
    } catch (_) {}
  }

  // ── 📝 PARAGRAPHES ──
  List<_Paragraph> _paragraphsOf(String key) {
    if (!_paragraphs.containsKey(key)) {
      final raw = _customTexts[key] ?? '';
      if (raw.isEmpty) {
        _paragraphs[key] = [_Paragraph()];
      } else {
        _paragraphs[key] = raw
            .split('\n\n')
            .map((t) => _Paragraph(text: t.trim()))
            .toList();
      }
    }
    return _paragraphs[key]!;
  }

  void _openQuickPreview() {
    final effective =
        SettingsService.applyToTemplate(_workingTemplate, _invoiceSettings);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF14101A),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                    Expanded(
                      child: Text(
                        'Aperçu rapide — ${_workingTemplate.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _tertiaryContainer.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _tertiaryContainer.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        'DONNÉES D\'EXEMPLE',
                        style: TextStyle(
                          color: _tertiaryContainer,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  maxScale: 2.5,
                  minScale: 0.3,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: AspectRatio(
                      aspectRatio: 794 / 1123,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: effective.showBorder
                              ? Border.all(
                                  color: effective.primaryColor
                                      .withValues(alpha: 0.35),
                                  width: 1.5)
                              : null,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 18,
                                offset: const Offset(0, 8)),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: effective.backgroundColorValue != 0
                                      ? Color(effective.backgroundColorValue)
                                      : Colors.white,
                                ),
                              ),
                            ),
                            if (_background.hasCustomImage ||
                                _background.hasPreset)
                              Positioned.fill(
                                child: TemplateBackgroundLayer(
                                  presetId: _background.presetId,
                                  imageBytes: decodeBackgroundImage(
                                      _background.fileData),
                                  opacity: _background.opacity,
                                  blur: _background.blur,
                                  fit: _background.fit,
                                ),
                              ),
                            Column(children: [
                              _buildCleanInvoiceHeader(),
                              Expanded(
                                child: LayoutBuilder(builder: (_, boxC) {
                                  return SingleChildScrollView(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          minHeight: boxC.maxHeight),
                                      child: _buildCleanInvoiceBody(),
                                    ),
                                  );
                                }),
                              ),
                            ]),
                            if (_showPaidStamp) _buildPaidStamp(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Rendu A4 avec vos personnalisations en cours — '
                  'pincez pour zoomer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveConfig({bool showFeedback = false}) async {
    final updatedPositions = _layoutConfig.toMap();
    updatedPositions['header_elements_order'] = _headerElements;
    updatedPositions['header_sections'] = _headerSections;
    updatedPositions['header_widths'] = Map<String, double>.from(_headerWidth);
    updatedPositions['header_alignments'] =
        _headerAlign.map((k, v) => MapEntry(k, v.name));
    updatedPositions['header_visibility'] =
        Map<String, bool>.from(_headerVisibility);
    updatedPositions['blocks_sections'] = _sectionsLayout;
    updatedPositions['blocks_order'] =
        _sectionsLayout.expand((s) => s).toList();
    updatedPositions['block_visibility'] = _blockVisibility;
    updatedPositions['block_alignment'] =
        _blockAlignment.map((k, v) => MapEntry(k, v.name));
    updatedPositions['block_widths'] = Map<String, double>.from(_blockWidth);
    updatedPositions['block_bg_colors'] = Map<String, int>.from(_blockBg);
    updatedPositions['block_text_colors'] = Map<String, int>.from(_blockText);
    updatedPositions['block_fonts'] = Map<String, String>.from(_blockFonts);
    updatedPositions['block_font_scales'] =
        Map<String, double>.from(_blockFontScales);
    updatedPositions['qr_position'] = _qrPosition;
    updatedPositions['custom_legal_text'] = _customLegalText;
    updatedPositions['stamp_text'] = _stampText;
    updatedPositions['signatory_title'] = _signatoryTitle;
    updatedPositions['show_paid_stamp'] = _showPaidStamp;
    updatedPositions['show_signature_line'] = _showSignatureLine;
    updatedPositions['logo_size'] = _logoSize;
    updatedPositions['company_name'] = _companyName;
    updatedPositions['client_name'] = _clientName;
    updatedPositions['invoice_title_text'] = _invoiceTitleText;
    updatedPositions['invoice_subtitle'] = _invoiceSubtitle;

    // ✨ Styles PRO
    updatedPositions['header_style'] = _headerStyle;
    updatedPositions['table_style'] = _tableStyle;
    updatedPositions['footer_style'] = _footerStyle;
    updatedPositions['accent_border'] = _accentBorder;
    updatedPositions['show_thank_you'] = _showThankYou;
    updatedPositions['thank_you_text'] = _thankYouText;
    updatedPositions['bank_name'] = _bankName;
    updatedPositions['bank_account'] = _bankAccount;

    // 📝 Paragraphes structurés
    final serializedParagraphs = <String, List<Map<String, dynamic>>>{};
    _paragraphs.forEach((key, list) {
      _customTexts[key] = list.map((p) => p.text).join('\n\n');
      serializedParagraphs[key] = list.map((p) => p.toMap()).toList();
    });
    updatedPositions['custom_texts'] = Map<String, String>.from(_customTexts);
    updatedPositions['custom_paragraphs'] = serializedParagraphs;
    updatedPositions['title_extra_keys'] = List<String>.from(_titleExtraKeys);

    if (_signatureImageBytes != null && _signatureImageBytes!.isNotEmpty) {
      updatedPositions['signature_image'] = base64Encode(_signatureImageBytes!);
    }
    if (_customLogoBytes != null) {
      updatedPositions['custom_logo_base64'] = base64Encode(_customLogoBytes!);
    }

    await TemplateCustomService.saveCustom(
      _workingTemplate.id,
      positions: updatedPositions,
      mapping: _workingTemplate.mapping,
      background: _background,
    );

    try {
      final t = _workingTemplate;
      final s = _invoiceSettings;
      final differs = s.primaryColorValue != t.primaryColorValue ||
          s.textColorValue != t.textColorValue ||
          s.backgroundColorValue != t.backgroundColorValue ||
          s.fontFamily != t.fontFamily ||
          s.fontSize != t.fontSize ||
          s.showLogo != t.showLogo ||
          s.showBorder != t.showBorder ||
          s.showTaxDetails != t.showTaxDetails ||
          s.showPaymentTerms != t.showPaymentTerms ||
          s.showPaymentQR != t.showPaymentQR;
      if (differs) {
        _invoiceSettings = await SettingsService.instance
            .updateSettings((cur) => cur.copyWith(
                  primaryColor: t.primaryColor,
                  textColor: t.textColor,
                  backgroundColor: t.backgroundColor,
                  fontFamily: t.fontFamily,
                  fontSize: t.fontSize,
                  showLogo: t.showLogo,
                  showBorder: t.showBorder,
                  showTaxDetails: t.showTaxDetails,
                  showPaymentTerms: t.showPaymentTerms,
                  showPaymentQR: t.showPaymentQR,
                ));
      }
    } catch (e, st) {
      debugPrint('⚠️ Sync InvoiceSettings (atelier) échouée: $e');
      assert(() {
        debugPrintStack(stackTrace: st);
        return true;
      }());
    }

    if (!showFeedback || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('Personnalisation enregistrée !'),
        ]),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _removeFromHeaderSections(String key) {
    for (final row in _headerSections) {
      row.remove(key);
    }
    _headerSections.removeWhere((r) => r.isEmpty);
  }

  void _reorderHeaderElements(String draggedKey, String targetKey) {
    if (draggedKey == targetKey) return;
    setState(() {
      int? fromRow, fromCol;
      for (var r = 0; r < _headerSections.length; r++) {
        final c = _headerSections[r].indexOf(draggedKey);
        if (c != -1) {
          fromRow = r;
          fromCol = c;
          break;
        }
      }
      if (fromRow == null) return;
      _headerSections[fromRow].removeAt(fromCol!);
      int? toRow, toCol;
      for (var r = 0; r < _headerSections.length; r++) {
        final c = _headerSections[r].indexOf(targetKey);
        if (c != -1) {
          toRow = r;
          toCol = c;
          break;
        }
      }
      if (toRow == null) {
        if (_headerSections.isEmpty) {
          _headerSections.add([draggedKey]);
        } else {
          _headerSections.last.add(draggedKey);
        }
      } else {
        _headerSections[toRow].insert(toCol!, draggedKey);
      }
      _draggingHeaderKey = null;
      _dragOverHeaderKey = null;
    });
    _saveConfig();
  }

  void _moveBlock(String key, int targetSection,
      {String? beforeKey, bool newSection = false, int? replaceEmptyAtIndex}) {
    if (newSection && _sectionsLayout.isNotEmpty) {
      final last = _sectionsLayout.last;
      if (last.length == 1 && last.first == key) return;
    }
    setState(() {
      final sourceIdx = _sectionsLayout.indexWhere((s) => s.contains(key));
      List<String>? sourceList;
      var removedIdx = -1;
      if (sourceIdx != -1) {
        sourceList = _sectionsLayout[sourceIdx];
        removedIdx = sourceList.indexOf(key);
      }
      var insertIdx = -1;
      var replaceIdx = -1;
      if (!newSection &&
          targetSection >= 0 &&
          targetSection < _sectionsLayout.length) {
        final list = _sectionsLayout[targetSection];
        if (replaceEmptyAtIndex != null &&
            replaceEmptyAtIndex >= 0 &&
            replaceEmptyAtIndex < list.length &&
            list[replaceEmptyAtIndex] == _emptyColumnKey) {
          replaceIdx = replaceEmptyAtIndex;
          insertIdx = replaceIdx;
        } else {
          insertIdx = beforeKey != null ? list.indexOf(beforeKey) : list.length;
          if (insertIdx == -1) insertIdx = list.length;
        }
      }
      if (sourceIdx != -1) {
        sourceList!.removeAt(removedIdx);
        if (sourceList.isEmpty) {
          _sectionsLayout.removeAt(sourceIdx);
          if (targetSection > sourceIdx) targetSection -= 1;
        }
      }
      if (newSection ||
          targetSection < 0 ||
          targetSection >= _sectionsLayout.length) {
        _sectionsLayout.add([key]);
      } else {
        final list = _sectionsLayout[targetSection];
        if (identical(list, sourceList) && insertIdx > removedIdx) {
          insertIdx -= 1;
        }
        if (insertIdx < 0) insertIdx = 0;
        if (insertIdx > list.length) insertIdx = list.length;
        if (replaceIdx >= 0) {
          if (replaceIdx >= list.length) {
            list.add(key);
          } else {
            list[replaceIdx] = key;
          }
        } else {
          list.insert(insertIdx, key);
        }
      }
      _draggingKey = null;
      _dragOverKey = null;
      _dragOverSection = null;
    });
    _saveConfig();
  }

  void _moveSection(int s, int delta) {
    final target = s + delta;
    if (target < 0 || target >= _sectionsLayout.length) return;
    setState(() {
      final section = _sectionsLayout.removeAt(s);
      _sectionsLayout.insert(target, section);
    });
    _saveConfig();
  }

  /// ✅ Déplace un élément du corps vers l'en-tête — REBUILD GARANTI.
  void _moveBlockToHeader(String key, {String? beforeKey, int? row}) {
    setState(() {
      // 1. Retire du corps (toutes les sections).
      for (final section in _sectionsLayout) {
        section.remove(key);
      }
      _sectionsLayout.removeWhere((s) => s.isEmpty);
      if (_sectionsLayout.isEmpty) _sectionsLayout.add(<String>[]);

      // 2. Retire de l'en-tête (positions précédentes éventuelles).
      _removeFromHeaderSections(key);

      // 3. Force la visibilité.
      _blockVisibility[key] = true;
      _headerVisibility[key] = true;
      _headerWidth.putIfAbsent(key, () => 1.0);
      if (!_headerAlign.containsKey(key)) {
        _headerAlign[key] = TextAlign.left;
      }

      // 4. Insère à la position demandée.
      final targetRow =
          (row != null && row >= 0 && row < _headerSections.length)
              ? row
              : (_headerSections.isEmpty ? -1 : _headerSections.length - 1);
      if (targetRow < 0) {
        _headerSections.add([key]);
      } else {
        final list = _headerSections[targetRow];
        final idx = beforeKey == null ? -1 : list.indexOf(beforeKey);
        if (idx >= 0) {
          list.insert(idx, key);
        } else {
          list.add(key);
        }
      }

      // 5. ✅ REBUILD de la table des blocs (sinon le bloc disparaît).
      _initBlocks();
    });
    _saveConfig();
  }

  /// ✅ Déplace un élément de l'en-tête vers le corps — REBUILD GARANTI.
  void _moveHeaderToBody(String key) {
    // Les clés natives restent dans l'en-tête.
    if (_nativeHeaderKeys.contains(key)) return;

    setState(() {
      // 1. Retire de l'en-tête.
      _removeFromHeaderSections(key);
      _headerVisibility.remove(key);
      _headerWidth.remove(key);
      _headerAlign.remove(key);

      if (_headerSections.isEmpty) {
        _headerSections = [
          List<String>.from(_nativeHeaderKeys),
        ];
      }

      // 2. Force la visibilité du bloc.
      _blockVisibility[key] = true;

      // 3. Ajoute au corps si absent.
      if (!_sectionsLayout.any((s) => s.contains(key))) {
        _sectionsLayout.add(<String>[key]);
      }

      // 4. ✅ REBUILD.
      _initBlocks();
    });
    _saveConfig();
  }

  /// ✅ Retire un texte du titre et le replace dans le corps.
  void _dropUnderTitle(String key) {
    setState(() {
      for (final section in _sectionsLayout) {
        section.remove(key);
      }
      _sectionsLayout.removeWhere((s) => s.isEmpty);
      if (_sectionsLayout.isEmpty) _sectionsLayout.add(<String>[]);
      _removeFromHeaderSections(key);
      _headerVisibility.remove(key);
      _headerWidth.remove(key);
      _headerAlign.remove(key);

      _blockVisibility[key] = true;

      if (!_titleExtraKeys.contains(key)) {
        _titleExtraKeys.add(key);
      }

      if (!_isTextBlock(key) &&
          key != _emptyColumnKey &&
          key.startsWith('text_')) {
        _customTexts.putIfAbsent(key, () => '');
      }
      _initBlocks();
      _draggingKey = null;
      _dragOverKey = null;
      _dragOverSection = null;
    });
    _saveConfig();
  }

  void _removeTextFromTitle(String key) {
    setState(() {
      _titleExtraKeys.remove(key);
      if (!_sectionsLayout.any((s) => s.contains(key))) {
        _sectionsLayout.add(<String>[key]);
      }
      _initBlocks();
    });
    _saveConfig();
  }

  void _showAddUnderTitleSheet() {
    final bodyKeys = _sectionsLayout
        .expand((s) => s)
        .where((k) => k != _emptyColumnKey)
        .where((k) => !_titleExtraKeys.contains(k))
        .toList();
    final headerKeys =
        _headerElements.where((k) => !_titleExtraKeys.contains(k)).toList();
    final freeTexts = _customTexts.keys
        .where((k) => !_titleExtraKeys.contains(k))
        .where((k) => !_headerElements.contains(k))
        .toList();
    final candidates = <String>{...bodyKeys, ...headerKeys, ...freeTexts};

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.vertical_align_top, color: _primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text("Ajouter sous le titre",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              "Créez un texte ou rattachez un bloc existant sous le titre.",
              style: TextStyle(fontSize: 12, color: _onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.notes_outlined, size: 20, color: _primary),
              title: const Text('Nouveau texte libre',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: Text("Créer un texte sous le titre",
                  style: TextStyle(fontSize: 11.5, color: _onSurfaceVariant)),
              trailing: Icon(Icons.chevron_right, size: 20, color: _outline),
              onTap: () {
                Navigator.of(ctx).pop();
                _addTextUnderTitle();
              },
            ),
            if (candidates.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 6),
              const Text("Blocs existants",
                  style:
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final key in candidates)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(
                            _headerElements.contains(key)
                                ? Icons.view_column_outlined
                                : _sectionsLayout.any((s) => s.contains(key))
                                    ? Icons.dashboard_outlined
                                    : Icons.notes_outlined,
                            size: 18,
                            color: _outline,
                          ),
                          title: Text(_blockTitle(key),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          trailing: Icon(Icons.vertical_align_top,
                              size: 18, color: _primary),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _dropUnderTitle(key);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddToHeaderSheet() {
    final bodyKeys = _sectionsLayout
        .expand((s) => s)
        .where((k) =>
            k != _emptyColumnKey &&
            !_headerElements.contains(k) &&
            !_titleExtraKeys.contains(k))
        .toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.add_to_photos_outlined, color: _primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text("Ajouter dans l'en-tête",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              "Ajoutez un texte libre ou déplacez un bloc du corps dans "
              "l'en-tête (nouvelle colonne, à droite du titre).",
              style: TextStyle(fontSize: 12, color: _onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.notes_outlined, size: 20, color: _primary),
              title: const Text('Texte libre',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: Text("Créer un texte dans l'en-tête",
                  style: TextStyle(fontSize: 11.5, color: _onSurfaceVariant)),
              trailing: Icon(Icons.chevron_right, size: 20, color: _outline),
              onTap: () {
                Navigator.of(ctx).pop();
                _addTextToHeader();
              },
            ),
            if (bodyKeys.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 6),
              const Text("Blocs du corps",
                  style:
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final key in bodyKeys)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(Icons.drag_indicator,
                              size: 18, color: _outline),
                          title: Text(_blockTitle(key),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          trailing: Icon(Icons.vertical_align_top,
                              size: 18, color: _primary),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _moveBlockToHeader(key);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _addTextToHeader({int? row}) {
    final key = 'text_${++_textSeq}';
    setState(() {
      _customTexts[key] = '';
      _paragraphs[key] = [_Paragraph()];
      _blockVisibility[key] = true;
      _blockAlignment[key] = TextAlign.left;
      final targetRow =
          (row != null && row >= 0 && row < _headerSections.length)
              ? row
              : (_headerSections.isEmpty ? -1 : _headerSections.length - 1);
      if (targetRow < 0) {
        _headerSections.add([key]);
      } else {
        _headerSections[targetRow].add(key);
      }
      _headerVisibility.putIfAbsent(key, () => true);
      _headerWidth.putIfAbsent(key, () => 1.0);
      _initBlocks();
    });
    _saveConfig();
    _showStaticTextEditorSheet(key);
  }

  void _addHeaderRow() {
    final key = 'text_${++_textSeq}';
    setState(() {
      _customTexts[key] = '';
      _paragraphs[key] = [_Paragraph()];
      _blockVisibility[key] = true;
      _blockAlignment[key] = TextAlign.left;
      _headerSections.add([key]);
      _headerVisibility.putIfAbsent(key, () => true);
      _headerWidth.putIfAbsent(key, () => 1.0);
      _initBlocks();
    });
    _saveConfig();
    _showStaticTextEditorSheet(key);
  }

  void _addHeaderColumn(int row) {
    if (row < 0 || row >= _headerSections.length) return;
    final key = 'text_${++_textSeq}';
    setState(() {
      _customTexts[key] = '';
      _paragraphs[key] = [_Paragraph()];
      _blockVisibility[key] = true;
      _blockAlignment[key] = TextAlign.left;
      _headerSections[row].add(key);
      _headerVisibility.putIfAbsent(key, () => true);
      _headerWidth.putIfAbsent(key, () => 1.0);
      _initBlocks();
    });
    _saveConfig();
    _showStaticTextEditorSheet(key);
  }

  void _addTextUnderTitle() {
    final key = 'text_${++_textSeq}';
    setState(() {
      _customTexts[key] = '';
      _paragraphs[key] = [_Paragraph()];
      _blockVisibility[key] = true;
      _blockAlignment[key] = TextAlign.right;
      _titleExtraKeys.add(key);
      _initBlocks();
    });
    _saveConfig();
    _showStaticTextEditorSheet(key);
  }

  void _addStaticText() {
    final key = 'text_${++_textSeq}';
    setState(() {
      _customTexts[key] = '';
      _paragraphs[key] = [_Paragraph()];
      _blockVisibility[key] = true;
      _blockAlignment[key] = TextAlign.left;
      _initBlocks();
      _sectionsLayout.add(<String>[key]);
    });
    _saveConfig();
    _showStaticTextEditorSheet(key);
  }

  void _removeStaticText(String key) {
    setState(() {
      _customTexts.remove(key);
      _paragraphs.remove(key);
      _blockVisibility.remove(key);
      _blockAlignment.remove(key);
      _blockFonts.remove(key);
      _blockFontScales.remove(key);
      _blockWidth.remove(key);
      _blockBg.remove(key);
      _blockText.remove(key);
      for (final section in _sectionsLayout) {
        section.remove(key);
      }
      _sectionsLayout.removeWhere((s) => s.isEmpty);
      if (_sectionsLayout.isEmpty) _sectionsLayout.add(<String>[]);
      _titleExtraKeys.remove(key);
      _removeFromHeaderSections(key);
      _headerVisibility.remove(key);
      _headerWidth.remove(key);
      _headerAlign.remove(key);
      _initBlocks();
    });
    _saveConfig();
  }

  TextAlign _alignOf(String key) => _blockAlignment[key] ?? TextAlign.left;

  CrossAxisAlignment _ca(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return CrossAxisAlignment.center;
      case TextAlign.right:
      case TextAlign.end:
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.start;
    }
  }

  MainAxisAlignment _ma(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return MainAxisAlignment.center;
      case TextAlign.right:
      case TextAlign.end:
        return MainAxisAlignment.end;
      default:
        return MainAxisAlignment.start;
    }
  }

  Alignment _wa(TextAlign align) {
    switch (align) {
      case TextAlign.right:
      case TextAlign.end:
        return Alignment.centerRight;
      case TextAlign.left:
      case TextAlign.start:
        return Alignment.centerLeft;
      default:
        return Alignment.center;
    }
  }

  List<InvoiceTemplate> _getFilteredTemplates() {
    if (_availableTemplates.isEmpty) return [_workingTemplate];
    switch (_selectedCategory) {
      case 'Recommandé':
        return _availableTemplates
            .where((t) => t.isDefault || t.isPremium)
            .toList();
      case 'Simple':
        return _availableTemplates
            .where((t) => t.category == 'moderne' || !t.isPremium)
            .toList();
      case 'Classique':
        return _availableTemplates
            .where((t) => t.category == 'classique')
            .toList();
      case 'Professionnel':
        return _availableTemplates
            .where((t) => t.isPremium || t.category == 'entreprise')
            .toList();
      default:
        return _availableTemplates;
    }
  }

  Widget _buildAccessDeniedScreen() {
    return Scaffold(
      backgroundColor: _bgSurface,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Atelier Personnalisation',
            style: TextStyle(
                color: _onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _primary.withValues(alpha: 0.08),
                ),
                child:
                    Icon(Icons.lock_outline_rounded, size: 40, color: _primary),
              ),
              const SizedBox(height: 20),
              Text(
                'Personnalisation réservée',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "La personnalisation de ce modèle de facture est réservée à "
                "l'administrateur et au propriétaire du modèle. Acquérez-le "
                "dans la boutique pour le personnaliser.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: _onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/templates'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.storefront, size: 18),
                label: const Text('Voir la boutique'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_accessChecked) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_canCustomize) {
      return _buildAccessDeniedScreen();
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildGlassAppBar(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primary))
          : Column(children: [
              Expanded(child: _buildInvoicePreviewArea()),
              _buildBottomControlPanel(),
            ]),
    );
  }

  PreferredSizeWidget _buildGlassAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.75),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: _onSurface, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Atelier Personnalisation',
                      style: TextStyle(
                        color: _onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Aperçu rapide',
                    icon: Icon(Icons.visibility_outlined,
                        color: _onSurface, size: 20),
                    onPressed: _openQuickPreview,
                  ),
                  Tooltip(
                    message: 'Enregistrer',
                    child: _GlassButton(
                      onPressed: () => _saveConfig(showFeedback: true),
                      padding: const EdgeInsets.all(7),
                      child:
                          const Icon(Icons.save, size: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoicePreviewArea() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: Transform.scale(
            scale: _zoom,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_paperRadius),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: _shadowBlur,
                        spreadRadius: 2,
                        offset: const Offset(0, 8)),
                    BoxShadow(
                        color: _primary.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 2)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(children: [
                  TemplateBackgroundLayer(
                    presetId: _background.presetId,
                    imageBytes: decodeBackgroundImage(_background.fileData),
                    opacity: _background.opacity,
                    blur: _background.blur,
                    fit: _background.fit,
                  ),
                  Column(children: [
                    _buildInvoiceHeader(),
                    _buildDraggableInvoiceBody(),
                    _buildBottomStripe(),
                  ]),
                  if (_showPaidStamp) _buildPaidStamp(),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceHeader() {
    final headerColor = _workingTemplate.primaryColor;

    final rows = <Widget>[];
    for (var r = 0; r < _headerSections.length; r++) {
      rows.add(_buildHeaderRowWidget(r));
    }

    return Container(
      decoration: BoxDecoration(
        color: headerColor,
        border: _draggingKey != null
            ? Border.all(color: Colors.amberAccent, width: 2)
            : null,
      ),
      padding: const EdgeInsets.all(12),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _DotPatternPainter())),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz,
                      color: Colors.white70, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '${_headerElements.length} élément(s) — '
                    '${_headerSections.length} ligne(s) · glissez pour réorganiser',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 8,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            ...rows,
            _buildHeaderAddRowButton(),
            _buildUnderTitleDropZone(),
          ],
        ),
      ]),
    );
  }

  Widget _buildHeaderRowWidget(int r) {
    if (r < 0 || r >= _headerSections.length) {
      return const SizedBox.shrink();
    }
    final rowKeys = _headerSections[r];

    final cells = <Widget>[];
    for (var c = 0; c < rowKeys.length; c++) {
      if (c > 0) cells.add(const SizedBox(width: 4));
      final k = rowKeys[c];
      cells.add(
        Expanded(
          flex: _headerFlexOf(k),
          child: Align(
            alignment: _wa(_headerAlignOf(k)),
            child: Opacity(
              opacity: _headerVisibleOf(k) ? 1.0 : 0.35,
              child: _buildDraggableHeaderElement(k),
            ),
          ),
        ),
      );
    }
    if (rowKeys.length < 6) {
      cells.add(_buildHeaderAddColumnButton(r));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: cells,
      ),
    );
  }

  Widget _buildHeaderAddColumnButton(int r) {
    return Tooltip(
      message: 'Ajouter une colonne à cette ligne',
      child: GestureDetector(
        onTap: () {
          if (r < 0 || r >= _headerSections.length) return;
          _addHeaderColumn(r);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(left: 4),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          ),
          child: Icon(Icons.add,
              size: 14, color: Colors.white.withValues(alpha: 0.9)),
        ),
      ),
    );
  }

  Widget _buildHeaderAddRowButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DragTarget<String>(
          onWillAcceptWithDetails: (d) {
            if (d.data.isEmpty) return false;
            return !_headerElements.contains(d.data);
          },
          onAcceptWithDetails: (d) {
            _moveBlockToHeader(d.data, row: _headerSections.length);
          },
          builder: (ctx, candidate, _) {
            final isOver = candidate.isNotEmpty;
            return GestureDetector(
              onTap: _addHeaderRow,
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(top: 2),
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isOver
                        ? Colors.amberAccent
                        : Colors.white.withValues(alpha: 0.35),
                    width: isOver ? 2 : 1,
                  ),
                  color: isOver
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add,
                        size: 12, color: Colors.white.withValues(alpha: 0.9)),
                    const SizedBox(width: 4),
                    Text(
                      isOver
                          ? 'Déposer pour créer une nouvelle ligne'
                          : 'Ajouter une ligne',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        GestureDetector(
          onTap: _showAddToHeaderSheet,
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_to_photos_outlined,
                    size: 12, color: Colors.white.withValues(alpha: 0.9)),
                const SizedBox(width: 4),
                Text(
                  'Ajouter un bloc ou un texte',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnderTitleDropZone() {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) {
        return !_titleExtraKeys.contains(d.data);
      },
      onAcceptWithDetails: (d) => _dropUnderTitle(d.data),
      onMove: (_) => setState(() => _dragOverSection = -2),
      onLeave: (_) => setState(() => _dragOverSection = null),
      builder: (ctx, candidate, _) {
        final isOver = _dragOverSection == -2;
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isOver
                  ? Colors.white.withValues(alpha: 0.20)
                  : Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: isOver
                    ? Colors.amberAccent
                    : Colors.white.withValues(alpha: 0.35),
                width: isOver ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: _showAddUnderTitleSheet,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOver ? Icons.move_down_rounded : Icons.add,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOver
                        ? 'Déposer ici pour rattacher au titre'
                        : 'Déposer un bloc sous le titre',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCleanInvoiceHeader() {
    final headerColor = _workingTemplate.primaryColor;

    final rowsWidgets = <Widget>[];
    for (var r = 0; r < _headerSections.length; r++) {
      final rowKeys = _headerSections[r];
      final cells = <Widget>[];
      for (var c = 0; c < rowKeys.length; c++) {
        final k = rowKeys[c];
        if (!_headerVisibleOf(k)) continue;
        cells.add(
          Expanded(
            flex: _headerFlexOf(k),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Align(
                alignment: _wa(_headerAlignOf(k)),
                child: _buildHeaderElementContent(k),
              ),
            ),
          ),
        );
      }
      if (cells.isNotEmpty) {
        rowsWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: cells,
            ),
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(color: headerColor),
      padding: const EdgeInsets.all(12),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _DotPatternPainter())),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowsWidgets,
        ),
      ]),
    );
  }

  Widget _buildDraggableCell({
    required String key,
    required Widget content,
    required bool Function(String) acceptDrop,
    required void Function(String) onAcceptDrop,
    double feedbackWidth = 190,
    bool isHeaderContext = false,
  }) {
    final isDragging = _draggingKey == key || _draggingHeaderKey == key;
    final isDragOver = _dragOverKey == key || _dragOverHeaderKey == key;
    final isSelected = _selectedBlockKey == key || _selectedHeaderKey == key;

    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != key && acceptDrop(d.data),
      onAcceptWithDetails: (d) => onAcceptDrop(d.data),
      onMove: (_) => setState(() {
        if (isHeaderContext) {
          _dragOverHeaderKey = key;
        } else {
          _dragOverKey = key;
        }
      }),
      onLeave: (_) => setState(() {
        if (isHeaderContext) {
          _dragOverHeaderKey = null;
        } else {
          _dragOverKey = null;
        }
      }),
      builder: (ctx, candidate, _) {
        return Draggable<String>(
          data: key,
          onDragStarted: () => setState(() {
            if (isHeaderContext) {
              _draggingHeaderKey = key;
            } else {
              _draggingKey = key;
            }
          }),
          onDragEnd: (_) => setState(() {
            _draggingKey = null;
            _draggingHeaderKey = null;
            _dragOverKey = null;
            _dragOverHeaderKey = null;
            _dragOverSection = null;
          }),
          feedback: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(10),
            color: isHeaderContext
                ? _workingTemplate.primaryColor.withValues(alpha: 0.95)
                : Colors.white,
            child: Container(
              width: feedbackWidth,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isHeaderContext
                    ? _workingTemplate.primaryColor.withValues(alpha: 0.95)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isHeaderContext ? Colors.amber : _primary,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Opacity(opacity: 0.9, child: content),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: content),
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (isHeaderContext) {
                  _selectedHeaderKey = key;
                } else {
                  _selectedBlockKey = key;
                }
              });
              if (isHeaderContext) {
                _showHeaderElementSheet(key);
              } else {
                _showElementEditorSheet(key);
              }
            },
            child: isHeaderContext
                ? _wrapHeaderWithIndicator(
                    key,
                    content,
                    isBeingDragged: isDragging,
                    isSelected: isSelected,
                  )
                : _wrapBlockTypo(
                    key,
                    _wrapBlock(
                      _invoiceBlocks.firstWhere(
                        (b) => b.key == key,
                        orElse: () {
                          assert(() {
                            debugPrint(
                                '⚠️ _buildDraggableCell: clé inconnue « $key »');
                            return true;
                          }());
                          return _invoiceBlocks.first;
                        },
                      ),
                      content,
                      isDragOver,
                      isBeingDragged: isDragging,
                      isSelected: isSelected,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildDraggableHeaderElement(String key) {
    return _buildDraggableCell(
      key: key,
      content: _buildHeaderElementContent(key),
      acceptDrop: (data) => data != key,
      onAcceptDrop: (data) => _reorderHeaderElements(data, key),
      feedbackWidth: 220,
      isHeaderContext: true,
    );
  }

  void _showHeaderElementSheet(String key) {
    final title = switch (key) {
      'logo' => 'Logo',
      'company_info' => 'Infos Société',
      'invoice_title' => 'Titre',
      _ => _blockTitle(key),
    };
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.view_column_outlined, color: _primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Colonne « $title »',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15.5)),
                  ),
                ]),
                const SizedBox(height: 4),

                // ✅ Texte libre : édition directe du contenu.
                if (_isTextBlock(key)) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showStaticTextEditorSheet(key);
                    },
                    icon: Icon(Icons.article_outlined,
                        size: 18, color: _primary),
                    label: Text('Éditer le contenu (multi-paragraphes)',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: _primary,
                            fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: _primary.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Afficher cet élément',
                      style: TextStyle(fontSize: 13.5)),
                  subtitle: Text(
                    _headerVisibleOf(key)
                        ? 'Visible sur la facture'
                        : 'Masqué (l\'espace est libéré pour les autres)',
                    style: TextStyle(fontSize: 11.5, color: _onSurfaceVariant),
                  ),
                  value: _headerVisibleOf(key),
                  activeThumbColor: _primary,
                  onChanged: (val) {
                    setState(() => _headerVisibility[key] = val);
                    setSS(() => _headerVisibility[key] = val);
                    _saveConfig();
                  },
                ),
                Row(children: [
                  const Text('Alignement :',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() => _headerAlign[key] = TextAlign.left);
                      setSS(() => _headerAlign[key] = TextAlign.left);
                      _saveConfig();
                    },
                    icon: const Icon(Icons.format_align_left, size: 18),
                    color: _headerAlignOf(key) == TextAlign.left
                        ? _primary
                        : _onSurfaceVariant,
                    constraints: const BoxConstraints(minWidth: 34),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _headerAlign[key] = TextAlign.center);
                      setSS(() => _headerAlign[key] = TextAlign.center);
                      _saveConfig();
                    },
                    icon: const Icon(Icons.format_align_center, size: 18),
                    color: _headerAlignOf(key) == TextAlign.center
                        ? _primary
                        : _onSurfaceVariant,
                    constraints: const BoxConstraints(minWidth: 34),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _headerAlign[key] = TextAlign.right);
                      setSS(() => _headerAlign[key] = TextAlign.right);
                      _saveConfig();
                    },
                    icon: const Icon(Icons.format_align_right, size: 18),
                    color: _headerAlignOf(key) == TextAlign.right
                        ? _primary
                        : _onSurfaceVariant,
                    constraints: const BoxConstraints(minWidth: 34),
                    padding: EdgeInsets.zero,
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Text('Largeur :',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${(_headerWidthOf(key) * 100).round()}%',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: _primary,
                          fontWeight: FontWeight.bold)),
                ]),
                Slider(
                  value: _headerWidthOf(key),
                  min: 0.5,
                  max: 2.5,
                  activeColor: _primary,
                  onChanged: (val) {
                    setState(() => _headerWidth[key] = val);
                    setSS(() => _headerWidth[key] = val);
                    _saveConfig();
                  },
                ),
                if (key == 'invoice_title') ...[
                  const SizedBox(height: 4),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('Éléments sous le titre',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showAddUnderTitleSheet();
                      },
                      icon: Icon(Icons.add, size: 16, color: _primary),
                      label: Text('Ajouter',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: _primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  if (_titleExtraKeys.isEmpty)
                    Text('Aucun élément — ajoutez un texte sous le titre.',
                        style:
                            TextStyle(fontSize: 11.5, color: _onSurfaceVariant))
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 170),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final ek in _titleExtraKeys)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: Icon(
                                  _isTextBlock(ek)
                                      ? Icons.notes_outlined
                                      : Icons.dashboard_outlined,
                                  size: 17,
                                  color: _primary,
                                ),
                                title: Text(_blockTitle(ek),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Modifier',
                                      icon: Icon(Icons.edit_outlined,
                                          size: 17, color: _primary),
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        if (_isTextBlock(ek)) {
                                          _showStaticTextEditorSheet(ek);
                                        } else {
                                          _showElementEditorSheet(ek);
                                        }
                                      },
                                    ),
                                    IconButton(
                                      tooltip: 'Retirer du titre',
                                      icon: const Icon(Icons.close,
                                          size: 17, color: Colors.redAccent),
                                      onPressed: () {
                                        _removeTextFromTitle(ek);
                                        setSS(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (!_nativeHeaderKeys.contains(key))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _moveHeaderToBody(key);
                      },
                      icon: Icon(Icons.vertical_align_bottom,
                          size: 16, color: _primary),
                      label: Text('Replacer dans le corps',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: _primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wrapHeaderWithIndicator(String key, Widget child,
      {bool isBeingDragged = false, bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isBeingDragged
            ? Colors.white.withValues(alpha: 0.15)
            : isSelected
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            top: -2,
            right: -2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.drag_indicator,
                      size: 10, color: Colors.white70),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 12,
                  icon: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.more_vert,
                        size: 10, color: Colors.white70),
                  ),
                  onSelected: (v) {
                    switch (v) {
                      case 'visibility':
                        setState(() =>
                            _headerVisibility[key] = !_headerVisibleOf(key));
                        _saveConfig();
                        break;
                      case 'remove':
                        _moveHeaderToBody(key);
                        break;
                      case 'edit':
                        if (_isTextBlock(key)) {
                          _showStaticTextEditorSheet(key);
                        } else {
                          _showHeaderElementSheet(key);
                        }
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'visibility',
                      child: Text(
                          _headerVisibleOf(key) ? 'Masquer' : 'Afficher'),
                    ),
                    const PopupMenuItem(
                        value: 'edit', child: Text('Modifier')),
                    const PopupMenuItem(
                        value: 'remove', child: Text('Retirer')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderElementContent(String key) {
    final companyName = _companyName.isNotEmpty
        ? _companyName
        : (_company?.name ?? 'Noi Concept digital');
    final initials = companyName.length >= 3
        ? companyName.substring(0, 3).toUpperCase()
        : companyName.toUpperCase();

    switch (key) {
      case 'logo':
        if (!_workingTemplate.showLogo) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              border:
                  Border.all(color: Colors.white38, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_not_supported_outlined,
                    color: Colors.white70, size: 16),
                SizedBox(height: 2),
                Text('Logo masqué',
                    style: TextStyle(color: Colors.white70, fontSize: 8)),
              ],
            ),
          );
        }
        return Container(
          width: _logoSize,
          height: _logoSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.18),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.4), width: 1.5),
          ),
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          child: _customLogoBytes != null
              ? Image.memory(_customLogoBytes!,
                  fit: BoxFit.cover, width: _logoSize, height: _logoSize)
              : Text(initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: (_logoSize * 0.28).clamp(10.0, 18.0),
                  )),
        );

      case 'company_info':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('DE',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: (_customFontSize * 0.7).clamp(7.0, 11.0),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
            Text(companyName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: (_customFontSize * 0.95).clamp(9.0, 14.0))),
            Text(
              '$_companyAddress\n$_companyPhone\n$_companyEmail',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: (_customFontSize * 0.65).clamp(7.0, 10.0),
                  height: 1.3),
            ),
          ],
        );

      case 'invoice_title':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_invoiceTitleText,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: (_customFontSize * 1.35).clamp(13.0, 22.0),
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4)
                  ],
                )),
            if (_invoiceSubtitle.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(_invoiceSubtitle.trim(),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: (_customFontSize * 0.7).clamp(7.5, 11.0),
                      letterSpacing: 0.6,
                    )),
              ),
            if (_qrPosition == 'header' && _workingTemplate.showPaymentQR)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _buildQRCodeWidget(mini: true),
              ),
            for (final ek in _titleExtraKeys)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _buildUnderTitleElement(ek),
              ),
          ],
        );

      default:
        if (_isTextBlock(key)) {
          final paragraphs = _paragraphsOf(key);
          final isEmpty = paragraphs.every((p) => p.text.trim().isEmpty);
          final align = _headerAlignOf(key);
          return GestureDetector(
            onTap: () => _showStaticTextEditorSheet(key),
            child: Container(
              padding: isEmpty
                  ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
                  : EdgeInsets.zero,
              decoration: isEmpty
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    )
                  : null,
              child: isEmpty
                  ? Text(
                      'Tapez ici…',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                        fontSize: (_customFontSize * 0.8).clamp(7.5, 12.5),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final p in paragraphs)
                          if (p.text.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                p.text,
                                textAlign: align,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: (_customFontSize * 0.8)
                                      .clamp(7.5, 12.5),
                                  height: 1.3,
                                  fontWeight: p.bold
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontStyle: p.italic
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              ),
                            ),
                      ],
                    ),
            ),
          );
        }

        final moved = _invoiceBlocks.where((b) => b.key == key).toList();
        if (moved.isNotEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: IconTheme(
              data: IconThemeData(
                  color: Colors.white.withValues(alpha: 0.9), size: 12),
              child: DefaultTextStyle(
                style:
                    TextStyle(color: Colors.white, fontSize: _customFontSize),
                child: moved.first.builder(_headerAlignOf(key)),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
    }
  }

  Widget _buildUnderTitleElement(String key) {
    if (_isTextBlock(key)) {
      final paragraphs = _paragraphsOf(key);
      final isEmpty = paragraphs.every((p) => p.text.trim().isEmpty);
      return GestureDetector(
        onTap: () => _showStaticTextEditorSheet(key),
        child: isEmpty
            ? Text(
                'Tapez ici…',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                  fontSize: (_customFontSize * 0.7).clamp(7.5, 11.0),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final p in paragraphs)
                    if (p.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          p.text,
                          textAlign: p.align == TextAlign.left
                              ? TextAlign.right
                              : p.align,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize:
                                (_customFontSize * 0.7).clamp(7.5, 11.0),
                            height: 1.25,
                            fontWeight:
                                p.bold ? FontWeight.bold : FontWeight.w500,
                            fontStyle: p.italic
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                ],
              ),
      );
    }
    if (key == 'logo' || key == 'company_info') {
      return _buildHeaderElementContent(key);
    }
    final moved = _invoiceBlocks.where((b) => b.key == key).toList();
    if (moved.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: IconTheme(
          data: IconThemeData(
              color: Colors.white.withValues(alpha: 0.9), size: 12),
          child: DefaultTextStyle(
            style: TextStyle(color: Colors.white, fontSize: _customFontSize),
            child: moved.first.builder(_headerAlignOf(key)),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  bool _isBlockVisible(String key) {
    if (!(_blockVisibility[key] ?? true)) return false;
    if (key == 'qr_block') {
      return _workingTemplate.showPaymentQR && _qrPosition == 'standalone';
    }
    return true;
  }

  Widget _buildDraggableInvoiceBody() {
    final children = <Widget>[];
    for (var s = 0; s < _sectionsLayout.length; s++) {
      children.add(_buildSectionRow(s));
    }
    children.add(_buildNewSectionDropZone());

    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildCleanInvoiceBody() {
    final cells = <Widget>[];
    for (final section in _sectionsLayout) {
      final inRow = <Widget>[];
      for (final key in section) {
        if (key == _emptyColumnKey) {
          inRow.add(
              Expanded(flex: _flexOf(key), child: _buildEmptyColumnPreview()));
          continue;
        }
        if (!_isBlockVisible(key)) continue;
        final block = _invoiceBlocks.firstWhere(
          (b) => b.key == key,
          orElse: () {
            assert(() {
              debugPrint('⚠️ _buildCleanInvoiceBody: clé inconnue « $key »');
              return true;
            }());
            return _invoiceBlocks.first;
          },
        );
        inRow.add(Expanded(
            flex: _flexOf(key),
            child: _wrapBlockTypo(
              key,
              _tintBlock(key, block.builder(_alignOf(key))),
            )));
      }
      if (inRow.isNotEmpty) {
        cells.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, children: inRow),
        ));
      }
    }
    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: cells,
      ),
    );
  }

  Widget _buildEmptyColumnPreview() {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.view_week_outlined,
          size: 14,
          color: Colors.grey.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildSectionRow(int s) {
    final rawKeys = _sectionsLayout[s];
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) =>
          !_sectionsLayout[s].contains(d.data) &&
          _sectionsLayout[s].length < _maxPerSection,
      onAcceptWithDetails: (d) => _moveBlock(d.data, s),
      onMove: (_) => setState(() => _dragOverSection = s),
      onLeave: (_) => setState(() => _dragOverSection = null),
      builder: (ctx, candidate, _) {
        final isOver = _dragOverSection == s;
        final cells = <Widget>[];
        for (var i = 0; i < rawKeys.length; i++) {
          final key = rawKeys[i];
          if (key == _emptyColumnKey) {
            cells.add(Expanded(
                flex: _flexOf(key), child: _buildEmptyColumnCell(s, i)));
          } else if (_isBlockVisible(key)) {
            final block = _invoiceBlocks.firstWhere(
              (b) => b.key == key,
              orElse: () {
                assert(() {
                  debugPrint('⚠️ _buildSectionRow: clé inconnue « $key »');
                  return true;
                }());
                return _invoiceBlocks.first;
              },
            );
            cells.add(Expanded(
              flex: _flexOf(key),
              child: _buildBlockCell(block, s),
            ));
          }
        }
        if (cells.isEmpty && _draggingKey != null) {
          cells.add(Expanded(
            child: SizedBox(
              height: 40,
              child: Center(child: Icon(Icons.add, size: 16, color: _outline)),
            ),
          ));
        }
        if (rawKeys.length < _maxPerSection) {
          cells.add(_buildAddEmptyColumnCell(s));
        }

        final rowChildren = <Widget>[];
        for (var i = 0; i < cells.length; i++) {
          if (i > 0) rowChildren.add(const SizedBox(width: 6));
          rowChildren.add(cells[i]);
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isOver
                ? _tertiaryContainer.withValues(alpha: 0.08)
                : Colors.transparent,
            border: Border.all(
              color: isOver ? _tertiaryContainer : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_draggingKey != null)
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 2),
                  child: Text(
                      'Section ${s + 1} · ${_sectionsLayout[s].length}/$_maxPerSection colonnes',
                      style: TextStyle(fontSize: 7.5, color: _outline)),
                ),
              if (_draggingKey == null && _sectionsLayout.length > 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Section ${s + 1}',
                        style: TextStyle(fontSize: 7.5, color: _outline)),
                    const SizedBox(width: 4),
                    _SectionMoveButton(
                      icon: Icons.keyboard_arrow_up,
                      enabled: s > 0,
                      onTap: () => _moveSection(s, -1),
                      color: _outline,
                    ),
                    _SectionMoveButton(
                      icon: Icons.keyboard_arrow_down,
                      enabled: s < _sectionsLayout.length - 1,
                      onTap: () => _moveSection(s, 1),
                      color: _outline,
                    ),
                  ]),
                ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rowChildren,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewSectionDropZone() {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => true,
      onAcceptWithDetails: (d) =>
          _moveBlock(d.data, _sectionsLayout.length, newSection: true),
      onMove: (_) => setState(() => _dragOverSection = -1),
      onLeave: (_) => setState(() => _dragOverSection = null),
      builder: (ctx, candidate, _) {
        final isOver = _dragOverSection == -1;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isOver
                ? _tertiaryContainer.withValues(alpha: 0.08)
                : Colors.transparent,
            border: Border.all(
                color: isOver
                    ? _tertiaryContainer
                    : _surfaceVariant.withValues(alpha: 0.6)),
          ),
          child: InkWell(
            onTap: _addSectionBelow,
            borderRadius: BorderRadius.circular(8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, size: 14, color: _outline),
              const SizedBox(width: 4),
              Text(
                  _draggingKey != null
                      ? 'Nouvelle section (pleine largeur)'
                      : 'Ajouter une rangée de colonnes en dessous',
                  style: TextStyle(fontSize: 9.5, color: _outline)),
            ]),
          ),
        );
      },
    );
  }

  void _addSectionBelow() {
    setState(() => _sectionsLayout.add(<String>[_emptyColumnKey]));
    _saveConfig();
  }

  Widget _buildEmptyColumnCell(int s, int index) {
    final hoverKey = 'empty@$s@$index';
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != _emptyColumnKey,
      onAcceptWithDetails: (d) =>
          _moveBlock(d.data, s, replaceEmptyAtIndex: index),
      onMove: (_) => setState(() => _dragOverKey = hoverKey),
      onLeave: (_) => setState(() => _dragOverKey = null),
      builder: (ctx, candidate, _) {
        final isOver = _dragOverKey == hoverKey;
        return Container(
          constraints: const BoxConstraints(minHeight: 44),
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DashedRectPainter(
                  color: isOver
                      ? _tertiaryContainer
                      : _outline.withValues(alpha: 0.45),
                ),
              ),
            ),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    isOver ? Icons.move_down_rounded : Icons.view_week_outlined,
                    size: 13,
                    color: isOver ? _tertiaryContainer : _outline),
                const SizedBox(height: 2),
                Text(isOver ? 'Placer ici' : 'Vide',
                    style: TextStyle(
                        fontSize: 7, color: _outline, letterSpacing: 0.3)),
              ]),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _removeEmptyColumn(s, index),
                behavior: HitTestBehavior.opaque,
                child: Tooltip(
                  message: 'Supprimer la colonne vide',
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: _outline.withValues(alpha: 0.4), width: 0.8),
                    ),
                    child: Icon(Icons.close, size: 9, color: _outline),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildAddEmptyColumnCell(int s) {
    return Tooltip(
      message: 'Ajouter une colonne vide (scinder la rangée)',
      child: GestureDetector(
        onTap: () => _addEmptyColumn(s),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 30,
          height: 44,
          child: CustomPaint(
            painter: _DashedRectPainter(
                color: _outline.withValues(alpha: 0.35), radius: 6),
            child: Center(child: Icon(Icons.add, size: 13, color: _outline)),
          ),
        ),
      ),
    );
  }

  void _addEmptyColumn(int s) {
    if (s < 0 || s >= _sectionsLayout.length) return;
    if (_sectionsLayout[s].length >= _maxPerSection) return;
    setState(() => _sectionsLayout[s].add(_emptyColumnKey));
    _saveConfig();
  }

  void _removeEmptyColumn(int s, int index) {
    if (s < 0 || s >= _sectionsLayout.length) return;
    final list = _sectionsLayout[s];
    if (index < 0 || index >= list.length) return;
    if (list[index] != _emptyColumnKey) return;
    setState(() {
      list.removeAt(index);
      if (list.isEmpty) _sectionsLayout.removeAt(s);
    });
    _saveConfig();
  }

  Widget _buildBlockCell(_InvoiceBlock block, int section) {
    final align = _alignOf(block.key);
    return _buildDraggableCell(
      key: block.key,
      content: block.builder(align),
      acceptDrop: (data) {
        final sec = _sectionsLayout[section];
        if (sec.contains(data)) return true;
        return sec.length < _maxPerSection;
      },
      onAcceptDrop: (data) => _moveBlock(data, section, beforeKey: block.key),
      feedbackWidth: 190,
      isHeaderContext: false,
    );
  }

  Widget _wrapBlock(_InvoiceBlock block, Widget child, bool isDragOver,
      {bool isBeingDragged = false, bool isSelected = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isBeingDragged
            ? _primary.withValues(alpha: 0.08)
            : isSelected
                ? _primary.withValues(alpha: 0.05)
                : Colors.transparent,
        border: Border.all(
          color: isSelected
              ? _primary
              : isDragOver
                  ? _tertiaryContainer
                  : Colors.transparent,
          width: isSelected ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Tooltip(
                message: 'Glisser pour réordonner ${block.title}',
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.drag_indicator, size: 14, color: _primary),
                ),
              ),
            ),
            Expanded(child: child),
          ]),
          if (isSelected)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 10, color: Colors.white),
                    SizedBox(width: 2),
                    Text(
                      'Modifier',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStaticTextBlock(String key, TextAlign align) {
    final paragraphs = _paragraphsOf(key);
    final isEmpty = paragraphs.every((p) => p.text.trim().isEmpty);

    if (isEmpty) {
      return GestureDetector(
        onTap: () => _showStaticTextEditorSheet(key),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Texte libre — appuyez pour saisir',
            textAlign: align,
            style: TextStyle(
              fontSize: _customFontSize,
              height: 1.35,
              fontStyle: FontStyle.italic,
              color: _onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showStaticTextEditorSheet(key),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: _ca(align),
          children: [
            for (final p in paragraphs)
              if (p.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    p.text,
                    textAlign: p.align,
                    style: TextStyle(
                      fontSize: _customFontSize,
                      height: 1.35,
                      color: _textColorOf(key) ?? _onSurface,
                      fontWeight:
                          p.bold ? FontWeight.bold : FontWeight.normal,
                      fontStyle:
                          p.italic ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingInfoBlock(TextAlign align) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: _ca(align), children: [
        Text('FACTURÉ À',
            textAlign: align,
            style: TextStyle(
                fontSize: (_customFontSize * 0.65).clamp(7.0, 10.0),
                fontWeight: FontWeight.w700,
                color: _onSurfaceVariant,
                letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Text(_clientName,
            textAlign: align,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: (_customFontSize * 0.85).clamp(8.5, 12.0),
                color: _onSurface,
                fontWeight: FontWeight.w600)),
        Text(_clientAddress,
            textAlign: align,
            style: TextStyle(
                fontSize: (_customFontSize * 0.70).clamp(7.0, 10.0),
                color: _onSurfaceVariant)),
      ]),
    );
  }

  Widget _buildInvoiceMetaBlock(TextAlign align) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: _ca(align), children: [
        _metaRow('FACTURE N°', 'INV000342', align),
        const SizedBox(height: 3),
        _metaRow('DATE', '26/03/2025', align),
        const SizedBox(height: 3),
        _metaRow('ÉCHÉANCE', '02/04/2025', align),
      ]),
    );
  }

  Widget _metaRow(String label, String value, TextAlign align) {
    return Row(mainAxisAlignment: _ma(align), children: [
      SizedBox(
          width: 58,
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: (_customFontSize * 0.65).clamp(6.5, 10.0),
                  fontWeight: FontWeight.w700,
                  color: _onSurfaceVariant,
                  letterSpacing: 0.4))),
      const SizedBox(width: 4),
      Flexible(
        child: Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: (_customFontSize * 0.75).clamp(7.5, 11.0),
                color: _onSurface,
                fontWeight: FontWeight.w500)),
      ),
    ]);
  }

  Widget _buildItemsTableBlock(TextAlign align) {
    const descFlex = 5, qtyFlex = 2, priceFlex = 3;
    final cellStyle = TextStyle(
        fontSize: (_customFontSize * 0.72).clamp(6.5, 11.0), color: _onSurface);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _workingTemplate.primaryColor.withValues(alpha: 0.08),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Row(children: [
            Expanded(flex: descFlex, child: _th('Description')),
            Expanded(flex: qtyFlex, child: _th('QTÉ', align: TextAlign.center)),
            Expanded(
                flex: priceFlex, child: _th('Prix HT', align: TextAlign.right)),
            Expanded(
                flex: priceFlex, child: _th('Total', align: TextAlign.right)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            border: Border(
                bottom:
                    BorderSide(color: _surfaceVariant.withValues(alpha: 0.5))),
          ),
          child: Row(children: [
            Expanded(
              flex: descFlex,
              child: Text('Prestation de conseil & Audit informatique',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: cellStyle),
            ),
            Expanded(
              flex: qtyFlex,
              child: Text('1',
                  textAlign: TextAlign.center, maxLines: 1, style: cellStyle),
            ),
            Expanded(
              flex: priceFlex,
              child: Text('150 000',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: cellStyle),
            ),
            Expanded(
              flex: priceFlex,
              child: Text('150 000',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: cellStyle),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _th(String t, {TextAlign align = TextAlign.left}) {
    return Text(t,
        textAlign: align,
        style: TextStyle(
            fontSize: (_customFontSize * 0.65).clamp(7.0, 10.0),
            fontWeight: FontWeight.w700,
            color: _workingTemplate.primaryColor));
  }

  Widget _buildTotalsBlock(TextAlign align) {
    final labelStyle = TextStyle(
        fontSize: (_customFontSize * 0.7).clamp(6.5, 10.5),
        color: _onSurfaceVariant,
        fontWeight: FontWeight.w600);
    final valueStyle = TextStyle(
        fontSize: (_customFontSize * 0.7).clamp(6.5, 10.5), color: _onSurface);
    final totalStyle = TextStyle(
        color: _onSurface,
        fontSize: (_customFontSize * 0.75).clamp(7.0, 11.0),
        fontWeight: FontWeight.w800);

    Widget line(String label, String value, TextStyle l, TextStyle v) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: _ma(align),
          children: [
            Text(label, style: l),
            const SizedBox(width: 6),
            Text(value, style: v),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: _ca(align),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: _ca(align),
            children: [
              line('Sous-Total HT', '150 000 FCFA', labelStyle, valueStyle),
              if (_workingTemplate.showTaxDetails)
                line('TVA (18%)', '27 000 FCFA', labelStyle, valueStyle),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisAlignment: _ma(align),
                  children: [
                    Text('TOTAL TTC', style: totalStyle),
                    const SizedBox(width: 6),
                    Text(
                      _workingTemplate.showTaxDetails
                          ? '177 000 FCFA'
                          : '150 000 FCFA',
                      style: totalStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_qrPosition == 'totals' && _workingTemplate.showPaymentQR)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildQRCodeWidget(),
          ),
      ],
    );
  }

  Widget _buildLegalMentionsBlock(TextAlign align) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: _ca(align), children: [
        Divider(height: 1, color: _surfaceVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 6),
        if (_workingTemplate.showPaymentTerms)
          Text('Conditions & Délais de Paiement',
              textAlign: align,
              style: TextStyle(
                  fontSize: (_customFontSize * 0.65).clamp(7.0, 10.0),
                  fontWeight: FontWeight.w700,
                  color: _onSurface)),
        Text(_customLegalText,
            textAlign: align,
            style: TextStyle(
                fontSize: (_customFontSize * 0.62).clamp(6.5, 9.5),
                color: _onSurfaceVariant,
                height: 1.3)),
        if (_qrPosition == 'footer' && _workingTemplate.showPaymentQR)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _buildQRCodeWidget(),
          ),
      ]),
    );
  }

  Widget _buildSignatureBlock(TextAlign align) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: _ca(align), children: [
        Text('Signature & Cachet',
            textAlign: align,
            style: TextStyle(
                fontSize: (_customFontSize * 0.60).clamp(6.5, 9.0),
                fontWeight: FontWeight.w700,
                color: _onSurfaceVariant)),
        const SizedBox(height: 14),
        Container(
            width: 90,
            height: 1,
            color: _onSurfaceVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 2),
        Text(_signatoryTitle,
            textAlign: align,
            style: TextStyle(
                fontSize: (_customFontSize * 0.55).clamp(6.0, 8.5),
                color: _onSurfaceVariant)),
      ]),
    );
  }

  Widget _buildQRBlock(TextAlign align) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(alignment: _wa(align), child: _buildQRCodeWidget()),
    );
  }

  Widget _buildQRCodeWidget({bool mini = false}) {
    if (mini) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2, size: 20, color: Colors.black87),
            SizedBox(width: 4),
            Text('PAYQR',
                style: TextStyle(
                    color: Colors.black87,
                    fontSize: 7,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _primary.withValues(alpha: 0.2)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.qr_code_2, size: 28, color: Colors.black),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Payer via Mobile Money',
                  style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: _primary)),
              Text('Scanner le QR Code sécurisé',
                  style: TextStyle(fontSize: 7.5, color: _onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaidStamp() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Transform.rotate(
            angle: -0.22,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: _stampColor, width: 3.5),
                borderRadius: BorderRadius.circular(8),
                color: _stampColor.withValues(alpha: 0.08),
              ),
              child: Text(_stampText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFBAAB6D),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomStripe() {
    return Container(
      height: 5,
      decoration: BoxDecoration(color: _workingTemplate.primaryColor),
      child: Row(children: [
        const SizedBox(width: 16),
        Transform(
            transform: Matrix4.skewX(-0.3),
            child: Container(width: 28, color: Colors.white24)),
        const SizedBox(width: 4),
        Transform(
            transform: Matrix4.skewX(-0.3),
            child: Container(width: 14, color: Colors.white24)),
      ]),
    );
  }

  Widget _buildBottomControlPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.75),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildPanelHandle(),
            if (!_panelCollapsed) ...[
              _buildCategoryTabs(),
              _buildTemplateCarousel(),
              Divider(height: 1, color: _surfaceVariant.withValues(alpha: 0.5)),
            ],
            _buildToolBar(),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
          ]),
        ),
      ),
    );
  }

  Widget _buildPanelHandle() {
    return InkWell(
      onTap: () => setState(() => _panelCollapsed = !_panelCollapsed),
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: _outline.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _panelCollapsed
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: _onSurfaceVariant,
            ),
            const SizedBox(width: 2),
            Text(
              _panelCollapsed ? 'Afficher les modèles' : 'Masquer les modèles',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: _onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _categories.map((cat) {
          final isSel = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: isSel ? _primary : Colors.transparent,
                        width: 2.5)),
              ),
              child: Text(cat,
                  style: TextStyle(
                      color: isSel ? _primary : _onSurfaceVariant,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTemplateCarousel() {
    final templates = _getFilteredTemplates();
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: templates.length,
        itemBuilder: (context, i) {
          final t = templates[i];
          final isSel = _workingTemplate.id == t.id;
          return GestureDetector(
            onTap: () => setState(() => _workingTemplate = t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 76,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isSel ? _primary : _outline.withValues(alpha: 0.3),
                    width: isSel ? 2 : 1),
                boxShadow: isSel
                    ? [
                        BoxShadow(
                            color: _primary.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ]
                    : [],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(children: [
                Column(children: [
                  Container(
                    height: 22,
                    decoration: BoxDecoration(color: t.primaryColor),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle)),
                          Container(
                              width: 18, height: 3, color: Colors.white60),
                        ]),
                  ),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.white),
                      padding: const EdgeInsets.all(4),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                width: 32, height: 3, color: Colors.grey[400]),
                            const SizedBox(height: 3),
                            Container(
                                width: 46, height: 2, color: Colors.grey[300]),
                            const SizedBox(height: 4),
                            Container(height: 10, color: Colors.grey[200]),
                            const Spacer(),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Container(
                                  width: 20, height: 5, color: t.primaryColor),
                            ),
                          ]),
                    ),
                  ),
                ]),
                if (t.isPremium)
                  Positioned(
                    top: 3,
                    right: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                          color: _tertiaryContainer,
                          borderRadius: BorderRadius.circular(3)),
                      child: const Text('PRO',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(children: [
        _toolItem(Icons.palette_outlined, 'Couleur', 'couleur',
            _showColorPickerSheet),
        _toolItem(Icons.image_outlined, 'Logo', 'logo', _showLogoSettingsSheet),
        _toolItem(Icons.text_fields_outlined, 'Taille police', 'police',
            _showFontSizeSheet),
        _toolItem(Icons.notes_outlined, 'Textes', 'textes', _showTextsSheet),
        _toolItem(Icons.article_outlined, 'Texte libre', 'texte_libre',
            _showStaticTextsSheet),
        _toolItem(Icons.style_outlined, 'Style', 'style', _showStyleSheet),
        _toolItem(Icons.format_align_left, 'Alignement', 'alignement',
            _showAlignmentSheet),
        _toolItem(Icons.texture_outlined, 'Ombres & Zoom', 'ombres',
            _showShadowSheet),
        _toolItem(
            Icons.draw_outlined, 'Signature', 'signature', _showSignatureSheet,
            badge: _showSignatureLine),
        _toolItem(Icons.gavel_outlined, 'Mentions légales', 'legale',
            _showLegalMentionsSheet),
        _toolItem(
            Icons.qr_code_2_outlined, 'QR Code', 'qrcode', _showQRCodeSheet,
            badge: _workingTemplate.showPaymentQR),
        _toolItem(Icons.wallpaper_outlined, 'Image de fond', 'fond',
            _showBackgroundImageSheet,
            badge: _background.hasCustomImage || _background.hasPreset),
      ]),
    );
  }

  Widget _toolItem(IconData icon, String label, String key, VoidCallback onTap,
      {bool badge = false}) {
    final active = _activeTool == key;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 64,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: active
                    ? _primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 24, color: active ? _primary : _onSurfaceVariant),
            ),
            if (badge)
              Positioned(
                top: -1,
                right: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5)),
                ),
              ),
          ]),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                  fontSize: 9.5,
                  height: 1.1,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  color: active ? _primary : _onSurfaceVariant)),
        ]),
      ),
    );
  }

  // ── TEXTES ──
  void _showTextsSheet() {
    setState(() => _activeTool = 'textes');
    final titleCtrl = TextEditingController(text: _invoiceTitleText);
    final subtitleCtrl = TextEditingController(text: _invoiceSubtitle);
    final companyCtrl = TextEditingController(text: _companyName);
    final clientCtrl = TextEditingController(text: _clientName);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.notes, color: _primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Textes de la facture',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15.5)),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subtitleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Sous-titre',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: companyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom société (aperçu)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clientCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom client (aperçu)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Annuler',
                      style: TextStyle(color: _onSurfaceVariant)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _invoiceTitleText = titleCtrl.text.trim().isNotEmpty
                          ? titleCtrl.text.trim()
                          : 'FACTURE';
                      _invoiceSubtitle = subtitleCtrl.text.trim();
                      _companyName = companyCtrl.text.trim().isNotEmpty
                          ? companyCtrl.text.trim()
                          : _companyName;
                      _clientName = clientCtrl.text.trim().isNotEmpty
                          ? clientCtrl.text.trim()
                          : _clientName;
                    });
                    Navigator.of(ctx).pop();
                    _saveConfig(showFeedback: true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Appliquer'),
                ),
              ]),
            ],
          ),
        ),
      ),
    ).whenComplete(() => setState(() => _activeTool = ''));
  }

  void _showStaticTextsSheet() {
    setState(() => _activeTool = 'texte_libre');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.article_outlined, color: _primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Texte libre',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15.5)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                'Ajoutez du texte statique (mention, note, congés…).',
                style: TextStyle(fontSize: 12, color: _onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              if (_customTexts.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _surfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Aucun texte libre pour le moment.',
                      style:
                          TextStyle(fontSize: 12.5, color: _onSurfaceVariant)),
                )
              else
                ..._customTexts.keys.map((key) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading:
                          Icon(Icons.notes_outlined, size: 18, color: _primary),
                      title: Text(_textBlockTitle(key),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${_paragraphsOf(key).where((p) => p.text.trim().isNotEmpty).length} '
                        'paragraphe(s) — '
                        '${_titleExtraKeys.contains(key) ? 'Sous le titre' : _headerElements.contains(key) ? 'En-tête' : 'Corps'}',
                        style:
                            TextStyle(fontSize: 11, color: _onSurfaceVariant),
                      ),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: 'Modifier',
                          icon: Icon(Icons.edit_outlined,
                              size: 18, color: _primary),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showStaticTextEditorSheet(key);
                          },
                        ),
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.redAccent),
                          onPressed: () {
                            _removeStaticText(key);
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ]),
                    )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _addStaticText();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  label: const Text('Ajouter un texte'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => setState(() => _activeTool = ''));
  }

  /// 📝 Éditeur multi-paragraphes — accessible depuis le sheet de bloc.
  void _showStaticTextEditorSheet(String key) {
    final paragraphs = _paragraphsOf(key);
    final working = paragraphs.map((p) => p.copy()).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) {
          Future<void> apply() async {
            setState(() {
              _paragraphs[key] = working;
              _customTexts[key] = working.map((p) => p.text).join('\n\n');
            });
            await _saveConfig(showFeedback: true);
            if (ctx.mounted) Navigator.of(ctx).pop();
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.article_outlined, color: _primary, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Éditeur multi-paragraphes',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15.5)),
                  ),
                  IconButton(
                    tooltip: 'Ajouter un paragraphe',
                    onPressed: () {
                      setSS(() => working.add(_Paragraph()));
                    },
                    icon: Icon(Icons.add_circle_outline,
                        color: _primary, size: 22),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  '${working.length} paragraphe${working.length > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 11.5, color: _onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < working.length; i++)
                          _buildParagraphEditor(
                            index: i,
                            paragraph: working[i],
                            onChanged: () => setSS(() {}),
                            onRemove: working.length > 1
                                ? () {
                                    setSS(() => working.removeAt(i));
                                  }
                                : null,
                            onMoveUp: i > 0
                                ? () {
                                    setSS(() {
                                      final p = working.removeAt(i);
                                      working.insert(i - 1, p);
                                    });
                                  }
                                : null,
                            onMoveDown: i < working.length - 1
                                ? () {
                                    setSS(() {
                                      final p = working.removeAt(i);
                                      working.insert(i + 1, p);
                                    });
                                  }
                                : null,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _paragraphs[key] = working;
                          _customTexts[key] =
                              working.map((p) => p.text).join('\n\n');
                        });
                        _saveConfig();
                        Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Appliquer'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: apply,
                      style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white),
                      child: const Text('Enregistrer'),
                    ),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildParagraphEditor({
    required int index,
    required _Paragraph paragraph,
    required VoidCallback onChanged,
    VoidCallback? onRemove,
    VoidCallback? onMoveUp,
    VoidCallback? onMoveDown,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('¶ ${index + 1}',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _primary)),
            ),
            const Spacer(),
            if (onMoveUp != null)
              IconButton(
                tooltip: 'Monter',
                onPressed: onMoveUp,
                icon: Icon(Icons.arrow_upward, size: 16, color: _outline),
                constraints: const BoxConstraints(minWidth: 28),
                padding: EdgeInsets.zero,
              ),
            if (onMoveDown != null)
              IconButton(
                tooltip: 'Descendre',
                onPressed: onMoveDown,
                icon: Icon(Icons.arrow_downward, size: 16, color: _outline),
                constraints: const BoxConstraints(minWidth: 28),
                padding: EdgeInsets.zero,
              ),
            if (onRemove != null)
              IconButton(
                tooltip: 'Supprimer',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: Colors.redAccent),
                constraints: const BoxConstraints(minWidth: 28),
                padding: EdgeInsets.zero,
              ),
          ]),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: paragraph.text,
            maxLines: null,
            minLines: 2,
            onChanged: (v) {
              paragraph.text = v;
              onChanged();
            },
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Saisissez votre paragraphe…',
              hintStyle:
                  TextStyle(fontSize: 12.5, color: _onSurfaceVariant),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _outline),
              ),
            ),
            style: TextStyle(
              fontSize: 13,
              color: _onSurface,
              fontWeight:
                  paragraph.bold ? FontWeight.bold : FontWeight.normal,
              fontStyle:
                  paragraph.italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            FilterChip(
              label: const Text('Gras', style: TextStyle(fontSize: 11)),
              selected: paragraph.bold,
              onSelected: (v) {
                paragraph.bold = v;
                onChanged();
              },
            ),
            FilterChip(
              label: const Text('Italique', style: TextStyle(fontSize: 11)),
              selected: paragraph.italic,
              onSelected: (v) {
                paragraph.italic = v;
                onChanged();
              },
            ),
            _alignChip(paragraph, TextAlign.left, Icons.format_align_left,
                onChanged),
            _alignChip(paragraph, TextAlign.center, Icons.format_align_center,
                onChanged),
            _alignChip(paragraph, TextAlign.right, Icons.format_align_right,
                onChanged),
          ]),
        ],
      ),
    );
  }

  Widget _alignChip(_Paragraph p, TextAlign align, IconData icon,
      VoidCallback onChanged) {
    final selected = p.align == align;
    return GestureDetector(
      onTap: () {
        p.align = align;
        onChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? _primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _primary : _outline.withValues(alpha: 0.5),
          ),
        ),
        child: Icon(icon,
            size: 14, color: selected ? _primary : _onSurfaceVariant),
      ),
    );
  }

  String _blockTitle(String key) {
    if (key == _emptyColumnKey) return 'Colonne vide';
    if (_isTextBlock(key)) return _textBlockTitle(key);
    for (final b in _invoiceBlocks) {
      if (b.key == key) return b.title;
    }
    return key;
  }

  /// ✅ ÉDITEUR DE BLOC : tous les contrôles + édition texte intégrée.
  void _showElementEditorSheet(String key) {
    final clientCtrl = TextEditingController(text: _clientName);
    final signatoryCtrl = TextEditingController(text: _signatoryTitle);
    final legalCtrl = TextEditingController(text: _customLegalText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Titre ──
                Row(children: [
                  Icon(Icons.tune, color: _primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_blockTitle(key),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15.5)),
                  ),
                ]),
                const SizedBox(height: 6),

                // ✅ TEXTE LIBRE : édition du contenu + paragraphes.
                if (_isTextBlock(key)) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _surfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _outline.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.article_outlined,
                              size: 16, color: _primary),
                          const SizedBox(width: 6),
                          Text(
                            'Contenu du texte',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _onSurface,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        // Aperçu du contenu actuel.
                        Text(
                          _customTexts[key]?.trim().isEmpty == true
                              ? '(vide)'
                              : _customTexts[key] ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: _customTexts[key]?.trim().isEmpty ==
                                    true
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: _onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _showStaticTextEditorSheet(key);
                            },
                            icon: Icon(Icons.edit_note,
                                size: 18, color: _primary),
                            label: Text(
                              'Éditer (multi-paragraphes)',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: _primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: _primary.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── Visibilité ──
                if (key != 'qr_block')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Afficher ce bloc',
                        style: TextStyle(fontSize: 13.5)),
                    value: _blockVisibility[key] ?? true,
                    activeThumbColor: _primary,
                    onChanged: (val) {
                      setState(() {
                        _blockVisibility[key] = val;
                        if (key == 'signature_block') {
                          _showSignatureLine = val;
                        }
                      });
                      setSS(() {
                        _blockVisibility[key] = val;
                      });
                      _saveConfig();
                    },
                  ),

                // ── Police ──
                const SizedBox(height: 4),
                Row(children: [
                  const Text('Police :',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _blockFonts[key] ?? '',
                      isDense: true,
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(ctx).colorScheme.onSurface,
                          fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(
                            value: '', child: Text('Défaut (modèle)')),
                        DropdownMenuItem(
                            value: 'WorkSans', child: Text('Work Sans')),
                        DropdownMenuItem(
                            value: 'Manrope', child: Text('Manrope')),
                        DropdownMenuItem(
                            value: 'Roboto', child: Text('Roboto')),
                      ],
                      onChanged: (val) {
                        final font = (val == null || val.isEmpty) ? '' : val;
                        setState(() {
                          if (font.isEmpty) {
                            _blockFonts.remove(key);
                          } else {
                            _blockFonts[key] = font;
                          }
                        });
                        setSS(() {
                          if (font.isEmpty) {
                            _blockFonts.remove(key);
                          } else {
                            _blockFonts[key] = font;
                          }
                        });
                        _saveConfig();
                      },
                    ),
                  ),
                ]),

                // ── Taille de police par bloc ──
                Row(children: [
                  const Text('Taille de police :',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${(_blockFontScaleOf(key) * 100).round()}%',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: _primary,
                          fontWeight: FontWeight.bold)),
                ]),
                Slider(
                  value: _blockFontScaleOf(key),
                  min: 0.6,
                  max: 1.8,
                  divisions: 12,
                  activeColor: _primary,
                  label: '${(_blockFontScaleOf(key) * 100).round()}%',
                  onChanged: (val) {
                    setState(() => _blockFontScales[key] = val);
                    setSS(() => _blockFontScales[key] = val);
                    _saveConfig();
                  },
                ),

                // ── Alignement ──
                Row(children: [
                  const Text('Alignement :',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() => _blockAlignment[key] = TextAlign.left);
                      setSS(() => _blockAlignment[key] = TextAlign.left);
                      _saveConfig();
                    },
                    icon: const Icon(Icons.format_align_left, size: 18),
                    color: _alignOf(key) == TextAlign.left
                        ? _primary
                        : _onSurfaceVariant,
                    constraints: const BoxConstraints(minWidth: 34),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _blockAlignment[key] = TextAlign.center);
                      setSS(() => _blockAlignment[key] = TextAlign.center);
                      _saveConfig();
                    },
                    icon: const Icon(Icons.format_align_center, size: 18),
                    color: _alignOf(key) == TextAlign.center
                        ? _primary
                        : _onSurfaceVariant,
                    constraints: const BoxConstraints(minWidth: 34),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _blockAlignment[key] = TextAlign.right);
                      setSS(() => _blockAlignment[key] = TextAlign.right);
                      _saveConfig();
                    },
                    icon: const Icon(Icons.format_align_right, size: 18),
                    color: _alignOf(key) == TextAlign.right
                        ? _primary
                        : _onSurfaceVariant,
                    constraints: const BoxConstraints(minWidth: 34),
                    padding: EdgeInsets.zero,
                  ),
                ]),

                // ── Déplacer / Retirer ──
                const SizedBox(height: 6),
                if (_titleExtraKeys.contains(key))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _removeTextFromTitle(key);
                      },
                      icon: Icon(Icons.vertical_align_bottom,
                          size: 16, color: _primary),
                      label: Text('Replacer dans le corps',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: _primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  )
                else if (!_nativeHeaderKeys.contains(key) &&
                    _headerElements.contains(key))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _moveHeaderToBody(key);
                      },
                      icon: Icon(Icons.vertical_align_bottom,
                          size: 16, color: _primary),
                      label: Text('Replacer dans le corps',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: _primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  )
                else if (!_nativeHeaderKeys.contains(key))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PopupMenuButton<String>(
                      tooltip: 'Déplacer ce bloc vers l\'en-tête',
                      color: Theme.of(ctx).colorScheme.surface,
                      onSelected: (val) {
                        Navigator.of(ctx).pop();
                        switch (val) {
                          case 'header_first':
                            _moveBlockToHeader(key, beforeKey: 'logo');
                            break;
                          case 'header_after_logo':
                            _moveBlockToHeader(key, beforeKey: 'company_info');
                            break;
                          case 'under_title':
                            _dropUnderTitle(key);
                            break;
                          default:
                            _moveBlockToHeader(key);
                            break;
                        }
                      },
                      itemBuilder: (c) => const [
                        PopupMenuItem(
                            value: 'header_first',
                            child: Text('En-tête — avant le logo')),
                        PopupMenuItem(
                            value: 'header_after_logo',
                            child: Text('En-tête — après le logo')),
                        PopupMenuItem(
                            value: 'under_title', child: Text('Sous le titre')),
                      ],
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.vertical_align_top,
                            size: 16, color: _primary),
                        const SizedBox(width: 4),
                        Text('Déplacer vers l\'en-tête',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: _primary,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                if (_isTextBlock(key))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _removeStaticText(key);
                      },
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: Colors.redAccent),
                      label: const Text('Supprimer ce texte',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),

                // ── Largeur de colonne ──
                const SizedBox(height: 8),
                Row(children: [
                  const Text('Largeur de colonne :',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${(_widthOf(key) * 100).round()}%',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: _primary,
                          fontWeight: FontWeight.bold)),
                ]),
                Slider(
                  value: _widthOf(key),
                  min: 0.5,
                  max: 2.5,
                  divisions: 20,
                  activeColor: _primary,
                  label: '${(_widthOf(key) * 100).round()}%',
                  onChanged: (val) {
                    setState(() => _blockWidth[key] = val);
                    setSS(() => _blockWidth[key] = val);
                    _saveConfig();
                  },
                ),

                // ── Couleur du fond ──
                const SizedBox(height: 6),
                const Text('Couleur du fond :',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  _colorChip(null, _bgOf(key) == null, () {
                    setState(() => _blockBg[key] = 0);
                    setSS(() => _blockBg[key] = 0);
                    _saveConfig();
                  }),
                  for (final c in _paletteColors)
                    _colorChip(c, _blockBg[key] == c.toARGB32(), () {
                      setState(() => _blockBg[key] = c.toARGB32());
                      setSS(() => _blockBg[key] = c.toARGB32());
                      _saveConfig();
                    }),
                ]),

                // ── Couleur du texte ──
                const SizedBox(height: 10),
                const Text('Couleur du texte :',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  _colorChip(null, _textColorOf(key) == null, () {
                    setState(() => _blockText[key] = 0);
                    setSS(() => _blockText[key] = 0);
                    _saveConfig();
                  }),
                  for (final c in [
                    Colors.black,
                    Colors.white,
                    ..._paletteColors,
                  ])
                    _colorChip(c, _blockText[key] == c.toARGB32(), () {
                      setState(() => _blockText[key] = c.toARGB32());
                      setSS(() => _blockText[key] = c.toARGB32());
                      _saveConfig();
                    }),
                ]),

                // ── Champs spécifiques ──
                if (key == 'billing_info') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: clientCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom du client',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() => _clientName = val);
                      _saveConfig();
                    },
                  ),
                ],
                if (key == 'signature_block') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: signatoryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Titre du signataire',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() => _signatoryTitle = val);
                      _saveConfig();
                    },
                  ),
                ],
                if (key == 'legal_mentions') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: legalCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Texte des mentions légales',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() => _customLegalText = val);
                      _saveConfig();
                    },
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _colorChip(Color? color, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color ?? Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? _primary : _outline.withValues(alpha: 0.5),
            width: selected ? 3 : 1.2,
          ),
        ),
        child: color == null
            ? Icon(Icons.block, size: 14, color: _outline)
            : (selected
                ? Icon(Icons.check,
                    size: 16,
                    color: color.computeLuminance() > 0.55
                        ? Colors.black
                        : Colors.white)
                : null),
      ),
    );
  }

  void _showStyleSheet() {
    setState(() => _activeTool = 'style');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.style_outlined, color: _primary, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Style du modèle',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15.5)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  "Personnalisez le style d'en-tête, de tableau et de pied de page.",
                  style: TextStyle(fontSize: 12, color: _onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                _styleSectionTitle('En-tête'),
                _styleChoices<String>(
                  current: _headerStyle,
                  options: const [
                    ('flat', 'Plat'),
                    ('band', 'Bandeau coloré'),
                    ('bar', 'Barre haute'),
                    ('dark', 'Sombre'),
                    ('zigzag', 'Zigzag'),
                  ],
                  onChanged: (v) {
                    setSS(() => _headerStyle = v);
                    setState(() {});
                    _saveConfig();
                  },
                ),
                const SizedBox(height: 14),
                _styleSectionTitle('Tableau des articles'),
                _styleChoices<String>(
                  current: _tableStyle,
                  options: const [
                    ('plain', 'Simple'),
                    ('zebra', 'Zébré'),
                    ('cards', 'Cartes'),
                    ('numbered', 'Numéroté'),
                  ],
                  onChanged: (v) {
                    setSS(() => _tableStyle = v);
                    setState(() {});
                    _saveConfig();
                  },
                ),
                const SizedBox(height: 14),
                _styleSectionTitle('Pied de page'),
                _styleChoices<String>(
                  current: _footerStyle,
                  options: const [
                    ('simple', 'Simple'),
                    ('contact', 'Contact'),
                    ('banner', 'Bandeau'),
                    ('icons', 'Icônes'),
                  ],
                  onChanged: (v) {
                    setSS(() => _footerStyle = v);
                    setState(() {});
                    _saveConfig();
                  },
                ),
                const SizedBox(height: 14),
                _styleSectionTitle('Bordure décorative'),
                _styleChoices<String>(
                  current: _accentBorder,
                  options: const [
                    ('', 'Aucune'),
                    ('top', 'Haut'),
                    ('left', 'Gauche'),
                    ('frame', 'Cadre'),
                  ],
                  onChanged: (v) {
                    setSS(() => _accentBorder = v);
                    setState(() {});
                    _saveConfig();
                  },
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Afficher « Merci pour votre confiance »',
                      style: TextStyle(fontSize: 13.5)),
                  value: _showThankYou,
                  activeThumbColor: _primary,
                  onChanged: (v) {
                    setSS(() => _showThankYou = v);
                    setState(() {});
                    _saveConfig();
                  },
                ),
                if (_showThankYou)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: TextFormField(
                      initialValue: _thankYouText,
                      decoration: const InputDecoration(
                        labelText: 'Texte de remerciement',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        _thankYouText = v;
                        _saveConfig();
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                _styleSectionTitle('Infos bancaires'),
                TextFormField(
                  initialValue: _bankName,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la banque',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    _bankName = v;
                    _saveConfig();
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: _bankAccount,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de compte',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    _bankAccount = v;
                    _saveConfig();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => setState(() => _activeTool = ''));
  }

  Widget _styleSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: _onSurface,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _styleChoices<T>({
    required T current,
    required List<(T, String)> options,
    required ValueChanged<T> onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          GestureDetector(
            onTap: () => onChanged(value),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: value == current
                    ? _primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: value == current
                      ? _primary
                      : _outline.withValues(alpha: 0.5),
                  width: value == current ? 2 : 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      value == current ? FontWeight.w700 : FontWeight.w500,
                  color: value == current ? _primary : _onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showColorPickerSheet() {
    setState(() => _activeTool = 'couleur');
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Palette de Couleur Principale',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _paletteColors.map((color) {
                    final isSel = _workingTemplate.primaryColor == color;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _workingTemplate = InvoiceTemplate(
                            id: _workingTemplate.id,
                            name: _workingTemplate.name,
                            description: _workingTemplate.description,
                            primaryColor: color,
                            textColor: _workingTemplate.textColor,
                            backgroundColor: _workingTemplate.backgroundColor,
                            showLogo: _workingTemplate.showLogo,
                            showTaxDetails: _workingTemplate.showTaxDetails,
                            showPaymentTerms: _workingTemplate.showPaymentTerms,
                            showPaymentQR: _workingTemplate.showPaymentQR,
                            isPremium: _workingTemplate.isPremium,
                            category: _workingTemplate.category,
                            price: _workingTemplate.price,
                          );
                        });
                        setSS(() {});
                        _saveConfig();
                      },
                      child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      isSel ? Colors.black : Colors.transparent,
                                  width: isSel ? 3.5 : 0)),
                          child: isSel
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 22)
                              : null),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
              ]),
        ),
      ),
    ).whenComplete(() => setState(() => _activeTool = ''));
  }

  void _showLogoSettingsSheet() {
    setState(() => _activeTool = 'logo');
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Réglages du Logo d'Entreprise",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text("Afficher le Logo"),
                  value: _workingTemplate.showLogo,
                  activeThumbColor: _primary,
                  onChanged: (val) {
                    setState(() {
                      _workingTemplate = InvoiceTemplate(
                        id: _workingTemplate.id,
                        name: _workingTemplate.name,
                        description: _workingTemplate.description,
                        primaryColor: _workingTemplate.primaryColor,
                        textColor: _workingTemplate.textColor,
                        backgroundColor: _workingTemplate.backgroundColor,
                        showLogo: val,
                        showTaxDetails: _workingTemplate.showTaxDetails,
                        showPaymentTerms: _workingTemplate.showPaymentTerms,
                        showPaymentQR: _workingTemplate.showPaymentQR,
                        isPremium: _workingTemplate.isPremium,
                      );
                    });
                    setSS(() {});
                    _saveConfig();
                  },
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('Taille du logo: '),
                  Expanded(
                    child: Slider(
                      value: _logoSize,
                      min: 32,
                      max: 72,
                      divisions: 10,
                      activeColor: _primary,
                      onChanged: (val) {
                        setState(() => _logoSize = val);
                        setSS(() => _logoSize = val);
                        _saveConfig();
                      },
                    ),
                  ),
                  Text('${_logoSize.toInt()} px'),
                ]),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final picked =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      final bytes = await picked.readAsBytes();
                      setState(() => _customLogoBytes = bytes);
                      _saveConfig();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Nouveau logo téléversé !')));
                      }
                    }
                  },
                  icon: Icon(Icons.upload_file, color: _primary),
                  label: Text('Téléverser un logo (PNG / JPEG)',
                      style: TextStyle(color: _primary)),
                ),
                const SizedBox(height: 16),
              ]),
        ),
      ),
    ).whenComplete(() => setState(() => _activeTool = ''));
  }

  void _showFontSizeSheet() {
    setState(() => _activeTool = 'police');
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Taille de Police Globale',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${_customFontSize.toInt()} pt',
                          style: TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ]),
                const SizedBox(height: 14),
                Slider(
                  value: _customFontSize.clamp(9.0, 20.0),
                  min: 9,
                  max: 20,
                  divisions: 11,
                  activeColor: _primary,
                  onChanged: (val) {
                    setState(() {
                      _customFontSize = val;
                      _workingTemplate = InvoiceTemplate(
                        id: _workingTemplate.id,
                        name: _workingTemplate.name,
                        description: _workingTemplate.description,
                        primaryColor: _workingTemplate.primaryColor,
                        textColor: _workingTemplate.textColor,
                        backgroundColor: _workingTemplate.backgroundColor,
                        showLogo: _workingTemplate.showLogo,
                        showTaxDetails: _workingTemplate.showTaxDetails,
                        showPaymentTerms: _workingTemplate.showPaymentTerms,
                        showPaymentQR: _workingTemplate.showPaymentQR,
                        fontSize: val,
                        isPremium: _workingTemplate.isPremium,
                      );
                    });
                    setSS(() => _customFontSize = val);
                    _saveConfig();
                  },
                ),
                const SizedBox(height: 16),
              ]),
        ),
      ),
    ).whenComplete(() => setState(() => _activeTool = ''));
  }

  void _showShadowSheet() {
    setState(() => _activeTool = 'ombres');
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Style & Zoom du Canevas A4",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 14),
                Row(children: [
                  const SizedBox(width: 120, child: Text('Zoom de la page: ')),
                  Expanded(
                      child: Slider(
                    value: _zoom,
                    min: 0.5,
                    max: 1.1,
                    divisions: 12,
                    activeColor: _primary,
                    onChanged: (val) {
                      setState(() => _zoom = val);
                      setSS(() => _zoom = val);
                    },
                  )),
                  Text('${(_zoom * 100).toInt()}%'),
                ]),
                Row(children: [
                  const SizedBox(
                      width: 120, child: Text('Intensité d\'ombre: ')),
                  Expanded(
                      child: Slider(
                    value: _shadowBlur,
                    min: 4,
                    max: 40,
                    divisions: 18,
                    activeColor: _primary,
                    onChanged: (val) {
                      setState(() => _shadowBlur = val);
                      setSS(() => _shadowBlur = val);
                    },
                  )),
                  Text('${_shadowBlur.toInt()}px'),
                ]),
                Row(children: [
                  const SizedBox(width: 120, child: Text('Arrondi feuille: ')),
                  Expanded(
                      child: Slider(
                    value: _paperRadius,
                    min: 0,
                    max: 24,
                    divisions: 12,
                    activeColor: _primary,
                    onChanged: (val) {
                      setState(() => _paperRadius = val);
                      setSS(() => _paperRadius = val);
                    },
                  )),
                  Text('${_paperRadius.toInt()}px'),
                ]),
                const SizedBox(height: 16),
              ]),
        ),
      ),
    ).whenComplete(() => setState(() => _activeTool = ''));
  }

  void _showAlignmentSheet() {
    setState(() => _activeTool = 'alignement');
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alignement des blocs',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text(
                      'Alignement du contenu de chaque bloc. Astuce : glissez-déposez '
                      'les blocs sur la facture.',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 14),
                  ..._sectionsLayout
                      .expand((s) => s)
                      .where((key) => key != _emptyColumnKey)
                      .where(_isBlockVisible)
                      .map((key) => _alignmentRow(key, setSS)),
                  if (_headerElements.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    const Text("Colonnes de l'en-tête",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    for (final key in _headerElements)
                      _headerAlignmentRow(key, setSS),
                  ],
                  const SizedBox(height: 10),
                ]),
          ),
        ),
      ),
    ).whenComplete(() => setState(() => _activeTool = ''));
  }

  Widget _headerAlignmentRow(String key, void Function(void Function()) setSS) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
          child: Text(
              key == _emptyColumnKey ? 'Colonne vide' : _blockTitle(key),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        SegmentedButton<TextAlign>(
          segments: const [
            ButtonSegment(
                value: TextAlign.left,
                icon: Icon(Icons.format_align_left, size: 16)),
            ButtonSegment(
                value: TextAlign.center,
                icon: Icon(Icons.format_align_center, size: 16)),
            ButtonSegment(
                value: TextAlign.right,
                icon: Icon(Icons.format_align_right, size: 16)),
          ],
          selected: {_headerAlignOf(key)},
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onSelectionChanged: (sel) {
            setState(() => _headerAlign[key] = sel.first);
            setSS(() => _headerAlign[key] = sel.first);
            _saveConfig();
          },
        ),
      ]),
    );
  }

  Widget _alignmentRow(String key, void Function(void Function()) setSS) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
          child: Text(_blockTitle(key),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        SegmentedButton<TextAlign>(
          segments: const [
            ButtonSegment(
                value: TextAlign.left,
                icon: Icon(Icons.format_align_left, size: 16)),
            ButtonSegment(
                value: TextAlign.center,
                icon: Icon(Icons.format_align_center, size: 16)),
            ButtonSegment(
                value: TextAlign.right,
                icon: Icon(Icons.format_align_right, size: 16)),
          ],
          selected: {_alignOf(key)},
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onSelectionChanged: (sel) {
            setState(() => _blockAlignment[key] = sel.first);
            setSS(() => _blockAlignment[key] = sel.first);
            _saveConfig();
          },
        ),
      ]),
    );
  }

  void _showSignatureSheet() {
    setState(() => _activeTool = 'signature');
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Tampon & Signature de l'Émetteur",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Afficher le Tampon d\'état'),
                  value: _showPaidStamp,
                  activeThumbColor: _primary,
                  onChanged: (val) {
                    setState(() => _showPaidStamp = val);
                    setSS(() => _showPaidStamp = val);
                    _saveConfig();
                  },
                ),
                if (_showPaidStamp)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      children: ['PAYÉ', 'DEVIS', 'VALIDE', 'URGENT', 'REÇU']
                          .map((txt) {
                        final isSel = _stampText == txt;
                        return ChoiceChip(
                          label: Text(txt),
                          selected: isSel,
                          selectedColor: _primary,
                          labelStyle: TextStyle(
                              color: isSel ? Colors.white : Colors.black),
                          onSelected: (_) {
                            setState(() => _stampText = txt);
                            setSS(() => _stampText = txt);
                            _saveConfig();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                const Divider(height: 24),
                SwitchListTile(
                  title: const Text('Afficher la Ligne de Signature'),
                  value: _showSignatureLine,
                  activeThumbColor: _primary,
                  onChanged: (val) {
                    setState(() {
                      _showSignatureLine = val;
                      _blockVisibility['signature_block'] = val;
                    });
                    setSS(() {
                      _showSignatureLine = val;
                      _blockVisibility['signature_block'] = val;
                    });
                    _saveConfig();
                  },
                ),
                const SizedBox(height: 16),
              ]),
        ),
      ),
    ).whenComplete(() => setState(() => _activeTool = ''));
  }

  void _showLegalMentionsSheet() {
    setState(() => _activeTool = 'legale');
    final controller = TextEditingController(text: _customLegalText);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mentions Légales & Conformité OHADA',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Détails des Taxes & TVA'),
                  value: _workingTemplate.showTaxDetails,
                  activeThumbColor: _primary,
                  onChanged: (val) {
                    setState(() {
                      _workingTemplate = InvoiceTemplate(
                        id: _workingTemplate.id,
                        name: _workingTemplate.name,
                        description: _workingTemplate.description,
                        primaryColor: _workingTemplate.primaryColor,
                        textColor: _workingTemplate.textColor,
                        backgroundColor: _workingTemplate.backgroundColor,
                        showLogo: _workingTemplate.showLogo,
                        showTaxDetails: val,
                        showPaymentTerms: _workingTemplate.showPaymentTerms,
                        showPaymentQR: _workingTemplate.showPaymentQR,
                        isPremium: _workingTemplate.isPremium,
                      );
                    });
                    setSS(() {});
                    _saveConfig();
                  },
                ),
                SwitchListTile(
                  title: const Text('Conditions & Délais de Paiement'),
                  value: _workingTemplate.showPaymentTerms,
                  activeThumbColor: _primary,
                  onChanged: (val) {
                    setState(() {
                      _workingTemplate = InvoiceTemplate(
                        id: _workingTemplate.id,
                        name: _workingTemplate.name,
                        description: _workingTemplate.description,
                        primaryColor: _workingTemplate.primaryColor,
                        textColor: _workingTemplate.textColor,
                        backgroundColor: _workingTemplate.backgroundColor,
                        showLogo: _workingTemplate.showLogo,
                        showTaxDetails: _workingTemplate.showTaxDetails,
                        showPaymentTerms: val,
                        showPaymentQR: _workingTemplate.showPaymentQR,
                        isPremium: _workingTemplate.isPremium,
                      );
                    });
                    setSS(() {});
                    _saveConfig();
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Texte des mentions légales',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() => _customLegalText = val);
                    _saveConfig();
                  },
                ),
                const SizedBox(height: 16),
              ]),
        ),
      ),
    ).whenComplete(() => setState(() => _activeTool = ''));
  }

  void _showQRCodeSheet() {
    setState(() => _activeTool = 'qrcode');
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('QR Code de Paiement Sécurisé',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 14),
                SwitchListTile(
                  title: const Text('Afficher le QR Code PayQR'),
                  value: _workingTemplate.showPaymentQR,
                  activeThumbColor: _primary,
                  onChanged: (val) {
                    setState(() {
                      _workingTemplate = InvoiceTemplate(
                        id: _workingTemplate.id,
                        name: _workingTemplate.name,
                        description: _workingTemplate.description,
                        primaryColor: _workingTemplate.primaryColor,
                        textColor: _workingTemplate.textColor,
                        backgroundColor: _workingTemplate.backgroundColor,
                        showLogo: _workingTemplate.showLogo,
                        showTaxDetails: _workingTemplate.showTaxDetails,
                        showPaymentTerms: _workingTemplate.showPaymentTerms,
                        showPaymentQR: val,
                        isPremium: _workingTemplate.isPremium,
                      );
                    });
                    setSS(() {});
                    _saveConfig();
                  },
                ),
                if (_workingTemplate.showPaymentQR)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Text('Emplacement du QR: '),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _qrPosition,
                          items: const [
                            DropdownMenuItem(
                                value: 'header', child: Text('En-tête')),
                            DropdownMenuItem(
                                value: 'totals', child: Text('Bloc Totaux')),
                            DropdownMenuItem(
                                value: 'footer', child: Text('Pied de page')),
                            DropdownMenuItem(
                                value: 'standalone',
                                child: Text('Bloc autonome')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _qrPosition = val);
                              setSS(() => _qrPosition = val);
                              _saveConfig();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ]),
        ),
      ),
    ).whenComplete(() => setState(() => _activeTool = ''));
  }

  void _showBackgroundImageSheet() {
    setState(() => _activeTool = 'fond');
    showBackgroundSettingsSheet(
      context,
      current: _background,
      onChanged: (newBg) {
        setState(() => _background = newBg);
        _saveConfig();
      },
    ).whenComplete(() => setState(() => _activeTool = ''));
  }
}

// ── Modèles annexes ──
class _InvoiceBlock {
  final String key;
  final String title;
  final Widget Function(TextAlign align) builder;
  const _InvoiceBlock({
    required this.key,
    required this.title,
    required this.builder,
  });
}

class _Paragraph {
  String text;
  TextAlign align;
  bool bold;
  bool italic;

  _Paragraph({
    this.text = '',
    this.align = TextAlign.left,
    this.bold = false,
    this.italic = false,
  });

  _Paragraph copy() => _Paragraph(
        text: text,
        align: align,
        bold: bold,
        italic: italic,
      );

  Map<String, dynamic> toMap() => {
        'text': text,
        'align': align.name,
        'bold': bold,
        'italic': italic,
      };

  factory _Paragraph.fromMap(Map<String, dynamic> m) => _Paragraph(
        text: m['text']?.toString() ?? '',
        align: TextAlign.values.firstWhere(
          (a) => a.name == m['align'],
          orElse: () => TextAlign.left,
        ),
        bold: m['bold'] as bool? ?? false,
        italic: m['italic'] as bool? ?? false,
      );
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.12);
    const spacing = 12.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  static const double _dashWidth = 3.5;
  static const double _dashGap = 2.5;

  const _DashedRectPainter({
    required this.color,
    this.radius = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + _dashWidth).clamp(0.0, metric.length);
        dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + _dashGap;
      }
    }
    canvas.drawPath(
      dashed,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _GlassButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassButton({
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor.withValues(alpha: 0.85),
                Theme.of(context).primaryColor.withValues(alpha: 0.65),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.3), width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: padding,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionMoveButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color color;

  const _SectionMoveButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = enabled ? color : color.withValues(alpha: 0.35);
    return Tooltip(
      message: icon == Icons.keyboard_arrow_up
          ? 'Monter la section'
          : 'Descendre la section',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          child: Icon(icon, size: 15, color: c),
        ),
      ),
    );
  }
}