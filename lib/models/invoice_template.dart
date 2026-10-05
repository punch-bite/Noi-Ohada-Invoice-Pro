// lib/models/invoice_template.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'invoice_layout.dart';

part 'invoice_template.g.dart';

@HiveType(typeId: 6)
class InvoiceTemplate {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final int primaryColorValue;

  @HiveField(4)
  final int textColorValue;

  @HiveField(5)
  final int backgroundColorValue;

  @HiveField(6)
  final bool showLogo;

  @HiveField(7)
  final bool showTaxDetails;

  @HiveField(8)
  final bool showPaymentTerms;

  @HiveField(9)
  final bool showPaymentQR;

  @HiveField(10)
  final bool isPremium;

  @HiveField(11)
  final bool isDefault;

  @HiveField(12)
  final String fontFamily;

  @HiveField(13)
  final double fontSize;

  @HiveField(14)
  final bool showBorder;

  @HiveField(15)
  final String? createdBy;

  @HiveField(16)
  final bool isActive;

  @HiveField(17)
  final DateTime? createdAt;

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

  static const int kRoyalDesignVersion = 2;

  static bool presetPositionsNeedBackfill({
    required Map<String, dynamic>? storedPositions,
    required int storedVersion,
  }) {
    if (storedVersion < kRoyalDesignVersion) return false;
    return storedPositions == null || storedPositions.isEmpty;
  }

  // ============================================================
  //  🧩 SECTIONS DE BLOCS (compat Firestore)
  // ============================================================
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

  /// 🧩 Positions effectives : custom > template.
  static Map<String, dynamic> effectivePositions({
    required Map<String, dynamic> customPositions,
    required Map<String, dynamic> templatePositions,
  }) =>
      customPositions.isNotEmpty
          ? customPositions
          : Map<String, dynamic>.from(templatePositions);

  // ============================================================
  //  🧩 EN-TÊTE : éléments déplaçables
  // ============================================================
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
            (headerElements.contains(element) ||
                element.startsWith('text_'))) {
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

  // ============================================================
  //  📋 VARIABLES / CATÉGORIES
  // ============================================================
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
    'Menthe',
    'Marbre',
    'Charbon',
  ];

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
    this.fontFamily = 'Roboto',
    this.fontSize = 12.0,
    this.showBorder = true,
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
    this.designVersion = 1,
  })  : primaryColorValue = primaryColor?.toARGB32() ?? 0xFF1976D2,
        textColorValue = textColor?.toARGB32() ?? 0xFF000000,
        backgroundColorValue = backgroundColor?.toARGB32() ?? 0xFFFFFFFF;

  factory InvoiceTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InvoiceTemplate(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      primaryColor:
          Color((data['primaryColor'] as num?)?.toInt() ?? 0xFF1976D2),
      textColor: Color((data['textColor'] as num?)?.toInt() ?? 0xFF000000),
      backgroundColor:
          Color((data['backgroundColor'] as num?)?.toInt() ?? 0xFFFFFFFF),
      showLogo: data['showLogo'] ?? true,
      showTaxDetails: data['showTaxDetails'] ?? true,
      showPaymentTerms: data['showPaymentTerms'] ?? true,
      showPaymentQR: data['showPaymentQR'] ?? false,
      isPremium: data['isPremium'] ?? false,
      isDefault: data['isDefault'] ?? false,
      fontFamily: data['fontFamily'] ?? 'Roboto',
      fontSize: (data['fontSize'] as num?)?.toDouble() ?? 12.0,
      showBorder: data['showBorder'] ?? true,
      createdBy: data['createdBy'],
      isActive: data['isActive'] ?? true,
      createdAt:
          data['createdAt'] != null ? _parseDateTime(data['createdAt']) : null,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      paid: data['paid'] ?? false,
      purchasedBy: List<String>.from(data['purchasedBy'] ?? const []),
      fileType: data['fileType'] ?? '',
      fileData: data['fileData'] ?? '',
      mapping: Map<String, String>.from(data['mapping'] ?? const {}),
      category: data['category'] ?? 'classique',
      positions: Map<String, dynamic>.from(data['positions'] ?? const {}),
      designVersion: (data['designVersion'] as num?)?.toInt() ?? 1,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
    );
  }

  factory InvoiceTemplate.fromMap(Map<String, dynamic> map,
      {String? documentId}) {
    return InvoiceTemplate(
      id: documentId ?? map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      primaryColor: Color((map['primaryColor'] as num?)?.toInt() ?? 0xFF1976D2),
      textColor: Color((map['textColor'] as num?)?.toInt() ?? 0xFF000000),
      backgroundColor:
          Color((map['backgroundColor'] as num?)?.toInt() ?? 0xFFFFFFFF),
      showLogo: map['showLogo'] ?? true,
      showTaxDetails: map['showTaxDetails'] ?? true,
      showPaymentTerms: map['showPaymentTerms'] ?? true,
      showPaymentQR: map['showPaymentQR'] ?? false,
      isPremium: map['isPremium'] ?? false,
      isDefault: map['isDefault'] ?? false,
      fontFamily: map['fontFamily'] ?? 'Roboto',
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 12.0,
      showBorder: map['showBorder'] ?? true,
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
      designVersion: (map['designVersion'] as num?)?.toInt() ?? 1,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
  }

  // ============================================================
  //  🧩 CONFIGURATION « positions » d'un modèle prédéfini
  // ============================================================
  //
  // 🔄 v3 : ajout des nouvelles clés exploitées par le `PrintingService` :
  //   • `page_padding` — marge de page (24 par défaut)
  //   • `show_watermark` — filigrane ON/OFF
  //   • `watermark_text` — texte du filigrane
  //   • `stamp_x/y/rotation/scale/color` — tampon PAYÉ déplaçable
  //   • `qr_position` — 'standalone' | 'header' | 'footer'
  //   • `signature_image` — base64 (rempli par SignatureService)
  //
  // Le preset reste un « document complet » exploitable directement par
  // l'aperçu et le PDF, sans passer par l'atelier.
  static Map<String, dynamic> _presetPositions({
    required String invoiceTitle,
    String invoiceSubtitle = '',
    bool showQr = false,
    bool showSignatureLine = true,
    String signatoryTitle = 'Direction Générale',
    bool showPaidStamp = true,
    String stampText = 'PAYÉ',
    String legalText =
        'Paiement sous 30 jours net. Pénalités de retard applicables selon '
            'normes SYSCOHADA.',
    List<String> headerOrder = const ['logo', 'company_info', 'invoice_title'],
    Map<String, double> headerWidths = const {'company_info': 2.0},
    Map<String, String> headerAlignments = const {
      'logo': 'left',
      'company_info': 'left',
      'invoice_title': 'right',
    },
    // ✅ Nouveaux paramètres
    double pagePadding = 24.0,
    bool showWatermark = false,
    String watermarkText = 'OHADA Invoice Pro',
    String qrPosition = 'standalone',
    int stampColor = 0xFFBAAB6D,
    double stampX = 0.5,
    double stampY = 0.5,
    double stampRotation = -0.15,
    double stampScale = 1.0,
  }) {
    final sections = <List<String>>[
      const ['billing_info', 'invoice_meta'],
      const ['items_table'],
      const ['totals'],
      if (showQr) const ['qr_block'],
      const ['legal_mentions'],
      if (showSignatureLine) const ['signature_block'],
    ];

    return <String, dynamic>{
      // Base identique à celle produite par l'atelier.
      ...InvoiceLayoutConfig.defaultLayout().toMap(),
      'blocks_sections': encodeSections(sections),
      'blocks_order': [for (final s in sections) ...s],
      'block_visibility': <String, bool>{
        'billing_info': true,
        'invoice_meta': true,
        'items_table': true,
        'totals': true,
        'legal_mentions': true,
        'signature_block': showSignatureLine,
        'qr_block': showQr,
      },
      'block_alignment': const <String, String>{
        'billing_info': 'left',
        'invoice_meta': 'right',
        'items_table': 'left',
        'totals': 'right',
        'legal_mentions': 'left',
        'signature_block': 'center',
        'qr_block': 'center',
      },
      'header_elements_order': List<String>.from(headerOrder),
      'header_widths': Map<String, double>.from(headerWidths),
      'header_alignments': Map<String, String>.from(headerAlignments),
      'invoice_title_text': invoiceTitle,
      'invoice_subtitle': invoiceSubtitle,
      'custom_legal_text': legalText,
      'signatory_title': signatoryTitle,
      'stamp_text': stampText,
      'show_paid_stamp': showPaidStamp,
      'show_signature_line': showSignatureLine,
      'qr_position': qrPosition,
      // ✅ Nouvelles clés exploitées par le PrintingService.
      'page_padding': pagePadding,
      'show_watermark': showWatermark,
      'watermark_text': watermarkText,
      'stamp_color': stampColor,
      'stamp_x': stampX,
      'stamp_y': stampY,
      'stamp_rotation': stampRotation,
      'stamp_scale': stampScale,
    };
  }

  // ============================================================
  //  MODÈLES PAR DÉFAUT
  // ============================================================
  static List<InvoiceTemplate> getDefaultTemplates() {
    return [
      InvoiceTemplate(
        id: 'default_1',
        name: 'Améthyste',
        description:
            'Classique raffiné aux tons améthyste — conforme SYSCOHADA',
        primaryColor: const Color.fromARGB(76, 48, 5, 70),
        textColor: const Color(0xFF1E1A1F),
        backgroundColor: const Color(0xFFFFF7FC),
        fontSize: 12.5,
        fontFamily: 'WorkSans',
        isDefault: true,
        showLogo: true,
        showTaxDetails: true,
        showPaymentTerms: true,
        showBorder: false,
        category: 'Classique',
        price: 0,
        rating: 4.5,
        designVersion: 2,
        positions: _presetPositions(
          invoiceTitle: 'FACTURE',
          signatoryTitle: 'Direction Générale',
        ),
      ),
      InvoiceTemplate(
        id: 'default_2',
        name: 'Moderne Violet',
        description: 'Design contemporain, accents vifs et tableaux épurés',
        primaryColor: const Color(0xFF6C3AED),
        textColor: const Color(0xFF1E1A1F),
        backgroundColor: const Color(0xFFF5F3FF),
        fontSize: 12.5,
        fontFamily: 'WorkSans',
        showLogo: true,
        showTaxDetails: true,
        showPaymentTerms: true,
        showBorder: true,
        category: 'Moderne',
        price: 0,
        rating: 4.0,
        designVersion: 2,
        positions: _presetPositions(
          invoiceTitle: 'FACTURE',
          invoiceSubtitle: 'Document commercial',
          signatoryTitle: 'Service Commercial',
        ),
      ),
      InvoiceTemplate(
        id: 'default_3',
        name: 'Élégance Or',
        description: 'Style sophistiqué champagne & or — idéal grands comptes',
        primaryColor: const Color(0xFF6A5E28),
        textColor: const Color(0xFF211B00),
        backgroundColor: const Color(0xFFFDF8EC),
        fontSize: 12.5,
        fontFamily: 'WorkSans',
        showLogo: true,
        showTaxDetails: true,
        showPaymentTerms: true,
        showBorder: false,
        category: 'Élégant',
        price: 0,
        rating: 4.8,
        designVersion: 2,
        positions: _presetPositions(
          invoiceTitle: 'FACTURE',
          invoiceSubtitle: 'Prestige & Excellence',
          signatoryTitle: 'La Direction',
        ),
      ),
      InvoiceTemplate(
        id: 'default_4',
        name: 'Nuit Royale',
        description: 'Encre bleutée & améthyste claire — édition premium',
        primaryColor: const Color(0xFFE6B4FD),
        textColor: const Color(0xFFF7EEF5),
        backgroundColor: const Color(0xFF171216),
        fontSize: 12.5,
        fontFamily: 'WorkSans',
        showLogo: true,
        showTaxDetails: true,
        showPaymentTerms: true,
        showBorder: false,
        isPremium: true,
        category: 'Premium',
        price: 500,
        rating: 5.0,
        designVersion: 2,
        positions: _presetPositions(
          invoiceTitle: 'FACTURE',
          invoiceSubtitle: 'Édition Premium',
          signatoryTitle: 'Direction Générale',
          showWatermark: true,
          watermarkText: 'ÉDITION PREMIUM',
        ),
      ),
      InvoiceTemplate(
        id: 'default_5',
        name: 'Saphir Corporate',
        description:
            'Autorité et confiance — design institutionnel bleu saphir',
        primaryColor: const Color(0xFF1E3A8A),
        textColor: const Color(0xFF1E1A1F),
        backgroundColor: const Color(0xFFEFF6FF),
        fontSize: 12.5,
        fontFamily: 'WorkSans',
        showLogo: true,
        showTaxDetails: true,
        showPaymentTerms: true,
        showBorder: true,
        category: 'Corporate',
        price: 1000,
        rating: 4.3,
        designVersion: 2,
        positions: _presetPositions(
          invoiceTitle: 'FACTURE',
          invoiceSubtitle: 'Société & Institution',
          signatoryTitle: 'La Direction Générale',
        ),
      ),
      InvoiceTemplate(
        id: 'default_6',
        name: 'Menthe Royale',
        description: 'Fraîcheur émeraude — apaisant, naturel et élégant',
        primaryColor: const Color(0xFF059669),
        textColor: const Color(0xFF0F2E1D),
        backgroundColor: const Color(0xFFF0FDF4),
        fontSize: 12.5,
        fontFamily: 'WorkSans',
        showLogo: true,
        showTaxDetails: true,
        showPaymentTerms: true,
        showPaymentQR: true,
        showBorder: false,
        category: 'Menthe',
        price: 0,
        rating: 4.6,
        designVersion: 2,
        positions: _presetPositions(
          invoiceTitle: 'FACTURE',
          invoiceSubtitle: 'Paiement par QR sécurisé',
          showQr: true,
          signatoryTitle: 'Service Comptabilité',
          qrPosition: 'standalone',
        ),
      ),
      InvoiceTemplate(
        id: 'default_7',
        name: 'Marbre Perle',
        description: 'Subtilité marbre — papier perle et fins reliefs',
        primaryColor: const Color(0xFF334155),
        textColor: const Color(0xFF0F172A),
        backgroundColor: const Color(0xFFF8FAFC),
        fontSize: 12.5,
        fontFamily: 'WorkSans',
        showLogo: true,
        showTaxDetails: true,
        showPaymentTerms: true,
        showPaymentQR: true,
        showBorder: false,
        category: 'Marbre',
        price: 500,
        rating: 4.7,
        designVersion: 2,
        positions: _presetPositions(
          invoiceTitle: 'FACTURE',
          invoiceSubtitle: 'Paiement par QR sécurisé',
          showQr: true,
          signatoryTitle: 'Direction Financière',
          qrPosition: 'footer',
        ),
      ),
      InvoiceTemplate(
        id: 'default_8',
        name: 'Obsidienne',
        description: 'Contraste nocturne profond, accents ambre & or',
        primaryColor: const Color(0xFFF3E29F),
        textColor: const Color(0xFFF7EEF5),
        backgroundColor: const Color(0xFF0B0E14),
        fontSize: 12.5,
        fontFamily: 'WorkSans',
        showLogo: true,
        showTaxDetails: true,
        showPaymentTerms: true,
        showBorder: false,
        isPremium: true,
        category: 'Charbon',
        price: 1000,
        rating: 4.9,
        designVersion: 2,
        positions: _presetPositions(
          invoiceTitle: 'FACTURE',
          invoiceSubtitle: 'Édition Signature',
          signatoryTitle: 'Direction Générale',
          showWatermark: true,
          watermarkText: 'SIGNATURE',
          stampColor: 0xFFF3E29F,
        ),
      ),
    ];
  }

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
  }) {
    return InvoiceTemplate(
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
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return DateTime.now();
  }
}