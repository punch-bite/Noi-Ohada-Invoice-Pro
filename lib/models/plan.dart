// lib/models/plan.dart
import 'package:hive/hive.dart';

part 'plan.g.dart';

@HiveType(typeId: 10)
class Plan {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final double price;

  @HiveField(4)
  final String currency;

  @HiveField(5)
  final String interval;

  @HiveField(6)
  final int maxInvoices;

  @HiveField(7)
  final int maxClients;

  @HiveField(8)
  final bool hasPdfExport;

  @HiveField(9)
  final bool hasCloudSync;

  @HiveField(10)
  final bool hasTeamAccess;

  @HiveField(11)
  final int maxProducts;

  @HiveField(12)
  final List<String> features;

  @HiveField(13)
  final bool isPopular;

  @HiveField(14)
  final bool isActive;

  @HiveField(15)
  final int maxTeamMembers;

  @HiveField(16)
  final bool hasGoogleDriveSync;

  @HiveField(17)
  final bool hasClientRelance;

  Plan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.interval,
    this.maxInvoices = -1,
    this.maxClients = -1,
    this.maxProducts = -1,
    this.hasPdfExport = true,
    this.hasCloudSync = true,
    this.hasTeamAccess = false,
    this.maxTeamMembers = 0,
    this.hasGoogleDriveSync = false,
    this.hasClientRelance = false,
    this.features = const [],
    this.isPopular = false,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'interval': interval,
      'maxInvoices': maxInvoices,
      'maxClients': maxClients,
      'maxProducts': maxProducts,
      'hasPdfExport': hasPdfExport,
      'hasCloudSync': hasCloudSync,
      'hasTeamAccess': hasTeamAccess,
      'maxTeamMembers': maxTeamMembers,
      'hasGoogleDriveSync': hasGoogleDriveSync,
      'hasClientRelance': hasClientRelance,
      'features': features,
      'isPopular': isPopular,
      'isActive': isActive,
    };
  }

  factory Plan.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Plan(
      id: documentId ?? map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'XAF',
      interval: map['interval'] ?? 'month',
      maxInvoices: (map['maxInvoices'] as num?)?.toInt() ?? -1,
      maxClients: (map['maxClients'] as num?)?.toInt() ?? -1,
      maxProducts: (map['maxProducts'] as num?)?.toInt() ?? -1,
      hasPdfExport: map['hasPdfExport'] ?? true,
      hasCloudSync: map['hasCloudSync'] ?? true,
      hasTeamAccess: map['hasTeamAccess'] ?? false,
      maxTeamMembers: (map['maxTeamMembers'] as num?)?.toInt() ?? 0,
      hasGoogleDriveSync: map['hasGoogleDriveSync'] ?? false,
      hasClientRelance: map['hasClientRelance'] ?? false,
      features: List<String>.from(map['features'] ?? []),
      isPopular: map['isPopular'] ?? false,
      isActive: map['isActive'] ?? true,
    );
  }

  Plan copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? currency,
    String? interval,
    int? maxInvoices,
    int? maxClients,
    int? maxProducts,
    bool? hasPdfExport,
    bool? hasCloudSync,
    bool? hasTeamAccess,
    int? maxTeamMembers,
    bool? hasGoogleDriveSync,
    bool? hasClientRelance,
    List<String>? features,
    bool? isPopular,
    bool? isActive,
  }) {
    return Plan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      interval: interval ?? this.interval,
      maxInvoices: maxInvoices ?? this.maxInvoices,
      maxClients: maxClients ?? this.maxClients,
      maxProducts: maxProducts ?? this.maxProducts,
      hasPdfExport: hasPdfExport ?? this.hasPdfExport,
      hasCloudSync: hasCloudSync ?? this.hasCloudSync,
      hasTeamAccess: hasTeamAccess ?? this.hasTeamAccess,
      maxTeamMembers: maxTeamMembers ?? this.maxTeamMembers,
      hasGoogleDriveSync: hasGoogleDriveSync ?? this.hasGoogleDriveSync,
      hasClientRelance: hasClientRelance ?? this.hasClientRelance,
      features: features ?? this.features,
      isPopular: isPopular ?? this.isPopular,
      isActive: isActive ?? this.isActive,
    );
  }

  String getFormattedPrice() {
    if (price == 0) return 'Gratuit';
    final priceStr = price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
    return '$priceStr $currency';
  }

  bool get isFree => price == 0;
  bool get hasInvoiceLimit => maxInvoices > 0;
  bool get hasClientLimit => maxClients > 0;
  bool get hasProductLimit => maxProducts > 0;

  bool isUnlimitedInvoices() => maxInvoices <= 0;
  bool isUnlimitedClients() => maxClients <= 0;
  bool isUnlimitedProducts() => maxProducts <= 0;

  static Plan getFreePlan() {
    return Plan(
      id: 'free',
      name: 'Gratuit',
      description: 'Pour démarrer avec OHADA Invoice Pro',
      price: 0.0,
      currency: 'XAF',
      interval: 'month',
      maxInvoices: 5,
      maxClients: 5,
      maxProducts: 3,
      hasPdfExport: true,
      hasCloudSync: false,
      hasTeamAccess: false,
      maxTeamMembers: 0,
      hasGoogleDriveSync: false,
      features: [
        '5 factures',
        '5 clients',
        '3 produits',
        'Export PDF',
        'Stockage Firestore',
      ],
      isPopular: false,
      isActive: true,
    );
  }

  static Plan getProPlan() {
    return Plan(
      id: 'pro',
      name: 'Pro',
      description: 'Pour les PME en croissance',
      price: 9900.0,
      currency: 'XAF',
      interval: 'month',
      maxInvoices: -1,
      maxClients: 200,
      maxProducts: 25,
      hasPdfExport: true,
      hasCloudSync: true,
      hasTeamAccess: false,
      maxTeamMembers: 0,
      hasGoogleDriveSync: false,
      hasClientRelance: true,
      features: [
        'Factures illimitées',
        '200 clients',
        '25 produits',
        'Export PDF illimité',
        'Synchronisation cloud',
        'Relance clients (email / WhatsApp / SMS)',
        'Support prioritaire',
      ],
      isPopular: true,
    );
  }

  static Plan getBusinessPlan() {
    return Plan(
      id: 'business',
      name: 'Business',
      description: 'Pour les entreprises et équipes',
      price: 49000.0,
      currency: 'XAF',
      interval: 'year',
      maxInvoices: -1,
      maxClients: -1,
      maxProducts: -1,
      hasPdfExport: true,
      hasCloudSync: true,
      hasTeamAccess: true,
      maxTeamMembers: 20,
      hasGoogleDriveSync: true,
      hasClientRelance: true,
      features: [
        'Tout le plan Pro',
        'Clients / produits / factures illimités',
        'Module équipe (20 utilisateurs)',
        'Invitation par lien e-mail',
        'Synchronisation Google Drive',
        'Relance clients (email / WhatsApp / SMS)',
        'Support dédié 24/7',
      ],
    );
  }

  static List<Plan> getDefaultPlans() {
    return [getFreePlan(), getProPlan(), getBusinessPlan()];
  }
}
