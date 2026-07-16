// lib/services/hive_service.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/client.dart';
import '../models/company.dart';
import '../models/dashboard_stats.dart' show DashboardStats, Customer, CustomerAdapter, DashboardStatsAdapter;
import '../models/delivery.dart';
import '../models/invoice.dart';
import '../models/line_item.dart';
import '../models/product.dart';
import '../models/reminder.dart';
import '../models/subscription.dart';
import '../models/supplier.dart';
import '../models/plan.dart';
import '../models/notification.dart';
import '../models/user.dart';
import '../models/invoice_settings.dart';
import '../models/invoice_template.dart';
import '../models/financial_stats.dart';

class HiveService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    // 1. Initialiser Hive
    await Hive.initFlutter();

    // 2. Enregistrer TOUS les adaptateurs (vérifier l'unicité des typeId)
    _registerAdapters();

    // 3. Ouvrir TOUTES les boxes
    await _openAllBoxes();

    _initialized = true;
    debugPrint('✅ Hive initialisé à 100%, toutes les boxes sont ouvertes');
  }

  static void _registerAdapters() {
    // Liste complète des adaptateurs (à adapter selon vos modèles)
    Hive.registerAdapter(ClientAdapter());          // typeId: 0
    Hive.registerAdapter(CompanyAdapter());         // typeId: 1
    Hive.registerAdapter(InvoiceAdapter());         // typeId: 2
    Hive.registerAdapter(LineItemAdapter());        // typeId: 3
    Hive.registerAdapter(DeliveryAdapter());        // typeId: 4
    Hive.registerAdapter(ProductAdapter());         // typeId: 5
    Hive.registerAdapter(ReminderAdapter());        // typeId: 6
    Hive.registerAdapter(SubscriptionAdapter());    // typeId: 7
    Hive.registerAdapter(SupplierAdapter());        // typeId: 8
    Hive.registerAdapter(PlanAdapter());            // typeId: 9
    Hive.registerAdapter(InvoiceTemplateAdapter()); // typeId: 10
    Hive.registerAdapter(InvoiceSettingsAdapter()); // typeId: 11
    Hive.registerAdapter(DashboardStatsAdapter());  // typeId: 12
    Hive.registerAdapter(CustomerAdapter());        // typeId: 13
    Hive.registerAdapter(FinancialStatsAdapter());  // typeId: 14
    Hive.registerAdapter(AppNotificationAdapter()); // typeId: 15 (si utilisé)
    Hive.registerAdapter(AppUserAdapter());         // typeId: 16 (si utilisé)
  }

  static Future<void> _openAllBoxes() async {
    // Ouvrir toutes les boxes utilisées dans l'application
    await Hive.openBox<Client>('clients');
    await Hive.openBox<Company>('companies');
    await Hive.openBox<Invoice>('invoices');
    // LineItem n'a pas besoin de box propre (il est intégré dans Invoice)
    await Hive.openBox<Delivery>('deliveries');
    await Hive.openBox<Product>('products');
    await Hive.openBox<Reminder>('reminders');
    await Hive.openBox<Subscription>('subscriptions');
    await Hive.openBox<Supplier>('suppliers');
    await Hive.openBox<Plan>('plans');
    await Hive.openBox<InvoiceTemplate>('invoice_templates');
    await Hive.openBox<InvoiceSettings>('invoice_settings');
    await Hive.openBox<DashboardStats>('dashboard_stats');
    await Hive.openBox<Customer>('customer_stats');
    await Hive.openBox<FinancialStats>('financial_stats');
    await Hive.openBox<AppNotification>('notifications'); // si besoin
    await Hive.openBox<AppUser>('user_cache'); // pour le cache utilisateur
  }

  /// Vérifie que Hive est prêt
  static void ensureInitialized() {
    if (!_initialized) {
      throw Exception('HiveService n’est pas initialisé. Appelez HiveService.init() d’abord.');
    }
  }

  /// Retourne le nombre de boxes (sécurisé)
  static int get boxCount {
    ensureInitialized();
    return 100;
  }
}

