// lib/models/invoice_settings.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'invoice_settings.g.dart';

@HiveType(typeId: 5) // Assure-toi que l'ID est unique
class InvoiceSettings {
  @HiveField(0)
  final bool showLogo;

  @HiveField(1)
  final bool showBorder;

  @HiveField(2)
  final bool showWatermark;

  @HiveField(3)
  final bool showPaymentQR;

  @HiveField(4)
  final int primaryColorValue;

  @HiveField(5)
  final int secondaryColorValue;

  @HiveField(6)
  final int backgroundColorValue;

  @HiveField(7)
  final int textColorValue;

  @HiveField(8)
  final String fontFamily;

  @HiveField(9)
  final double fontSize;

  @HiveField(10)
  final bool showCompanyInfo;

  @HiveField(11)
  final bool showClientInfo;

  @HiveField(12)
  final bool showPaymentTerms;

  @HiveField(13)
  final bool showTaxDetails;

  @HiveField(14)
  final String watermarkText;

  // Getters pour les couleurs (converties depuis les valeurs entières)
  Color get primaryColor => Color(primaryColorValue);
  Color get secondaryColor => Color(secondaryColorValue);
  Color get backgroundColor => Color(backgroundColorValue);
  Color get textColor => Color(textColorValue);

  InvoiceSettings({
    this.showLogo = true,
    this.showBorder = true,
    this.showWatermark = false,
    this.showPaymentQR = false,
    Color? primaryColor,
    Color? secondaryColor,
    Color? backgroundColor,
    Color? textColor,
    this.fontFamily = 'Roboto',
    this.fontSize = 12.0,
    this.showCompanyInfo = true,
    this.showClientInfo = true,
    this.showPaymentTerms = true,
    this.showTaxDetails = true,
    this.watermarkText = 'OHADA Invoice Pro',
  })  : primaryColorValue = primaryColor?.value ?? 0xFF1A237E,
        secondaryColorValue = secondaryColor?.value ?? 0xFF3949AB,
        backgroundColorValue = backgroundColor?.value ?? 0xFFFFFFFF,
        textColorValue = textColor?.value ?? 0xFF1A1A1A;

  // Constructeur pour Firestore
  factory InvoiceSettings.fromFirestore(Map<String, dynamic> map) {
    return InvoiceSettings(
      showLogo: map['showLogo'] ?? true,
      showBorder: map['showBorder'] ?? true,
      showWatermark: map['showWatermark'] ?? false,
      showPaymentQR: map['showPaymentQR'] ?? false,
      primaryColor: Color((map['primaryColor'] as num?)?.toInt() ?? 0xFF1A237E),
      secondaryColor: Color((map['secondaryColor'] as num?)?.toInt() ?? 0xFF3949AB),
      backgroundColor: Color((map['backgroundColor'] as num?)?.toInt() ?? 0xFFFFFFFF),
      textColor: Color((map['textColor'] as num?)?.toInt() ?? 0xFF1A1A1A),
      fontFamily: map['fontFamily'] ?? 'Roboto',
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 12.0,
      showCompanyInfo: map['showCompanyInfo'] ?? true,
      showClientInfo: map['showClientInfo'] ?? true,
      showPaymentTerms: map['showPaymentTerms'] ?? true,
      showTaxDetails: map['showTaxDetails'] ?? true,
      watermarkText: map['watermarkText'] ?? 'OHADA Invoice Pro',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'showLogo': showLogo,
      'showBorder': showBorder,
      'showWatermark': showWatermark,
      'showPaymentQR': showPaymentQR,
      'primaryColor': primaryColorValue,
      'secondaryColor': secondaryColorValue,
      'backgroundColor': backgroundColorValue,
      'textColor': textColorValue,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'showCompanyInfo': showCompanyInfo,
      'showClientInfo': showClientInfo,
      'showPaymentTerms': showPaymentTerms,
      'showTaxDetails': showTaxDetails,
      'watermarkText': watermarkText,
    };
  }

  InvoiceSettings copyWith({
    bool? showLogo,
    bool? showBorder,
    bool? showWatermark,
    bool? showPaymentQR,
    Color? primaryColor,
    Color? secondaryColor,
    Color? backgroundColor,
    Color? textColor,
    String? fontFamily,
    double? fontSize,
    bool? showCompanyInfo,
    bool? showClientInfo,
    bool? showPaymentTerms,
    bool? showTaxDetails,
    String? watermarkText,
  }) {
    return InvoiceSettings(
      showLogo: showLogo ?? this.showLogo,
      showBorder: showBorder ?? this.showBorder,
      showWatermark: showWatermark ?? this.showWatermark,
      showPaymentQR: showPaymentQR ?? this.showPaymentQR,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      showCompanyInfo: showCompanyInfo ?? this.showCompanyInfo,
      showClientInfo: showClientInfo ?? this.showClientInfo,
      showPaymentTerms: showPaymentTerms ?? this.showPaymentTerms,
      showTaxDetails: showTaxDetails ?? this.showTaxDetails,
      watermarkText: watermarkText ?? this.watermarkText,
    );
  }

  // Instance par défaut (pour initialisation)
  static InvoiceSettings get defaultSettings => InvoiceSettings();
}