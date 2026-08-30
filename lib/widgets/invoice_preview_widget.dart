// lib/widgets/invoice_preview_widget.dart
//
// 🧩 Rendu visuel de la facture aligné sur les maquettes du flow
// Aperçu ↔ Personnaliser.
//
// Widget réutilisable : utilisé aussi bien dans l'écran plein écran
// [TemplatePreviewScreen] (Aperçu) que dans la bandeau supérieur de
// [InvoiceCustomizationScreen] (Personnaliser).
//
import 'package:flutter/material.dart';
import '../models/customization_config.dart';

/// Données factices affichées dans l'aperç� lorsqu'aucune donnée réelle
/// n'est fournie. Elles reproduisent l'exemple des maquettes (DE Noi Concept
/// digital / Client SARL / facture FV-2024-0018).
class PreviewInvoiceData {
  final String companyName;
  final String companyAddress;
  final String companyPhone;
  final String companyEmail;
  final String rccm;
  final String clientName;
  final String clientAddress;
  final String clientPhone;
  final String clientEmail;
  final String invoiceNumber;
  final String issueDate;
  final String dueDate;
  final String currency;
  final List<PreviewLineItem> items;
  final String subtotal;
  final String tax;
  final String total;
  final String legalText;

  const PreviewInvoiceData({
    this.companyName = 'DE Noi Concept digital',
    this.companyAddress = '123 Rue de l\'Indépendance, Douala',
    this.companyPhone = 'TEL: +237 690 00 00 00',
    this.companyEmail = 'contact@noiconcept.cm',
    this.rccm = 'RCCM: DZ-02-2021-B001',
    this.clientName = 'Client SARL',
    this.clientAddress = 'Douala, Cameroun',
    this.clientPhone = 'Tél: +237 6XX XX XX XX',
    this.clientEmail = 'client@exemple.com',
    this.invoiceNumber = 'FV-2024-0018',
    this.issueDate = '30/08/2026',
    this.dueDate = '30/09/2026',
    this.currency = 'FCFA',
    this.items = const [
      PreviewLineItem(
        description: 'Développement prestation web',
        quantity: '2',
        unitPrice: '50 000',
        amount: '100 000',
      ),
      PreviewLineItem(
        description: 'Hébergement et maintenance mensuelle',
        quantity: '1',
        unitPrice: '20 000',
        amount: '20 000',
      ),
    ],
    this.subtotal = '100 000 FCFA',
    this.tax = '18 000 FCFA',
    this.total = '118 000 FCFA',
    this.legalText =
        'Conforme aux normes OHADA et SYSCOHADA — TVA non applicable, article 277 du CGI',
  });
}

class PreviewLineItem {
  final String description;
  final String quantity;
  final String unitPrice;
  final String amount;

  const PreviewLineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });
}

class InvoicePreviewWidget extends StatelessWidget {
  final CustomizationConfig config;

  /// Données factices. Si nulles, les valeurs par défaut du constructeur
  /// ci-dessus sont utilisées (cohérentes avec les maquettes).
  final PreviewInvoiceData? data;

  /// Bordure autour de la carte (true pour l'Aperçu plein écran).
  final bool showShadow;

  const InvoicePreviewWidget({
    super.key,
    required this.config,
    this.data,
    this.showShadow = true,
  });

  static const double _cardWidth = 370.0;

  PreviewInvoiceData get _d => data ?? const PreviewInvoiceData();

  // ─── PEAU DE LA CARTE ─────────────────────────────────────────────
  BoxDecoration _cardDecoration() {
    final List<BoxShadow> shadow = showShadow
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ]
        : const [];
    return BoxDecoration(
      color: config.backgroundColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
      boxShadow: shadow,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Largeur adaptative : jamais plus large que l'écran (370 max), sinon les
    // cartes se reposent au maximum disponible.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite && constraints.maxWidth < _cardWidth
                ? constraints.maxWidth
                : _cardWidth;
        return Container(
          width: width,
          decoration: _cardDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                _buildHeader(),
                _buildClientSection(),
                _buildInvoiceInfo(),
                _buildItemsTable(),
                _buildTotals(),
                if (config.showSignature) _buildSignature(),
                _buildFooter(),
              ],
            ),
          ),
        );
      },
    );
  }
  // ─── EN-TÊTE (bande bleue à moitié-ton) ──────────────────────────
  Widget _buildHeader() {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _HalftonePainter(color: config.primaryColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (config.showLogo) _buildLogo(),
              if (config.showLogo) const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _d.companyName,
                      style: TextStyle(
                        fontSize: config.fontSize(FontSizeSection.title) * 0.6,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _d.companyAddress,
                      style: TextStyle(
                        fontSize: config.fontSize(FontSizeSection.companyClient),
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    Text(
                      '${_d.companyPhone}  •  ${_d.rccm}',
                      style: TextStyle(
                        fontSize:
                            config.fontSize(FontSizeSection.companyClient) - 1,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              _buildFactureBadge(),
            ],
          ),
        ),
      ],
    );
  }

  /// Logo carré blanc (placeholder) ou image réelle.
  Widget _buildLogo() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 1)],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.business,
        color: config.primaryColor,
        size: 26,
      ),
    );
  }

  /// Badge "FACTURE" en majuscule sur la droite de la bande.
  Widget _buildFactureBadge() {
    return Transform(
      transform: Matrix4.rotationZ(-0.03),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          'FACTURE',
          style: TextStyle(
            fontSize: config.fontSize(FontSizeSection.title) * 0.7,
            fontWeight: FontWeight.w800,
            color: config.primaryColor,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
  /// Bloc "FACTURÉ À" + coordonnées du client.
  Widget _buildClientSection() {
    final sub = config.textColor.withValues(alpha: 0.55);
    final fs = config.fontSize(FontSizeSection.companyClient);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FACTURÉ À',
            style: TextStyle(
              fontSize: config.fontSize(FontSizeSection.title) * 0.65,
              fontWeight: FontWeight.w700,
              color: config.primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _d.clientName,
            style: TextStyle(
              fontSize: fs + 2,
              fontWeight: FontWeight.w700,
              color: config.textColor,
            ),
          ),
          Text(_d.clientAddress, style: TextStyle(fontSize: fs, color: sub)),
          Text(_d.clientPhone, style: TextStyle(fontSize: fs, color: sub)),
          Text(_d.clientEmail, style: TextStyle(fontSize: fs, color: sub)),
        ],
      ),
    );
  }

  /// Infos de facture (2 colonnes : N°/DATE | ÉCHÉANCE/DÉVISE).
  Widget _buildInvoiceInfo() {
    final sub = config.textColor.withValues(alpha: 0.55);
    final fs = config.fontSize(FontSizeSection.invoiceInfo);
    final bold = TextStyle(
        fontSize: fs, fontWeight: FontWeight.w600, color: config.textColor);
    final light = TextStyle(fontSize: fs, color: sub);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        Row(children: [
          Expanded(
              child: _infoCell('FACTURE N°', _d.invoiceNumber, bold, light)),
          Expanded(child: _infoCell('DATE', _d.issueDate, bold, light)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _infoCell('ÉCHÉANCE', _d.dueDate, bold, light)),
          Expanded(child: _infoCell('DEVISE', _d.currency, bold, light)),
        ]),
      ]),
    );
  }

  Widget _infoCell(
      String label, String value, TextStyle bold, TextStyle light) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: light),
      const SizedBox(height: 2),
      Text(value, style: bold),
    ]);
  }

  /// Tableau des lignes (Description | QTÉ | Prix | Montant).
  Widget _buildItemsTable() {
    final header = config.primaryColor;
    final textColor = config.textColor;
    final fs = config.fontSize(FontSizeSection.companyClient) - 1;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      decoration: BoxDecoration(
        border: Border.all(
            color: config.primaryColor.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          color: header,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
          child: const Row(children: [
            Expanded(
                flex: 3,
                child: Text('Désignation',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700))),
            Expanded(
                flex: 1,
                child: Text('QTÉ',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700))),
            Expanded(
                flex: 2,
                child: Text('Prix',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700))),
            Expanded(
                flex: 2,
                child: Text('Montant',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700))),
          ]),
        ),
        ...List.generate(_d.items.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Divider(
                height: 1,
                thickness: 1,
                color: config.primaryColor.withValues(alpha: 0.08),
                indent: 10,
                endIndent: 10);
          }
          final item = _d.items[i ~/ 2];
          return Container(
            color: i ~/ 2 % 2 == 0
                ? config.backgroundColor
                : config.primaryColor.withValues(alpha: 0.02),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: Text(item.description,
                    style: TextStyle(fontSize: fs, color: textColor)),
              ),
              Expanded(
                  flex: 1,
                  child: Text(item.quantity,
                      style: TextStyle(fontSize: fs, color: textColor),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text(item.unitPrice,
                      style: TextStyle(fontSize: fs, color: textColor),
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text(item.amount,
                      style: TextStyle(
                          fontSize: fs,
                          color: textColor,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right)),
            ]),
          );
        }),
      ]),
    );
  }

  // ─── TOTALS + TAMPON PAYÉ ───────────────────────────────────────
  Widget _buildTotals() {
    final textColor = config.textColor;
    final fs = config.fontSize(FontSizeSection.invoiceInfo);
    final sub = textColor.withValues(alpha: 0.55);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              _totalRow('Sous-total', _d.subtotal,
                  TextStyle(fontSize: fs, color: sub)),
              const SizedBox(height: 4),
              _totalRow('TVA (18%)', _d.tax,
                  TextStyle(fontSize: fs, color: sub)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: config.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL TTC',
                        style: TextStyle(
                            fontSize: fs,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text(_d.total,
                        style: TextStyle(
                            fontSize: fs + 1,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          if (config.showPaidStamp)
            Positioned(
              top: -24,
              right: -30,
              child: _PaidStamp(),
            ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, TextStyle style) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }

  Widget _buildSignature() {
    final sub = config.textColor.withValues(alpha: 0.45);
    final fs = config.fontSize(FontSizeSection.companyClient) - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(width: 110, height: 1, color: sub),
              const SizedBox(height: 4),
              Text('Signature', style: TextStyle(fontSize: fs, color: sub)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── PIED DE PAGE (bande rayée + mentions légales) ─────────────
  Widget _buildFooter() {
    final fs = config.fontSize(FontSizeSection.companyClient) - 1;
    return Stack(
      children: [
        SizedBox(
          height: 56,
          child: CustomPaint(
            painter: _DiagonalStripesPainter(color: config.primaryColor),
            child: const SizedBox.expand(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _d.legalText,
                style: TextStyle(
                    fontSize: fs - 1,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                    height: 1.3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Merci pour votre confiance',
                style: TextStyle(
                    fontSize: fs,
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 🎨 Motif à moitié-ton (points) pour la bande d'en-tête.
class _HalftonePainter extends CustomPainter {
  final Color color;
  const _HalftonePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.22);
    const radius = 1.6;
    const spacing = 9.0;
    for (double y = 2; y < size.height; y += spacing) {
      final offset = (y / spacing) % 2 == 0 ? 0.0 : spacing / 2;
      for (double x = offset; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HalftonePainter old) => old.color != color;
}

/// 🎨 Rayures diagonales pour le pied de page.
class _DiagonalStripesPainter extends CustomPainter {
  final Color color;
  const _DiagonalStripesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    const spacing = 16.0;
    final count = (size.width + size.height) / spacing + 2;
    for (int i = -2; i < count; i++) {
      final start = Offset(i * spacing, 0);
      final end = Offset(i * spacing + size.height, size.height);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiagonalStripesPainter old) =>
      old.color != color;
}

/// 🧾 Tampon "PAYÉ" tourné en forme de cachet.
class _PaidStamp extends StatelessWidget {
  const _PaidStamp();

  @override
  Widget build(BuildContext context) {
    const stampColor = Color(0xFF2ECC71);
    return Transform.rotate(
      angle: -0.40,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: stampColor,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.star, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'PAYÉ',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            left: 4,
            child: Container(
              width: 42,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}