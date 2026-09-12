import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'team.g.dart';

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

  /// 🔑 POLITIQUE D'ACCÈS AUX FICHIERS PARTAGÉS, PAR RÔLE.
  /// - [memberPermission] : droit accordé aux MEMBRES simples
  ///   (`'read'` = lecture seule, `'write'` = lecture/écriture).
  /// - [adminPermission] : droit accordé aux ADMINISTRATEURS (et au
  ///   propriétaire) — par défaut `'write'`.
  /// Tout membre qui ADHÈRE à l'équipe reçoit ces droits sur les ressources
  /// déjà partagées (factures / produits / clients).
  @HiveField(10)
  final String memberPermission;
  @HiveField(11)
  final String adminPermission;

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
    this.memberPermission = 'read',
    this.adminPermission = 'write',
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
      'memberPermission': memberPermission,
      'adminPermission': adminPermission,
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
      updatedAt:
          map['updatedAt'] != null ? _parseDateTime(map['updatedAt']) : null,
      isActive: map['isActive'] ?? true,
      memberPermission:
          normalizePermission(map['memberPermission'], fallback: 'read'),
      adminPermission:
          normalizePermission(map['adminPermission'], fallback: 'write'),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  bool isOwnerOf(String userId) => ownerId == userId;
  bool isAdmin(String userId) => adminIds.contains(userId);
  bool isMember(String userId) =>
      memberIds.contains(userId) || isAdmin(userId) || isOwnerOf(userId);

  // 👑 TITRES DE RÔLE affichés dans la messagerie d'équipe.
  static const String ownerTitle = 'Propriétaire du groupe';
  static const String memberTitle = 'Membre';

  /// 👑 Titre de [userId] : « Propriétaire du groupe » pour le propriétaire
  /// et les administrateurs de l'équipe, « Membre » pour les autres.
  /// Un utilisateur inconnu (hors équipe) est considéré comme simple membre.
  String roleTitleFor(String userId) =>
      isOwnerOf(userId) || isAdmin(userId) ? ownerTitle : memberTitle;

  /// Normalise une valeur de permission ('read' | 'write').
  static String normalizePermission(String? value, {String fallback = 'read'}) {
    final v = (value ?? '').trim().toLowerCase();
    if (v == 'write' || v == 'read') return v;
    return fallback;
  }

  /// 🔑 Droit d'accès de [userId] aux FICHIERS PARTAGÉS de l'équipe,
  /// déduit de son RÔLE (propriétaire/admin → [adminPermission],
  /// membre simple → [memberPermission]).
  String permissionFor(String userId) {
    if (isOwnerOf(userId) || isAdmin(userId)) return adminPermission;
    return memberPermission;
  }

  /// Vrai si [userId] peut MODIFIER les fichiers partagés de l'équipe.
  bool canWriteShared(String userId) => permissionFor(userId) == 'write';

  /// Vrai si [userId] peut au moins LIRE les fichiers partagés de l'équipe.
  /// Les membres y ont toujours accès en lecture (le partage est explicite).
  bool canReadShared(String userId) =>
      isMember(userId) || memberPermission == 'read';

  Team copyWith({
    String? name,
    String? description,
    List<String>? memberIds,
    List<String>? adminIds,
    String? logoPath,
    bool? isActive,
    String? memberPermission,
    String? adminPermission,
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
      memberPermission: normalizePermission(memberPermission,
          fallback: this.memberPermission),
      adminPermission:
          normalizePermission(adminPermission, fallback: this.adminPermission),
    );
  }
}
