// lib/models/user.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String? phone;
  final String? companyName;
  final String? companyAddress;
  final String? taxId;
  final String? subscriptionId;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;
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
      'createdAt': createdAt,
      'lastLoginAt': lastLoginAt,
      'isActive': isActive,
      'roles': roles,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      phone: map['phone'],
      companyName: map['companyName'],
      companyAddress: map['companyAddress'],
      taxId: map['taxId'],
      subscriptionId: map['subscriptionId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (map['lastLoginAt'] as Timestamp?)?.toDate(),
      isActive: map['isActive'] ?? true,
      roles: List<String>.from(map['roles'] ?? ['user']),
    );
  }

  AppUser copyWith({
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
      email: email,
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

  bool get isAdmin => roles.contains('admin');
  bool get hasActiveSubscription => subscriptionId != null && subscriptionId!.isNotEmpty;
}