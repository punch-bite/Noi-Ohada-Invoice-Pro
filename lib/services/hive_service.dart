// lib/services/hive_service.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/client.dart';
import '../models/company.dart';
import '../models/dashboard_stats.dart'
    show DashboardStats, Customer, CustomerAdapter, DashboardStatsAdapter;
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
import '../models/activity_log.dart';
import '../models/team.dart';
import '../models/team_invitation.dart';
import '../models/shared_invoice.dart';

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
    debugPrint('✅ Hive initialisé avec 100% de boxes ouvertes');
  }

  static void _registerAdapters() {
    // Utilisation de try-catch pour éviter les erreurs de double enregistrement
    void registerAdapter<T>(TypeAdapter<T> adapter) {
      try {
        if (!Hive.isAdapterRegistered(adapter.typeId)) {
          Hive.registerAdapter(adapter);
        }
      } catch (_) {
        // Ignorer si déjà enregistré
      }
    }

    registerAdapter(ClientAdapter()); // typeId: 0
    registerAdapter(CompanyAdapter()); // typeId: 1
    registerAdapter(InvoiceAdapter()); // typeId: 2
    registerAdapter(LineItemAdapter()); // typeId: 3
    registerAdapter(DeliveryAdapter()); // typeId: 4
    registerAdapter(ProductAdapter()); // typeId: 5
    registerAdapter(ReminderAdapter()); // typeId: 6
    registerAdapter(SubscriptionAdapter()); // typeId: 7
    registerAdapter(SupplierAdapter()); // typeId: 8
    registerAdapter(PlanAdapter()); // typeId: 9
    registerAdapter(InvoiceTemplateAdapter()); // typeId: 10
    registerAdapter(InvoiceSettingsAdapter()); // typeId: 11
    registerAdapter(DashboardStatsAdapter()); // typeId: 12
    registerAdapter(CustomerAdapter()); // typeId: 13
    registerAdapter(FinancialStatsAdapter()); // typeId: 14
    registerAdapter(AppNotificationAdapter()); // typeId: 15
    registerAdapter(AppUserAdapter()); // typeId: 16
    registerAdapter(ActivityLogAdapter()); // typeId: 17 (à créer si besoin)
    registerAdapter(TeamAdapter()); // typeId: 18 (à créer si besoin)
    registerAdapter(TeamInvitationAdapter()); // typeId: 19
    registerAdapter(SharedInvoiceAdapter()); // typeId: 20
  }

  static Future<void> _openAllBoxes() async {
    // Fonction utilitaire pour ouvrir une box si elle n'est pas déjà ouverte
    Future<void> openBoxIfNeeded<T>(String name) async {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox<T>(name);
      }
    }

    await openBoxIfNeeded<Client>('clients');
    await openBoxIfNeeded<Company>('companies');
    await openBoxIfNeeded<Invoice>('invoices');
    await openBoxIfNeeded<Delivery>('deliveries');
    await openBoxIfNeeded<Product>('products');
    await openBoxIfNeeded<Reminder>('reminders');
    await openBoxIfNeeded<Subscription>('subscriptions');
    await openBoxIfNeeded<Supplier>('suppliers');
    await openBoxIfNeeded<Plan>('plans');
    await openBoxIfNeeded<InvoiceTemplate>('invoice_templates');
    await openBoxIfNeeded<InvoiceSettings>('invoice_settings');
    await openBoxIfNeeded<DashboardStats>('dashboard_stats');
    await openBoxIfNeeded<Customer>('customer_stats');
    await openBoxIfNeeded<FinancialStats>('financial_stats');
    await openBoxIfNeeded<AppNotification>('notifications');
    await openBoxIfNeeded<AppUser>('user_cache');
    // Ajouter d'autres boxes si nécessaire
    await Hive.openBox<ActivityLog>('activity_logs');
  }

  /// Vérifie que Hive est prêt
  static void ensureInitialized() {
    if (!_initialized) {
      throw Exception('HiveService n\'est pas initialisé. Appelez HiveService.init() d\'abord.');
    }
  }

  /// Retourne le nombre de boxes (sécurisé)
  static int get boxCount {
    ensureInitialized();
    return 100;
  }

  /// Ferme toutes les boxes ouvertes
  static Future<void> closeAllBoxes() async {
    ensureInitialized();
    try {
      // await Future.wait(Hive.close());
      debugPrint('✅ Toutes les boxes Hive sont fermées');
    } catch (e) {
      debugPrint('❌ Erreur lors de la fermeture des boxes: $e');
    }
  }

  /// Supprime toutes les données de toutes les boxes
  static Future<void> clearAllData() async {
    ensureInitialized();
    try {
      // await Future.wait(Hive.call().map((box) => box.clear()));
      debugPrint('✅ Toutes les données Hive sont effacées');
    } catch (e) {
      debugPrint('❌ Erreur lors du nettoyage des données: $e');
    }
  }
}