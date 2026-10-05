// lib/widgets/template_background_palette.dart
//
// 🎨 PALETTE DE FONDS DE PAGE pour les factures — partagée par toute la
// logique de personnalisation :
//   • l'espace de personnalisation drag & drop (template_workspace_screen)
//   • l'aperçu d'un modèle (template_preview_screen)
//   • le détail d'une facture (invoice_detail_screen)
//
// 🔄 v3 : catalogue MULTI-MODÈLES (24+ presets, 6 familles) avec rendu PDF
// natif + rendu Flutter équivalent.
//
// ⚠️ IMPORTANT : `TemplateBackgroundSettings` N'EST PAS défini ici.
// La classe vit dans `lib/services/template_custom_service.dart` et est
// IMPORTÉE. Redéfinir la classe ici provoquerait un conflit de compilation
// dans tout fichier qui importe les deux modules.
//
// Compatibilité totale avec l'ancien code via `typedef BackgroundPreset`.
//
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
// ✅ IMPORT — pas de redéfinition locale.
import '../services/template_custom_service.dart'
    show TemplateBackgroundSettings;

// ═══════════════════════════════════════════════════════════════════════
//  FAMILLES
// ═══════════════════════════════════════════════════════════════════════

/// 🎨 Familles visuelles de fond.
enum BackgroundFamily {
  solid,
  gradient,
  pastel,
  dark,
  geometric,
  branded,
}

extension BackgroundFamilyLabel on BackgroundFamily {
  String get label {
    switch (this) {
      case BackgroundFamily.solid:
        return 'Unis';
      case BackgroundFamily.gradient:
        return 'Dégradés';
      case BackgroundFamily.pastel:
        return 'Pastels';
      case BackgroundFamily.dark:
        return 'Sombres';
      case BackgroundFamily.geometric:
        return 'Géométriques';
      case BackgroundFamily.branded:
        return 'Brandés';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  MODÈLE DE FOND PRÉDÉFINI
// ═══════════════════════════════════════════════════════════════════════

/// 🖼️ Modèle de fond prédéfini.
class MultiBackgroundPreset {
  final String id;
  final String label;
  final BackgroundFamily family;
  final List<Color> colors;
  final String pattern;
  final int patternSeed;

  const MultiBackgroundPreset({
    required this.id,
    required this.label,
    required this.family,
    required this.colors,
    this.pattern = 'none',
    this.patternSeed = 0,
  });

  Color get mainColor => colors.length > 1 ? colors[1] : colors.first;

  // ─────────────────────────────────────────────────────────────
  //  CATALOGUE
  // ─────────────────────────────────────────────────────────────
  static const List<MultiBackgroundPreset> all = [
    // ── Unis ────────────────────────────────────────────────
    MultiBackgroundPreset(
      id: 'solid_white',
      label: 'Blanc',
      family: BackgroundFamily.solid,
      colors: [Color(0xFFFFFFFF)],
    ),
    MultiBackgroundPreset(
      id: 'solid_ivory',
      label: 'Ivoire',
      family: BackgroundFamily.solid,
      colors: [Color(0xFFFFFBF2)],
    ),
    MultiBackgroundPreset(
      id: 'solid_lightgray',
      label: 'Gris clair',
      family: BackgroundFamily.solid,
      colors: [Color(0xFFF5F5F5)],
    ),

    // ── Dégradés ────────────────────────────────────────────
    MultiBackgroundPreset(
      id: 'gradient_blue',
      label: 'Bleu océan',
      family: BackgroundFamily.gradient,
      colors: [Color(0xFF0F4C81), Color(0xFF6FB3E0)],
    ),
    MultiBackgroundPreset(
      id: 'gradient_teal',
      label: 'Turquoise',
      family: BackgroundFamily.gradient,
      colors: [Color(0xFF008080), Color(0xFFB2DFDB)],
    ),
    MultiBackgroundPreset(
      id: 'gradient_gold',
      label: 'Or / Sable',
      family: BackgroundFamily.gradient,
      colors: [Color(0xFFBAAB6D), Color(0xFFFFF8E1)],
    ),
    MultiBackgroundPreset(
      id: 'gradient_purple',
      label: 'Violet doux',
      family: BackgroundFamily.gradient,
      colors: [Color(0xFF6A4C93), Color(0xFFE8DFF5)],
    ),
    MultiBackgroundPreset(
      id: 'gradient_green',
      label: 'Vert OHADA',
      family: BackgroundFamily.gradient,
      colors: [Color(0xFF1B5E20), Color(0xFFC8E6C9)],
    ),
    MultiBackgroundPreset(
      id: 'gradient_sunset',
      label: 'Coucher de soleil',
      family: BackgroundFamily.gradient,
      colors: [Color(0xFFE96443), Color(0xFFFFD194)],
    ),

    // ── Pastel ──────────────────────────────────────────────
    MultiBackgroundPreset(
      id: 'pastel_mint',
      label: 'Menthe',
      family: BackgroundFamily.pastel,
      colors: [Color(0xFFD9F2E6), Color(0xFFF2FBF7)],
    ),
    MultiBackgroundPreset(
      id: 'pastel_rose',
      label: 'Rose poudré',
      family: BackgroundFamily.pastel,
      colors: [Color(0xFFF7D9DE), Color(0xFFFFF7F9)],
    ),
    MultiBackgroundPreset(
      id: 'pastel_lavender',
      label: 'Lavande',
      family: BackgroundFamily.pastel,
      colors: [Color(0xFFE2DAF5), Color(0xFFF7F4FC)],
    ),
    MultiBackgroundPreset(
      id: 'pastel_sand',
      label: 'Sable',
      family: BackgroundFamily.pastel,
      colors: [Color(0xFFF0E6D2), Color(0xFFFBF7F0)],
    ),

    // ── Sombre ──────────────────────────────────────────────
    MultiBackgroundPreset(
      id: 'dark_charcoal',
      label: 'Anthracite',
      family: BackgroundFamily.dark,
      colors: [Color(0xFF1C1C1C), Color(0xFF2E2E2E)],
    ),
    MultiBackgroundPreset(
      id: 'dark_navy',
      label: 'Bleu nuit',
      family: BackgroundFamily.dark,
      colors: [Color(0xFF0A1A2F), Color(0xFF1C3A5E)],
      pattern: 'rings',
    ),
    MultiBackgroundPreset(
      id: 'dark_forest',
      label: 'Forêt',
      family: BackgroundFamily.dark,
      colors: [Color(0xFF102A1A), Color(0xFF1E4A2C)],
    ),

    // ── Géométrique ─────────────────────────────────────────
    MultiBackgroundPreset(
      id: 'geo_diagonal',
      label: 'Diagonale bicolore',
      family: BackgroundFamily.geometric,
      colors: [Color(0xFF0F4C81), Color(0xFFFFFBF2)],
      patternSeed: 1,
    ),
    MultiBackgroundPreset(
      id: 'geo_stripes',
      label: 'Rayures douces',
      family: BackgroundFamily.geometric,
      colors: [Color(0xFFF2F2F2), Color(0xFFE0E0E0)],
      pattern: 'grid',
      patternSeed: 2,
    ),
    MultiBackgroundPreset(
      id: 'geo_blocks',
      label: 'Blocs',
      family: BackgroundFamily.geometric,
      colors: [Color(0xFFEEF4FB), Color(0xFFD6E6F7)],
      pattern: 'dots',
      patternSeed: 3,
    ),
    MultiBackgroundPreset(
      id: 'geo_waves',
      label: 'Vagues',
      family: BackgroundFamily.geometric,
      colors: [Color(0xFFF8FAFC), Color(0xFFEEF2F7), Color(0xFFE2E8F0)],
      pattern: 'waves',
    ),

    // ── Brandés ─────────────────────────────────────────────
    MultiBackgroundPreset(
      id: 'branded_ohada',
      label: 'OHADA Signature',
      family: BackgroundFamily.branded,
      colors: [Color(0xFFBAAB6D), Color(0xFF0F4C81), Color(0xFFFFFBF2)],
      pattern: 'rings',
    ),
    MultiBackgroundPreset(
      id: 'branded_premium',
      label: 'Premium Noir / Or',
      family: BackgroundFamily.branded,
      colors: [Color(0xFF111111), Color(0xFFBAAB6D)],
      pattern: 'rings',
    ),
    MultiBackgroundPreset(
      id: 'branded_amethyst',
      label: 'Améthyste',
      family: BackgroundFamily.branded,
      colors: [Color(0xFF1E1B4B), Color(0xFF4338CA), Color(0xFF7C3AED)],
    ),
    MultiBackgroundPreset(
      id: 'branded_emerald',
      label: 'Émeraude',
      family: BackgroundFamily.branded,
      colors: [Color(0xFF064E3B), Color(0xFF059669), Color(0xFFBBF7D0)],
    ),
  ];

  // ─────────────────────────────────────────────────────────────
  //  RECHERCHE
  // ─────────────────────────────────────────────────────────────
  static MultiBackgroundPreset? byId(String id) {
    if (id.isEmpty) return null;
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static List<MultiBackgroundPreset> ofFamily(BackgroundFamily f) =>
      all.where((p) => p.family == f).toList();

  static Map<BackgroundFamily, List<MultiBackgroundPreset>>
      get catalogByFamily => {
            for (final f in BackgroundFamily.values) f: ofFamily(f),
          };

  // ─────────────────────────────────────────────────────────────
  //  RENDU PDF
  // ─────────────────────────────────────────────────────────────
  pw.Widget toPdfWidget() {
    switch (family) {
      case BackgroundFamily.solid:
        return pw.Container(
          decoration: pw.BoxDecoration(color: _pdf(colors.first)),
        );

      case BackgroundFamily.gradient:
      case BackgroundFamily.pastel:
      case BackgroundFamily.dark:
        return pw.Container(
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              begin: pw.Alignment.topLeft,
              end: pw.Alignment.bottomRight,
              colors: colors.map(_pdf).toList(),
            ),
          ),
        );

      case BackgroundFamily.geometric:
        return pw.Container(
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              begin: pw.Alignment.topCenter,
              end: pw.Alignment.bottomCenter,
              colors: colors.map(_pdf).toList(),
              stops: const [0.0, 1.0],
            ),
          ),
        );

      case BackgroundFamily.branded:
        final stops = <double>[
          for (var i = 0; i < colors.length; i++)
            i / (colors.length - 1).clamp(1, 10),
        ];
        return pw.Container(
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              begin: pw.Alignment.topCenter,
              end: pw.Alignment.bottomCenter,
              colors: colors.map(_pdf).toList(),
              stops: stops,
            ),
          ),
        );
    }
  }

  List<Color> get pdfColors => colors;

  static PdfColor _pdf(Color c) => PdfColor(c.r, c.g, c.b);
}

// ─── Compat : ancien nom conservé ──────────────────────────────
typedef BackgroundPreset = MultiBackgroundPreset;

// ═══════════════════════════════════════════════════════════════════════
//  PAINTER FLUTTER
// ═══════════════════════════════════════════════════════════════════════

/// Peint un fond préréglé : dégradé vertical + motif discret superposé.
class BackgroundPresetPainter extends CustomPainter {
  final MultiBackgroundPreset preset;
  final double opacity;

  BackgroundPresetPainter({required this.preset, this.opacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: preset.colors,
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = gradient);

    final bool isDarkPreset = preset.mainColor.computeLuminance() < 0.4;
    final Color patternColor =
        (isDarkPreset ? Colors.white : const Color(0xFF4338CA))
            .withValues(alpha: 0.10);

    switch (preset.pattern) {
      case 'dots':
        const step = 22.0;
        final dot = Paint()..color = patternColor;
        for (double y = step / 2; y < size.height; y += step) {
          for (double x = step / 2; x < size.width; x += step) {
            canvas.drawCircle(Offset(x, y), 1.4, dot);
          }
        }
        break;
      case 'grid':
        const step = 34.0;
        final line = Paint()
          ..color = patternColor
          ..strokeWidth = 1;
        for (double x = 0; x <= size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
        }
        for (double y = 0; y <= size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
        break;
      case 'waves':
        final wave = Paint()
          ..color = patternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
        for (double y = size.height * 0.10;
            y < size.height;
            y += size.height * 0.16) {
          final path = Path()..moveTo(0, y);
          for (double x = 0; x <= size.width; x += 24) {
            path.quadraticBezierTo(x + 12, y - 9, x + 24, y);
          }
          canvas.drawPath(path, wave);
        }
        break;
      case 'rings':
        final ring = Paint()
          ..color = patternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
        final center = Offset(size.width * 0.85, size.height * 0.10);
        for (var i = 1; i <= 6; i++) {
          canvas.drawCircle(center, i * 34.0, ring);
        }
        break;
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant BackgroundPresetPainter oldDelegate) =>
      oldDelegate.preset.id != preset.id || oldDelegate.opacity != opacity;
}

// ═══════════════════════════════════════════════════════════════════════
//  COUCHE D'ARRIÈRE-PLAN
// ═══════════════════════════════════════════════════════════════════════

class TemplateBackgroundLayer extends StatelessWidget {
  final String presetId;
  final Uint8List? imageBytes;
  final double opacity;
  final double blur;
  final String fit;

  const TemplateBackgroundLayer({
    super.key,
    this.presetId = '',
    this.imageBytes,
    this.opacity = 1.0,
    this.blur = 0,
    this.fit = 'fill',
  });

  @override
  Widget build(BuildContext context) {
    final double clampedOpacity = opacity.clamp(0.0, 1.0).toDouble();

    Widget? child;
    if (imageBytes != null) {
      Widget image = Image.memory(
        imageBytes!,
        fit: BoxFit.fill,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
      );
      if (blur > 0) {
        image = ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: image,
        );
      }
      child = SizedBox.expand(child: image);
    } else {
      final preset = MultiBackgroundPreset.byId(presetId);
      if (preset != null) {
        child = CustomPaint(
          painter:
              BackgroundPresetPainter(preset: preset, opacity: clampedOpacity),
          child: const SizedBox.expand(),
        );
      }
    }

    if (child == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(opacity: clampedOpacity, child: child),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  HELPERS PUBLICS
// ═══════════════════════════════════════════════════════════════════════

/// Décodage sûr d'une image de fond base64 (null si invalide/vide).
Uint8List? decodeBackgroundImage(String? fileData) {
  if (fileData == null || fileData.isEmpty) return null;
  try {
    var raw = fileData;
    if (raw.startsWith('data:image')) {
      final comma = raw.indexOf(',');
      if (comma == -1) return null;
      raw = raw.substring(comma + 1);
    }
    final bytes = base64Decode(raw);
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  BOTTOM SHEET DE RÉGLAGES
// ═══════════════════════════════════════════════════════════════════════

Future<void> showBackgroundSettingsSheet(
  BuildContext context, {
  required TemplateBackgroundSettings current,
  required ValueChanged<TemplateBackgroundSettings> onChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final theme = Provider.of<ThemeProvider>(sheetCtx);
      final isDark = theme.isDarkMode;
      TemplateBackgroundSettings settings = current;
      BackgroundFamily? activeFamily = BackgroundFamily.gradient;
      return StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          void update(TemplateBackgroundSettings next) {
            setSheet(() => settings = next);
            onChanged(next);
          }

          Future<void> pickFromGallery() async {
            try {
              final picked = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 1600,
                imageQuality: 85,
              );
              if (picked == null) return;
              final bytes = await picked.readAsBytes();
              final isPng = picked.path.toLowerCase().endsWith('.png');
              update(settings.copyWith(
                fileData: base64Encode(bytes),
                fileType: isPng ? 'png' : 'jpeg',
                presetId: '',
              ));
            } catch (_) {
              if (sheetCtx.mounted) {
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  const SnackBar(
                    content: Text("Impossible de charger l'image"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }

          final familyPresets = activeFamily == null
              ? MultiBackgroundPreset.all
              : MultiBackgroundPreset.ofFamily(activeFamily!);

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151722) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Image de fond',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.textColor,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            update(const TemplateBackgroundSettings()),
                        child: Text(
                          'AUCUN',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _sectionLabel('FAMILLE', theme),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _familyChip(
                          label: 'Toutes',
                          selected: activeFamily == null,
                          color: theme.primaryColor,
                          isDark: isDark,
                          onTap: () => setSheet(() => activeFamily = null),
                        ),
                        for (final f in BackgroundFamily.values)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _familyChip(
                              label: f.label,
                              selected: activeFamily == f,
                              color: theme.primaryColor,
                              isDark: isDark,
                              onTap: () => setSheet(() => activeFamily = f),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionLabel('PALETTE DE FONDS', theme),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.72,
                    children: [
                      for (final preset in familyPresets)
                        _presetTile(
                          preset,
                          selected: !settings.hasCustomImage &&
                              settings.presetId == preset.id,
                          onTap: () => update(settings.copyWith(
                            presetId: preset.id,
                            fileData: '',
                            fileType: 'jpeg',
                          )),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: pickFromGallery,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: BorderSide(
                          color: theme.primaryColor.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      foregroundColor: theme.primaryColor,
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text(
                      'Depuis la galerie',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('RÉGLAGES', theme),
                  _settingsSlider(
                    label: 'Opacité',
                    value: settings.opacity,
                    min: 0,
                    max: 1,
                    display: settings.opacity.toStringAsFixed(2),
                    theme: theme,
                    onChanged: (v) => update(settings.copyWith(opacity: v)),
                  ),
                  _settingsSlider(
                    label: 'Flou (image personnalisée)',
                    value: settings.blur,
                    min: 0,
                    max: 20,
                    display: settings.blur.toStringAsFixed(0),
                    theme: theme,
                    onChanged: (v) => update(settings.copyWith(blur: v)),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'fill', label: Text('Remplir')),
                        ButtonSegment(
                            value: 'contain', label: Text('Ajuster')),
                      ],
                      selected: {
                        settings.fit == 'contain' ? 'contain' : 'fill'
                      },
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) =>
                          update(settings.copyWith(fit: selection.first)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════════════════
//  WIDGETS INTERNES
// ═══════════════════════════════════════════════════════════════════════

Widget _sectionLabel(String label, ThemeProvider theme) {
  return Text(
    label,
    style: TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: theme.subTextColor,
    ),
  );
}

Widget _familyChip({
  required String label,
  required bool selected,
  required Color color,
  required bool isDark,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.15)
            : (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              selected ? color.withValues(alpha: 0.6) : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color:
              selected ? color : (isDark ? Colors.white70 : Colors.black54),
        ),
      ),
    ),
  );
}

Widget _presetTile(
  MultiBackgroundPreset preset, {
  required bool selected,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CustomPaint(
                    painter: BackgroundPresetPainter(preset: preset),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          preset.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

Widget _settingsSlider({
  required String label,
  required double value,
  required double min,
  required double max,
  required String display,
  required ThemeProvider theme,
  required ValueChanged<double> onChanged,
}) {
  return Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: theme.textColor,
            ),
          ),
          Text(
            display,
            style: TextStyle(fontSize: 11.5, color: theme.subTextColor),
          ),
        ],
      ),
      Slider(
        value: value.clamp(min, max).toDouble(),
        min: min,
        max: max,
        activeColor: theme.primaryColor,
        onChanged: onChanged,
      ),
    ],
  );
}