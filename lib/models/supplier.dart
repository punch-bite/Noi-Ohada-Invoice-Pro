// lib/models/supplier.dart
//
// CHANGELOG : ajout `companyId`, `sharedWithUsers`, `sharedTeams`,
//             `editableByUsers`, `editableTeams`.
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'supplier.g.dart';

@HiveType(typeId: 25)
class Supplier {
  @HiveField(0)  final String id;
  @HiveField(1)  final String userId;
  @HiveField(2)  final String name;
  @HiveField(3)  final String email;
  @HiveField(4)  final String phone;
  @HiveField(5)  final String address;
  @HiveField(6)  final String taxId;
  @HiveField(7)  final String contactPerson;
  @HiveField(8)  final String notes;
  @HiveField(9)  final bool isActive;
  @HiveField(10) final DateTime createdAt;
  @HiveField(11) final DateTime? updatedAt;
  @HiveField(12) final bool isSynced;

  // 🔑 NOUVEAU
  @HiveField(13) final String? companyId;
  @HiveField(14) final List<String> sharedWithUsers;
  @HiveField(15) final List<String> sharedTeams;
  @HiveField(16) final List<String> editableByUsers;
  @HiveField(17) final List<String> editableTeams;

  Supplier({
    String? id,
    required this.userId,
    required this.name,
    this.email = '',
    this.phone = '',
    this.address = '',
    this.taxId = '',
    this.contactPerson = '',
    this.notes = '',
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.companyId,
    this.sharedWithUsers = const [],
    this.sharedTeams = const [],
    this.editableByUsers = const [],
    this.editableTeams = const [],
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'companyId': companyId,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'taxId': taxId,
      'contactPerson': contactPerson,
      'notes': notes,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isSynced': isSynced,
      'sharedWithUsers': sharedWithUsers,
      'sharedTeams': sharedTeams,
      'editableByUsers': editableByUsers,
      'editableTeams': editableTeams,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Supplier(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      userId: map['userId'] ?? '',
      companyId: map['companyId'],
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      taxId: map['taxId'] ?? '',
      contactPerson: map['contactPerson'] ?? '',
      notes: map['notes'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null
          ? _parseDateTime(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? _parseDateTime(map['updatedAt'])
          : null,
      isSynced: map['isSynced'] ?? false,
      sharedWithUsers: List<String>.from(map['sharedWithUsers'] ?? const []),
      sharedTeams: List<String>.from(map['sharedTeams'] ?? const []),
      editableByUsers: List<String>.from(map['editableByUsers'] ?? const []),
      editableTeams: List<String>.from(map['editableTeams'] ?? const []),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  Supplier copyWith({
    String? name, String? email, String? phone, String? address,
    String? taxId, String? contactPerson, String? notes,
    bool? isActive, bool? isSynced, DateTime? updatedAt,
    String? companyId,
    List<String>? sharedWithUsers,
    List<String>? sharedTeams,
    List<String>? editableByUsers,
    List<String>? editableTeams,
  }) {
    return Supplier(
      id: id,
      userId: userId,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      taxId: taxId ?? this.taxId,
      contactPerson: contactPerson ?? this.contactPerson,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
      sharedWithUsers: sharedWithUsers ?? this.sharedWithUsers,
      sharedTeams: sharedTeams ?? this.sharedTeams,
      editableByUsers: editableByUsers ?? this.editableByUsers,
      editableTeams: editableTeams ?? this.editableTeams,
    );
  }
}