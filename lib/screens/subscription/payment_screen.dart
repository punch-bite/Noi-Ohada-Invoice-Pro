// lib/screens/subscription/payment_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/plan.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/nochpay_service.dart';
import '../../services/notification_service.dart';
import '../../models/notification.dart';

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
  final NochPayService _nochPayService = NochPayService();
  final NotificationService _notificationService = NotificationService();

  String _selectedMethod = 'orange_money';
  String _phoneNumber = '';
  String _confirmationCode = '';
  String _userConfirmationCode = '';
  String _transactionId = '';
  bool _isProcessing = false;
  bool _isConfirming = false;
  String _error = '';
  final int _retryCount = 0;
  final int _maxRetries = 3;

  final List<PaymentMethod> _paymentMethods = [
    PaymentMethod(
      id: 'orange_money',
      name: 'Orange Money',
      icon: Icons.phone_android,
      color: Colors.orange,
    ),
    PaymentMethod(
      id: 'mtn_money',
      name: 'MTN Mobile Money',
      icon: Icons.phone_android,
      color: const Color(0xFFFFD700),
    ),
    PaymentMethod(
      id: 'wave',
      name: 'Wave',
      icon: Icons.waves,
      color: Colors.blue,
    ),
    PaymentMethod(
      id: 'card',
      name: 'Carte bancaire',
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
    final textColor = themeProvider.textColor ?? Colors.black;
    final subTextColor = themeProvider.subTextColor ?? Colors.grey;
    final primaryColor = themeProvider.primaryColor ?? Colors.blue;
    final bgColor = themeProvider.backgroundColor ?? Colors.white;
    final cardColor = themeProvider.cardColor ?? Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Paiement',
          style: TextStyle(color: textColor),
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
            // Résumé du plan
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.7)],
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
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.plan.description,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total à payer',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                      ),
                      Text(
                        widget.plan.getFormattedPrice(),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isConfirming)
              _buildConfirmationView(
                isDark,
                textColor,
                subTextColor,
                primaryColor,
                cardColor,
              )
            else
              _buildPaymentForm(
                isDark,
                textColor,
                subTextColor,
                primaryColor,
                cardColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    Color cardColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Méthode de paiement',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 12),
        ..._paymentMethods.map((method) => _buildPaymentMethodTile(method, isDark, textColor, primaryColor)),
        const SizedBox(height: 16),

        // Numéro de téléphone
        TextFormField(
          keyboardType: TextInputType.phone,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Numéro de téléphone',
            labelStyle: TextStyle(color: subTextColor),
            hintText: '6X XX XX XX XX',
            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
            prefixIcon: Icon(Icons.phone, color: primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: (value) => setState(() => _phoneNumber = value),
        ),
        const SizedBox(height: 16),

        if (_error.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 13)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: _isProcessing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 12),
                      Text('Traitement en cours...'),
                    ],
                  )
                : Text(
                    'Payer ${widget.plan.getFormattedPrice()}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
              'Paiement sécurisé via NochPay • Données cryptées',
              style: TextStyle(fontSize: 12, color: subTextColor),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmationView(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    Color cardColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.hourglass_empty, size: 48, color: Colors.orange),
        const SizedBox(height: 16),
        Text(
          'En attente de confirmation...',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Veuillez confirmer le paiement sur votre téléphone',
          style: TextStyle(fontSize: 14, color: subTextColor),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Montant:', style: TextStyle(color: subTextColor)),
                  Text(
                    widget.plan.getFormattedPrice(),
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Téléphone:', style: TextStyle(color: subTextColor)),
                  Text(_phoneNumber, style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Transaction:', style: TextStyle(color: subTextColor)),
                  Text('#${_transactionId.substring(0, 8)}', style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
                ],
              ),
            ],
          ),
        ),

        if (_confirmationCode.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Code de confirmation envoyé par SMS',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) => setState(() => _userConfirmationCode = value),
                        decoration: InputDecoration(
                          hintText: 'Entrez le code reçu',
                          hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: isDark ? Colors.grey[800] : Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _confirmWithCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isProcessing
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Confirmer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _showSnackBar('Un nouveau code a été envoyé', Colors.blue),
            child: Text('Renvoyer le code', style: TextStyle(color: primaryColor)),
          ),
        ],

        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _isConfirming = false;
              _transactionId = '';
              _confirmationCode = '';
              _userConfirmationCode = '';
            });
          },
          child: const Text('Annuler le paiement', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile(
    PaymentMethod method,
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
          color: isSelected ? method.color.withOpacity(0.1) : (isDark ? Colors.grey[800] : Colors.grey[50]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? method.color : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(method.icon, color: method.color, size: 24),
            const SizedBox(width: 12),
            Text(
              method.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? method.color : textColor,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: method.color, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (_phoneNumber.isEmpty || _phoneNumber.length < 9) {
      _showSnackBar('Numéro de téléphone invalide', Colors.red);
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = '';
    });

    try {
      final result = await _nochPayService.initiatePayment(
        amount: widget.plan.price,
        currency: widget.plan.currency,
        phoneNumber: _phoneNumber,
        invoiceNumber: 'SUB-${DateTime.now().millisecondsSinceEpoch}',
        description: 'Abonnement ${widget.plan.name}',
      );

      if (result['success'] == true) {
        setState(() {
          _transactionId = result['transaction_id'];
          _confirmationCode = result['confirmation_code'] ?? '';
          _isProcessing = false;
          _isConfirming = true;
        });

        await _nochPayService.savePendingTransaction(
          transactionId: _transactionId,
          invoiceId: 'sub_${DateTime.now().millisecondsSinceEpoch}',
          invoiceNumber: 'SUB-${DateTime.now().millisecondsSinceEpoch}',
          phoneNumber: _phoneNumber,
          amount: widget.plan.price,
        );

        _startAutoCheck();
        _showSnackBar('Paiement initié. Veuillez confirmer sur votre téléphone.', Colors.blue);
      } else {
        setState(() {
          _isProcessing = false;
          _error = result['error'] ?? 'Erreur d\'initialisation';
        });
        _showSnackBar(_error, Colors.red);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'Erreur: $e';
      });
      _showSnackBar(_error, Colors.red);
    }
  }

  void _startAutoCheck() {
    int checks = 0;
    const maxChecks = 12;

    Future.delayed(const Duration(seconds: 5), () {
      _autoCheckStatus(checks, maxChecks);
    });
  }

  Future<void> _autoCheckStatus(int checks, int maxChecks) async {
    if (checks >= maxChecks || !_isConfirming) return;

    final result = await _nochPayService.checkPaymentStatus(_transactionId);

    if (result['success'] == true && result['status'] == 'paid') {
      await _completeSubscription();
      return;
    }

    if (result['success'] == true && result['status'] == 'failed') {
      setState(() {
        _isConfirming = false;
        _error = 'Le paiement a échoué';
      });
      await _notificationService.addNotification(
        AppNotification(
          title: '⚠️ Paiement échoué',
          body: 'Le paiement pour l\'abonnement ${widget.plan.name} a échoué. Veuillez réessayer.',
          type: NotificationType.system_update.toString(),
        ),
      );
      _showSnackBar(_error, Colors.red);
      return;
    }

    Future.delayed(const Duration(seconds: 5), () {
      _autoCheckStatus(checks + 1, maxChecks);
    });
  }

  Future<void> _confirmWithCode() async {
    if (_userConfirmationCode.isEmpty || _userConfirmationCode.length < 6) {
      _showSnackBar('Veuillez entrer le code de confirmation reçu par SMS', Colors.orange);
      return;
    }

    setState(() => _isProcessing = true);

    final result = await _nochPayService.confirmPaymentWithCode(
      transactionId: _transactionId,
      confirmationCode: _userConfirmationCode,
    );

    if (result['success'] == true) {
      await _completeSubscription();
    } else {
      setState(() {
        _isProcessing = false;
        _error = result['error'] ?? 'Code de confirmation invalide';
      });
      _showSnackBar(_error, Colors.red);
    }
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

    await _nochPayService.removePendingTransaction(_transactionId);

    setState(() {
      _isConfirming = false;
      _isProcessing = false;
    });

    if (success) {
      await _notificationService.addNotification(
        AppNotification(
          title: '🎉 Abonnement activé',
          body: 'Votre abonnement ${widget.plan.name} a été activé avec succès.',
          type: NotificationType.system_update.toString(),
        ),
      );
      _showSnackBar('Abonnement ${widget.plan.name} activé avec succès ! ✅', Colors.green);
      widget.onPaymentComplete();
      Navigator.pop(context, true);
    } else {
      await _notificationService.addNotification(
        AppNotification(
          title: '⚠️ Erreur d\'activation',
          body: 'Le paiement a été effectué mais l\'activation de l\'abonnement a échoué. Contactez le support.',
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

class PaymentMethod {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  PaymentMethod({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}