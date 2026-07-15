// lib/models/invoice.dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'line_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'invoice.g.dart'; // Pour Hive

@HiveType(typeId: 0)
class Invoice {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String companyId;
  
  @HiveField(2)
  final String clientId;
  
  @HiveField(3)
  final String invoiceNumber;
  
  @HiveField(4)
  final DateTime issueDate;
  
  @HiveField(5)
  final DateTime dueDate;
  
  @HiveField(6)
  final String status; // draft, sent, paid, overdue
  
  @HiveField(7)
  final List<LineItem> items;
  
  @HiveField(8)
  final double subtotal;
  
  @HiveField(9)
  final double taxRate;
  
  @HiveField(10)
  final double taxAmount;
  
  @HiveField(11)
  final double discount; // Réduction en montant
   
  @HiveField(12)
  final double totalAmount;
  
  @HiveField(13)
  final String terms;
  
  @HiveField(14)
  final bool isDevis;
  
  @HiveField(15)
  final String notes;
  
  @HiveField(16)
  final DateTime? syncedAt;

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
    this.discount = 0,
    required this.totalAmount,
    this.terms = 'Paiement à 30 jours',
    this.isDevis = false,
    this.notes = '',
    this.syncedAt,
  }) : id = id ?? const Uuid().v4();

  // Factory pour créer depuis Firestore
  factory Invoice.fromFirestore(Map<String, dynamic> data) {
    return Invoice(
      id: data['id'] ?? const Uuid().v4(),
      companyId: data['companyId'] ?? '',
      clientId: data['clientId'] ?? '',
      invoiceNumber: data['invoiceNumber'] ?? '',
      issueDate: (data['issueDate'] as Timestamp).toDate(),
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'draft',
      items: (data['items'] as List)
          .map((e) => LineItem.fromMap(e))
          .toList(),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      taxRate: (data['taxRate'] as num?)?.toDouble() ?? 18,
      taxAmount: (data['taxAmount'] as num?)?.toDouble() ?? 0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      terms: data['terms'] ?? 'Paiement à 30 jours',
      isDevis: data['isDevis'] ?? false,
      notes: data['notes'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
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
      'syncedAt': Timestamp.now(),
    };
  }

  Invoice copyWith({
    String? id,
    String? companyId,
    String? clientId,
    String? invoiceNumber,
    DateTime? issueDate,
    DateTime? dueDate,
    String? status,
    List<LineItem>? items,
    double? subtotal,
    double? taxRate,
    double? taxAmount,
    double? discount,
    double? totalAmount,
    String? terms,
    bool? isDevis,
    String? notes,
    DateTime? syncedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      clientId: clientId ?? this.clientId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      discount: discount ?? this.discount,
      totalAmount: totalAmount ?? this.totalAmount,
      terms: terms ?? this.terms,
      isDevis: isDevis ?? this.isDevis,
      notes: notes ?? this.notes,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
