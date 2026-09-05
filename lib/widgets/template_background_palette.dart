// lib/widgets/template_background_palette.dart
//
// 🎨 PALETTE DE FONDS DE PAGE pour les factures — partagée par toute la
// logique de personnalisation :
//   • l'espace de personnalisation drag & drop (template_workspace_screen)
//   • l'aperçu d'un modèle (template_preview_screen)
//   • le détail d'une facture (invoice_detail_screen)
//
// Deux sources de fond possibles :
//   • un PRÉRÉGLAGE décoratif dessiné en code (dégradé + motif) — léger,
//     sans asset binaire, approximé à l'impression par un dégradé PDF ;
//   • une IMAGE personnalisée choisie dans la galerie (base64 via
//     TemplateCustomService — toujours prioritaire sur le préréglage).

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/template_custom_service.dart';

/// Un fond de page préréglé (dessiné en code, sans asset binaire).
class BackgroundPreset {
  final String id;
  final String label;

  /// Couleurs du dégradé vertical (haut → bas). Réutilisées à l'impression
  /// pour l'approximation PDF du fond.
  final List<Color> colors;

  /// Motif superposé : 'none' | 'dots' | 'grid' | 'waves' | 'rings'.
  final String pattern;

  const BackgroundPreset({
    required this.id,
    required this.label,
    required this.colors,
    this.pattern = 'none',
  });

  /// Couleur dominante (milieu du dégradé) — vignettes & motifs.
  Color get mainColor => colors.length > 1 ? colors[1] : colors.first;

  static const List<BackgroundPreset> presets = [
    BackgroundPreset(
      id: 'indigo-nuit',
      label: 'Indigo nuit',
      colors: [Color(0xFF1E1B4B), Color(0xFF4338CA), Color(0xFF7C3AED)],
    ),
    BackgroundPreset(
      id: 'violet-douceur',
      label: 'Violet douceur',
      colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
    ),
    BackgroundPreset(
      id: 'or-elegant',
      label: 'Or élégant',
      colors: [Color(0xFFFFFBEB), Color(0xFFFDF0C2), Color(0xFFF5D98B)],
      pattern: 'rings',
    ),
    BackgroundPreset(
      id: 'marbre',
      label: 'Marbre',
      colors: [Color(0xFFF8FAFC), Color(0xFFEEF2F7), Color(0xFFE2E8F0)],
      pattern: 'waves',
    ),
    BackgroundPreset(
      id: 'points',
      label: 'Points',
      colors: [Color(0xFFFFFFFF), Color(0xFFF6F7FB)],
      pattern: 'dots',
    ),
    BackgroundPreset(
      id: 'grille',
      label: 'Grille',
      colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
      pattern: 'grid',
    ),
    BackgroundPreset(
      id: 'menthe',
      label: 'Menthe',
      colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
      pattern: 'dots',
    ),
    BackgroundPreset(
      id: 'charbon',
      label: 'Charbon',
      colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
      pattern: 'rings',
    ),
  ];

  static BackgroundPreset? byId(String id) {
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}

/// Peint un fond préréglé : dégradé vertical + motif discret superposé.
class BackgroundPresetPainter extends CustomPainter {
  final BackgroundPreset preset;
  final double opacity;

  BackgroundPresetPainter({required this.preset, this.opacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Dégradé vertical.
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: preset.colors,
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = gradient);

    // 2. Motif discret (contrasté selon la luminosité du fond).
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

/// Couche d'arrière-plan d'une page facture — à poser en PREMIER enfant d'un
/// Stack (sous le contenu). Rend l'image personnalisée si fournie, sinon le
/// préréglage de la palette, sinon rien.
class TemplateBackgroundLayer extends StatelessWidget {
  final String presetId;
  final Uint8List? imageBytes;
  final double opacity;
  final double blur;
  final String fit; // 'fill' | 'contain'

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
        fit: fit == 'contain' ? BoxFit.contain : BoxFit.fill,
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
      // 📐 PROPORTIONNALITÉ A4 : quelle que soit la hauteur réelle du
      // conteneur (le corps du workspace laisse la hauteur libre), l'IMAGE
      // est contrainte au ratio exact d'une feuille A4 (794×1123, cf.
      // A4Dimensions) alignée en haut. Le fond s'affiche donc IDENTIQUE
      // à l'impression PDF (même ratio) au lieu d'être étiré/découpé selon
      // le contenu. Le motif des presets (dégradé plein, à droite) reste
      // en fill — aucun risque de distorsion pour un dégradé.
      child = Align(
        alignment: Alignment.topCenter,
        child: AspectRatio(
          aspectRatio: 794 / 1123,
          child: image,
        ),
      );
    } else {
      final preset = BackgroundPreset.byId(presetId);
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

/// Décodage sûr d'une image de fond base64 (null si invalide/vide).
Uint8List? decodeBackgroundImage(String fileData) {
  if (fileData.isEmpty) return null;
  try {
    return base64Decode(fileData);
  } catch (_) {
    return null;
  }
}

/// 🎨 Bottom sheet « Image de fond » : palette de préréglages + image galerie
/// + réglages (opacité, flou, ajustement). Partagée par le workspace et le
/// détail de facture ; [onChanged] est appelé à chaque modification et
/// persiste côté appelant.
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
                      for (final preset in BackgroundPreset.presets)
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
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
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

Widget _presetTile(
  BackgroundPreset preset, {
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
