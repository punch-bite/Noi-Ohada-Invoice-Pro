// lib/models/invoice.dart
//
// CHANGELOG :
//   • Ajout `companyId` (rattachement SaaS — pilote la numérotation par
//     entreprise, plus par utilisateur → plus de doublons).
//   • Ajout `sharedWithUsers`, `sharedTeams`, `editableByUsers`,
//     `editableTeams` (mêmes champs que les autres ressources partageables).
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'line_item.dart';

part 'invoice.g.dart';

@HiveType(typeId: 7)
class Invoice {
  @HiveField(0)  final String id;
  @HiveField(1)  final String companyId;
  @HiveField(2)  final String clientId;
  @HiveField(3)  final String invoiceNumber;
  @HiveField(4)  final DateTime issueDate;
  @HiveField(5)  final DateTime dueDate;
  @HiveField(6)  final String status;
  @HiveField(7)  final List<LineItem> items;
  @HiveField(8)  final double subtotal;
  @HiveField(9)  final double taxRate;
  @HiveField(10) final double taxAmount;
  @HiveField(11) final double discount;
  @HiveField(12) final double totalAmount;
  @HiveField(13) final String terms;
  @HiveField(14) final bool isDevis;
  @HiveField(15) final String notes;
  @HiveField(16) final String? userId;
  @HiveField(17) final bool isSynced;
  @HiveField(18) final DateTime? syncedAt;
  @HiveField(19) final DateTime updatedAt;
  @HiveField(20) final DateTime createdAt;
  @HiveField(21) final String? templateId;

  // 🔑 NOUVEAU — partages SaaS
  @HiveField(22) final List<String> sharedWithUsers;
  @HiveField(23) final List<String> sharedTeams;
  @HiveField(24) final List<String> editableByUsers;
  @HiveField(25) final List<String> editableTeams;

  Invoice({
    String? id,
    required this.companyId,
    required this.clientId,
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    this.status = 'draft',
    required this.items,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    this.discount = 0.0,
    required this.totalAmount,
    this.terms = 'Paiement à 30 jours',
    this.isDevis = false,
    this.notes = '',
    this.userId,
    this.syncedAt,
    this.isSynced = false,
    this.templateId,
    DateTime? updatedAt,
    DateTime? createdAt,
    this.sharedWithUsers = const [],
    this.sharedTeams = const [],
    this.editableByUsers = const [],
    this.editableTeams = const [],
  })  : id = id ?? const Uuid().v4(),
        updatedAt = updatedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'clientId': clientId,
      'invoiceNumber': invoiceNumber,
      'issueDate': Timestamp.fromDate(issueDate),
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'discount': discount,
      'totalAmount': totalAmount,
      'terms': terms,
      'isDevis': isDevis,
      'notes': notes,
      'userId': userId ?? '',
      'isSynced': isSynced,
      'syncedAt': syncedAt != null ? Timestamp.fromDate(syncedAt!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'templateId': templateId,
      'sharedWithUsers': sharedWithUsers,
      'sharedTeams': sharedTeams,
      'editableByUsers': editableByUsers,
      'editableTeams': editableTeams,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Invoice(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      companyId: map['companyId'] ?? '',
      clientId: map['clientId'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      issueDate: _parseDateTime(map['issueDate']),
      dueDate: _parseDateTime(map['dueDate']),
      status: map['status'] ?? 'draft',
      items: (map['items'] as List?)
              ?.map((e) =>
                  LineItem.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxRate: (map['taxRate'] as num?)?.toDouble() ?? 18.0,
      taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      terms: map['terms'] ?? 'Paiement à 30 jours',
      isDevis: map['isDevis'] ?? false,
      notes: map['notes'] ?? '',
      userId: map['userId'],
      syncedAt: map['syncedAt'] != null
          ? _parseDateTime(map['syncedAt'])
          : null,
      updatedAt: map['updatedAt'] != null
          ? _parseDateTime(map['updatedAt'])
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? _parseDateTime(map['createdAt'])
          : DateTime.now(),
      isSynced: map['isSynced'] ?? false,
      templateId: map['templateId'],
      sharedWithUsers: List<String>.from(map['sharedWithUsers'] ?? const []),
      sharedTeams: List<String>.from(map['sharedTeams'] ?? const []),
      editableByUsers: List<String>.from(map['editableByUsers'] ?? const []),
      editableTeams: List<String>.from(map['editableTeams'] ?? const []),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return DateTime.now();
  }

  Invoice copyWith({
    String? status,
    DateTime? updatedAt,
    bool? isSynced,
    DateTime? syncedAt,
    DateTime? dueDate,
    String? notes,
    String? userId,
    String? templateId,
    String? companyId,
    List<String>? sharedWithUsers,
    List<String>? sharedTeams,
    List<String>? editableByUsers,
    List<String>? editableTeams,
  }) {
    return Invoice(
      id: id,
      companyId: companyId ?? this.companyId,
      clientId: clientId,
      invoiceNumber: invoiceNumber,
      issueDate: issueDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      items: items,
      subtotal: subtotal,
      taxRate: taxRate,
      taxAmount: taxAmount,
      discount: discount,
      totalAmount: totalAmount,
      terms: terms,
      isDevis: isDevis,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
      syncedAt: syncedAt ?? this.syncedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt,
      isSynced: isSynced ?? this.isSynced,
      templateId: templateId ?? this.templateId,
      sharedWithUsers: sharedWithUsers ?? this.sharedWithUsers,
      sharedTeams: sharedTeams ?? this.sharedTeams,
      editableByUsers: editableByUsers ?? this.editableByUsers,
      editableTeams: editableTeams ?? this.editableTeams,
    );
  }
}