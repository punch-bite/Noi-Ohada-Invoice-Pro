// lib/screens/customization/template_workspace_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/company.dart';
import '../../models/invoice_layout.dart';
import '../../models/invoice_template.dart';
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
  static const Color _secondary = Color(0xFF6B5773);
  static const Color _bgSurface = Color(0xFFFFF7FC);
  static const Color _surfaceVariant = Color(0xFFE8E0E6);
  static const Color _onSurface = Color(0xFF1E1A1F);
  static const Color _onSurfaceVariant = Color(0xFF4C444E);
  static const Color _tertiaryContainer = Color(0xFFBAAB6D);
  static const Color _onTertiaryContainer = Color(0xFF493F0B);
  static const Color _outline = Color(0xFF7D747F);

  final DatabaseService _db = DatabaseService();
  Company? _company;
  late InvoiceLayoutConfig _layoutConfig;
  late InvoiceTemplate _workingTemplate;
  TemplateBackgroundSettings _background = const TemplateBackgroundSettings();

  bool _isLoading = true;
  double _zoom = 0.82;
  double _shadowBlur = 24.0;
  double _paperRadius = 14.0;
  double _logoSize = 46.0;
  Uint8List? _customLogoBytes;

  LayoutElement? _selectedElement;
  String _selectedCategory = 'Recommandé';
  String _activeTool = '';
  double _customFontSize = 12.0;

  // Header Drag & Drop state
  List<String> _headerElements = ['logo', 'company_info', 'invoice_title'];
  String? _draggingHeaderKey;
  String? _dragOverHeaderKey;
  String? _selectedHeaderKey;

  // Body Drag & Drop state
  int? _draggingBlockIndex;
  int? _dragOverBlockIndex;

  // Signature & Stamp state
  bool _showPaidStamp = true;
  String _stampText = 'PAYÉ';
  Color _stampColor = const Color(0xFFBAAB6D);
  bool _showSignatureLine = true;
  String _signatoryTitle = 'Direction Générale';

  // Legal & QR state
  String _customLegalText = 'Paiement sous 30 jours net. Pénalités de retard applicables selon normes SYSCOHADA.';
  String _qrPosition = 'header'; // 'header', 'totals', 'footer'

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
    _loadData();
  }

  void _initBlocks() {
    _invoiceBlocks = [
      _InvoiceBlock(key: 'billing_info', builder: _buildBillingInfoBlock),
      _InvoiceBlock(key: 'items_table', builder: _buildItemsTableBlock),
      _InvoiceBlock(key: 'totals', builder: _buildTotalsBlock),
      _InvoiceBlock(key: 'footer', builder: _buildFooterBlock),
    ];
  }

  Future<void> _loadData() async {
    final company = await _db.getCompany();
    final custom = await TemplateCustomService.loadCustom(widget.template.id);
    final templates = InvoiceTemplate.getDefaultTemplates();
    if (!mounted) return;
    setState(() {
      _company = company;
      if (custom.positions.isNotEmpty) {
        _layoutConfig = InvoiceLayoutConfig.fromMap(custom.positions);
        if (custom.positions['header_elements_order'] is List) {
          _headerElements = List<String>.from(custom.positions['header_elements_order']);
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
        if (custom.positions['show_paid_stamp'] != null) {
          _showPaidStamp = custom.positions['show_paid_stamp'] as bool;
        }
        if (custom.positions['show_signature_line'] != null) {
          _showSignatureLine = custom.positions['show_signature_line'] as bool;
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
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    final updatedPositions = _layoutConfig.toMap();
    updatedPositions['header_elements_order'] = _headerElements;
    updatedPositions['qr_position'] = _qrPosition;
    updatedPositions['custom_legal_text'] = _customLegalText;
    updatedPositions['stamp_text'] = _stampText;
    updatedPositions['show_paid_stamp'] = _showPaidStamp;
    updatedPositions['show_signature_line'] = _showSignatureLine;
    updatedPositions['logo_size'] = _logoSize;
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

  void _reorderBlocks(int from, int to) {
    setState(() {
      final item = _invoiceBlocks.removeAt(from);
      _invoiceBlocks.insert(to, item);
      _draggingBlockIndex = null;
      _dragOverBlockIndex = null;
    });
    _saveConfig();
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

  @override
  Widget build(BuildContext context) {
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
    final companyName = _company?.name ?? 'Noi Concept digital';
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
              '${_company?.address ?? "Doww Essos Yaoundé Cameroun"}\n'
              '${_company?.phone ?? "+237620409383"}\n'
              '${_company?.email ?? "contact@noiconcept.com"}',
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
            Text('FACTURE',
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

  Widget _buildDraggableInvoiceBody() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: List.generate(_invoiceBlocks.length, (index) {
          final block = _invoiceBlocks[index];
          final isDragging = _draggingBlockIndex == index;
          final isDragOver = _dragOverBlockIndex == index;
          return DragTarget<int>(
            onWillAcceptWithDetails: (d) => d.data != index,
            onAcceptWithDetails: (d) => _reorderBlocks(d.data, index),
            onMove: (_) => setState(() => _dragOverBlockIndex = index),
            onLeave: (_) => setState(() => _dragOverBlockIndex = null),
            builder: (ctx, candidateData, _) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 2),
                decoration: isDragOver
                    ? BoxDecoration(
                        border: Border(
                            top: BorderSide(
                                color: _primary.withValues(alpha: 0.6), width: 2.5)))
                    : null,
                child: Draggable<int>(
                  data: index,
                  axis: Axis.vertical,
                  onDragStarted: () => setState(() => _draggingBlockIndex = index),
                  onDragEnd: (_) => setState(() {
                    _draggingBlockIndex = null;
                    _dragOverBlockIndex = null;
                  }),
                  feedback: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 80,
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Opacity(opacity: 0.85, child: block.builder())),
                    ),
                  ),
                  childWhenDragging:
                      Opacity(opacity: 0.35, child: _wrapBlock(block.builder(), isDragOver)),
                  child: _wrapBlock(block.builder(), isDragOver, isBeingDragged: isDragging),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _wrapBlock(Widget child, bool isDragOver, {bool isBeingDragged = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: isBeingDragged ? _primary.withValues(alpha: 0.04) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 4),
          child: Icon(Icons.drag_indicator,
              size: 14, color: Colors.grey.withValues(alpha: 0.5)),
        ),
        Expanded(child: child),
      ]),
    );
  }

  // ── Blocs individuels du corps ────────────────────────────────────────────

  Widget _buildBillingInfoBlock() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FACTURÉ À',
                style: TextStyle(
                    fontSize: (_customFontSize * 0.65).clamp(7.0, 10.0),
                    fontWeight: FontWeight.w700,
                    color: _onSurfaceVariant,
                    letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text('Client Exemple SARL',
                style: TextStyle(
                    fontSize: (_customFontSize * 0.85).clamp(8.5, 12.0),
                    color: _onSurface,
                    fontWeight: FontWeight.w600)),
            Text('N° RCCM: CM-DOU-2024-B123\nDouala, Cameroun',
                style: TextStyle(
                    fontSize: (_customFontSize * 0.70).clamp(7.0, 10.0),
                    color: _onSurfaceVariant)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _metaRow('FACTURE N°', 'INV000342'),
          const SizedBox(height: 3),
          _metaRow('DATE', '26/03/2025'),
          const SizedBox(height: 3),
          _metaRow('ÉCHÉANCE', '02/04/2025'),
        ]),
      ]),
    );
  }

  Widget _metaRow(String label, String value) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
          width: 68,
          child: Text(label,
              style: TextStyle(
                  fontSize: (_customFontSize * 0.65).clamp(7.0, 10.0),
                  fontWeight: FontWeight.w700,
                  color: _onSurfaceVariant,
                  letterSpacing: 0.5))),
      const SizedBox(width: 4),
      Text(value,
          style: TextStyle(
              fontSize: (_customFontSize * 0.75).clamp(8.0, 11.0),
              color: _onSurface,
              fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildItemsTableBlock() {
    return Column(children: [
      Container(
        color: _workingTemplate.primaryColor.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(children: [
          Expanded(child: _th('Description')),
          SizedBox(width: 32, child: _th('QTÉ', align: TextAlign.center)),
          SizedBox(width: 52, child: _th('Prix HT', align: TextAlign.right)),
          SizedBox(width: 52, child: _th('Total', align: TextAlign.right)),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _surfaceVariant.withValues(alpha: 0.5))),
        ),
        child: Row(children: [
          Expanded(
            child: Text('Prestation de conseil & Audit informatique',
                style: TextStyle(fontSize: (_customFontSize * 0.72).clamp(7.5, 11.0), color: _onSurface)),
          ),
          SizedBox(width: 32, child: Text('1', textAlign: TextAlign.center, style: TextStyle(fontSize: (_customFontSize * 0.72).clamp(7.5, 11.0)))),
          SizedBox(width: 52, child: Text('150 000', textAlign: TextAlign.right, style: TextStyle(fontSize: (_customFontSize * 0.72).clamp(7.5, 11.0)))),
          SizedBox(width: 52, child: Text('150 000', textAlign: TextAlign.right, style: TextStyle(fontSize: (_customFontSize * 0.72).clamp(7.5, 11.0)))),
        ]),
      ),
    ]);
  }

  Widget _th(String t, {TextAlign align = TextAlign.left}) {
    return Text(t,
        textAlign: align,
        style: TextStyle(
            fontSize: (_customFontSize * 0.65).clamp(7.0, 10.0),
            fontWeight: FontWeight.w700,
            color: _workingTemplate.primaryColor));
  }

  Widget _buildTotalsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
              width: 160,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Sous-Total HT',
                        style: TextStyle(
                            fontSize: (_customFontSize * 0.7).clamp(7.5, 10.5),
                            color: _onSurfaceVariant,
                            fontWeight: FontWeight.w600)),
                    Text('150 000 FCFA', style: TextStyle(fontSize: (_customFontSize * 0.7).clamp(7.5, 10.5), color: _onSurface)),
                  ]),
                ),
                if (_workingTemplate.showTaxDetails)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('TVA (18%)',
                          style: TextStyle(
                              fontSize: (_customFontSize * 0.7).clamp(7.5, 10.5),
                              color: _onSurfaceVariant,
                              fontWeight: FontWeight.w600)),
                      Text('27 000 FCFA', style: TextStyle(fontSize: (_customFontSize * 0.7).clamp(7.5, 10.5), color: _onSurface)),
                    ]),
                  ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: _workingTemplate.primaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('TOTAL TTC',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: (_customFontSize * 0.75).clamp(8.0, 11.0),
                            fontWeight: FontWeight.w800)),
                    Text(_workingTemplate.showTaxDetails ? '177 000 FCFA' : '150 000 FCFA',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: (_customFontSize * 0.75).clamp(8.0, 11.0),
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ])),
        ),
        if (_qrPosition == 'totals' && _workingTemplate.showPaymentQR)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildQRCodeWidget(),
          ),
      ],
    );
  }

  Widget _buildFooterBlock() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Divider(height: 1, color: _surfaceVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_workingTemplate.showPaymentTerms)
                    Text('Conditions & Délais de Paiement',
                        style: TextStyle(
                            fontSize: (_customFontSize * 0.65).clamp(7.0, 10.0),
                            fontWeight: FontWeight.w700,
                            color: _onSurface)),
                  Text(_customLegalText,
                      style: TextStyle(
                          fontSize: (_customFontSize * 0.62).clamp(6.5, 9.5),
                          color: _onSurfaceVariant,
                          height: 1.3)),
                ],
              ),
            ),
            if (_showSignatureLine)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  children: [
                    Text('Signature & Cachet',
                        style: TextStyle(
                            fontSize: (_customFontSize * 0.60).clamp(6.5, 9.0),
                            fontWeight: FontWeight.w700,
                            color: _onSurfaceVariant)),
                    const SizedBox(height: 14),
                    Container(
                      width: 70,
                      height: 1,
                      color: _onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(_signatoryTitle,
                        style: TextStyle(
                            fontSize: (_customFontSize * 0.55).clamp(6.0, 8.5),
                            color: _onSurfaceVariant)),
                  ],
                ),
              ),
          ],
        ),
        if (_qrPosition == 'footer' && _workingTemplate.showPaymentQR)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _buildQRCodeWidget(),
          ),
      ]),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.qr_code_2, size: 28, color: Colors.black),
          ),
          const SizedBox(width: 8),
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

  Widget _buildPaidStamp() {
    return Positioned(
      top: 150,
      left: 50,
      right: 50,
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
                setState(() {});
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
                setState(() {});
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
  final Widget Function() builder;
  const _InvoiceBlock({required this.key, required this.builder});
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
