import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'shared_invoice.g.dart';
@HiveType(typeId: 23)
class SharedInvoice {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String invoiceId; // id de la ressource partagée (facture, produit, client)

  @HiveField(2)
  final String teamId;

  @HiveField(3)
  final String sharedBy;

  @HiveField(4)
  final List<String> sharedWith; // User IDs (@mentions)

  @HiveField(5)
  final DateTime sharedAt;

  @HiveField(6)
  final String permissionLevel; // 'read' ou 'write'

  @HiveField(7)
  final DateTime? expiresAt;

  @HiveField(8)
  final bool isActive;

  // Champs NON Hive (persistés uniquement en Firestore) : type de ressource
  // partagée ('invoice' | 'product' | 'client') et nom lisible.
  final String resourceType;
  final String resourceName;

  /// 🔑 Membres disposant du droit d'ÉCRITURE sur ce partage (sous-ensemble de
  /// [sharedWith]). Rempli à l'adhésion d'un membre dont le rôle autorise
  /// l'écriture (cf. Team.memberPermission / Team.adminPermission).
  final List<String> writeUsers;

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
    this.resourceType = 'invoice',
    this.resourceName = '',
    this.writeUsers = const [],
  })  : id = id ?? const Uuid().v4();

  /// Vrai si [userId] peut MODIFIER la ressource partagée.
  /// • partage globalement en écriture (`permissionLevel == 'write'`), ou
  /// • membre explicitement listé dans [writeUsers] (rôle autorisant l'écriture).
  bool canWrite(String userId) =>
      permissionLevel == 'write' || writeUsers.contains(userId);

  /// Vrai si [userId] a au moins la LECTURE (destinataire du partage).
  bool canRead(String userId) => sharedWith.contains(userId);

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
      'resourceType': resourceType,
      'resourceName': resourceName,
      'writeUsers': writeUsers,
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
      resourceType: map['resourceType'] ?? 'invoice',
      resourceName: map['resourceName'] ?? '',
      writeUsers: List<String>.from(map['writeUsers'] ?? const []),
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