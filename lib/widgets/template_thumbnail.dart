// lib/widgets/template_thumbnail.dart
//
// CHANGELOG (v5) :
//   • ✨ 4 nouveaux styles d'en-tête : serif_title, solid_band_left,
//     split_diagonal_orange_blue, pill_date.
//   • ✨ Nouveau style de tableau : side_bars_orange.
//
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/invoice_template.dart';

class TemplateThumbnail extends StatelessWidget {
  final InvoiceTemplate template;
  const TemplateThumbnail({super.key, required this.template});

  String _style(String key, String fallback) {
    final v = template.positions[key];
    return v is String && v.isNotEmpty ? v : fallback;
  }

  bool _flag(String key, bool fallback) {
    final v = template.positions[key];
    return v is bool ? v : fallback;
  }

  bool get _hasImage {
    final t = template.fileType.toLowerCase();
    return template.fileData.isNotEmpty &&
        (t == 'png' || t == 'jpeg' || t == 'jpg');
  }

  @override
  Widget build(BuildContext context) {
    if (_hasImage) {
      try {
        final bytes = base64Decode(template.fileData);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _drawn(),
        );
      } catch (_) {
        return _drawn();
      }
    }
    return _drawn();
  }

  Widget _drawn() {
    final t = template;
    final headerStyle = _style('header_style', 'flat');
    final tableStyle = _style('table_style', 'plain');
    final footerStyle = _style('footer_style', 'simple');
    final accentBorder = _style('accent_border', '');
    final showThankYou = _flag('show_thank_you', false);

    final onPrimary = t.primaryColor.computeLuminance() > 0.55
        ? const Color(0xFF1F2937)
        : Colors.white;
    final line = t.textColor.withValues(alpha: 0.22);
    final lineSoft = t.textColor.withValues(alpha: 0.10);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: t.backgroundColor,
      child: Stack(
        children: [
          if (accentBorder == 'top')
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(height: 4, color: t.primaryColor),
            ),
          if (accentBorder == 'left')
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              child: Container(width: 4, color: t.primaryColor),
            ),
          if (accentBorder == 'frame')
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: t.primaryColor.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          if (accentBorder == 'stripes_bottom')
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 6,
                child: _RainbowStrip(color: t.primaryColor),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(t, headerStyle, onPrimary),
                const SizedBox(height: 6),
                _buildClientMeta(t, line, lineSoft),
                const SizedBox(height: 6),
                _buildItemsTable(t, tableStyle, line, lineSoft),
                const Spacer(),
                _buildTotals(t),
                if (showThankYou || footerStyle != 'simple')
                  const SizedBox(height: 6),
                if (showThankYou || footerStyle != 'simple')
                  _buildFooter(t, footerStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(InvoiceTemplate t, String style, Color onPrimary) {
    final headerContent = Row(
      children: [
        if (t.showLogo) ...[
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: onPrimary.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 4,
                  width: 46,
                  color: onPrimary.withValues(alpha: 0.9)),
              const SizedBox(height: 2.5),
              Container(
                  height: 2.5,
                  width: 32,
                  color: onPrimary.withValues(alpha: 0.5)),
            ],
          ),
        ),
        Text(
          'INVOICE',
          style: TextStyle(
            color: onPrimary,
            fontSize: 6,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );

    switch (style) {
      case 'band':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: t.primaryColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: headerContent,
        );
      case 'dark':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: Color.lerp(t.primaryColor, Colors.black, 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: headerContent,
        );

      case 'wave':
      case 'split_orange_left':
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 32,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ThumbWavePainter(accent: t.primaryColor),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  child: headerContent,
                ),
              ],
            ),
          ),
        );

      case 'orange_band_right':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: t.primaryColor.withValues(alpha: 0.08),
            border: Border(
              right: BorderSide(color: t.primaryColor, width: 3.5),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: headerContent,
        );

      case 'split_diagonal_corners':
        return SizedBox(
          height: 36,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: ClipPath(
                  clipper: _ThumbCornerClipper(topLeft: true),
                  child: Container(
                    width: 30,
                    height: 30,
                    color: t.primaryColor,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: ClipPath(
                  clipper: _ThumbCornerClipper(topLeft: false),
                  child: Container(
                    width: 30,
                    height: 30,
                    color: t.primaryColor,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 4),
                child: headerContent,
              ),
            ],
          ),
        );

      case 'circle_accent_top_left':
        return SizedBox(
          height: 36,
          child: Stack(
            children: [
              Positioned(
                top: -12,
                left: -12,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: t.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 4),
                child: headerContent,
              ),
            ],
          ),
        );

      // ✨ NOUVEAU : Serif Title
      case 'serif_title':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              if (t.showLogo) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: t.primaryColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 3.5,
                      width: 40,
                      color: t.primaryColor,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: 2.5,
                      width: 28,
                      color: t.textColor.withValues(alpha: 0.10),
                    ),
                  ],
                ),
              ),
              Text(
                'Invoice',
                style: TextStyle(
                  color: t.primaryColor,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        );

      // ✨ NOUVEAU : Solid Band Left
      case 'solid_band_left':
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 36,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: t.primaryColor),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  child: headerContent,
                ),
              ],
            ),
          ),
        );

      // ✨ NOUVEAU : Diagonale Orange / Bleu (blanc courbé)
      case 'split_diagonal_orange_blue':
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 36,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: t.primaryColor),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 34,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.elliptical(24, 40),
                        bottomLeft: Radius.elliptical(24, 40),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  child: headerContent,
                ),
              ],
            ),
          ),
        );

      // ✨ NOUVEAU : Pill Date
      case 'pill_date':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              headerContent,
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: t.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Invoice · Date',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case 'cursive_title':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              if (t.showLogo) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: t.primaryColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 3.5,
                      width: 40,
                      color: t.primaryColor,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: 2.5,
                      width: 28,
                      color: t.textColor.withValues(alpha: 0.10),
                    ),
                  ],
                ),
              ),
              Text(
                'Invoice',
                style: TextStyle(
                  color: t.primaryColor,
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        );

      case 'diamond_center':
        return SizedBox(
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                child: Transform.rotate(
                  angle: 0.785398,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: t.primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 26, right: 4),
                child: headerContent,
              ),
            ],
          ),
        );

      case 'flat':
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: headerContent,
        );
    }
  }

  Widget _buildClientMeta(InvoiceTemplate t, Color line, Color lineSoft) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 2.5,
                  width: 24,
                  color: t.primaryColor.withValues(alpha: 0.8)),
              const SizedBox(height: 2.5),
              Container(height: 2.5, width: 38, color: lineSoft),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(height: 2.5, width: 22, color: lineSoft),
            const SizedBox(height: 2.5),
            Container(height: 2.5, width: 22, color: lineSoft),
          ],
        ),
      ],
    );
  }

  Widget _buildItemsTable(
      InvoiceTemplate t, String style, Color line, Color lineSoft) {
    final headerBg = style == 'dark_header'
        ? const Color(0xFF1B4965)
        : t.primaryColor;

    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: style == 'cards'
            ? BorderRadius.circular(4)
            : const BorderRadius.vertical(top: Radius.circular(2)),
      ),
      child: Row(
        children: [
          _thumbCell(Colors.white, 24, 2),
          const Spacer(),
          _thumbCell(Colors.white, 12, 2),
          const SizedBox(width: 6),
          _thumbCell(Colors.white, 16, 2),
        ],
      ),
    );

    final bodyRows = <Widget>[];
    for (var i = 0; i < 3; i++) {
      final isAlt = style == 'alternate_dark' && i.isEven;
      final showNumbered = style == 'numbered';
      final isSideBars = style == 'side_bars_orange';
      bodyRows.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: isAlt ? t.textColor.withValues(alpha: 0.05) : null,
            border: isSideBars
                ? Border(
                    left: BorderSide(color: t.primaryColor, width: 2),
                    right: BorderSide(color: t.primaryColor, width: 2),
                    bottom: BorderSide(
                        color: line.withValues(alpha: 0.4), width: 0.5),
                  )
                : Border(
                    bottom: BorderSide(
                        color: line.withValues(alpha: 0.4), width: 0.5),
                  ),
          ),
          child: Row(
            children: [
              if (showNumbered) ...[
                Text(
                  '${i + 1}.',
                  style: TextStyle(
                    color: t.primaryColor,
                    fontSize: 5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 3),
              ],
              _thumbCell(lineSoft, 34 - i * 4, 2),
              const Spacer(),
              _thumbCell(lineSoft, 8, 2),
              const SizedBox(width: 6),
              _thumbCell(lineSoft, 12, 2),
            ],
          ),
        ),
      );
    }

    if (style == 'cards') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 3),
          for (var i = 0; i < 2; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                    color: t.primaryColor.withValues(alpha: 0.2), width: 0.5),
              ),
              child: Row(
                children: [
                  _thumbCell(lineSoft, 30, 2),
                  const Spacer(),
                  _thumbCell(lineSoft, 8, 2),
                  const SizedBox(width: 6),
                  _thumbCell(lineSoft, 12, 2),
                ],
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, ...bodyRows],
    );
  }

  Widget _thumbCell(Color color, double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
        ),
      );

  Widget _buildTotals(InvoiceTemplate t) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              height: 2.5,
              width: 24,
              color: t.textColor.withValues(alpha: 0.2)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
            decoration: BoxDecoration(
              color: t.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              'TOTAL',
              style: TextStyle(
                color: t.primaryColor.computeLuminance() > 0.55
                    ? const Color(0xFF1F2937)
                    : Colors.white,
                fontSize: 5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(InvoiceTemplate t, String style) {
    switch (style) {
      case 'contact_bar_icons':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: t.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _thumbIcon(Colors.white),
              _thumbIcon(Colors.white),
              _thumbIcon(Colors.white),
            ],
          ),
        );

      case 'zigzag_thankyou':
      case 'thick_orange_band':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: t.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Center(
            child: Container(
              height: 2.5,
              width: 50,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        );

      case 'rainbow_strip':
        return SizedBox(
          height: 6,
          child: _RainbowStrip(color: t.primaryColor),
        );

      case 'diagonal_bottom_stripes':
        return SizedBox(
          height: 5,
          child: _RainbowStrip(color: t.primaryColor),
        );

      default:
        return Row(
          children: [
            if (t.showPaymentQR)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: t.textColor.withValues(alpha: 0.2), width: 0.6),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            if (t.showPaymentTerms) ...[
              if (t.showPaymentQR) const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 2,
                        width: 40,
                        color: t.textColor.withValues(alpha: 0.12)),
                    const SizedBox(height: 2),
                    Container(
                        height: 2,
                        width: 30,
                        color: t.textColor.withValues(alpha: 0.12)),
                  ],
                ),
              ),
            ],
          ],
        );
    }
  }

  Widget _thumbIcon(Color c) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
        ),
      );
}

class _ThumbWavePainter extends CustomPainter {
  final Color accent;
  _ThumbWavePainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF1B4965));
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
    canvas.drawPath(path, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _ThumbWavePainter old) => old.accent != accent;
}

class _ThumbCornerClipper extends CustomClipper<Path> {
  final bool topLeft;
  _ThumbCornerClipper({required this.topLeft});

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
  bool shouldReclip(covariant _ThumbCornerClipper old) =>
      old.topLeft != topLeft;
}

class _RainbowStrip extends StatelessWidget {
  final Color color;
  const _RainbowStrip({required this.color});

  @override
  Widget build(BuildContext context) {
    const stripes = 16;
    const colors = [
      Color(0xFFE8A33D),
      Color(0xFF1B4965),
      Color(0xFFE67E22),
      Color(0xFF111111),
    ];
    return Row(
      children: [
        for (var i = 0; i < stripes; i++)
          Expanded(
            child: Container(color: colors[i % colors.length]),
          ),
      ],
    );
  }
}