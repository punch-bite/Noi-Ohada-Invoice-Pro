// lib/models/invoice_template.dart
//
// CHANGELOG (v5) :
//   • 🐛 FIX preset `default_2` : `wave_orange_blue` → `wave`.
//   • ✨ Nouveaux styles finaux : `serif_title`, `solid_band_left`,
//     `split_diagonal_orange_blue`, `pill_date`, `side_bars_orange`.
//   • ✨ Presets mis à jour : `default_4`, `default_5`, `default_6`, `default_7`.
//   • ✨ Nouveau preset `default_9` « Moderne Date » (image #7).
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'invoice_layout.dart';

part 'invoice_template.g.dart';

@HiveType(typeId: 6)
class InvoiceTemplate {

  static const List<String> availableVariables = [
    'invoice_number',
    'issue_date',
    'due_date',
    'client_name',
    'client_address',
    'client_email',
    'client_phone',
    'company_name',
    'company_address',
    'company_phone',
    'company_email',
    'company_tax_id',
    'company_rccm',
    'company_legal_text',
    'payment_terms',
    'notes',
    'subtotal',
    'tax_amount',
    'discount',
    'total_amount',
    'status',
    'currency',
  ];

  static const List<String> categories = [
    'Tous',
    'Classique',
    'Moderne',
    'Élégant',
    'Premium',
    'Corporate',
    'Minimaliste',
  ];

  @HiveField(0)  final String id;
  @HiveField(1)  final String name;
  @HiveField(2)  final String description;
  @HiveField(3)  final int primaryColorValue;
  @HiveField(4)  final int textColorValue;
  @HiveField(5)  final int backgroundColorValue;
  @HiveField(6)  final bool showLogo;
  @HiveField(7)  final bool showTaxDetails;
  @HiveField(8)  final bool showPaymentTerms;
  @HiveField(9)  final bool showPaymentQR;
  @HiveField(10) final bool isPremium;
  @HiveField(11) final bool isDefault;
  @HiveField(12) final String fontFamily;
  @HiveField(13) final double fontSize;
  @HiveField(14) final bool showBorder;
  @HiveField(15) final String? createdBy;
  @HiveField(16) final bool isActive;
  @HiveField(17) final DateTime? createdAt;

  final double price;
  final bool paid;
  final List<String> purchasedBy;
  final String fileType;
  final String fileData;
  final Map<String, String> mapping;
  final String category;
  final Map<String, dynamic> positions;
  final double rating;
  final int designVersion;

  static const int kRoyalDesignVersion = 4;
  static const double gridSnap = 8.0;
  static const double kPageWidth = 794.0;
  static const double kPageHeight = 1123.0;

  Color get primaryColor => Color(primaryColorValue);
  Color get textColor => Color(textColorValue);
  Color get backgroundColor => Color(backgroundColorValue);

  InvoiceTemplate({
    required this.id,
    required this.name,
    required this.description,
    Color? primaryColor,
    Color? textColor,
    Color? backgroundColor,
    this.showLogo = true,
    this.showTaxDetails = true,
    this.showPaymentTerms = true,
    this.showPaymentQR = false,
    this.isPremium = false,
    this.isDefault = false,
    this.fontFamily = 'WorkSans',
    this.fontSize = 12.0,
    this.showBorder = false,
    this.createdBy,
    this.isActive = true,
    this.createdAt,
    this.price = 0,
    this.paid = false,
    this.purchasedBy = const [],
    this.fileType = '',
    this.fileData = '',
    this.mapping = const {},
    this.category = 'classique',
    this.positions = const {},
    this.rating = 0,
    this.designVersion = 4,
  })  : primaryColorValue = primaryColor?.toARGB32() ?? 0xFF1976D2,
        textColorValue = textColor?.toARGB32() ?? 0xFF1A1A1A,
        backgroundColorValue = backgroundColor?.toARGB32() ?? 0xFFFFFFFF;

  // ═══════════════════════════════════════════════════════════════
  //  SECTIONS / POSITIONS
  // ═══════════════════════════════════════════════════════════════
  static const String kSectionSeparator = '|';

  static List<String> encodeSections(List<List<String>> sections) => [
        for (final section in sections) section.join(kSectionSeparator),
      ];

  static List<List<String>> decodeSections(Object? raw) {
    if (raw is! List) return const <List<String>>[];
    final sections = <List<String>>[];
    for (final entry in raw) {
      if (entry is List) {
        sections.add(entry.whereType<String>().toList());
      } else if (entry is String) {
        sections.add(
          entry
              .split(kSectionSeparator)
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        );
      }
    }
    return sections;
  }

  static Map<String, dynamic> effectivePositions({
    required Map<String, dynamic> customPositions,
    required Map<String, dynamic> templatePositions,
  }) =>
      customPositions.isNotEmpty
          ? customPositions
          : Map<String, dynamic>.from(templatePositions);

  // ═══════════════════════════════════════════════════════════════
  //  EN-TÊTE
  // ═══════════════════════════════════════════════════════════════
  static const List<String> headerElements = [
    'logo',
    'company_info',
    'invoice_title',
  ];

  static List<String> resolveHeaderOrder(Object? rawOrder) {
    final order = <String>[];
    if (rawOrder is List) {
      for (final element in rawOrder) {
        if (element is String &&
            !order.contains(element) &&
            (headerElements.contains(element) || element.startsWith('text_'))) {
          order.add(element);
        }
      }
    }
    for (final element in headerElements) {
      if (!order.contains(element)) order.add(element);
    }
    return order;
  }

  static bool isHeaderElementVisible(
    Map<String, dynamic> positions,
    String key,
  ) {
    final map = positions['header_visibility'];
    if (map is Map) {
      final value = map[key];
      if (value is bool) return value;
    }
    return true;
  }

  static List<String> visibleHeaderElements(Map<String, dynamic> positions) {
    final rawTexts = positions['custom_texts'];
    final texts =
        rawTexts is Map ? rawTexts.keys.toSet() : const <Object?>{};
    return resolveHeaderOrder(positions['header_elements_order'])
        .where((key) =>
            isHeaderElementVisible(positions, key) &&
            (!key.startsWith('text_') || texts.contains(key)))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════
  //  CONSTRUCTION PRESET
  // ═══════════════════════════════════════════════════════════════
  static Map<String, dynamic> _preset({
    required String title,
    String subtitle = '',
    List<List<String>>? headerSections,
    Map<String, double> headerWidths = const {'company_info': 2.0},
    Map<String, String> headerAlignments = const {
      'logo': 'left',
      'company_info': 'left',
      'invoice_title': 'right',
    },
    String headerStyle = 'flat',
    String accentBorder = '',
    List<List<String>>? sections,
    Map<String, String> blockAlignment = const {
      'billing_info': 'left',
      'invoice_meta': 'right',
      'items_table': 'left',
      'totals': 'right',
      'legal_mentions': 'left',
      'signature_block': 'right',
      'qr_block': 'center',
    },
    Map<String, double> blockWidths = const {
      'billing_info': 1.2,
      'invoice_meta': 1.0,
    },
    Map<String, bool> blockVisibility = const {
      'billing_info': true,
      'invoice_meta': true,
      'items_table': true,
      'totals': true,
      'legal_mentions': true,
      'signature_block': true,
      'qr_block': false,
    },
    String tableStyle = 'plain',
    String footerStyle = 'simple',
    bool showThankYou = false,
    String thankYouText = 'Merci pour votre confiance !',
    String bankName = '',
    String bankAccount = '',
    String signatoryTitle = 'Authorized Sign',
    bool showSignatureLine = true,
    String legalText =
        'Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed do '
            'eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim '
            'ad minim veniam, quis nostrud exercitation ullamco laboris nisi.',
    double pagePadding = 32.0,
    bool showPaidStamp = false,
    String stampText = 'PAYÉ',
    String qrPosition = 'totals',
  }) {
    final defaultSections = sections ??
        const <List<String>>[
          ['billing_info', 'invoice_meta'],
          ['items_table'],
          ['totals'],
          ['legal_mentions', 'signature_block'],
        ];

    return <String, dynamic>{
      ...InvoiceLayoutConfig.defaultLayout().toMap(),
      'blocks_sections': encodeSections(defaultSections),
      'blocks_order': [for (final s in defaultSections) ...s],
      'block_visibility': Map<String, bool>.from(blockVisibility)
        ..['signature_block'] = showSignatureLine
        ..['qr_block'] = blockVisibility['qr_block'] ?? false,
      'block_alignment': Map<String, String>.from(blockAlignment),
      'block_widths': Map<String, double>.from(blockWidths),
      'header_sections': encodeSections(
        headerSections ?? const [['logo', 'company_info', 'invoice_title']],
      ),
      'header_elements_order': const ['logo', 'company_info', 'invoice_title'],
      'header_widths': Map<String, double>.from(headerWidths),
      'header_alignments': Map<String, String>.from(headerAlignments),
      'header_style': headerStyle,
      'table_style': tableStyle,
      'footer_style': footerStyle,
      'accent_border': accentBorder,
      'invoice_title_text': title,
      'invoice_subtitle': subtitle,
      'custom_legal_text': legalText,
      'signatory_title': signatoryTitle,
      'stamp_text': stampText,
      'show_paid_stamp': showPaidStamp,
      'show_signature_line': showSignatureLine,
      'show_thank_you': showThankYou,
      'thank_you_text': thankYouText,
      'bank_name': bankName,
      'bank_account': bankAccount,
      'qr_position': qrPosition,
      'page_padding': pagePadding,
      'grid_snap': InvoiceTemplate.gridSnap,
      'design_version': kRoyalDesignVersion,
    };
  }

  // ═══════════════════════════════════════════════════════════════
  //  9 PRESETS
  // ═══════════════════════════════════════════════════════════════
  static List<InvoiceTemplate> getDefaultTemplates() => [
    // ① BANDE ORANGE
    InvoiceTemplate(
      id: 'default_1',
      name: 'Bande Orange',
      description: 'Bandeau orange — corporate dynamique',
      primaryColor: const Color(0xFFF39200),
      textColor: const Color(0xFF1F2937),
      backgroundColor: const Color(0xFFFFFFFF),
      fontSize: 11.5,
      fontFamily: 'WorkSans',
      isDefault: true,
      category: 'Classique',
      price: 0,
      rating: 4.6,
      designVersion: 4,
      showTaxDetails: true,
      showPaymentTerms: true,
      showLogo: true,
      positions: _preset(
        title: 'INVOICE',
        headerStyle: 'split_orange_left',
        headerSections: const [
          ['invoice_title'],
          ['logo', 'company_info'],
        ],
        headerWidths: const {
          'logo': 0.8,
          'company_info': 2.0,
          'invoice_title': 1.4,
        },
        headerAlignments: const {
          'logo': 'right',
          'company_info': 'right',
          'invoice_title': 'left',
        },
        sections: const [
          ['billing_info', 'invoice_meta'],
          ['items_table'],
          ['legal_mentions', 'totals'],
          ['signature_block'],
        ],
        blockAlignment: const {
          'billing_info': 'left',
          'invoice_meta': 'right',
          'items_table': 'left',
          'totals': 'right',
          'legal_mentions': 'left',
          'signature_block': 'right',
        },
        blockWidths: const {'billing_info': 1.0, 'invoice_meta': 1.4},
        tableStyle: 'alternate_dark',
        footerStyle: 'zigzag_thankyou',
        showThankYou: true,
        thankYouText: 'Thank you for your business',
        signatoryTitle: 'Authorized Sign',
        accentBorder: '',
        pagePadding: 32,
      ),
    ),

    // ② MODERNE ZIGZAG
    InvoiceTemplate(
      id: 'default_2',
      name: 'Moderne Zigzag',
      description: 'Vague orange & bleu — moderne',
      primaryColor: const Color(0xFF1B4965),
      textColor: const Color(0xFF1F2937),
      backgroundColor: const Color(0xFFFFFFFF),
      fontSize: 11.5,
      fontFamily: 'WorkSans',
      category: 'Moderne',
      price: 0,
      rating: 4.7,
      designVersion: 4,
      positions: _preset(
        title: 'Invoice',
        subtitle: 'Invoice: 0001593   Date: 01/05/2029',
        headerStyle: 'wave',
        headerSections: const [
          ['logo'],
          ['company_info', 'invoice_title'],
        ],
        headerWidths: const {
          'logo': 1.0,
          'company_info': 1.2,
          'invoice_title': 1.6,
        },
        headerAlignments: const {
          'logo': 'left',
          'company_info': 'left',
          'invoice_title': 'right',
        },
        sections: const [
          ['billing_info'],
          ['invoice_meta'],
          ['items_table'],
          ['legal_mentions', 'totals'],
          ['signature_block'],
        ],
        blockAlignment: const {
          'billing_info': 'left',
          'invoice_meta': 'right',
          'items_table': 'left',
          'totals': 'right',
          'legal_mentions': 'left',
          'signature_block': 'left',
        },
        tableStyle: 'dark_header',
        footerStyle: 'contact_bar_icons',
        accentBorder: 'top',
        pagePadding: 36,
        showThankYou: false,
        signatoryTitle: 'Director',
        bankName: 'Your Bank',
        bankAccount: '000 000 000',
      ),
    ),

    // ③ CLASSIQUE OR
    InvoiceTemplate(
      id: 'default_3',
      name: 'Classique Or',
      description: 'Or & noir — intemporel raffiné',
      primaryColor: const Color(0xFFE8A33D),
      textColor: const Color(0xFF1F2937),
      backgroundColor: const Color(0xFFFFFFFF),
      fontSize: 11.5,
      fontFamily: 'WorkSans',
      category: 'Élégant',
      price: 500,
      rating: 4.8,
      designVersion: 4,
      positions: _preset(
        title: 'Invoice',
        headerStyle: 'flat',
        headerSections: const [
          ['logo', 'company_info'],
          ['invoice_title'],
        ],
        headerWidths: const {
          'logo': 0.6,
          'company_info': 2.0,
          'invoice_title': 1.4,
        },
        headerAlignments: const {
          'logo': 'left',
          'company_info': 'left',
          'invoice_title': 'right',
        },
        sections: const [
          ['billing_info', 'invoice_meta'],
          ['items_table'],
          ['legal_mentions', 'totals'],
          ['signature_block'],
        ],
        blockAlignment: const {
          'billing_info': 'right',
          'invoice_meta': 'right',
          'items_table': 'left',
          'totals': 'right',
          'legal_mentions': 'left',
          'signature_block': 'right',
        },
        tableStyle: 'orange_bars',
        footerStyle: 'simple',
        accentBorder: '',
        pagePadding: 36,
        signatoryTitle: 'Authorized Sign',
      ),
    ),

    // ④ BANDEAU BLEU — ✨ headerStyle → solid_band_left
    InvoiceTemplate(
      id: 'default_4',
      name: 'Bandeau Bleu',
      description: 'Bandeau orange & bleu nuit — élégance',
      primaryColor: const Color(0xFFE8A33D),
      textColor: const Color(0xFF1F2937),
      backgroundColor: const Color(0xFFFFFFFF),
      fontSize: 11.5,
      fontFamily: 'WorkSans',
      category: 'Moderne',
      price: 0,
      rating: 4.5,
      designVersion: 4,
      positions: _preset(
        title: 'INVOICE',
        headerStyle: 'solid_band_left',
        headerSections: const [
          ['logo', 'company_info'],
          ['invoice_title'],
        ],
        headerWidths: const {
          'logo': 0.9,
          'company_info': 1.8,
          'invoice_title': 1.6,
        },
        headerAlignments: const {
          'logo': 'left',
          'company_info': 'left',
          'invoice_title': 'right',
        },
        sections: const [
          ['billing_info', 'invoice_meta'],
          ['items_table'],
          ['legal_mentions', 'totals'],
          ['signature_block'],
        ],
        blockAlignment: const {
          'billing_info': 'left',
          'invoice_meta': 'right',
          'items_table': 'left',
          'totals': 'right',
          'legal_mentions': 'left',
          'signature_block': 'right',
        },
        tableStyle: 'orange_bars',
        footerStyle: 'simple',
        accentBorder: 'stripes_bottom',
        pagePadding: 36,
        signatoryTitle: 'Authorized Sign',
      ),
    ),

    // ⑤ MINIMAL TWO-COL — ✨ headerStyle → split_diagonal_orange_blue
    InvoiceTemplate(
      id: 'default_5',
      name: 'Minimal Two-Col',
      description: 'Deux colonnes épurées — idéal freelances',
      primaryColor: const Color(0xFFE67E22),
      textColor: const Color(0xFF1F2937),
      backgroundColor: const Color(0xFFFFFFFF),
      fontSize: 11.5,
      fontFamily: 'WorkSans',
      category: 'Classique',
      price: 0,
      rating: 4.4,
      designVersion: 4,
      positions: _preset(
        title: 'INVOICE',
        headerStyle: 'split_diagonal_orange_blue',
        headerSections: const [
          ['logo', 'company_info'],
          ['invoice_title'],
        ],
        headerWidths: const {
          'logo': 0.9,
          'company_info': 1.8,
          'invoice_title': 2.0,
        },
        headerAlignments: const {
          'logo': 'left',
          'company_info': 'left',
          'invoice_title': 'right',
        },
        sections: const [
          ['billing_info', 'invoice_meta'],
          ['items_table'],
          ['legal_mentions', 'totals'],
          ['signature_block'],
        ],
        blockAlignment: const {
          'billing_info': 'left',
          'invoice_meta': 'right',
          'items_table': 'left',
          'totals': 'right',
          'legal_mentions': 'left',
          'signature_block': 'right',
        },
        tableStyle: 'alternate_dark',
        footerStyle: 'contact_bar_icons',
        pagePadding: 36,
        signatoryTitle: 'Authorized Signature',
      ),
    ),

    // ⑥ COMPACT PRO — ✨ tableStyle → side_bars_orange
    InvoiceTemplate(
      id: 'default_6',
      name: 'Compact Pro',
      description: 'Diagonales latérales & barres orange — dense',
      primaryColor: const Color(0xFFE8A33D),
      textColor: const Color(0xFF1F2937),
      backgroundColor: const Color(0xFFFFFFFF),
      fontSize: 11.5,
      fontFamily: 'WorkSans',
      category: 'Corporate',
      price: 0,
      rating: 4.5,
      designVersion: 4,
      positions: _preset(
        title: 'INVOICE',
        headerStyle: 'split_diagonal_corners',
        headerSections: const [
          ['invoice_title'],
          ['company_info'],
        ],
        headerWidths: const {
          'logo': 0.7,
          'company_info': 2.0,
          'invoice_title': 1.4,
        },
        headerAlignments: const {
          'logo': 'left',
          'company_info': 'left',
          'invoice_title': 'center',
        },
        sections: const [
          ['invoice_meta', 'billing_info'],
          ['items_table'],
          ['totals'],
          ['legal_mentions', 'signature_block'],
        ],
        blockAlignment: const {
          'billing_info': 'right',
          'invoice_meta': 'left',
          'items_table': 'left',
          'totals': 'right',
          'legal_mentions': 'left',
          'signature_block': 'left',
        },
        blockWidths: const {'billing_info': 1.0, 'invoice_meta': 1.2},
        tableStyle: 'side_bars_orange',
        footerStyle: 'diagonal_bottom_stripes',
        showThankYou: false,
        signatoryTitle: 'AUTHORIZED SIGN',
        bankName: 'Account 1234 1325 4879',
        bankAccount: 'A/C Name / Bank Details',
        pagePadding: 36,
      ),
    ),

    // ⑦ CARTE DORÉE — ✨ headerStyle → serif_title
    InvoiceTemplate(
      id: 'default_7',
      name: 'Carte Dorée',
      description: 'Titre serif & pied épais — élégant',
      primaryColor: const Color(0xFFE8A33D),
      textColor: const Color(0xFF1F2937),
      backgroundColor: const Color(0xFFFFFDF7),
      fontSize: 11.5,
      fontFamily: 'WorkSans',
      category: 'Élégant',
      price: 500,
      rating: 4.7,
      designVersion: 4,
      positions: _preset(
        title: 'Invoice',
        headerStyle: 'serif_title',
        headerSections: const [
          ['logo', 'company_info'],
          ['invoice_title'],
        ],
        headerWidths: const {
          'logo': 0.9,
          'company_info': 2.0,
          'invoice_title': 1.6,
        },
        headerAlignments: const {
          'logo': 'left',
          'company_info': 'left',
          'invoice_title': 'right',
        },
        sections: const [
          ['billing_info', 'invoice_meta'],
          ['items_table'],
          ['legal_mentions', 'totals'],
          ['signature_block'],
        ],
        blockAlignment: const {
          'billing_info': 'left',
          'invoice_meta': 'right',
          'items_table': 'left',
          'totals': 'right',
          'legal_mentions': 'left',
          'signature_block': 'right',
        },
        tableStyle: 'orange_bars',
        footerStyle: 'thick_orange_band',
        showThankYou: true,
        thankYouText: 'THANK YOU FOR YOUR BUSINESS',
        signatoryTitle: 'Your Signature Here',
        bankName: 'Account: 1122004466',
        bankAccount: 'Bank Details',
        pagePadding: 36,
      ),
    ),

    // ⑧ BANDEAU SOMBRE
    InvoiceTemplate(
      id: 'default_8',
      name: 'Bandeau Sombre',
      description: 'Losange central & stripe arc-en-ciel — premium',
      primaryColor: const Color(0xFFE8A33D),
      textColor: const Color(0xFF1F2937),
      backgroundColor: const Color(0xFFFFFFFF),
      fontSize: 11.5,
      fontFamily: 'WorkSans',
      category: 'Premium',
      price: 1000,
      rating: 4.9,
      designVersion: 4,
      isPremium: true,
      positions: _preset(
        title: 'INVOICE',
        headerStyle: 'diamond_center',
        headerSections: const [
          ['company_info'],
          ['invoice_title'],
        ],
        headerWidths: const {
          'logo': 0.8,
          'company_info': 2.0,
          'invoice_title': 1.6,
        },
        headerAlignments: const {
          'logo': 'center',
          'company_info': 'center',
          'invoice_title': 'right',
        },
        sections: const [
          ['billing_info', 'invoice_meta'],
          ['items_table'],
          ['legal_mentions', 'totals'],
          ['signature_block'],
        ],
        blockAlignment: const {
          'billing_info': 'left',
          'invoice_meta': 'right',
          'items_table': 'left',
          'totals': 'right',
          'legal_mentions': 'left',
          'signature_block': 'right',
        },
        tableStyle: 'orange_bars',
        footerStyle: 'rainbow_strip',
        showThankYou: true,
        thankYouText: 'Thank you for business!',
        signatoryTitle: 'Surname Here',
        bankName: 'Bank Name Here',
        bankAccount: 'Branch Code 000000 / Account 00 000 000 000',
        pagePadding: 36,
      ),
    ),

    // ⑨ MODERNE DATE — image #7
    InvoiceTemplate(
      id: 'default_9',
      name: 'Moderne Date',
      description: 'Pill orange & table bleu foncé — moderne daté',
      primaryColor: const Color(0xFFE8A33D),
      textColor: const Color(0xFF1F2937),
      backgroundColor: const Color(0xFFFFFFFF),
      fontSize: 11.5,
      fontFamily: 'WorkSans',
      category: 'Moderne',
      price: 0,
      rating: 4.6,
      designVersion: 4,
      positions: _preset(
        title: 'Invoice',
        subtitle: 'Invoice: 0001593     Date 01/05/2029',
        headerStyle: 'pill_date',
        headerSections: const [
          ['logo', 'company_info'],
          ['invoice_title'],
        ],
        headerWidths: const {
          'logo': 0.8,
          'company_info': 2.0,
          'invoice_title': 1.6,
        },
        headerAlignments: const {
          'logo': 'left',
          'company_info': 'left',
          'invoice_title': 'right',
        },
        sections: const [
          ['billing_info'],
          ['items_table'],
          ['legal_mentions', 'totals'],
          ['signature_block'],
        ],
        blockAlignment: const {
          'billing_info': 'left',
          'invoice_meta': 'right',
          'items_table': 'left',
          'totals': 'right',
          'legal_mentions': 'left',
          'signature_block': 'right',
        },
        tableStyle: 'dark_header',
        footerStyle: 'diagonal_bottom_stripes',
        accentBorder: '',
        pagePadding: 36,
        signatoryTitle: 'Director',
        bankName: 'Your Bank',
        bankAccount: '000 000 000',
      ),
    ),
  ];

  // ═══════════════════════════════════════════════════════════════
  //  SÉRIALISATION
  // ═══════════════════════════════════════════════════════════════
  factory InvoiceTemplate.fromFirestore(DocumentSnapshot doc) =>
      InvoiceTemplate.fromMap(doc.data() as Map<String, dynamic>,
          documentId: doc.id);

  factory InvoiceTemplate.fromMap(Map<String, dynamic> map,
      {String? documentId}) {
    return InvoiceTemplate(
      id: documentId ?? map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      primaryColor: Color((map['primaryColor'] as num?)?.toInt() ?? 0xFF1976D2),
      textColor: Color((map['textColor'] as num?)?.toInt() ?? 0xFF1A1A1A),
      backgroundColor:
          Color((map['backgroundColor'] as num?)?.toInt() ?? 0xFFFFFFFF),
      showLogo: map['showLogo'] ?? true,
      showTaxDetails: map['showTaxDetails'] ?? true,
      showPaymentTerms: map['showPaymentTerms'] ?? true,
      showPaymentQR: map['showPaymentQR'] ?? false,
      isPremium: map['isPremium'] ?? false,
      isDefault: map['isDefault'] ?? false,
      fontFamily: map['fontFamily'] ?? 'WorkSans',
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 11.5,
      showBorder: map['showBorder'] ?? false,
      createdBy: map['createdBy'],
      isActive: map['isActive'] ?? true,
      createdAt:
          map['createdAt'] != null ? _parseDateTime(map['createdAt']) : null,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      paid: map['paid'] ?? false,
      purchasedBy: List<String>.from(map['purchasedBy'] ?? const []),
      fileType: map['fileType'] ?? '',
      fileData: map['fileData'] ?? '',
      mapping: Map<String, String>.from(map['mapping'] ?? const {}),
      category: map['category'] ?? 'classique',
      positions: Map<String, dynamic>.from(map['positions'] ?? const {}),
      designVersion: (map['designVersion'] as num?)?.toInt() ?? 4,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'primaryColor': primaryColorValue,
        'textColor': textColorValue,
        'backgroundColor': backgroundColorValue,
        'showLogo': showLogo,
        'showTaxDetails': showTaxDetails,
        'showPaymentTerms': showPaymentTerms,
        'showPaymentQR': showPaymentQR,
        'isPremium': isPremium,
        'isDefault': isDefault,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'showBorder': showBorder,
        'createdBy': createdBy,
        'isActive': isActive,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
        'price': price,
        'paid': paid,
        'purchasedBy': purchasedBy,
        'fileType': fileType,
        'fileData': fileData,
        'mapping': mapping,
        'category': category,
        'positions': positions,
        'designVersion': designVersion,
        'rating': rating,
      };

  bool canBeCustomizedBy({
    required String userId,
    required bool isAdmin,
    required bool hasPremiumAccess,
  }) {
    if (isAdmin) return true;
    if (price <= 0) return true;
    if (hasPremiumAccess) return true;
    if (userId.isNotEmpty && createdBy == userId) return true;
    return userId.isNotEmpty && purchasedBy.contains(userId);
  }

  InvoiceTemplate copyWith({
    String? name,
    String? description,
    Color? primaryColor,
    Color? textColor,
    Color? backgroundColor,
    bool? showLogo,
    bool? showTaxDetails,
    bool? showPaymentTerms,
    bool? showPaymentQR,
    bool? isPremium,
    bool? isDefault,
    String? fontFamily,
    double? fontSize,
    bool? showBorder,
    bool? isActive,
    double? price,
    bool? paid,
    List<String>? purchasedBy,
    String? fileType,
    String? fileData,
    Map<String, String>? mapping,
    String? category,
    Map<String, dynamic>? positions,
    int? designVersion,
    double? rating,
  }) =>
      InvoiceTemplate(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        primaryColor: primaryColor ?? this.primaryColor,
        textColor: textColor ?? this.textColor,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        showLogo: showLogo ?? this.showLogo,
        showTaxDetails: showTaxDetails ?? this.showTaxDetails,
        showPaymentTerms: showPaymentTerms ?? this.showPaymentTerms,
        showPaymentQR: showPaymentQR ?? this.showPaymentQR,
        isPremium: isPremium ?? this.isPremium,
        isDefault: isDefault ?? this.isDefault,
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        showBorder: showBorder ?? this.showBorder,
        createdBy: createdBy,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        price: price ?? this.price,
        paid: paid ?? this.paid,
        purchasedBy: purchasedBy ?? this.purchasedBy,
        fileType: fileType ?? this.fileType,
        fileData: fileData ?? this.fileData,
        mapping: mapping ?? this.mapping,
        category: category ?? this.category,
        positions: positions ?? this.positions,
        designVersion: designVersion ?? this.designVersion,
        rating: rating ?? this.rating,
      );

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return DateTime.now();
  }
}