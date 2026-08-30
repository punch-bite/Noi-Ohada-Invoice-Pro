// lib/screens/customization/templates_screen.dart
//
// 🧩 Sélecteur de modèles de facture : modèles intégrés + modèles créés par
// l'admin (boutique). Le modèle choisi devient le modèle « actif », mémorisé
// localement via TemplateSelectionService (persistance hors-ligne) puis
// appliqué aux aperçus PDF / impressions.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/invoice_template.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/template_selection_service.dart';
import '../../services/template_service.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final TemplateService _templateService = TemplateService();
  List<InvoiceTemplate> _templates = [];
  String? _activeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Fusion : modèles par défaut + ceux créés par l'admin (boutique),
    // sans doublons — même logique que l'écran de détail facture.
    final defaults = InvoiceTemplate.getDefaultTemplates();
    List<InvoiceTemplate> adminTemplates = [];
    try {
      adminTemplates = await _templateService.getAllTemplates();
    } catch (_) {}
    final adminIds = adminTemplates.map((e) => e.id).toSet();
    final templates = [
      ...defaults.where((d) => !adminIds.contains(d.id)),
      ...adminTemplates,
    ];

    // ✅ Modèle actif choisi précédemment (sélection persistante).
    final activeId = await TemplateSelectionService.getActiveTemplateId();
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _activeId = activeId;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final subProvider = context.watch<SubscriptionProvider>();
    final canAccessPremium = subProvider.canAccessPremiumTemplates;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: _buildAppBar(context, theme, canAccessPremium),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: _templates.length,
                itemBuilder: (context, index) {
                  final template = _templates[index];
                  final isLocked = template.isPremium && !canAccessPremium;
                  return TemplateCard(
                    template: template,
                    isLocked: isLocked,
                    isActive: _activeId == template.id,
                    onTap: () =>
                        _handleTemplateTap(context, template, isLocked, theme),
                  );
                },
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ThemeProvider theme, bool canAccess) {
    return AppBar(
      title: Text(
        'Modèles de Facture', 
        style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      backgroundColor: theme.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: theme.textColor, size: 20),
        onPressed: () => context.pop(),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Icon(
                canAccess ? Icons.stars_rounded : Icons.lock_outline_rounded, 
                size: 18, 
                color: canAccess ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                canAccess ? 'Accès Premium activé' : 'Modèles Premium verrouillés',
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.w600,
                  color: canAccess ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTemplateTap(BuildContext context, InvoiceTemplate template,
      bool isLocked, ThemeProvider theme) async {
    if (isLocked) {
      _showUpgradeDialog(context, theme);
      return;
    }
    // ✅ Persiste réellement la sélection : le modèle devient le modèle
    // actif, retrouvé au prochain rendu PDF / à la prochaine ouverture.
    await TemplateSelectionService.setActiveTemplateId(template.id);
    if (!mounted) return;
    setState(() => _activeId = template.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${template.name} défini comme modèle actif'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '⭐ Accès Premium requis',
          style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Passez à la formule supérieure pour débloquer l\'intégralité des designs exclusifs.',
          style: TextStyle(color: theme.subTextColor, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: theme.subTextColor, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Voir les offres', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class TemplateCard extends StatelessWidget {
  final InvoiceTemplate template;
  final bool isLocked;
  final bool isActive;
  final VoidCallback onTap;

  const TemplateCard({
    super.key, 
    required this.template, 
    required this.isLocked, 
    required this.isActive, 
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return Card(
      color: theme.cardColor,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive
              ? theme.primaryColor
              : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
          width: isActive ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: template.backgroundColor,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: template.primaryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.description_outlined, 
                            color: template.primaryColor, 
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    if (isLocked)
                      Container(
                        color: Colors.black.withValues(alpha: 0.4),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_rounded, 
                              color: Colors.white, 
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    if (isActive)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Text(
                template.name, 
                style: TextStyle(
                  fontWeight: FontWeight.w600, 
                  color: theme.textColor,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          ],
        ),
      ),
    );
  }
}