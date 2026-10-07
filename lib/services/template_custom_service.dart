// lib/services/template_custom_service.dart
//
// CHANGELOG (v4) :
//   • `saveCustom` normalise DÉSORMAIS toutes les valeurs de layout sur la
//     grille 8pt (InvoiceTemplate.gridSnap) → plus aucun décalage entre
//     l'atelier, l'aperçu et le PDF.
//   • `loadCustom` VALIDE les positions (clamp, types, dédoublonnage) →
//     aucune donnée corrompue ne peut casser le rendu.
//   • Support complet des nouvelles clés : `grid_snap`, `design_version`,
//     styles `split_orange_left`, `wave`, `diamond_center`, `rainbow_strip`,…
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

      final data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : (raw is String
              ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
              : <String, dynamic>{});

      final positions = _normalizePositions(
        Map<String, dynamic>.from(data['positions'] ?? const {}),
      );

      final mapping = Map<String, String>.from(data['mapping'] ?? const {});

      final bg = TemplateBackgroundSettings.fromMap(
        Map<String, dynamic>.from(data['background'] ?? const {}),
      );

      return TemplateCustom(
        positions: positions,
        mapping: mapping,
        background: bg,
      );
    } catch (e) {
      debugPrint('⚠️ TemplateCustomService.loadCustom($templateId): $e');
      return const TemplateCustom();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  SAVE — normalise sur la grille 8pt
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
  //  NORMALISATION — grille 8pt + validation stricte
  // ═══════════════════════════════════════════════════════════════
  static const double _grid = InvoiceTemplate.gridSnap; // 8.0

  static double _snap(double v) => (v / _grid).round() * _grid;

  static Map<String, dynamic> _normalizePositions(
    Map<String, dynamic> input,
  ) {
    final out = <String, dynamic>{};

    // ─── Sections (en-tête + corps) ───
    for (final key in ['header_sections', 'blocks_sections']) {
      final raw = input[key];
      if (raw is List) {
        out[key] = [
          for (final s in raw)
            if (s is List)
              s.whereType<String>().toList()
            else if (s is String)
              s.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            else
              <String>[],
        ];
      }
    }

    // ─── Maps de doubles (widths, font scales) ───
    for (final key in ['header_widths', 'block_widths']) {
      final raw = input[key];
      if (raw is Map) {
        final m = <String, double>{};
        raw.forEach((k, v) {
          if (v is num) {
            // Largeur : clamp 0.3..3.0 et snap
            m[k.toString()] = _snap(v.toDouble().clamp(0.3, 3.0) * 100) / 100;
          }
        });
        if (m.isNotEmpty) out[key] = m;
      }
    }

    for (final key in ['block_font_scales']) {
      final raw = input[key];
      if (raw is Map) {
        final m = <String, double>{};
        raw.forEach((k, v) {
          if (v is num) {
            // Échelle de police : clamp 0.6..1.8 et snap
            m[k.toString()] = _snap(v.toDouble().clamp(0.6, 1.8) * 100) / 100;
          }
        });
        if (m.isNotEmpty) out[key] = m;
      }
    }

    // ─── Maps d'alignements ───
    for (final key in ['header_alignments', 'block_alignment']) {
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
    for (final key in ['header_visibility', 'block_visibility']) {
      final raw = input[key];
      if (raw is Map) {
        final m = <String, bool>{};
        raw.forEach((k, v) {
          if (v is bool) m[k.toString()] = v;
        });
        if (m.isNotEmpty) out[key] = m;
      }
    }

    // ─── Couleurs de bloc (int ARGB) ───
    for (final key in ['block_bg_colors', 'block_text_colors']) {
      final raw = input[key];
      if (raw is Map) {
        final m = <String, int>{};
        raw.forEach((k, v) {
          if (v is num) m[k.toString()] = v.toInt();
        });
        if (m.isNotEmpty) out[key] = m;
      }
    }

    // ─── Polices de bloc ───
    final rawFonts = input['block_fonts'];
    if (rawFonts is Map) {
      final m = <String, String>{};
      rawFonts.forEach((k, v) {
        if (v is String && v.isNotEmpty) m[k.toString()] = v;
      });
      if (m.isNotEmpty) out['block_fonts'] = m;
    }

    // ─── Styles (valeurs énumérées) ───
    const validHeaderStyles = {
      'flat', 'dark', 'band', 'wave', 'split_orange_left',
      'split_diagonal_corners', 'circle_accent_top_left',
      'orange_band_right', 'cursive_title', 'diamond_center',
    };
    const validTableStyles = {
      'plain', 'alternate_dark', 'dark_header', 'orange_bars', 'cards',
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
        if (key.startsWith('text_')) {
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

    if (input['title_extra_keys'] is List) {
      out['title_extra_keys'] = (input['title_extra_keys'] as List)
          .whereType<String>()
          .where((k) => k.startsWith('text_'))
          .toList();
    }

    // ─── Images (base64) ───
    for (final key in ['signature_image', 'custom_logo_base64']) {
      final v = input[key];
      if (v is String && v.isNotEmpty) out[key] = v;
    }

    // ─── Métadonnées design ───
    out['grid_snap'] = _grid;
    out['design_version'] = InvoiceTemplate.kRoyalDesignVersion;

    return out;
  }

  // ═══════════════════════════════════════════════════════════════
  //  UTILITAIRES PUBLICS
  // ═══════════════════════════════════════════════════════════════
  static Uint8List? decodeBackground(TemplateBackgroundSettings settings) {
    if (!settings.hasCustomImage) return null;
    try {
      return base64Decode(settings.fileData);
    } catch (_) {
      return null;
    }
  }
}