// lib/models/supplier.dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'supplier.g.dart';

@HiveType(typeId: 6) // Assurez-vous que l'ID est unique
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
  final String taxId; // NUI / RCCM

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
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] ?? const Uuid().v4(),
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      taxId: map['taxId'] ?? '',
      contactPerson: map['contactPerson'] ?? '',
      notes: map['notes'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'])
          : null,
    );
  }

  Supplier copyWith({
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
      id: id,
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

  String get formattedPhone => phone.isNotEmpty ? phone : 'Non renseigné';
  String get formattedEmail => email.isNotEmpty ? email : 'Non renseigné';
}