// lib/widgets/template_thumbnail.dart
//
// 🖼️ Vignette visuelle d'un modèle de facture pour la boutique et les
// galeries de modèles.
//
// • Si le modèle embarque une image (`fileData` base64 jpeg/png, téléversée
//   par l'admin) → elle est affichée en couverture.
// • Sinon → une mini-facture STYLISÉE est dessinée à partir des couleurs et
//   options du modèle (couleur principale, couleurs texte/fond, bordure,
//   logo, QR) : en-tête coloré, tableau simulé, bloc totaux, pied QR.
//
// Léger (pur Container/Row/Column) : conçu pour des grilles de cartes.
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/invoice_template.dart';

class TemplateThumbnail extends StatelessWidget {
  final InvoiceTemplate template;
  const TemplateThumbnail({super.key, required this.template});

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

  // ── Mini-facture stylisée ─────────────────────────────────────────────────
  Widget _drawn() {
    final t = template;
    final onPrimary = t.primaryColor.computeLuminance() > 0.55
        ? const Color(0xFF1E1A1F)
        : Colors.white;
    final line = t.textColor.withValues(alpha: 0.22);
    final lineSoft = t.textColor.withValues(alpha: 0.12);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: t.backgroundColor,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── En-tête coloré : logo + nom entreprise + FACTURE ──
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: t.primaryColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                if (t.showLogo) ...[
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: onPrimary.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          height: 4.5,
                          width: 54,
                          color: onPrimary.withValues(alpha: 0.9)),
                      const SizedBox(height: 3),
                      Container(
                          height: 3,
                          width: 38,
                          color: onPrimary.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
                Text(
                  'FACTURE',
                  style: TextStyle(
                    color: onPrimary,
                    fontSize: 6.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),

          // ── Bloc client / méta ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 3,
                        width: 30,
                        color: t.primaryColor.withValues(alpha: 0.8)),
                    const SizedBox(height: 3),
                    Container(height: 3, width: 44, color: lineSoft),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(height: 3, width: 26, color: lineSoft),
                  const SizedBox(height: 3),
                  Container(height: 3, width: 26, color: lineSoft),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          _tableSection(t, line, lineSoft),
        ],
      ),
    );
  }

  // ── Tableau simulé + totaux + pied QR/termes ──────────────────────────────
  Widget _tableSection(InvoiceTemplate t, Color line, Color lineSoft) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: t.showBorder
                    ? Border.all(color: t.primaryColor.withValues(alpha: 0.4))
                    : Border.all(color: lineSoft),
                borderRadius: BorderRadius.circular(5),
              ),
              padding: const EdgeInsets.all(5),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(height: 2.5, width: 34, color: line),
                      Container(height: 2.5, width: 12, color: line),
                      Container(height: 2.5, width: 20, color: line),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ...List.generate(3, (i) {
                    final w = 70.0 - i * 8;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(height: 3, width: w, color: lineSoft),
                          const Spacer(),
                          Container(height: 3, width: 16, color: lineSoft),
                        ],
                      ),
                    );
                  }),
                  const Spacer(),
                  Container(height: 3, color: line),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(height: 3, width: 28, color: lineSoft),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: t.primaryColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'TOTAL',
                          style: TextStyle(
                            color: t.primaryColor.computeLuminance() > 0.55
                                ? const Color(0xFF1E1A1F)
                                : Colors.white,
                            fontSize: 5.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (t.showPaymentQR || t.showPaymentTerms) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                if (t.showPaymentQR)
                  Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      border: Border.all(color: line, width: 1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                if (t.showPaymentTerms) ...[
                  if (t.showPaymentQR) const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 2.5, width: 50, color: lineSoft),
                        const SizedBox(height: 2.5),
                        Container(height: 2.5, width: 36, color: lineSoft),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}