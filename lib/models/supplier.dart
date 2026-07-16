// lib/models/supplier.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'supplier.g.dart';

@JsonSerializable()
@HiveType(typeId: 8) // Modifié à 8 pour éviter la collision avec Reminder (typeId: 6) et Subscription (typeId: 7)
class Supplier {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String email;

  @HiveField(3)
  final String phone;

  @HiveField(4)
  final String address;

  @HiveField(5)
  final String taxId; // NUI / RCCM (Normes fiscales locales)

  @HiveField(6)
  final String contactPerson;

  @HiveField(7)
  final String notes;

  @HiveField(8)
  final bool isActive;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final DateTime? updatedAt;

  Supplier({
    String? id,
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
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  // ===== SÉRIALISATION COMPATIBLE HIVE & FIRESTORE =====

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Supplier(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      taxId: map['taxId'] ?? '',
      contactPerson: map['contactPerson'] ?? '',
      notes: map['notes'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null ? _parseDateTime(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? _parseDateTime(map['updatedAt']) : null,
    );
  }

  // ===== CLONAGE (copyWith) =====

  Supplier copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? taxId,
    String? contactPerson,
    String? notes,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
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
    );
  }

  // ===== GETTERS D'INTERFACE =====

  String get formattedPhone => phone.isNotEmpty ? phone : 'Non renseigné';
  String get formattedEmail => email.isNotEmpty ? email : 'Non renseigné';

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