// lib/screens/customization/template_checkout_screen.dart
//
// 🛒 Checkout du panier de modèles de factures.
//  - Si le panier ne contient que des modèles GRATUITS (prix 0) → on
//    débloque SANS passer par le paiement (confirmation directe).
//  - Si le panier contient des modèles payants → règlement ENKAP (Orange /
//    MTN / carte) puis déblocage sécurisé par le serveur.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/template_cart.dart';
import '../../services/template_service.dart';
import '../../widgets/enkap_checkout_dialog.dart';

class TemplateCheckoutScreen extends StatefulWidget {
  const TemplateCheckoutScreen({super.key});

  @override
  State<TemplateCheckoutScreen> createState() => _TemplateCheckoutScreenState();
}

class _TemplateCheckoutScreenState extends State<TemplateCheckoutScreen> {
  final TemplateService _templateService = TemplateService();
  bool _processing = false;

  String _fmt(double amount) =>
      '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ')} XAF';

  Future<void> _checkout() async {
    final cart = TemplateCart.instance;
    final auth = context.read<AppAuthProvider>();
    final userId = auth.user?.id ?? '';
    if (userId.isEmpty) {
      _snack('Connectez-vous pour finaliser votre commande', Colors.orange);
      return;
    }
    if (cart.isEmpty) return;

    setState(() => _processing = true);

    final items = cart.items;
    final total = cart.total;

    if (total <= 0) {
      // 🎉 Panier 100 % gratuit → pas de paiement, déblocage direct.
      final ok = await _templateService.purchaseTemplates(
        userId: userId,
        templateIds: items.map((e) => e.id).toList(),
      );
      if (!mounted) return;
      setState(() => _processing = false);
      if (ok) {
        cart.clear();
        _snack('✅ ${items.length} modèle(s) débloqué(s) gratuitement', Colors.green);
        _goToMyTemplates();
      } else {
        _snack('Échec de la commande. Réessayez.', Colors.red);
      }
      return;
    }

    // 💳 Panier payant → paiement ENKAP.
    final reference = 'TPL-${DateTime.now().millisecondsSinceEpoch}';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => EnkapCheckoutDialog(
        amount: total,
        currency: 'XAF',
        description: 'Achat de ${items.length} modèle(s) de facture',
        merchantReference: reference,
        providerName: 'ENKAP',
        customerName: auth.user?.displayName,
        customerEmail: auth.user?.email,
        onSuccess: () => _completePaidPurchase(items, reference),
        onCancel: () {
          if (mounted) setState(() => _processing = false);
        },
      ),
    );
  }

  Future<void> _completePaidPurchase(
      List<InvoiceTemplate> items, String reference) async {
    final auth = context.read<AppAuthProvider>();
    final userId = auth.user?.id ?? '';
    final ok = await _templateService.purchaseTemplates(
      userId: userId,
      templateIds: items.map((e) => e.id).toList(),
      reference: reference,
    );
    if (!mounted) return;
    setState(() => _processing = false);
    if (ok) {
      TemplateCart.instance.clear();
      _snack('✅ Modèles achetés et débloqués', Colors.green);
      _goToMyTemplates();
    } else {
      _snack('Paiement effectué mais déblocage impossible. Contactez le support.',
          Colors.red);
    }
  }

  void _goToMyTemplates() {
    context.pushReplacement('/templates/mine');
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final cart = context.watch<TemplateCart>();
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;
    final total = cart.total;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('🛒 Panier (${cart.count})',
            style: TextStyle(color: text, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: cart.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 64, color: sub.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('Votre panier est vide',
                      style: TextStyle(color: sub)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Retour à la boutique'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final t = cart.items[index];
                      return _cartTile(t, theme);
                    },
                  ),
                ),
                // ===== Récapitulatif + bouton =====
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    border: Border(
                      top: BorderSide(
                        color: theme.isDarkMode
                            ? Colors.grey[800]!
                            : Colors.grey[200]!,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text('Total',
                              style: TextStyle(
                                  color: sub, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text(_fmt(total),
                              style: TextStyle(
                                  color: text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        total > 0
                            ? 'Paiement sécurisé via E-nkap (Orange Money, MTN, carte).'
                            : '🎉 Aucun paiement requis : ces modèles sont gratuits.',
                        style: TextStyle(fontSize: 11, color: sub),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _processing ? null : _checkout,
                          icon: _processing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Icon(total > 0
                                  ? Icons.lock_outline
                                  : Icons.check_circle_outline),
                          label: Text(
                            total > 0
                                ? 'Payer ${_fmt(total)}'
                                : 'Confirmer (gratuit)',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _cartTile(InvoiceTemplate t, ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.description_outlined,
                color: t.primaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name,
                    style: TextStyle(
                        color: theme.textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  t.price > 0
                      ? '${t.price.toStringAsFixed(0)} XAF'
                      : 'Gratuit',
                  style: TextStyle(
                    color: t.price > 0
                        ? Colors.green
                        : Colors.blueGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: theme.subTextColor, size: 20),
            onPressed: () => TemplateCart.instance.remove(t.id),
          ),
        ],
      ),
    );
  }
}
