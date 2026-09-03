// lib/screens/customization/template_checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../services/template_service.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/glass_widgets.dart';

/// 🛒 Écran d'achat / validation d'un modèle de facture premium ou gratuit.
class TemplateCheckoutScreen extends StatefulWidget {
  final InvoiceTemplate? template;
  final List<InvoiceTemplate>? cartTemplates;

  const TemplateCheckoutScreen({
    super.key,
    this.template,
    this.cartTemplates,
  });

  @override
  State<TemplateCheckoutScreen> createState() => _TemplateCheckoutScreenState();
}

class _TemplateCheckoutScreenState extends State<TemplateCheckoutScreen> {
  static const Color goldAccent = Color(0xFFC9A227);
  static const Color bgSurface = Color(0xFF1E1A24);
  static const Color bgBackground = Color(0xFF120F17);

  final TemplateService _templateService = TemplateService();

  late List<InvoiceTemplate> _items;
  String _selectedPaymentMethod = 'om'; // om, mtn, moov, card
  bool _isProcessing = false;
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _items = [widget.template!];
    } else if (widget.cartTemplates != null && widget.cartTemplates!.isNotEmpty) {
      _items = widget.cartTemplates!;
    } else {
      _items = [];
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  double get _totalPrice {
    return _items.fold(0.0, (sum, item) => sum + item.price);
  }

  Future<void> _processCheckout() async {
    if (_items.isEmpty) return;

    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final userId = auth.user?.id ?? '';

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez vous connecter pour acquérir des modèles.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final templateIds = _items.map((e) => e.id).toList();
      final isFree = _totalPrice <= 0;

      final success = await _templateService.purchaseTemplates(
        userId: userId,
        templateIds: templateIds,
        reference: isFree ? null : 'PAY_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (success || isFree) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: bgSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: RoyalColors.tertiary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isFree ? 'Modèle débloqué !' : 'Paiement Réussi !',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(
              isFree
                  ? 'Le modèle est désormais disponible dans vos modèles.'
                  : 'Félicitations ! Votre modèle est prêt à être personnalisé.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/templates/mine');
                },
                child: const Text('Voir Mes Modèles',
                    style: TextStyle(color: goldAccent)),
              ),
              if (_items.isNotEmpty)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RoyalColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/templates/workspace', extra: _items.first);
                  },
                  child: const Text('Personnaliser Maintenant',
                      style: TextStyle(color: Colors.white)),
                ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le paiement n\'a pas pu être validé. Réessayez.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la transaction : $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Scaffold(
        backgroundColor: bgBackground,
        appBar: AppBar(
          backgroundColor: bgSurface,
          title: const Text('Panier de Modèles'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_basket_outlined,
                  size: 64, color: Colors.white38),
              const SizedBox(height: 16),
              const Text('Votre panier est vide',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.go('/templates'),
                icon: const Icon(Icons.storefront),
                label: const Text('Voir la boutique'),
                style: ElevatedButton.styleFrom(backgroundColor: RoyalColors.primary),
              )
            ],
          ),
        ),
      );
    }

    final isFree = _totalPrice <= 0;

    return Scaffold(
      backgroundColor: bgBackground,
      appBar: AppBar(
        backgroundColor: bgSurface,
        elevation: 0,
        title: const Text(
          'Confirmation & Règlement',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Manrope',
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Articles Sélectionnés',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._items.map(
              (item) => GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: item.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: item.primaryColor),
                      ),
                      child: Icon(Icons.description, color: item.primaryColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.category.toUpperCase(),
                            style: TextStyle(
                              color: goldAccent.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item.price <= 0
                          ? 'GRATUIT'
                          : '${item.price.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        color: item.price <= 0
                            ? RoyalColors.tertiary
                            : goldAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (!isFree) ...[
              Text(
                'Mode de Paiement',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildPaymentOption(
                id: 'om',
                name: 'Orange Money',
                icon: Icons.phone_android,
                color: Colors.orange,
              ),
              const SizedBox(height: 10),
              _buildPaymentOption(
                id: 'mtn',
                name: 'MTN Mobile Money',
                icon: Icons.phone_iphone,
                color: Colors.yellow.shade700,
              ),
              const SizedBox(height: 10),
              _buildPaymentOption(
                id: 'moov',
                name: 'Moov Money',
                icon: Icons.mobile_friendly,
                color: Colors.blue,
              ),
              const SizedBox(height: 10),
              _buildPaymentOption(
                id: 'card',
                name: 'Carte Bancaire / Visa',
                icon: Icons.credit_card,
                color: Colors.purpleAccent,
              ),

              const SizedBox(height: 16),

              if (_selectedPaymentMethod != 'card') ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Numéro de Téléphone Mobile Money',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    prefixIcon: const Icon(Icons.phone, color: goldAccent),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],

            GlassCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total à régler',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Text(
                        isFree
                            ? 'GRATUIT'
                            : '${_totalPrice.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          color: goldAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RoyalColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    isFree
                                        ? Icons.lock_open
                                        : Icons.shopping_cart_checkout,
                                    color: Colors.white),
                                const SizedBox(width: 10),
                                Text(
                                  isFree
                                      ? 'Débloquer le Modèle'
                                      : 'Confirmer & Payer (${_totalPrice.toStringAsFixed(0)} FCFA)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fade().slideY(begin: 0.1, duration: const Duration(milliseconds: 300)),
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String name,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedPaymentMethod == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = id),
      child: Container(
        decoration: BoxDecoration(
          color: bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? goldAccent : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Radio<String>(
              value: id,
              groupValue: _selectedPaymentMethod,
              onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
              activeColor: goldAccent,
            ),
          ],
        ),
      ),
    );
  }
}
