// lib/services/template_cart.dart
//
// 🛒 Panier d'achat des modèles de factures (singleton ChangeNotifier).
// On peut y ajouter plusieurs modèles (gratuits et payants), puis passer
// au checkout : les gratuits sont débloqués SANS paiement, les payants
// nécessitent un règlement ENKAP.
import 'package:flutter/foundation.dart';
import '../models/invoice_template.dart';

class TemplateCart extends ChangeNotifier {
  TemplateCart._();
  static final TemplateCart instance = TemplateCart._();

  final List<InvoiceTemplate> _items = [];
  List<InvoiceTemplate> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get count => _items.length;

  /// Total à payer (somme des modèles payants, non déjà possédés).
  double get total {
    var t = 0.0;
    for (final item in _items) {
      t += (item.price > 0 ? item.price : 0);
    }
    return t;
  }

  bool contains(String templateId) => _items.any((e) => e.id == templateId);

  void add(InvoiceTemplate template) {
    if (_items.any((e) => e.id == template.id)) return;
    _items.add(template);
    notifyListeners();
  }

  void remove(String templateId) {
    _items.removeWhere((e) => e.id == templateId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
