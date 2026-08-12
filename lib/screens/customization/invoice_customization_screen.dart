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
  
  InvoiceSettings _settings = InvoiceSettings();
  final List<Color> _presetColors = [
    const Color(0xFF4338CA),
    const Color(0xFF00695C),
    const Color(0xFFD84315),
    const Color(0xFF0B3D91),
    const Color(0xFF8E24AA),
    const Color(0xFF262626),
  ];
  final List<String> _fonts = [
    'Roboto',
    'Inter',
    'Poppins',
    'Open Sans',
    'Montserrat',
  ];
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
        title: Text(
          'Personnalisation', 
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 18),
        ),
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
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final cardColor = theme.cardColor;

    return Selector<SubscriptionProvider, bool>(
      selector: (_, provider) => provider.canAccessPremiumTemplates,
      builder: (context, canAccessPremium, _) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Modèles de facture', textColor),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final t = _templates[index];
                    return TemplateCard(
                      template: t,
                      isSelected: _selectedTemplate?.id == t.id,
                      isLocked: t.isPremium && !canAccessPremium,
                      onTap: () {
                        if (t.isPremium && !canAccessPremium) {
                          _showUpgradeDialog(context, theme);
                        } else {
                          setState(() => _selectedTemplate = t);
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
              _buildSectionTitle('Options d\'affichage', textColor),
              const SizedBox(height: 12),
              
              // Liste des options de personnalisation
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
                child: Column(
                  children: [
                    // ✅ CORRECTION 2 : Utilisation propre de copyWith pour l'état immutable
                    _buildSwitchTile(
                      title: 'Afficher le logo de l\'entreprise',
                      subtitle: 'Ajouter votre logo officiel sur l\'en-tête',
                      value: _settings.showLogo,
                      icon: Icons.image_outlined,
                      theme: theme,
                      onChanged: (val) => setState(() {
                        _settings = _settings.copyWith(showLogo: val);
                      }),
                    ),
                    Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    _buildSwitchTile(
                      title: 'Ajouter un cadre de facture',
                      subtitle: 'Ajoute une bordure stylisée autour du document',
                      value: _settings.showBorder,
                      icon: Icons.border_all_rounded,
                      theme: theme,
                      onChanged: (val) => setState(() {
                        _settings = _settings.copyWith(showBorder: val);
                      }),
                    ),
                    Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    _buildSwitchTile(
                      title: 'Filigrane de sécurité',
                      subtitle: 'Affiche un texte en arrière-plan',
                      value: _settings.showWatermark,
                      icon: Icons.layers_outlined,
                      theme: theme,
                      onChanged: (val) => setState(() {
                        _settings = _settings.copyWith(showWatermark: val);
                      }),
                    ),
                    Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    _buildSwitchTile(
                      title: 'Code QR de paiement',
                      subtitle: 'Permet de scanner pour payer par Mobile Money',
                      value: _settings.showPaymentQR,
                      icon: Icons.qr_code_2_rounded,
                      theme: theme,
                      onChanged: (val) => setState(() {
                        _settings = _settings.copyWith(showPaymentQR: val);
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Palette de couleurs', textColor),
                    const SizedBox(height: 12),
                    _buildColorPicker(
                      title: 'Couleur primaire',
                      current: _settings.primaryColor,
                      onSelected: (color) => setState(() => _settings = _settings.copyWith(primaryColor: color)),
                    ),
                    const SizedBox(height: 12),
                    _buildColorPicker(
                      title: 'Couleur secondaire',
                      current: _settings.secondaryColor,
                      onSelected: (color) => setState(() => _settings = _settings.copyWith(secondaryColor: color)),
                    ),
                    const SizedBox(height: 12),
                    _buildColorPicker(
                      title: 'Couleur du fond',
                      current: _settings.backgroundColor,
                      onSelected: (color) => setState(() => _settings = _settings.copyWith(backgroundColor: color)),
                    ),
                    const SizedBox(height: 12),
                    _buildColorPicker(
                      title: 'Couleur du texte',
                      current: _settings.textColor,
                      onSelected: (color) => setState(() => _settings = _settings.copyWith(textColor: color)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Typographie & filigrane', textColor),
                    const SizedBox(height: 12),
                    _buildFontSelector(theme),
                    const SizedBox(height: 16),
                    _buildSliderTile(
                      title: 'Taille du texte',
                      min: 10,
                      max: 20,
                      value: _settings.fontSize,
                      onChanged: (value) => setState(() => _settings = _settings.copyWith(fontSize: value)),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Texte du filigrane',
                      value: _settings.watermarkText,
                      hintText: 'Entrez le texte du filigrane',
                      onChanged: (value) => setState(() => _settings = _settings.copyWith(watermarkText: value)),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedTemplate == null
                            ? null
                            : () {
                                context.push(
                                  '/templates/preview',
                                  extra: {
                                    'template': _selectedTemplate!,
                                    'settings': _settings,
                                  },
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Voir l’aperçu', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14, 
        fontWeight: FontWeight.bold, 
        color: color.withValues(alpha: 0.9),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ThemeProvider theme,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, color: theme.primaryColor),
      title: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textColor),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11, color: theme.subTextColor),
      ),
      activeThumbColor: theme.primaryColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
  Widget _buildColorPicker({
    required String title,
    required Color current,
    required ValueChanged<Color> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: current.computeLuminance() > 0.4 ? Colors.black87 : Colors.white),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presetColors.map((color) {
            final isSelected = color.toARGB32() == current.toARGB32();
            return GestureDetector(
              onTap: () => onSelected(color),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.transparent,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFontSelector(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Police',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.textColor),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _settings.fontFamily,
              items: _fonts
                  .map((font) => DropdownMenuItem(
                        value: font,
                        child: Text(font, style: TextStyle(fontFamily: font, fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _settings = _settings.copyWith(fontFamily: value));
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderTile({
    required String title,
    required double min,
    required double max,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            Text('${value.toStringAsFixed(0)} pt', style: const TextStyle(fontSize: 12)),
          ],
        ),
        Slider(value: value, min: min, max: max, divisions: (max - min).toInt(), onChanged: onChanged),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required String hintText,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            style: const TextStyle(fontSize: 14),
            controller: TextEditingController(text: value),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
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
          'Passez à la formule supérieure pour débloquer de magnifiques modèles exclusifs et professionnels.',
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
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  const TemplateCard({
    super.key, 
    required this.template, 
    required this.isSelected, 
    required this.isLocked, 
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 125,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? theme.primaryColor.withValues(alpha: 0.08) : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? theme.primaryColor 
                    : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: template.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.description_outlined, 
                    color: template.primaryColor, 
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  template.name, 
                  style: TextStyle(
                    color: theme.textColor, 
                    fontSize: 12, 
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isLocked)
            Positioned(
              top: 8,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded, 
                  size: 12, 
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}