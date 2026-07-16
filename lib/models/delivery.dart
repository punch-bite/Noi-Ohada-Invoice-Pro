// lib/models/delivery.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'delivery.g.dart';

enum DeliveryType { 
  incoming,   // Réception de stock / Approvisionnement
  outgoing,   // Livraison / Sortie de stock client
  adjustment, // Ajustement inventaire / Correction manuelle
  loss, out,       // Perte / Casse / Vol
}

enum DeliveryStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

@JsonSerializable()
@HiveType(typeId: 3)
class Delivery {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String productId;
  
  @HiveField(2)
  final String productName;
  
  @HiveField(3)
  final int quantity;
  
  @HiveField(4)
  final String type; // DeliveryType en String simple (ex: 'incoming')
  
  @HiveField(5)
  final String status; // DeliveryStatus en String simple (ex: 'pending')
  
  @HiveField(6)
  final String? reference; // N° de commande, facture, etc.
  
  @HiveField(7)
  final String? clientName;
  
  @HiveField(8)
  final String? notes;
  
  @HiveField(9)
  final DateTime createdAt;
  
  @HiveField(10)
  final DateTime? completedAt;
  
  @HiveField(11)
  final String? createdBy;

  Delivery({
    String? id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.type,
    this.status = 'pending',
    this.reference,
    this.clientName,
    this.notes,
    DateTime? createdAt,
    this.completedAt,
    this.createdBy,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// Parse le type de flux vers l'enum [DeliveryType]
  DeliveryType get deliveryType {
    return DeliveryType.values.firstWhere(
      (e) => e.name == type || e.toString() == type,
      orElse: () => DeliveryType.incoming,
    );
  }

  /// Parse le statut vers l'enum [DeliveryStatus]
  DeliveryStatus get deliveryStatus {
    return DeliveryStatus.values.firstWhere(
      (e) => e.name == status || e.toString() == status,
      orElse: () => DeliveryStatus.pending,
    );
  }

  bool get isIncoming => deliveryType == DeliveryType.incoming;
  bool get isOutgoing => deliveryType == DeliveryType.outgoing;
  bool get isAdjustment => deliveryType == DeliveryType.adjustment;
  bool get isLoss => deliveryType == DeliveryType.loss;
  
  bool get isCompleted => deliveryStatus == DeliveryStatus.completed;
  bool get isPending => deliveryStatus == DeliveryStatus.pending;
  bool get isInProgress => deliveryStatus == DeliveryStatus.inProgress;
  bool get isCancelled => deliveryStatus == DeliveryStatus.cancelled;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'type': type,
      'status': status,
      'reference': reference,
      'clientName': clientName,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdBy': createdBy,
    };
  }

  factory Delivery.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Delivery(
      id: documentId ?? map['id'] ?? const Uuid().v4(),
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      type: map['type'] ?? DeliveryType.incoming.name,
      status: map['status'] ?? DeliveryStatus.pending.name,
      reference: map['reference'],
      clientName: map['clientName'],
      notes: map['notes'],
      createdAt: _parseDateTime(map['createdAt']),
      completedAt: map['completedAt'] != null ? _parseDateTime(map['completedAt']) : null,
      createdBy: map['createdBy'],
    );
  }

  Delivery copyWith({
    int? quantity,
    String? status,
    String? notes,
    DateTime? completedAt,
    String? reference,
    String? clientName,
    String? createdBy,
  }) {
    return Delivery(
      id: id,
      productId: productId,
      productName: productName,
      quantity: quantity ?? this.quantity,
      type: type,
      status: status ?? this.status,
      reference: reference ?? this.reference,
      clientName: clientName ?? this.clientName,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Fonction d'aide pour parser les dates de manière ultra-robuste
  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }
}