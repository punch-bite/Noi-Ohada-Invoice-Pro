// lib/models/supplier.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'supplier.g.dart';

@JsonSerializable()
@HiveType(typeId: 14) // Assurez-vous que l'ID est unique
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

  // ===== SÉRIALISATION HIVE / FIRESTORE =====

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
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? _parseDateTime(map['updatedAt']) : null,
    );
  }

  /// Constructeur dédié pour Firestore (plus clair)
  factory Supplier.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Supplier.fromMap(data, documentId: doc.id);
  }

  // ===== JSON (pour sérialisation web / API) =====

  Map<String, dynamic> toJson() => _$SupplierToJson(this);

  factory Supplier.fromJson(Map<String, dynamic> json) => _$SupplierFromJson(json);

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

  // ===== GETTERS UTILITAIRES =====

  String get formattedPhone => phone.isNotEmpty ? phone : 'Non renseigné';
  String get formattedEmail => email.isNotEmpty ? email : 'Non renseigné';

  /// Vérifie si le fournisseur est valide (au minimum un nom)
  bool get isValid => name.isNotEmpty;

  // ===== FONCTIONS DE PARSING ROBUSTE =====

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return DateTime.now();
  }
}