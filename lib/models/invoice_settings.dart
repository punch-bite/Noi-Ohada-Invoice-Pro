// lib/models/invoice_settings.dart
import 'package:flutter/material.dart';

class InvoiceSettings {
  bool showLogo;
  bool showBorder;
  bool showWatermark;
  bool showPaymentQR;
  Color primaryColor;
  Color secondaryColor;
  Color backgroundColor;
  Color textColor;
  String fontFamily;
  double fontSize;
  bool showCompanyInfo;
  bool showClientInfo;
  bool showPaymentTerms;
  bool showTaxDetails;
  String watermarkText;

  InvoiceSettings({
    this.showLogo = true,
    this.showBorder = true,
    this.showWatermark = false,
    this.showPaymentQR = false,
    this.primaryColor = const Color(0xFF1A237E),
    this.secondaryColor = const Color(0xFF3949AB),
    this.backgroundColor = Colors.white,
    this.textColor = const Color(0xFF1A1A1A),
    this.fontFamily = 'Roboto',
    this.fontSize = 12.0,
    this.showCompanyInfo = true,
    this.showClientInfo = true,
    this.showPaymentTerms = true,
    this.showTaxDetails = true,
    this.watermarkText = 'OHADA Invoice Pro',
  });

  Map<String, dynamic> toMap() {
    return {
      'showLogo': showLogo,
      'showBorder': showBorder,
      'showWatermark': showWatermark,
      'showPaymentQR': showPaymentQR,
      'primaryColor': primaryColor.value,
      'secondaryColor': secondaryColor.value,
      'backgroundColor': backgroundColor.value,
      'textColor': textColor.value,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'showCompanyInfo': showCompanyInfo,
      'showClientInfo': showClientInfo,
      'showPaymentTerms': showPaymentTerms,
      'showTaxDetails': showTaxDetails,
      'watermarkText': watermarkText,
    };
  }

  factory InvoiceSettings.fromMap(Map<String, dynamic> map) {
    return InvoiceSettings(
      showLogo: map['showLogo'] ?? true,
      showBorder: map['showBorder'] ?? true,
      showWatermark: map['showWatermark'] ?? false,
      showPaymentQR: map['showPaymentQR'] ?? false,
      primaryColor: Color(map['primaryColor'] ?? 0xFF1A237E),
      secondaryColor: Color(map['secondaryColor'] ?? 0xFF3949AB),
      backgroundColor: Color(map['backgroundColor'] ?? 0xFFFFFFFF),
      textColor: Color(map['textColor'] ?? 0xFF1A1A1A),
      fontFamily: map['fontFamily'] ?? 'Roboto',
      fontSize: map['fontSize'] ?? 12.0,
      showCompanyInfo: map['showCompanyInfo'] ?? true,
      showClientInfo: map['showClientInfo'] ?? true,
      showPaymentTerms: map['showPaymentTerms'] ?? true,
      showTaxDetails: map['showTaxDetails'] ?? true,
      watermarkText: map['watermarkText'] ?? 'OHADA Invoice Pro',
    );
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
}