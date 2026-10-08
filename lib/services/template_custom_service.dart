// lib/services/template_custom_service.dart
//
// CHANGELOG (v6) :
//   • Support complet v9/v10 (footer, labels, spacer, divider).
//   • Ajout des styles finaux : `serif_title`, `solid_band_left`,
//     `split_diagonal_orange_blue`, `pill_date`, `side_bars_orange`.
//
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/invoice_template.dart';

class TemplateBackgroundSettings {
  final String presetId;
  final String fileData;
  final String fileType;
  final double opacity;
  final double blur;
  final String fit;

  const TemplateBackgroundSettings({
    this.presetId = '',
    this.fileData = '',
    this.fileType = 'jpeg',
    this.opacity = 1.0,
    this.blur = 0.0,
    this.fit = 'fill',
  });

  bool get hasCustomImage => fileData.isNotEmpty;
  bool get hasPreset => presetId.isNotEmpty;

  TemplateBackgroundSettings copyWith({
    String? presetId,
    String? fileData,
    String? fileType,
    double? opacity,
    double? blur,
    String? fit,
  }) =>
      TemplateBackgroundSettings(
        presetId: presetId ?? this.presetId,
        fileData: fileData ?? this.fileData,
        fileType: fileType ?? this.fileType,
        opacity: (opacity ?? this.opacity).clamp(0.0, 1.0),
        blur: (blur ?? this.blur).clamp(0.0, 30.0),
        fit: fit ?? this.fit,
      );

  Map<String, dynamic> toMap() => {
        'presetId': presetId,
        'fileData': fileData,
        'fileType': fileType,
        'opacity': opacity,
        'blur': blur,
        'fit': fit,
      };

  factory TemplateBackgroundSettings.fromMap(Map<String, dynamic> map) =>
      TemplateBackgroundSettings(
        presetId: map['presetId']?.toString() ?? '',
        fileData: map['fileData']?.toString() ?? '',
        fileType: map['fileType']?.toString() ?? 'jpeg',
        opacity: (map['opacity'] as num?)?.toDouble() ?? 1.0,
        blur: (map['blur'] as num?)?.toDouble() ?? 0.0,
        fit: map['fit']?.toString() ?? 'fill',
      );
}

class TemplateCustom {
  final Map<String, dynamic> positions;
  final Map<String, String> mapping;
  final TemplateBackgroundSettings background;

  const TemplateCustom({
    this.positions = const {},
    this.mapping = const {},
    this.background = const TemplateBackgroundSettings(),
  });
}

class TemplateCustomService {
  static const String _boxName = 'invoice_templates_custom';

  static Future<Box> _box() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  // ═══════════════════════════════════════════════════════════════
  //  LOAD
  // ═══════════════════════════════════════════════════════════════
  static Future<TemplateCustom> loadCustom(String templateId) async {
    if (templateId.isEmpty) return const TemplateCustom();
    try {
      final box = await _box();
      final raw = box.get(templateId);
      if (raw == null) return const TemplateCustom();

      Map<String, dynamic> data;
      if (raw is Map<String, dynamic>) {
        data = raw;
      } else if (raw is Map) {
        data = raw.map((k, v) => MapEntry(k.toString(), v));
      } else if (raw is String) {
        data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } else {
        return const TemplateCustom();
      }

      final rawPositions = data['positions'];
      final positionsMap = rawPositions is Map
          ? rawPositions.map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{};
      final positions = _normalizePositions(positionsMap);

      final mapping = data['mapping'] is Map
          ? Map<String, String>.from(
              (data['mapping'] as Map).map(
                (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
              ),
            )
          : <String, String>{};

      final bgRaw = data['background'];
      final bg = bgRaw is Map
          ? TemplateBackgroundSettings.fromMap(
              bgRaw.map((k, v) => MapEntry(k.toString(), v)),
            )
          : const TemplateBackgroundSettings();

      return TemplateCustom(
        positions: positions,
        mapping: mapping,
        background: bg,
      );
    } catch (e, st) {
      debugPrint('⚠️ TemplateCustomService.loadCustom($templateId): $e\n$st');
      return const TemplateCustom();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  SAVE
  // ═══════════════════════════════════════════════════════════════
  static Future<void> saveCustom(
    String templateId, {
    required Map<String, dynamic> positions,
    required Map<String, String> mapping,
    required TemplateBackgroundSettings background,
  }) async {
    if (templateId.isEmpty) return;
    try {
      final box = await _box();
      final payload = <String, dynamic>{
        'positions': _normalizePositions(positions),
        'mapping': mapping,
        'background': background.toMap(),
        'savedAt': DateTime.now().toIso8601String(),
      };
      await box.put(templateId, payload);
    } catch (e) {
      debugPrint('⚠️ TemplateCustomService.saveCustom($templateId): $e');
    }
  }

  static Future<void> clearCustom(String templateId) async {
    try {
      final box = await _box();
      await box.delete(templateId);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  //  NORMALISATION
  // ═══════════════════════════════════════════════════════════════
  static const double _grid = InvoiceTemplate.gridSnap;

  static double _snap(double v) => (v / _grid).round() * _grid;

  static Map<String, dynamic> _normalizePositions(
    Map<String, dynamic> input,
  ) {
    final out = <String, dynamic>{};

    // ─── Sections ───
    for (final key in [
      'header_sections',
      'blocks_sections',
      'footer_sections',
    ]) {
      final raw = input[key];
      if (raw is List) {
        out[key] = [
          for (final s in raw)
            if (s is List)
              s.whereType<String>().toList()
            else if (s is String)
              s
                  .split('|')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList()
            else
              <String>[],
        ];
      }
    }

    // ─── Largeurs ───
    for (final key in [
      'header_widths',
      'block_widths',
      'footer_widths',
    ]) {
      final raw = input[key];
      if (raw is Map) {
        final m = <String, double>{};
        raw.forEach((k, v) {
          if (v is num) {
            m[k.toString()] =
                _snap(v.toDouble().clamp(0.3, 3.0) * 100) / 100;
          }
        });
        if (m.isNotEmpty) out[key] = m;
      }
    }

    // ─── Font scales ───
    for (final key in ['block_font_scales', 'footer_font_scales']) {
      final raw = input[key];
      if (raw is Map) {
        final m = <String, double>{};
        raw.forEach((k, v) {
          if (v is num) {
            m[k.toString()] =
                _snap(v.toDouble().clamp(0.6, 1.8) * 100) / 100;
          }
        });
        if (m.isNotEmpty) out[key] = m;
      }
    }

    // ─── Spacer sizes ───
    final rawSpacers = input['spacer_sizes'];
    if (rawSpacers is Map) {
      final m = <String, double>{};
      rawSpacers.forEach((k, v) {
        if (v is num) {
          m[k.toString()] = _snap(v.toDouble().clamp(8.0, 500.0));
        }
      });
      if (m.isNotEmpty) out['spacer_sizes'] = m;
    }

    // ─── Alignements ───
    for (final key in [
      'header_alignments',
      'block_alignment',
      'footer_alignments',
    ]) {
      final raw = input[key];
      if (raw is Map) {
        final m = <String, String>{};
        raw.forEach((k, v) {
          final s = v?.toString();
          if (s == 'left' || s == 'center' || s == 'right') {
            m[k.toString()] = s!;
          }
        });
        if (m.isNotEmpty) out[key] = m;
      }
    }

    // ─── Visibilités ───
    for (final key in [
      'header_visibility',
      'block_visibility',
      'footer_visibility',
    ]) {
      final raw = input[key];
      if (raw is Map) {
        final m = <String, bool>{};
        raw.forEach((k, v) {
          if (v is bool) m[k.toString()] = v;
        });
        if (m.isNotEmpty) out[key] = m;
      }
    }

    // ─── Couleurs ───
    for (final key in [
      'block_bg_colors',
      'block_text_colors',
      'footer_bg_colors',
      'footer_text_colors',
    ]) {
      final raw = input[key];
      if (raw is Map) {
        final m = <String, int>{};
        raw.forEach((k, v) {
          if (v is num) m[k.toString()] = v.toInt();
        });
        if (m.isNotEmpty) out[key] = m;
      }
    }

    // ─── Polices ───
    for (final key in ['block_fonts', 'footer_fonts']) {
      final rawFonts = input[key];
      if (rawFonts is Map) {
        final m = <String, String>{};
        rawFonts.forEach((k, v) {
          if (v is String && v.isNotEmpty) m[k.toString()] = v;
        });
        if (m.isNotEmpty) out[key] = m;
      }
    }

    // ─── Séparateurs ───
    final rawDividers = input['divider_styles'];
    if (rawDividers is Map) {
      const validDividerStyles = {'solid', 'dashed', 'dots'};
      final m = <String, String>{};
      rawDividers.forEach((k, v) {
        final s = v?.toString();
        if (s != null && validDividerStyles.contains(s)) {
          m[k.toString()] = s;
        }
      });
      if (m.isNotEmpty) out['divider_styles'] = m;
    }

    // ─── Labels personnalisés ───
    final rawLabels = input['block_labels'];
    if (rawLabels is Map) {
      final m = <String, String>{};
      rawLabels.forEach((k, v) {
        if (v is String && v.trim().isNotEmpty) {
          m[k.toString()] = v;
        }
      });
      if (m.isNotEmpty) out['block_labels'] = m;
    }

    // ─── Styles (valeurs énumérées) — V6 ───
    const validHeaderStyles = {
      'flat', 'dark', 'band', 'wave', 'split_orange_left',
      'split_diagonal_corners', 'circle_accent_top_left',
      'orange_band_right', 'cursive_title', 'diamond_center',
      // ✨ Nouveaux :
      'serif_title', 'solid_band_left',
      'split_diagonal_orange_blue', 'pill_date',
    };
    const validTableStyles = {
      'plain', 'alternate_dark', 'dark_header', 'orange_bars', 'cards',
      // ✨ Nouveau :
      'side_bars_orange',
    };
    const validFooterStyles = {
      'simple', 'contact_bar_icons', 'zigzag_thankyou',
      'thick_orange_band', 'rainbow_strip', 'diagonal_bottom_stripes',
    };
    const validAccentBorders = {'', 'top', 'left', 'frame', 'stripes_bottom'};

    final hs = input['header_style']?.toString() ?? '';
    if (validHeaderStyles.contains(hs)) out['header_style'] = hs;

    final ts = input['table_style']?.toString() ?? '';
    if (validTableStyles.contains(ts)) out['table_style'] = ts;

    final fs = input['footer_style']?.toString() ?? '';
    if (validFooterStyles.contains(fs)) out['footer_style'] = fs;

    final ab = input['accent_border']?.toString() ?? '';
    if (validAccentBorders.contains(ab)) out['accent_border'] = ab;

    // ─── Textes ───
    for (final key in [
      'invoice_title_text',
      'invoice_subtitle',
      'custom_legal_text',
      'signatory_title',
      'stamp_text',
      'thank_you_text',
      'bank_name',
      'bank_account',
      'qr_position',
    ]) {
      final v = input[key];
      if (v is String && v.isNotEmpty) out[key] = v;
    }

    // ─── Booléens ───
    for (final key in [
      'show_paid_stamp',
      'show_signature_line',
      'show_thank_you',
    ]) {
      final v = input[key];
      if (v is bool) out[key] = v;
    }

    // ─── Nombres ───
    final pp = input['page_padding'];
    if (pp is num) {
      out['page_padding'] = _snap(pp.toDouble().clamp(8.0, 80.0));
    }

    final logoSize = input['logo_size'];
    if (logoSize is num) {
      out['logo_size'] = _snap(logoSize.toDouble().clamp(24.0, 100.0));
    }

    // ─── Textes libres ───
    if (input['custom_texts'] is Map) {
      final m = <String, String>{};
      (input['custom_texts'] as Map).forEach((k, v) {
        final key = k.toString();
        if (key.startsWith('text_') || key.startsWith('foot_')) {
          m[key] = v?.toString() ?? '';
        }
      });
      out['custom_texts'] = m;
    }

    // ─── Paragraphes ───
    if (input['custom_paragraphs'] is Map) {
      final m = <String, List<Map<String, dynamic>>>{};
      (input['custom_paragraphs'] as Map).forEach((k, v) {
        if (v is List) {
          m[k.toString()] = [
            for (final e in v)
              if (e is Map) Map<String, dynamic>.from(e)
          ];
        }
      });
      out['custom_paragraphs'] = m;
    }

    // ─── Extra keys du titre ───
    if (input['title_extra_keys'] is List) {
      out['title_extra_keys'] = (input['title_extra_keys'] as List)
          .whereType<String>()
          .where((k) => k.startsWith('text_') || k.startsWith('foot_'))
          .toList();
    }

    // ─── Images ───
    for (final key in ['signature_image', 'custom_logo_base64']) {
      final v = input[key];
      if (v is String && v.isNotEmpty) out[key] = v;
    }

    // ─── Métadonnées ───
    out['grid_snap'] = _grid;
    out['design_version'] = InvoiceTemplate.kRoyalDesignVersion;

    return out;
  }

  static Uint8List? decodeBackground(TemplateBackgroundSettings settings) {
    if (!settings.hasCustomImage) return null;
    try {
      return base64Decode(settings.fileData);
    } catch (_) {
      return null;
    }
  }
}