// lib/models/invoice_template.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

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

  // Liste des variables disponibles pour les factures (à exposer dans l'UI).
  static const List<String> availableVariables = [
    'invoice_number',
    'issue_date',
    'due_date',
    'client_name',
    'client_email',
    'client_phone',
    'company_name',
    'company_address',
    'company_tax_id',
    'subtotal',
    'tax_amount',
    'total_amount',
    'status',
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
  })  : primaryColorValue = primaryColor?.value ?? 0xFF1976D2,
        textColorValue = textColor?.value ?? 0xFF000000,
        backgroundColorValue = backgroundColor?.value ?? 0xFFFFFFFF;

  // Constructeur Firestore
  factory InvoiceTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InvoiceTemplate(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      primaryColor: Color((data['primaryColor'] as num?)?.toInt() ?? 0xFF1976D2),
      textColor: Color((data['textColor'] as num?)?.toInt() ?? 0xFF000000),
      backgroundColor: Color((data['backgroundColor'] as num?)?.toInt() ?? 0xFFFFFFFF),
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
      createdAt: data['createdAt'] != null ? _parseDateTime(data['createdAt']) : null,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      paid: data['paid'] ?? false,
      purchasedBy: List<String>.from(data['purchasedBy'] ?? const []),
      fileType: data['fileType'] ?? '',
      fileData: data['fileData'] ?? '',
      mapping: Map<String, String>.from(data['mapping'] ?? const {}),
    );
  }

  // Constructeur depuis Map (Firestore)
  factory InvoiceTemplate.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return InvoiceTemplate(
      id: documentId ?? map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      primaryColor: Color((map['primaryColor'] as num?)?.toInt() ?? 0xFF1976D2),
      textColor: Color((map['textColor'] as num?)?.toInt() ?? 0xFF000000),
      backgroundColor: Color((map['backgroundColor'] as num?)?.toInt() ?? 0xFFFFFFFF),
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
      createdAt: map['createdAt'] != null ? _parseDateTime(map['createdAt']) : null,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      paid: map['paid'] ?? false,
      purchasedBy: List<String>.from(map['purchasedBy'] ?? const []),
      fileType: map['fileType'] ?? '',
      fileData: map['fileData'] ?? '',
      mapping: Map<String, String>.from(map['mapping'] ?? const {}),
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
    };
  }

  static List<InvoiceTemplate> getDefaultTemplates() {
    return [
      InvoiceTemplate(
        id: 'default_1',
        name: 'Classique',
        description: 'Modèle épuré et professionnel',
        primaryColor: const Color(0xFF1A237E),
        textColor: const Color(0xFF000000),
        backgroundColor: Colors.white,
        isDefault: true,
      ),
      InvoiceTemplate(
        id: 'default_2',
        name: 'Moderne',
        description: 'Design contemporain avec touches de couleur',
        primaryColor: const Color(0xFFE91E63),
        textColor: const Color(0xFF000000),
        backgroundColor: const Color(0xFFF5F5F5),
      ),
      InvoiceTemplate(
        id: 'default_3',
        name: 'Élégant',
        description: 'Style sophistiqué pour les grandes entreprises',
        primaryColor: const Color(0xFF004D40),
        textColor: const Color(0xFF000000),
        backgroundColor: const Color(0xFFF9FBE7),
      ),
      InvoiceTemplate(
        id: 'default_4',
        name: 'Premium Or',
        description: 'Design luxueux pour les clients VIP',
        primaryColor: const Color(0xFFFFD700),
        textColor: Colors.white,
        backgroundColor: const Color(0xFF1A1A2E),
        isPremium: true,
      ),
    ];
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