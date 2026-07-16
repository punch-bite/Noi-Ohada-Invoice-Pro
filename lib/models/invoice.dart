// lib/models/invoice.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import 'line_item.dart';

part 'invoice.g.dart';

@JsonSerializable()
@HiveType(typeId: 2)
class Invoice {
  @HiveField(0) final String id;
  @HiveField(1) final String companyId;
  @HiveField(2) final String clientId;
  @HiveField(3) final String invoiceNumber;
  @HiveField(4) final DateTime issueDate;
  @HiveField(5) final DateTime dueDate;
  @HiveField(6) final String status;
  @HiveField(7) final List<LineItem> items;
  @HiveField(8) final double subtotal;
  @HiveField(9) final double taxRate;
  @HiveField(10) final double taxAmount;
  @HiveField(11) final double discount;
  @HiveField(12) final double totalAmount;
  @HiveField(13) final String terms;
  @HiveField(14) final bool isDevis;
  @HiveField(15) final String notes;
  @HiveField(16) final DateTime? syncedAt;
  @HiveField(17) final DateTime updatedAt; // Champ critique pour la synchro

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
    this.syncedAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       updatedAt = updatedAt ?? DateTime.now();

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
      'syncedAt': syncedAt != null ? Timestamp.fromDate(syncedAt!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
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
      items: (map['items'] as List?)?.map((e) => LineItem.fromMap(Map<String, dynamic>.from(e))).toList() ?? [],
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxRate: (map['taxRate'] as num?)?.toDouble() ?? 18.0,
      taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      terms: map['terms'] ?? 'Paiement à 30 jours',
      isDevis: map['isDevis'] ?? false,
      notes: map['notes'] ?? '',
      syncedAt: map['syncedAt'] != null ? _parseDateTime(map['syncedAt']) : null,
      updatedAt: map['updatedAt'] != null ? _parseDateTime(map['updatedAt']) : DateTime.now(),
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
    // ... autres champs
  }) {
    return Invoice(
      id: id,
      companyId: companyId,
      clientId: clientId,
      invoiceNumber: invoiceNumber,
      issueDate: issueDate,
      dueDate: dueDate,
      status: status ?? this.status,
      items: items,
      subtotal: subtotal,
      taxRate: taxRate,
      taxAmount: taxAmount,
      discount: discount,
      totalAmount: totalAmount,
      terms: terms,
      isDevis: isDevis,
      notes: notes,
      syncedAt: syncedAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}