import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'team.g.dart';

@JsonSerializable()
@HiveType(typeId: 20)
class Team {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String ownerId; // ID du créateur

  @HiveField(4)
  final List<String> memberIds;

  @HiveField(5)
  final List<String> adminIds;

  @HiveField(6)
  final String? logoPath;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime? updatedAt;

  @HiveField(9)
  final bool isActive;

  Team({
    String? id,
    required this.name,
    this.description = '',
    required this.ownerId,
    this.memberIds = const [],
    this.adminIds = const [],
    this.logoPath,
    DateTime? createdAt,
    this.updatedAt,
    this.isActive = true,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'adminIds': adminIds,
      'logoPath': logoPath,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
    };
  }

  factory Team.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Team(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      ownerId: map['ownerId'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      adminIds: List<String>.from(map['adminIds'] ?? []),
      logoPath: map['logoPath'],
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? _parseDateTime(map['updatedAt']) : null,
      isActive: map['isActive'] ?? true,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  bool get isOwner => false; // Remplacé par une méthode avec userId

  bool isOwnerOf(String userId) => ownerId == userId;
  bool isAdmin(String userId) => adminIds.contains(userId);
  bool isMember(String userId) => memberIds.contains(userId) || isAdmin(userId) || isOwnerOf(userId);

  Team copyWith({
    String? name,
    String? description,
    List<String>? memberIds,
    List<String>? adminIds,
    String? logoPath,
    bool? isActive,
  }) {
    return Team(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId,
      memberIds: memberIds ?? this.memberIds,
      adminIds: adminIds ?? this.adminIds,
      logoPath: logoPath ?? this.logoPath,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive ?? this.isActive,
    );
  }
}