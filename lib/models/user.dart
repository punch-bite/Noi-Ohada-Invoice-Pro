// lib/models/user.dart
//
// CHANGELOG :
//   • Ajout `companyId` (rattachement SaaS — pilote les custom claims côté CF).
//   • Ajout `teamIds` (liste d'équipes — dupliquée dans les claims pour
//     éviter un get() par lecture dans les règles Firestore).
//   • `toMap()` inclut désormais `userId`, `companyId`, `teamIds`.
//   • `isAdmin` reste basé sur `roles` (source serveur → custom claims).
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
@HiveType(typeId: 15)
class AppUser {
  @HiveField(0)  final String id;
  @HiveField(1)  final String email;
  @HiveField(2)  final String displayName;
  @HiveField(3)  final String? phone;
  @HiveField(4)  final String? companyName;
  @HiveField(5)  final String? companyAddress;
  @HiveField(6)  final String? taxId;
  @HiveField(7)  final String? subscriptionId;
  @HiveField(8)  final DateTime createdAt;
  @HiveField(9)  final DateTime? lastLoginAt;
  @HiveField(10) final bool isActive;
  @HiveField(11) final List<String> roles;

  // 🔑 NOUVEAU — Rattachement SaaS
  @HiveField(12) final String? companyId;
  @HiveField(13) final List<String> teamIds;

  AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.phone,
    this.companyName,
    this.companyAddress,
    this.taxId,
    this.subscriptionId,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
    this.roles = const ['user'],
    this.companyId,
    this.teamIds = const [],
  });

  // ===== SÉRIALISATION =====

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': id,
      'email': email,
      'displayName': displayName,
      'phone': phone,
      'companyName': companyName,
      'companyAddress': companyAddress,
      'taxId': taxId,
      'subscriptionId': subscriptionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt':
          lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'isActive': isActive,
      'roles': roles,
      'companyId': companyId,
      'teamIds': teamIds,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return AppUser(
      id: documentId ?? map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      phone: map['phone'],
      companyName: map['companyName'],
      companyAddress: map['companyAddress'],
      taxId: map['taxId'],
      subscriptionId: map['subscriptionId'],
      createdAt: map['createdAt'] != null
          ? _parseDateTime(map['createdAt'])
          : DateTime.now(),
      lastLoginAt: map['lastLoginAt'] != null
          ? _parseDateTime(map['lastLoginAt'])
          : null,
      isActive: map['isActive'] ?? true,
      roles: List<String>.from(map['roles'] ?? const ['user']),
      companyId: map['companyId'],
      teamIds: List<String>.from(map['teamIds'] ?? const []),
    );
  }

  Map<String, dynamic> toJson() => _$AppUserToJson(this);
  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);

  AppUser copyWith({
    String? email,
    String? displayName,
    String? phone,
    String? companyName,
    String? companyAddress,
    String? taxId,
    String? subscriptionId,
    DateTime? lastLoginAt,
    bool? isActive,
    List<String>? roles,
    String? companyId,
    List<String>? teamIds,
  }) {
    return AppUser(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      companyName: companyName ?? this.companyName,
      companyAddress: companyAddress ?? this.companyAddress,
      taxId: taxId ?? this.taxId,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      roles: roles ?? this.roles,
      companyId: companyId ?? this.companyId,
      teamIds: teamIds ?? this.teamIds,
    );
  }

  // ===== GETTERS =====
  bool get isAdmin => roles.contains('admin') || roles.contains('super-admin');
  bool get hasActiveSubscription =>
      subscriptionId != null && subscriptionId!.isNotEmpty;
  bool get hasCompany => companyId != null && companyId!.isNotEmpty;

  String get displayNameOrDefault =>
      displayName.isNotEmpty ? displayName : 'Utilisateur';
  String get emailOrDefault => email.isNotEmpty ? email : 'Non renseigné';
  String get phoneOrDefault => phone?.isNotEmpty == true ? phone! : 'Non renseigné';
  String get companyNameOrDefault =>
      companyName?.isNotEmpty == true ? companyName! : 'Non renseignée';

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return DateTime.now();
  }
}