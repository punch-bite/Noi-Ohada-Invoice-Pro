// lib/screens/dashboard/invoice_settings_edit_screen.dart
//
// 🎨 Éditeur des paramètres de facture (`InvoiceSettings`) :
// filigrane, couleurs (primaire/secondaire/fond/texte), police, taille,
// visibilité des blocs et marges.
//
// Persistance : `SettingsService` (Hive offline-first + Firestore).
//
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/settings_service.dart';
import '../../models/invoice_settings.dart';
import '../../services/theme_service.dart';
import '../../widgets/glass_widgets.dart';

/// Palette de couleurs prédéfinies pour le sélecteur (évite une dépendance
/// externe à un color-picker). L'utilisateur peut aussi saisir la valeur hex.
final List<Color> kPaletteColors = [
  const Color(0xFF1A237E), // Indigo profond
  const Color(0xFF3949AB), // Indigo clair
  const Color(0xFF4338CA), // Violet
  const Color(0xFF7C3AED), // Violet vif
  const Color(0xFF0B5394), // Bleu océan
  const Color(0xFF0277BD), // Cyan
  const Color(0xFF2E7D32), // Vert
  const Color(0xFFEF6C00), // Orange
  const Color(0xFFC62828), // Rouge
  const Color(0xFF6A1B97), // Mauve foncé
  const Color(0xFF424242), // Gris anthracite
  const Color(0xFF1A1A1A), // Noir
];

class InvoiceSettingsEditScreen extends StatefulWidget {
  const InvoiceSettingsEditScreen({super.key});

    @override
  State<InvoiceSettingsEditScreen> createState() =>
      _InvoiceSettingsEditScreenState();
}

class _InvoiceSettingsEditScreenState extends State<InvoiceSettingsEditScreen> {
  final SettingsService _settingsService = SettingsService.instance;

  bool _isLoading = true;
  bool _isSaving = false;
  late InvoiceSettings _settings;

  final _watermarkCtrl = TextEditingController();
  final _fontFamilyCtrl = TextEditingController();
  final _fontSizeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _watermarkCtrl.dispose();
    _fontFamilyCtrl.dispose();
    _fontSizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await _settingsService.loadSettings();
    setState(() {
      _settings = s;
      _watermarkCtrl.text = s.watermarkText;
      _fontFamilyCtrl.text = s.fontFamily;
      _fontSizeCtrl.text =
          s.fontSize.toStringAsFixed(s.fontSize % 1 == 0 ? 0 : 1);
      _isLoading = false;
    });
  }

  /// Reconstruit [_settings] en conservant l'instance précédente (immuable).
  InvoiceSettings _copyWith(InvoiceSettings next) {
    return _settings.copyWith(
      showLogo: next.showLogo,
      showBorder: next.showBorder,
      showWatermark: next.showWatermark,
      showPaymentQR: next.showPaymentQR,
      primaryColor: next.primaryColor,
      secondaryColor: next.secondaryColor,
      backgroundColor: next.backgroundColor,
      textColor: next.textColor,
      fontFamily: next.fontFamily,
      fontSize: next.fontSize,
      showCompanyInfo: next.showCompanyInfo,
      showClientInfo: next.showClientInfo,
      showPaymentTerms: next.showPaymentTerms,
      showTaxDetails: next.showTaxDetails,
      watermarkText: next.watermarkText,
    );
  }

    // ── Widgets réutilisables ─────────────────────────────────────────────

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    try {
      await _settingsService.saveSettings(_settings);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Paramètres de facture enregistrés !'),
          ]),
          backgroundColor: ThemeService.primaryLight,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Échec de l\'enregistrement : $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _toggle(String label, bool value, Function(bool) onChanged,
      {Color? color}) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      value: value,
      activeThumbColor: color ?? ThemeService.primaryLight,
      onChanged: (v) => setState(() => onChanged(v)),
    );
  }

  Future<void> _pickColor(
          String field, Color current, InvoiceSettings Function(Color) apply) async {
    Color picked = current;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Couleur $field',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in kPaletteColors)
              GestureDetector(
                onTap: () => setState(() => picked = c),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: c,
                  child: picked == c
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              ),
            // Saisie hex manuelle
            SizedBox(
              width: 90,
              child: TextField(
                controller: TextEditingController(
                    text: _colorHex(picked)),
                decoration: const InputDecoration(
                    labelText: 'Hex',
                    isDense: true,
                    border: OutlineInputBorder()),
                onChanged: (v) {
                  final c = _parseHex(v);
                  if (c != null) setState(() => picked = c);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _settings = _copyWith(apply(picked));
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static String _colorHex(Color c) {
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}';
  }

    static Color? _parseHex(String hex) {
    final v = hex.replaceAll('#', '').trim();
    if (v.length == 6 || v.length == 8) {
      final n = int.tryParse(v, radix: 16);
      if (n != null) return Color(n);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: const Text('Personnalisation de facture',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('ENREGISTRER',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
            body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final s = _settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor =
        textColor.withValues(alpha: isDark ? 0.6 : 0.55);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Section : Filigrane ──
        _sectionTitle('Filigrane', isDark, subTextColor),
        _glassCard(cardColor, isDark, [
          TextField(
            controller: _watermarkCtrl,
            decoration: const InputDecoration(
                labelText: 'Texte du filigrane',
                border: OutlineInputBorder(),
                hintText: 'Laisser vide pour désactiver'),
            onChanged: (v) => setState(() {
              _settings = _copyWith(_settings.copyWith(
                  watermarkText: v, showWatermark: v.isNotEmpty));
            }),
          ),
          _toggle('Afficher le filigrane', s.showWatermark, (v) =>
              _settings = _copyWith(_settings.copyWith(showWatermark: v))),
        ]),
        const SizedBox(height: 20),

        // ── Section : Couleurs ──
        _sectionTitle('Couleurs', isDark, subTextColor),
        _glassCard(cardColor, isDark, [
          _colorPickerRow('Primaire', s.primaryColor,
              (c) => s.copyWith(primaryColor: c)),
          _colorPickerRow('Secondaire', s.secondaryColor,
              (c) => s.copyWith(secondaryColor: c)),
          _colorPickerRow('Fond', s.backgroundColor,
              (c) => s.copyWith(backgroundColor: c)),
          _colorPickerRow('Texte', s.textColor, (c) => s.copyWith(textColor: c)),
        ]),
        const SizedBox(height: 20),

        // ── Section : Typographie ──
        _sectionTitle('Police & taille', isDark, subTextColor),
        _glassCard(cardColor, isDark, [
          TextField(
            controller: _fontFamilyCtrl,
            decoration: const InputDecoration(
                labelText: 'Famille de police',
                border: OutlineInputBorder(),
                hintText: 'Roboto, WorkSans, ...'),
                        onChanged: (v) => setState(() {
              _settings = _copyWith(_settings.copyWith(fontFamily: v.isNotEmpty ? v : 'Roboto'));
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fontSizeCtrl,
            decoration: const InputDecoration(
                labelText: 'Taille (pt)', border: OutlineInputBorder()),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              final n = double.tryParse(v.replaceAll(',', '.'));
              if (n != null && n > 0) {
                setState(() {
                  _settings = _copyWith(_settings.copyWith(fontSize: n));
                });
              }
            },
          ),
        ]),
        const SizedBox(height: 20),

        // ── Section : Affichage ──
        _sectionTitle('Affichage des éléments', isDark, subTextColor),
        _glassCard(cardColor, isDark, [
          _toggle('Logo entreprise', s.showLogo,
              (v) => _settings = _copyWith(_settings.copyWith(showLogo: v))),
          _toggle('Bordure', s.showBorder,
              (v) => _settings = _copyWith(_settings.copyWith(showBorder: v))),
          _toggle('Infos entreprise', s.showCompanyInfo, (v) =>
              _settings = _copyWith(_settings.copyWith(showCompanyInfo: v))),
          _toggle('Infos client', s.showClientInfo, (v) =>
              _settings = _copyWith(_settings.copyWith(showClientInfo: v))),
          _toggle('Conditions de paiement', s.showPaymentTerms, (v) =>
              _settings = _copyWith(_settings.copyWith(showPaymentTerms: v))),
          _toggle('Détails fiscaux', s.showTaxDetails, (v) =>
              _settings = _copyWith(_settings.copyWith(showTaxDetails: v))),
          _toggle('QR code paiement', s.showPaymentQR, (v) =>
              _settings = _copyWith(_settings.copyWith(showPaymentQR: v))),
        ]),
        const SizedBox(height: 24),
                 _saveButton(),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeService.primaryLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        icon: _isSaving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.save),
        label: Text(_isSaving
            ? 'ENREGISTREMENT...'
            : 'ENREGISTRER LES MODIFICATIONS'),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87)),
    );
  }

  Widget _glassCard(Color cardColor, bool isDark, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12, width: 1),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _colorPickerRow(
      String label, Color current, InvoiceSettings Function(Color) apply) {
    final hex = _colorHex(current);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(radius: 14, backgroundColor: current),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      subtitle: Text(hex, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.palette_outlined, size: 20),
      onTap: () => _pickColor(label, current, apply),
    );
  }
}





