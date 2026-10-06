// lib/screens/customization/my_templates_screen.dart
//
// 📁 Mes Modèles : bibliothèque des modèles acquis + gestion du modèle actif.
// Épuré : héro animé, cards uniformes, statut cohérent (Actif / Autre).
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/template_custom_service.dart';
import '../../services/template_selection_service.dart';
import '../../services/template_service.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/template_thumbnail.dart';

class MyTemplatesScreen extends StatefulWidget {
  const MyTemplatesScreen({super.key});

  @override
  State<MyTemplatesScreen> createState() => _MyTemplatesScreenState();
}

class _MyTemplatesScreenState extends State<MyTemplatesScreen> {
  final TemplateService _templateService = TemplateService();

  List<InvoiceTemplate> _myTemplates = [];
  InvoiceTemplate? _activeTemplate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final userId = auth.user?.id ?? '';

    final activeId = await TemplateSelectionService.getActiveTemplateId();
    var list = await _templateService.getMyTemplates(userId);
    if (list.isEmpty) {
      list = InvoiceTemplate.getDefaultTemplates();
    }

    InvoiceTemplate? active;
    if (activeId != null) {
      active = list.firstWhere((t) => t.id == activeId,
          orElse: () => list.first);
    } else if (list.isNotEmpty) {
      active = list.first;
    }

    if (!mounted) return;
    setState(() {
      _myTemplates = list;
      _activeTemplate = active;
      _isLoading = false;
    });
  }

  Future<void> _setActiveTemplate(InvoiceTemplate template) async {
    await TemplateSelectionService.setActiveTemplateId(template.id);
    if (!mounted) return;
    setState(() => _activeTemplate = template);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('« ${template.name} » est désormais votre modèle actif'),
        backgroundColor: RoyalColors.tertiary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _resetTemplateCustom(InvoiceTemplate template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Réinitialiser ?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Les personnalisations de « ${template.name} » seront perdues.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await TemplateCustomService.clearCustom(template.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('« ${template.name} » réinitialisé'),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final goldAccent = theme.accentGold;

    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Mes modèles',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 19,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Boutique',
            icon: Icon(Icons.add_shopping_cart_rounded,
                color: goldAccent, size: 22),
            onPressed: () => context.push('/templates'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: goldAccent))
          : RefreshIndicator(
              onRefresh: _loadTemplates,
              color: goldAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Héro : modèle actif ──
                    if (_activeTemplate != null)
                      _buildActiveHero(
                        _activeTemplate!,
                        theme,
                        textColor,
                        subTextColor,
                      ).animate().fadeIn(duration: 400.ms).slideY(
                            begin: 0.1,
                            end: 0,
                            duration: 400.ms,
                            curve: Curves.easeOut,
                          ),
                    const SizedBox(height: 28),

                    // ── Section : tous les modèles ──
                    Row(
                      children: [
                        Text(
                          'Bibliothèque',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: goldAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_myTemplates.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: goldAccent,
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => context.push('/templates'),
                          icon: Icon(Icons.add_rounded,
                              color: goldAccent, size: 18),
                          label: Text(
                            'Ajouter',
                            style: TextStyle(
                              color: goldAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8),
                            minimumSize: const Size(0, 32),
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    ..._myTemplates.asMap().entries.map((entry) {
                      final i = entry.key;
                      final t = entry.value;
                      final isActive = t.id == _activeTemplate?.id;
                      return _buildTemplateCard(
                        t,
                        isActive: isActive,
                        theme: theme,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        goldAccent: goldAccent,
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 100 + (i * 60)),
                            duration: 400.ms,
                          )
                          .slideY(
                            begin: 0.06,
                            end: 0,
                            duration: 400.ms,
                            curve: Curves.easeOut,
                          );
                    }),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Héro : grand carte du modèle actif ──
  Widget _buildActiveHero(
    InvoiceTemplate template,
    ThemeProvider theme,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            template.primaryColor,
            template.primaryColor.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: template.primaryColor.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 13),
                    SizedBox(width: 5),
                    Text(
                      'MODÈLE ACTIF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: 44,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 22,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            template.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            template.description.isNotEmpty
                ? template.description
                : template.category,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/templates/workspace',
                      extra: template),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Personnaliser'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: template.primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => context.push('/templates/preview',
                      extra: template),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: const Icon(Icons.visibility_outlined,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Card uniforme d'un modèle ──
  Widget _buildTemplateCard(
    InvoiceTemplate t, {
    required bool isActive,
    required ThemeProvider theme,
    required Color textColor,
    required Color subTextColor,
    required Color goldAccent,
  }) {
    final isDark = theme.isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? goldAccent.withValues(alpha: 0.5)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04)),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/templates/preview', extra: t),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Aperçu miniature
                      Container(
                        width: 60,
                        height: 72,
                        decoration: BoxDecoration(
                          color: t.backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: t.primaryColor.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: TemplateThumbnail(template: t),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                if (isActive) _activeBadge(goldAccent),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.description.isNotEmpty
                                  ? t.description
                                  : t.category,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Réinitialiser (discret)
                      InkWell(
                        onTap: () => _resetTemplateCustom(t),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.refresh_rounded,
                                  size: 14,
                                  color: subTextColor.withValues(alpha: 0.8)),
                              const SizedBox(width: 4),
                              Text(
                                'Reset',
                                style: TextStyle(
                                  color: subTextColor.withValues(alpha: 0.8),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Aperçu
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => context.push(
                              '/templates/preview', extra: t),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Icon(Icons.visibility_outlined,
                                size: 18, color: subTextColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Éditer
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.push('/templates/workspace', extra: t),
                        icon: const Icon(Icons.tune_rounded, size: 15),
                        label: const Text('Éditer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (!isActive) ...[
                        const SizedBox(width: 8),
                        // Activer
                        OutlinedButton(
                          onPressed: () => _setActiveTemplate(t),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: goldAccent,
                            side: BorderSide(
                                color: goldAccent.withValues(alpha: 0.5),
                                width: 1.2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          child: const Text('Activer'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _activeBadge(Color goldAccent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: goldAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 11, color: goldAccent),
          const SizedBox(width: 4),
          Text(
            'ACTIF',
            style: TextStyle(
              color: goldAccent,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}