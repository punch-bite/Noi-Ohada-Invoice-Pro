// lib/widgets/invoice_mockup_preview.dart
//
// 🧾 Aperçu « maquette » de la facture — rendu conforme aux designs
// Détails Facture : bandeau d'en-tête couleur primaire avec grille de points,
// logo circulaire, tampon PAYÉ incliné, pilule MONTANT TOTAL.
//
// Partagé par l'écran de personnalisation (/customization) et l'écran
// d'aperçu (/templates/apropos/preview). Totalement piloté par
// [CustomizationConfig] : couleurs, tailles S/M/L/XL par section, options
// (logo, ombres, tampon, signature, termes).

import 'package:flutter/material.dart';
import '../models/customization_config.dart';

/// Doré du tampon « PAYÉ » (identique aux maquettes).
const Color kPaidStampColor = Color(0xFFCDB261);

/// Une ligne de démonstration du tableau des lignes.
class _MockupItem {
  final String description;
  final String qty;
  final String price;
  final String amount;
  const _MockupItem(this.description, this.qty, this.price, this.amount);
}

const List<_MockupItem> _mockupItems = [
  _MockupItem('Développement prestation web', '2', '50 000', '100 000'),
  _MockupItem('Hébergement et maintenance', '1', '20 000', '20 000'),
];

/// Grille de points décorative du bandeau d'en-tête.
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.10);
    const spacing = 11.0;
    for (double x = 5; x < size.width; x += spacing) {
      for (double y = 5; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Aperçu de facture « maquette » piloté par [CustomizationConfig].
class InvoiceMockupPreview extends StatelessWidget {
  final CustomizationConfig config;

  const InvoiceMockupPreview({super.key, required this.config});

  String get _initials {
    final letters = 'Noi Concept digital'.replaceAll(' ', '').toUpperCase();
    return letters.length >= 3 ? letters.substring(0, 3) : letters;
  }

  @override
  Widget build(BuildContext context) {
    final cfg = config;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: cfg.showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerBand(cfg),
          const SizedBox(height: 16),
          _infoSection(cfg),
          const SizedBox(height: 14),
          _itemsWithStamp(cfg),
          const SizedBox(height: 12),
          _totals(cfg),
          if (cfg.showPaymentTerms) ...[
            const SizedBox(height: 6),
            const Divider(height: 22, thickness: 1, color: Color(0xFFEEF0F4)),
            _terms(cfg),
          ],
          if (cfg.showSignature) _signature(cfg),
        ],
      ),
    );
  }

  // ── Bandeau d'en-tête ──────────────────────────────────────────────────
  Widget _headerBand(CustomizationConfig cfg) {
    final companySize = cfg.fontSize(FontSizeSection.companyClient);
    final small = (companySize - 2.5).clamp(8.0, 12.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DotGridPainter()),
          ),
          Container(
            color: cfg.primaryColor,
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (cfg.showLogo) ...[
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      _initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        fontFamily: cfg.fontFamily,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DE',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: (companySize - 3.5).clamp(7.0, 11.0),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          fontFamily: cfg.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Noi Concept digital',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (companySize + 1.5).clamp(11.0, 18.0),
                          fontWeight: FontWeight.w700,
                          fontFamily: cfg.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Dovv Essos Yaoundé Cameroun',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: small,
                          fontFamily: cfg.fontFamily,
                        ),
                      ),
                      Text(
                        '+237 620 409 383',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: small,
                          fontFamily: cfg.fontFamily,
                        ),
                      ),
                      Text(
                        'contact@noiconcept.com',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: small,
                          fontFamily: cfg.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'FACTURE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: cfg.fontSize(FontSizeSection.title),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        fontFamily: cfg.fontFamily,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Facturé à + infos facture ──────────────────────────────────────────
  Widget _infoSection(CustomizationConfig cfg) {
    final labelSize = (cfg.fontSize(FontSizeSection.invoiceInfo) - 1.5)
        .clamp(8.0, 14.0);
    final valueSize = cfg.fontSize(FontSizeSection.invoiceInfo);
    Widget infoLine(String label, String value) {
      return SizedBox(
        width: 195,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: const Color(0xFF6B7280),
                  fontSize: labelSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  fontFamily: cfg.fontFamily,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: const Color(0xFF111827),
                fontSize: valueSize,
                fontWeight: FontWeight.w600,
                fontFamily: cfg.fontFamily,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FACTURÉ À',
                style: TextStyle(
                  color: const Color(0xFF6B7280),
                  fontSize: labelSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  fontFamily: cfg.fontFamily,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '-',
                style: TextStyle(
                  color: const Color(0xFF111827),
                  fontSize: valueSize,
                  fontWeight: FontWeight.w600,
                  fontFamily: cfg.fontFamily,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            infoLine('FACTURE N°', 'INV000342'),
            const SizedBox(height: 4),
            infoLine('DATE', '26/03/2025'),
            const SizedBox(height: 4),
            infoLine('ÉCHÉANCE', '02/04/2025'),
            const SizedBox(height: 4),
            infoLine('DEVISE', 'XAF'),
          ],
        ),
      ],
    );
  }

  // ── Tableau des lignes + tampon PAYÉ ───────────────────────────────────
  Widget _itemsWithStamp(CustomizationConfig cfg) {
    final cellSize = (cfg.fontSize(FontSizeSection.invoiceInfo) - 3.5)
        .clamp(8.0, 11.0);
    final cellStyle = TextStyle(
      color: const Color(0xFF111827),
      fontSize: cellSize,
      fontFamily: cfg.fontFamily,
    );
    final headerStyle = TextStyle(
      color: Colors.white,
      fontSize: cellSize,
      fontWeight: FontWeight.w700,
      fontFamily: cfg.fontFamily,
    );

    final table = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: cfg.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Description', style: headerStyle)),
                Expanded(
                    child: Center(
                        child: Text('QTÉ',
                            textAlign: TextAlign.center, style: headerStyle))),
                Expanded(
                    child: Text('Prix',
                        textAlign: TextAlign.right, style: headerStyle)),
                Expanded(
                    child: Text('Montant',
                        textAlign: TextAlign.right, style: headerStyle)),
              ],
            ),
          ),
          for (final item in _mockupItems)
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: const Color(0xFFE5E7EB)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text(item.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: cellStyle)),
                  Expanded(
                      child: Center(
                          child:
                              Text(item.qty, textAlign: TextAlign.center, style: cellStyle))),
                  Expanded(
                      child: Text(item.price,
                          textAlign: TextAlign.right, style: cellStyle)),
                  Expanded(
                      child: Text(item.amount,
                          textAlign: TextAlign.right, style: cellStyle)),
                ],
              ),
            ),
        ],
      ),
    );

    return Stack(
      children: [
        table,
        if (cfg.showPaidStamp)
          Center(
            child: Transform.translate(
              offset: const Offset(0, 4),
              child: Transform.rotate(
                angle: -0.13,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    border: Border.all(color: kPaidStampColor, width: 2.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'PAYÉ',
                    style: TextStyle(
                      color: kPaidStampColor.withValues(alpha: 0.92),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                      fontFamily: cfg.fontFamily,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Totaux ─────────────────────────────────────────────────────────────
  Widget _totals(CustomizationConfig cfg) {
    final valueSize = cfg.fontSize(FontSizeSection.invoiceInfo);
    final labelStyle = TextStyle(
      color: const Color(0xFF6B7280),
      fontSize: valueSize,
      fontWeight: FontWeight.w500,
      fontFamily: cfg.fontFamily,
    );
    final valueStyle = TextStyle(
      color: const Color(0xFF111827),
      fontSize: valueSize,
      fontWeight: FontWeight.w600,
      fontFamily: cfg.fontFamily,
    );
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 215,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sous-Total', style: labelStyle),
                Text('120 000', style: valueStyle),
              ],
            ),
            const SizedBox(height: 7),
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: cfg.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'MONTANT TOTAL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (valueSize - 1.5).clamp(8.0, 13.0),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        fontFamily: cfg.fontFamily,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '120 000 XAF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: valueSize,
                      fontWeight: FontWeight.w700,
                      fontFamily: cfg.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Termes et signature ────────────────────────────────────────────────
  Widget _terms(CustomizationConfig cfg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Termes et conditions',
          style: TextStyle(
            color: const Color(0xFF111827),
            fontSize: cfg.fontSize(FontSizeSection.invoiceInfo),
            fontWeight: FontWeight.w700,
            fontFamily: cfg.fontFamily,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Merci pour votre confiance.',
          style: TextStyle(
            color: const Color(0xFF6B7280),
            fontSize: cfg.fontSize(FontSizeSection.companyClient),
            fontFamily: cfg.fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _signature(CustomizationConfig cfg) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 110, height: 1, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 5),
            Text(
              'Signature',
              style: TextStyle(
                color: const Color(0xFF6B7280),
                fontSize: 10,
                fontFamily: cfg.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
