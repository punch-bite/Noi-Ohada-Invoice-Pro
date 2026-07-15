// lib/widgets/nochpay_payment_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/nochpay_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/invoice.dart';

class NochPayPaymentDialog extends StatefulWidget {
  final Invoice invoice;
  final String phoneNumber;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const NochPayPaymentDialog({
    super.key,
    required this.invoice,
    required this.phoneNumber,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<NochPayPaymentDialog> createState() => _NochPayPaymentDialogState();
}

class _NochPayPaymentDialogState extends State<NochPayPaymentDialog> {
  final NochPayService _nochPayService = NochPayService();
  final DatabaseService _db = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  String _status = 'initializing';
  String _transactionId = '';
  String _confirmationCode = '';
  String _error = '';
  bool _isLoading = false;
  String _userConfirmationCode = '';
  int _retryCount = 0;
  final int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _notificationService.init(); // Initialiser le service de notifications
    _initiatePayment();
  }

  Future<void> _initiatePayment() async {
    setState(() {
      _status = 'initializing';
      _isLoading = true;
    });

    final result = await _nochPayService.initiatePayment(
      amount: widget.invoice.totalAmount,
      currency: 'XAF',
      phoneNumber: widget.phoneNumber,
      invoiceNumber: widget.invoice.invoiceNumber,
      description: 'Paiement facture ${widget.invoice.invoiceNumber}',
    );

    if (result['success'] == true) {
      setState(() {
        _transactionId = result['transaction_id'];
        _confirmationCode = result['confirmation_code'] ?? '';
        _status = 'pending';
        _isLoading = false;
      });

      await _nochPayService.savePendingTransaction(
        transactionId: _transactionId,
        invoiceId: widget.invoice.id,
        phoneNumber: widget.phoneNumber,
        amount: widget.invoice.totalAmount, invoiceNumber: '',
      );

      _startAutoCheck();
    } else {
      setState(() {
        _status = 'failed';
        _error = result['error'] ?? 'Erreur d\'initialisation du paiement';
        _isLoading = false;
      });
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
    if (checks >= maxChecks || _status == 'success' || _status == 'failed') {
      return;
    }

    final result = await _nochPayService.checkPaymentStatus(_transactionId);

    if (result['success'] == true && result['status'] == 'paid') {
      setState(() {
        _status = 'success';
        _isLoading = false;
      });
      await _completePayment();
      return;
    }

    if (result['success'] == true && result['status'] == 'failed') {
      setState(() {
        _status = 'failed';
        _error = 'Le paiement a échoué';
        _isLoading = false;
      });
      return;
    }

    Future.delayed(const Duration(seconds: 5), () {
      _autoCheckStatus(checks + 1, maxChecks);
    });
  }

  Future<void> _confirmWithCode() async {
    if (_userConfirmationCode.isEmpty || _userConfirmationCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un code de confirmation valide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _status = 'confirming';
      _isLoading = true;
    });

    final result = await _nochPayService.confirmPaymentWithCode(
      transactionId: _transactionId,
      confirmationCode: _userConfirmationCode,
    );

    if (result['success'] == true) {
      setState(() {
        _status = 'success';
        _isLoading = false;
      });
      await _completePayment();
    } else {
      setState(() {
        _status = 'pending';
        _error = result['error'] ?? 'Code de confirmation invalide';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completePayment() async {
    // Mettre à jour le statut de la facture
    final updatedInvoice = widget.invoice.copyWith(
      status: 'paid',
    );
    await _db.updateInvoice(updatedInvoice);

    // 🔥 ENVOYER LES NOTIFICATIONS
    await _notificationService.notifyInvoicePaid(widget.invoice.invoiceNumber);
    await _notificationService.notifyPaymentReceived(widget.invoice.totalAmount);

    // Supprimer la transaction en cours
    await _nochPayService.removePendingTransaction(_transactionId);

    widget.onSuccess();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final primaryColor = themeProvider.primaryColor;
    final cardColor = themeProvider.cardColor;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: cardColor,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.payment,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Paiement NochPay',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: subTextColor),
                  onPressed: () {
                    widget.onCancel();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatusContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContent() {
    switch (_status) {
      case 'initializing':
        return _buildInitializing();
      case 'pending':
        return _buildPending();
      case 'confirming':
        return _buildConfirming();
      case 'success':
        return _buildSuccess();
      case 'failed':
        return _buildFailed();
      default:
        return _buildInitializing();
    }
  }

  Widget _buildInitializing() {
    final themeProvider = context.watch<ThemeProvider>();
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;

    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          'Initialisation du paiement...',
          style: TextStyle(
            fontSize: 16,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Veuillez patienter',
          style: TextStyle(
            fontSize: 13,
            color: subTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPending() {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final primaryColor = themeProvider.primaryColor;

    return Column(
      children: [
        const Icon(
          Icons.hourglass_empty,
          size: 48,
          color: Colors.orange,
        ),
        const SizedBox(height: 16),
        Text(
          'Paiement en cours...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Veuillez confirmer le paiement sur votre téléphone',
          style: TextStyle(
            fontSize: 14,
            color: subTextColor,
          ),
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
                  Text(
                    'Montant:',
                    style: TextStyle(
                      color: subTextColor,
                    ),
                  ),
                  Text(
                    '${widget.invoice.totalAmount.toStringAsFixed(0)} FCFA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Téléphone:',
                    style: TextStyle(
                      color: subTextColor,
                    ),
                  ),
                  Text(
                    widget.phoneNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_confirmationCode.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.green,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Code de confirmation envoyé par SMS',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setState(() => _userConfirmationCode = value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Entrez le code reçu par SMS',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.grey[800] : Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _confirmWithCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Confirmer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Un nouveau code a été envoyé'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Renvoyer le code',
              style: TextStyle(
                color: primaryColor,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            widget.onCancel();
            Navigator.pop(context);
          },
          child: const Text(
            'Annuler le paiement',
            style: TextStyle(
              color: Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirming() {
    final themeProvider = context.watch<ThemeProvider>();
    final textColor = themeProvider.textColor;

    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          'Confirmation en cours...',
          style: TextStyle(
            fontSize: 16,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    final themeProvider = context.watch<ThemeProvider>();
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            size: 48,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Paiement réussi !',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'La facture a été marquée comme payée',
          style: TextStyle(
            fontSize: 14,
            color: subTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFailed() {
    final themeProvider = context.watch<ThemeProvider>();
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Erreur de paiement',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _error,
          style: TextStyle(
            fontSize: 14,
            color: subTextColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  widget.onCancel();
                  Navigator.pop(context);
                },
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _retryCount < _maxRetries
                    ? () {
                        setState(() {
                          _retryCount++;
                          _status = 'initializing';
                          _isLoading = true;
                        });
                        _initiatePayment();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: Text(
                  _retryCount < _maxRetries ? 'Réessayer' : 'Contacter le support',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}