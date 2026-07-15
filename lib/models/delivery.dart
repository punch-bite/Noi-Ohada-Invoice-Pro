// lib/models/delivery.dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'delivery.g.dart';

enum DeliveryType { 
  incoming, // Réception de stock
  outgoing, // Livraison / Sortie de stock
  adjustment, out // Ajustement
}

enum DeliveryStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

@HiveType(typeId: 5)
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
  final String type; // DeliveryType en string
  
  @HiveField(5)
  final String status; // DeliveryStatus en string
  
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

  DeliveryType get deliveryType {
    return DeliveryType.values.firstWhere(
      (e) => e.toString() == type,
      orElse: () => DeliveryType.incoming,
    );
  }

  DeliveryStatus get deliveryStatus {
    return DeliveryStatus.values.firstWhere(
      (e) => e.toString() == status,
      orElse: () => DeliveryStatus.pending,
    );
  }

  bool get isIncoming => deliveryType == DeliveryType.incoming;
  bool get isOutgoing => deliveryType == DeliveryType.outgoing;
  bool get isCompleted => deliveryStatus == DeliveryStatus.completed;
  bool get isPending => deliveryStatus == DeliveryStatus.pending;

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
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  factory Delivery.fromMap(Map<String, dynamic> map) {
    return Delivery(
      id: map['id'] ?? const Uuid().v4(),
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
      type: map['type'] ?? DeliveryType.incoming.toString(),
      status: map['status'] ?? DeliveryStatus.pending.toString(),
      reference: map['reference'],
      clientName: map['clientName'],
      notes: map['notes'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      completedAt: map['completedAt'] != null 
          ? DateTime.tryParse(map['completedAt']) 
          : null,
      createdBy: map['createdBy'],
    );
  }

  Delivery copyWith({
    int? quantity,
    String? status,
    String? notes,
    DateTime? completedAt,
  }) {
    return Delivery(
      id: id,
      productId: productId,
      productName: productName,
      quantity: quantity ?? this.quantity,
      type: type,
      status: status ?? this.status,
      reference: reference,
      clientName: clientName,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      createdBy: createdBy,
    );
  }
}