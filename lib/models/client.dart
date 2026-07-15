// lib/models/client.dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'client.g.dart';

@HiveType(typeId: 1)
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
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] ?? const Uuid().v4(),
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      taxId: map['taxId'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      createdAt: map['createdAt'] ?? DateTime.now(),
      updatedAt: map['updatedAt'],
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
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
