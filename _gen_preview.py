import os

preview = """// lib/screens/customization/template_preview_screen.dart
//
// 👁️ APERÇU DE LA FACTURE — Prévisualisation du modèle sélectionné.
//
// Refonte fidèle à la maquette Stitch :
//   • Header avec retour + titre "Détails Facture"
//   • Bouton "Sauver" en haut à droite
//   • Carte facture A4 avec header coloré (logo, n° facture, statut, dates)
//   • Infos société/client, tableau items, totaux, footer
//   • Barre d'actions flottante (zoom, info, edit, personnaliser)
//   • Bottom bar sombre avec Éditer/Personnaliser

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:noi_ohada_invoice_pro/theme/royal_ledger.dart";

import "../../models/invoice_template.dart";
import "../../models/company.dart";
import "../../services/database_service.dart";
import "../../services/template_custom_service.dart";

class TemplatePreviewScreen extends StatefulWidget {
  final InvoiceTemplate template;

  const TemplatePreviewScreen({super.key, required this.template});

  @override
  State<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends State<TemplatePreviewScreen> {
  final DatabaseService _db = DatabaseService();
  Company? _company;
  bool _isLoading = true;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final company = await _db.getCompany();
    if (!mounted) return;
    setState(() {
      _company = company;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RoyalColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildPreview()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: RoyalColors.surfaceContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(Icons.arrow_back, size: 20, color: RoyalColors.onSurface),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Détails Facture",
              style: RoyalTextStyles.headlineMd.copyWith(color: RoyalColors.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () async {
              await TemplateCustomService.saveCustom(widget.template.id, positions: {}, mapping: {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Sauvegardé")),
                );
              }
            },
            child: Text(
              "Sauver",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: RoyalColors.secondary,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: FittedBox(
              fit: BoxFit.fitWidth,
              child: Transform.scale(
                scale: _zoom,
                child: _invoiceCard(),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _floatingActions(),
        ),
      ],
    );
  }

  Widget _invoiceCard() {
    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: RoyalColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: RoyalColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _invoiceHeader(),
          _invoiceBody(),
          _invoiceFooter(),
        ],
      ),
    );
  }

  Widget _invoiceHeader() {
    final t = widget.template;
    return Container(
      height: 128,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.primaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.business, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "FACTURE",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "N° FP-2025-001",
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                ),
                const Spacer(),
                Text(
                  "Date: 25/03/2025",
                  style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: RoyalColors.tertiary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              "PAYÉE",
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceBody() {
    final t = widget.template;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_company?.name ?? "Mon entreprise", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: RoyalColors.onSurface)),
                    Text(_company?.address ?? "Adresse", style: TextStyle(fontSize: 10, color: RoyalColors.onSurfaceVariant)),
                    Text(_company?.phone ?? "+225 00 00 00 00", style: TextStyle(fontSize: 10, color: RoyalColors.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Client", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: RoyalColors.secondary)),
                    Text("Nom Client", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: RoyalColors.onSurface)),
                    Text("Adresse client", style: TextStyle(fontSize: 10, color: RoyalColors.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: RoyalColors.outlineVariant),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: t.primaryColor.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text("Description", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: RoyalColors.onSurface))),
                      Expanded(child: Text("Qté", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: RoyalColors.onSurface))),
                      Expanded(child: Text("Prix", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: RoyalColors.onSurface))),
                      Expanded(child: Text("Total", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: RoyalColors.onSurface))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text("Produit exemple", style: TextStyle(fontSize: 10, color: RoyalColors.onSurface))),
                      Expanded(child: Text("2", style: TextStyle(fontSize: 10, color: RoyalColors.onSurface))),
                      Expanded(child: Text("50 000", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: RoyalColors.onSurface))),
                      Expanded(child: Text("100 000", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: RoyalColors.onSurface))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 200,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Sous-Total", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: RoyalColors.onSurfaceVariant)),
                      Text("100 000", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: RoyalColors.onSurface)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: t.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Montant Total", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: RoyalColors.secondary)),
                        Text("100 000", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: RoyalColors.secondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Termes et conditions", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: RoyalColors.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text("Merci pour votre confiance.", style: TextStyle(fontSize: 10, color: RoyalColors.onSurfaceVariant.withValues(alpha: 0.8))),
          const SizedBox(height: 12),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: widget.template.primaryColor.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _floatingActions() {
    return Column(
      children: [
        _actionBtn(Icons.zoom_out, () => setState(() => _zoom = (_zoom - 0.1).clamp(0.5, 2.0))),
        const SizedBox(height: 8),
        _actionBtn(Icons.zoom_in, () => setState(() => _zoom = (_zoom + 0.1).clamp(0.5, 2.0))),
        const SizedBox(height: 8),
        _actionBtn(Icons.info_outline, () {}),
        const SizedBox(height: 8),
        _actionBtn(Icons.edit_outlined, () => context.push("/templates/workspace", extra: widget.template)),
      ],
    );
  }

  Widget _actionBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: RoyalColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: RoyalColors.outlineVariant.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: RoyalColors.onSurface),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: RoyalColors.inverseSurface.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: RoyalColors.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _bottomAction(Icons.edit_outlined, "Éditer", () {}),
            _bottomAction(Icons.palette_outlined, "Personnaliser", () => context.push("/templates/workspace", extra: widget.template)),
          ],
        ),
      ),
    );
  }

  Widget _bottomAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: RoyalColors.outlineVariant.withValues(alpha: 0.2)),
              color: RoyalColors.surface.withValues(alpha: 0.05),
            ),
            child: Icon(icon, size: 20, color: RoyalColors.inverseOnSurface),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: RoyalColors.inverseOnSurface),
          ),
        ],
      ),
    );
  }
}
"""

with open("lib/screens/customization/template_preview_screen.dart", "w", encoding="utf-8") as f:
    f.write(preview)
print("Preview OK")