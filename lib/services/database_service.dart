// lib/services/database_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:noi_ohada_invoice_pro/models/user.dart';
import '../models/invoice.dart';
import '../models/client.dart';
import '../models/company.dart';
import '../models/line_item.dart';

class DatabaseService {
  static const String invoiceBox = 'invoices';
  static const String clientBox = 'clients';
  static const String companyBox = 'companies';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(InvoiceAdapter());
    Hive.registerAdapter(ClientAdapter());
    Hive.registerAdapter(CompanyAdapter());
    Hive.registerAdapter(LineItemAdapter());

    await Hive.openBox<Invoice>(invoiceBox);
    await Hive.openBox<Client>(clientBox);
    await Hive.openBox<Company>(companyBox);
  }

  Future<void> updateUser(AppUser user) async {
    final box = Hive.box<AppUser>('user_cache');
    await box.put('user_data', user);
    
  }

  // ---- COMPANY ----
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

  // ---- CLIENTS ----
  Future<List<Client>> getClients() async {
    final box = Hive.box<Client>(clientBox);
    return box.values.toList();
  }

  // ⚠️ UNE SEULE FOIS cette fonction
  Future<Client?> getClient(String id) async {
    final box = Hive.box<Client>(clientBox);
    try {
      return box.values.firstWhere((client) => client.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> addClient(Client client) async {
    final box = Hive.box<Client>(clientBox);
    await box.add(client);
  }

  Future<void> updateClient(Client client) async {
    final box = Hive.box<Client>(clientBox);
    final index = box.values.toList().indexWhere((c) => c.id == client.id);
    if (index != -1) {
      await box.putAt(index, client);
    }
  }

  Future<void> deleteClient(String id) async {
    final box = Hive.box<Client>(clientBox);
    final index = box.values.toList().indexWhere((c) => c.id == id);
    if (index != -1) {
      await box.deleteAt(index);
    }
  }

  // ---- INVOICES ----
  Future<List<Invoice>> getInvoices() async {
    final box = Hive.box<Invoice>(invoiceBox);
    return box.values.toList();
  }

  // ⚠️ UNE SEULE FOIS cette fonction (GARDE CELLE-CI)
  Future<Invoice?> getInvoice(String id) async {
    final box = Hive.box<Invoice>(invoiceBox);
    try {
      return box.values.firstWhere((invoice) => invoice.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> addInvoice(Invoice invoice) async {
    final box = Hive.box<Invoice>(invoiceBox);
    await box.add(invoice);
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final box = Hive.box<Invoice>(invoiceBox);
    final index = box.values.toList().indexWhere((inv) => inv.id == invoice.id);
    if (index != -1) {
      await box.putAt(index, invoice);
    }
  }

  Future<void> deleteInvoice(String id) async {
    final box = Hive.box<Invoice>(invoiceBox);
    final index = box.values.toList().indexWhere((inv) => inv.id == id);
    if (index != -1) {
      await box.deleteAt(index);
    }
  }

  // Get next invoice number
  Future<String> getNextInvoiceNumber(bool isDevis) async {
    final box = Hive.box<Invoice>(invoiceBox);
    final prefix = isDevis ? 'DEV' : 'FA';
    final year = DateTime.now().year;
    final count = box.values.where((inv) => inv.isDevis == isDevis).length;

    final sequence = (count + 1).toString().padLeft(3, '0');
    return '$prefix-$year-$sequence';
  }

  // Get invoices by status
  Future<List<Invoice>> getInvoicesByStatus(String status) async {
    final box = Hive.box<Invoice>(invoiceBox);
    return box.values.where((inv) => inv.status == status).toList();
  }

  // Get overdue invoices
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

  // Get invoices by client
  Future<List<Invoice>> getInvoicesByClient(String clientId) async {
    final box = Hive.box<Invoice>(invoiceBox);
    return box.values.where((inv) => inv.clientId == clientId).toList();
  }

  // Update invoice status
  Future<void> updateInvoiceStatus(String id, String status) async {
    final invoice = await getInvoice(id);
    if (invoice != null) {
      final updatedInvoice = invoice.copyWith(status: status);
      await updateInvoice(updatedInvoice);
    }
  }

  Future<void> clearAllData() async {
    await Hive.box<Invoice>(invoiceBox).clear();
    await Hive.box<Client>(clientBox).clear();
    await Hive.box<Company>(companyBox).clear();
  }
  // Ajouter ces méthodes dans DatabaseService

// --- USER DATA (local cache) ---
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final box = await Hive.openBox('user_cache');
    await box.put('user_data', userData);
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final box = await Hive.openBox('user_cache');
    return box.get('user_data');
  }

  Future<void> clearUserData() async {
    final box = await Hive.openBox('user_cache');
    await box.clear();
  }
}
