import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'shared_invoice.g.dart';
@JsonSerializable()
@HiveType(typeId: 23)
class SharedInvoice {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String invoiceId;

  @HiveField(2)
  final String teamId;

  @HiveField(3)
  final String sharedBy;

  @HiveField(4)
  final List<String> sharedWith; // User IDs

  @HiveField(5)
  final DateTime sharedAt;

  @HiveField(6)
  final String permissionLevel; // 'read' ou 'write'

  @HiveField(7)
  final DateTime? expiresAt;

  @HiveField(8)
  final bool isActive;

  SharedInvoice({
    String? id,
    required this.invoiceId,
    required this.teamId,
    required this.sharedBy,
    required this.sharedWith,
    required this.permissionLevel,
    required this.sharedAt,
    this.expiresAt,
    this.isActive = true,
  })  : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'teamId': teamId,
      'sharedBy': sharedBy,
      'sharedWith': sharedWith,
      'sharedAt': Timestamp.fromDate(sharedAt),
      'permissionLevel': permissionLevel,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isActive': isActive,
    };
  }

  factory SharedInvoice.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return SharedInvoice(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      invoiceId: map['invoiceId'] ?? '',
      teamId: map['teamId'] ?? '',
      sharedBy: map['sharedBy'] ?? '',
      sharedWith: List<String>.from(map['sharedWith'] ?? []),
      permissionLevel: map['permissionLevel'] ?? 'read',
      sharedAt: _parseDateTime(map['sharedAt']),
      expiresAt: map['expiresAt'] != null ? _parseDateTime(map['expiresAt']) : null,
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
}