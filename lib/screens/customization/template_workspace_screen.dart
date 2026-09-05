// lib/screens/customization/template_workspace_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/company.dart';
import '../../models/invoice_layout.dart';
import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/database_service.dart';
import '../../services/template_custom_service.dart';
import '../../widgets/template_background_palette.dart';

/// 🎨 Écran d'atelier visuel de personnalisation de facture — Design Stitch Refined.
class TemplateWorkspaceScreen extends StatefulWidget {
  final InvoiceTemplate template;
  const TemplateWorkspaceScreen({super.key, required this.template});

  @override
  State<TemplateWorkspaceScreen> createState() => _TemplateWorkspaceScreenState();
}

class _TemplateWorkspaceScreenState extends State<TemplateWorkspaceScreen>
    with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF300546);
  static const Color _bgSurface = Color(0xFFFFF7FC);
  static const Color _surfaceVariant = Color(0xFFE8E0E6);
  static const Color _onSurface = Color(0xFF1E1A1F);
  static const Color _onSurfaceVariant = Color(0xFF4C444E);
  static const Color _tertiaryContainer = Color(0xFFBAAB6D);
  static const Color _outline = Color(0xFF7D747F);

  final DatabaseService _db = DatabaseService();
  Company? _company;
  late InvoiceLayoutConfig _layoutConfig;
  late InvoiceTemplate _workingTemplate;
  TemplateBackgroundSettings _background = const TemplateBackgroundSettings();

  bool _isLoading = true;
  // 👮 Contrôle d'accès : personnalisation réservée à l'admin/propriétaire.
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

  // Header Drag & Drop state
  List<String> _headerElements = ['logo', 'company_info', 'invoice_title'];
  String? _draggingHeaderKey;
  String? _dragOverHeaderKey;
  String? _selectedHeaderKey;

  // Body Blocks : SECTIONS empilées, chacune pleine largeur, avec 1 à 3
  // blocs côte à côte (colonnes PAR SECTION, pas sur tout le papier).
  // Le tampon n'en fait pas partie : c'est un calque FIXE au-dessus de tout.
  static const int _maxPerSection = 3;
  /// 🧱 Clé spéciale : colonne VIDE (spacer). Elle réserve une fraction de
  /// la largeur de la section sans contenu — utile pour scinder une rangée
  /// (ex. « Totaux » à gauche, vide à droite). Plusieurs colonnes vides
  /// peuvent coexister dans une même section ; elles comptent dans la
  /// limite de _maxPerSection colonnes.
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
  // Alignement du contenu de chaque bloc (outil « Alignement »).
  final Map<String, TextAlign> _blockAlignment = {
    'billing_info': TextAlign.left,
    'invoice_meta': TextAlign.right,
    'items_table': TextAlign.left,
    'totals': TextAlign.right,
    'legal_mentions': TextAlign.left,
    'signature_block': TextAlign.center,
    'qr_block': TextAlign.center,
  };

  String? _draggingKey;
  String? _dragOverKey;
  int? _dragOverSection; // -1 = zone « nouvelle section »
  String? _selectedBlockKey;

  // Signature & Stamp state
  bool _showPaidStamp = true;
  String _stampText = 'PAYÉ';
  final Color _stampColor = const Color(0xFFBAAB6D);
  bool _showSignatureLine = true;
  String _signatoryTitle = 'Direction Générale';

  // Legal & QR state
  String _customLegalText = 'Paiement sous 30 jours net. Pénalités de retard applicables selon normes SYSCOHADA.';
  String _qrPosition = 'totals'; // 'header', 'totals', 'footer', 'standalone'

  // Editable Label Overrides
  String _companyName = '';
  String _companyAddress = '';
  String _companyPhone = '';
  String _companyEmail = '';
  String _clientName = 'Client Exemple SARL';
  final String _clientAddress = 'N° RCCM: CM-DOU-2024-B123\nDouala, Cameroun';
  String _invoiceTitleText = 'FACTURE';

  final List<String> _categories = const [
    'Recommandé', 'Simple', 'Classique', 'Professionnel',
  ];

  final List<Color> _paletteColors = const [
    Color(0xFF300546), Color(0xFF4A148C), Color(0xFF1E1E2C), Color(0xFF0D47A1),
    Color(0xFF004D40), Color(0xFFB78103), Color(0xFF880E4F), Color(0xFF1B5E20),
  ];

  List<InvoiceTemplate> _availableTemplates = [];
  late List<_InvoiceBlock> _invoiceBlocks;

  @override
  void initState() {
    super.initState();
    _workingTemplate = widget.template;
    _customFontSize = widget.template.fontSize;
    _layoutConfig = InvoiceLayoutConfig.defaultLayout();
    _initBlocks();
    _checkAccess();
    _loadData();
  }

  /// 👮 Vérifie que l'utilisateur courant peut personnaliser ce modèle :
  /// la personnalisation de la facture est réservée à l'administrateur et
  /// au propriétaire du modèle (créateur / acheteur / accès premium /
  /// modèle gratuit).
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
          key: 'billing_info', title: 'Infos Client (Facturé à)', builder: _buildBillingInfoBlock),
      'invoice_meta': _InvoiceBlock(
          key: 'invoice_meta', title: 'Méta Facture (N°, Date, Échéance)', builder: _buildInvoiceMetaBlock),
      'items_table': _InvoiceBlock(
          key: 'items_table', title: 'Tableau des Articles', builder: _buildItemsTableBlock),
      'totals': _InvoiceBlock(
          key: 'totals', title: 'Bloc Totaux (HT, TVA, TTC)', builder: _buildTotalsBlock),
      'legal_mentions': _InvoiceBlock(
          key: 'legal_mentions', title: 'Mentions Légales & Conditions', builder: _buildLegalMentionsBlock),
      'signature_block': _InvoiceBlock(
          key: 'signature_block', title: 'Ligne de Signature & Cachet', builder: _buildSignatureBlock),
      'qr_block': _InvoiceBlock(
          key: 'qr_block', title: 'QR Code de Paiement', builder: _buildQRBlock),
    };

    // Définitions de tous les blocs (le tampon, lui, est un calque fixe).
    _invoiceBlocks = allBlocks.values.toList();

    // Normalise les sections : 1 à _maxPerSection blocs par section, blocs
    // connus uniquement, sans doublon. Les anciennes clés inconnues (ex :
    // « stamp_block ») sont retirées ; un bloc excédentaire ou manquant est
    // ajouté à la dernière section non pleine, sinon dans une nouvelle.
    final knownKeys = allBlocks.keys.toSet();
    final seen = <String>{};
    final sections = <List<String>>[];
    for (final section in _sectionsLayout) {
      final cleaned = <String>[];
      for (final key in section) {
        // 🧱 Les colonnes vides (spacers) sont conservées : doublons
        // autorisés (chaque occurrence est un spacer distinct).
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
    final custom = await TemplateCustomService.loadCustom(widget.template.id);
    final templates = InvoiceTemplate.getDefaultTemplates();
    if (!mounted) return;
    setState(() {
      _company = company;
      _companyName = company?.name ?? 'Noi Concept digital';
      _companyAddress = company?.address ?? 'Doww Essos Yaoundé Cameroun';
      _companyPhone = company?.phone ?? '+237620409383';
      _companyEmail = company?.email ?? 'contact@noiconcept.com';

      if (custom.positions.isNotEmpty) {
        _layoutConfig = InvoiceLayoutConfig.fromMap(custom.positions);
        if (custom.positions['header_elements_order'] is List) {
          _headerElements = List<String>.from(custom.positions['header_elements_order']);
        }
        if (custom.positions['blocks_sections'] is List) {
          final raw = custom.positions['blocks_sections'] as List;
          _sectionsLayout = [
            for (final s in raw)
              if (s is List) List<String>.from(s.whereType<String>()) else <String>[],
          ];
        } else if (custom.positions['blocks_layout'] is List) {
          // Migration : anciennes colonnes pleine page → une section par colonne.
          _sectionsLayout = [
            for (final s in custom.positions['blocks_layout'] as List)
              if (s is List) List<String>.from(s.whereType<String>()) else <String>[],
          ];
        } else if (custom.positions['blocks_order'] is List) {
          // Migration : ancien ordre simple → une section par bloc.
          _sectionsLayout = [
            for (final key
                in (custom.positions['blocks_order'] as List).whereType<String>())
              [key],
          ];
        }
        if (custom.positions['block_visibility'] is Map) {
          final Map<String, dynamic> visMap = custom.positions['block_visibility'];
          visMap.forEach((k, v) {
            if (v is bool) _blockVisibility[k] = v;
          });
        }
        if (custom.positions['block_alignment'] is Map) {
          (custom.positions['block_alignment'] as Map).forEach((k, v) {
            final key = k.toString();
            for (final t in TextAlign.values) {
              if (t.name == v) _blockAlignment[key] = t;
            }
          });
        }
        if (custom.positions['qr_position'] != null) {
          _qrPosition = custom.positions['qr_position'] as String;
        }
        if (custom.positions['custom_legal_text'] != null) {
          _customLegalText = custom.positions['custom_legal_text'] as String;
        }
        if (custom.positions['stamp_text'] != null) {
          _stampText = custom.positions['stamp_text'] as String;
        }
        if (custom.positions['signatory_title'] != null) {
          _signatoryTitle = custom.positions['signatory_title'] as String;
        }
        if (custom.positions['company_name'] != null) {
          _companyName = custom.positions['company_name'] as String;
        }
        if (custom.positions['client_name'] != null) {
          _clientName = custom.positions['client_name'] as String;
        }
        if (custom.positions['invoice_title_text'] != null) {
          _invoiceTitleText = custom.positions['invoice_title_text'] as String;
        }
        if (custom.positions['show_paid_stamp'] != null) {
          _showPaidStamp = custom.positions['show_paid_stamp'] as bool;
        }
        if (custom.positions['show_signature_line'] != null) {
          _showSignatureLine = custom.positions['show_signature_line'] as bool;
          _blockVisibility['signature_block'] = _showSignatureLine;
        }
        if (custom.positions['logo_size'] != null) {
          _logoSize = (custom.positions['logo_size'] as num).toDouble();
        }
        if (custom.positions['custom_logo_base64'] != null) {
          try {
            _customLogoBytes = base64Decode(custom.positions['custom_logo_base64'] as String);
          } catch (_) {}
        }
      }
      _background = custom.background;
      _availableTemplates = templates;
      _initBlocks();
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    final updatedPositions = _layoutConfig.toMap();
    updatedPositions['header_elements_order'] = _headerElements;
    updatedPositions['blocks_sections'] = _sectionsLayout;
    // Compat : ordre à plat (d'éventuels anciens lecteurs / exports).
    updatedPositions['blocks_order'] =
        _sectionsLayout.expand((s) => s).toList();
    updatedPositions['block_visibility'] = _blockVisibility;
    updatedPositions['block_alignment'] =
        _blockAlignment.map((k, v) => MapEntry(k, v.name));
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
    if (_customLogoBytes != null) {
      updatedPositions['custom_logo_base64'] = base64Encode(_customLogoBytes!);
    }

    await TemplateCustomService.saveCustom(
      _workingTemplate.id,
      positions: updatedPositions,
      mapping: _workingTemplate.mapping,
      background: _background,
    );
    if (!mounted) return;
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

  void _reorderHeaderElements(String draggedKey, String targetKey) {
    if (draggedKey == targetKey) return;
    setState(() {
      final fromIndex = _headerElements.indexOf(draggedKey);
      final toIndex = _headerElements.indexOf(targetKey);
      if (fromIndex != -1 && toIndex != -1) {
        final item = _headerElements.removeAt(fromIndex);
        _headerElements.insert(toIndex, item);
      }
      _draggingHeaderKey = null;
      _dragOverHeaderKey = null;
    });
    _saveConfig();
  }

  // ── Déplacement d'un bloc entre les sections ──────────────────────────────

  /// Déplace [key] dans la section [targetSection] — avant [beforeKey] si
  /// fourni, sinon en fin de section. Avec [newSection], crée une section
  /// pleine largeur dédiée. Avec [replaceEmptyAtIndex], le bloc PREND LA
  /// PLACE de la colonne vide située à cet index (le spacer est consommé).
  /// Les sections devenues vides sont supprimées.
  void _moveBlock(String key, int targetSection,
      {String? beforeKey,
      bool newSection = false,
      int? replaceEmptyAtIndex}) {
    setState(() {
      final sourceIdx = _sectionsLayout.indexWhere((s) => s.contains(key));
      List<String>? sourceList;
      var removedIdx = -1;
      if (sourceIdx != -1) {
        sourceList = _sectionsLayout[sourceIdx];
        removedIdx = sourceList.indexOf(key);
      }
      // Position d'insertion calculée AVANT suppression (index de beforeKey
      // ou index de la colonne vide à remplacer).
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
      // Suppression à la source (+ suppression de la section si vide).
      if (sourceIdx != -1) {
        sourceList!.removeAt(removedIdx);
        if (sourceList.isEmpty) {
          _sectionsLayout.removeAt(sourceIdx);
          if (targetSection > sourceIdx) targetSection -= 1;
        }
      }
      // Réinsertion : avant le bloc visé, en fin de section, nouvelle
      // section dédiée, ou REMPLACEMENT d'une colonne vide (le bloc prend
      // sa place, le spacer disparaît).
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

  /// Alignement courant du contenu d'un bloc.
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
        return _availableTemplates.where((t) => t.isDefault || t.isPremium).toList();
      case 'Simple':
        return _availableTemplates.where((t) => t.category == 'moderne' || !t.isPremium).toList();
      case 'Classique':
        return _availableTemplates.where((t) => t.category == 'classique').toList();
      case 'Professionnel':
        return _availableTemplates.where((t) => t.isPremium || t.category == 'entreprise').toList();
      default:
        return _availableTemplates;
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  /// 👮 Écran « Accès restreint » : la personnalisation de la facture est
  /// réservée à l'administrateur et au propriétaire du modèle.
  Widget _buildAccessDeniedScreen() {
    return Scaffold(
      backgroundColor: _bgSurface,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Atelier Personnalisation',
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
                child: const Icon(Icons.lock_outline_rounded,
                    size: 40, color: _primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'Personnalisation réservée',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _onSurface,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
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
    // 👮 Personnalisation réservée à l'administrateur et au propriétaire du
    // modèle : écran bloquant (aucune modification ni sauvegarde possible).
    if (!_accessChecked) {
      return const Scaffold(
        backgroundColor: _bgSurface,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_canCustomize) {
      return _buildAccessDeniedScreen();
    }
    return Scaffold(
      backgroundColor: _bgSurface,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Atelier Personnalisation',
            style: TextStyle(color: _onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          ElevatedButton.icon(
            onPressed: _saveConfig,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.save, size: 16),
            label: const Text('ENREGISTRER',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.8)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : Column(children: [
              Expanded(child: _buildInvoicePreviewArea()),
              _buildBottomControlPanel(),
            ]),
    );
  }

  // ── Zone de prévisualisation ──────────────────────────────────────────────

  Widget _buildInvoicePreviewArea() {
    return Container(
      width: double.infinity,
      color: _bgSurface,
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
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: _shadowBlur,
                        spreadRadius: 2,
                        offset: const Offset(0, 8)),
                    BoxShadow(
                        color: _primary.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(children: [
                  // Image / motif de fond
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
                  // 🏷️ Tampon FIXE : calque au-dessus de TOUS les éléments.
                  if (_showPaidStamp) _buildPaidStamp(),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── EN-TÊTE AVEC DRAG & DROP (Titre, Logo, Info Entreprise) ───────────────

  Widget _buildInvoiceHeader() {
    final headerColor = _workingTemplate.primaryColor;
    return Container(
      color: headerColor,
      padding: const EdgeInsets.all(12),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _DotPatternPainter())),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.swap_horiz, color: Colors.white70, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Glissez pour réorganiser : Titre, Logo & Infos',
                    style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final key in _headerElements)
                  Expanded(
                    flex: key == 'company_info' ? 2 : 1,
                    child: _buildDraggableHeaderElement(key),
                  ),
              ],
            ),
          ],
        ),
      ]),
    );
  }

  Widget _buildDraggableHeaderElement(String key) {
    final isDragging = _draggingHeaderKey == key;
    final isDragOver = _dragOverHeaderKey == key;
    final isSelected = _selectedHeaderKey == key;

    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != key,
      onAcceptWithDetails: (d) => _reorderHeaderElements(d.data, key),
      onMove: (_) => setState(() => _dragOverHeaderKey = key),
      onLeave: (_) => setState(() => _dragOverHeaderKey = null),
      builder: (ctx, candidateData, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            border: isDragOver
                ? Border.all(color: Colors.amberAccent, width: 2)
                : isSelected
                    ? Border.all(color: Colors.white, width: 1.5)
                    : Border.all(color: Colors.transparent, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Draggable<String>(
            data: key,
            feedback: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _workingTemplate.primaryColor.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Opacity(
                  opacity: 0.9,
                  child: _buildHeaderElementContent(key, isFeedback: true),
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.25,
              child: _buildHeaderElementContent(key),
            ),
            onDragStarted: () => setState(() => _draggingHeaderKey = key),
            onDragEnd: (_) => setState(() {
              _draggingHeaderKey = null;
              _dragOverHeaderKey = null;
            }),
            child: GestureDetector(
              onTap: () => setState(() => _selectedHeaderKey = key),
              child: _wrapHeaderWithIndicator(
                key,
                _buildHeaderElementContent(key),
                isBeingDragged: isDragging,
                isSelected: isSelected,
              ),
            ),
          ),
        );
      },
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
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.drag_indicator, size: 10, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderElementContent(String key, {bool isFeedback = false}) {
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
              border: Border.all(color: Colors.white38, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.image_not_supported_outlined, color: Colors.white70, size: 16),
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
          ),
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          child: _customLogoBytes != null
              ? Image.memory(_customLogoBytes!, fit: BoxFit.cover, width: _logoSize, height: _logoSize)
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
              '$_companyAddress\n'
              '$_companyPhone\n'
              '$_companyEmail',
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
                  shadows: [Shadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                )),
            if (_qrPosition == 'header' && _workingTemplate.showPaymentQR)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _buildQRCodeWidget(mini: true),
              ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ── BLOCS DU CORPS DRAGGABLE ──────────────────────────────────────────────

  /// Un bloc est rendu s'il est marqué visible ; le QR Code n'apparaît dans
  /// son bloc dédié que si le placement « autonome » est sélectionné.
  bool _isBlockVisible(String key) {
    if (!(_blockVisibility[key] ?? true)) return false;
    if (key == 'qr_block') {
      return _workingTemplate.showPaymentQR && _qrPosition == 'standalone';
    }
    return true;
  }

  Widget _buildDraggableInvoiceBody() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SECTIONS empilées : chaque section prend toute la largeur et
          // répartit ses blocs (1 à 3) en colonnes SUR SA PROPRE LARGEUR.
          for (var s = 0; s < _sectionsLayout.length; s++) _buildSectionRow(s),
          if (_draggingKey != null) _buildNewSectionDropZone(),
        ],
      ),
    );
  }

  /// Une section : bande pleine largeur contenant 1 à 3 blocs côte à côte
  /// (colonne vide 🧱 acceptée pour scinder la rangée). Déposer un bloc sur
  /// l'espace libre → ajout en fin de cette section.
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
        // Cellules de la rangée : blocs visibles + colonnes vides, dans
        // l'ordre brut de la section (les index servent au remplacement).
        final cells = <Widget>[];
        for (var i = 0; i < rawKeys.length; i++) {
          final key = rawKeys[i];
          if (key == _emptyColumnKey) {
            cells.add(Expanded(child: _buildEmptyColumnCell(s, i)));
          } else if (_isBlockVisible(key)) {
            cells.add(Expanded(
              child: _buildBlockCell(
                  _invoiceBlocks.firstWhere((b) => b.key == key), s),
            ));
          }
        }
        // Section entièrement masquée : zone de dépôt pendant un drag.
        if (cells.isEmpty && _draggingKey != null) {
          cells.add(const Expanded(
            child: SizedBox(
              height: 40,
              child: Center(
                  child: Icon(Icons.add, size: 16, color: _outline)),
            ),
          ));
        }
        // 🧱 Mini-bouton « + colonne vide » (si la section n'est pas pleine).
        if (rawKeys.length < _maxPerSection) {
          cells.add(_buildAddEmptyColumnCell(s));
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
                      style: const TextStyle(fontSize: 7.5, color: _outline)),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cells.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    cells[i],
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Zone sous la dernière section : crée une NOUVELLE section pleine
  /// largeur dédiée au bloc déposé.
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
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.add, size: 14, color: _outline),
            SizedBox(width: 4),
            Text('Nouvelle section (pleine largeur)',
                style: TextStyle(fontSize: 9.5, color: _outline)),
          ]),
        );
      },
    );
  }

  /// 🧱 Colonne vide (spacer) : réserve une fraction de la largeur de la
  /// section sans contenu — permet de scinder une rangée (ex. « Totaux »
  /// à gauche, espace libre à droite). Déposer un bloc dessus le place à
  /// CETTE position (le spacer est consommé) ; le bouton × la supprime.
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
                    isOver
                        ? Icons.move_down_rounded
                        : Icons.view_week_outlined,
                    size: 13,
                    color: isOver ? _tertiaryContainer : _outline),
                const SizedBox(height: 2),
                Text(isOver ? 'Placer ici' : 'Vide',
                    style: const TextStyle(
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
                    child: const Icon(Icons.close, size: 9, color: _outline),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  /// 🧱 Mini-bouton « + » en fin de rangée : ajoute une colonne vide à la
  /// section (scinder la rangée). Pendant un drag, déposer dessus ajoute
  /// le bloc en fin de section (le DragTarget parent couvre la zone).
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
            child: const Center(
                child: Icon(Icons.add, size: 13, color: _outline)),
          ),
        ),
      ),
    );
  }

  /// 🧱 Ajoute une colonne vide en fin de section [s].
  void _addEmptyColumn(int s) {
    if (s < 0 || s >= _sectionsLayout.length) return;
    if (_sectionsLayout[s].length >= _maxPerSection) return;
    setState(() => _sectionsLayout[s].add(_emptyColumnKey));
    _saveConfig();
  }

  /// 🧱 Supprime la colonne vide d'index [index] dans la section [s].
  /// La section est retirée si elle ne contient plus aucune colonne.
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

  /// Une « cellule » : cible de dépôt (insertion avant ce bloc, dans la
  /// section de celui-ci) + source draggable — le glisser fonctionne au sein
  /// d'une section et entre les sections.
  Widget _buildBlockCell(_InvoiceBlock block, int section) {
    final align = _alignOf(block.key);
    final isDragging = _draggingKey == block.key;
    final isDragOver = _dragOverKey == block.key;
    final isSelected = _selectedBlockKey == block.key;

    return DragTarget<String>(
      onWillAcceptWithDetails: (d) {
        final sec = _sectionsLayout[section];
        // Réordonnancement au sein de la même section : toujours autorisé.
        if (sec.contains(d.data)) return true;
        // Sinon la section ne doit pas dépasser _maxPerSection blocs.
        return sec.length < _maxPerSection;
      },
      onAcceptWithDetails: (d) =>
          _moveBlock(d.data, section, beforeKey: block.key),
      onMove: (_) => setState(() => _dragOverKey = block.key),
      onLeave: (_) => setState(() => _dragOverKey = null),
      builder: (ctx, candidateData, _) {
        return Draggable<String>(
          data: block.key,
          onDragStarted: () => setState(() => _draggingKey = block.key),
          onDragEnd: (_) => setState(() {
            _draggingKey = null;
            _dragOverKey = null;
            _dragOverSection = null;
          }),
          feedback: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
            child: Container(
              width: 190,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Opacity(opacity: 0.9, child: block.builder(align)),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: _wrapBlock(block, block.builder(align), isDragOver,
                isBeingDragged: isDragging, isSelected: isSelected),
          ),
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedBlockKey = block.key);
              _showElementEditorSheet(block.key);
            },
            child: _wrapBlock(
              block,
              block.builder(align),
              isDragOver,
              isBeingDragged: isDragging,
              isSelected: isSelected,
            ),
          ),
        );
      },
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
                  child: const Icon(Icons.drag_indicator, size: 14, color: _primary),
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
                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Blocs individuels du corps ────────────────────────────────────────────

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
          color: _workingTemplate.primaryColor.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Row(children: [
            Expanded(flex: descFlex, child: _th('Description')),
            Expanded(flex: qtyFlex, child: _th('QTÉ', align: TextAlign.center)),
            Expanded(
                flex: priceFlex, child: _th('Prix HT', align: TextAlign.right)),
            Expanded(flex: priceFlex, child: _th('Total', align: TextAlign.right)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _surfaceVariant.withValues(alpha: 0.5))),
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
                  textAlign: TextAlign.center,
                  maxLines: 1,
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
    return Column(
      crossAxisAlignment: _ca(align),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Flexible(
                    child: Text('Sous-Total HT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('150 000 FCFA',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: valueStyle),
                  ),
                ]),
              ),
              if (_workingTemplate.showTaxDetails)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Flexible(
                      child: Text('TVA (18%)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('27 000 FCFA',
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: valueStyle),
                    ),
                  ]),
                ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: _workingTemplate.primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(children: [
                  Flexible(
                    child: Text('TOTAL TTC',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: (_customFontSize * 0.75).clamp(7.0, 11.0),
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        _workingTemplate.showTaxDetails
                            ? '177 000 FCFA'
                            : '150 000 FCFA',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: (_customFontSize * 0.75).clamp(7.0, 11.0),
                            fontWeight: FontWeight.w800)),
                  ),
                ]),
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
    // Bloc dédié : rendu uniquement quand le QR est en placement « autonome ».
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.qr_code_2, size: 20, color: Colors.black87),
            SizedBox(width: 4),
            Text('PAYQR', style: TextStyle(color: Colors.black87, fontSize: 7, fontWeight: FontWeight.bold)),
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
      // Wrap : s'adapte aux colonnes étroites (icône / textes à la ligne).
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
            children: const [
              Text('Payer via Mobile Money',
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: _primary)),
              Text('Scanner le QR Code sécurisé',
                  style: TextStyle(fontSize: 7.5, color: _onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  /// 🏷️ Tampon FIXE : calque positionné AU-DESSUS de tous les éléments de la
  /// facture (dernier enfant du Stack). IgnorePointer → il ne bloque ni le
  /// drag & drop des blocs, ni les taps.
  Widget _buildPaidStamp() {
    return Positioned(
      top: 150,
      left: 40,
      right: 40,
      child: IgnorePointer(
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
                style: TextStyle(
                    color: _stampColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4)),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomStripe() {
    return Container(
      height: 5,
      color: _workingTemplate.primaryColor,
      child: Row(children: [
        const SizedBox(width: 16),
        Transform(transform: Matrix4.skewX(-0.3),
            child: Container(width: 28, color: Colors.white24)),
        const SizedBox(width: 4),
        Transform(transform: Matrix4.skewX(-0.3),
            child: Container(width: 14, color: Colors.white24)),
      ]),
    );
  }

  // ── Panneau inférieur (Toolbar & Catégories) ──────────────────────────────

  Widget _buildBottomControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -6))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildCategoryTabs(),
        _buildTemplateCarousel(),
        Divider(height: 1, color: _surfaceVariant.withValues(alpha: 0.5)),
        _buildToolBar(),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 6),
      ]),
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
                        color: isSel ? _primary : Colors.transparent, width: 2.5)),
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
                    ? [BoxShadow(
                        color: _primary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2))]
                    : [],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(children: [
                Column(children: [
                  Container(
                    height: 22,
                    color: t.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.white24, shape: BoxShape.circle)),
                      Container(width: 18, height: 3, color: Colors.white60),
                    ]),
                  ),
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(width: 32, height: 3, color: Colors.grey[400]),
                        const SizedBox(height: 3),
                        Container(width: 46, height: 2, color: Colors.grey[300]),
                        const SizedBox(height: 4),
                        Container(height: 10, color: Colors.grey[200]),
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(width: 20, height: 5, color: t.primaryColor),
                        ),
                      ]),
                    ),
                  ),
                ]),
                if (t.isPremium)
                  Positioned(
                    top: 3, right: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
        _toolItem(Icons.palette_outlined, 'Couleur', 'couleur', _showColorPickerSheet),
        _toolItem(Icons.image_outlined, 'Logo', 'logo', _showLogoSettingsSheet),
        _toolItem(Icons.text_fields_outlined, 'Taille police', 'police', _showFontSizeSheet),
        _toolItem(Icons.format_align_left, 'Alignement', 'alignement', _showAlignmentSheet),
        _toolItem(Icons.texture_outlined, 'Ombres & Zoom', 'ombres', _showShadowSheet),
        _toolItem(Icons.draw_outlined, 'Signature', 'signature', _showSignatureSheet, badge: _showSignatureLine),
        _toolItem(Icons.gavel_outlined, 'Mentions légales', 'legale', _showLegalMentionsSheet),
        _toolItem(Icons.qr_code_2_outlined, 'QR Code', 'qrcode', _showQRCodeSheet, badge: _workingTemplate.showPaymentQR),
        _toolItem(Icons.wallpaper_outlined, 'Image de fond', 'fond', _showBackgroundImageSheet, badge: _background.hasCustomImage || _background.hasPreset),
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
                color: active ? _primary.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 24, color: active ? _primary : _onSurfaceVariant),
            ),
            if (badge)
              Positioned(
                top: -1, right: -1,
                child: Container(
                  width: 8, height: 8,
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

  // ── Éditeur rapide d'un bloc (tap sur un bloc du corps) ───────────────────

  String _blockTitle(String key) {
    if (key == _emptyColumnKey) return 'Colonne vide';
    for (final b in _invoiceBlocks) {
      if (b.key == key) return b.title;
    }
    return key;
  }

  void _showElementEditorSheet(String key) {
    final clientCtrl = TextEditingController(text: _clientName);
    final signatoryCtrl = TextEditingController(text: _signatoryTitle);
    final legalCtrl = TextEditingController(text: _customLegalText);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.tune, color: _primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_blockTitle(key),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15.5)),
                  ),
                ]),
                const SizedBox(height: 6),
                if (key != 'qr_block')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Afficher ce bloc',
                        style: TextStyle(fontSize: 13.5)),
                    value: _blockVisibility[key] ?? true,
                    activeThumbColor: _primary,
                    onChanged: (val) {
                      setSS(() => _blockVisibility[key] = val);
                      setState(() {
                        _blockVisibility[key] = val;
                        if (key == 'signature_block') _showSignatureLine = val;
                      });
                      _saveConfig();
                    },
                  ),
                const SizedBox(height: 4),
                Row(children: [
                  const Text('Alignement :',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setSS(() => _blockAlignment[key] = TextAlign.left);
                      setState(() => _blockAlignment[key] = TextAlign.left);
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
                      setSS(() => _blockAlignment[key] = TextAlign.center);
                      setState(() => _blockAlignment[key] = TextAlign.center);
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
                      setSS(() => _blockAlignment[key] = TextAlign.right);
                      setState(() => _blockAlignment[key] = TextAlign.right);
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
              ]),
        ),
      ),
    );
  }

  // ── Modales & Bottom Sheets ───────────────────────────────────────────────

  void _showColorPickerSheet() {
    setState(() => _activeTool = 'couleur');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Palette de Couleur Principale',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Applique la teinte sélectionnée sur les éléments clés de la facture.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: _paletteColors.map((color) {
                final isSel = _workingTemplate.primaryColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _workingTemplate = InvoiceTemplate(
                        id: _workingTemplate.id, name: _workingTemplate.name,
                        description: _workingTemplate.description, primaryColor: color,
                        textColor: _workingTemplate.textColor, backgroundColor: _workingTemplate.backgroundColor,
                        showLogo: _workingTemplate.showLogo, showTaxDetails: _workingTemplate.showTaxDetails,
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
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isSel ? Colors.black : Colors.transparent,
                            width: isSel ? 3.5 : 0)),
                    child: isSel
                        ? const Icon(Icons.check, color: Colors.white, size: 22)
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Réglages du Logo d'Entreprise",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text("Afficher le Logo"),
              value: _workingTemplate.showLogo,
              activeThumbColor: _primary,
              onChanged: (val) {
                setSS(() {});
                setState(() {
                  _workingTemplate = InvoiceTemplate(
                    id: _workingTemplate.id, name: _workingTemplate.name,
                    description: _workingTemplate.description, primaryColor: _workingTemplate.primaryColor,
                    textColor: _workingTemplate.textColor, backgroundColor: _workingTemplate.backgroundColor,
                    showLogo: val, showTaxDetails: _workingTemplate.showTaxDetails,
                    showPaymentTerms: _workingTemplate.showPaymentTerms,
                    showPaymentQR: _workingTemplate.showPaymentQR, isPremium: _workingTemplate.isPremium,
                  );
                });
                _saveConfig();
              },
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Taille du logo: '),
              Expanded(
                child: Slider(
                  value: _logoSize,
                  min: 32, max: 72, divisions: 10, activeColor: _primary,
                  onChanged: (val) {
                    setSS(() => _logoSize = val);
                    setState(() {});
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
                final picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  setState(() => _customLogoBytes = bytes);
                  _saveConfig();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nouveau logo téléversé !')));
                  }
                }
              },
              icon: const Icon(Icons.upload_file, color: _primary),
              label: const Text('Téléverser un logo (PNG / JPEG)', style: TextStyle(color: _primary)),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Taille de Police Globale',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${_customFontSize.toInt()} pt',
                  style: const TextStyle(
                      color: _primary, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 6),
            const Text('Ajuste dynamiquement la taille des textes de la facture.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 14),
            Slider(
              value: _customFontSize.clamp(9.0, 20.0),
              min: 9, max: 20, divisions: 11, activeColor: _primary,
              onChanged: (val) {
                setSS(() => _customFontSize = val);
                setState(() {
                  _workingTemplate = InvoiceTemplate(
                    id: _workingTemplate.id, name: _workingTemplate.name,
                    description: _workingTemplate.description, primaryColor: _workingTemplate.primaryColor,
                    textColor: _workingTemplate.textColor, backgroundColor: _workingTemplate.backgroundColor,
                    showLogo: _workingTemplate.showLogo, showTaxDetails: _workingTemplate.showTaxDetails,
                    showPaymentTerms: _workingTemplate.showPaymentTerms,
                    showPaymentQR: _workingTemplate.showPaymentQR,
                    fontSize: val, isPremium: _workingTemplate.isPremium,
                  );
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

  void _showShadowSheet() {
    setState(() => _activeTool = 'ombres');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Style & Zoom du Canevas A4",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 14),
            Row(children: [
              const SizedBox(width: 120, child: Text('Zoom de la page: ')),
              Expanded(child: Slider(
                value: _zoom, min: 0.5, max: 1.1, divisions: 12, activeColor: _primary,
                onChanged: (val) {
                  setSS(() {});
                  setState(() => _zoom = val);
                },
              )),
              Text('${(_zoom * 100).toInt()}%'),
            ]),
            Row(children: [
              const SizedBox(width: 120, child: Text('Intensité d\'ombre: ')),
              Expanded(child: Slider(
                value: _shadowBlur, min: 4, max: 40, divisions: 18, activeColor: _primary,
                onChanged: (val) {
                  setSS(() {});
                  setState(() => _shadowBlur = val);
                },
              )),
              Text('${_shadowBlur.toInt()}px'),
            ]),
            Row(children: [
              const SizedBox(width: 120, child: Text('Arrondi feuille: ')),
              Expanded(child: Slider(
                value: _paperRadius, min: 0, max: 24, divisions: 12, activeColor: _primary,
                onChanged: (val) {
                  setSS(() {});
                  setState(() => _paperRadius = val);
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

  // ── Outil « Alignement » : colonnes du corps + alignement par bloc ────────

  void _showAlignmentSheet() {
    setState(() => _activeTool = 'alignement');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Alignement des blocs',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text(
                'Alignement du contenu de chaque bloc. Astuce : glissez-déposez '
                'les blocs sur la facture — chaque section (pleine largeur) '
                'peut afficher 1 à 3 blocs côte à côte. Ajoutez une colonne '
                'vide (+) dans une section pour scinder la rangée.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 14),
            // 🧱 Les colonnes vides (spacers) n'ont pas d'alignement.
            ..._sectionsLayout
                .expand((s) => s)
                .where((key) => key != _emptyColumnKey)
                .where(_isBlockVisible)
                .map((key) => _alignmentRow(key, setSS)),
            const SizedBox(height: 10),
          ]),
        ),
      ),
    ).whenComplete(() => setState(() => _activeTool = ''));
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
            setSS(() => _blockAlignment[key] = sel.first);
            setState(() => _blockAlignment[key] = sel.first);
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Tampon & Signature de l'Émetteur",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Afficher le Tampon d\'état'),
              value: _showPaidStamp,
              activeThumbColor: _primary,
              onChanged: (val) {
                setSS(() => _showPaidStamp = val);
                setState(() => _showPaidStamp = val);
                _saveConfig();
              },
            ),
            if (_showPaidStamp)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: ['PAYÉ', 'DEVIS', 'VALIDE', 'URGENT', 'REÇU'].map((txt) {
                    final isSel = _stampText == txt;
                    return ChoiceChip(
                      label: Text(txt),
                      selected: isSel,
                      selectedColor: _primary,
                      labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black),
                      onSelected: (_) {
                        setSS(() => _stampText = txt);
                        setState(() {});
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
                setSS(() => _showSignatureLine = val);
                setState(() {
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Mentions Légales & Conformité OHADA',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Détails des Taxes & TVA 18% SYSCOHADA'),
              subtitle: const Text('Affiche le calcul explicite de la TVA et du Hors-Taxe'),
              value: _workingTemplate.showTaxDetails, activeThumbColor: _primary,
              onChanged: (val) {
                setSS(() {});
                setState(() {
                  _workingTemplate = InvoiceTemplate(
                    id: _workingTemplate.id, name: _workingTemplate.name,
                    description: _workingTemplate.description, primaryColor: _workingTemplate.primaryColor,
                    textColor: _workingTemplate.textColor, backgroundColor: _workingTemplate.backgroundColor,
                    showLogo: _workingTemplate.showLogo, showTaxDetails: val,
                    showPaymentTerms: _workingTemplate.showPaymentTerms,
                    showPaymentQR: _workingTemplate.showPaymentQR,
                    isPremium: _workingTemplate.isPremium,
                  );
                });
                _saveConfig();
              },
            ),
            SwitchListTile(
              title: const Text('Conditions & Délais de Paiement'),
              subtitle: const Text('Affiche les clauses de règlement'),
              value: _workingTemplate.showPaymentTerms, activeThumbColor: _primary,
              onChanged: (val) {
                setSS(() {});
                setState(() {
                  _workingTemplate = InvoiceTemplate(
                    id: _workingTemplate.id, name: _workingTemplate.name,
                    description: _workingTemplate.description, primaryColor: _workingTemplate.primaryColor,
                    textColor: _workingTemplate.textColor, backgroundColor: _workingTemplate.backgroundColor,
                    showLogo: _workingTemplate.showLogo, showTaxDetails: _workingTemplate.showTaxDetails,
                    showPaymentTerms: val, showPaymentQR: _workingTemplate.showPaymentQR,
                    isPremium: _workingTemplate.isPremium,
                  );
                });
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('QR Code de Paiement Sécurisé',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text(
                'Permet à vos clients de scanner la facture pour payer instantanément par Mobile Money.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 14),
            SwitchListTile(
              title: const Text('Afficher le QR Code PayQR'),
              value: _workingTemplate.showPaymentQR, activeThumbColor: _primary,
              onChanged: (val) {
                setSS(() {});
                setState(() {
                  _workingTemplate = InvoiceTemplate(
                    id: _workingTemplate.id, name: _workingTemplate.name,
                    description: _workingTemplate.description, primaryColor: _workingTemplate.primaryColor,
                    textColor: _workingTemplate.textColor, backgroundColor: _workingTemplate.backgroundColor,
                    showLogo: _workingTemplate.showLogo, showTaxDetails: _workingTemplate.showTaxDetails,
                    showPaymentTerms: _workingTemplate.showPaymentTerms, showPaymentQR: val,
                    isPremium: _workingTemplate.isPremium,
                  );
                });
                _saveConfig();
              },
            ),
            if (_workingTemplate.showPaymentQR)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text('Emplacement du QR: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _qrPosition,
                      items: const [
                        DropdownMenuItem(value: 'header', child: Text('En-tête')),
                        DropdownMenuItem(value: 'totals', child: Text('Bloc Totaux')),
                        DropdownMenuItem(value: 'footer', child: Text('Pied de page')),
                        DropdownMenuItem(value: 'standalone', child: Text('Bloc autonome')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSS(() => _qrPosition = val);
                          setState(() {});
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

// ── Modèle d'un bloc draggable ────────────────────────────────────────────

class _InvoiceBlock {
  final String key;
  final String title;

  /// Chaque constructeur de bloc reçoit l'alignement choisi pour ce bloc
  /// (outil « Alignement »).
  final Widget Function(TextAlign align) builder;
  const _InvoiceBlock({
    required this.key,
    required this.title,
    required this.builder,
  });
}

// ── Peintre du motif pointillés (header) ─────────────────────────────────

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

/// 🧱 Bordure pointillée (colonnes vides du drag & drop).
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
