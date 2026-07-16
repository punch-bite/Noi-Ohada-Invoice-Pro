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
      updatedAt: updatedAt ?? DateTime.now(), // Met à jour automatiquement la date de modification
    );
  }

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