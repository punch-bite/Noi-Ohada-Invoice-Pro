// lib/models/company.dart
//
// CHANGELOG :
//   • Ajout `memberIds` / `adminIds` pour la notion d'ENTREPRISE PARTAGÉE
//     (SaaS — plusieurs utilisateurs rattachés à la même entreprise).
//   • Ajout `sharedWithUsers` (équivalent générique, lu par les règles).
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'company.g.dart';

@HiveType(typeId: 1)
class Company {
  @HiveField(0)  final String id;
  @HiveField(1)  final String userId;   // propriétaire
  @HiveField(2)  final String name;
  @HiveField(3)  final String address;
  @HiveField(4)  final String taxId;
  @HiveField(5)  final String phone;
  @HiveField(6)  final String email;
  @HiveField(7)  final String logoPath;
  @HiveField(8)  final String currency;
  @HiveField(9)  final double defaultTaxRate;
  @HiveField(10) final String legalText;
  @HiveField(11) final String website;
  @HiveField(12) final String rccm;
  @HiveField(13) final DateTime createdAt;
  @HiveField(14) final DateTime? updatedAt;
  @HiveField(15) final bool isActive;
  @HiveField(16) final bool isSynced;

  // 🔑 NOUVEAU — SaaS partagé
  @HiveField(17) final List<String> memberIds;
  @HiveField(18) final List<String> adminIds;
  @HiveField(19) final List<String> sharedWithUsers;

  Company({
    String? id,
    required this.userId,
    required this.name,
    required this.address,
    required this.taxId,
    required this.phone,
    required this.email,
    this.logoPath = '',
    this.currency = 'XAF',
    this.defaultTaxRate = 18,
    this.legalText = 'Conforme aux normes OHADA et SYSCOHADA',
    this.website = '',
    this.rccm = '',
    DateTime? createdAt,
    this.updatedAt,
    this.isActive = true,
    this.isSynced = false,
    this.memberIds = const [],
    this.adminIds = const [],
    this.sharedWithUsers = const [],
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
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
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'isSynced': isSynced,
      'memberIds': memberIds,
      'adminIds': adminIds,
      'sharedWithUsers': sharedWithUsers,
    };
  }

  factory Company.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Company(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      taxId: map['taxId'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      logoPath: map['logoPath'] ?? '',
      currency: map['currency'] ?? 'XAF',
      defaultTaxRate: (map['defaultTaxRate'] as num?)?.toDouble() ?? 18,
      legalText: map['legalText'] ?? 'Conforme aux normes OHADA et SYSCOHADA',
      website: map['website'] ?? '',
      rccm: map['rccm'] ?? '',
      createdAt: map['createdAt'] != null
          ? _parseDateTime(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? _parseDateTime(map['updatedAt'])
          : null,
      isActive: map['isActive'] ?? true,
      isSynced: map['isSynced'] ?? false,
      memberIds: List<String>.from(map['memberIds'] ?? const []),
      adminIds: List<String>.from(map['adminIds'] ?? const []),
      sharedWithUsers: List<String>.from(map['sharedWithUsers'] ?? const []),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  bool isOwnerOf(String uid) => userId == uid;
  bool isAdminOf(String uid) => adminIds.contains(uid);
  bool hasMember(String uid) =>
      isOwnerOf(uid) || isAdminOf(uid) || memberIds.contains(uid);

  Company copyWith({
    String? name, String? address, String? phone, String? email,
    String? logoPath, String? currency, double? defaultTaxRate,
    String? legalText, String? website, String? rccm, String? taxId,
    bool? isActive, bool? isSynced,
    List<String>? memberIds, List<String>? adminIds,
    List<String>? sharedWithUsers,
  }) {
    return Company(
      id: id,
      userId: userId,
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
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      memberIds: memberIds ?? this.memberIds,
      adminIds: adminIds ?? this.adminIds,
      sharedWithUsers: sharedWithUsers ?? this.sharedWithUsers,
    );
  }
}