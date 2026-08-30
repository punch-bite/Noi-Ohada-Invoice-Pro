// lib/screens/customization/template_workspace_screen.dart
//
// 🧩 ESPACE DE PERSONNALISATION DRAG & DROP — « Personnaliser — {modèle} ».
//
// Refonte conforme au design system glass indigo → violet :
//   • Canvas A4 avec grille de repères 4×4 subtile
//   • Éléments déplaçables au doigt (Draggable/DragTarget — échange de slot),
//     sélection au tap (anneau primaire + étiquette)
//   • Barre inférieure : bouton « Éléments » + zoom, ou propriétés de
//     l'élément sélectionné (visibilité, colonne, ordre)
//   • Bottom sheet « Éléments » : chips par bloc + réglages de page

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:noi_ohada_invoice_pro/services/invoice_layout_engine.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_template.dart';
import '../../models/invoice_layout.dart';
import '../../models/company.dart';
import '../../services/database_service.dart';
import '../../services/template_custom_service.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/invoice_renderer.dart';

class TemplateWorkspaceScreen extends StatefulWidget {
  final InvoiceTemplate template;

  const TemplateWorkspaceScreen({super.key, required this.template});

  @override
  State<TemplateWorkspaceScreen> createState() =>
      _TemplateWorkspaceScreenState();
}

class _TemplateWorkspaceScreenState extends State<TemplateWorkspaceScreen> {
  final DatabaseService _db = DatabaseService();
  Company? _company;
  late InvoiceLayoutConfig _layoutConfig;
  bool _isLoading = true;
  double _zoom = 1.0;
  LayoutElement? _selected;

  @override
  void initState() {
    super.initState();
    _layoutConfig = InvoiceLayoutConfig.defaultLayout();
    _loadData();
  }

  Future<void> _loadData() async {
    final company = await _db.getCompany();
    final custom = await TemplateCustomService.loadCustom(widget.template.id);
    if (!mounted) return;
    setState(() {
      _company = company;
      if (custom.positions.isNotEmpty) {
        _layoutConfig = InvoiceLayoutConfig.fromMap(custom.positions);
      }
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    await TemplateCustomService.saveCustom(
      widget.template.id,
      positions: _layoutConfig.toMap(),
      mapping: const {},
    );
  }

  void _notifySaved() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Personnalisation enregistrée'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Réinitialise le layout par défaut (action AppBar).
  Future<void> _resetConfig() async {
    await TemplateCustomService.clearCustom(widget.template.id);
    if (!mounted) return;
    setState(() {
      _layoutConfig = InvoiceLayoutConfig.defaultLayout();
      _selected = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Layout réinitialisé'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Drag & drop : échange l'élément déposé avec l'occupant du slot cible
  /// (block / colonne / ordre) — le modèle reste aligné avec l'impression.
  void _onElementMoved(
    LayoutElement dragged,
    LayoutBlock targetBlock,
    int targetColumn,
    int targetOrder,
  ) {
    final draggedPos = _layoutConfig.positions[dragged];
    if (draggedPos == null) return;
    LayoutElement? occupant;
    for (final entry in _layoutConfig.positions.entries) {
      final p = entry.value;
      if (entry.key != dragged &&
          p.blockIndex == targetBlock.index &&
          p.column == targetColumn &&
          p.order == targetOrder) {
        occupant = entry.key;
        break;
      }
    }
    setState(() {
      final positions =
          Map<LayoutElement, ElementPosition>.of(_layoutConfig.positions);
      if (occupant != null) {
        // Swap : l'occupant prend la place d'origine du dragged.
        positions[occupant] = draggedPos;
        positions[dragged] = ElementPosition(
          blockIndex: targetBlock.index,
          column: targetColumn,
          colSpan: draggedPos.colSpan,
          order: targetOrder,
          visible: draggedPos.visible,
        );
      } else {
        // Slot vide : on déplace simplement l'élément.
        positions[dragged] = draggedPos.copyWith(
          blockIndex: targetBlock.index,
          column: targetColumn,
          order: targetOrder,
        );
      }
      _layoutConfig = _layoutConfig.copyWith(positions: positions);
      _selected = dragged;
    });
    _saveConfig();
  }

  /// Déplace un élément dans son bloc (±1 dans l'ordre des rangées).
  void _moveOrder(LayoutElement element, int delta) {
    final pos = _layoutConfig.positions[element];
    if (pos == null) return;
    LayoutElement? found;
    for (final entry in _layoutConfig.positions.entries) {
      final p = entry.value;
      if (entry.key != element &&
          p.blockIndex == pos.blockIndex &&
          p.order == pos.order + delta) {
        found = entry.key;
        break;
      }
    }
    // Copie finale : `other` est réassigné dans la boucle, la promotion de
    // type ne s'applique donc pas dans la closure `setState` sans passer
    // par cette variable finale (idiome Dart pour la null-safety).
    final other = found;
    if (other == null) return;
    setState(() {
      final positions =
          Map<LayoutElement, ElementPosition>.of(_layoutConfig.positions);
      positions[other] = positions[other]!.copyWith(order: pos.order);
      positions[element] = pos.copyWith(order: pos.order + delta);
      _layoutConfig = _layoutConfig.copyWith(positions: positions);
    });
    _saveConfig();
  }

  /// Change la colonne / la largeur d'un élément.
  void _setColumn(LayoutElement element, {required int column, int? colSpan}) {
    final pos = _layoutConfig.positions[element];
    if (pos == null) return;
    setState(() {
      final positions =
          Map<LayoutElement, ElementPosition>.of(_layoutConfig.positions);
      positions[element] = pos.copyWith(column: column, colSpan: colSpan);
      _layoutConfig = _layoutConfig.copyWith(positions: positions);
    });
    _saveConfig();
  }

  /// Bascule la visibilité d'un élément.
  void _toggleVisible(LayoutElement element) {
    final pos = _layoutConfig.positions[element];
    if (pos == null) return;
    setState(() {
      final positions =
          Map<LayoutElement, ElementPosition>.of(_layoutConfig.positions);
      positions[element] = pos.copyWith(visible: !pos.visible);
      _layoutConfig = _layoutConfig.copyWith(positions: positions);
    });
    _saveConfig();
  }

  void _setPageSpacing({double? pagePadding, double? blockSpacing}) {
    setState(() {
      _layoutConfig = _layoutConfig.copyWith(
        pagePadding: pagePadding,
        blockSpacing: blockSpacing,
      );
    });
    _saveConfig();
  }

  // ── Build principal ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final text = theme.textColor;

    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: text),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personnaliser',
              style: TextStyle(
                color: text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              widget.template.name,
              style: TextStyle(
                color: theme.subTextColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.restart_alt_rounded, size: 20, color: text),
            tooltip: 'Réinitialiser',
            onPressed: _resetConfig,
          ),
          _saveButton(theme),
          const SizedBox(width: 10),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: theme.primaryColor))
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(child: _canvas(theme, isDark)),
                  _bottomBar(theme, isDark),
                ],
              ),
            ),
    );
  }

  /// Bouton « Enregistrer » — pill en dégradé indigo → violet.
  Widget _saveButton(ThemeProvider theme) {
    return GestureDetector(
      onTap: () async {
        await _saveConfig();
        _notifySaved();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.primaryColor, theme.gradientEndColor],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.save_outlined, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Enregistrer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Canvas A4 + grille de repères ──────────────────────────────────────
  Widget _canvas(ThemeProvider theme, bool isDark) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isDark ? const Color(0xFF0B0D17) : const Color(0xFFECECF3),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: FittedBox(
            fit: BoxFit.fitWidth,
            child: Transform.scale(
              scale: _zoom,
              child: _a4Card(theme, isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _a4Card(ThemeProvider theme, bool isDark) {
    final renderer = InvoiceRenderer(
      config: _layoutConfig,
      mode: RenderMode.edit,
      onElementMoved: _onElementMoved,
      dragAccentColor: theme.primaryColor,
      elementBuilder: (ctx, element, pos) =>
          _selectableElement(element, pos, theme),
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            // Grille de repères 4×4 (aide au placement)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GridPainter(
                    color: theme.primaryColor.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: A4Dimensions.width,
              height: A4Dimensions.height,
              child: renderer,
            ),
          ],
        ),
      ),
    );
  }

  // ── Sélection d'élément (anneau + étiquette) ───────────────────────────
  Widget _selectableElement(
      LayoutElement element, ElementPosition pos, ThemeProvider theme) {
    final selected = _selected == element;
    return GestureDetector(
      onTap: () => setState(() => _selected = element),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: selected
              ? theme.primaryColor.withValues(alpha: 0.06)
              : Colors.transparent,
          border: Border.all(
            color: selected ? theme.primaryColor : Colors.transparent,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _buildElementContent(element, pos),
            if (selected)
              Positioned(
                top: -9,
                left: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    element.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Contenu des éléments de la facture ─────────────────────────────────
  Widget _buildElementContent(LayoutElement element, ElementPosition pos) {
    final t = widget.template;
    final c = _company;
    final primary = t.primaryColor;
    final text = t.textColor;
    final sub = text.withValues(alpha: 0.7);
    switch (element) {
      case LayoutElement.logo:
        return Container(width: 40, height: 40, decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Icon(Icons.business, color: primary, size: 24));
      case LayoutElement.companyName:
        return Text(c?.name ?? 'Mon entreprise', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: text));
      case LayoutElement.companyAddress:
        return Text(c?.address ?? 'Adresse', style: TextStyle(fontSize: 10, color: sub));
      case LayoutElement.companyPhone:
        return Text(c?.phone ?? '+225 00 00 00 00', style: TextStyle(fontSize: 10, color: sub));
      case LayoutElement.companyEmail:
        return Text(c?.email ?? 'contact@entreprise.com', style: TextStyle(fontSize: 10, color: sub));
      case LayoutElement.invoiceTitle:
        return Text('FACTURE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primary, letterSpacing: 1.5));
      case LayoutElement.clientName:
        return Text('Nom Client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text));
      case LayoutElement.clientAddress:
        return Text('Adresse', style: TextStyle(fontSize: 10, color: sub));
      case LayoutElement.clientPhone:
        return Text('Téléphone', style: TextStyle(fontSize: 10, color: sub));
      case LayoutElement.clientEmail:
        return Text('email@client.com', style: TextStyle(fontSize: 10, color: sub));
      case LayoutElement.itemsTable:
        return Column(children: [
          Container(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), decoration: BoxDecoration(color: primary, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))), child: Row(children: [Expanded(flex: 3, child: Text('Désignation', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600))), Expanded(child: Text('Qté', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600))), Expanded(child: Text('Prix', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600))), Expanded(child: Text('Total', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)))])),
          Container(padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8), decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!)), child: Row(children: [Expanded(flex: 3, child: Text('Produit', style: TextStyle(fontSize: 9, color: text))), Expanded(child: Text('2', style: TextStyle(fontSize: 9, color: text))), Expanded(child: Text('50 000', style: TextStyle(fontSize: 9, color: text))), Expanded(child: Text('100 000', style: TextStyle(fontSize: 9, color: text)))])),
        ]);
      case LayoutElement.subtotal:
        return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Sous-total', style: TextStyle(fontSize: 11, color: text)), Text('100 000', style: TextStyle(fontSize: 11, color: text))]);
      case LayoutElement.taxAmount:
        return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('TVA (18%)', style: TextStyle(fontSize: 11, color: text)), Text('18 000', style: TextStyle(fontSize: 11, color: text))]);
      case LayoutElement.discount:
        return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Remise', style: TextStyle(fontSize: 11, color: const Color(0xFFBA1A1A))), Text('-0', style: TextStyle(fontSize: 11, color: const Color(0xFFBA1A1A)))]);
      case LayoutElement.totalAmount:
        return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primary)), Text('118 000 FCFA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primary))]));
      case LayoutElement.footerText:
        return Text('Conforme aux normes OHADA', style: TextStyle(fontSize: 9, color: sub, fontStyle: FontStyle.italic));
      case LayoutElement.qrCode:
        return t.showPaymentQR ? Container(width: 70, height: 70, decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)), child: Icon(Icons.qr_code_2, size: 50, color: primary)) : const SizedBox.shrink();
      case LayoutElement.signature:
        return Column(children: [Container(width: 120, height: 1, color: Colors.grey), const SizedBox(height: 4), Text('Signature', style: TextStyle(fontSize: 10, color: sub))]);
    }
  }

  // ── Barre inférieure : propriétés OU bouton « Éléments » + zoom ────────
  Widget _bottomBar(ThemeProvider theme, bool isDark) {
    final selected = _selected;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF151722).withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: selected == null
          ? _idleBar(theme, isDark)
          : _propertiesBar(selected, theme, isDark),
    );
  }

  Widget _idleBar(ThemeProvider theme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _openElementsSheet,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.primaryColor, theme.gradientEndColor],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.widgets_outlined, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Éléments',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _zoomPill(theme, isDark),
      ],
    );
  }

  Widget _zoomPill(ThemeProvider theme, bool isDark) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: isDark ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          _zoomBtn(Icons.remove, () => setState(() => _zoom = (_zoom - 0.1).clamp(0.5, 2.0)), theme),
          Text(
            '${(_zoom * 100).round()}%',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: theme.primaryColor,
            ),
          ),
          _zoomBtn(Icons.add, () => setState(() => _zoom = (_zoom + 0.1).clamp(0.5, 2.0)), theme),
        ],
      ),
    );
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap, ThemeProvider theme) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(icon, size: 18, color: theme.primaryColor),
      ),
    );
  }

  // ── Barre propriétés de l'élément sélectionné ──────────────────────────
  Widget _propertiesBar(
      LayoutElement element, ThemeProvider theme, bool isDark) {
    final pos = _layoutConfig.positions[element];
    if (pos == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_elementIcon(element),
                      size: 14, color: theme.primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    element.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _propBtn(
              pos.visible ? Icons.visibility : Icons.visibility_off,
              () => _toggleVisible(element),
              theme,
              tooltip: 'Visibilité',
            ),
            _propBtn(
              Icons.arrow_upward,
              () => _moveOrder(element, -1),
              theme,
              tooltip: 'Monter',
            ),
            _propBtn(
              Icons.arrow_downward,
              () => _moveOrder(element, 1),
              theme,
              tooltip: 'Descendre',
            ),
            _propBtn(
              Icons.close,
              () => setState(() => _selected = null),
              theme,
              tooltip: 'Fermer',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _columnSelector(element, theme, isDark),
      ],
    );
  }

  // ── Sélecteur de position (Gauche / Droite / Pleine largeur) ───────────
  Widget _columnSelector(
      LayoutElement element, ThemeProvider theme, bool isDark) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Text(
            'Position',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.subTextColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: theme.primaryColor
                    .withValues(alpha: isDark ? 0.14 : 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _columnOption('Gauche', 0, 1, element, theme),
                  _columnOption('Droite', 1, 1, element, theme),
                  _columnOption('Pleine largeur', 0, 2, element, theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _columnOption(
      String label, int column, int colSpan, LayoutElement element,
      ThemeProvider theme) {
    final pos = _layoutConfig.positions[element]!;
    final active =
        pos.colSpan == colSpan && (colSpan == 2 || pos.column == column);
    return Expanded(
      child: GestureDetector(
        onTap: () => _setColumn(element, column: column, colSpan: colSpan),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: active ? theme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : theme.subTextColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _propBtn(IconData icon, VoidCallback onTap, ThemeProvider theme,
      {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 6),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: theme.primaryColor),
        ),
      ),
    );
  }

  IconData _elementIcon(LayoutElement e) {
    switch (e) {
      case LayoutElement.logo:
        return Icons.image_outlined;
      case LayoutElement.companyName:
        return Icons.business_outlined;
      case LayoutElement.companyAddress:
        return Icons.location_on_outlined;
      case LayoutElement.companyPhone:
        return Icons.phone_outlined;
      case LayoutElement.companyEmail:
        return Icons.mail_outline;
      case LayoutElement.invoiceTitle:
        return Icons.title;
      case LayoutElement.clientName:
        return Icons.person_outline;
      case LayoutElement.clientAddress:
        return Icons.location_on_outlined;
      case LayoutElement.clientPhone:
        return Icons.phone_outlined;
      case LayoutElement.clientEmail:
        return Icons.mail_outline;
      case LayoutElement.itemsTable:
        return Icons.table_rows;
      case LayoutElement.subtotal:
        return Icons.calculate_outlined;
      case LayoutElement.taxAmount:
        return Icons.percent;
      case LayoutElement.discount:
        return Icons.sell_outlined;
      case LayoutElement.totalAmount:
        return Icons.payments_outlined;
      case LayoutElement.footerText:
        return Icons.notes;
      case LayoutElement.qrCode:
        return Icons.qr_code_2;
      case LayoutElement.signature:
        return Icons.draw;
    }
  }

  // ── Bottom sheet « Éléments » (chips par bloc + réglages page) ─────────
  void _openElementsSheet() {
    final theme = context.read<ThemeProvider>();
    final isDark = theme.isDarkMode;
    LayoutBlock? filter;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          final elements = _filteredElements(filter);
          return Container(
            height: MediaQuery.of(sheetCtx).size.height * 0.68,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151722) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        'Éléments de la facture',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _resetConfig,
                        child: Text(
                          'RÉINITIALISER',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      _blockChip(null, theme, isDark, filter,
                          (b) => setSheet(() => filter = b)),
                      for (final block in LayoutBlock.values)
                        _blockChip(block, theme, isDark, filter,
                            (b) => setSheet(() => filter = b)),
                    ],
                  ),
                ),
                const Divider(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: elements.length,
                    itemBuilder: (ctx, i) =>
                        _elementTile(elements[i], theme, sheetCtx, setSheet),
                  ),
                ),
                const Divider(height: 8),
                _pageSettings(theme),
              ],
            ),
          );
        },
      ),
    );
  }

  List<LayoutElement> _filteredElements(LayoutBlock? filter) {
    final elements = _layoutConfig.positions.keys
        .where((e) =>
            filter == null ||
            _layoutConfig.positions[e]!.blockIndex == filter.index)
        .toList()
      ..sort((a, b) {
        final pa = _layoutConfig.positions[a]!;
        final pb = _layoutConfig.positions[b]!;
        final byBlock = pa.blockIndex.compareTo(pb.blockIndex);
        if (byBlock != 0) return byBlock;
        final byOrder = pa.order.compareTo(pb.order);
        if (byOrder != 0) return byOrder;
        return pa.column.compareTo(pb.column);
      });
    return elements;
  }

  Widget _blockChip(LayoutBlock? block, ThemeProvider theme, bool isDark,
      LayoutBlock? current, ValueChanged<LayoutBlock?> onTap) {
    final active = block == current;
    final label = block == null ? 'Tous' : block.label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onTap(block),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? theme.primaryColor
                : theme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: theme.primaryColor.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active ? Colors.white : theme.primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _elementTile(LayoutElement element, ThemeProvider theme,
      BuildContext sheetCtx, StateSetter setSheet) {
    final pos = _layoutConfig.positions[element]!;
    final block = LayoutBlock.values[pos.blockIndex];
    return ListTile(
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_elementIcon(element), size: 18, color: theme.primaryColor),
      ),
      title: Text(
        element.label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: pos.visible ? theme.textColor : theme.subTextColor,
        ),
      ),
      subtitle: Text(
        '${block.label} • ${pos.colSpan == 2 ? 'pleine largeur' : (pos.column == 0 ? 'gauche' : 'droite')}',
        style: TextStyle(fontSize: 10.5, color: theme.subTextColor),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              pos.visible ? Icons.visibility : Icons.visibility_off,
              size: 18,
              color: pos.visible ? theme.primaryColor : theme.subTextColor,
            ),
            onPressed: () {
              _toggleVisible(element);
              setSheet(() {});
            },
          ),
          IconButton(
            icon: Icon(Icons.arrow_upward, size: 18, color: theme.subTextColor),
            onPressed: () {
              _moveOrder(element, -1);
              setSheet(() {});
            },
          ),
          IconButton(
            icon: Icon(Icons.arrow_downward,
                size: 18, color: theme.subTextColor),
            onPressed: () {
              _moveOrder(element, 1);
              setSheet(() {});
            },
          ),
        ],
      ),
      selected: _selected == element,
      onTap: () {
        setState(() => _selected = element);
        Navigator.of(sheetCtx).pop();
      },
    );
  }

  Widget _pageSettings(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        children: [
          _pageSlider(
            'Marge de page',
            _layoutConfig.pagePadding,
            0,
            40,
            theme,
            (v) => _setPageSpacing(pagePadding: v),
          ),
          _pageSlider(
            'Espacement des blocs',
            _layoutConfig.blockSpacing,
            0,
            20,
            theme,
            (v) => _setPageSpacing(blockSpacing: v),
          ),
        ],
      ),
    );
  }

  Widget _pageSlider(String label, double value, double min, double max,
      ThemeProvider theme, ValueChanged<double> onChanged) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor),
            ),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(fontSize: 11.5, color: theme.subTextColor),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: theme.primaryColor,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Grille de repères 4×4 dessinée derrière les éléments du canvas A4.
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final dx = size.width * i / 4;
      final dy = size.height * i / 4;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color;
}
