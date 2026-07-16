// lib/models/plan.dart
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'plan.g.dart';

@JsonSerializable()
@HiveType(typeId: 10) // Assure-toi que c'est unique
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
  final List<String> features;

  @HiveField(12)
  final bool isPopular;

  @HiveField(13)
  final bool isActive;

  Plan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.interval,
    this.maxInvoices = -1,
    this.maxClients = -1,
    this.hasPdfExport = true,
    this.hasCloudSync = true,
    this.hasTeamAccess = false,
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
      'hasPdfExport': hasPdfExport,
      'hasCloudSync': hasCloudSync,
      'hasTeamAccess': hasTeamAccess,
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
      hasPdfExport: map['hasPdfExport'] ?? true,
      hasCloudSync: map['hasCloudSync'] ?? true,
      hasTeamAccess: map['hasTeamAccess'] ?? false,
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
    bool? hasPdfExport,
    bool? hasCloudSync,
    bool? hasTeamAccess,
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
      hasPdfExport: hasPdfExport ?? this.hasPdfExport,
      hasCloudSync: hasCloudSync ?? this.hasCloudSync,
      hasTeamAccess: hasTeamAccess ?? this.hasTeamAccess,
      features: features ?? this.features,
      isPopular: isPopular ?? this.isPopular,
      isActive: isActive ?? this.isActive,
    );
  }

  // ===== LOGIQUE =====

  String getFormattedPrice() {
    if (price == 0) return 'Gratuit';
    final priceStr = price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
    return '$priceStr $currency';
  }

  bool get isFree => price == 0;
  bool get hasInvoiceLimit => maxInvoices > 0;
  bool get hasClientLimit => maxClients > 0;

  // ===== PLANS PAR DÉFAUT =====

  static Plan getFreePlan() {
    return Plan(
      id: 'free',
      name: 'Gratuit',
      description: 'Pour démarrer avec OHADA Invoice Pro',
      price: 0.0,
      currency: 'XAF',
      interval: 'month',
      maxInvoices: 3,
      maxClients: 5,
      hasPdfExport: true,
      hasCloudSync: false,
      hasTeamAccess: false,
      features: [
        '3 factures par mois',
        '5 clients',
        'Export PDF',
        'Stockage local',
      ],
      isPopular: false,
      isActive: true,
    );
  }

  static List<Plan> getDefaultPlans() {
    return [
      getFreePlan(),
      Plan(
        id: 'pro',
        name: 'Pro',
        description: 'Pour les PME en croissance',
        price: 9900.0,
        currency: 'XAF',
        interval: 'month',
        maxInvoices: -1,
        maxClients: -1,
        hasPdfExport: true,
        hasCloudSync: true,
        hasTeamAccess: false,
        features: [
          'Factures illimitées',
          'Clients illimités',
          'Export PDF illimité',
          'Synchronisation cloud',
          'Support prioritaire',
        ],
        isPopular: true,
      ),
      Plan(
        id: 'business',
        name: 'Business',
        description: 'Pour les entreprises et équipes',
        price: 49000.0,
        currency: 'XAF',
        interval: 'year',
        maxInvoices: -1,
        maxClients: -1,
        hasPdfExport: true,
        hasCloudSync: true,
        hasTeamAccess: true,
        features: [
          'Tout le plan Pro',
          'Accès équipe (5 utilisateurs)',
          'API intégration',
          'Support dédié 24/7',
          'Formation incluse',
        ],
      ),
    ];
  }
}