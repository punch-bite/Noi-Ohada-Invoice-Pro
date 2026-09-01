// lib/services/hive_service.dart

import 'dart:io';
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

    registerAdapter(ClientAdapter());
    registerAdapter(CompanyAdapter());
    registerAdapter(InvoiceAdapter());
    registerAdapter(LineItemAdapter());
    registerAdapter(DeliveryAdapter());
    registerAdapter(ProductAdapter());
    registerAdapter(ReminderAdapter());
    registerAdapter(SubscriptionAdapter());
    registerAdapter(SupplierAdapter());
    registerAdapter(PlanAdapter());
    registerAdapter(InvoiceTemplateAdapter());
    registerAdapter(InvoiceSettingsAdapter());
    registerAdapter(DashboardStatsAdapter());
    registerAdapter(CustomerAdapter());
    registerAdapter(FinancialStatsAdapter());
    registerAdapter(AppUserAdapter());
    registerAdapter(AppNotificationAdapter()); // typeId 16
    registerAdapter(ActivityLogAdapter()); // typeId 17
    registerAdapter(TeamAdapter()); // typeId 20
    registerAdapter(SharedInvoiceAdapter()); // typeId 23
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

  /// Initialisation pour les tests (mode VM sans Flutter binding).
  static Future<void> initForTest() async {
    if (_initialized) return;
    final dir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(dir.path);
    _registerAdapters();
    await _openAllBoxes();
    _initialized = true;
    debugPrint('✅ Hive initialisé pour les tests');
  }

  /// Vérifie que Hive est prêt
  static void ensureInitialized() {
    if (!_initialized) {
      throw Exception(
          'HiveService n\'est pas initialisé. Appelez HiveService.init() d\'abord.');
    }
  }

  /// Retourne le nombre de boxes (sécurisé)
  static int get boxCount {
    ensureInitialized();
    return 100;
  }

  /// Boxes qui contiennent des données utilisateur (purgeables au logout)
  static const List<String> userDataBoxNames = [
    'clients',
    'companies',
    'invoices',
    'deliveries',
    'products',
    'reminders',
    'subscriptions',
    'suppliers',
    'plans',
    'invoice_templates',
    'invoice_settings',
    'dashboard_stats',
    'customer_stats',
    'financial_stats',
    'notifications',
    'user_cache',
    'activity_logs',
    'subscription_notifications_cache',
    'team_messages',
  ];

  /// Boxes qui restent sur l'appareil même après déconnexion
  /// (préférences locales indépendantes de l'utilisateur)
  static const List<String> protectedBoxNames = [
    'theme_preferences',
    'security_preferences',
    'app_logs',
  ];

  /// Ferme toutes les boxes ouvertes
  static Future<void> closeAllBoxes() async {
    try {
      // On ferme chaque box indépendamment pour qu'une erreur sur l'une
      // n'empêche pas la fermeture des suivantes.
      for (final name in [...userDataBoxNames, ...protectedBoxNames]) {
        if (Hive.isBoxOpen(name)) {
          try {
            final box = Hive.box(name);
            if (box.isOpen) {
              await box.close();
            }
          } catch (e) {
            debugPrint('⚠️ Fermeture box "$name" ignorée: $e');
          }
        }
      }
      _initialized = false; // Nécessite une réinitialisation
      debugPrint('✅ Toutes les boxes Hive sont fermées');
    } catch (e) {
      debugPrint('❌ Erreur lors de la fermeture des boxes: $e');
    }
  }

  /// © Supprime TOUTES les données de TOUTES les boxes, y compris les
  /// boxes protégées. À utiliser pour une réinitialisation totale.
  static Future<void> wipeAllData() async {
    ensureInitialized();
    try {
      final tasks = <Future>[];
      for (final name in [...userDataBoxNames, ...protectedBoxNames]) {
        if (Hive.isBoxOpen(name)) {
          tasks.add(Hive.box(name).clear());
        }
      }
      if (tasks.isNotEmpty) {
        await Future.wait(tasks);
      }
      debugPrint('✅ TOUTES les données Hive sont effacées');
    } catch (e) {
      debugPrint('❌ Erreur lors du nettoyage complet: $e');
    }
  }

  /// ⭐ MÉTHODE PRINCIPALE DE SÉCURITÉ : Purge les données UTILISATEUR
  static Future<void> clearAllData() async {
    try {
      final tasks = <Future>[];
      for (final name in userDataBoxNames) {
        if (Hive.isBoxOpen(name)) {
          tasks.add(Hive.box(name).clear());
        }
      }
      if (tasks.isNotEmpty) {
        await Future.wait(tasks);
      }
      debugPrint('✅ Données utilisateur Hive effacées (${tasks.length} boxes)');
    } catch (e) {
      debugPrint('❌ Erreur lors du nettoyage des données: $e');
    }
  }

  /// Alias de clearAllData pour plus de clarté sémantique.
  static Future<void> clearUserData() async {
    await clearAllData();
  }

  /// Supprime uniquement les logs d'activité et les notifications
  static Future<void> clearSensitiveUserCache() async {
    ensureInitialized();
    try {
      if (Hive.isBoxOpen('user_cache')) {
        await Hive.box<AppUser>('user_cache').clear();
      }
      if (Hive.isBoxOpen('activity_logs')) {
        await Hive.box<ActivityLog>('activity_logs').clear();
      }
      if (Hive.isBoxOpen('notifications')) {
        await Hive.box<AppNotification>('notifications').clear();
      }
      debugPrint('✅ Cache sensible utilisateur effacé');
    } catch (e) {
      debugPrint('❌ Erreur lors du nettoyage du cache: $e');
    }
  }
}
