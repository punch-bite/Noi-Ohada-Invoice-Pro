import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'client.g.dart';

@HiveType(typeId: 0)
class Client {
  @HiveField(0) final String id;
  @HiveField(1) final String userId;
  @HiveField(2) final String name;
  @HiveField(3) final String address;
  @HiveField(4) final String taxId;
  @HiveField(5) final String phone;
  @HiveField(6) final String email;
  @HiveField(7) final DateTime createdAt;
  @HiveField(8) final DateTime? updatedAt;
  @HiveField(9) final bool isActive;
  @HiveField(10) final bool isSynced;

  Client({
    String? id,
    required this.userId,
    required this.name,
    required this.address,
    required this.taxId,
    required this.phone,
    required this.email,
    DateTime? createdAt,
    this.updatedAt,
    this.isActive = true,
    this.isSynced = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'address': address,
      'taxId': taxId,
      'phone': phone,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'isSynced': isSynced,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Client(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      taxId: map['taxId'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      createdAt: map['createdAt'] != null ? _parseDateTime(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? _parseDateTime(map['updatedAt']) : null,
      isActive: map['isActive'] ?? true,
      isSynced: map['isSynced'] ?? false,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  Client copyWith({String? name, String? address, String? phone, String? email, bool? isActive, bool? isSynced, required String taxId}) {
    return Client(
      id: id,
      userId: userId,
      name: name ?? this.name,
      address: address ?? this.address,
      taxId: taxId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}