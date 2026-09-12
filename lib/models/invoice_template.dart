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

  // 💰 Prix de vente du template (0 = gratuit) et statut payé.
  final double price;
  final bool paid;
  final List<String> purchasedBy;

  // 🗂️ Fichier téléversé (PDF/JPEG/PNG) : type MIME + contenu base64.
  final String fileType; // 'pdf' | 'jpeg' | 'png'
  final String fileData; // base64 du fichier

  // 🧩 Mapping : variable de facture → placeholder dans le template.
  // Ex : {'invoice_number': '{invoice_number}', 'client_name': '{client_name}'}
  final Map<String, String> mapping;

  // 🏷️ Catégorie du modèle (pour la boutique) : classique, moderne, premium…
  final String category;

  // 📐 Positions des éléments (drag & drop) : élément → {x, y, scale, visible}.
  // Ex : {'header': {'x': 0.5, 'y': 0.12, 'scale': 1.0, 'visible': true}, ...}
  // Les coordonnées sont RELATIVES (0..1) pour rester proportionnelles à la page.
  final Map<String, dynamic> positions;

  /// ⭐ Note du template (étoiles, 0..5) — affichage boutique.
  final double rating;

  /// 🎨 Version du design prédéfini « Royal Ledger ».
  ///
  /// Utilisée par l'initialiseur Firestore pour mettre à jour les modèles
  /// par défaut vers le nouveau design (v2) SANS écraser les personnalisations
  /// ultérieures de l'admin (un modèle déjà en base avec `designVersion >= 2`
  /// n'est plus écrasé).
  final int designVersion;

  /// Dernière version du design système des modèles prédéfinis.
  static const int kRoyalDesignVersion = 2;

  /// 🧩 Décide si les `positions` d'un modèle « default_* » DÉJÀ stocké en
  /// base doivent être complétées par celles du preset (backfill).
  ///
  /// Les modèles historiques (design v2) ont été semés avec `positions` vides
  /// (`const {}`) : aucune section, aucun texte → la facture retombait sur le
  /// layout fixe et les 8 designs paraissaient identiques. Ce garde-fou
  /// permet à l'initialiseur de rattraper ces documents SANS écraser le reste
  /// (couleurs, polices, mapping, personnalisation admin).
  ///
  /// Règles :
  ///   • version antérieure à [kRoyalDesignVersion] → la mise à jour complète
  ///     du modèle s'en charge déjà (donc pas de backfill ici) ;
  ///   • `positions` absentes, nulles ou vides → backfill nécessaire ;
  ///   • `positions` déjà renseignées → on n'y touche pas.
  static bool presetPositionsNeedBackfill({
    required Map<String, dynamic>? storedPositions,
    required int storedVersion,
  }) {
    if (storedVersion < kRoyalDesignVersion) return false;
    return storedPositions == null || storedPositions.isEmpty;
  }

  // ============================================================
  //  🧩 ENCODAGE DES SECTIONS DE BLOCS (compatible Firestore)
  // ============================================================

  /// 🔗 Séparateur des blocs d'une même section dans l'encodage PLAT de
  /// `blocks_sections`.
  static const String kSectionSeparator = '|';

  /// 🧱 Encode des sections (`List<List<String>>`) en une liste PLATE de
  /// chaînes : `['billing_info|invoice_meta', 'items_table', ...]`.
  ///
  /// Firestore rejette les **tableaux imbriqués** (« Nested arrays are not
  /// supported ») : un preset contenant `List<List<String>>` ne pourrait donc
  /// pas être écrit tel quel dans un document. L'atelier, lui, stocke ses
  /// sections dans SharedPreferences sous forme JSON (imbrication permise) —
  /// [decodeSections] accepte les DEUX formes.
  static List<String> encodeSections(List<List<String>> sections) => [
        for (final section in sections) section.join(kSectionSeparator),
      ];

  /// 🧩 Décode `blocks_sections` en sections, en acceptant :
  ///   • la forme plate compatible Firestore (`List<String>`, séparateur
  ///     [kSectionSeparator]) — utilisée par les presets ;
  ///   • la forme imbriquée historique (`List<List<String>>`) écrite par
  ///     l'atelier via SharedPreferences/JSON.
  ///
  /// Toute autre valeur (absente, type inattendu) donne une liste vide.
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

  /// 🧩 **Positions effectives** d'un modèle.
  ///
  /// Règle de priorité unique de l'application (identique dans l'atelier,
  /// l'aperçu, l'écran de détail et l'impression) :
  ///
  ///   1. la personnalisation locale de l'utilisateur si elle existe ;
  ///   2. sinon les positions **embarquées dans le modèle** (presets
  ///      « Royal Ledger »).
  ///
  /// Sans ce repli, un modèle choisi mais pas encore personnalisé perdrait son
  /// design (textes, sections, visibilité) et la facture retomberait sur le
  /// layout fixe historique.
  static Map<String, dynamic> effectivePositions({
    required Map<String, dynamic> customPositions,
    required Map<String, dynamic> templatePositions,
  }) =>
      customPositions.isNotEmpty
          ? customPositions
          : Map<String, dynamic>.from(templatePositions);

  // 📋 VARIABLES EXPOSÉES DANS L'UI (toutes les données modifiables).
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

  // 🏷️ Catégories disponibles dans la boutique.
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

  // Getters pour les couleurs
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

  // Constructeur Firestore
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

  // Constructeur depuis Map (Firestore)
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

  /// 💎 Modèles prédéfinis « Royal Ledger » — édition raffinée (design v2).
  /// 8 designs signature, cohérents avec les maquettes améthyste/or :
  ///   • papiers à fonds sobres et élégants (perle, champagne, encre bleutée)
  ///   • accents profonds (améthyste, violet royal, saphir, émeraude, or)
  ///   • éditions premium « Nuit Royale » & « Obsidienne » sur fond sombre.
  /// Chaque modèle est STOCKÉ en base (Firestore, par l'initialiseur) pour
  /// être modifiable par l'ADMIN, et reste personnalisable drag & drop.
  /// 🧩 Configuration « positions » complète et prête à imprimer pour un
  /// modèle prédéfini.
  ///
  /// Reproduit EXACTEMENT le schéma écrit par l'ATELIER de personnalisation
  /// (`template_workspace_screen._saveConfig`) afin que l'aperçu A4
  /// (`stitch_a4_invoice_preview`) ET le PDF (`printing_service`) exploitent
  /// dès la première ouverture :
  ///   • l'ordre des sections du corps et la visibilité des blocs
  ///     (`blocks_sections`, `blocks_order`, `block_visibility`) ;
  ///   • l'ordre, la largeur et l'alignement des éléments d'en-tête
  ///     (`header_elements_order`, `header_widths`, `header_alignments`) ;
  ///   • les textes libres (`invoice_title_text`, `invoice_subtitle`,
  ///     `custom_legal_text`, `signatory_title`, `stamp_text`) ;
  ///   • les options d'impression (`qr_position`, `show_paid_stamp`,
  ///     `show_signature_line`).
  ///
  /// Aucune donnée n'est laissée implicite : le modèle est donc « complet »
  /// (sections, textes, méta, pied de page) sans passer par l'atelier.
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
    // Ordre des éléments d'en-tête (schemas identiques à l'atelier).
    List<String> headerOrder = const ['logo', 'company_info', 'invoice_title'],
    Map<String, double> headerWidths = const {'company_info': 2.0},
    Map<String, String> headerAlignments = const {
      'logo': 'left',
      'company_info': 'left',
      'invoice_title': 'right',
    },
  }) {
    // 4 sections empilées, 1 à 3 blocs côte à côte (comme le défaut atelier).
    // `qr_block` reste inoffensif tant que `qr_position != 'standalone'` :
    // le QR est alors rendu DANS le bloc « Totaux ».
    final sections = <List<String>>[
      const ['billing_info', 'invoice_meta'],
      const ['items_table'],
      const ['totals'],
      [
        'legal_mentions',
        'signature_block',
        if (showQr) 'qr_block',
      ],
    ];
    return <String, dynamic>{
      // Base identique à celle produite par l'atelier
      // (`InvoiceLayoutConfig.toMap`) : évite toute clé manquante quand le
      // modèle est ouvert puis re-sauvegardé depuis l'écran de personnalisation.
      ...InvoiceLayoutConfig.defaultLayout().toMap(),
      // ⚠️ Forme PLATE obligatoire : Firestore rejette les tableaux imbriqués
      // (`blocks_sections` reste donc `List<String>`, sections séparées par
      // `kSectionSeparator`). L'atelier relit les deux formes via
      // `InvoiceTemplate.decodeSections`.
      'blocks_sections': encodeSections(sections),
      // Compat : ordre à plat (anciens lecteurs / exports).
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
      'qr_position': 'totals',
    };
  }

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
        ),
      ),
    ];
  }

  /// 👮 La personnalisation de la facture (atelier drag & drop, fond,
  /// mapping) est réservée à l'administrateur et au propriétaire du modèle :
  ///   • administrateur (rôle admin / super-admin) ;
  ///   • créateur du modèle (`createdBy`) ;
  ///   • acheteur (`purchasedBy`) ;
  ///   • abonné premium (`hasPremiumAccess`) ;
  ///   • modèle gratuit (prix 0 : acquis par tous, comme dans la boutique).
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
