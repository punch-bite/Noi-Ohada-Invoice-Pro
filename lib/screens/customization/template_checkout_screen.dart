// lib/screens/customization/template_checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/invoice_template.dart';
import '../../providers/auth_provider.dart';
import '../../services/template_cart.dart';
import '../../services/template_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/enkap_checkout_dialog.dart';
import '../../widgets/glass_widgets.dart';
import 'customization_ui.dart';

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

    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    final userId = auth.user?.id ?? '';

    if (userId.isEmpty) {
      CustomSnack.show(context, l10n.checkoutLoginRequired,
          type: CustomSnackType.error);
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
      CustomSnack.show(context, l10n.checkoutInvalidPhone,
          type: CustomSnackType.error);
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
            ? l10n.checkoutPurchaseOne(_items.first.name)
            : l10n.checkoutPurchaseMany(_items.length),
        merchantReference: reference,
        providerName: _providerName,
        phoneNumber: _selectedPaymentMethod == 'card' ? null : phone,
        customerName: auth.user?.displayName,
        customerEmail: auth.user?.email,
        onSuccess: () => _unlockTemplates(reference: reference),
        onCancel: () {
          if (!mounted) return;
          setState(() => _isProcessing = false);
          CustomSnack.show(context, l10n.checkoutPaymentCancelled);
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
    final l10n = AppLocalizations.of(context);
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

      final p = CustomPalette.of(context);

      if (success || isFree) {
        // 🧹 Retire les modèles acquis du panier local (boutique / aperçu).
        for (final id in templateIds) {
          TemplateCart.instance.remove(id);
        }
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: p.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: p.gold, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isFree
                        ? l10n.checkoutUnlockedTitle
                        : l10n.checkoutSuccessTitle,
                    style: TextStyle(
                      color: p.text,
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              isFree
                  ? l10n.checkoutUnlockedMsg
                  : l10n.checkoutSuccessMsg,
              style: TextStyle(color: p.subText, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/templates/mine');
                },
                child: Text(l10n.checkoutViewMyTemplates,
                    style:
                        TextStyle(color: p.gold, fontWeight: FontWeight.w700)),
              ),
              if (_items.isNotEmpty)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: p.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/templates/workspace', extra: _items.first);
                  },
                  child: Text(l10n.checkoutCustomizeNow),
                ),
            ],
          ),
        );
      } else {
        CustomSnack.show(context, l10n.checkoutPaymentFailed,
            type: CustomSnackType.error);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      CustomSnack.show(context, l10n.checkoutTransactionError('$e'),
          type: CustomSnackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_items.isEmpty) {
      return GlassScaffold(
        appBar: CustomAppBar(title: l10n.checkoutCartTitle),
        body: EmptyState(
          icon: Icons.shopping_basket_outlined,
          title: l10n.checkoutEmptyTitle,
          message: l10n.checkoutEmptyMsg,
          actionLabel: l10n.checkoutBrowseStore,
          onAction: () => context.go('/templates'),
        ),
      );
    }

    final isFree = _totalPrice <= 0;

    return GlassScaffold(
      appBar: CustomAppBar(
        title: l10n.checkoutTitle,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Builder(builder: (context) {
          final p = CustomPalette.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Text(
              l10n.checkoutSelectedItems,
              style: TextStyle(
                color: p.text,
                fontFamily: 'Manrope',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            ..._items.map(
              (item) => EntranceFade(
                index: _items.indexOf(item),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: item.primaryColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: item.primaryColor.withValues(alpha: 0.5)),
                        ),
                        child: Icon(Icons.description_rounded,
                            color: item.primaryColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.text,
                                fontFamily: 'Manrope',
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.category.toUpperCase(),
                              style: TextStyle(
                                color: p.gold,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      item.price <= 0
                          ? OwnedPill(label: l10n.checkoutFreeItem)
                          : PricePill(
                              '${item.price.toStringAsFixed(0)} FCFA'),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (!isFree) ...[
              Text(
                l10n.checkoutPaymentMethod,
                style: TextStyle(
                  color: p.text,
                  fontFamily: 'Manrope',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  _buildPaymentOption(
                    id: 'om',
                    name: l10n.checkoutOrangeMoney,
                    icon: Icons.phone_android,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentOption(
                    id: 'mtn',
                    name: l10n.checkoutMtnMoney,
                    icon: Icons.phone_iphone,
                    color: Colors.yellow.shade700,
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentOption(
                    id: 'moov',
                    name: l10n.checkoutMoovMoney,
                    icon: Icons.mobile_friendly,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentOption(
                    id: 'card',
                    name: l10n.checkoutCard,
                    icon: Icons.credit_card,
                    color: Colors.purpleAccent,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (_selectedPaymentMethod != 'card') ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: p.text),
                  cursorColor: p.gold,
                  decoration: InputDecoration(
                    labelText: l10n.checkoutPhoneLabel,
                    labelStyle: TextStyle(color: p.subText),
                    prefixIcon: Icon(Icons.phone_rounded, color: p.gold),
                    filled: true,
                    fillColor: p.card,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: p.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: p.gold, width: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: p.cardHigh,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.checkoutTotalToPay,
                        style: TextStyle(
                          color: p.text,
                          fontFamily: 'Manrope',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isFree
                            ? l10n.checkoutFree
                            : '${_totalPrice.toStringAsFixed(0)} FCFA',
                        style: TextStyle(
                          color: isFree ? p.gold : p.text,
                          fontFamily: 'Manrope',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isProcessing ? null : _processCheckout,
                      icon: Icon(
                        isFree
                            ? Icons.lock_open_rounded
                            : Icons.shopping_cart_checkout_rounded,
                        size: 20,
                      ),
                      label: _isProcessing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: p.onPrimary, strokeWidth: 2.5),
                            )
                          : Text(
                              isFree
                                  ? l10n.checkoutUnlockButton
                                  : l10n.checkoutConfirmButton(
                                      _totalPrice.toStringAsFixed(0)),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                      style: FilledButton.styleFrom(
                        backgroundColor: p.primary,
                        foregroundColor: p.onPrimary,
                        elevation: 0,
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
        )
        .animate()
        .fade(duration: const Duration(milliseconds: 300))
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
        }),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String name,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedPaymentMethod == id;
    final p = CustomPalette.of(context);

    return PressScale(
      scaleDown: 0.98,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedPaymentMethod = id);
      },
      child: AnimatedContainer(
        duration: RoyalMotion.base,
        curve: RoyalMotion.standard,
        decoration: BoxDecoration(
          color: isSelected ? p.cardHigh : p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? p.gold : p.border,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: p.text,
                  fontFamily: 'WorkSans',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            AnimatedContainer(
              duration: RoyalMotion.base,
              curve: RoyalMotion.standard,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? p.gold : Colors.transparent,
                border: Border.all(
                  color: isSelected ? p.gold : p.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded, size: 14, color: p.onGold)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

