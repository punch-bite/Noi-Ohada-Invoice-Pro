// lib/screens/customization/template_checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/template_cart.dart';
import '../../services/template_service.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/enkap_checkout_dialog.dart';
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

    final isFree = _totalPrice <= 0;

    // 🆓 Panier 100 % gratuit : déblocage immédiat, sans paiement.
    if (isFree) {
      await _unlockTemplates(reference: null);
      return;
    }

    // 💳 Panier payant : numéro Mobile Money requis (sauf carte bancaire).
    final phone = _phoneController.text.trim();
    if (_selectedPaymentMethod != 'card' && phone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir un numéro de téléphone valide.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    // 💳 Paiement ENKAP (Orange Money / MTN / Moov / carte) : crée la
    // commande, ouvre la page sécurisée E-nkap et vérifie automatiquement la
    // confirmation. Le déblocage n'est validé qu'après confirmation — le
    // serveur revérifie la commande ENKAP avant l'ajout à `purchasedBy`.
    final reference = 'TPL-${DateTime.now().millisecondsSinceEpoch}';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => EnkapCheckoutDialog(
        amount: _totalPrice,
        currency: 'XAF',
        description: _items.length == 1
            ? 'Achat modèle : ${_items.first.name}'
            : 'Achat de ${_items.length} modèles de facture',
        merchantReference: reference,
        providerName: _providerName,
        phoneNumber: _selectedPaymentMethod == 'card' ? null : phone,
        customerName: auth.user?.displayName,
        customerEmail: auth.user?.email,
        onSuccess: () => _unlockTemplates(reference: reference),
        onCancel: () {
          if (!mounted) return;
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paiement annulé.'),
              backgroundColor: Colors.orange,
            ),
          );
        },
      ),
    );
  }

  /// Libellé lisible du mode de paiement sélectionné (pour ENKAP).
  String get _providerName {
    switch (_selectedPaymentMethod) {
      case 'om':
        return 'Orange Money';
      case 'mtn':
        return 'MTN Mobile Money';
      case 'moov':
        return 'Moov Money';
      default:
        return 'Carte Bancaire';
    }
  }

  /// Débloque les modèles : appelé directement pour un panier gratuit
  /// (`reference` = null) ou après confirmation du paiement ENKAP.
  Future<void> _unlockTemplates({required String? reference}) async {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final userId = auth.user?.id ?? '';
    final isFree = reference == null;

    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      final templateIds = _items.map((e) => e.id).toList();

      final success = await _templateService.purchaseTemplates(
        userId: userId,
        templateIds: templateIds,
        reference: reference,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final theme = context.read<ThemeProvider>();

      if (success || isFree) {
        // 🧹 Retire les modèles acquis du panier local (boutique / aperçu).
        for (final id in templateIds) {
          TemplateCart.instance.remove(id);
        }
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: RoyalColors.tertiary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isFree ? 'Modèle débloqué !' : 'Paiement Réussi !',
                    style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(
              isFree
                  ? 'Le modèle est désormais disponible dans vos modèles.'
                  : 'Félicitations ! Votre modèle est prêt à être personnalisé.',
              style: TextStyle(color: theme.subTextColor),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/templates/mine');
                },
                child: Text('Voir Mes Modèles',
                    style: TextStyle(color: theme.accentGold)),
              ),
              if (_items.isNotEmpty)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
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
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final goldAccent = theme.accentGold;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;

    if (_items.isEmpty) {
      return GlassScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('Panier de Modèles', style: TextStyle(color: textColor)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_basket_outlined,
                  size: 64, color: subTextColor),
              const SizedBox(height: 16),
              Text('Votre panier est vide',
                  style: TextStyle(color: textColor, fontSize: 18)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.go('/templates'),
                icon: const Icon(Icons.storefront),
                label: const Text('Voir la boutique'),
                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor),
              )
            ],
          ),
        ),
      );
    }

    final isFree = _totalPrice <= 0;

    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Confirmation & Règlement',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontFamily: 'Manrope',
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
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
                color: textColor,
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
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.category.toUpperCase(),
                            style: TextStyle(
                              color: goldAccent,
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
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: _selectedPaymentMethod,
                onChanged: (val) => setState(() => _selectedPaymentMethod = val ?? 'om'),
                child: Column(
                  children: [
                    _buildPaymentOption(
                      id: 'om',
                      name: 'Orange Money',
                      icon: Icons.phone_android,
                      color: Colors.orange,
                      theme: theme,
                    ),
                    const SizedBox(height: 10),
                    _buildPaymentOption(
                      id: 'mtn',
                      name: 'MTN Mobile Money',
                      icon: Icons.phone_iphone,
                      color: Colors.yellow.shade700,
                      theme: theme,
                    ),
                    const SizedBox(height: 10),
                    _buildPaymentOption(
                      id: 'moov',
                      name: 'Moov Money',
                      icon: Icons.mobile_friendly,
                      color: Colors.blue,
                      theme: theme,
                    ),
                    const SizedBox(height: 10),
                    _buildPaymentOption(
                      id: 'card',
                      name: 'Carte Bancaire / Visa',
                      icon: Icons.credit_card,
                      color: Colors.purpleAccent,
                      theme: theme,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (_selectedPaymentMethod != 'card') ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Numéro de Téléphone Mobile Money',
                    labelStyle: TextStyle(color: subTextColor),
                    prefixIcon: Icon(Icons.phone, color: goldAccent),
                    filled: true,
                    fillColor: theme.inputFillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: theme.inputBorderColor),
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
                      Text(
                        'Total à régler',
                        style: TextStyle(color: textColor, fontSize: 16),
                      ),
                      Text(
                        isFree
                            ? 'GRATUIT'
                            : '${_totalPrice.toStringAsFixed(0)} FCFA',
                        style: TextStyle(
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
                        backgroundColor: theme.primaryColor,
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
    required ThemeProvider theme,
  }) {
    final isSelected = _selectedPaymentMethod == id;
    final goldAccent = theme.accentGold;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = id),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? goldAccent : theme.dividerColor,
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
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Radio<String>(
              value: id,
              activeColor: goldAccent,
            ),
          ],
        ),
      ),
    );
  }
}

