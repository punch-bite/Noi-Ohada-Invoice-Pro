import 'dart:convert' show base64Decode;
import 'dart:typed_data';

import 'package:flutter/material.dart' show Color;

import '../models/invoice_settings.dart';
import '../models/invoice_template.dart';
import 'settings_service.dart';
import 'template_custom_service.dart';

class InvoiceRenderState {
  final InvoiceTemplate effectiveTemplate;
  final Map<String, dynamic> positions;
  final Map<String, String> mapping;
  final TemplateBackgroundSettings backgroundSettings;
  final Uint8List? backgroundImage;
  final InvoiceSettings invoiceSettings;
  final String watermarkText;
  final bool showWatermark;

  const InvoiceRenderState({
    required this.effectiveTemplate,
    required this.positions,
    required this.mapping,
    required this.backgroundSettings,
    required this.backgroundImage,
    required this.invoiceSettings,
    required this.watermarkText,
    required this.showWatermark,
  });
}

class InvoiceRenderService {
  static Map<String, dynamic> mergePositions({
    required Map<String, dynamic> templatePositions,
    Map<String, dynamic>? customPositions,
    Map<String, dynamic>? overridePositions,
  }) {
    final merged = <String, dynamic>{
      ...templatePositions,
      ...?customPositions,
      ...?overridePositions,
    };
    return merged;
  }

  static Map<String, String> mergeMapping({
    required Map<String, String> templateMapping,
    Map<String, String>? customMapping,
    Map<String, String>? overrideMapping,
  }) {
    return <String, String>{
      ...templateMapping,
      ...?customMapping,
      ...?overrideMapping,
    };
  }

  static Uint8List? _decodeImageString(String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      var raw = data;
      if (raw.startsWith('data:image')) {
        final idx = raw.indexOf(',');
        if (idx == -1) return null;
        raw = raw.substring(idx + 1);
      }
      final bytes = base64Decode(raw);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  static Future<InvoiceRenderState> resolveRenderState({
    required InvoiceTemplate template,
    Map<String, dynamic>? customPositions,
    Map<String, dynamic>? overridePositions,
    Map<String, String>? customMapping,
    Map<String, String>? overrideMapping,
    TemplateBackgroundSettings? backgroundSettings,
    InvoiceSettings? invoiceSettings,
  }) async {
    final savedCustom = await TemplateCustomService.loadCustom(template.id);
    final settings = invoiceSettings ?? await SettingsService.instance.loadSettings();

    final mergedPositions = mergePositions(
      templatePositions: template.positions,
      customPositions: customPositions ?? savedCustom.positions,
      overridePositions: overridePositions,
    );

    final mergedMapping = mergeMapping(
      templateMapping: template.mapping,
      customMapping: customMapping ?? savedCustom.mapping,
      overrideMapping: overrideMapping,
    );

    final effectiveBackground = backgroundSettings ?? savedCustom.background;
    final backgroundImage = effectiveBackground.hasCustomImage
        ? _decodeImageString(effectiveBackground.fileData)
        : null;

    var effectiveTemplate = SettingsService.applyToTemplate(template, settings);
    final templateOverrides = mergedPositions['template_overrides'];
    if (templateOverrides is Map) {
      int? colorValue(String key) {
        final value = templateOverrides[key];
        return value is num ? value.toInt() : null;
      }

      effectiveTemplate = effectiveTemplate.copyWith(
        primaryColor: colorValue('primaryColorValue') == null
            ? null
            : Color(colorValue('primaryColorValue')!),
        textColor: colorValue('textColorValue') == null
            ? null
            : Color(colorValue('textColorValue')!),
        backgroundColor: colorValue('backgroundColorValue') == null
            ? null
            : Color(colorValue('backgroundColorValue')!),
        showLogo: templateOverrides['showLogo'] as bool?,
        showTaxDetails: templateOverrides['showTaxDetails'] as bool?,
        showPaymentTerms: templateOverrides['showPaymentTerms'] as bool?,
        showPaymentQR: templateOverrides['showPaymentQR'] as bool?,
        showBorder: templateOverrides['showBorder'] as bool?,
        fontFamily: templateOverrides['fontFamily'] as String?,
        fontSize: (templateOverrides['fontSize'] as num?)?.toDouble(),
      );
    }
    final customFontSize = mergedPositions['custom_font_size'];
    if (customFontSize is num) {
      effectiveTemplate = effectiveTemplate.copyWith(
        fontSize: customFontSize.toDouble().clamp(6.0, 40.0),
      );
    }
    final watermarkText = ((mergedPositions['watermark_text'] as String?) ??
            settings.watermarkText)
        .trim();
    final showWatermark = (mergedPositions['show_watermark'] as bool?) ??
        settings.showWatermark;

    final resolvedPositions = Map<String, dynamic>.from(mergedPositions);
    if (watermarkText.isNotEmpty) {
      resolvedPositions['watermark_text'] = watermarkText;
    }
    resolvedPositions['show_watermark'] = showWatermark;

    return InvoiceRenderState(
      effectiveTemplate: effectiveTemplate,
      positions: resolvedPositions,
      mapping: mergedMapping,
      backgroundSettings: effectiveBackground,
      backgroundImage: backgroundImage,
      invoiceSettings: settings,
      watermarkText: watermarkText,
      showWatermark: showWatermark,
    );
  }
}
