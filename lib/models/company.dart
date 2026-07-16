// lib/models/company.dart
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'company.g.dart';

@JsonSerializable()
@HiveType(typeId: 10)
class Company {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String address;
  
  @HiveField(3)
  final String taxId; // NUI (Numéro d'Identifiant Unique)
  
  @HiveField(4)
  final String phone;
  
  @HiveField(5)
  final String email;
  
  @HiveField(6)
  final String logoPath;
  
  @HiveField(7)
  final String currency;
  
  @HiveField(8)
  final double defaultTaxRate;
  
  @HiveField(9)
  final String legalText;
  
  @HiveField(10)
  final String website;
  
  @HiveField(11)
  final String rccm;

  Company({
    String? id,
    required this.name,
    required this.address,
    required this.taxId,
    required this.phone,
    required this.email,
    this.logoPath = '',
    this.currency = 'XAF',
    this.defaultTaxRate = 18.0,
    this.legalText = 'Conforme aux dispositions du SYSCOHADA révisé',
    this.website = '',
    this.rccm = '',
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'taxId': taxId,
      'phone': phone,
      'email': email,
      'logoPath': logoPath,
      'currency': currency,
      'defaultTaxRate': defaultTaxRate,
      'legalText': legalText,
      'website': website,
      'rccm': rccm,
    };
  }

  factory Company.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Company(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      taxId: map['taxId'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      logoPath: map['logoPath'] ?? '',
      currency: map['currency'] ?? 'XAF',
      defaultTaxRate: (map['defaultTaxRate'] as num?)?.toDouble() ?? 18.0,
      legalText: map['legalText'] ?? 'Conforme aux dispositions du SYSCOHADA révisé',
      website: map['website'] ?? '',
      rccm: map['rccm'] ?? '',
    );
  }

  Company copyWith({
    String? name,
    String? address,
    String? taxId,
    String? phone,
    String? email,
    String? logoPath,
    String? currency,
    double? defaultTaxRate,
    String? legalText,
    String? website,
    String? rccm,
  }) {
    return Company(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      taxId: taxId ?? this.taxId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      logoPath: logoPath ?? this.logoPath,
      currency: currency ?? this.currency,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      legalText: legalText ?? this.legalText,
      website: website ?? this.website,
      rccm: rccm ?? this.rccm,
    );
  }
}