// lib/screens/customization/invoice_preview_screen.dart
//
// 👁️ APERÇU « Détails Facture » — maquette adaptée au thème glass
// indigo → violet de l'application.
//
// Structure (maquette 3) :
//   • AppBar « Détails Facture » + action SAUVER
//   • Aperçu plein de la facture (InvoiceMockupPreview) + zoom
//   • Barre sombre en bas : boutons circulaires « Éditer » et
//     « Personnaliser » (Pastille dorée).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:noi_ohada_invoice_pro/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';

import '../../models/customization_config.dart';
import '../../models/invoice_template.dart';
import '../../providers/theme_provider.dart';
import '../../services/customization_service.dart';
import '../../widgets/invoice_mockup_preview.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final CustomizationConfig? config;
  final InvoiceTemplate? template;

  const InvoicePreviewScreen({super.key, this.config, this.template});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  CustomizationConfig _config = CustomizationConfig.defaults;
  bool _loading = true;
  bool _saving = false;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = widget.config ?? await CustomizationService.instance.load();
    if (!mounted) return;
    setState(() {
      _config = cfg;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await CustomizationService.instance.save(_config);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Aperçu enregistré'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    context.pop(_config);
  }

  /// « Éditer » : ouvre l'espace drag & drop du modèle actif
  /// (ou le sélecteur de modèles si aucun n'est fourni).
  Future<void> _onEdit() async {
    if (widget.template != null) {
      await context.push('/templates/workspace', extra: widget.template);
    } else {
      await context.push('/templates/select');
    }
    if (mounted) await _load();
  }

  /// « Personnaliser » : ouvre l'écran de personnalisation et applique
  /// la configuration mise à jour en retour.
  Future<void> _onCustomize() async {
    final result = await context.push<CustomizationConfig>(
      '/customization',
      extra: _config,
    );
    if (result is CustomizationConfig && mounted) {
      setState(() => _config = result);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
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
        title: Text(
          'Détails Facture',
          style: TextStyle(
            color: text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          _saveButton(theme),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: theme.primaryColor))
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(child: _previewArea(theme, isDark)),
                  _inkBar(theme, isDark),
                ],
              ),
            ),
    );
  }

  /// Bouton « SAUVER » — pill en dégradé indigo → violet.
  Widget _saveButton(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: _saving ? null : _save,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          child: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'SAUVER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Zone d'aperçu + FAB zoom ───────────────────────────────────────────
  Widget _previewArea(ThemeProvider theme, bool isDark) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              scale: _zoom,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: InvoiceMockupPreview(config: _config),
              ),
            ),
          ),
        ),
        // FAB zoom à droite (maquette 3)
        Positioned(
          right: 12,
          bottom: 8,
          child: Column(
            children: [
              _zoomFab(
                Icons.add,
                theme,
                isDark,
                () => setState(
                    () => _zoom = (_zoom + 0.2).clamp(0.6, 2.2)),
              ),
              const SizedBox(height: 8),
              _zoomFab(
                Icons.remove,
                theme,
                isDark,
                () => setState(() => _zoom = (_zoom - 0.2).clamp(0.6, 2.2)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _zoomFab(
      IconData icon, ThemeProvider theme, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: theme.primaryColor),
      ),
    );
  }

  // ── Barre sombre « Éditer / Personnaliser » (maquette 3) ───────────────
  Widget _inkBar(ThemeProvider theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151722) : const Color(0xFF23262F),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _inkAction(
            icon: Icons.edit_outlined,
            label: 'Éditer',
            isDark: isDark,
            onTap: _onEdit,
          ),
          _inkAction(
            icon: Icons.palette_outlined,
            label: 'Personnaliser',
            isDark: isDark,
            goldDot: true,
            onTap: _onCustomize,
          ),
        ],
      ),
    );
  }

  Widget _inkAction({
    required IconData icon,
    required String label,
    required bool isDark,
    bool goldDot = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.09),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Icon(icon, size: 24, color: Colors.white),
              ),
              if (goldDot)
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9B949),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF151722)
                            : const Color(0xFF23262F),
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
