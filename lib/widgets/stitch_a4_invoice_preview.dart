// lib/widgets/stitch_a4_invoice_preview.dart
//
// CHANGELOG (v7) :
//   • ✨ 4 nouveaux styles d'en-tête : serif_title, solid_band_left,
//     split_diagonal_orange_blue, pill_date.
//   • ✨ Nouveau style de tableau : side_bars_orange.
//   • ✅ Conserve v6 (footer_sections, block_labels, spacer, divider, foot_*).
//
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/invoice_layout.dart';
import '../models/invoice_template.dart';
import '../services/template_custom_service.dart';
import '../theme/royal_ledger.dart';
import 'template_background_palette.dart';

class StitchPreviewItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;
  const StitchPreviewItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
}

class StitchPreviewData {
  final String companyInitials;
  final String companyLogoPath;
  final String companyName;
  final String companyAddress;
  final String companyPhone;
  final String companyEmail;
  final String companyWebsite;
  final String clientName;
  final String clientAddress;
  final String clientPhone;
  final String clientEmail;
  final String invoiceNumber;
  final String issueDate;
  final String dueDate;
  final String currency;
  final List<StitchPreviewItem> items;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double discount;
  final double totalAmount;
  final String terms;
  final String legalMention;
  final String rccm;
  final String taxId;
  final bool isDevis;
  final bool isPaid;

  const StitchPreviewData({
    this.companyInitials = '',
    this.companyLogoPath = '',
    this.companyName = '',
    this.companyAddress = '',
    this.companyPhone = '',
    this.companyEmail = '',
    this.companyWebsite = '',
    this.clientName = '',
    this.clientAddress = '',
    this.clientPhone = '',
    this.clientEmail = '',
    this.invoiceNumber = '',
    this.issueDate = '',
    this.dueDate = '',
    this.currency = 'XAF',
    this.items = const [],
    this.subtotal = 0,
    this.taxRate = 18,
    this.taxAmount = 0,
    this.discount = 0,
    this.totalAmount = 0,
    this.terms = 'Merci pour votre confiance.',
    this.legalMention = '',
    this.rccm = '',
    this.taxId = '',
    this.isDevis = false,
    this.isPaid = false,
  });

  factory StitchPreviewData.sample() => const StitchPreviewData(
        companyInitials: 'NO!',
        companyName: 'Noi Concept digital',
        companyAddress: 'Dovv Essos Yaoundé Cameroun',
        companyPhone: '+237620409383',
        companyEmail: 'contact@noiconcept.com',
        companyWebsite: 'noiconcept.com',
        clientName: 'Rivay Ravs',
        clientAddress: 'JI Ciracas KDW No 27\nLocation, Country',
        invoiceNumber: 'INV000342',
        issueDate: '26/03/2025',
        dueDate: '02/04/2025',
        currency: 'XAF',
        items: [
          StitchPreviewItem(
              description: 'Wireless Router',
              quantity: 1,
              unitPrice: 500,
              total: 500),
          StitchPreviewItem(
              description: 'Lan Cable', quantity: 3, unitPrice: 20, total: 60),
          StitchPreviewItem(
              description: 'Lorem ipsum dolor',
              quantity: 3,
              unitPrice: 10,
              total: 30),
        ],
        subtotal: 590,
        taxAmount: 0,
        totalAmount: 590,
        isPaid: false,
      );

  static String money(double value) =>
      NumberFormat('#,##0').format(value).replaceAll(',', ' ');

  static String amount(double value) => 'Fr${money(value)}';
}

class StitchA4InvoicePreview extends StatelessWidget {
  final StitchPreviewData data;
  final Color? accentColor;
  final Color? pageColor;
  final bool showLogo;
  final bool showBorder;
  final bool showTaxDetails;
  final bool showPaymentTerms;
  final bool showPaymentQR;
  final String fontFamily;
  final double fontScale;
  final InvoiceLayoutConfig layoutConfig;
  final TemplateBackgroundSettings backgroundSettings;
  final Uint8List? backgroundImage;
  final bool showPaidStamp;
  final String watermarkText;
  final bool showWatermark;
  final Map<String, dynamic> customPositions;

  const StitchA4InvoicePreview({
    super.key,
    required this.data,
    this.accentColor,
    this.pageColor,
    this.showLogo = true,
    this.showBorder = false,
    this.showTaxDetails = true,
    this.showPaymentTerms = true,
    this.showPaymentQR = false,
    this.fontFamily = 'WorkSans',
    this.fontScale = 1.0,
    this.layoutConfig = _emptyConfig,
    this.backgroundSettings = const TemplateBackgroundSettings(),
    this.backgroundImage,
    this.showPaidStamp = false,
    this.watermarkText = '',
    this.showWatermark = false,
    this.customPositions = const {},
  });

  static const InvoiceLayoutConfig _emptyConfig =
      InvoiceLayoutConfig(positions: {}, styles: {});

  static const double _paperWidth = 560;
  static const double _paperBaseHeight = _paperWidth * 1123 / 794;

  bool _vis(LayoutElement e) => layoutConfig.styleOf(e).visible;

  bool _cpBool(String key, bool fallback) {
    final v = customPositions[key];
    return v is bool ? v : fallback;
  }

  String _cpStr(String key) => (customPositions[key] as String? ?? '').trim();
  double _cpDouble(String key, double fallback) {
    final v = customPositions[key];
    return v is num ? v.toDouble() : fallback;
  }

  String get _headerStyle =>
      _cpStr('header_style').isNotEmpty ? _cpStr('header_style') : 'flat';
  String get _tableStyle =>
      _cpStr('table_style').isNotEmpty ? _cpStr('table_style') : 'plain';
  String get _footerStyle =>
      _cpStr('footer_style').isNotEmpty ? _cpStr('footer_style') : 'simple';
  String get _accentBorder => _cpStr('accent_border');

  bool get _showThankYou => _cpBool('show_thank_you', false);
  String get _thankYouText => _sanitize(_cpStr('thank_you_text').isNotEmpty
      ? _cpStr('thank_you_text')
      : 'Merci pour votre confiance !');
  String get _bankName => _sanitize(_cpStr('bank_name'));
  String get _bankAccount => _sanitize(_cpStr('bank_account'));

  String get _customCompanyName {
    final o = _sanitize(_cpStr('company_name'));
    return o.isNotEmpty ? o : _sanitize(data.companyName);
  }
  String get _customClientName {
    final o = _sanitize(_cpStr('client_name'));
    return o.isNotEmpty ? o : _sanitize(data.clientName);
  }
  String get _customTitle {
    final o = _sanitize(_cpStr('invoice_title_text'));
    if (o.isNotEmpty) return o;
    return data.isDevis ? 'DEVIS' : 'FACTURE';
  }
  String get _customSubtitle => _sanitize(_cpStr('invoice_subtitle'));
  String get _customLegalText => _sanitize(_cpStr('custom_legal_text'));
  String get _customStampText => _sanitize(_cpStr('stamp_text'));
  String get _customSignatoryTitle => _sanitize(
      _cpStr('signatory_title').isNotEmpty ? _cpStr('signatory_title') : 'Signature');

  String _labelOf(String key, String fallback) {
    final labels = customPositions['block_labels'];
    if (labels is Map) {
      final raw = labels[key];
      if (raw is String && raw.trim().isNotEmpty) return _sanitize(raw);
    }
    return fallback;
  }

  Uint8List? get _effectiveLogoBytes {
    final b64 = _cpStr('custom_logo_base64');
    if (b64.isNotEmpty) {
      try {
        final b = base64Decode(b64);
        return b.isEmpty ? null : b;
      } catch (_) {}
    }
    final path = data.companyLogoPath;
    if (path.isEmpty) return null;
    try {
      if (path.startsWith('data:image')) {
        final parts = path.split(',');
        return base64Decode(parts.length == 2 ? parts[1] : path);
      }
      final file = File(path);
      if (file.existsSync()) return file.readAsBytesSync();
    } catch (_) {}
    return null;
  }

  Uint8List? get _signatureBytes {
    final raw = _cpStr('signature_image');
    if (raw.isEmpty) return null;
    try {
      final b = base64Decode(raw);
      return b.isEmpty ? null : b;
    } catch (_) {
      return null;
    }
  }

  bool get _effectiveShowStamp => _cpBool('show_paid_stamp', showPaidStamp);
  bool get _effectiveShowSignature =>
      _cpBool('show_signature_line', _vis(LayoutElement.signature));

  @override
  Widget build(BuildContext context) {
    final Color accent = accentColor ?? RoyalColors.secondary;
    final Color page = pageColor ?? RoyalColors.surfaceContainerLowest;
    final bool darkPage = page.computeLuminance() < 0.45;
    final Color cText = darkPage ? Colors.white : RoyalColors.onSurface;
    final Color cSub = darkPage
        ? Colors.white.withValues(alpha: 0.75)
        : RoyalColors.onSurfaceVariant;
    final Color line = darkPage
        ? Colors.white.withValues(alpha: 0.22)
        : RoyalColors.outlineVariant.withValues(alpha: 0.55);

    final double k = fontScale.clamp(0.80, 1.35);
    final double pad = _cpDouble('page_padding', 24).clamp(8, 80);

    final bool hasBg = backgroundImage != null || backgroundSettings.hasPreset;
    final double overlayAlpha = hasBg
        ? (darkPage ? 0.18 : 0.15) *
            backgroundSettings.opacity.clamp(0.3, 1.0)
        : 0.0;

    return FittedBox(
      fit: BoxFit.fitWidth,
      child: Container(
        width: _paperWidth,
        height: _paperBaseHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: page,
          borderRadius: BorderRadius.circular(5),
          border: showBorder
              ? Border.all(color: accent.withValues(alpha: 0.35), width: 1.5)
              : Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: TemplateBackgroundLayer(
                presetId:
                    backgroundImage != null ? '' : backgroundSettings.presetId,
                imageBytes: backgroundImage,
                opacity: backgroundSettings.opacity,
                blur: backgroundSettings.blur,
                fit: backgroundSettings.fit,
              ),
            ),
            if (hasBg && overlayAlpha > 0)
              Positioned.fill(
                child: ColoredBox(
                  color: darkPage
                      ? Colors.black.withValues(alpha: overlayAlpha)
                      : Colors.white.withValues(alpha: overlayAlpha),
                ),
              ),
            ..._accentBorderWidgets(accent),
            if (_effectiveShowStamp && data.isPaid) _buildPaidStampAt(),
            if (showWatermark && watermarkText.isNotEmpty)
              Positioned.fill(child: _buildWatermark(cText)),
            Padding(
              padding: EdgeInsets.all(pad * k),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderWrapper(accent, k),
                  SizedBox(height: 12 * k),
                  Expanded(child: _buildBody(cText, cSub, line, k)),
                  _buildCustomFooterSections(accent, cText, cSub, k),
                  _buildFooter(accent, cText, cSub, line, k),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _accentBorderWidgets(Color accent) {
    switch (_accentBorder) {
      case 'top':
        return [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(height: 8, color: accent),
          ),
        ];
      case 'left':
        return [
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: Container(width: 8, color: accent),
          ),
        ];
      case 'frame':
        return [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: accent, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ];
      case 'stripes_bottom':
        return [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 14,
              child: CustomPaint(
                painter: _RainbowStripPainter(accent: accent, stripes: 20),
              ),
            ),
          ),
        ];
      default:
        return const [];
    }
  }

  Widget _buildHeaderWrapper(Color accent, double k) {
    switch (_headerStyle) {
      case 'dark':
        return _headerFilled(accent, k, dark: true);
      case 'band':
        return _headerFilled(accent, k);
      case 'wave':
      case 'split_orange_left':
        return _headerSplitLeft(accent, k);
      case 'orange_band_right':
        return _headerSplitRight(accent, k);
      case 'split_diagonal_corners':
        return _headerDiagonalCorners(accent, k);
      case 'circle_accent_top_left':
        return _headerCircle(accent, k);
      case 'cursive_title':
        return _headerCursive(accent, k);
      case 'diamond_center':
        return _headerDiamond(accent, k);
      // ✨ NOUVEAUX
      case 'serif_title':
        return _headerSerif(accent, k);
      case 'solid_band_left':
        return _headerSolidBandLeft(accent, k);
      case 'split_diagonal_orange_blue':
        return _headerDiagonalOrangeBlue(accent, k);
      case 'pill_date':
        return _headerPillDate(accent, k);
      case 'flat':
      default:
        return _headerFlat(accent, k);
    }
  }

  List<String> _headerKeys() {
    final order = InvoiceTemplate.visibleHeaderElements(customPositions);
    return order.where((k) {
      if (!showLogo && k == 'logo') return false;
      return true;
    }).toList();
  }

  Widget _headerCol(String key, Color onColor, double k) {
    switch (key) {
      case 'logo':
        return _buildLogo(onColor, k);
      case 'company_info':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_customCompanyName.isNotEmpty)
              Text(
                _customCompanyName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16 * k,
                  fontWeight: FontWeight.w800,
                  color: onColor,
                  height: 1.15,
                ),
              ),
            if (data.companyAddress.isNotEmpty)
              _contact(data.companyAddress, onColor, k),
            if (data.companyPhone.isNotEmpty)
              _contact(data.companyPhone, onColor, k),
            if (data.companyEmail.isNotEmpty)
              _contact(data.companyEmail, onColor, k),
          ],
        );
      case 'invoice_title':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _customTitle,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 22 * k,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: onColor,
              ),
            ),
            if (_customSubtitle.isNotEmpty && _headerStyle != 'pill_date')
              Padding(
                padding: EdgeInsets.only(top: 2 * k),
                child: Text(
                  _customSubtitle,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'WorkSans',
                    fontSize: 10.5 * k,
                    color: onColor.withValues(alpha: 0.85),
                  ),
                ),
              ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _headerFlat(Color accent, double k) {
    final keys = _headerKeys();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6 * k),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _rowChildren(keys, accent, k),
      ),
    );
  }

  Widget _headerFilled(Color accent, double k, {bool dark = false}) {
    final bg = dark ? Color.lerp(accent, Colors.black, 0.3)! : accent;
    final keys = _headerKeys();
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(vertical: 14 * k, horizontal: 14 * k),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _rowChildren(keys, Colors.white, k),
      ),
    );
  }

  Widget _headerSplitLeft(Color accent, double k) {
    final keys = _headerKeys();
    final titleIndex = keys.indexOf('invoice_title');
    final leftKeys = titleIndex >= 0 ? keys.sublist(0, titleIndex) : keys;
    final rightKeys = titleIndex >= 0 ? [keys[titleIndex]] : <String>[];

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 90 * k,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _WaveHeaderPainter(accent: accent),
              ),
            ),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 16 * k, vertical: 12 * k),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _rowChildren(leftKeys, Colors.white, k),
                ),
              ),
            ),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 20 * k, vertical: 12 * k),
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _rowChildren(rightKeys, Colors.white, k),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerSplitRight(Color accent, double k) {
    final keys = _headerKeys();
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          right: BorderSide(color: accent, width: 6 * k),
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: 12 * k, horizontal: 14 * k),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _rowChildren(keys, accent, k),
      ),
    );
  }

  Widget _headerDiagonalCorners(Color accent, double k) {
    final keys = _headerKeys();
    return SizedBox(
      height: 110 * k,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: _diagonalCorner(accent, 70 * k, topLeft: true),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: _diagonalCorner(accent, 70 * k, topLeft: false),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 14 * k, vertical: 12 * k),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: _rowChildren(keys, RoyalColors.onSurface, k),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagonalCorner(Color color, double size, {required bool topLeft}) {
    return ClipPath(
      clipper: _CornerDiagonalClipper(topLeft: topLeft),
      child: Container(width: size, height: size, color: color),
    );
  }

  Widget _headerCircle(Color accent, double k) {
    final keys = _headerKeys();
    return SizedBox(
      height: 110 * k,
      child: Stack(
        children: [
          Positioned(
            top: -30 * k,
            left: -30 * k,
            child: Container(
              width: 90 * k,
              height: 90 * k,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: -20 * k,
            left: -20 * k,
            child: Container(
              width: 70 * k,
              height: 70 * k,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 14 * k, vertical: 12 * k),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: _rowChildren(keys, RoyalColors.onSurface, k),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCursive(Color accent, double k) {
    final keys = _headerKeys();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8 * k),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _rowChildren(keys, accent, k, italicTitle: true),
      ),
    );
  }

  Widget _headerDiamond(Color accent, double k) {
    final keys = _headerKeys();
    return SizedBox(
      height: 110 * k,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Transform.rotate(
                angle: 0.785398,
                child: Container(
                  width: 50 * k,
                  height: 50 * k,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 70 * k, vertical: 12 * k),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: _rowChildren(keys, RoyalColors.onSurface, k),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✨ NOUVEAU : Serif Title
  Widget _headerSerif(Color accent, double k) {
    final keys = _headerKeys();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10 * k),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _rowChildren(keys, accent, k, italicTitle: true),
      ),
    );
  }

  // ✨ NOUVEAU : Solid Band Left
  Widget _headerSolidBandLeft(Color accent, double k) {
    final keys = _headerKeys();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 90 * k,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: accent)),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: Container(
                width: 150 * k,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2A),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40 * k),
                    bottomLeft: Radius.circular(40 * k),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 14 * k, vertical: 10 * k),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _rowChildren(keys, Colors.white, k),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✨ NOUVEAU : Diagonale Orange / Bleu (blanc courbé)
  Widget _headerDiagonalOrangeBlue(Color accent, double k) {
    final keys = _headerKeys();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 90 * k,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: accent)),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: Container(
                width: 145 * k,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.elliptical(60 * k, 90 * k),
                    bottomLeft: Radius.elliptical(60 * k, 90 * k),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 14 * k, vertical: 10 * k),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _rowChildren(keys, Colors.white, k),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✨ NOUVEAU : Pill Date
  Widget _headerPillDate(Color accent, double k) {
    final keys = _headerKeys();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _rowChildren(keys, RoyalColors.onSurface, k),
          ),
          if (_customSubtitle.isNotEmpty) ...[
            SizedBox(height: 10 * k),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 18 * k,
                  vertical: 8 * k,
                ),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(20 * k),
                ),
                child: Text(
                  _customSubtitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Manrope',
                    fontSize: 10 * k,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _rowChildren(
    List<String> keys,
    Color onColor,
    double k, {
    bool italicTitle = false,
  }) {
    final children = <Widget>[];
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      if (i > 0) children.add(SizedBox(width: 10 * k));
      if (key == 'invoice_title' && italicTitle) {
        children.add(
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                _customTitle,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 22 * k,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                  color: onColor,
                ),
              ),
            ),
          ),
        );
      } else {
        children.add(
          Expanded(
            flex: key == 'company_info' ? 2 : 1,
            child: _headerCol(key, onColor, k),
          ),
        );
      }
    }
    return children;
  }

  Widget _buildLogo(Color onColor, double k) {
    final size = 56 * k;
    final bytes = _effectiveLogoBytes;
    final fallback = Text(
      data.companyInitials.isEmpty
          ? 'LOGO'
          : data.companyInitials.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 14 * k,
        fontWeight: FontWeight.w900,
        color: onColor,
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: onColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: onColor.withValues(alpha: 0.35), width: 1.5),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: bytes == null
          ? fallback
          : Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }

  Widget _contact(String text, Color onColor, double k) => Padding(
        padding: EdgeInsets.only(top: 2 * k),
        child: Text(
          _sanitize(text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'WorkSans',
            fontSize: 9.5 * k,
            color: onColor.withValues(alpha: 0.85),
            height: 1.25,
          ),
        ),
      );

  Widget _buildBody(Color cText, Color cSub, Color line, double k) {
    final sections = InvoiceTemplate.decodeSections(
      customPositions['blocks_sections'],
    );
    final visMap = (customPositions['block_visibility'] as Map?) ?? {};
    final alignMap = (customPositions['block_alignment'] as Map?) ?? {};
    final widthMap = (customPositions['block_widths'] as Map?) ?? {};

    double widthOf(String key) {
      final v = widthMap[key];
      return v is num ? v.toDouble().clamp(0.3, 3.0) : 1.0;
    }

    TextAlign alignOf(String key) {
      final v = alignMap[key];
      if (v == 'center') return TextAlign.center;
      if (v == 'right') return TextAlign.right;
      return TextAlign.left;
    }

    bool visOf(String key) {
      final v = visMap[key];
      return v is bool ? v : true;
    }

    final rows = <Widget>[];
    for (final section in sections) {
      final visibleKeys = section.where(visOf).toList();
      if (visibleKeys.isEmpty) continue;
      final children = <Widget>[];
      for (var i = 0; i < visibleKeys.length; i++) {
        final key = visibleKeys[i];
        if (i > 0) children.add(SizedBox(width: 10 * k));
        final w = (widthOf(key) * 10).round().clamp(3, 30);
        children.add(Expanded(
          flex: w,
          child: Align(
            alignment: _alignmentOf(alignOf(key)),
            child: _bodyBlock(key, cText, cSub, line, k),
          ),
        ));
      }
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: 10 * k),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }

  Alignment _alignmentOf(TextAlign a) {
    switch (a) {
      case TextAlign.right:
      case TextAlign.end:
        return Alignment.topRight;
      case TextAlign.center:
        return Alignment.topCenter;
      default:
        return Alignment.topLeft;
    }
  }

  Widget _bodyBlock(String key, Color cText, Color cSub, Color line, double k) {
    if (key.startsWith('__spacer')) {
      final raw = (customPositions['spacer_sizes'] as Map?)?[key];
      final h = (raw is num ? raw.toDouble() : 60.0).clamp(8.0, 500.0);
      return SizedBox(width: double.infinity, height: h * k);
    }
    if (key.startsWith('__divider')) {
      final raw = (customPositions['divider_styles'] as Map?)?[key];
      final style = raw is String && raw.isNotEmpty ? raw : 'solid';
      return _dividerWidget(style, cText, k);
    }

    switch (key) {
      case 'billing_info':
        return _billingBlock(cText, cSub, k);
      case 'invoice_meta':
        return _metaBlock(cText, cSub, k);
      case 'items_table':
        return _itemsBlock(cText, line, k);
      case 'totals':
        return _totalsBlock(cText, cSub, k);
      case 'legal_mentions':
        return _legalBlock(cText, cSub, k);
      case 'signature_block':
        return _signatureBlock(cText, cSub, k);
      case 'qr_block':
        return _qrBlock(k);
      default:
        if (key.startsWith('text_') || key.startsWith('foot_')) {
          return _textBlock(key, cText, k);
        }
        return const SizedBox.shrink();
    }
  }

  Widget _dividerWidget(String style, Color color, double k) {
    switch (style) {
      case 'dashed':
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 400.0;
            const dashW = 6.0;
            const gap = 4.0;
            final count = (width / (dashW + gap)).floor();
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                count,
                (_) => Container(
                  width: dashW,
                  height: 1.5,
                  margin: const EdgeInsets.symmetric(horizontal: gap / 2),
                  color: color.withValues(alpha: 0.35),
                ),
              ),
            );
          },
        );
      case 'dots':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            20,
            (_) => Container(
              width: 3,
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      case 'solid':
      default:
        return Container(
          height: 1,
          color: color.withValues(alpha: 0.25),
          margin: const EdgeInsets.symmetric(vertical: 6),
        );
    }
  }

  Widget _billingBlock(Color cText, Color cSub, double k) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _labelOf('billing_info', 'INVOICE TO:'),
            style: TextStyle(
              fontFamily: 'WorkSans',
              fontSize: 10 * k,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: cSub,
            ),
          ),
          SizedBox(height: 4 * k),
          Text(
            _customClientName,
            style: TextStyle(
              fontFamily: 'WorkSans',
              fontSize: 12 * k,
              fontWeight: FontWeight.w700,
              color: cText,
            ),
          ),
          if (data.clientAddress.isNotEmpty)
            Text(
              _sanitize(data.clientAddress),
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 10.5 * k,
                color: cSub,
                height: 1.3,
              ),
            ),
          if (data.clientPhone.isNotEmpty)
            Text(
              _sanitize(data.clientPhone),
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 10.5 * k,
                color: cSub,
              ),
            ),
        ],
      );

  Widget _metaBlock(Color cText, Color cSub, double k) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _metaRow('Invoice #', _sanitize(data.invoiceNumber), cText, cSub, k),
          _metaRow('Date', data.issueDate, cText, cSub, k),
          _metaRow('Due Date', data.dueDate, cText, cSub, k),
        ],
      );

  Widget _metaRow(String l, String v, Color cText, Color cSub, double k) =>
      Padding(
        padding: EdgeInsets.only(bottom: 3 * k),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$l : ',
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 10 * k,
                fontWeight: FontWeight.w700,
                color: cSub,
              ),
            ),
            Text(
              v,
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 10.5 * k,
                color: cText,
              ),
            ),
          ],
        ),
      );

  Widget _itemsBlock(Color cText, Color line, double k) {
    final items = data.items;
    final rows = items.isEmpty
        ? const [
            StitchPreviewItem(
                description: 'Prestation',
                quantity: 1,
                unitPrice: 0,
                total: 0),
          ]
        : items;

    final headerWidget = Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 9 * k),
      decoration: BoxDecoration(
        color: _tableStyle == 'dark_header'
            ? RoyalColors.inverseSurface
            : (accentColor ?? RoyalColors.secondary),
        borderRadius: _tableStyle == 'cards'
            ? BorderRadius.circular(8)
            : const BorderRadius.vertical(top: Radius.circular(4)),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: _th('N°', Colors.white, k)),
          Expanded(flex: 5, child: _th('ITEM DESCRIPTION', Colors.white, k)),
          Expanded(
              flex: 2,
              child: _th('QTY', Colors.white, k, align: TextAlign.center)),
          Expanded(
              flex: 2,
              child: _th('PRICE', Colors.white, k, align: TextAlign.right)),
          Expanded(
              flex: 2,
              child: _th('TOTAL', Colors.white, k, align: TextAlign.right)),
        ],
      ),
    );

    final body = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final item = rows[i];
      final isAlt = _tableStyle == 'alternate_dark' && i.isEven;
      final isSideBars = _tableStyle == 'side_bars_orange';
      final effectiveAccent = accentColor ?? RoyalColors.secondary;
      body.add(Container(
        padding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 9 * k),
        decoration: BoxDecoration(
          color: isAlt ? cText.withValues(alpha: 0.05) : null,
          border: isSideBars
              ? Border(
                  left: BorderSide(color: effectiveAccent, width: 4),
                  right: BorderSide(color: effectiveAccent, width: 4),
                  bottom: BorderSide(color: line, width: 0.5),
                )
              : Border(
                  bottom: BorderSide(color: line, width: 0.5),
                ),
        ),
        child: Row(
          children: [
            Expanded(flex: 1, child: _td('${i + 1}', cText, k)),
            Expanded(
                flex: 5,
                child: _td(_sanitize(item.description), cText, k)),
            Expanded(
                flex: 2,
                child:
                    _td('${item.quantity}', cText, k, align: TextAlign.center)),
            Expanded(
                flex: 2,
                child: _td(StitchPreviewData.money(item.unitPrice), cText, k,
                    align: TextAlign.right)),
            Expanded(
                flex: 2,
                child: _td(StitchPreviewData.money(item.total), cText, k,
                    align: TextAlign.right, bold: true)),
          ],
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [headerWidget, ...body],
    );
  }

  Widget _th(String t, Color color, double k,
          {TextAlign align = TextAlign.left}) =>
      Text(
        t,
        textAlign: align,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 9.5 * k,
          letterSpacing: 0.4,
        ),
      );

  Widget _td(String t, Color color, double k,
          {TextAlign align = TextAlign.left, bool bold = false}) =>
      Text(
        t,
        textAlign: align,
        style: TextStyle(
          fontFamily: 'WorkSans',
          fontSize: 10 * k,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
      );

  Widget _totalsBlock(Color cText, Color cSub, double k) {
    final totalLabel = _labelOf('totals', 'TOTAL');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _totalLine('Sub Total', StitchPreviewData.money(data.subtotal), cSub,
            cText, k),
        if (showTaxDetails)
          _totalLine('Tax (${data.taxRate.toStringAsFixed(0)}%)',
              StitchPreviewData.money(data.taxAmount), cSub, cText, k),
        if (data.discount > 0)
          _totalLine('Discount', '-${StitchPreviewData.money(data.discount)}',
              cSub, cText, k),
        SizedBox(height: 6 * k),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 8 * k),
          decoration: BoxDecoration(
            color: accentColor ?? RoyalColors.secondary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                totalLabel,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5 * k,
                ),
              ),
              SizedBox(width: 12 * k),
              Text(
                StitchPreviewData.money(data.totalAmount),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11 * k,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _totalLine(String l, String v, Color cSub, Color cText, double k) =>
      Padding(
        padding: EdgeInsets.only(bottom: 3 * k),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$l : ',
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 10 * k,
                color: cSub,
              ),
            ),
            Text(
              v,
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 10.5 * k,
                color: cText,
              ),
            ),
          ],
        ),
      );

  Widget _legalBlock(Color cText, Color cSub, double k) {
    final legal = _customLegalText.isNotEmpty
        ? _customLegalText
        : _sanitize(data.legalMention);
    final headerLabel = _labelOf('legal_mentions', 'TERMS & CONDITIONS');
    if (!showPaymentTerms && legal.isEmpty && data.rccm.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPaymentTerms) ...[
          Text(
            headerLabel,
            style: TextStyle(
              fontFamily: 'WorkSans',
              fontSize: 10 * k,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: (accentColor ?? RoyalColors.secondary),
            ),
          ),
          SizedBox(height: 4 * k),
        ],
        if (legal.isNotEmpty)
          Text(
            legal,
            style: TextStyle(
              fontFamily: 'WorkSans',
              fontSize: 9.5 * k,
              color: cSub,
              height: 1.35,
            ),
          ),
      ],
    );
  }

  Widget _signatureBlock(Color cText, Color cSub, double k) {
    if (!_effectiveShowSignature) return const SizedBox.shrink();
    final title = _labelOf('signature_block', _customSignatoryTitle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_signatureBytes != null)
          Padding(
            padding: EdgeInsets.only(bottom: 4 * k),
            child: Image.memory(
              _signatureBytes!,
              width: 120 * k,
              height: 44 * k,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        Container(
          width: 110 * k,
          height: 1,
          color: cSub.withValues(alpha: 0.5),
        ),
        SizedBox(height: 3 * k),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'WorkSans',
            fontSize: 10 * k,
            color: cSub,
          ),
        ),
      ],
    );
  }

  Widget _qrBlock(double k) {
    if (!showPaymentQR) return const SizedBox.shrink();
    return Container(
      width: 60 * k,
      height: 60 * k,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
            color: (accentColor ?? RoyalColors.secondary)
                .withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.qr_code_2, size: 40),
    );
  }

  Widget _textBlock(String key, Color cText, double k) {
    final paragraphs = _paragraphsOf(key);
    if (paragraphs.isEmpty || paragraphs.every((p) => p.text.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in paragraphs)
          if (p.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 3 * k),
              child: Text(
                _sanitize(p.text),
                textAlign: p.align,
                style: TextStyle(
                  fontFamily: 'WorkSans',
                  fontSize: 10 * k,
                  fontWeight: p.bold ? FontWeight.bold : FontWeight.w500,
                  fontStyle:
                      p.italic ? FontStyle.italic : FontStyle.normal,
                  color: cText,
                ),
              ),
            ),
      ],
    );
  }

  List<_PreviewParagraph> _paragraphsOf(String key) {
    final raw = customPositions['custom_paragraphs'];
    if (raw is Map && raw[key] is List) {
      return (raw[key] as List)
          .whereType<Map>()
          .map((m) => _PreviewParagraph(
                text: m['text']?.toString() ?? '',
                align: TextAlign.values.firstWhere(
                  (a) => a.name == m['align'],
                  orElse: () => TextAlign.left,
                ),
                bold: m['bold'] == true,
                italic: m['italic'] == true,
              ))
          .toList();
    }
    final rawText = customPositions['custom_texts'];
    if (rawText is Map && rawText[key] is String) {
      final text = rawText[key] as String;
      if (text.isEmpty) return const [];
      return text
          .split('\n\n')
          .where((t) => t.trim().isNotEmpty)
          .map((t) => _PreviewParagraph(text: t.trim()))
          .toList();
    }
    return const [];
  }

  Widget _buildCustomFooterSections(
    Color accent,
    Color cText,
    Color cSub,
    double k,
  ) {
    final sections = InvoiceTemplate.decodeSections(
      customPositions['footer_sections'],
    );
    if (sections.every((s) => s.isEmpty)) return const SizedBox.shrink();

    final visMap = (customPositions['footer_visibility'] as Map?) ?? {};
    final alignMap = (customPositions['footer_alignments'] as Map?) ?? {};
    final widthMap = (customPositions['footer_widths'] as Map?) ?? {};

    bool visOf(String key) {
      final v = visMap[key];
      return v is bool ? v : true;
    }

    TextAlign alignOf(String key) {
      final v = alignMap[key];
      if (v == 'center') return TextAlign.center;
      if (v == 'right') return TextAlign.right;
      return TextAlign.left;
    }

    double widthOf(String key) {
      final v = widthMap[key];
      return v is num ? v.toDouble().clamp(0.3, 3.0) : 1.0;
    }

    final rows = <Widget>[];
    for (final section in sections) {
      final visibleKeys = section.where(visOf).toList();
      if (visibleKeys.isEmpty) continue;
      final children = <Widget>[];
      for (var i = 0; i < visibleKeys.length; i++) {
        final key = visibleKeys[i];
        if (i > 0) children.add(SizedBox(width: 10 * k));
        final w = (widthOf(key) * 10).round().clamp(3, 30);
        children.add(Expanded(
          flex: w,
          child: Align(
            alignment: _alignmentOf(alignOf(key)),
            child: _textBlock(key, cText, k),
          ),
        ));
      }
      rows.add(Padding(
        padding: EdgeInsets.only(top: 6 * k),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _buildFooter(
      Color accent, Color cText, Color cSub, Color line, double k) {
    final widgets = <Widget>[];

    if (_bankName.isNotEmpty || _bankAccount.isNotEmpty) {
      widgets.add(Padding(
        padding: EdgeInsets.only(top: 6 * k),
        child: Text(
          '${_bankName.isNotEmpty ? 'Bank: $_bankName' : ''}'
          '${_bankName.isNotEmpty && _bankAccount.isNotEmpty ? '   ' : ''}'
          '${_bankAccount.isNotEmpty ? 'Account: $_bankAccount' : ''}',
          style: TextStyle(
            fontFamily: 'WorkSans',
            fontSize: 9.5 * k,
            color: cSub,
          ),
        ),
      ));
    }

    if (_showThankYou) {
      switch (_footerStyle) {
        case 'rainbow_strip':
          widgets.add(Padding(
            padding: EdgeInsets.only(top: 10 * k),
            child: SizedBox(
              height: 18 * k,
              child: CustomPaint(
                painter: _RainbowStripPainter(accent: accent, stripes: 32),
              ),
            ),
          ));
          widgets.add(Padding(
            padding: EdgeInsets.only(top: 6 * k),
            child: Text(
              _thankYouText.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: 11 * k,
                letterSpacing: 1,
                color: accent,
              ),
            ),
          ));
          break;
        case 'thick_orange_band':
        case 'zigzag_thankyou':
          widgets.add(Padding(
            padding: EdgeInsets.only(top: 10 * k),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 16 * k, vertical: 10 * k),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _thankYouText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11 * k,
                ),
              ),
            ),
          ));
          break;
        default:
          widgets.add(Padding(
            padding: EdgeInsets.only(top: 8 * k),
            child: Text(
              _thankYouText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11 * k,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ));
      }
    }

    if (_footerStyle == 'contact_bar_icons') {
      widgets.add(Padding(
        padding: EdgeInsets.only(top: 10 * k),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 8 * k),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _footerContact(
                  Icons.public,
                  _sanitize(data.companyWebsite.isNotEmpty
                      ? data.companyWebsite
                      : 'www.example.com'),
                  k),
              _footerContact(
                  Icons.mail_outline,
                  _sanitize(data.companyEmail.isNotEmpty
                      ? data.companyEmail
                      : 'mail@example.com'),
                  k),
              _footerContact(
                  Icons.phone_outlined,
                  _sanitize(data.companyPhone.isNotEmpty
                      ? data.companyPhone
                      : '+000 000 000'),
                  k),
            ],
          ),
        ),
      ));
    }

    if (_footerStyle == 'diagonal_bottom_stripes') {
      widgets.add(Padding(
        padding: EdgeInsets.only(top: 10 * k),
        child: SizedBox(
          height: 14 * k,
          child: CustomPaint(
            painter: _RainbowStripPainter(accent: accent, stripes: 24),
          ),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  Widget _footerContact(IconData icon, String text, double k) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11 * k, color: Colors.white),
          SizedBox(width: 4 * k),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 9.5 * k,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );

  Widget _buildPaidStampAt() {
    final sx = _cpDouble('stamp_x', 0.5).clamp(0.05, 0.95);
    final sy = _cpDouble('stamp_y', 0.5).clamp(0.05, 0.95);
    final rot = _cpDouble('stamp_rotation', -0.15);
    final sc = _cpDouble('stamp_scale', 1.0).clamp(0.5, 3.0);
    final text = _customStampText.isNotEmpty ? _customStampText : 'PAYÉ';
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (_, c) => Stack(
            children: [
              Positioned(
                left: sx * c.maxWidth - 90 * sc,
                top: sy * c.maxHeight - 30 * sc,
                child: Transform.rotate(
                  angle: rot,
                  child: Opacity(
                    opacity: 0.85,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 26 * sc, vertical: 10 * sc),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8 * sc),
                        border: Border.all(
                          color: const Color(0xFFBAAB6D),
                          width: 4 * sc,
                        ),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 40 * sc,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6 * sc,
                          color: const Color(0xFFBAAB6D),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWatermark(Color base) {
    final rot = _cpDouble('watermark_rotation', -0.5);
    final size = _cpDouble('watermark_size', 48);
    final op = _cpDouble('watermark_opacity', 0.08).clamp(0.01, 0.5);
    return Center(
      child: Transform.rotate(
        angle: rot,
        child: Opacity(
          opacity: op,
          child: Text(
            _sanitize(watermarkText),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: size,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              color: base,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  static String _sanitize(String input) {
    if (input.isEmpty) return input;
    final buf = StringBuffer();
    for (final rune in input.runes) {
      if (_isSafe(rune)) buf.writeCharCode(rune);
    }
    return buf.toString();
  }

  static bool _isSafe(int r) {
    if (r == 0x09 || r == 0x0A || r == 0x0D) return true;
    if (r >= 0x20 && r <= 0x7E) return true;
    if (r >= 0x00A0 && r <= 0x024F) return true;
    if (r >= 0x2000 && r <= 0x206F) return true;
    if (r >= 0x20A0 && r <= 0x20CF) return true;
    if (r >= 0x2190 && r <= 0x21FF) return true;
    if (r >= 0x25A0 && r <= 0x25FF) return true;
    if (r >= 0x2700 && r <= 0x27BF) return true;
    return false;
  }
}

class _PreviewParagraph {
  final String text;
  final TextAlign align;
  final bool bold;
  final bool italic;
  const _PreviewParagraph({
    required this.text,
    this.align = TextAlign.left,
    this.bold = false,
    this.italic = false,
  });
}

class _WaveHeaderPainter extends CustomPainter {
  final Color accent;
  _WaveHeaderPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF1B4965));

    final orange = Paint()..color = accent;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.55, 0)
      ..quadraticBezierTo(
        size.width * 0.65,
        size.height * 0.5,
        size.width * 0.5,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, orange);
  }

  @override
  bool shouldRepaint(covariant _WaveHeaderPainter old) => old.accent != accent;
}

class _CornerDiagonalClipper extends CustomClipper<Path> {
  final bool topLeft;
  _CornerDiagonalClipper({required this.topLeft});

  @override
  Path getClip(Size size) {
    final p = Path();
    if (topLeft) {
      p
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(0, size.height)
        ..close();
    } else {
      p
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }
    return p;
  }

  @override
  bool shouldReclip(covariant _CornerDiagonalClipper old) =>
      old.topLeft != topLeft;
}

class _RainbowStripPainter extends CustomPainter {
  final Color accent;
  final int stripes;
  _RainbowStripPainter({required this.accent, this.stripes = 24});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / stripes;
    const colors = [
      Color(0xFFE8A33D),
      Color(0xFF1B4965),
      Color(0xFFE67E22),
      Color(0xFF111111),
    ];
    for (var i = 0; i < stripes; i++) {
      final paint = Paint()..color = colors[i % colors.length];
      final path = Path()
        ..moveTo(i * w, 0)
        ..lineTo((i + 1) * w, 0)
        ..lineTo((i + 1) * w - w * 0.5, size.height)
        ..lineTo(i * w - w * 0.5, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainbowStripPainter old) =>
      old.accent != accent || old.stripes != stripes;
}

extension StitchPreviewDataX on StitchPreviewData {
  static StitchPreviewData fromInvoice({
    required dynamic invoice,
    dynamic client,
    dynamic company,
  }) {
    String initials = '';
    final name = company?.name as String? ?? '';
    for (final part
        in name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2)) {
      initials += part[0].toUpperCase();
    }
    if (initials.isEmpty) initials = 'NO';

    String fmtDate(dynamic d) {
      if (d is DateTime) {
        return '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year}';
      }
      return '';
    }

    final items = (invoice.items as List).map((e) {
      return StitchPreviewItem(
        description: e.description as String,
        quantity: e.quantity as int,
        unitPrice: (e.unitPrice as num).toDouble(),
        total: (e.totalPrice as num).toDouble(),
      );
    }).toList();

    return StitchPreviewData(
      companyInitials: initials,
      companyLogoPath: company?.logoPath as String? ?? '',
      companyName: name,
      companyAddress: company?.address as String? ?? '',
      companyPhone: company?.phone as String? ?? '',
      companyEmail: company?.email as String? ?? '',
      companyWebsite: company?.website as String? ?? '',
      clientName: client?.name as String? ?? '',
      clientAddress: client?.address as String? ?? '',
      clientPhone: client?.phone as String? ?? '',
      clientEmail: client?.email as String? ?? '',
      invoiceNumber: invoice.invoiceNumber as String,
      issueDate: fmtDate(invoice.issueDate),
      dueDate: fmtDate(invoice.dueDate),
      currency: company?.currency as String? ?? 'XAF',
      items: items,
      subtotal: (invoice.subtotal as num).toDouble(),
      taxRate: (invoice.taxRate as num).toDouble(),
      taxAmount: (invoice.taxAmount as num).toDouble(),
      discount: (invoice.discount as num).toDouble(),
      totalAmount: (invoice.totalAmount as num).toDouble(),
      terms: invoice.terms as String? ?? '',
      legalMention: company?.legalText as String? ?? '',
      rccm: company?.rccm as String? ?? '',
      taxId: company?.taxId as String? ?? '',
      isDevis: (invoice.isDevis as bool?) ?? false,
      isPaid: (invoice.status as String? ?? '') == 'paid',
    );
  }
}