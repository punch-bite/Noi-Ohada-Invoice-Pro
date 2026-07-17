import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'team_permission.g.dart';

enum PermissionLevel { none, read, write, admin }

@JsonSerializable()
@HiveType(typeId: 21)
class TeamPermission {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String teamId;

  @HiveField(2)
  final String userId;

  @HiveField(3)
  final String resourceType; // 'invoice', 'client', 'product', 'all'

  @HiveField(4)
  final String permissionLevel; // 'none', 'read', 'write', 'admin'

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime? updatedAt;

  TeamPermission({
    String? id,
    required this.teamId,
    required this.userId,
    required this.resourceType,
    required this.permissionLevel,
    DateTime? createdAt,
    this.updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teamId': teamId,
      'userId': userId,
      'resourceType': resourceType,
      'permissionLevel': permissionLevel,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory TeamPermission.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return TeamPermission(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      teamId: map['teamId'] ?? '',
      userId: map['userId'] ?? '',
      resourceType: map['resourceType'] ?? 'all',
      permissionLevel: map['permissionLevel'] ?? 'none',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? _parseDateTime(map['updatedAt']) : null,
    );
  }

  PermissionLevel get permission => PermissionLevel.values.firstWhere(
        (e) => e.toString() == permissionLevel,
        orElse: () => PermissionLevel.none,
      );

  bool get canRead => permission == PermissionLevel.read || permission == PermissionLevel.write || permission == PermissionLevel.admin;
  bool get canWrite => permission == PermissionLevel.write || permission == PermissionLevel.admin;
  bool get isAdmin => permission == PermissionLevel.admin;

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}