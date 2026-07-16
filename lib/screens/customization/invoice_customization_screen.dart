// lib/screens/customization/invoice_customization_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/invoice_template.dart';
import '../../models/invoice_settings.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/template_service.dart';

class InvoiceCustomizationScreen extends StatefulWidget {
  const InvoiceCustomizationScreen({super.key});

  @override
  State<InvoiceCustomizationScreen> createState() => _InvoiceCustomizationScreenState();
}

class _InvoiceCustomizationScreenState extends State<InvoiceCustomizationScreen> {
  final TemplateService _templateService = TemplateService();
  List<InvoiceTemplate> _templates = [];
  InvoiceTemplate? _selectedTemplate;
  final InvoiceSettings _settings = InvoiceSettings();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final customTemplates = await _templateService.getAllTemplates();
    final all = [...InvoiceTemplate.getDefaultTemplates(), ...customTemplates];
    
    if (mounted) {
      setState(() {
        _templates = all;
        _selectedTemplate = all.firstWhere((t) => t.isDefault, orElse: () => all.first);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text('Personnalisation', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.textColor, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeProvider theme) {
    // Utilisation de Selector pour ne reconstruire que cette partie si le statut Premium change
    return Selector<SubscriptionProvider, bool>(
      selector: (_, provider) => provider.canAccessPremiumTemplates,
      builder: (context, canAccessPremium, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Modèles', theme.textColor),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final t = _templates[index];
                    return TemplateCard(
                      template: t,
                      isSelected: _selectedTemplate?.id == t.id,
                      isLocked: t.isPremium && !canAccessPremium,
                      onTap: () {
                        if (t.isPremium && !canAccessPremium) {
                          _showUpgradeDialog(context);
                        } else {
                          setState(() => _selectedTemplate = t);
                        }
                      },
                    );
                  },
                ),
              ),
              // Ajoutez ici vos autres widgets de paramètres (_buildSwitch, etc.)
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, Color color) => Text(
        title,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color.withOpacity(0.8)),
      );

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⭐ Accès Premium'),
        content: const Text('Passez à un plan supérieur pour débloquer ces modèles.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            child: const Text('Voir les offres'),
          ),
        ],
      ),
    );
  }
}

// Composant extrait pour la lisibilité et la performance
class TemplateCard extends StatelessWidget {
  final InvoiceTemplate template;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  const TemplateCard({
    super.key, 
    required this.template, 
    required this.isSelected, 
    required this.isLocked, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.1) : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? theme.primaryColor : Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Expanded(child: Icon(Icons.receipt_long, color: template.primaryColor)),
            Text(template.name, style: TextStyle(color: theme.textColor, fontSize: 12)),
            if (isLocked) const Icon(Icons.lock, size: 16, color: Colors.amber),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}