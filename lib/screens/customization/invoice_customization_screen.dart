// lib/screens/customization/invoice_customization_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/invoice_template.dart';
import '../../models/invoice_settings.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/template_service.dart';
import 'template_preview_screen.dart';

class InvoiceCustomizationScreen extends StatefulWidget {
  const InvoiceCustomizationScreen({super.key});

  @override
  State<InvoiceCustomizationScreen> createState() =>
      _InvoiceCustomizationScreenState();
}

class _InvoiceCustomizationScreenState
    extends State<InvoiceCustomizationScreen> {
  final TemplateService _templateService = TemplateService();
  List<InvoiceTemplate> _templates = [];
  final List<InvoiceTemplate> _defaultTemplates =
      InvoiceTemplate.getDefaultTemplates();
  InvoiceTemplate? _selectedTemplate;
  final InvoiceSettings _settings = InvoiceSettings();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    final customTemplates = await _templateService.getAllTemplates();
    _templates = [..._defaultTemplates, ...customTemplates];
    if (_templates.isNotEmpty) {
      _selectedTemplate = _templates.firstWhere(
        (t) => t.isDefault,
        orElse: () => _templates.first,
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    // Sauvegarder les options (à implémenter avec SharedPreferences ou Firestore)
    await Future.delayed(const Duration(milliseconds: 300));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paramètres sauvegardés'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final subscription = context.watch<SubscriptionProvider>();
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;
    final card = theme.cardColor;
    final canAccessPremium = subscription.canAccessPremiumTemplates;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          'Personnalisation',
          style:
              TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save_outlined, color: primary),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === MODÈLES ===
                  _sectionTitle('Modèles', text),
                  const SizedBox(height: 10),
                  Text(
                    canAccessPremium
                        ? 'Tous les modèles disponibles'
                        : '⭐ Abonnez-vous pour débloquer les modèles Premium',
                    style: TextStyle(
                      fontSize: 12,
                      color: canAccessPremium ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _templates.length,
                      itemBuilder: (context, index) {
                        final template = _templates[index];
                        final isSelected = _selectedTemplate?.id == template.id;
                        final isLocked =
                            template.isPremium && !canAccessPremium;
                        return _templateCard(template, isSelected, isLocked,
                            isDark, text, sub, primary);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // === APERÇU ===
                  if (_selectedTemplate != null) ...[
                    _sectionTitle('Aperçu', text),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        final isLocked =
                            _selectedTemplate!.isPremium && !canAccessPremium;
                        if (isLocked) {
                          _showUpgradeDialog(context);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TemplatePreviewScreen(
                                  template: _selectedTemplate!),
                            ),
                          );
                        }
                      },
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isDark
                                  ? Colors.grey[800]!
                                  : Colors.grey[200]!,
                              width: 0.5),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 36,
                                color: _selectedTemplate!.primaryColor,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedTemplate!.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: text,
                                    fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedTemplate!.description,
                                style: TextStyle(color: sub, fontSize: 12),
                              ),
                              if (_selectedTemplate!.isPremium &&
                                  canAccessPremium) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '⭐ Premium',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // === OPTIONS DE PERSONNALISATION ===
                  _sectionTitle('Options', text),
                  const SizedBox(height: 12),
                  _buildSwitch(
                    'Afficher le logo',
                    _settings.showLogo,
                    (v) => setState(() => _settings.showLogo = v),
                    isDark,
                    primary,
                  ),
                  _buildSwitch(
                    'Afficher la TVA',
                    _settings.showTaxDetails,
                    (v) => setState(() => _settings.showTaxDetails = v),
                    isDark,
                    primary,
                  ),
                  _buildSwitch(
                    'Afficher les conditions de paiement',
                    _settings.showPaymentTerms,
                    (v) => setState(() => _settings.showPaymentTerms = v),
                    isDark,
                    primary,
                  ),
                  _buildSwitch(
                    'Afficher le QR Code paiement',
                    _settings.showPaymentQR,
                    (v) => setState(() => _settings.showPaymentQR = v),
                    isDark,
                    primary,
                  ),
                  const SizedBox(height: 32),

                  // Bouton Enregistrer
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Enregistrer',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ===== WIDGETS =====

  Widget _sectionTitle(String title, Color text) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: text.withOpacity(0.8),
      ),
    );
  }

  Widget _templateCard(
    InvoiceTemplate template,
    bool isSelected,
    bool isLocked,
    bool isDark,
    Color text,
    Color sub,
    Color primary,
  ) {
    return GestureDetector(
      onTap: isLocked
          ? () => _showUpgradeDialog(context)
          : () => setState(() => _selectedTemplate = template),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withOpacity(0.08)
              : (isDark ? Colors.grey[850] : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primary
                : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
            width: isSelected ? 2 : 0.5,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Miniature
                Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: template.backgroundColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.receipt_long,
                      color: template.primaryColor,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  template.name,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? primary : text,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (template.isPremium) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isLocked ? Colors.grey : Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLocked ? Icons.lock : Icons.star,
                          size: 8,
                          color: isLocked ? Colors.white : Colors.black,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          isLocked ? 'Premium' : 'Débloqué',
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                            color: isLocked ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (isSelected)
              Positioned(
                right: 0,
                top: 0,
                child: Icon(Icons.check_circle, color: primary, size: 16),
              ),
            if (isLocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                      child: Icon(Icons.lock, color: Colors.white, size: 20)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch(
    String label,
    bool value,
    Function(bool) onChanged,
    bool isDark,
    Color primary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87, fontSize: 13)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.watch<ThemeProvider>().cardColor,
        title: const Text('⭐ Premium'),
        content: const Text(
          'Ce modèle est réservé aux abonnés Pro et Business.\n\n'
          'Passez à un plan supérieur pour y accéder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Voir les offres'),
          ),
        ],
      ),
    );
  }
}
