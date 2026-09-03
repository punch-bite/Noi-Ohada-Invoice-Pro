// lib/screens/customization/my_templates_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../services/template_custom_service.dart';
import '../../services/template_selection_service.dart';
import '../../services/template_service.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/glass_widgets.dart';

/// 📁 Mes Modèles : Bibliothèque des modèles enregistrés et gestion du modèle actif.
class MyTemplatesScreen extends StatefulWidget {
  const MyTemplatesScreen({super.key});

  @override
  State<MyTemplatesScreen> createState() => _MyTemplatesScreenState();
}

class _MyTemplatesScreenState extends State<MyTemplatesScreen> {
  static const Color goldAccent = Color(0xFFC9A227);
  static const Color bgSurface = Color(0xFF1E1A24);
  static const Color bgBackground = Color(0xFF120F17);

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
      active = list.firstWhere((t) => t.id == activeId, orElse: () => list.first);
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
        content: Text('Le modèle "${template.name}" est désormais actif.'),
        backgroundColor: RoyalColors.tertiary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetTemplateCustom(InvoiceTemplate template) async {
    await TemplateCustomService.clearCustom(template.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Personnalisation de "${template.name}" réinitialisée.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBackground,
      appBar: AppBar(
        backgroundColor: bgSurface,
        elevation: 0,
        title: const Text(
          'Mes Modèles de Facture',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Manrope',
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Ajouter depuis la Boutique',
            icon: const Icon(Icons.add_shopping_cart, color: goldAccent),
            onPressed: () => context.push('/templates'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: goldAccent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_activeTemplate != null) ...[
                    Text(
                      'Modèle Actuellement Utilisé',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 70,
                            decoration: BoxDecoration(
                              color: _activeTemplate!.backgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _activeTemplate!.primaryColor,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 30,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _activeTemplate!.primaryColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _activeTemplate!.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: goldAccent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: goldAccent),
                                      ),
                                      child: const Text(
                                        'ACTIF',
                                        style: TextStyle(
                                          color: goldAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _activeTemplate!.description,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        context.push('/templates/workspace',
                                            extra: _activeTemplate);
                                      },
                                      icon: const Icon(Icons.tune, size: 16),
                                      label: const Text('Personnaliser (Drag & Drop)'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: RoyalColors.primary,
                                        foregroundColor: Colors.white,
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
                        ],
                      ),
                    ).animate().fade().scale(duration: const Duration(milliseconds: 250)),
                    const SizedBox(height: 24),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Vos Modèles Enregistrés (${_myTemplates.length})',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => context.push('/templates'),
                        icon: const Icon(Icons.add, color: goldAccent, size: 18),
                        label: const Text(
                          'Boutique',
                          style: TextStyle(color: goldAccent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _myTemplates.length,
                    itemBuilder: (context, index) {
                      final t = _myTemplates[index];
                      final isActive = t.id == _activeTemplate?.id;

                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: t.primaryColor,
                                  radius: 16,
                                  child: Icon(Icons.palette, color: t.textColor, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        t.description,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isActive)
                                  const Icon(Icons.check_circle,
                                      color: goldAccent, size: 24)
                                else
                                  OutlinedButton(
                                    onPressed: () => _setActiveTemplate(t),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.3)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Activer',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                              ],
                            ),
                            const Divider(color: Colors.white12, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _resetTemplateCustom(t),
                                  icon: const Icon(Icons.refresh,
                                      size: 16, color: Colors.white54),
                                  label: const Text('Réinitialiser',
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      context.push('/templates/preview', extra: t),
                                  icon: const Icon(Icons.visibility, size: 16),
                                  label: const Text('Aperçu',
                                      style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.2)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      context.push('/templates/workspace', extra: t),
                                  icon: const Icon(Icons.tune, size: 16),
                                  label: const Text('Éditer',
                                      style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: RoyalColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fade().slideY(
                            begin: 0.05,
                            duration: Duration(milliseconds: 200 + (index * 40)),
                          );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
