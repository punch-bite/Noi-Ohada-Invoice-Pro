// lib/screens/customization/my_templates_screen.dart
//
// 📁 « Mes modèles » : espace de stockage des modèles de factures achetés
// (ou débloqués gratuitement) par l'utilisateur. Il peut les personnaliser
// (drag & drop) ou les définir comme modèle actif.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/template_selection_service.dart';
import '../../services/template_service.dart';

class MyTemplatesScreen extends StatefulWidget {
  const MyTemplatesScreen({super.key});

  @override
  State<MyTemplatesScreen> createState() => _MyTemplatesScreenState();
}

class _MyTemplatesScreenState extends State<MyTemplatesScreen> {
  final TemplateService _templateService = TemplateService();
  List<InvoiceTemplate> _mine = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AppAuthProvider>().user?.id ?? '';
    final mine = await _templateService.getMyTemplates(userId);
    if (!mounted) return;
    setState(() {
      _mine = mine;
      _loading = false;
    });
  }

  Future<void> _use(InvoiceTemplate t) async {
    await TemplateSelectionService.setActiveTemplateId(t.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${t.name} défini comme modèle actif'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('📁 Mes modèles',
            style: TextStyle(color: text, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Boutique',
            icon: Icon(Icons.storefront_outlined, color: text),
            onPressed: () => context.push('/templates'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _mine.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 140),
                        Icon(Icons.folder_open,
                            size: 64, color: sub.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Center(
                            child: Text('Aucun modèle pour le moment')),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            'Achetez des modèles ou débloquez-en gratuitement '
                            'dans la boutique.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: sub),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: FilledButton.icon(
                            onPressed: () => context.push('/templates'),
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text('Voir la boutique'),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: _mine.length,
                      itemBuilder: (context, index) {
                        final t = _mine[index];
                        return _tile(t, theme, isDark);
                      },
                    ),
            ),
    );
  }

  Widget _tile(InvoiceTemplate t, ThemeProvider theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/templates/preview', extra: t),
              child: Container(
                decoration: BoxDecoration(
                  color: t.backgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.primaryColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.description_outlined,
                        color: t.primaryColor, size: 30),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name,
                    style: TextStyle(
                        color: theme.textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _use(t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: t.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded,
                                  size: 14, color: t.primaryColor),
                              const SizedBox(width: 4),
                              Text('Utiliser',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: t.primaryColor)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            context.push('/templates/workspace', extra: t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.tune_rounded,
                                  size: 13, color: Colors.white),
                              SizedBox(width: 3),
                              Text('Personnaliser',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
