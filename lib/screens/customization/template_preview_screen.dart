import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/invoice_template.dart';
import '../../models/invoice_settings.dart';
import '../../models/invoice_layout.dart';
import '../../models/company.dart';
import '../../services/database_service.dart';
import '../../services/template_custom_service.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/invoice_renderer.dart';

class TemplatePreviewScreen extends StatefulWidget {
  final InvoiceTemplate template;
  final InvoiceSettings? settings;
  const TemplatePreviewScreen(
      {super.key, required this.template, this.settings});
  @override
  State<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends State<TemplatePreviewScreen> {
  final DatabaseService _db = DatabaseService();
  Company? _company;
  late InvoiceLayoutConfig _layoutConfig;
  bool _isLoading = true;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _layoutConfig = InvoiceLayoutConfig.defaultLayout();
    _loadData();
  }

  Future<void> _loadData() async {
    final company = await _db.getCompany();
    final custom = await TemplateCustomService.loadCustom(widget.template.id);
    if (mounted) {
      setState(() {
        _company = company;
        if (custom.positions.isNotEmpty) {
          _layoutConfig = InvoiceLayoutConfig.fromMap(custom.positions);
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final text = theme.textColor;
    final primary = theme.primaryColor;
    final bg = theme.backgroundColor;
    if (_isLoading) {
      return Scaffold(backgroundColor: bg, body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg, elevation: 0, scrolledUnderElevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 20, color: text), onPressed: () => context.pop()),
        title: Text(widget.template.name, style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.01)),
        actions: [
          _iconBtn(Icons.remove, () => setState(() => _zoom = (_zoom - 0.1).clamp(0.5, 2.0)), text),
          _iconBtn(Icons.add, () => setState(() => _zoom = (_zoom + 0.1).clamp(0.5, 2.0)), text),
          _iconBtn(Icons.edit_outlined, () => context.push('/templates/workspace', extra: widget.template), primary),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Center(child: Transform.scale(scale: _zoom, child: _buildPreviewCard(isDark, primary))))),
        _buildBottomActions(primary, text, isDark),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, Color color) {
    return IconButton(icon: Icon(icon, size: 20, color: color), onPressed: onTap, splashRadius: 22);
  }

  Widget _buildPreviewCard(bool isDark, Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: InvoiceRenderer(config: _layoutConfig, mode: RenderMode.render, elementBuilder: (ctx, element, pos) => _buildElement(element, pos))),
    );
  }

  Widget _buildBottomActions(Color primary, Color text, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2433) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => context.push('/templates/workspace', extra: widget.template), style: OutlinedButton.styleFrom(foregroundColor: text, side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFCBD5E1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), minimumSize: const Size(0, 48)), child: const Text('Personnaliser', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(onPressed: () => context.push('/templates/workspace', extra: widget.template), style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), minimumSize: const Size(0, 48)), child: const Text('Modifier le layout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)))),
      ]),
    );
  }

  Widget _buildElement(LayoutElement element, ElementPosition pos) {
    final t = widget.template;
    final c = _company;
    final primary = t.primaryColor;
    final text = t.textColor;
    final sub = text.withValues(alpha: 0.7);
    switch (element) {
      case LayoutElement.logo:
        return Container(width: 40, height: 40, decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Icon(Icons.business, color: primary, size: 24));
      case LayoutElement.companyName:
        return Text(c?.name ?? 'Mon entreprise', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: text));
      case LayoutElement.companyAddress:
        return Text(c?.address ?? 'Adresse', style: TextStyle(fontSize: 10, color: sub));
      case LayoutElement.companyPhone:
        return Text(c?.phone ?? '+225 00 00 00 00', style: TextStyle(fontSize: 10, color: sub));
      case LayoutElement.companyEmail:
        return Text(c?.email ?? 'contact@entreprise.com', style: TextStyle(fontSize: 10, color: sub));
      case LayoutElement.invoiceTitle:
        return Text('FACTURE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primary, letterSpacing: 1.5));
      case LayoutElement.clientName:
        return Text('Nom Client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text));
      case LayoutElement.clientAddress:
        return Text('Adresse', style: TextStyle(fontSize: 10, color: sub));
      case LayoutElement.clientPhone:
        return Text('Téléphone', style: TextStyle(fontSize: 10, color: sub));
      case LayoutElement.clientEmail:
        return Text('email@client.com', style: TextStyle(fontSize: 10, color: sub));
      case LayoutElement.itemsTable:
        return Column(children: [
          Container(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), decoration: BoxDecoration(color: primary, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))), child: Row(children: [Expanded(flex: 3, child: Text('Désignation', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600))), Expanded(child: Text('Qté', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600))), Expanded(child: Text('Prix', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600))), Expanded(child: Text('Total', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)))])),
          Container(padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8), decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!)), child: Row(children: [Expanded(flex: 3, child: Text('Produit', style: TextStyle(fontSize: 9, color: text))), Expanded(child: Text('2', style: TextStyle(fontSize: 9, color: text))), Expanded(child: Text('50 000', style: TextStyle(fontSize: 9, color: text))), Expanded(child: Text('100 000', style: TextStyle(fontSize: 9, color: text)))])),
        ]);
      case LayoutElement.subtotal:
        return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Sous-total', style: TextStyle(fontSize: 11, color: text)), Text('100 000', style: TextStyle(fontSize: 11, color: text))]);
      case LayoutElement.taxAmount:
        return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('TVA (18%)', style: TextStyle(fontSize: 11, color: text)), Text('18 000', style: TextStyle(fontSize: 11, color: text))]);
      case LayoutElement.discount:
        return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Remise', style: TextStyle(fontSize: 11, color: const Color(0xFFBA1A1A))), Text('-0', style: TextStyle(fontSize: 11, color: const Color(0xFFBA1A1A)))]);
      case LayoutElement.totalAmount:
        return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primary)), Text('118 000 FCFA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primary))]));
      case LayoutElement.footerText:
        return Text('Conforme aux normes OHADA', style: TextStyle(fontSize: 9, color: sub, fontStyle: FontStyle.italic));
      case LayoutElement.qrCode:
        return t.showPaymentQR ? Container(width: 70, height: 70, decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)), child: Icon(Icons.qr_code_2, size: 50, color: primary)) : const SizedBox.shrink();
      case LayoutElement.signature:
        return Column(children: [Container(width: 120, height: 1, color: Colors.grey), const SizedBox(height: 4), Text('Signature', style: TextStyle(fontSize: 10, color: sub))]);
    }
  }
}
