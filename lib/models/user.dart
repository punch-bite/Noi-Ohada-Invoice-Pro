// lib/models/user.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart'; // Généré par Hive

@JsonSerializable()
@HiveType(typeId: 15) // Attribué à 9 pour suivre notre registre de modèles (Supplier: 8)
class AppUser {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String email;

  @HiveField(2)
  final String displayName;

  @HiveField(3)
  final String? phone;

  @HiveField(4)
  final String? companyName;

  @HiveField(5)
  final String? companyAddress;

  @HiveField(6)
  final String? taxId; // NUI / RCCM de l'entreprise de l'utilisateur

  @HiveField(7)
  final String? subscriptionId;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final DateTime? lastLoginAt;

  @HiveField(10)
  final bool isActive;

  @HiveField(11)
  final List<String> roles; // ['user', 'admin']

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
  });

  // ===== SÉRIALISATION COMPATIBLE HIVE & FIRESTORE =====

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'phone': phone,
      'companyName': companyName,
      'companyAddress': companyAddress,
      'taxId': taxId,
      'subscriptionId': subscriptionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'isActive': isActive,
      'roles': roles,
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
      createdAt: map['createdAt'] != null ? _parseDateTime(map['createdAt']) : DateTime.now(),
      lastLoginAt: map['lastLoginAt'] != null ? _parseDateTime(map['lastLoginAt']) : null,
      isActive: map['isActive'] ?? true,
      roles: List<String>.from(map['roles'] ?? ['user']),
    );
  }

  // ===== CLONAGE (copyWith) =====

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
    );
  }

  // ===== GETTERS APPLICATIFS =====

  bool get isAdmin => roles.contains('admin');
  bool get hasActiveSubscription => subscriptionId != null && subscriptionId!.isNotEmpty;

  /// Fonction d'aide pour parser les dates de manière ultra-robuste (Firestore, Hive et JSON)
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