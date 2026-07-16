// lib/models/invoice_template.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InvoiceTemplate {
  final String id;
  final String name;
  final String description;
  final Color primaryColor;
  final Color textColor;
  final Color backgroundColor;
  final bool showLogo;
  final bool showTaxDetails;
  final bool showPaymentTerms;
  final bool showPaymentQR;
  final bool isPremium;
  final bool isDefault;
  final String fontFamily;
  final double fontSize;
  final bool showBorder;
  final String? createdBy;
  final bool isActive;
  final DateTime? createdAt;

  InvoiceTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.primaryColor,
    required this.textColor,
    required this.backgroundColor,
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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'primaryColor': primaryColor.value,
      'textColor': textColor.value,
      'backgroundColor': backgroundColor.value,
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
    };
  }

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
    );
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
    );
  }

  /// Fonction d'aide pour parser les dates de manière ultra-robuste
  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }
}