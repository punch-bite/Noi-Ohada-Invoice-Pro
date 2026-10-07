// lib/screens/customization/template_workspace_screen.dart
//
// 🎨 ATELIER DE PERSONNALISATION — v7 « True Canvas ».
//
// CHANGELOG v7 :
//   • 🖼️ VRAI CANVAS : fond gris + trame de points, page A4 CENTRÉE et
//     AUTO-FIT (la page entière tient à l'écran, peu importe la taille).
//   • ✅ FIX `StackFit.expand` : le fond + contenu remplissent la page A4
//     (l'ancien `Stack` sans fit réduisait tout à 0×0 → écran blanc).
//   • ✅ Bouton "Fit" (⛶) : retour au 100% auto-fit.
//   • ✅ Zoom clamps élargis (0.30 → 3.00).
//   • ✅ Grille magnétique 8pt conservée.
//   • ✅ Undo / Redo illimité (50 étapes).
//
// ignore_for_file: dead_null_aware_expression, deprecated_member_use,
//   unused_field, unused_element, unnecessary_import

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/company.dart';
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

// ═══════════════════════════════════════════════════════════════════════
//  CONSTANTES
// ═══════════════════════════════════════════════════════════════════════
const double _kGrid = InvoiceTemplate.gridSnap; // 8.0
const int _kMaxHistory = 50;

class TemplateWorkspaceScreen extends StatefulWidget {
  final InvoiceTemplate template;
  const TemplateWorkspaceScreen({super.key, required this.template});

  @override
  State<TemplateWorkspaceScreen> createState() =>
      _TemplateWorkspaceScreenState();
}

class _TemplateWorkspaceScreenState extends State<TemplateWorkspaceScreen>
    with TickerProviderStateMixin {
  // ── Thème ──
  ThemeProvider get _tp => Provider.of<ThemeProvider>(context, listen: false);
  Color get _primary => _tp.primaryColor;
  Color get _surface => _tp.cardColor;
  Color get _surfaceVariant => _tp.backgroundColor;
  Color get _onSurface => _tp.textColor;
  Color get _onSurfaceVariant => _tp.subTextColor;
  Color get _outline => _tp.dividerColor;

  // ── Services ──
  final DatabaseService _db = DatabaseService();
  Company? _company;

  // ── État du modèle ──
  late InvoiceTemplate _workingTemplate;
  TemplateBackgroundSettings _background = const TemplateBackgroundSettings();
  InvoiceSettings _invoiceSettings = InvoiceSettings.defaultSettings;

  bool _isLoading = true;
  bool _accessChecked = false;
  bool _canCustomize = false;

  // ── Canvas (zoom + fit) ──
  double _zoom = 1.0; // 1.0 = fit-to-screen
  bool _showGrid = true;
  final double _paperRadius = 12;

  // ── Sélection / drag ──
  String? _selectedKey;
  String? _draggingKey;
  String? _hoveredKey;
  int? _dragOverSection;

  // ── Historique ──
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _isRestoringHistory = false;
  bool get _canUndo => _undoStack.length > 1;
  bool get _canRedo => _redoStack.isNotEmpty;

  // ── Source unique de vérité (positions) ──
  Map<String, dynamic> _positions = <String, dynamic>{};

  // ── En-tête ──
  List<List<String>> _headerSections = [
    ['logo', 'company_info', 'invoice_title'],
  ];
  final Map<String, double> _headerWidths = {};
  final Map<String, TextAlign> _headerAlignments = {};
  final Map<String, bool> _headerVisibility = {};
  List<String> _titleExtraKeys = [];

  // ── Corps ──
  List<List<String>> _bodySections = [
    ['billing_info', 'invoice_meta'],
    ['items_table'],
    ['totals'],
    ['legal_mentions', 'signature_block'],
  ];
  final Map<String, bool> _blockVisibility = {};
  final Map<String, TextAlign> _blockAlignment = {};
  final Map<String, double> _blockWidths = {};
  final Map<String, String> _blockFonts = {};
  final Map<String, double> _blockFontScales = {};
  final Map<String, int> _blockBg = {};
  final Map<String, int> _blockText = {};

  // ── Textes libres ──
  final Map<String, String> _customTexts = {};
  final Map<String, List<_Paragraph>> _paragraphs = {};
  int _textSeq = 0;

  // ── Styles globaux ──
  String _headerStyle = 'flat';
  String _tableStyle = 'plain';
  String _footerStyle = 'simple';
  String _accentBorder = '';
  bool _showThankYou = false;
  String _thankYouText = '';
  String _bankName = '';
  String _bankAccount = '';
  bool _showPaidStamp = false;
  String _stampText = 'PAYÉ';
  bool _showSignatureLine = true;
  String _signatoryTitle = 'Authorized Sign';
  String _customLegalText = '';
  String _qrPosition = 'totals';
  double _pagePadding = 32;

  // ── Contenu démo ──
  String _companyName = '';
  String _companyAddress = '';
  String _companyPhone = '';
  String _companyEmail = '';
  final String _clientName = 'Client Exemple SARL';
  final String _clientAddress = 'RCCM: CM-DOU-2024-B123\nDouala, Cameroun';
  String _invoiceTitle = 'FACTURE';
  String _invoiceSubtitle = '';
  Uint8List? _customLogoBytes;
  Uint8List? _signatureBytes;
  double _logoSize = 46;

  @override
  void initState() {
    super.initState();
    _workingTemplate = widget.template;
    _checkAccess();
    _loadData();
  }

  // ═══════════════════════════════════════════════════════════════
  //  ACCÈS
  // ═══════════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════════
  //  CHARGEMENT
  // ═══════════════════════════════════════════════════════════════
  Future<void> _loadData({InvoiceTemplate? template}) async {
    final tpl = template ?? _workingTemplate;
    final company = await _db.getCompany();
    final custom = await TemplateCustomService.loadCustom(tpl.id);

    final merged = <String, dynamic>{
      ...tpl.positions,
      ...custom.positions,
    };

    Uint8List? storedSig;
    try {
      storedSig = await SignatureService().loadSignatureBytes();
    } catch (_) {}

    _resetAllMaps();
    _applyPositions(merged);

    if (!mounted) return;
    setState(() {
      _workingTemplate = tpl;
      _company = company;
      _companyName = company?.name ?? 'Mon entreprise';
      _companyAddress = company?.address ?? '';
      _companyPhone = company?.phone ?? '';
      _companyEmail = company?.email ?? '';
      _signatureBytes = storedSig;
      _background = custom.background;
      _isLoading = false;
      _undoStack
        ..clear()
        ..add(jsonEncode(_captureSnapshot()));
      _redoStack.clear();
    });

    try {
      final s = await SettingsService.instance.loadSettings();
      if (mounted) setState(() => _invoiceSettings = s);
    } catch (_) {}
  }

  void _resetAllMaps() {
    _headerSections = [
      ['logo', 'company_info', 'invoice_title'],
    ];
    _headerWidths.clear();
    _headerAlignments.clear();
    _headerVisibility.clear();
    _bodySections = [
      ['billing_info', 'invoice_meta'],
      ['items_table'],
      ['totals'],
      ['legal_mentions', 'signature_block'],
    ];
    _blockVisibility.clear();
    _blockAlignment.clear();
    _blockWidths.clear();
    _blockFonts.clear();
    _blockFontScales.clear();
    _blockBg.clear();
    _blockText.clear();
    _customTexts.clear();
    _paragraphs.clear();
    _titleExtraKeys = [];
    _textSeq = 0;
    _headerStyle = 'flat';
    _tableStyle = 'plain';
    _footerStyle = 'simple';
    _accentBorder = '';
    _showThankYou = false;
    _thankYouText = '';
    _bankName = '';
    _bankAccount = '';
    _showPaidStamp = false;
    _stampText = 'PAYÉ';
    _showSignatureLine = true;
    _signatoryTitle = 'Authorized Sign';
    _customLegalText = '';
    _qrPosition = 'totals';
    _pagePadding = 32;
    _customLogoBytes = null;
    _logoSize = 46;
  }

  void _applyPositions(Map<String, dynamic> p) {
    if (p.isEmpty) return;

    final hs = InvoiceTemplate.decodeSections(p['header_sections']);
    if (hs.isNotEmpty) _headerSections = hs;

    _readDoubleMap(p['header_widths'], _headerWidths);
    _readAlignMap(p['header_alignments'], _headerAlignments);
    _readBoolMap(p['header_visibility'], _headerVisibility);

    final bs = InvoiceTemplate.decodeSections(p['blocks_sections']);
    if (bs.isNotEmpty) _bodySections = bs;
    _readBoolMap(p['block_visibility'], _blockVisibility);
    _readAlignMap(p['block_alignment'], _blockAlignment);
    _readDoubleMap(p['block_widths'], _blockWidths);
    _readIntMap(p['block_bg_colors'], _blockBg);
    _readIntMap(p['block_text_colors'], _blockText);
    _readStringMap(p['block_fonts'], _blockFonts);
    _readDoubleMap(p['block_font_scales'], _blockFontScales);

    if (p['custom_texts'] is Map) {
      (p['custom_texts'] as Map).forEach((k, v) {
        final key = k.toString();
        if (key.startsWith('text_')) {
          _customTexts[key] = v?.toString() ?? '';
          final seq = int.tryParse(key.substring('text_'.length));
          if (seq != null && seq > _textSeq) _textSeq = seq;
        }
      });
    }
    if (p['custom_paragraphs'] is Map) {
      (p['custom_paragraphs'] as Map).forEach((k, v) {
        if (v is List) {
          _paragraphs[k.toString()] = v
              .whereType<Map>()
              .map((m) => _Paragraph.fromMap(Map<String, dynamic>.from(m)))
              .toList();
        }
      });
      _paragraphs.forEach((key, list) {
        _customTexts[key] = list.map((e) => e.text).join('\n\n');
      });
    }
    if (p['title_extra_keys'] is List) {
      _titleExtraKeys = (p['title_extra_keys'] as List)
          .whereType<String>()
          .where((k) => k.startsWith('text_'))
          .toList();
    }

    _headerStyle = p['header_style']?.toString() ?? 'flat';
    _tableStyle = p['table_style']?.toString() ?? 'plain';
    _footerStyle = p['footer_style']?.toString() ?? 'simple';
    _accentBorder = p['accent_border']?.toString() ?? '';
    _showThankYou = p['show_thank_you'] as bool? ?? false;
    _thankYouText = p['thank_you_text']?.toString() ?? '';
    _bankName = p['bank_name']?.toString() ?? '';
    _bankAccount = p['bank_account']?.toString() ?? '';
    _showPaidStamp = p['show_paid_stamp'] as bool? ?? false;
    _stampText = p['stamp_text']?.toString() ?? 'PAYÉ';
    _showSignatureLine = p['show_signature_line'] as bool? ?? true;
    _signatoryTitle = p['signatory_title']?.toString() ?? 'Authorized Sign';
    _customLegalText = p['custom_legal_text']?.toString() ?? '';
    _qrPosition = p['qr_position']?.toString() ?? 'totals';
    _pagePadding = (p['page_padding'] as num?)?.toDouble() ?? 32;
    _invoiceTitle = p['invoice_title_text']?.toString() ?? 'FACTURE';
    _invoiceSubtitle = p['invoice_subtitle']?.toString() ?? '';

    final logo = p['custom_logo_base64']?.toString();
    if (logo != null && logo.isNotEmpty) {
      try {
        _customLogoBytes = base64Decode(logo);
      } catch (_) {}
    }
    final sig = p['signature_image']?.toString();
    if (sig != null && sig.isNotEmpty) {
      try {
        _signatureBytes = base64Decode(sig);
      } catch (_) {}
    }
    _logoSize = (p['logo_size'] as num?)?.toDouble() ?? 46;
  }

  void _readBoolMap(Object? raw, Map<String, bool> target) {
    if (raw is! Map) return;
    raw.forEach((k, v) {
      if (v is bool) target[k.toString()] = v;
    });
  }

  void _readAlignMap(Object? raw, Map<String, TextAlign> target) {
    if (raw is! Map) return;
    raw.forEach((k, v) {
      for (final a in TextAlign.values) {
        if (a.name == v) target[k.toString()] = a;
      }
    });
  }

  void _readDoubleMap(Object? raw, Map<String, double> target) {
    if (raw is! Map) return;
    raw.forEach((k, v) {
      if (v is num) target[k.toString()] = v.toDouble();
    });
  }

  void _readIntMap(Object? raw, Map<String, int> target) {
    if (raw is! Map) return;
    raw.forEach((k, v) {
      if (v is num) target[k.toString()] = v.toInt();
    });
  }

  void _readStringMap(Object? raw, Map<String, String> target) {
    if (raw is! Map) return;
    raw.forEach((k, v) {
      if (v is String && v.isNotEmpty) target[k.toString()] = v;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  SNAPSHOT / HISTORIQUE
  // ═══════════════════════════════════════════════════════════════
  Map<String, dynamic> _captureSnapshot() {
    final snap = <String, dynamic>{
      'header_sections': InvoiceTemplate.encodeSections(_headerSections),
      'header_widths': Map<String, double>.from(_headerWidths),
      'header_alignments': _headerAlignments.map((k, v) => MapEntry(k, v.name)),
      'header_visibility': Map<String, bool>.from(_headerVisibility),
      'blocks_sections': InvoiceTemplate.encodeSections(_bodySections),
      'block_visibility': Map<String, bool>.from(_blockVisibility),
      'block_alignment': _blockAlignment.map((k, v) => MapEntry(k, v.name)),
      'block_widths': Map<String, double>.from(_blockWidths),
      'block_bg_colors': Map<String, int>.from(_blockBg),
      'block_text_colors': Map<String, int>.from(_blockText),
      'block_fonts': Map<String, String>.from(_blockFonts),
      'block_font_scales': Map<String, double>.from(_blockFontScales),
      'header_style': _headerStyle,
      'table_style': _tableStyle,
      'footer_style': _footerStyle,
      'accent_border': _accentBorder,
      'show_thank_you': _showThankYou,
      'thank_you_text': _thankYouText,
      'bank_name': _bankName,
      'bank_account': _bankAccount,
      'show_paid_stamp': _showPaidStamp,
      'stamp_text': _stampText,
      'show_signature_line': _showSignatureLine,
      'signatory_title': _signatoryTitle,
      'custom_legal_text': _customLegalText,
      'qr_position': _qrPosition,
      'page_padding': _pagePadding,
      'grid_snap': InvoiceTemplate.gridSnap,
      'invoice_title_text': _invoiceTitle,
      'invoice_subtitle': _invoiceSubtitle,
      'logo_size': _logoSize,
      'custom_texts': Map<String, String>.from(_customTexts),
      'custom_paragraphs': {
        for (final e in _paragraphs.entries)
          e.key: e.value.map((p) => p.toMap()).toList(),
      },
      'title_extra_keys': List<String>.from(_titleExtraKeys),
    };
    if (_customLogoBytes != null) {
      snap['custom_logo_base64'] = base64Encode(_customLogoBytes!);
    }
    if (_signatureBytes != null) {
      snap['signature_image'] = base64Encode(_signatureBytes!);
    }
    return snap;
  }

  void _recordHistory() {
    if (_isRestoringHistory) return;
    final json = jsonEncode(_captureSnapshot());
    if (_undoStack.isNotEmpty && _undoStack.last == json) return;
    _undoStack.add(json);
    if (_undoStack.length > _kMaxHistory) _undoStack.removeAt(0);
    _redoStack.clear();
    setState(() {});
  }

  void _undo() {
    if (!_canUndo) return;
    _isRestoringHistory = true;
    _redoStack.add(_undoStack.removeLast());
    _restoreFromJson(_undoStack.last);
    _isRestoringHistory = false;
    _persist();
  }

  void _redo() {
    if (!_canRedo) return;
    _isRestoringHistory = true;
    final json = _redoStack.removeLast();
    _undoStack.add(json);
    _restoreFromJson(json);
    _isRestoringHistory = false;
    _persist();
  }

  void _restoreFromJson(String json) {
    final snapshot = jsonDecode(json) as Map<String, dynamic>;
    _resetAllMaps();
    _applyPositions(snapshot);
    setState(() => _selectedKey = null);
  }

  Future<void> _persist({bool feedback = false}) async {
    final positions = _captureSnapshot();
    _positions = positions;

    await TemplateCustomService.saveCustom(
      _workingTemplate.id,
      positions: positions,
      mapping: _workingTemplate.mapping,
      background: _background,
    );
    _recordHistory();

    if (feedback && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Modifications enregistrées'),
            ]),
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            duration: const Duration(milliseconds: 1400),
          ),
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  MAGNETIC SNAP
  // ═══════════════════════════════════════════════════════════════
  double _snapToGrid(double value) => (value / _kGrid).round() * _kGrid;

  // ═══════════════════════════════════════════════════════════════
  //  MUTATIONS
  // ═══════════════════════════════════════════════════════════════
  void _mutate(VoidCallback fn) {
    setState(fn);
    _persist();
  }

  void _moveBlock(String key, int targetSection, {String? beforeKey}) {
    _mutate(() {
      for (final section in _bodySections) {
        section.remove(key);
      }
      _bodySections.removeWhere((s) => s.isEmpty);
      if (_bodySections.isEmpty) _bodySections.add(<String>[]);

      if (targetSection < 0 || targetSection >= _bodySections.length) {
        _bodySections.add([key]);
      } else {
        final list = _bodySections[targetSection];
        if (beforeKey != null) {
          final idx = list.indexOf(beforeKey);
          if (idx >= 0) {
            list.insert(idx, key);
          } else {
            list.add(key);
          }
        } else {
          list.add(key);
        }
      }
      _draggingKey = null;
      _dragOverSection = null;
    });
  }

  void _moveBlockToHeader(String key, {int? row, String? beforeKey}) {
    if (_headerSections.isEmpty) {
      _headerSections = [
        <String>[],
      ];
    }
    _mutate(() {
      for (final s in _bodySections) {
        s.remove(key);
      }
      _bodySections.removeWhere((s) => s.isEmpty);
      if (_bodySections.isEmpty) _bodySections.add(<String>[]);
      for (final s in _headerSections) {
        s.remove(key);
      }
      _headerSections.removeWhere((s) => s.isEmpty);

      _headerVisibility[key] = true;
      _headerWidths.putIfAbsent(key, () => 1.0);
      _headerAlignments.putIfAbsent(key, () => TextAlign.left);

      final targetRow =
          (row ?? (_headerSections.length - 1))
              .clamp(0, _headerSections.length - 1);
      if (_headerSections.isEmpty) {
        _headerSections.add([key]);
      } else {
        final list = _headerSections[targetRow];
        if (beforeKey != null) {
          final idx = list.indexOf(beforeKey);
          if (idx >= 0) {
            list.insert(idx, key);
          } else {
            list.add(key);
          }
        } else {
          list.add(key);
        }
      }
    });
  }

  void _moveHeaderToBody(String key) {
    _mutate(() {
      for (final s in _headerSections) {
        s.remove(key);
      }
      _headerSections.removeWhere((s) => s.isEmpty);
      if (_headerSections.isEmpty) {
        _headerSections = [
          <String>[],
        ];
      }
      _headerVisibility.remove(key);
      _headerWidths.remove(key);
      _headerAlignments.remove(key);

      if (!_bodySections.any((s) => s.contains(key))) {
        _bodySections.add([key]);
      }
    });
  }

  void _dropUnderTitle(String key) {
    _mutate(() {
      for (final s in _bodySections) {
        s.remove(key);
      }
      _bodySections.removeWhere((s) => s.isEmpty);
      if (_bodySections.isEmpty) _bodySections.add(<String>[]);
      for (final s in _headerSections) {
        s.remove(key);
      }
      _headerSections.removeWhere((s) => s.isEmpty);
      if (_headerSections.isEmpty) {
        _headerSections = [
          <String>[],
        ];
      }

      if (!_titleExtraKeys.contains(key)) _titleExtraKeys.add(key);
      if (key.startsWith('text_')) {
        _customTexts.putIfAbsent(key, () => '');
        _paragraphs.putIfAbsent(key, () => [_Paragraph()]);
      }
    });
  }

  void _removeFromTitle(String key) {
    _mutate(() {
      _titleExtraKeys.remove(key);
      if (!_bodySections.any((s) => s.contains(key))) {
        _bodySections.add([key]);
      }
    });
  }

  void _addHeaderRow() {
    final key = 'text_${++_textSeq}';
    _mutate(() {
      _customTexts[key] = '';
      _paragraphs[key] = [_Paragraph()];
      _blockVisibility[key] = true;
      _blockAlignment[key] = TextAlign.left;
      _headerVisibility[key] = true;
      _headerWidths[key] = 1.0;
      _headerAlignments[key] = TextAlign.left;
      _headerSections.add([key]);
    });
  }

  void _addHeaderColumn(int row) {
    if (row < 0 || row >= _headerSections.length) return;
    final key = 'text_${++_textSeq}';
    _mutate(() {
      _customTexts[key] = '';
      _paragraphs[key] = [_Paragraph()];
      _blockVisibility[key] = true;
      _blockAlignment[key] = TextAlign.left;
      _headerVisibility[key] = true;
      _headerWidths[key] = 1.0;
      _headerAlignments[key] = TextAlign.left;
      _headerSections[row].add(key);
    });
  }

  void _addBodyColumn(int section) {
    if (section < 0 || section >= _bodySections.length) return;
    final key = 'text_${++_textSeq}';
    _mutate(() {
      _customTexts[key] = '';
      _paragraphs[key] = [_Paragraph()];
      _blockVisibility[key] = true;
      _blockAlignment[key] = TextAlign.left;
      _bodySections[section].add(key);
    });
  }

  void _addBodySection() {
    _mutate(() {
      _bodySections.add(<String>[]);
    });
  }

  void _removeText(String key) {
    _mutate(() {
      _customTexts.remove(key);
      _paragraphs.remove(key);
      _blockVisibility.remove(key);
      _blockAlignment.remove(key);
      _blockFonts.remove(key);
      _blockFontScales.remove(key);
      _blockWidths.remove(key);
      _blockBg.remove(key);
      _blockText.remove(key);
      for (final s in _bodySections) {
        s.remove(key);
      }
      _bodySections.removeWhere((s) => s.isEmpty);
      if (_bodySections.isEmpty) _bodySections.add(<String>[]);
      for (final s in _headerSections) {
        s.remove(key);
      }
      _headerSections.removeWhere((s) => s.isEmpty);
      if (_headerSections.isEmpty) {
        _headerSections = [
          <String>[],
        ];
      }
      _titleExtraKeys.remove(key);
    });
  }

  void _addTextToBody() {
    final key = 'text_${++_textSeq}';
    _mutate(() {
      _customTexts[key] = '';
      _paragraphs[key] = [_Paragraph()];
      _blockVisibility[key] = true;
      _blockAlignment[key] = TextAlign.left;
      _bodySections.add([key]);
    });
    _openTextEditor(key);
  }

  void _addTextToHeader() {
    final key = 'text_${++_textSeq}';
    _mutate(() {
      _customTexts[key] = '';
      _paragraphs[key] = [_Paragraph()];
      _blockVisibility[key] = true;
      _blockAlignment[key] = TextAlign.left;
      _headerVisibility[key] = true;
      _headerWidths[key] = 1.0;
      _headerAlignments[key] = TextAlign.left;
      if (_headerSections.isEmpty) {
        _headerSections = [
          [key],
        ];
      } else {
        _headerSections.last.add(key);
      }
    });
    _openTextEditor(key);
  }

  // ═══════════════════════════════════════════════════════════════
  //  APERÇU
  // ═══════════════════════════════════════════════════════════════
  Widget _buildA4Preview() {
    return _WorkspaceA4Preview(
      state: _WorkspaceRenderState(
        headerSections: _headerSections,
        headerWidths: _headerWidths,
        headerAlignments: _headerAlignments,
        headerVisibility: _headerVisibility,
        titleExtraKeys: _titleExtraKeys,
        bodySections: _bodySections,
        blockVisibility: _blockVisibility,
        blockAlignment: _blockAlignment,
        blockWidths: _blockWidths,
        blockFonts: _blockFonts,
        blockFontScales: _blockFontScales,
        blockBg: _blockBg,
        blockText: _blockText,
        customTexts: _customTexts,
        paragraphs: _paragraphs,
        headerStyle: _headerStyle,
        tableStyle: _tableStyle,
        footerStyle: _footerStyle,
        accentBorder: _accentBorder,
        showThankYou: _showThankYou,
        thankYouText: _thankYouText,
        bankName: _bankName,
        bankAccount: _bankAccount,
        showPaidStamp: _showPaidStamp,
        stampText: _stampText,
        showSignatureLine: _showSignatureLine,
        signatoryTitle: _signatoryTitle,
        customLegalText: _customLegalText,
        qrPosition: _qrPosition,
        pagePadding: _pagePadding,
        companyName: _companyName,
        companyAddress: _companyAddress,
        companyPhone: _companyPhone,
        companyEmail: _companyEmail,
        clientName: _clientName,
        clientAddress: _clientAddress,
        invoiceTitle: _invoiceTitle,
        invoiceSubtitle: _invoiceSubtitle,
        logoSize: _logoSize,
        customLogoBytes: _customLogoBytes,
        signatureBytes: _signatureBytes,
        primary: _workingTemplate.primaryColor,
        textColor: _workingTemplate.textColor,
        backgroundColor: _workingTemplate.backgroundColor,
        fontFamily: _workingTemplate.fontFamily,
        fontSize: _workingTemplate.fontSize,
        background: _background,
      ),
      onBlockDroppedInSection: (key, section, beforeKey) =>
          _moveBlock(key, section, beforeKey: beforeKey),
      onBlockDroppedInHeader: (key, row, beforeKey) =>
          _moveBlockToHeader(key, row: row, beforeKey: beforeKey),
      onBlockDroppedUnderTitle: (key) => _dropUnderTitle(key),
      onDragStarted: (key) => setState(() => _draggingKey = key),
      onDragEnded: () => setState(() {
        _draggingKey = null;
        _hoveredKey = null;
        _dragOverSection = null;
      }),
      onSectionHover: (idx) => setState(() => _dragOverSection = idx),
      onSelected: (key) {
        setState(() => _selectedKey = key);
        _openBlockSheet(key);
      },
      showGrid: _showGrid,
      gridSize: _kGrid,
      paperRadius: _paperRadius,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SHEETS D'ÉDITION
  // ═══════════════════════════════════════════════════════════════
  void _openBlockSheet(String key) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BlockSheet(
        keyName: key,
        title: _blockTitle(key),
        isHeader: _isHeaderKey(key),
        isText: key.startsWith('text_'),
        isNativeHeader:
            ['logo', 'company_info', 'invoice_title'].contains(key),
        visibility: _isHeaderKey(key)
            ? (_headerVisibility[key] ?? true)
            : (_blockVisibility[key] ?? true),
        width: _isHeaderKey(key)
            ? (_headerWidths[key] ?? 1.0)
            : (_blockWidths[key] ?? 1.0),
        alignment: _isHeaderKey(key)
            ? (_headerAlignments[key] ?? TextAlign.left)
            : (_blockAlignment[key] ?? TextAlign.left),
        font: _blockFonts[key],
        fontScale: _blockFontScales[key] ?? 1.0,
        bgColor: _blockBg[key],
        textColor: _blockText[key],
        paletteColors: const [
          Color(0xFF300546),
          Color(0xFF4A148C),
          Color(0xFF1E1E2C),
          Color(0xFF0D47A1),
          Color(0xFF004D40),
          Color(0xFFB78103),
          Color(0xFF880E4F),
          Color(0xFF1B5E20),
          Colors.black,
          Colors.white,
        ],
        themeColor: _primary,
        surface: _surface,
        onVisibilityChanged: (v) => _mutate(() {
          if (_isHeaderKey(key)) {
            _headerVisibility[key] = v;
          } else {
            _blockVisibility[key] = v;
          }
        }),
        onWidthChanged: (v) => _mutate(() {
          final snapped = _snapToGrid(v * 100) / 100;
          if (_isHeaderKey(key)) {
            _headerWidths[key] = snapped;
          } else {
            _blockWidths[key] = snapped;
          }
        }),
        onAlignmentChanged: (a) => _mutate(() {
          if (_isHeaderKey(key)) {
            _headerAlignments[key] = a;
          } else {
            _blockAlignment[key] = a;
          }
        }),
        onFontChanged: (f) => _mutate(() {
          if (f == null) {
            _blockFonts.remove(key);
          } else {
            _blockFonts[key] = f;
          }
        }),
        onFontScaleChanged: (v) => _mutate(() {
          final snapped = _snapToGrid(v * 100) / 100;
          _blockFontScales[key] = snapped.clamp(0.6, 1.8);
        }),
        onBgChanged: (c) => _mutate(() {
          _blockBg[key] = c?.toARGB32() ?? 0;
        }),
        onTextColorChanged: (c) => _mutate(() {
          _blockText[key] = c?.toARGB32() ?? 0;
        }),
        onEditText: key.startsWith('text_') ? () => _openTextEditor(key) : null,
        onMoveToHeader: !_isHeaderKey(key) && !key.startsWith('text_')
            ? () => _moveBlockToHeader(key)
            : null,
        onMoveToBody:
            _isHeaderKey(key) &&
                    !['logo', 'company_info', 'invoice_title'].contains(key)
                ? () => _moveHeaderToBody(key)
                : null,
        onRemoveFromTitle:
            _titleExtraKeys.contains(key) ? () => _removeFromTitle(key) : null,
        onDelete: key.startsWith('text_') ? () => _removeText(key) : null,
      ),
    ).whenComplete(() => setState(() => _selectedKey = null));
  }

  void _openTextEditor(String key) {
    final paragraphs = _paragraphsOf(key);
    final working = paragraphs.map((p) => p.copy()).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => _TextEditorSheet(
          working: working,
          onChanged: () => setSS(() {}),
          onAdd: () => setSS(() => working.add(_Paragraph())),
          onRemove: (i) => setSS(() => working.removeAt(i)),
          onMoveUp: (i) => setSS(() {
            final p = working.removeAt(i);
            working.insert(i - 1, p);
          }),
          onMoveDown: (i) => setSS(() {
            final p = working.removeAt(i);
            working.insert(i + 1, p);
          }),
          onSave: () {
            _mutate(() {
              _paragraphs[key] = working;
              _customTexts[key] = working.map((p) => p.text).join('\n\n');
            });
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

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

  bool _isHeaderKey(String key) {
    for (final s in _headerSections) {
      if (s.contains(key)) return true;
    }
    return false;
  }

  String _blockTitle(String key) {
    switch (key) {
      case 'logo':
        return 'Logo';
      case 'company_info':
        return 'Infos société';
      case 'invoice_title':
        return 'Titre facture';
      case 'billing_info':
        return 'Infos client';
      case 'invoice_meta':
        return 'Méta facture';
      case 'items_table':
        return 'Tableau articles';
      case 'totals':
        return 'Totaux';
      case 'legal_mentions':
        return 'Mentions légales';
      case 'signature_block':
        return 'Signature';
      case 'qr_block':
        return 'QR code';
      default:
        if (key.startsWith('text_')) {
          final t = (_customTexts[key] ?? '').replaceAll('\n', ' ').trim();
          if (t.isEmpty) return 'Texte libre';
          return t.length > 20 ? '${t.substring(0, 20)}…' : t;
        }
        return key;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  SHEET STYLE
  // ═══════════════════════════════════════════════════════════════
  void _openStyleSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => _StyleSheet(
          headerStyle: _headerStyle,
          tableStyle: _tableStyle,
          footerStyle: _footerStyle,
          accentBorder: _accentBorder,
          showThankYou: _showThankYou,
          thankYouText: _thankYouText,
          bankName: _bankName,
          bankAccount: _bankAccount,
          pagePadding: _pagePadding,
          showPaidStamp: _showPaidStamp,
          stampText: _stampText,
          showSignatureLine: _showSignatureLine,
          signatoryTitle: _signatoryTitle,
          customLegalText: _customLegalText,
          qrPosition: _qrPosition,
          showPaymentQR: _workingTemplate.showPaymentQR,
          showTaxDetails: _workingTemplate.showTaxDetails,
          showPaymentTerms: _workingTemplate.showPaymentTerms,
          primary: _primary,
          onHeaderStyle: (v) => setSS(() => _mutate(() => _headerStyle = v)),
          onTableStyle: (v) => setSS(() => _mutate(() => _tableStyle = v)),
          onFooterStyle: (v) => setSS(() => _mutate(() => _footerStyle = v)),
          onAccentBorder: (v) => setSS(() => _mutate(() => _accentBorder = v)),
          onShowThankYou: (v) => setSS(() => _mutate(() => _showThankYou = v)),
          onThankYouText: (v) => _mutate(() => _thankYouText = v),
          onBankName: (v) => _mutate(() => _bankName = v),
          onBankAccount: (v) => _mutate(() => _bankAccount = v),
          onPagePadding: (v) =>
              setSS(() => _mutate(() => _pagePadding = _snapToGrid(v))),
          onShowPaidStamp: (v) => setSS(() => _mutate(() => _showPaidStamp = v)),
          onStampText: (v) => _mutate(() => _stampText = v),
          onShowSignatureLine: (v) =>
              setSS(() => _mutate(() => _showSignatureLine = v)),
          onSignatoryTitle: (v) => _mutate(() => _signatoryTitle = v),
          onCustomLegalText: (v) => _mutate(() => _customLegalText = v),
          onQrPosition: (v) => setSS(() => _mutate(() => _qrPosition = v)),
          onTogglePaymentQR: (v) => setSS(() {
            _mutate(() =>
                _workingTemplate = _workingTemplate.copyWith(showPaymentQR: v));
          }),
          onToggleTaxDetails: (v) => setSS(() {
            _mutate(() => _workingTemplate =
                _workingTemplate.copyWith(showTaxDetails: v));
          }),
          onTogglePaymentTerms: (v) => setSS(() {
            _mutate(() => _workingTemplate =
                _workingTemplate.copyWith(showPaymentTerms: v));
          }),
          surface: _surface,
        ),
      ),
    );
  }

  void _openBackgroundSheet() {
    showBackgroundSettingsSheet(
      context,
      current: _background,
      onChanged: (b) => _mutate(() => _background = b),
    );
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    _mutate(() => _customLogoBytes = bytes);
  }

  Future<void> _pickSignature() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    _mutate(() => _signatureBytes = bytes);
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (!_accessChecked) {
      return Scaffold(
        backgroundColor: _surfaceVariant,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_canCustomize) {
      return _buildDenied();
    }
    return Scaffold(
      backgroundColor: _surfaceVariant,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _isLoading ? _skeleton() : _buildPreviewArea()),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _skeleton() => const Center(child: CircularProgressIndicator());

  Widget _buildDenied() {
    return Scaffold(
      backgroundColor: _surfaceVariant,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: const Text('Atelier'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 48, color: _primary),
              const SizedBox(height: 16),
              const Text(
                'Personnalisation réservée',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Acquérez ce modèle dans la boutique pour le personnaliser.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/templates'),
                child: const Text('Voir la boutique'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BARRE SUPÉRIEURE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTopBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _surface,
        border:
            Border(bottom: BorderSide(color: _outline.withValues(alpha: 0.25))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: _onSurface),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _workingTemplate.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _onSurface,
                  ),
                ),
                Text(
                  'Atelier de personnalisation',
                  style: TextStyle(fontSize: 11, color: _onSurfaceVariant),
                ),
              ],
            ),
          ),
          _toolbarIcon(
            Icons.undo_rounded,
            tooltip: 'Annuler',
            enabled: _canUndo,
            onTap: _undo,
          ),
          _toolbarIcon(
            Icons.redo_rounded,
            tooltip: 'Rétablir',
            enabled: _canRedo,
            onTap: _redo,
          ),
          Container(
            height: 22,
            width: 1,
            color: _outline.withValues(alpha: 0.4),
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          _toolbarIcon(
            Icons.grid_on_rounded,
            tooltip: _showGrid ? 'Masquer la grille' : 'Afficher la grille',
            active: _showGrid,
            onTap: () => setState(() => _showGrid = !_showGrid),
          ),
          _toolbarIcon(
            Icons.remove_rounded,
            tooltip: 'Zoom −',
            onTap: () =>
                setState(() => _zoom = (_zoom - 0.10).clamp(0.30, 3.0)),
          ),
          Text(
            '${(_zoom * 100).toInt()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _onSurfaceVariant,
            ),
          ),
          _toolbarIcon(
            Icons.add_rounded,
            tooltip: 'Zoom +',
            onTap: () =>
                setState(() => _zoom = (_zoom + 0.10).clamp(0.30, 3.0)),
          ),
          _toolbarIcon(
            Icons.fit_screen_rounded,
            tooltip: 'Ajuster à l\'écran (100%)',
            onTap: () => setState(() => _zoom = 1.0),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 36),
              ),
              onPressed: () => _persist(feedback: true),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text(
                'Enregistrer',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarIcon(
    IconData icon, {
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
    bool enabled = true,
  }) {
    final color = !enabled
        ? _onSurfaceVariant.withValues(alpha: 0.3)
        : (active ? _primary : _onSurfaceVariant);
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 18, color: color),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CANVAS (v7 — vrai canvas centré + auto-fit)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPreviewArea() {
    return Container(
      color: const Color(0xFFF3F4F6), // gris clair type Figma
      child: Stack(
        children: [
          // ── Trame de points en fond (feel "canvas") ──
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CanvasDotPainter(
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
          ),

          // ── Contenu zoomable et centré (auto-fit) ──
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const pageW = InvoiceTemplate.kPageWidth; // 794
                const pageH = InvoiceTemplate.kPageHeight; // 1123
                const outerPad = 40.0;

                final availW = (constraints.maxWidth - outerPad * 2)
                    .clamp(80.0, double.infinity);
                final availH = (constraints.maxHeight - outerPad * 2)
                    .clamp(80.0, double.infinity);

                // Scale "fit-to-screen" : la page entière doit tenir.
                final fitScale = math.min(availW / pageW, availH / pageH);
                // Scale final = fit × zoom utilisateur.
                final totalScale = (fitScale * _zoom).clamp(0.10, 4.0);

                final displayW = pageW * totalScale;
                final displayH = pageH * totalScale;

                return InteractiveViewer(
                  minScale: 0.20,
                  maxScale: 4.0,
                  boundaryMargin: const EdgeInsets.all(160),
                  panEnabled: true,
                  scaleEnabled: true,
                  child: Center(
                    child: SizedBox(
                      width: displayW,
                      height: displayH,
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: SizedBox(
                          width: pageW,
                          height: pageH,
                          child: _buildA4Preview(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BARRE INFÉRIEURE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBottomBar() {
    final tools = <_Tool>[
      _Tool('Style', Icons.palette_outlined, _openStyleSheet),
      _Tool('Fond', Icons.wallpaper_outlined, _openBackgroundSheet),
      _Tool('Logo', Icons.image_outlined, _pickLogo),
      _Tool('Signature', Icons.draw_outlined, _pickSignature),
      _Tool('Texte', Icons.notes_outlined, _addTextToBody),
      _Tool('Colonne', Icons.view_column_outlined, () {
        final idx = _bodySections.length - 1;
        if (idx >= 0) _addBodyColumn(idx);
      }),
      _Tool('Section', Icons.add_box_outlined, _addBodySection),
      _Tool('En-tête +', Icons.add_to_photos_outlined, _addTextToHeader),
    ];
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _outline.withValues(alpha: 0.25))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: tools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) => _toolButton(tools[i]),
      ),
    );
  }

  Widget _toolButton(_Tool tool) {
    return InkWell(
      onTap: tool.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(tool.icon, size: 18, color: _primary),
            ),
            const SizedBox(height: 4),
            Text(
              tool.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: _onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  STRUCTURES
// ═══════════════════════════════════════════════════════════════════════

class _Tool {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _Tool(this.label, this.icon, this.onTap);
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
  _Paragraph copy() =>
      _Paragraph(text: text, align: align, bold: bold, italic: italic);
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

// ═══════════════════════════════════════════════════════════════════════
//  ÉTAT DE RENDU
// ═══════════════════════════════════════════════════════════════════════
class _WorkspaceRenderState {
  final List<List<String>> headerSections;
  final Map<String, double> headerWidths;
  final Map<String, TextAlign> headerAlignments;
  final Map<String, bool> headerVisibility;
  final List<String> titleExtraKeys;
  final List<List<String>> bodySections;
  final Map<String, bool> blockVisibility;
  final Map<String, TextAlign> blockAlignment;
  final Map<String, double> blockWidths;
  final Map<String, String> blockFonts;
  final Map<String, double> blockFontScales;
  final Map<String, int> blockBg;
  final Map<String, int> blockText;
  final Map<String, String> customTexts;
  final Map<String, List<_Paragraph>> paragraphs;
  final String headerStyle;
  final String tableStyle;
  final String footerStyle;
  final String accentBorder;
  final bool showThankYou;
  final String thankYouText;
  final String bankName;
  final String bankAccount;
  final bool showPaidStamp;
  final String stampText;
  final bool showSignatureLine;
  final String signatoryTitle;
  final String customLegalText;
  final String qrPosition;
  final double pagePadding;
  final String companyName;
  final String companyAddress;
  final String companyPhone;
  final String companyEmail;
  final String clientName;
  final String clientAddress;
  final String invoiceTitle;
  final String invoiceSubtitle;
  final double logoSize;
  final Uint8List? customLogoBytes;
  final Uint8List? signatureBytes;
  final Color primary;
  final Color textColor;
  final Color backgroundColor;
  final String fontFamily;
  final double fontSize;
  final TemplateBackgroundSettings background;

  const _WorkspaceRenderState({
    required this.headerSections,
    required this.headerWidths,
    required this.headerAlignments,
    required this.headerVisibility,
    required this.titleExtraKeys,
    required this.bodySections,
    required this.blockVisibility,
    required this.blockAlignment,
    required this.blockWidths,
    required this.blockFonts,
    required this.blockFontScales,
    required this.blockBg,
    required this.blockText,
    required this.customTexts,
    required this.paragraphs,
    required this.headerStyle,
    required this.tableStyle,
    required this.footerStyle,
    required this.accentBorder,
    required this.showThankYou,
    required this.thankYouText,
    required this.bankName,
    required this.bankAccount,
    required this.showPaidStamp,
    required this.stampText,
    required this.showSignatureLine,
    required this.signatoryTitle,
    required this.customLegalText,
    required this.qrPosition,
    required this.pagePadding,
    required this.companyName,
    required this.companyAddress,
    required this.companyPhone,
    required this.companyEmail,
    required this.clientName,
    required this.clientAddress,
    required this.invoiceTitle,
    required this.invoiceSubtitle,
    required this.logoSize,
    this.customLogoBytes,
    this.signatureBytes,
    required this.primary,
    required this.textColor,
    required this.backgroundColor,
    required this.fontFamily,
    required this.fontSize,
    required this.background,
  });
}

// ═══════════════════════════════════════════════════════════════════════
//  APERÇU A4
// ═══════════════════════════════════════════════════════════════════════
class _WorkspaceA4Preview extends StatelessWidget {
  final _WorkspaceRenderState state;
  final void Function(String key, int section, String? beforeKey)
      onBlockDroppedInSection;
  final void Function(String key, int row, String? beforeKey)
      onBlockDroppedInHeader;
  final void Function(String key) onBlockDroppedUnderTitle;
  final ValueChanged<String> onDragStarted;
  final VoidCallback onDragEnded;
  final ValueChanged<int> onSectionHover;
  final ValueChanged<String> onSelected;
  final bool showGrid;
  final double gridSize;
  final double paperRadius;

  const _WorkspaceA4Preview({
    required this.state,
    required this.onBlockDroppedInSection,
    required this.onBlockDroppedInHeader,
    required this.onBlockDroppedUnderTitle,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onSectionHover,
    required this.onSelected,
    required this.showGrid,
    required this.gridSize,
    required this.paperRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      // ✅ StackFit.expand : force les enfants à remplir la page A4.
      fit: StackFit.expand,
      children: [
        // Feuille A4 : fond + ombre.
        Container(
          decoration: BoxDecoration(
            color: state.backgroundColor,
            borderRadius: BorderRadius.circular(paperRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: TemplateBackgroundLayer(
            presetId: state.background.presetId,
            imageBytes: decodeBackgroundImage(state.background.fileData),
            opacity: state.background.opacity,
            blur: state.background.blur,
            fit: state.background.fit,
          ),
        ),

        // Contenu.
        Container(
          padding: EdgeInsets.all(state.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(child: _buildBody()),
              _buildFooter(),
            ],
          ),
        ),

        // Grille magnétique visuelle.
        if (showGrid) IgnorePointer(child: _buildGridOverlay()),
      ],
    );
  }

  Widget _buildGridOverlay() {
    return CustomPaint(
      painter: _GridPainter(
        gridSize: gridSize,
        color: Colors.black.withValues(alpha: 0.035),
        strongColor: Colors.black.withValues(alpha: 0.07),
      ),
    );
  }

  // ── EN-TÊTE ──
  Widget _buildHeader() {
    final rows = <Widget>[];
    for (var r = 0; r < state.headerSections.length; r++) {
      rows.add(_buildHeaderRow(r));
    }
    final headerBg = (state.headerStyle == 'dark' ||
            state.headerStyle == 'band' ||
            state.headerStyle == 'wave' ||
            state.headerStyle == 'split_orange_left')
        ? state.primary
        : Colors.transparent;

    return Container(
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(6),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }

  Widget _buildHeaderRow(int r) {
    final keys = state.headerSections[r];
    final children = <Widget>[];
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      if (i > 0) children.add(const SizedBox(width: 8));
      if (state.headerVisibility[key] == false) continue;
      final flex = ((state.headerWidths[key] ?? 1.0) * 10).round().clamp(4, 30);
      children.add(Expanded(
        flex: flex,
        child: _draggable(
          key: key,
          isHeader: true,
          child: _buildHeaderContent(key),
        ),
      ));
    }
    if (keys.length < 4) {
      children.add(const SizedBox(width: 4));
      children.add(_plusColumn(() => onSelected('__add_header_col__$r')));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child:
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: children),
    );
  }

  Widget _buildHeaderContent(String key) {
    switch (key) {
      case 'logo':
        return _logoWidget();
      case 'company_info':
        return _companyInfoWidget();
      case 'invoice_title':
        return _invoiceTitleWidget();
      default:
        if (key.startsWith('text_')) return _textBlockWidget(key);
        return const SizedBox.shrink();
    }
  }

  Widget _logoWidget() {
    final initials = state.companyName.isNotEmpty
        ? state.companyName
            .substring(0, state.companyName.length >= 3 ? 3 : state.companyName.length)
            .toUpperCase()
        : 'ABC';
    final size = state.logoSize;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: state.primary.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(color: state.primary.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        child: state.customLogoBytes != null
            ? Image.memory(state.customLogoBytes!, fit: BoxFit.cover)
            : Text(
                initials,
                style: TextStyle(
                  color: state.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.3,
                ),
              ),
      ),
    );
  }

  Widget _companyInfoWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.companyName.isNotEmpty)
          Text(
            state.companyName,
            style: TextStyle(
              fontSize: state.fontSize * 1.15,
              fontWeight: FontWeight.w800,
              color: state.primary,
            ),
          ),
        if (state.companyAddress.isNotEmpty)
          Text(
            state.companyAddress,
            style: TextStyle(
              fontSize: state.fontSize * 0.8,
              color: state.textColor.withValues(alpha: 0.7),
            ),
          ),
        if (state.companyPhone.isNotEmpty)
          Text(
            state.companyPhone,
            style: TextStyle(
              fontSize: state.fontSize * 0.8,
              color: state.textColor.withValues(alpha: 0.7),
            ),
          ),
        if (state.companyEmail.isNotEmpty)
          Text(
            state.companyEmail,
            style: TextStyle(
              fontSize: state.fontSize * 0.8,
              color: state.textColor.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }

  Widget _invoiceTitleWidget() {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            state.invoiceTitle,
            style: TextStyle(
              fontSize: state.fontSize * 2.4,
              fontWeight: FontWeight.w900,
              color: state.primary,
              letterSpacing: -1,
            ),
          ),
          if (state.invoiceSubtitle.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                state.invoiceSubtitle,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: state.fontSize * 0.85,
                  color: state.textColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ...state.titleExtraKeys
              .where((k) => state.customTexts.containsKey(k))
              .map((k) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _textBlockWidget(k),
                  )),
        ],
      ),
    );
  }

  // ── CORPS ──
  Widget _buildBody() {
    final rows = <Widget>[];
    for (var s = 0; s < state.bodySections.length; s++) {
      rows.add(_buildBodySection(s));
    }
    return SingleChildScrollView(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }

  Widget _buildBodySection(int index) {
    final keys = state.bodySections[index];
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => true,
      onAcceptWithDetails: (d) => onBlockDroppedInSection(d.data, index, null),
      onMove: (_) => onSectionHover(index),
      onLeave: (_) => onSectionHover(-1),
      builder: (ctx, candidates, rejected) {
        final children = <Widget>[];
        for (var i = 0; i < keys.length; i++) {
          final key = keys[i];
          if (i > 0) children.add(const SizedBox(width: 8));
          if (state.blockVisibility[key] == false) continue;
          final flex =
              ((state.blockWidths[key] ?? 1.0) * 10).round().clamp(3, 30);
          children.add(Expanded(
            flex: flex,
            child: _draggable(
              key: key,
              isHeader: false,
              child: _buildBodyContent(key),
            ),
          ));
        }
        if (keys.length < 3) {
          if (children.isNotEmpty) children.add(const SizedBox(width: 8));
          children.add(_plusColumn(() => onSelected('__add_body_col__$index')));
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: candidates.isNotEmpty
                ? Border.all(color: state.primary, width: 1.5)
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children.isEmpty ? [_emptySectionHint()] : children,
          ),
        );
      },
    );
  }

  Widget _emptySectionHint() => Expanded(
        child: Container(
          height: 32,
          alignment: Alignment.center,
          child: Text(
            'Déposer un bloc ici',
            style: TextStyle(
              fontSize: 10,
              color: state.textColor.withValues(alpha: 0.4),
            ),
          ),
        ),
      );

  Widget _buildBodyContent(String key) {
    switch (key) {
      case 'billing_info':
        return _billingWidget();
      case 'invoice_meta':
        return _metaWidget();
      case 'items_table':
        return _itemsTableWidget();
      case 'totals':
        return _totalsWidget();
      case 'legal_mentions':
        return _legalWidget();
      case 'signature_block':
        return _signatureWidget();
      case 'qr_block':
        return _qrWidget();
      default:
        if (key.startsWith('text_')) return _textBlockWidget(key);
        return const SizedBox.shrink();
    }
  }

  Widget _billingWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INVOICE TO:',
            style: TextStyle(
              fontSize: state.fontSize * 0.85,
              fontWeight: FontWeight.w800,
              color: state.primary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.clientName,
            style: TextStyle(
              fontSize: state.fontSize,
              fontWeight: FontWeight.w700,
              color: state.textColor,
            ),
          ),
          if (state.clientAddress.isNotEmpty)
            Text(
              state.clientAddress,
              style: TextStyle(
                fontSize: state.fontSize * 0.85,
                color: state.textColor.withValues(alpha: 0.75),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metaWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _metaRow('Invoice #', '0001593'),
          _metaRow('Date', '01/05/2029'),
          _metaRow('Due Date', '30/05/2029'),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$label : ',
              style: TextStyle(
                fontSize: state.fontSize * 0.8,
                fontWeight: FontWeight.w700,
                color: state.textColor.withValues(alpha: 0.65),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: state.fontSize * 0.85,
                color: state.textColor,
              ),
            ),
          ],
        ),
      );

  Widget _itemsTableWidget() {
    final rows = const [
      ['1', 'Wireless Router', '120', '10', '1 200'],
      ['2', 'Lan Cable', '200', '8', '1 600'],
      ['3', 'Lorem ipsum', '30', '15', '450'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: state.primary,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 1, child: _ThCell('N°')),
                Expanded(flex: 5, child: _ThCell('ITEM DESCRIPTION')),
                Expanded(
                    flex: 2,
                    child: _ThCell('QTY', align: TextAlign.center)),
                Expanded(
                    flex: 2,
                    child: _ThCell('PRICE', align: TextAlign.right)),
                Expanded(
                    flex: 2,
                    child: _ThCell('TOTAL', align: TextAlign.right)),
              ],
            ),
          ),
          ...rows.asMap().entries.map((e) {
            final i = e.key;
            final r = e.value;
            final alt = state.tableStyle == 'alternate_dark' && i.isEven;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: alt
                    ? state.primary.withValues(alpha: 0.05)
                    : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: state.textColor.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(flex: 1, child: _TdCell(r[0])),
                  Expanded(flex: 5, child: _TdCell(r[1])),
                  Expanded(
                      flex: 2,
                      child: _TdCell(r[2], align: TextAlign.center)),
                  Expanded(
                      flex: 2,
                      child: _TdCell(r[3], align: TextAlign.right)),
                  Expanded(
                      flex: 2,
                      child: _TdCell(r[4],
                          align: TextAlign.right, bold: true)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _totalsWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _totalLine('Sub Total', '2 800 \$'),
          _totalLine('Tax', '280 \$'),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: state.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOTAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: state.fontSize * 0.95,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '3 080 \$',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: state.fontSize * 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$label : ',
              style: TextStyle(
                fontSize: state.fontSize * 0.85,
                color: state.textColor.withValues(alpha: 0.7),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: state.fontSize * 0.9,
                color: state.textColor,
              ),
            ),
          ],
        ),
      );

  Widget _legalWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TERMS & CONDITIONS',
            style: TextStyle(
              fontSize: state.fontSize * 0.85,
              fontWeight: FontWeight.w800,
              color: state.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.customLegalText.isNotEmpty
                ? state.customLegalText
                : 'Paiement à 30 jours nets. Pénalités de retard selon SYSCOHADA.',
            style: TextStyle(
              fontSize: state.fontSize * 0.75,
              color: state.textColor.withValues(alpha: 0.75),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _signatureWidget() {
    if (!state.showSignatureLine) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (state.signatureBytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Image.memory(
                state.signatureBytes!,
                width: 120,
                height: 44,
                fit: BoxFit.contain,
              ),
            ),
          Container(
            width: 110,
            height: 1,
            color: state.textColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 3),
          Text(
            state.signatoryTitle,
            style: TextStyle(
              fontSize: state.fontSize * 0.75,
              color: state.textColor.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qrWidget() => Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: state.textColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.qr_code_2, size: 40),
      );

  Widget _textBlockWidget(String key) {
    final paragraphs = state.paragraphs[key] ??
        [_Paragraph(text: state.customTexts[key] ?? '')];
    final isEmpty = paragraphs.every((p) => p.text.trim().isEmpty);
    return GestureDetector(
      onTap: () => onSelected(key),
      child: Container(
        padding: isEmpty
            ? const EdgeInsets.all(6)
            : const EdgeInsets.symmetric(vertical: 4),
        decoration: isEmpty
            ? BoxDecoration(
                border: Border.all(
                  color: state.textColor.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: isEmpty
            ? Text(
                'Tapez ici…',
                style: TextStyle(
                  fontSize: state.fontSize * 0.85,
                  color: state.textColor.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final p in paragraphs)
                    if (p.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          p.text,
                          textAlign: p.align,
                          style: TextStyle(
                            fontSize: state.fontSize * 0.85,
                            color: state.textColor,
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
      ),
    );
  }

  // ── PIED ──
  Widget _buildFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.bankName.isNotEmpty || state.bankAccount.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${state.bankName} ${state.bankAccount}',
              style: TextStyle(
                fontSize: state.fontSize * 0.75,
                color: state.textColor.withValues(alpha: 0.65),
              ),
            ),
          ),
        if (state.showThankYou)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: state.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                state.thankYouText.isNotEmpty
                    ? state.thankYouText
                    : 'Merci pour votre confiance !',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── DRAG WRAPPER ──
  Widget _draggable({
    required String key,
    required bool isHeader,
    required Widget child,
  }) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != key,
      onAcceptWithDetails: (d) {
        if (isHeader) {
          final row =
              state.headerSections.indexWhere((s) => s.contains(key));
          onBlockDroppedInHeader(d.data, row < 0 ? 0 : row, key);
        } else {
          final section =
              state.bodySections.indexWhere((s) => s.contains(key));
          onBlockDroppedInSection(d.data, section < 0 ? 0 : section, key);
        }
      },
      builder: (ctx, candidates, _) {
        final isHover = candidates.isNotEmpty;
        return Draggable<String>(
          data: key,
          onDragStarted: () => onDragStarted(key),
          onDragEnd: (_) => onDragEnded(),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.85,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: state.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: state.primary, width: 1.5),
                ),
                child: child,
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: child),
          child: GestureDetector(
            onTap: () => onSelected(key),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isHover ? state.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _plusColumn(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: state.textColor.withValues(alpha: 0.2)),
        ),
        child: Icon(
          Icons.add,
          size: 12,
          color: state.textColor.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _ThCell extends StatelessWidget {
  final String label;
  final TextAlign align;
  const _ThCell(this.label, {this.align = TextAlign.left});
  @override
  Widget build(BuildContext context) => Text(
        label,
        textAlign: align,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      );
}

class _TdCell extends StatelessWidget {
  final String value;
  final TextAlign align;
  final bool bold;
  const _TdCell(this.value, {this.align = TextAlign.left, this.bold = false});
  @override
  Widget build(BuildContext context) => Text(
        value,
        textAlign: align,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════
//  PAINTERS
// ═══════════════════════════════════════════════════════════════════════
class _GridPainter extends CustomPainter {
  final double gridSize;
  final Color color;
  final Color strongColor;
  _GridPainter({
    required this.gridSize,
    required this.color,
    required this.strongColor,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final thin = Paint()
      ..color = color
      ..strokeWidth = 0.4;
    final strong = Paint()
      ..color = strongColor
      ..strokeWidth = 0.8;
    for (double x = 0; x <= size.width; x += gridSize) {
      final strongLine = (x / gridSize) % 5 == 0;
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), strongLine ? strong : thin);
    }
    for (double y = 0; y <= size.height; y += gridSize) {
      final strongLine = (y / gridSize) % 5 == 0;
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), strongLine ? strong : thin);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.gridSize != gridSize || old.color != color;
}

/// 🎨 Trame de points type Figma / Photoshop (fond canvas).
class _CanvasDotPainter extends CustomPainter {
  final Color color;
  const _CanvasDotPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const step = 24.0;
    final paint = Paint()..color = color;
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasDotPainter old) => old.color != color;
}

// ═══════════════════════════════════════════════════════════════════════
//  SHEET : BLOC
// ═══════════════════════════════════════════════════════════════════════
class _BlockSheet extends StatelessWidget {
  final String keyName;
  final String title;
  final bool isHeader;
  final bool isText;
  final bool isNativeHeader;
  final bool visibility;
  final double width;
  final TextAlign alignment;
  final String? font;
  final double fontScale;
  final int? bgColor;
  final int? textColor;
  final List<Color> paletteColors;
  final Color themeColor;
  final Color surface;
  final ValueChanged<bool> onVisibilityChanged;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<TextAlign> onAlignmentChanged;
  final ValueChanged<String?> onFontChanged;
  final ValueChanged<double> onFontScaleChanged;
  final ValueChanged<Color?> onBgChanged;
  final ValueChanged<Color?> onTextColorChanged;
  final VoidCallback? onEditText;
  final VoidCallback? onMoveToHeader;
  final VoidCallback? onMoveToBody;
  final VoidCallback? onRemoveFromTitle;
  final VoidCallback? onDelete;

  const _BlockSheet({
    required this.keyName,
    required this.title,
    required this.isHeader,
    required this.isText,
    required this.isNativeHeader,
    required this.visibility,
    required this.width,
    required this.alignment,
    required this.font,
    required this.fontScale,
    required this.bgColor,
    required this.textColor,
    required this.paletteColors,
    required this.themeColor,
    required this.surface,
    required this.onVisibilityChanged,
    required this.onWidthChanged,
    required this.onAlignmentChanged,
    required this.onFontChanged,
    required this.onFontScaleChanged,
    required this.onBgChanged,
    required this.onTextColorChanged,
    this.onEditText,
    this.onMoveToHeader,
    this.onMoveToBody,
    this.onRemoveFromTitle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (ctx, setSS) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    isHeader
                        ? Icons.view_column_outlined
                        : Icons.dashboard_outlined,
                    color: themeColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isText && onEditText != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onEditText,
                    icon:
                        Icon(Icons.edit_outlined, size: 16, color: themeColor),
                    label: Text('Éditer le contenu',
                        style: TextStyle(color: themeColor)),
                    style: OutlinedButton.styleFrom(
                      side:
                          BorderSide(color: themeColor.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Afficher cet élément',
                    style: TextStyle(fontSize: 13)),
                value: visibility,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  onVisibilityChanged(v);
                  setSS(() {});
                },
              ),
              const SizedBox(height: 4),
              _label('Alignement'),
              Row(
                children: [
                  for (final a in [
                    TextAlign.left,
                    TextAlign.center,
                    TextAlign.right
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Icon(
                          a == TextAlign.left
                              ? Icons.format_align_left
                              : a == TextAlign.center
                                  ? Icons.format_align_center
                                  : Icons.format_align_right,
                          size: 16,
                        ),
                        selected: alignment == a,
                        selectedColor: themeColor.withValues(alpha: 0.15),
                        onSelected: (_) {
                          onAlignmentChanged(a);
                          setSS(() {});
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _label('Largeur (${(width * 100).round()}%)'),
              Slider(
                value: width.clamp(0.3, 3.0),
                min: 0.3,
                max: 3.0,
                divisions: 27,
                activeColor: themeColor,
                label: '${(width * 100).round()}%',
                onChanged: (v) {
                  onWidthChanged(v);
                  setSS(() {});
                },
              ),
              const SizedBox(height: 8),
              _label('Taille du texte (${(fontScale * 100).round()}%)'),
              Slider(
                value: fontScale.clamp(0.6, 1.8),
                min: 0.6,
                max: 1.8,
                divisions: 12,
                activeColor: themeColor,
                label: '${(fontScale * 100).round()}%',
                onChanged: (v) {
                  onFontScaleChanged(v);
                  setSS(() {});
                },
              ),
              const SizedBox(height: 8),
              _label('Couleur du fond'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _colorDot(null, bgColor == null || bgColor == 0, themeColor,
                      () {
                    onBgChanged(null);
                    setSS(() {});
                  }),
                  for (final c in paletteColors)
                    _colorDot(c, bgColor == c.toARGB32(), themeColor, () {
                      onBgChanged(c);
                      setSS(() {});
                    }),
                ],
              ),
              const SizedBox(height: 12),
              _label('Couleur du texte'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _colorDot(null,
                      textColor == null || textColor == 0, themeColor, () {
                    onTextColorChanged(null);
                    setSS(() {});
                  }),
                  for (final c in paletteColors)
                    _colorDot(c, textColor == c.toARGB32(), themeColor, () {
                      onTextColorChanged(c);
                      setSS(() {});
                    }),
                ],
              ),
              const SizedBox(height: 12),
              _label('Police'),
              DropdownButtonFormField<String?>(
                initialValue: font,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Par défaut')),
                  DropdownMenuItem(value: 'WorkSans', child: Text('Work Sans')),
                  DropdownMenuItem(value: 'Manrope', child: Text('Manrope')),
                  DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                ],
                onChanged: (v) {
                  onFontChanged(v);
                  setSS(() {});
                },
              ),
              const SizedBox(height: 16),
              if (onRemoveFromTitle != null)
                TextButton.icon(
                  onPressed: onRemoveFromTitle,
                  icon: Icon(Icons.vertical_align_bottom,
                      size: 16, color: themeColor),
                  label: Text('Replacer dans le corps',
                      style: TextStyle(color: themeColor)),
                ),
              if (onMoveToHeader != null)
                TextButton.icon(
                  onPressed: onMoveToHeader,
                  icon: Icon(Icons.vertical_align_top,
                      size: 16, color: themeColor),
                  label: Text("Déplacer vers l'en-tête",
                      style: TextStyle(color: themeColor)),
                ),
              if (onMoveToBody != null)
                TextButton.icon(
                  onPressed: onMoveToBody,
                  icon: Icon(Icons.vertical_align_bottom,
                      size: 16, color: themeColor),
                  label: Text('Replacer dans le corps',
                      style: TextStyle(color: themeColor)),
                ),
              if (onDelete != null)
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.redAccent),
                  label: const Text('Supprimer ce texte',
                      style: TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );

  Widget _colorDot(Color? color, bool selected, Color themeColor,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color ?? Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color:
                selected ? themeColor : Colors.black.withValues(alpha: 0.15),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: color == null
            ? const Icon(Icons.block, size: 14, color: Colors.black45)
            : (selected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  SHEET : TEXTE
// ═══════════════════════════════════════════════════════════════════════
class _TextEditorSheet extends StatelessWidget {
  final List<_Paragraph> working;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onMoveUp;
  final ValueChanged<int> onMoveDown;
  final VoidCallback onSave;

  const _TextEditorSheet({
    required this.working,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Éditeur de texte',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              IconButton(
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Ajouter un paragraphe',
              ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < working.length; i++)
                    _paragraphCard(i, working[i]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onSave,
                  child: const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paragraphCard(int i, _Paragraph p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('¶ ${i + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.blueGrey,
                  )),
              const Spacer(),
              if (i > 0)
                IconButton(
                  onPressed: () => onMoveUp(i),
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
              if (i < working.length - 1)
                IconButton(
                  onPressed: () => onMoveDown(i),
                  icon: const Icon(Icons.arrow_downward, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
              if (working.length > 1)
                IconButton(
                  onPressed: () => onRemove(i),
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.redAccent),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: p.text,
            maxLines: null,
            minLines: 2,
            onChanged: (v) {
              p.text = v;
              onChanged();
            },
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Saisissez votre texte…',
              border: OutlineInputBorder(),
            ),
            style: TextStyle(
              fontWeight: p.bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: p.italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [
            FilterChip(
              label: const Text('Gras', style: TextStyle(fontSize: 11)),
              selected: p.bold,
              onSelected: (v) {
                p.bold = v;
                onChanged();
              },
            ),
            FilterChip(
              label: const Text('Italique', style: TextStyle(fontSize: 11)),
              selected: p.italic,
              onSelected: (v) {
                p.italic = v;
                onChanged();
              },
            ),
            _alignChip(p, TextAlign.left, Icons.format_align_left),
            _alignChip(p, TextAlign.center, Icons.format_align_center),
            _alignChip(p, TextAlign.right, Icons.format_align_right),
          ]),
        ],
      ),
    );
  }

  Widget _alignChip(_Paragraph p, TextAlign align, IconData icon) {
    final selected = p.align == align;
    return GestureDetector(
      onTap: () {
        p.align = align;
        onChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? Colors.blue.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.blue : Colors.grey.withValues(alpha: 0.4),
          ),
        ),
        child: Icon(icon,
            size: 14, color: selected ? Colors.blue : Colors.black54),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  SHEET : STYLE
// ═══════════════════════════════════════════════════════════════════════
class _StyleSheet extends StatelessWidget {
  final String headerStyle;
  final String tableStyle;
  final String footerStyle;
  final String accentBorder;
  final bool showThankYou;
  final String thankYouText;
  final String bankName;
  final String bankAccount;
  final double pagePadding;
  final bool showPaidStamp;
  final String stampText;
  final bool showSignatureLine;
  final String signatoryTitle;
  final String customLegalText;
  final String qrPosition;
  final bool showPaymentQR;
  final bool showTaxDetails;
  final bool showPaymentTerms;
  final Color primary;
  final Color surface;
  final ValueChanged<String> onHeaderStyle;
  final ValueChanged<String> onTableStyle;
  final ValueChanged<String> onFooterStyle;
  final ValueChanged<String> onAccentBorder;
  final ValueChanged<bool> onShowThankYou;
  final ValueChanged<String> onThankYouText;
  final ValueChanged<String> onBankName;
  final ValueChanged<String> onBankAccount;
  final ValueChanged<double> onPagePadding;
  final ValueChanged<bool> onShowPaidStamp;
  final ValueChanged<String> onStampText;
  final ValueChanged<bool> onShowSignatureLine;
  final ValueChanged<String> onSignatoryTitle;
  final ValueChanged<String> onCustomLegalText;
  final ValueChanged<String> onQrPosition;
  final ValueChanged<bool> onTogglePaymentQR;
  final ValueChanged<bool> onToggleTaxDetails;
  final ValueChanged<bool> onTogglePaymentTerms;

  const _StyleSheet({
    required this.headerStyle,
    required this.tableStyle,
    required this.footerStyle,
    required this.accentBorder,
    required this.showThankYou,
    required this.thankYouText,
    required this.bankName,
    required this.bankAccount,
    required this.pagePadding,
    required this.showPaidStamp,
    required this.stampText,
    required this.showSignatureLine,
    required this.signatoryTitle,
    required this.customLegalText,
    required this.qrPosition,
    required this.showPaymentQR,
    required this.showTaxDetails,
    required this.showPaymentTerms,
    required this.primary,
    required this.surface,
    required this.onHeaderStyle,
    required this.onTableStyle,
    required this.onFooterStyle,
    required this.onAccentBorder,
    required this.onShowThankYou,
    required this.onThankYouText,
    required this.onBankName,
    required this.onBankAccount,
    required this.onPagePadding,
    required this.onShowPaidStamp,
    required this.onStampText,
    required this.onShowSignatureLine,
    required this.onSignatoryTitle,
    required this.onCustomLegalText,
    required this.onQrPosition,
    required this.onTogglePaymentQR,
    required this.onToggleTaxDetails,
    required this.onTogglePaymentTerms,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Icon(Icons.palette_outlined, color: primary, size: 18),
              const SizedBox(width: 8),
              const Text('Styles de la facture',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 14),
            _label('En-tête'),
            _chips<String>(
              current: headerStyle,
              options: const [
                ('flat', 'Plat'),
                ('dark', 'Foncé'),
                ('band', 'Bandeau'),
                ('wave', 'Vague'),
                ('split_orange_left', 'Orange (G)'),
                ('split_diagonal_corners', 'Diagonales'),
                ('circle_accent_top_left', 'Cercle (G)'),
                ('orange_band_right', 'Orange (D)'),
                ('cursive_title', 'Cursive'),
                ('diamond_center', 'Losange'),
              ],
              onChanged: onHeaderStyle,
            ),
            const SizedBox(height: 12),
            _label('Tableau'),
            _chips<String>(
              current: tableStyle,
              options: const [
                ('plain', 'Simple'),
                ('alternate_dark', 'Zébré foncé'),
                ('dark_header', 'Header foncé'),
                ('orange_bars', 'Barres orange'),
                ('cards', 'Cartes'),
              ],
              onChanged: onTableStyle,
            ),
            const SizedBox(height: 12),
            _label('Pied de page'),
            _chips<String>(
              current: footerStyle,
              options: const [
                ('simple', 'Simple'),
                ('contact_bar_icons', 'Contact (icônes)'),
                ('zigzag_thankyou', 'Zigzag'),
                ('thick_orange_band', 'Bande orange'),
                ('rainbow_strip', 'Arc-en-ciel'),
                ('diagonal_bottom_stripes', 'Diagonales'),
              ],
              onChanged: onFooterStyle,
            ),
            const SizedBox(height: 12),
            _label('Bordure décorative'),
            _chips<String>(
              current: accentBorder,
              options: const [
                ('', 'Aucune'),
                ('top', 'Haut'),
                ('left', 'Gauche'),
                ('frame', 'Cadre'),
                ('stripes_bottom', 'Bandes bas'),
              ],
              onChanged: onAccentBorder,
            ),
            const SizedBox(height: 12),
            _label('Marge page (${pagePadding.round()}pt)'),
            Slider(
              value: pagePadding.clamp(8, 80),
              min: 8,
              max: 80,
              divisions: 18,
              activeColor: primary,
              label: '${pagePadding.round()}',
              onChanged: onPagePadding,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('QR code paiement',
                  style: TextStyle(fontSize: 13)),
              value: showPaymentQR,
              activeThumbColor: primary,
              onChanged: onTogglePaymentQR,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Détails fiscaux (TVA)',
                  style: TextStyle(fontSize: 13)),
              value: showTaxDetails,
              activeThumbColor: primary,
              onChanged: onToggleTaxDetails,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Conditions de paiement',
                  style: TextStyle(fontSize: 13)),
              value: showPaymentTerms,
              activeThumbColor: primary,
              onChanged: onTogglePaymentTerms,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Tampon "PAYÉ"',
                  style: TextStyle(fontSize: 13)),
              value: showPaidStamp,
              activeThumbColor: primary,
              onChanged: onShowPaidStamp,
            ),
            if (showPaidStamp)
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Texte du tampon',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: onStampText,
                controller: TextEditingController(text: stampText),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Ligne de signature',
                  style: TextStyle(fontSize: 13)),
              value: showSignatureLine,
              activeThumbColor: primary,
              onChanged: onShowSignatureLine,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Afficher "Merci…"',
                  style: TextStyle(fontSize: 13)),
              value: showThankYou,
              activeThumbColor: primary,
              onChanged: onShowThankYou,
            ),
            if (showThankYou)
              TextField(
                controller: TextEditingController(text: thankYouText),
                decoration: const InputDecoration(
                  labelText: 'Texte de remerciement',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: onThankYouText,
              ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: bankName),
              decoration: const InputDecoration(
                labelText: 'Banque',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: onBankName,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: bankAccount),
              decoration: const InputDecoration(
                labelText: 'Numéro de compte',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: onBankAccount,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: signatoryTitle),
              decoration: const InputDecoration(
                labelText: 'Titre du signataire',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: onSignatoryTitle,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: customLegalText),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mentions légales',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: onCustomLegalText,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      );

  Widget _chips<T>({
    required T current,
    required List<(T, String)> options,
    required ValueChanged<T> onChanged,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (v, label) in options)
          GestureDetector(
            onTap: () => onChanged(v),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: v == current
                    ? primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: v == current
                      ? primary
                      : Colors.black.withValues(alpha: 0.15),
                  width: v == current ? 2 : 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: v == current ? FontWeight.w700 : FontWeight.w500,
                  color: v == current ? primary : Colors.black87,
                ),
              ),
            ),
          ),
      ],
    );
  }
}