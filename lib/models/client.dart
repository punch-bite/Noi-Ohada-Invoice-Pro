// lib/models/client.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'client.g.dart';

@JsonSerializable()
@HiveType(typeId: 0)
class Client {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String address;
  
  @HiveField(3)
  final String taxId; // NUI / RCCM
  
  @HiveField(4)
  final String phone;
  
  @HiveField(5)
  final String email;
  
  @HiveField(6)
  final DateTime createdAt;
  
  @HiveField(7)
  final DateTime? updatedAt;

  Client({
    String? id,
    required this.name,
    required this.address,
    required this.taxId,
    required this.phone,
    required this.email,
    DateTime? createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  // ===== SÉRIALISATION =====

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'taxId': taxId,
      'phone': phone,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Client(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      taxId: map['taxId'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? _parseDateTime(map['updatedAt']) : null,
    );
  }

  /// Constructeur dédié pour Firestore (plus clair)
  factory Client.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Client.fromMap(data, documentId: doc.id);
  }

  // ===== JSON (pour API) =====

  Map<String, dynamic> toJson() => _$ClientToJson(this);

  factory Client.fromJson(Map<String, dynamic> json) => _$ClientFromJson(json);

  // ===== COPY =====

  Client copyWith({
    String? name,
    String? address,
    String? taxId,
    String? phone,
    String? email,
    DateTime? updatedAt,
  }) {
    return Client(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      taxId: taxId ?? this.taxId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // ===== GETTERS UTILITAIRES =====

  String get formattedPhone => phone.isNotEmpty ? phone : 'Non renseigné';
  String get formattedEmail => email.isNotEmpty ? email : 'Non renseigné';
  String get formattedTaxId => taxId.isNotEmpty ? taxId : 'Non renseigné';

  /// Vérifie si le client est valide (nom non vide)
  bool get isValid => name.isNotEmpty;

  /// Date de création formatée
  String get formattedCreatedAt => 
      '${createdAt.day}/${createdAt.month}/${createdAt.year}';

  /// Date de mise à jour formatée (si disponible)
  String get formattedUpdatedAt => 
      updatedAt != null ? '${updatedAt!.day}/${updatedAt!.month}/${updatedAt!.year}' : 'Jamais';

  /// Nom complet (alias pour affichage)
  String get displayName => name;

  // ===== VALIDATION =====

  /// Vérifie si le client a toutes les informations minimales
  bool get hasRequiredInfo => 
      name.isNotEmpty && 
      (phone.isNotEmpty || email.isNotEmpty);

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