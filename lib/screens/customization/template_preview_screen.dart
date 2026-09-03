// lib/screens/customization/template_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/invoice_layout.dart';
import '../../models/invoice_template.dart';
import '../../services/template_custom_service.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/invoice_renderer.dart';

/// 👁️ Aperçu grand écran A4 haute fidélité du modèle de facture avec impression PDF.
class TemplatePreviewScreen extends StatefulWidget {
  final InvoiceTemplate template;

  const TemplatePreviewScreen({super.key, required this.template});

  @override
  State<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends State<TemplatePreviewScreen> {
  static const Color goldAccent = Color(0xFFC9A227);
  static const Color bgSurface = Color(0xFF1E1A24);
  static const Color bgBackground = Color(0xFF120F17);

  late InvoiceLayoutConfig _layoutConfig;
  bool _isLoading = true;
  double _zoom = 0.85;

  @override
  void initState() {
    super.initState();
    _layoutConfig = InvoiceLayoutConfig.defaultLayout();
    _loadData();
  }

  Future<void> _loadData() async {
    final custom = await TemplateCustomService.loadCustom(widget.template.id);
    if (!mounted) return;
    setState(() {
      if (custom.positions.isNotEmpty) {
        _layoutConfig = InvoiceLayoutConfig.fromMap(custom.positions);
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBackground,
      appBar: AppBar(
        backgroundColor: bgSurface,
        elevation: 0,
        title: Column(
          children: [
            Text(
              widget.template.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: 'Manrope',
              ),
            ),
            Text(
              'Aperçu Format A4 (SYSCOHADA)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Personnaliser (Drag & Drop)',
            icon: const Icon(Icons.tune, color: goldAccent),
            onPressed: () =>
                context.push('/templates/workspace', extra: widget.template),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: goldAccent),
            )
          : Column(
              children: [
                Container(
                  color: bgSurface,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.zoom_out,
                                color: Colors.white70),
                            onPressed: () {
                              setState(() {
                                _zoom = (_zoom - 0.1).clamp(0.4, 1.5);
                              });
                            },
                          ),
                          Text(
                            '${(_zoom * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.zoom_in,
                                color: Colors.white70),
                            onPressed: () {
                              setState(() {
                                _zoom = (_zoom + 0.1).clamp(0.4, 1.5);
                              });
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Impression PDF pour "${widget.template.name}"'),
                                  backgroundColor: RoyalColors.primary,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text('Tester PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RoyalColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              context.push('/templates/workspace',
                                  extra: widget.template);
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Éditer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: goldAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Transform.scale(
                        scale: _zoom,
                        alignment: Alignment.topCenter,
                        child: Material(
                          elevation: 16,
                          shadowColor: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.template.backgroundColor,
                              borderRadius: BorderRadius.circular(4),
                              border: widget.template.showBorder
                                  ? Border.all(
                                      color: widget.template.primaryColor
                                          .withValues(alpha: 0.3),
                                      width: 1.5)
                                  : null,
                            ),
                            child: InvoiceRenderer(
                              config: _layoutConfig,
                              mode: RenderMode.render,
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .fade()
                          .scale(duration: const Duration(milliseconds: 300)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
