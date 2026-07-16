// lib/services/database_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user.dart';
import '../models/invoice.dart';
import '../models/client.dart';
import '../models/company.dart';
import '../models/line_item.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/reminder.dart';
import '../models/subscription.dart';

class DatabaseService {
  // Noms des Boxes
  static const String userBox = 'user_cache';
  static const String companyBox = 'companies';
  static const String clientBox = 'clients';
  static const String invoiceBox = 'invoices';
  static const String productBox = 'products';
  static const String supplierBox = 'suppliers';
  static const String reminderBox = 'reminders';
  static const String subscriptionBox = 'subscriptions';

  /// Initialisation globale de Hive et ouverture de toutes les boxes requises
  static Future<void> init() async {
    // ignore: invalid_use_of_visible_for_testing_member
    Hive.resetAdapters();

    await Hive.initFlutter();

    // 2. Enregistrement des adaptateurs
    _registerAdapters();

    // 3. Ouverture des boxes
    await Future.wait([
      Hive.openBox<AppUser>(userBox),
      Hive.openBox<Company>(companyBox),
      Hive.openBox<Client>(clientBox),
      Hive.openBox<Invoice>(invoiceBox),
      Hive.openBox<Product>(productBox),
      Hive.openBox<Supplier>(supplierBox),
      Hive.openBox<Reminder>(reminderBox),
      Hive.openBox<Subscription>(subscriptionBox),
    ]);
  }

  static void _registerAdapters() {
    // Liste des adaptateurs avec leur typeId
    final Map<int, TypeAdapter> adapters = {
      0: CompanyAdapter(),
      1: ClientAdapter(),
      2: InvoiceAdapter(),
      3: LineItemAdapter(),
      5: ProductAdapter(),
      6: ReminderAdapter(),
      7: SubscriptionAdapter(),
      8: SupplierAdapter(),
      9: AppUserAdapter(),
    };

    adapters.forEach((typeId, adapter) {
      if (!Hive.isAdapterRegistered(typeId)) {
        Hive.registerAdapter(adapter);
      }
    });
  }

  // ==========================================
  // ---- USER CACHE ----
  // ==========================================

  Future<AppUser?> getUser() async {
    final box = Hive.box<AppUser>(userBox);
    return box.get('current_user');
  }

  Future<void> saveUser(AppUser user) async {
    final box = Hive.box<AppUser>(userBox);
    await box.put('current_user', user);
  }

  Future<void> updateUser(AppUser user) async {
    final box = Hive.box<AppUser>(userBox);
    // On utilise la même clé que dans saveUser
    await box.put('current_user', user);
  }

  Future<void> clearUser() async {
    final box = Hive.box<AppUser>(userBox);
    await box.clear();
  }

  // ==========================================
  // ---- COMPANY ----
  // ==========================================

  Future<Company?> getCompany() async {
    final box = Hive.box<Company>(companyBox);
    return box.values.isNotEmpty ? box.getAt(0) : null;
  }

  Future<void> saveCompany(Company company) async {
    final box = Hive.box<Company>(companyBox);
    if (box.isEmpty) {
      await box.add(company);
    } else {
      await box.putAt(0, company);
    }
  }

  // ==========================================
  // ---- CLIENTS (Optimisés avec clé unique) ----
  // ==========================================

  Future<List<Client>> getClients() async {
    final box = Hive.box<Client>(clientBox);
    return box.values.toList();
  }

  Future<Client?> getClient(String id) async {
    final box = Hive.box<Client>(clientBox);
    return box.get(id); // Récupération directe en O(1)
  }

  Future<void> addClient(Client client) async {
    final box = Hive.box<Client>(clientBox);
    await box.put(client.id, client); // Utilisation de l'UUID en clé
  }

  Future<void> updateClient(Client client) async {
    final box = Hive.box<Client>(clientBox);
    await box.put(
        client.id, client); // Écrase l'ancienne valeur sans parcourir la liste
  }

  Future<void> deleteClient(String id) async {
    final box = Hive.box<Client>(clientBox);
    await box.delete(id);
  }

  // ==========================================
  // ---- INVOICES (Optimisés avec clé unique) ----
  // ==========================================

  Future<List<Invoice>> getInvoices() async {
    final box = Hive.box<Invoice>(invoiceBox);
    return box.values.toList();
  }

  Future<Invoice?> getInvoice(String id) async {
    final box = Hive.box<Invoice>(invoiceBox);
    return box.get(id); // Récupération directe en O(1)
  }

  Future<void> addInvoice(Invoice invoice) async {
    final box = Hive.box<Invoice>(invoiceBox);
    await box.put(invoice.id, invoice);
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final box = Hive.box<Invoice>(invoiceBox);
    await box.put(invoice.id, invoice);
  }

  Future<void> deleteInvoice(String id) async {
    final box = Hive.box<Invoice>(invoiceBox);
    await box.delete(id);
  }

  // Génération dynamique du numéro de facture ou devis
  Future<String> getNextInvoiceNumber(bool isDevis) async {
    final box = Hive.box<Invoice>(invoiceBox);
    final prefix = isDevis ? 'DEV' : 'FA';
    final year = DateTime.now().year;
    final count = box.values.where((inv) => inv.isDevis == isDevis).length;

    final sequence = (count + 1).toString().padLeft(3, '0');
    return '$prefix-$year-$sequence';
  }

  Future<List<Invoice>> getInvoicesByStatus(String status) async {
    final box = Hive.box<Invoice>(invoiceBox);
    return box.values.where((inv) => inv.status == status).toList();
  }

  Future<List<Invoice>> getOverdueInvoices() async {
    final now = DateTime.now();
    final box = Hive.box<Invoice>(invoiceBox);
    return box.values
        .where((inv) =>
            inv.status != 'paid' &&
            inv.status != 'overdue' &&
            inv.dueDate.isBefore(now))
        .toList();
  }

  Future<List<Invoice>> getInvoicesByClient(String clientId) async {
    final box = Hive.box<Invoice>(invoiceBox);
    return box.values.where((inv) => inv.clientId == clientId).toList();
  }

  Future<void> updateInvoiceStatus(String id, String status) async {
    final invoice = await getInvoice(id);
    if (invoice != null) {
      final updatedInvoice = invoice.copyWith(status: status);
      await updateInvoice(updatedInvoice);
    }
  }

  // ==========================================
  // ---- PRODUCTS (Ajouté pour le workflow) ----
  // ==========================================

  Future<List<Product>> getProducts() async {
    final box = Hive.box<Product>(productBox);
    return box.values.toList();
  }

  Future<Product?> getProduct(String id) async {
    return Hive.box<Product>(productBox).get(id);
  }

  Future<void> saveProduct(Product product) async {
    await Hive.box<Product>(productBox).put(product.id, product);
  }

  Future<void> deleteProduct(String id) async {
    await Hive.box<Product>(productBox).delete(id);
  }

  // ==========================================
  // ---- SUPPLIERS & REMINDERS ----
  // ==========================================

  Future<List<Supplier>> getSuppliers() async {
    return Hive.box<Supplier>(supplierBox).values.toList();
  }

  Future<void> saveSupplier(Supplier supplier) async {
    await Hive.box<Supplier>(supplierBox).put(supplier.id, supplier);
  }

  Future<List<Reminder>> getReminders() async {
    return Hive.box<Reminder>(reminderBox).values.toList();
  }

  Future<void> saveReminder(Reminder reminder) async {
    await Hive.box<Reminder>(reminderBox).put(reminder.id, reminder);
  }

  // ==========================================
  // ---- NETTOYAGE ABSOLU (Déconnexion) ----
  // ==========================================

  Future<void> clearAllData() async {
    await Future.wait([
      Hive.box<AppUser>(userBox).clear(),
      Hive.box<Company>(companyBox).clear(),
      Hive.box<Client>(clientBox).clear(),
      Hive.box<Invoice>(invoiceBox).clear(),
      Hive.box<Product>(productBox).clear(),
      Hive.box<Supplier>(supplierBox).clear(),
      Hive.box<Reminder>(reminderBox).clear(),
      Hive.box<Subscription>(subscriptionBox).clear(),
    ]);
  }
}
