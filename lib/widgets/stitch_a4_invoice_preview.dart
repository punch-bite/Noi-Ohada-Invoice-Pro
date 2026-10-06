// lib/widgets/stitch_a4_invoice_preview.dart
//
// 🧾 Aperçu A4 « Aperçu de la facture » — maquette Stitch.
// 🔄 v4 : WYSIWYG strict avec le PDF.
//   • `_sanitizeText` local pour un rendu identique au PDF (sans emojis).
//   • Priorité `custom_logo_base64` > `company.logoPath`.
//   • Différenciation des styles de pied de page.
//   • headerStyle  : 'flat' | 'band' | 'bar' | 'dark' | 'zigzag'
//   • tableStyle   : 'plain' | 'zebra' | 'cards' | 'numbered'
//   • footerStyle  : 'simple' | 'contact' | 'banner' | 'icons'

import 'dart:convert' show base64Decode;
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/invoice_layout.dart';
import '../models/invoice_template.dart';
import '../services/template_custom_service.dart';
import '../theme/royal_ledger.dart';
import 'template_background_palette.dart';

/// Ligne du tableau des articles de l'aperçu.
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

/// Données affichées dans l'aperçu (facture réelle ou exemple maquette).
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
        invoiceNumber: 'INV000342',
        issueDate: '26/03/2025',
        dueDate: '02/04/2025',
        currency: 'XAF',
        isPaid: true,
      );

  static String money(double value) =>
      NumberFormat('#,##0').format(value).replaceAll(',', ' ');

  static String amount(double value) => 'Fr${money(value)}';
}

/// Aperçu A4 de la facture — fidèle à la maquette Stitch, piloté par les
/// personnalisations sauvegardées du modèle actif.
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

  static const InvoiceLayoutConfig _emptyConfig = InvoiceLayoutConfig(
    positions: {},
    styles: {},
  );

  static const double _paperWidth = 560;
  static const double _paperBaseHeight = _paperWidth * 1123 / 794;

  bool _vis(LayoutElement element) => layoutConfig.styleOf(element).visible;

  bool _cpBool(String key, bool fallback) {
    final v = customPositions[key];
    return v is bool ? v : fallback;
  }

  String _cpString(String key) =>
      (customPositions[key] as String? ?? '').trim();

  String get _bodyFont =>
      (fontFamily == 'Manrope' || fontFamily == 'WorkSans')
          ? fontFamily
          : 'WorkSans';

  // 🔤 Retire les emojis pour un rendu identique au PDF.
  static String _sanitizeText(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (_isSafeRune(rune)) buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }

  static bool _isSafeRune(int rune) {
    if (rune == 0x09 || rune == 0x0A || rune == 0x0D) return true;
    if (rune >= 0x20 && rune <= 0x7E) return true;
    if (rune >= 0x00A0 && rune <= 0x024F) return true;
    if (rune >= 0x2000 && rune <= 0x206F) return true;
    if (rune >= 0x20A0 && rune <= 0x20CF) return true;
    if (rune >= 0x2190 && rune <= 0x21FF) return true;
    if (rune >= 0x25A0 && rune <= 0x25FF) return true;
    if (rune >= 0x2700 && rune <= 0x27BF) return true;
    if (rune == 0xFEFF) return false;
    return false;
  }

  // ── Styles PRO ─────────────────────────────────────────────
  String get _headerStyle => _cpString('header_style').isNotEmpty
      ? _cpString('header_style')
      : 'flat';

  String get _tableStyle => _cpString('table_style').isNotEmpty
      ? _cpString('table_style')
      : 'plain';

  String get _footerStyle => _cpString('footer_style').isNotEmpty
      ? _cpString('footer_style')
      : 'simple';

  String get _accentBorder => _cpString('accent_border');

  bool get _showThankYou => _cpBool('show_thank_you', false);

  String get _thankYouText => _sanitizeText(
        _cpString('thank_you_text').isNotEmpty
            ? _cpString('thank_you_text')
            : 'Merci pour votre confiance !',
      );

  String get _bankName => _sanitizeText(_cpString('bank_name'));
  String get _bankAccount => _sanitizeText(_cpString('bank_account'));

  // ── Overrides personnalisés ────────────────────────────────
  String get _customCompanyName {
    final override = _sanitizeText(_cpString('company_name'));
    return override.isNotEmpty ? override : _sanitizeText(data.companyName);
  }

  String get _customClientName {
    final override = _sanitizeText(_cpString('client_name'));
    return override.isNotEmpty ? override : _sanitizeText(data.clientName);
  }

  String get _customTitle {
    final override = _sanitizeText(_cpString('invoice_title_text'));
    if (override.isNotEmpty) return override;
    return data.isDevis ? 'DEVIS' : 'FACTURE';
  }

  String get _customSubtitle => _sanitizeText(_cpString('invoice_subtitle'));

  String get _customLegalText => _sanitizeText(_cpString('custom_legal_text'));

  String get _customStampText => _sanitizeText(_cpString('stamp_text'));

  String get _customSignatoryTitle {
    final override = _sanitizeText(_cpString('signatory_title'));
    return override.isNotEmpty ? override : 'Signature';
  }

  /// Logo effectif : `custom_logo_base64` prioritaire sur le chemin.
  Uint8List? get _effectiveLogoBytes {
    final b64 = _cpString('custom_logo_base64');
    if (b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        return bytes.isEmpty ? null : bytes;
      } catch (_) {
        // ignore
      }
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

  Uint8List? get _signatureImageBytes {
    final raw = _cpString('signature_image');
    if (raw.isEmpty) return null;
    try {
      final bytes = base64Decode(raw);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  bool get _effectiveShowPaidStamp =>
      _cpBool('show_paid_stamp', showPaidStamp);

  bool get _effectiveShowSignature =>
      _cpBool('show_signature_line', _vis(LayoutElement.signature));

  @override
  Widget build(BuildContext context) {
    final Color accent = accentColor ?? RoyalColors.secondary;
    final bool lightAccent = accent.computeLuminance() > 0.55;
    final Color onAccent = lightAccent ? RoyalColors.onSurface : Colors.white;

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

    final double pagePadding =
        ((customPositions['page_padding'] as num?)?.toDouble() ?? 24.0)
            .clamp(8.0, 80.0);

    final double stampX =
        ((customPositions['stamp_x'] as num?)?.toDouble() ?? 0.5)
            .clamp(0.05, 0.95);
    final double stampY =
        ((customPositions['stamp_y'] as num?)?.toDouble() ?? 0.5)
            .clamp(0.05, 0.95);
    final double stampRotation =
        ((customPositions['stamp_rotation'] as num?)?.toDouble() ?? -0.15);
    final double stampScale =
        ((customPositions['stamp_scale'] as num?)?.toDouble() ?? 1.0)
            .clamp(0.5, 3.0);

    final bool hasBg = backgroundImage != null || backgroundSettings.hasPreset;

    final double overlayAlpha = hasBg
        ? (darkPage ? 0.18 : 0.15) * backgroundSettings.opacity.clamp(0.3, 1.0)
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
            if (_accentBorder == 'left')
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 8,
                    decoration: BoxDecoration(color: accent),
                  ),
                ),
              ),
            if (_accentBorder == 'top')
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(color: accent),
                  ),
                ),
              ),
            if (_accentBorder == 'frame')
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
            if (_effectiveShowPaidStamp && data.isPaid)
              Positioned.fill(
                child: _buildPaidStampAt(
                  x: stampX,
                  y: stampY,
                  rotation: stampRotation,
                  scale: stampScale,
                ),
              ),
            if (showWatermark && watermarkText.isNotEmpty)
              Positioned.fill(child: _buildWatermark(cText)),
            Padding(
              padding: EdgeInsets.all(pagePadding * k),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(accent, onAccent, k),
                  _buildInfoRow(cText, cSub, k),
                  Expanded(
                    child: _buildItemsAndTotals(
                        accent, onAccent, cText, cSub, line, k),
                  ),
                  _buildFooter(accent, cText, cSub, line, k),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //  EN-TÊTE — multi-styles
  // ============================================================
  Widget _buildHeader(Color accent, Color onAccent, double k) {
    final Color dotColor =
        Color.lerp(accent, Colors.black, 0.5)!.withValues(alpha: 0.55);

    final baseRow = Padding(
      padding: EdgeInsets.fromLTRB(4 * k, 14 * k, 4 * k, 14 * k),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildHeaderRowChildren(onAccent, k),
      ),
    );

    switch (_headerStyle) {
      case 'dark':
        return Container(
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _DotsPatternPainter(dotColor),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.95),
                        accent.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
              ),
              baseRow,
            ],
          ),
        );

      case 'bar':
        return Column(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(color: accent),
              child: baseRow,
            ),
          ],
        );

      case 'zigzag':
        return Column(
          children: [
            ClipPath(
              clipper: _DiagonalClipper(),
              child: Container(
                height: 70 * k,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent,
                      Color.lerp(accent, Colors.black, 0.15)!,
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(child: baseRow),
          ],
        );

      case 'band':
      default:
        return Container(
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _DotsPatternPainter(dotColor),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.92),
                        accent.withValues(alpha: 0.70),
                        accent.withValues(alpha: 0.30),
                      ],
                    ),
                  ),
                ),
              ),
              baseRow,
            ],
          ),
        );
    }
  }

  List<Widget> _buildHeaderRowChildren(Color onAccent, double k) {
    final resolved = InvoiceTemplate.visibleHeaderElements(customPositions);

    final children = <Widget>[];
    for (var i = 0; i < resolved.length; i++) {
      final key = resolved[i];
      final isLast = i == resolved.length - 1;
      if (key == 'logo') {
        if (showLogo) {
          children.add(_buildLogo(onAccent, k));
          if (!isLast) children.add(SizedBox(width: 14 * k));
        }
      } else if (key == 'company_info') {
        children.add(Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DE',
                style: TextStyle(
                  fontFamily: 'WorkSans',
                  fontSize: 10.5 * k,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: onAccent.withValues(alpha: 0.80),
                ),
              ),
              SizedBox(height: 2 * k),
              Text(
                _customCompanyName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20 * k,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: onAccent,
                ),
              ),
              SizedBox(height: 4 * k),
              if (data.companyAddress.isNotEmpty)
                _contactLine(_sanitizeText(data.companyAddress), onAccent, k),
              if (data.companyPhone.isNotEmpty)
                _contactLine(_sanitizeText(data.companyPhone), onAccent, k),
              if (data.companyEmail.isNotEmpty)
                _contactLine(_sanitizeText(data.companyEmail), onAccent, k),
              if (data.companyWebsite.isNotEmpty)
                _contactLine(_sanitizeText(data.companyWebsite), onAccent, k),
            ],
          ),
        ));
        if (!isLast) children.add(SizedBox(width: 10 * k));
      } else if (key == 'invoice_title') {
        children.add(Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _customTitle,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 26 * k,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
                color: onAccent,
              ),
            ),
            if (_customSubtitle.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 2 * k),
                child: Text(
                  _customSubtitle,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'WorkSans',
                    fontSize: 11 * k,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: onAccent.withValues(alpha: 0.85),
                  ),
                ),
              ),
          ],
        ));
      }
    }
    return children;
  }

  Widget _contactLine(String text, Color onAccent, double k) {
    return Padding(
      padding: EdgeInsets.only(top: 2 * k),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'WorkSans',
          fontSize: 11.5 * k,
          color: onAccent.withValues(alpha: 0.90),
          height: 1.25,
        ),
      ),
    );
  }

  Widget _buildLogo(Color onAccent, double k) {
    final double size = 64 * k;
    final Uint8List? bytes = _effectiveLogoBytes;

    final Widget fallback = Text(
      data.companyInitials.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 19 * k,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        color: const Color(0xFF93000A),
      ),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFDAD6),
        shape: BoxShape.circle,
        border:
            Border.all(color: onAccent.withValues(alpha: 0.20), width: 2),
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

  // ============================================================
  //  INFOS
  // ============================================================
  Widget _buildInfoRow(Color cText, Color cSub, double k) {
    final rows = <(String, String)>[
      ('FACTURE N°', _sanitizeText(data.invoiceNumber)),
      ('DATE', data.issueDate),
      ('ÉCHÉANCE', data.dueDate),
      ('DEVISE', data.currency),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(4 * k, 16 * k, 4 * k, 12 * k),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _vis(LayoutElement.clientName)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FACTURÉ À',
                        style: TextStyle(
                          fontFamily: 'WorkSans',
                          fontSize: 11 * k,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: cSub,
                        ),
                      ),
                      SizedBox(height: 6 * k),
                      if (data.clientName.isNotEmpty)
                        Text(
                          _customClientName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: _bodyFont,
                            fontSize: 13 * k,
                            fontWeight: FontWeight.w600,
                            color: cText,
                          ),
                        ),
                      if (_vis(LayoutElement.clientAddress) &&
                          data.clientAddress.isNotEmpty)
                        _clientLine(
                            _sanitizeText(data.clientAddress), cSub, k),
                      if (_vis(LayoutElement.clientPhone) &&
                          data.clientPhone.isNotEmpty)
                        _clientLine(
                            _sanitizeText(data.clientPhone), cSub, k),
                      if (_vis(LayoutElement.clientEmail) &&
                          data.clientEmail.isNotEmpty)
                        _clientLine(
                            _sanitizeText(data.clientEmail), cSub, k),
                    ],
                  )
                : const SizedBox(),
          ),
          SizedBox(width: 16 * k),
          SizedBox(
            width: 160 * k,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (label, value) in rows)
                  Padding(
                    padding: EdgeInsets.only(bottom: 5 * k),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'WorkSans',
                              fontSize: 10.5 * k,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: cSub,
                            ),
                          ),
                        ),
                        SizedBox(width: 8 * k),
                        Text(
                          value,
                          style: TextStyle(
                            fontFamily: 'WorkSans',
                            fontSize: 11.5 * k,
                            color: cText,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientLine(String text, Color cSub, double k) {
    return Padding(
      padding: EdgeInsets.only(top: 2 * k),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'WorkSans',
          fontSize: 11 * k,
          color: cSub,
          height: 1.3,
        ),
      ),
    );
  }

  // ============================================================
  //  TABLEAU + TOTAUX
  // ============================================================
  Widget _buildItemsAndTotals(
    Color accent,
    Color onAccent,
    Color cText,
    Color cSub,
    Color line,
    double k,
  ) {
    final BorderSide side = BorderSide(color: line, width: 1);

    return Padding(
      padding: EdgeInsets.fromLTRB(4 * k, 4 * k, 4 * k, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_vis(LayoutElement.itemsTable)) ...[
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 12 * k, vertical: 9 * k),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.82),
                borderRadius: _tableStyle == 'cards'
                    ? BorderRadius.circular(8)
                    : const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 8,
                    child: _thText('DESCRIPTION', onAccent, k),
                  ),
                  Expanded(
                    flex: 2,
                    child:
                        _thText('QTÉ', onAccent, k, align: TextAlign.center),
                  ),
                  Expanded(
                    flex: 3,
                    child:
                        _thText('PRIX', onAccent, k, align: TextAlign.right),
                  ),
                  Expanded(
                    flex: 3,
                    child: _thText('MONTANT', onAccent, k,
                        align: TextAlign.right),
                  ),
                ],
              ),
            ),
            if (data.items.isEmpty)
              Container(
                height: 64 * k,
                decoration: BoxDecoration(
                  border: Border(left: side, right: side, bottom: side),
                ),
                child: const SizedBox.shrink(),
              )
            else
              for (var i = 0; i < data.items.length; i++)
                _buildItemRowStyled(data.items[i], i, cText, accent, side, k),
          ],
          if (_vis(LayoutElement.subtotal) ||
              _vis(LayoutElement.totalAmount)) ...[
            SizedBox(height: 14 * k),
            Padding(
              padding: EdgeInsets.only(right: 4 * k),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_vis(LayoutElement.subtotal))
                    _totalLine('Sous-Total',
                        StitchPreviewData.amount(data.subtotal), cSub, cText, k),
                  if (showTaxDetails && _vis(LayoutElement.taxAmount))
                    _totalLine(
                        'TVA (${data.taxRate.toStringAsFixed(0)}%)',
                        StitchPreviewData.amount(data.taxAmount),
                        cSub,
                        cText,
                        k),
                  if (data.discount > 0 && _vis(LayoutElement.discount))
                    _totalLine(
                        'Remise',
                        '- ${StitchPreviewData.amount(data.discount)}',
                        cSub,
                        cText,
                        k),
                  if (_vis(LayoutElement.totalAmount)) ...[
                    SizedBox(height: 8 * k),
                    Container(
                      width: 220 * k,
                      padding: EdgeInsets.symmetric(
                          horizontal: 12 * k, vertical: 9 * k),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MONTANT TOTAL',
                            style: TextStyle(
                              fontFamily: 'WorkSans',
                              fontSize: 10.5 * k,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: onAccent,
                            ),
                          ),
                          Text(
                            StitchPreviewData.amount(data.totalAmount),
                            style: TextStyle(
                              fontFamily: 'WorkSans',
                              fontSize: 12.5 * k,
                              fontWeight: FontWeight.w600,
                              color: onAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _thText(String label, Color onAccent, double k,
      {TextAlign align = TextAlign.left}) {
    return Text(
      label,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'WorkSans',
        fontSize: 10 * k,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: onAccent,
      ),
    );
  }

  Widget _buildItemRowStyled(
    StitchPreviewItem item,
    int index,
    Color cText,
    Color accent,
    BorderSide side,
    double k,
  ) {
    switch (_tableStyle) {
      case 'zebra':
        return Container(
          decoration: BoxDecoration(
            color: index.isEven
                ? Colors.grey.withValues(alpha: 0.06)
                : Colors.transparent,
            border: Border(left: side, right: side, bottom: side),
          ),
          padding:
              EdgeInsets.symmetric(horizontal: 12 * k, vertical: 10 * k),
          child: _itemRowContentFlex(item, cText, k),
        );

      case 'cards':
        return Container(
          margin: EdgeInsets.symmetric(vertical: 4 * k),
          padding:
              EdgeInsets.symmetric(horizontal: 12 * k, vertical: 10 * k),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _itemRowContentFlex(item, cText, k),
        );

      case 'numbered':
        return Container(
          decoration: BoxDecoration(border: Border(bottom: side)),
          padding:
              EdgeInsets.symmetric(horizontal: 12 * k, vertical: 10 * k),
          child: Row(
            children: [
              SizedBox(
                width: 30 * k,
                child: Text(
                  '${index + 1}.',
                  style: TextStyle(
                    fontFamily: 'WorkSans',
                    fontSize: 11 * k,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
              Expanded(child: _itemRowContentFlex(item, cText, k)),
            ],
          ),
        );

      case 'plain':
      default:
        return Container(
          decoration: BoxDecoration(
            border: Border(left: side, right: side, bottom: side),
          ),
          padding:
              EdgeInsets.symmetric(horizontal: 12 * k, vertical: 10 * k),
          child: _itemRowContentFlex(item, cText, k),
        );
    }
  }

  /// ✅ Ligne d'article — Row autonome avec ses `Expanded` internes.
  Widget _itemRowContentFlex(
    StitchPreviewItem item,
    Color cText,
    double k,
  ) {
    final safeDescription = _sanitizeText(item.description);
    return Row(
      children: [
        Expanded(
          flex: 8,
          child: Text(
            safeDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _bodyFont,
              fontSize: 12 * k,
              fontWeight: FontWeight.w500,
              color: cText,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            item.quantity.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _bodyFont,
              fontSize: 11.5 * k,
              color: cText,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            StitchPreviewData.money(item.unitPrice),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: _bodyFont,
              fontSize: 11.5 * k,
              color: cText,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            StitchPreviewData.money(item.total),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: _bodyFont,
              fontSize: 11.5 * k,
              fontWeight: FontWeight.w600,
              color: cText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _totalLine(
      String label, String value, Color cSub, Color cText, double k) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6 * k),
      child: SizedBox(
        width: 220 * k,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 10.5 * k,
                fontWeight: FontWeight.w700,
                color: cSub,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: _bodyFont,
                fontSize: 12 * k,
                fontWeight: FontWeight.w600,
                color: cText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //  PIED — multi-styles différenciés
  // ============================================================
  Widget _buildFooter(
      Color accent, Color cText, Color cSub, Color line, double k) {
    final bool termsOn = showPaymentTerms && _vis(LayoutElement.footerText);
    final bool legalOn = _vis(LayoutElement.legalMention) &&
        (data.rccm.isNotEmpty ||
            data.taxId.isNotEmpty ||
            data.legalMention.isNotEmpty ||
            _customLegalText.isNotEmpty);
    final bool qrOn = showPaymentQR && _vis(LayoutElement.qrCode);
    final bool signOn = _effectiveShowSignature;
    final bool contactBar = _footerStyle == 'icons' ||
        _footerStyle == 'contact' ||
        _footerStyle == 'banner';

    if (!termsOn &&
        !legalOn &&
        !qrOn &&
        !signOn &&
        !_showThankYou &&
        !contactBar) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(4 * k, 6 * k, 4 * k, 4 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (termsOn) ...[
                      Text(
                        'Termes et conditions',
                        style: TextStyle(
                          fontFamily: 'WorkSans',
                          fontSize: 11.5 * k,
                          fontWeight: FontWeight.w700,
                          color: cSub,
                        ),
                      ),
                      SizedBox(height: 3 * k),
                      Text(
                        _sanitizeText(data.terms.isEmpty
                            ? 'Merci pour votre confiance.'
                            : data.terms),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'WorkSans',
                          fontSize: 11 * k,
                          color: cSub.withValues(alpha: 0.80),
                        ),
                      ),
                    ],
                    if (legalOn) ...[
                      SizedBox(height: 8 * k),
                      Text(
                        _sanitizeText(
                          'RCCM : ${data.rccm.isEmpty ? '—' : data.rccm}'
                          '  ·  N° Contribuable : ${data.taxId.isEmpty ? '—' : data.taxId}',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'WorkSans',
                          fontSize: 9.5 * k,
                          color: cSub,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (qrOn) ...[
                SizedBox(width: 12 * k),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    border: Border.all(color: line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_2, size: 46 * k, color: accent),
                      SizedBox(height: 3 * k),
                      Text(
                        'Paiement Mobile Money',
                        style: TextStyle(
                          fontFamily: 'WorkSans',
                          fontSize: 8.5 * k,
                          color: cSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (_bankName.isNotEmpty || _bankAccount.isNotEmpty) ...[
            SizedBox(height: 8 * k),
            Text(
              '${_bankName.isNotEmpty ? 'Banque : $_bankName' : ''}'
              '${_bankName.isNotEmpty && _bankAccount.isNotEmpty ? '  ·  ' : ''}'
              '${_bankAccount.isNotEmpty ? 'Compte : $_bankAccount' : ''}',
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 9.5 * k,
                color: cSub,
              ),
            ),
          ],
          if (_showThankYou) ...[
            SizedBox(height: 10 * k),
            Center(
              child: Text(
                _thankYouText,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13 * k,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          if (signOn) ...[
            SizedBox(height: 14 * k),
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_signatureImageBytes != null) ...[
                    Image.memory(
                      _signatureImageBytes!,
                      width: 130 * k,
                      height: 52 * k,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomRight,
                      gaplessPlayback: true,
                    ),
                    SizedBox(height: 2 * k),
                  ],
                  Container(
                    width: 120 * k,
                    height: 1,
                    decoration: BoxDecoration(
                      color: cSub.withValues(alpha: 0.45),
                    ),
                  ),
                  SizedBox(height: 4 * k),
                  Text(
                    _customSignatoryTitle,
                    style: TextStyle(
                      fontFamily: 'WorkSans',
                      fontSize: 10 * k,
                      color: cSub,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (contactBar) ...[
            SizedBox(height: 12 * k),
            _buildFooterContactBar(accent, cSub, k),
          ],
        ],
      ),
    );
  }

  /// ✅ Différenciation : `icons` (icônes + texte), `contact` (texte seul),
  /// `banner` (bandeau plein + centré).
  Widget _buildFooterContactBar(Color accent, Color cSub, double k) {
    final String website = _sanitizeText(data.companyWebsite.isNotEmpty
        ? data.companyWebsite
        : 'www.example.com');
    final String email = _sanitizeText(data.companyEmail.isNotEmpty
        ? data.companyEmail
        : 'mail@example.com');
    final String phone = _sanitizeText(data.companyPhone.isNotEmpty
        ? data.companyPhone
        : '+00 123 45X XX');

    switch (_footerStyle) {
      case 'banner':
        // Bandeau plein largeur, contenu centré.
        return Container(
          width: double.infinity,
          padding:
              EdgeInsets.symmetric(horizontal: 12 * k, vertical: 10 * k),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                website,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'WorkSans',
                  fontSize: 10 * k,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2 * k),
              Text(
                '$email  ·  $phone',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'WorkSans',
                  fontSize: 9 * k,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );

      case 'contact':
        // 3 colonnes de texte sans icônes.
        return Container(
          padding:
              EdgeInsets.symmetric(horizontal: 12 * k, vertical: 8 * k),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _footerTextOnly(website, k),
              _footerTextOnly(email, k),
              _footerTextOnly(phone, k),
            ],
          ),
        );

      case 'icons':
      default:
        // 3 icônes + texte.
        return Container(
          padding:
              EdgeInsets.symmetric(horizontal: 12 * k, vertical: 8 * k),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _footerContact(Icons.public, website, k),
              _footerContact(Icons.mail_outline, email, k),
              _footerContact(Icons.phone_outlined, phone, k),
            ],
          ),
        );
    }
  }

  Widget _footerTextOnly(String text, double k) {
    return Flexible(
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
    );
  }

  Widget _footerContact(IconData icon, String text, double k) {
    return Row(
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
  }

  // ============================================================
  //  TAMPON PAYÉ
  // ============================================================
  Widget _buildPaidStampAt({
    required double x,
    required double y,
    required double rotation,
    required double scale,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            Positioned(
              left: x * w - 90 * scale,
              top: y * h - 30 * scale,
              child: Transform.rotate(
                angle: rotation,
                child: Opacity(
                  opacity: 0.85,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 26 * scale, vertical: 10 * scale),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8 * scale),
                      border: Border.all(
                        color: const Color(0xFFBAAB6D),
                        width: 4 * scale,
                      ),
                    ),
                    child: Text(
                      _customStampText.isNotEmpty ? _customStampText : 'PAYÉ',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 40 * scale,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6 * scale,
                        color: const Color(0xFFBAAB6D),
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  //  FILIGRANE
  // ============================================================
  Widget _buildWatermark(Color baseColor) {
    final double rotation =
        ((customPositions['watermark_rotation'] as num?)?.toDouble() ?? -0.5);
    final double size =
        ((customPositions['watermark_size'] as num?)?.toDouble() ?? 48);
    final double opacity =
        ((customPositions['watermark_opacity'] as num?)?.toDouble() ?? 0.08)
            .clamp(0.01, 0.5);

    return Center(
      child: Transform.rotate(
        angle: rotation,
        child: Opacity(
          opacity: opacity,
          child: Text(
            _sanitizeText(watermarkText),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: size,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              color: baseColor,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Conversion des modèles métier → données de l'aperçu.
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

    String fmtDate(dynamic date) {
      if (date is DateTime) {
        return '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/${date.year}';
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

/// Motif de points de l'en-tête.
class _DotsPatternPainter extends CustomPainter {
  final Color color;
  _DotsPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const double cell = 8.0;
    const double radius = 1.2;
    final Paint paint = Paint()..color = color;
    for (double y = cell / 2; y < size.height; y += cell) {
      for (double x = cell / 2; x < size.width; x += cell) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Bandeau diagonal pour le style `zigzag`.
class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    p.lineTo(0, size.height * 0.6);
    p.lineTo(size.width, size.height);
    p.lineTo(size.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}