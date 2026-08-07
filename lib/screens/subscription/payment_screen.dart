// lib/screens/subscription/payment_screen.dart
//
// 💳 Paiement d'abonnement 100% ENKAP (Orange Money / MTN Mobile Money /
// Carte). Le client est redirigé vers la page sécurisée E-nkap, la
// confirmation est vérifiée automatiquement puis l'abonnement est activé.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/notification.dart';
import '../../models/plan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/enkap_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/enkap_checkout_dialog.dart';

class PaymentScreen extends StatefulWidget {
  final Plan plan;
  final VoidCallback onPaymentComplete;

  const PaymentScreen({
    super.key,
    required this.plan,
    required this.onPaymentComplete,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final EnkapService _enkapService = EnkapService();
  final NotificationService _notificationService = NotificationService();

  String _selectedMethod = EnkapService.methodOrangeMoney;
  String _phoneNumber = '';
  String _transactionId = '';
  bool _isProcessing = false;
  String _error = '';

  bool get _isCard => _selectedMethod == EnkapService.methodCard;

  // 🔒 Méthodes de paiement ENKAP.
  final List<({String id, String name, IconData icon, Color color})> _methods =
      [
    (
      id: EnkapService.methodOrangeMoney,
      name: 'Orange Money',
      icon: Icons.phone_android,
      color: Colors.orange,
    ),
    (
      id: EnkapService.methodMtnMoney,
      name: 'MTN Mobile Money',
      icon: Icons.phone_android,
      color: const Color(0xFFFFD700),
    ),
    (
      id: EnkapService.methodCard,
      name: 'Carte bancaire (Visa / MasterCard)',
      icon: Icons.credit_card,
      color: Colors.purple,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _notificationService.init();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final primaryColor = themeProvider.primaryColor;
    final bgColor = themeProvider.backgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Paiement',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPlanSummary(textColor, subTextColor),
            const SizedBox(height: 24),
            _buildPaymentForm(
              isDark,
              textColor,
              subTextColor,
              primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  // ===== RÉSUMÉ DU PLAN =====
  Widget _buildPlanSummary(Color textColor, Color subTextColor) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Résumé de votre abonnement',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            widget.plan.name,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            widget.plan.description,
            style:
                TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total à payer',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
              ),
              Text(
                widget.plan.getFormattedPrice(),
                style: const TextStyle(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== FORMULAIRE DE PAIEMENT =====
  Widget _buildPaymentForm(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Méthode de paiement',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 4),
        Text(
          'Choisissez votre moyen de paiement : Mobile Money (Orange / MTN) '
          'ou carte bancaire (Visa / MasterCard).',
          style: TextStyle(fontSize: 12, color: subTextColor),
        ),
        const SizedBox(height: 12),
        ..._methods.map((m) => _buildMethodTile(m, isDark, textColor, primaryColor)),
        const SizedBox(height: 16),

        // Numéro de téléphone (Mobile Money uniquement).
        if (!_isCard) ...[
          TextFormField(
            keyboardType: TextInputType.phone,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Numéro de téléphone',
              labelStyle: TextStyle(color: subTextColor),
              hintText: '6X XX XX XX XX',
              hintStyle:
                  TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
              prefixIcon: Icon(Icons.phone, color: primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: (value) => setState(() => _phoneNumber = value),
          ),
          const SizedBox(height: 16),
        ],

        if (_error.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ],
            ),
          ),
        if (_error.isNotEmpty) const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _processPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: _isProcessing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 12),
                      Text('Traitement en cours...'),
                    ],
                  )
                : Text(
                    'Payer ${widget.plan.getFormattedPrice()}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 14, color: subTextColor),
            const SizedBox(width: 6),
            Text(
              'Paiement sécurisé via E-nkap • Données cryptées',
              style: TextStyle(fontSize: 12, color: subTextColor),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMethodTile(
    ({String id, String name, IconData icon, Color color}) method,
    bool isDark,
    Color textColor,
    Color primaryColor,
  ) {
    final isSelected = _selectedMethod == method.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? method.color.withValues(alpha: 0.1)
              : (isDark ? Colors.grey[800] : Colors.grey[50]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? method.color
                : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(method.icon, color: method.color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                method.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? method.color : textColor,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: method.color, size: 20),
          ],
        ),
      ),
    );
  }

  // ===== LANCEMENT DU PAIEMENT (ENKAP) =====
  Future<void> _processPayment() async {
    if (!_isCard && (_phoneNumber.isEmpty || _phoneNumber.length < 9)) {
      _showSnackBar('Numéro de téléphone invalide', Colors.red);
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = '';
    });

    final authProvider = context.read<AppAuthProvider>();
    final method = _methods.firstWhere((m) => m.id == _selectedMethod);
    final reference = 'SUB-${DateTime.now().millisecondsSinceEpoch}';
    _transactionId = reference;

    // Enregistre l'intention d'abonnement sur le serveur pour que le callback
    // ENKAP puisse activer l'abonnement (best-effort, même app fermée).
    final uid = authProvider.user?.id ?? '';
    if (uid.isNotEmpty) {
      await _enkapService.registerSubscriptionIntent(
        reference: reference,
        userId: uid,
        planId: widget.plan.id,
        amount: widget.plan.price,
        currency: widget.plan.currency,
        paymentMethod: _selectedMethod,
      );
    }

    // 💳 Paiement via ENKAP : la confirmation est vérifiée automatiquement.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => EnkapCheckoutDialog(
        amount: widget.plan.price,
        currency: widget.plan.currency,
        description: 'Abonnement ${widget.plan.name}',
        merchantReference: reference,
        providerName: method.name,
        phoneNumber: _isCard ? null : _phoneNumber,
        customerName: authProvider.user?.displayName,
        customerEmail: authProvider.user?.email,
        onSuccess: () {
          _completeSubscription();
        },
        onCancel: () {
          if (mounted) {
            setState(() => _isProcessing = false);
            _showSnackBar('Paiement annulé', Colors.orange);
          }
        },
      ),
    );
  }

  Future<void> _completeSubscription() async {
    final authProvider = context.read<AppAuthProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();

    if (authProvider.user == null) {
      _showSnackBar('Utilisateur non connecté', Colors.red);
      return;
    }

    final success = await subscriptionProvider.createSubscription(
      userId: authProvider.user!.id,
      planId: widget.plan.id,
      paymentMethod: _selectedMethod,
      paymentId: _transactionId,
      amount: widget.plan.price,
      currency: widget.plan.currency,
      interval: widget.plan.interval,
    );

    setState(() => _isProcessing = false);

    if (success) {
      await _notificationService.addNotification(
        AppNotification(
          title: '🎉 Abonnement activé',
          body: 'Votre abonnement ${widget.plan.name} a été activé avec succès.',
          type: NotificationType.system_update.toString(),
        ),
      );
      _showSnackBar(
          'Abonnement ${widget.plan.name} activé avec succès ! ✅', Colors.green);
      widget.onPaymentComplete();
      Navigator.pop(context, true);
    } else {
      await _notificationService.addNotification(
        AppNotification(
          title: '⚠️ Erreur d\'activation',
          body:
              'Le paiement a été effectué mais l\'activation de l\'abonnement '
              'a échoué. Contactez le support.',
          type: NotificationType.system_update.toString(),
        ),
      );
      _showSnackBar('Erreur lors de l\'activation de l\'abonnement', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
