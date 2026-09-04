// lib/widgets/stitch_a4_invoice_preview.dart
//
// 🧾 Aperçu A4 « Aperçu de la facture » — maquette Stitch
// (design/stitch_refined_billing_interface/aper_u_de_la_facture/)
//
// Fidèle à la maquette mobile :
//   • En-tête coloré à motif de points + dégradé horizontal → logo rond à
//     initiales, colonne « DE » (société + coordonnées), titre FACTURE/DEVIS
//   • Section « FACTURÉ À » ↔ récap FACTURE N° / DATE / ÉCHÉANCE / DEVISE
//   • Tableau des lignes (en-tête teinté, séparateurs fins outline-variant)
//   • Totaux alignés à droite + bloc plein « MONTANT TOTAL »
//   • « Termes et conditions » + bande décorative basse
//   • Tampon « PAYÉ » doré pivoté de -12°
//
// Les PARAMÈTRES DE PERSONNALISATION sauvegardés sont appliqués :
//   • couleurs du modèle (primaryColor / backgroundColor / showBorder /
//     fontSize de InvoiceTemplate)
//   • visibilité des blocs du layout drag & drop (InvoiceLayoutConfig)
//   • fond de page : image personnalisée ou préréglage de la palette
//     (TemplateBackgroundSettings — opacité / flou / ajustement)

import 'dart:convert' show base64Decode;
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/invoice_layout.dart';
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

  /// Données d'exemple — identiques à la maquette Stitch.
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

  /// Montant formaté maquette : `448 400` (séparateur = espace).
  static String money(double value) =>
      NumberFormat('#,##0').format(value).replaceAll(',', ' ');

  /// Montant préfixé du symbole de la maquette : `Fr0`.
  static String amount(double value) => 'Fr${money(value)}';
}

/// Aperçu A4 de la facture — fidèle à la maquette Stitch, piloté par les
/// personnalisations sauvegardées du modèle actif.
class StitchA4InvoicePreview extends StatelessWidget {
  /// Données de la facture (réelles ou d'exemple).
  final StitchPreviewData data;

  /// 🎨 Couleur d'accent du modèle (primaryColor) — mauve de la maquette
  /// (`RoyalColors.secondary`) par défaut.
  final Color? accentColor;

  /// 🎨 Couleur de papier du modèle (backgroundColor) — blanc par défaut.
  final Color? pageColor;

  final bool showLogo;
  final bool showBorder;
  final bool showTaxDetails;
  final bool showPaymentTerms;
  final bool showPaymentQR;

  /// Police du modèle (corps de texte) : 'WorkSans' | 'Manrope' | autre.
  final String fontFamily;

  /// Échelle typographique du modèle (fontSize / 12).
  final double fontScale;

  /// 🧩 Layout drag & drop : gère la visibilité de chaque bloc.
  final InvoiceLayoutConfig layoutConfig;

  /// 🎨 Réglages de fond sauvegardés (image / préréglage palette).
  final TemplateBackgroundSettings backgroundSettings;

  /// Image de fond décodée (découle de [backgroundSettings]).
  final Uint8List? backgroundImage;

  /// Affiche le tampon « PAYÉ » pivoté (factures payées / aperçu maquette).
  final bool showPaidStamp;

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
  });

  static const InvoiceLayoutConfig _emptyConfig = InvoiceLayoutConfig(
    positions: {},
    styles: {},
  );

  /// Largeur de référence du dessin (échelle interne, rendue par FittedBox).
  static const double _paperWidth = 560;

  /// Hauteur A4 correspondante (ratio 794 × 1123).
  static const double _paperBaseHeight = _paperWidth * 1123 / 794;

  bool _vis(LayoutElement element) => layoutConfig.styleOf(element).visible;

  String get _bodyFont =>
      (fontFamily == 'Manrope' || fontFamily == 'WorkSans')
          ? fontFamily
          : 'WorkSans';

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

    // Hauteur adaptative : la zone blanche de la maquette absorbe ~4 lignes,
    // au-delà la page s'allonge pour ne jamais déborder.
    double extra = 0;
    if (data.items.length > 4) extra += (data.items.length - 4) * 34 * k;
    final bool qrOn = showPaymentQR && _vis(LayoutElement.qrCode);
    final bool signOn = _vis(LayoutElement.signature);
    final bool legalOn = _vis(LayoutElement.legalMention) &&
        (data.rccm.isNotEmpty ||
            data.taxId.isNotEmpty ||
            data.legalMention.isNotEmpty);
    if (qrOn) extra += 96 * k;
    if (signOn) extra += 46 * k;
    if (legalOn) extra += 30 * k;

    final bool hasBg = backgroundImage != null || backgroundSettings.hasPreset;

    return FittedBox(
      fit: BoxFit.fitWidth,
      child: Container(
        width: _paperWidth,
        height: _paperBaseHeight + extra,
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
            // 🎨 Fond personnalisé (image ou préréglage) — sous le contenu.
            Positioned.fill(
              child: TemplateBackgroundLayer(
                presetId:
                    backgroundImage != null ? '' : backgroundSettings.presetId,
                imageBytes: backgroundImage,
                opacity: backgroundSettings.hasCustomImage
                    ? 1.0
                    : backgroundSettings.opacity,
                blur: backgroundSettings.blur,
                fit: backgroundSettings.fit,
              ),
            ),
            // Voile de lisibilité quand un fond décoratif est posé.
            if (hasBg)
              Positioned.fill(
                child: ColoredBox(
                  color: darkPage
                      ? Colors.black.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.45),
                ),
              ),
            // Tampon « PAYÉ » doré pivoté (-12°) — maquette.
            if (showPaidStamp && data.isPaid)
              Positioned.fill(child: _buildPaidStamp()),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(accent, onAccent, k),
                _buildInfoRow(cText, cSub, k),
                Expanded(
                  child:
                      _buildItemsAndTotals(accent, onAccent, cText, cSub, line, k),
                ),
                _buildFooter(accent, cText, cSub, line, k),
                // Bande décorative basse de la maquette.
                Container(height: 8, color: accent.withValues(alpha: 0.85)),
              ],
            ),
          ],
        ),
      ),
    );
  }

    // ============================================================
  //  🟣 EN-TÊTE — bandeau coloré à motif de points + dégradé
  // ============================================================

  Widget _buildHeader(Color accent, Color onAccent, double k) {
    final Color dotColor =
        Color.lerp(accent, Colors.black, 0.5)!.withValues(alpha: 0.55);

    return Container(
      color: accent,
      child: Stack(
        children: [
          // Motif de points (radial-gradient 8px, maquette).
          Positioned.fill(
            child: CustomPaint(
              painter: _DotsPatternPainter(dotColor),
              child: const SizedBox.expand(),
            ),
          ),
          // Dégradé de lisibilité gauche → droite (secondary/90 → /30).
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
          Padding(
            padding: EdgeInsets.fromLTRB(24 * k, 20 * k, 24 * k, 20 * k),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLogo) ...[
                  _buildLogo(onAccent, k),
                  SizedBox(width: 14 * k),
                ],
                Expanded(
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
                        data.companyName,
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
                        _contactLine(data.companyAddress, onAccent, k),
                      if (data.companyPhone.isNotEmpty)
                        _contactLine(data.companyPhone, onAccent, k),
                      if (data.companyEmail.isNotEmpty)
                        _contactLine(data.companyEmail, onAccent, k),
                      if (data.companyWebsite.isNotEmpty)
                        _contactLine(data.companyWebsite, onAccent, k),
                    ],
                  ),
                ),
                SizedBox(width: 10 * k),
                // Titre FACTURE / DEVIS — tracking large (maquette).
                Text(
                  data.isDevis ? 'DEVIS' : 'FACTURE',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 26 * k,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                    color: onAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  /// Logo rond : image de la société, sinon cercle à initiales (maquette).
  Widget _buildLogo(Color onAccent, double k) {
    final double size = 64 * k;
    final Widget fallback = Text(
      data.companyInitials.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 19 * k,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        color: const Color(0xFF93000A), // on-error-container (maquette)
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFDAD6), // error-container (maquette)
        shape: BoxShape.circle,
        border:
            Border.all(color: onAccent.withValues(alpha: 0.20), width: 2),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: data.companyLogoPath.isEmpty
          ? fallback
          : _logoImage(data.companyLogoPath, size, fallback),
    );
  }

  /// Charge le logo (data URI base64, URL ou chemin fichier) avec repli.
  Widget _logoImage(String path, double size, Widget fallback) {
    try {
      final ImageProvider provider;
      if (path.startsWith('data:image')) {
        final parts = path.split(',');
        provider =
            MemoryImage(base64Decode(parts.length == 2 ? parts[1] : path));
      } else if (path.startsWith('http')) {
        provider = NetworkImage(path);
      } else {
        provider = FileImage(File(path));
      }
      return Image(
        image: provider,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    } catch (_) {
      return fallback;
    }
  }

  // ============================================================
  //  📋 INFOS — « FACTURÉ À » ↔ N° / Date / Échéance / Devise
  // ============================================================

  Widget _buildInfoRow(Color cText, Color cSub, double k) {
    final rows = <(String, String)>[
      ('FACTURE N°', data.invoiceNumber),
      ('DATE', data.issueDate),
      ('ÉCHÉANCE', data.dueDate),
      ('DEVISE', data.currency),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(24 * k, 16 * k, 24 * k, 12 * k),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bloc « FACTURÉ À » — coordonnées du client.
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
                          data.clientName,
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
                        _clientLine(data.clientAddress, cSub, k),
                      if (_vis(LayoutElement.clientPhone) &&
                          data.clientPhone.isNotEmpty)
                        _clientLine(data.clientPhone, cSub, k),
                      if (_vis(LayoutElement.clientEmail) &&
                          data.clientEmail.isNotEmpty)
                        _clientLine(data.clientEmail, cSub, k),
                    ],
                  )
                : const SizedBox(),
          ),
          SizedBox(width: 16 * k),
          // Récap facture (min-w 140px en maquette).
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
  //  🧾 TABLEAU + TOTAUX
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
      padding: EdgeInsets.fromLTRB(24 * k, 4 * k, 24 * k, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_vis(LayoutElement.itemsTable)) ...[
            // En-tête du tableau (bg accent/80, coins hauts arrondis).
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 12 * k, vertical: 9 * k),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.82),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 8,
                    child: _thText('DESCRIPTION', onAccent, k),
                  ),
                  Expanded(
                    flex: 2,
                    child: _thText('QTÉ', onAccent, k,
                        align: TextAlign.center),
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
            // Corps du tableau.
            if (data.items.isEmpty)
              Container(
                height: 64 * k,
                padding: EdgeInsets.symmetric(horizontal: 12 * k),
                decoration: BoxDecoration(
                  border: Border(left: side, right: side, bottom: side),
                ),
                child: Row(
                  children: [
                    const Expanded(flex: 8, child: SizedBox()),
                    _cellBorder(flex: 2, side: side),
                    _cellBorder(flex: 3, side: side),
                    _cellBorder(flex: 3, side: side),
                  ],
                ),
              )
            else
              for (var i = 0; i < data.items.length; i++)
                _itemRow(data.items[i], cText, side, k),
          ],

          // Totaux — alignés à droite (maquette).
          if (_vis(LayoutElement.subtotal) || _vis(LayoutElement.totalAmount)) ...[
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
                    _totalLine('Remise',
                        '- ${StitchPreviewData.amount(data.discount)}', cSub, cText, k),
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

  /// Colonne bordée à gauche (séparateur vertical, maquette).
  Widget _cellBorder({required int flex, required BorderSide side}) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(border: Border(left: side)),
      ),
    );
  }

  Widget _itemRow(StitchPreviewItem item, Color cText, BorderSide side, double k) {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: side, right: side, bottom: side),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 10 * k),
      child: Row(
        children: [
          Expanded(
            flex: 8,
            child: Text(
              item.description,
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
          _itemCell(item.quantity.toString(), cText, k,
              flex: 2, align: TextAlign.center, side: side),
          _itemCell(StitchPreviewData.money(item.unitPrice), cText, k,
              flex: 3, align: TextAlign.right, side: side),
          _itemCell(StitchPreviewData.money(item.total), cText, k,
              flex: 3, align: TextAlign.right, side: side),
        ],
      ),
    );
  }

  Widget _itemCell(
    String text,
    Color cText,
    double k, {
    required int flex,
    required TextAlign align,
    required BorderSide side,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(border: Border(left: side)),
        padding: EdgeInsets.only(left: 8 * k),
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontFamily: _bodyFont,
            fontSize: 11.5 * k,
            color: cText,
          ),
        ),
      ),
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
  //  📜 PIED — termes & conditions / légal / QR / signature + bande
  // ============================================================

  Widget _buildFooter(
      Color accent, Color cText, Color cSub, Color line, double k) {
    final bool termsOn = showPaymentTerms && _vis(LayoutElement.footerText);
    final bool legalOn = _vis(LayoutElement.legalMention) &&
        (data.rccm.isNotEmpty ||
            data.taxId.isNotEmpty ||
            data.legalMention.isNotEmpty);
    final bool qrOn = showPaymentQR && _vis(LayoutElement.qrCode);
    final bool signOn = _vis(LayoutElement.signature);

    if (!termsOn && !legalOn && !qrOn && !signOn) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(24 * k, 0, 24 * k, 12 * k),
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
                        data.terms.isEmpty
                            ? 'Merci pour votre confiance.'
                            : data.terms,
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
                        'RCCM : ${data.rccm.isEmpty ? '—' : data.rccm}'
                        '  ·  N° Contribuable : ${data.taxId.isEmpty ? '—' : data.taxId}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'WorkSans',
                          fontSize: 9.5 * k,
                          color: cSub,
                        ),
                      ),
                      if (data.legalMention.isNotEmpty)
                        Text(
                          data.legalMention,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'WorkSans',
                            fontSize: 9.5 * k,
                            fontStyle: FontStyle.italic,
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
          if (signOn) ...[
            SizedBox(height: 14 * k),
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                children: [
                  Container(
                      width: 120 * k,
                      height: 1,
                      color: cSub.withValues(alpha: 0.45)),
                  SizedBox(height: 4 * k),
                  Text(
                    'Signature',
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
        ],
      ),
    );
  }

  // ============================================================
  //  🏷️ TAMPON « PAYÉ »
  // ============================================================

  Widget _buildPaidStamp() {
    return Center(
      child: Transform.rotate(
        angle: -12 * math.pi / 180,
        child: Opacity(
          opacity: 0.80,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: RoyalColors.tertiaryFixedDim,
                width: 4,
              ),
            ),
            child: Text(
              'PAYÉ',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 46,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
                color: RoyalColors.tertiaryFixedDim,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Conversion des modèles métier → données de l'aperçu.
extension StitchPreviewDataX on StitchPreviewData {
  /// Construit les données d'aperçu depuis une facture réelle.
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

/// Motif de points de l'en-tête (radial-gradient 8px de la maquette).
class _DotsPatternPainter extends CustomPainter {
  final Color color;
  _DotsPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const double cell = 8.0;
    const double radius = 1.2; // ~15 % de la cellule
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









