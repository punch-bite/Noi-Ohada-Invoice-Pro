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

  @HiveField(18)
  final int maxSuppliers;

  /// 🎨 Couleur HEX d'accent (badge, gradient, icône). Stockée comme int.
  @HiveField(19)
  final int accentColorValue;

  /// 🏷️ Slogan court affiché sous le nom (ex: "Pour bien démarrer").
  @HiveField(20)
  final String tagline;

  /// 🎁 Nombre de relances clients incluses par mois (-1 = illimité).
  @HiveField(21)
  final int maxMonthlyRelances;

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
    this.maxSuppliers = -1,
    this.features = const [],
    this.isPopular = false,
    this.isActive = true,
    this.accentColorValue = 0xFF4338CA,
    this.tagline = '',
    this.maxMonthlyRelances = 0,
  });

  // ─── Color getter (utilisable côté UI) ───
  // ignore: avoid_getters_with_parameter
  // (défini ici pour simplifier le code UI)
  int get accentColorInt => accentColorValue;

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
      'maxSuppliers': maxSuppliers,
      'features': features,
      'isPopular': isPopular,
      'isActive': isActive,
      'accentColorValue': accentColorValue,
      'tagline': tagline,
      'maxMonthlyRelances': maxMonthlyRelances,
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
      maxSuppliers: (map['maxSuppliers'] as num?)?.toInt() ?? -1,
      features: List<String>.from(map['features'] ?? []),
      isPopular: map['isPopular'] ?? false,
      isActive: map['isActive'] ?? true,
      accentColorValue:
          (map['accentColorValue'] as num?)?.toInt() ?? 0xFF4338CA,
      tagline: map['tagline'] ?? '',
      maxMonthlyRelances:
          (map['maxMonthlyRelances'] as num?)?.toInt() ?? 0,
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
    int? maxSuppliers,
    bool? hasGoogleDriveSync,
    bool? hasClientRelance,
    List<String>? features,
    bool? isPopular,
    bool? isActive,
    int? accentColorValue,
    String? tagline,
    int? maxMonthlyRelances,
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
      maxSuppliers: maxSuppliers ?? this.maxSuppliers,
      hasGoogleDriveSync: hasGoogleDriveSync ?? this.hasGoogleDriveSync,
      hasClientRelance: hasClientRelance ?? this.hasClientRelance,
      features: features ?? this.features,
      isPopular: isPopular ?? this.isPopular,
      isActive: isActive ?? this.isActive,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      tagline: tagline ?? this.tagline,
      maxMonthlyRelances: maxMonthlyRelances ?? this.maxMonthlyRelances,
    );
  }

  String getFormattedPrice() {
    if (price == 0) return 'Gratuit';
    final priceStr =
        price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
    return '$priceStr $currency';
  }

  /// Prix sans devise (utile pour affichage stylisé).
  String getPriceNumber() {
    if (price == 0) return '0';
    return price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
  }

  bool get isFree => price == 0;
  bool get hasInvoiceLimit => maxInvoices > 0;
  bool get hasClientLimit => maxClients > 0;
  bool get hasProductLimit => maxProducts > 0;
  bool get hasSupplierLimit => maxSuppliers > 0;

  bool isUnlimitedInvoices() => maxInvoices <= 0;
  bool isUnlimitedClients() => maxClients <= 0;
  bool isUnlimitedProducts() => maxProducts <= 0;
  bool isUnlimitedSuppliers() => maxSuppliers <= 0;

  // ═══════════════════════════════════════════════════════════
  //  🎨 PLANS PRÉDÉFINIS
  // ═══════════════════════════════════════════════════════════

  static Plan getFreePlan() {
    return Plan(
      id: 'free',
      name: 'Gratuit',
      tagline: 'Découvrir',
      description: 'Pour tester toutes les fonctionnalités essentielles.',
      price: 0.0,
      currency: 'XAF',
      interval: 'month',
      maxInvoices: 5,
      maxClients: 5,
      maxProducts: 3,
      maxSuppliers: 2,
      hasPdfExport: true,
      hasCloudSync: false,
      hasTeamAccess: false,
      maxTeamMembers: 0,
      hasGoogleDriveSync: true,
      features: [
        '5 factures',
        '5 clients',
        '3 produits',
        '2 fournisseurs',
        'Export PDF',
        'Sauvegarde Google Drive',
      ],
      isPopular: false,
      isActive: true,
      accentColorValue: 0xFF64748B, // slate
    );
  }

  static Plan getStarterPlan() {
    return Plan(
      id: 'starter',
      name: 'Starter',
      tagline: 'Bien démarrer',
      description: 'L\'essentiel pour les indépendants et artisans.',
      price: 2800.0,
      currency: 'XAF',
      interval: 'month',
      maxInvoices: 30,
      maxClients: 20,
      maxProducts: 10,
      maxSuppliers: 5,
      hasPdfExport: true,
      hasCloudSync: false, // ❌ Pas de Firestore
      hasTeamAccess: false,
      maxTeamMembers: 0,
      hasGoogleDriveSync: true,
      hasClientRelance: false,
      features: [
        '30 factures / mois',
        '20 clients',
        '10 produits',
        '5 fournisseurs',
        'Export PDF illimité',
        'Sauvegarde Google Drive',
      ],
      isPopular: false,
      isActive: true,
      accentColorValue: 0xFF06B6D4, // cyan
    );
  }

  static Plan getEssentialPlan() {
    return Plan(
      id: 'essential',
      name: 'Essentiel',
      tagline: 'Recommandé',
      description:
          'Cloud + relances clients. Idéal pour les petits commerces.',
      price: 3100.0,
      currency: 'XAF',
      interval: 'month',
      maxInvoices: 60,
      maxClients: 40,
      maxProducts: 20,
      maxSuppliers: 10,
      hasPdfExport: true,
      hasCloudSync: true, // ✅ Firestore multi-appareils
      hasTeamAccess: false,
      maxTeamMembers: 0,
      hasGoogleDriveSync: true,
      hasClientRelance: true,
      maxMonthlyRelances: 50,
      features: [
        '60 factures / mois',
        '40 clients',
        '20 produits',
        '10 fournisseurs',
        'Export PDF illimité',
        'Synchronisation cloud Firestore',
        'Sauvegarde Google Drive',
        '50 relances clients / mois',
      ],
      isPopular: true, // Le nouveau "best-seller" d'entrée
      isActive: true,
      accentColorValue: 0xFF10B981, // emerald
    );
  }

  static Plan getProPlan() {
    return Plan(
      id: 'pro',
      name: 'Pro',
      tagline: 'PME en croissance',
      description: 'Pour les PME qui veulent aller plus vite.',
      price: 9900.0,
      currency: 'XAF',
      interval: 'month',
      maxInvoices: -1,
      maxClients: 200,
      maxProducts: 25,
      maxSuppliers: 25,
      hasPdfExport: true,
      hasCloudSync: true,
      hasTeamAccess: false,
      maxTeamMembers: 0,
      hasGoogleDriveSync: true,
      hasClientRelance: true,
      maxMonthlyRelances: -1,
      features: [
        'Factures illimitées',
        '200 clients',
        '25 produits',
        '25 fournisseurs',
        'Export PDF illimité',
        'Synchronisation cloud',
        'Sauvegarde Google Drive',
        'Relances clients illimitées',
        'Support prioritaire',
      ],
      isPopular: false,
      isActive: true,
      accentColorValue: 0xFF4338CA, // indigo
    );
  }

  static Plan getBusinessPlan() {
    return Plan(
      id: 'business',
      name: 'Business',
      tagline: 'Entreprises & équipes',
      description: 'Toutes les fonctionnalités, sans aucune limite.',
      price: 49000.0,
      currency: 'XAF',
      interval: 'year',
      maxInvoices: -1,
      maxClients: -1,
      maxProducts: -1,
      maxSuppliers: -1,
      hasPdfExport: true,
      hasCloudSync: true,
      hasTeamAccess: true,
      maxTeamMembers: 20,
      hasGoogleDriveSync: true,
      hasClientRelance: true,
      maxMonthlyRelances: -1,
      features: [
        'Tout le plan Pro',
        'Factures / clients / produits illimités',
        'Module équipe (20 utilisateurs)',
        'Invitation par lien e-mail',
        'Sauvegarde Google Drive',
        'Relances clients illimitées',
        'Support dédié 24/7',
      ],
      isPopular: false,
      isActive: true,
      accentColorValue: 0xFFBAAB6D, // or royal
    );
  }

  static List<Plan> getDefaultPlans() {
    return [
      getFreePlan(),
      getStarterPlan(),
      getEssentialPlan(),
      getProPlan(),
      getBusinessPlan(),
    ];
  }
}