// lib/models/customization_config.dart
//
// 🧩 État immutable de la personnalisation de facture, aligné sur les
// maquettes du flow Aperçu ↔ Personnaliser.
//
// Contrairement à [InvoiceSettings] (annoté Hive, champs fixes), ce modèle
// est volatil en mémoire : il découpe la taille de police par section (Titre,
// Infos de facture, Entreprise & client) et expose les nouvelles options
// (Tampon Payé, Signature, Ombres) demandées par les maquettes.
//
import 'package:flutter/material.dart';
import 'invoice_template.dart';

/// Taille de police proposée dans les selectors S/M/L/XL.
enum FontSizeOption {
  small(label: 'S', value: 0),
  medium(label: 'M', value: 1),
  large(label: 'L', value: 2),
  extraLarge(label: 'XL', value: 3);

  const FontSizeOption({required this.label, required this.value});

  final String label;
  final int value;
}

/// Sections de texte pilotables indépendamment dans la maquette.
enum FontSizeSection { title, invoiceInfo, companyClient }

/// Configuration complète de personnalisation d'une facture.
class CustomizationConfig {
  /// Couleur principale (en-tête, totaux, badge FACTURE…).
  final Color primaryColor;

  /// Couleur de fond de la facture.
  final Color backgroundColor;

  /// Couleur du texte principal.
  final Color textColor;

  /// Taille de police par section.
  final Map<FontSizeSection, FontSizeOption> fontSizes;

  /// Options d'affichage alignées sur les onglets de la maquette.
  final bool showLogo;
  final bool showShadow;
  final bool showPaidStamp;
  final bool showSignature;
  final bool showPaymentTerms;

  /// Police d'écriture.
  final String fontFamily;

  const CustomizationConfig({
    this.primaryColor = const Color(0xFF1A237E),
    this.backgroundColor = Colors.white,
    this.textColor = const Color(0xFF1A1A1A),
    this.fontSizes = const {},
    this.showLogo = true,
    this.showShadow = true,
    this.showPaidStamp = true,
    this.showSignature = true,
    this.showPaymentTerms = true,
    this.fontFamily = 'Roboto',
  });

  static const defaults = CustomizationConfig();

  /// Instancie une config initiale depuis un modèle existant.
  factory CustomizationConfig.fromTemplate(InvoiceTemplate template) {
    return CustomizationConfig(
      primaryColor: template.primaryColor,
      backgroundColor: template.backgroundColor,
      textColor: template.textColor,
    );
  }

  CustomizationConfig copyWith({
    Color? primaryColor,
    Color? backgroundColor,
    Color? textColor,
    Map<FontSizeSection, FontSizeOption>? fontSizes,
    bool? showLogo,
    bool? showShadow,
    bool? showPaidStamp,
    bool? showSignature,
    bool? showPaymentTerms,
    String? fontFamily,
  }) {
    return CustomizationConfig(
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      fontSizes: fontSizes ?? Map.of(this.fontSizes),
      showLogo: showLogo ?? this.showLogo,
      showShadow: showShadow ?? this.showShadow,
      showPaidStamp: showPaidStamp ?? this.showPaidStamp,
      showSignature: showSignature ?? this.showSignature,
      showPaymentTerms: showPaymentTerms ?? this.showPaymentTerms,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }

  /// Pixel réel d'une section selon son option S/M/L/XL.
  static double fontSizeFor(FontSizeOption option, FontSizeSection section) {
    final Map<FontSizeSection, Map<FontSizeOption, double>> table = {
      FontSizeSection.title: {
        FontSizeOption.small: 18,
        FontSizeOption.medium: 22,
        FontSizeOption.large: 26,
        FontSizeOption.extraLarge: 32,
      },
      FontSizeSection.invoiceInfo: {
        FontSizeOption.small: 11,
        FontSizeOption.medium: 13,
        FontSizeOption.large: 15,
        FontSizeOption.extraLarge: 17,
      },
      FontSizeSection.companyClient: {
        FontSizeOption.small: 10,
        FontSizeOption.medium: 12,
        FontSizeOption.large: 14,
        FontSizeOption.extraLarge: 16,
      },
    };
    return table[section]?[option] ?? 12;
  }

    double fontSize(FontSizeSection section) =>
      fontSizeFor(fontSizes[section] ?? FontSizeOption.medium, section);
}

/// Modèle léger de modèle de facture pour la galerie de la maquette.
class DemoTemplate {
  final String id;
  final String name;
  final String description;
  final Color primaryColor;
  final Color? backgroundColor;
  final bool isPremium;
  final String category; // 'recommended' | 'simple' | 'classic' | 'pro'

  const DemoTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.primaryColor,
    this.backgroundColor,
    this.isPremium = false,
    required this.category,
  });

  DemoTemplate copyWith({
    String? id,
    String? name,
    String? description,
    Color? primaryColor,
    Color? backgroundColor,
    bool? isPremium,
    String? category,
  }) {
    return DemoTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      isPremium: isPremium ?? this.isPremium,
      category: category ?? this.category,
    );
  }
}

/// Galerie statique de modèles alignée sur la vignette 1 des maquettes.
class DemoTemplates {
  static const List<DemoTemplate> all = [
    DemoTemplate(
      id: 'demo_classic_blue', name: 'Classique Bleu',
      description: 'Design épuré et professionnel',
      primaryColor: Color(0xFF1A237E), category: 'recommended',
    ),
    DemoTemplate(
      id: 'demo_green', name: 'Vert Émeraude',
      description: 'Professionnel et rassurant',
      primaryColor: Color(0xFF00695C), category: 'classic',
    ),
    DemoTemplate(
      id: 'demo_indigo', name: 'Indigo',
      description: 'Moderne et élégant',
      primaryColor: Color(0xFF4338CA), category: 'recommended',
    ),
    DemoTemplate(
      id: 'demo_teal', name: 'Turquoise',
      description: 'Frais et dynamique',
      primaryColor: Color(0xFF009688),
      backgroundColor: Color(0xFFE0F2F1), category: 'simple',
    ),
    DemoTemplate(
      id: 'demo_purple', name: 'Violet',
      description: 'Créatif et distinctif',
      primaryColor: Color(0xFF8E24AA),
      backgroundColor: Color(0xFFF3E5F5), category: 'classic',
    ),
    DemoTemplate(
      id: 'demo_red', name: 'Rouge',
      description: 'Moderne et audacieux',
      primaryColor: Color(0xFFD84315),
      backgroundColor: Color(0xFFFFEBEE), category: 'simple',
    ),
    DemoTemplate(
      id: 'demo_black', name: 'Noir',
      description: 'Luxe et minéral',
      primaryColor: Color(0xFF262626),
      backgroundColor: Colors.white,
      category: 'pro', isPremium: true,
    ),
    DemoTemplate(
      id: 'demo_gold', name: 'Or',
      description: 'Design premium et raffiné',
      primaryColor: Color(0xFFFFD700),
      backgroundColor: Color(0xFF1A1A2E),
      category: 'pro', isPremium: true,
    ),
    DemoTemplate(
      id: 'demo_pink', name: 'Rose',
      description: 'Féminin et élégant',
      primaryColor: Color(0xFFE91E63),
      backgroundColor: Color(0xFFFCE4EC), category: 'classic',
    ),
    DemoTemplate(
      id: 'demo_navy', name: 'Bleu Marine',
      description: 'Institutif et sobre',
      primaryColor: Color(0xFF0D47A1),
      backgroundColor: Color(0xFFE3F2FD),
      category: 'pro', isPremium: true,
    ),
  ];

  /// Catégories proposées par les onglets de la maquette (ordre d'affichage).
  static const List<String> categories = [
    'recommended',
    'simple',
    'classic',
    'pro',
  ];

  static String categoryLabel(String category) {
    switch (category) {
      case 'recommended':
        return 'Recommandé';
      case 'simple':
        return 'Simple';
      case 'classic':
        return 'Classique';
      case 'pro':
        return 'Professionnel';
      default:
        return 'Tous';
    }
  }

  static List<DemoTemplate> ofCategory(String category) {
    if (category == 'all') return all;
    return all.where((t) => t.category == category).toList();
  }
}

