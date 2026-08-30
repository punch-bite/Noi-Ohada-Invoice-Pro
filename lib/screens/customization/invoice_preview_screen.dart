// lib/screens/customization/invoice_preview_screen.dart
//
// 🧾 Écran Aperçu (flow maquette) :
//   - Preview plein écran de la facture (style bande bleue, tampon PAYÉ…).
//   - Top bar : titre «Aperçu», icône zoom, action «Sauver».
//   - Bas de page : boutons «Éditer» et «Personnaliser».
//
// Basé sur [InvoicePreviewWidget] et [CustomizationConfig].
//
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/customization_config.dart';
import '../../models/invoice_template.dart';
import '../../providers/theme_provider.dart';
import '../../services/customization_service.dart';
import '../../widgets/invoice_preview_widget.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final InvoiceTemplate? template;
  final CustomizationConfig? config;

  const InvoicePreviewScreen({super.key, this.template, this.config});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  late CustomizationConfig _config;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _config = widget.config ?? CustomizationConfig.defaults;
    if (widget.config == null) {
      CustomizationService.instance.load().then((saved) {
        if (mounted && saved != _config) {
          setState(() => _config = saved);
        }
      });
    }
  }

  Future<void> _save() async {
    await CustomizationService.instance.save(_config);
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text('Configuration sauvegardée ✅'),
        duration: Duration(milliseconds: 1200),
      ),
    );
    Future.microtask(() => setState(() => _saved = false));
  }

  void _openCustomization() {
    context.push('/templates/customization/edit', extra: _config);
  }

  @override
  Widget build(BuildContext context) {
    return _buildScaffold();
  }

  Widget _buildScaffold() {
    final theme = context.watch<ThemeProvider>();
    final bg = theme.backgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(theme),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: InvoicePreviewWidget(
                    config: _config,
                    showShadow: _config.showShadow,
                  ),
                ),
              ),
            ),
            _buildBottomBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeProvider theme) {
    final textColor = theme.textColor;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: theme.isDarkMode
                  ? const Color(0xFF2A2F3D)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              'A4',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: theme.subTextColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Aperçu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Zoom',
            icon: Icon(Icons.zoom_in_map,
                color: textColor.withValues(alpha: 0.7), size: 22),
            onPressed: () {},
          ),
          IconButton(
            tooltip: _saved ? 'Sauvegardé' : 'Sauver',
            icon: Icon(
              _saved ? Icons.check_circle : Icons.save_outlined,
              color: _saved
                  ? Colors.green
                  : theme.primaryColor.withValues(alpha: 0.9),
              size: 22,
            ),
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.pop(),
              icon: Icon(Icons.edit_outlined,
                  color: theme.textColor.withValues(alpha: 0.7)),
              label: Text('Éditer',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: theme.textColor)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.dividerColor),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _openCustomization,
              icon: const Icon(Icons.palette_outlined, color: Colors.white),
              label: const Text(
                'Personnaliser',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}