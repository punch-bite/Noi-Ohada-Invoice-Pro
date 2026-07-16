import 'dart:async';
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

  Timer? _statusTimer;
  String _status = 'initializing';
  String _transactionId = '';
  String _confirmationCode = '';
  String _error = '';
  bool _isLoading = false;
  String _userConfirmationCode = '';
  final int _retryCount = 0;
  final int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _notificationService.init();
    _initiatePayment();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  // --- Logique de paiement ---

  Future<void> _initiatePayment() async {
    if (!mounted) return;
    setState(() {
      _status = 'initializing';
      _isLoading = true;
    });

    try {
      final result = await _nochPayService.initiatePayment(
        amount: widget.invoice.totalAmount,
        currency: 'XAF',
        phoneNumber: widget.phoneNumber,
        invoiceNumber: widget.invoice.invoiceNumber,
        description: 'Paiement facture ${widget.invoice.invoiceNumber}',
      );

      if (!mounted) return;

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
          amount: widget.invoice.totalAmount,
          invoiceNumber: widget.invoice.invoiceNumber,
        );

        _startAutoCheck();
      } else {
        setState(() {
          _status = 'failed';
          _error = result['error'] ?? 'Erreur d\'initialisation';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'failed';
        _error = 'Connexion interrompue';
        _isLoading = false;
      });
    }
  }

  void _startAutoCheck() {
    int checks = 0;
    const maxChecks = 12;

    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted || _status == 'success' || _status == 'failed' || checks >= maxChecks) {
        timer.cancel();
        return;
      }
      checks++;
      await _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus() async {
    try {
      final result = await _nochPayService.checkPaymentStatus(_transactionId);
      if (!mounted) return;

      if (result['success'] == true && result['status'] == 'paid') {
        setState(() => _status = 'success');
        await _completePayment();
      } else if (result['success'] == true && result['status'] == 'failed') {
        setState(() => _status = 'failed');
      }
    } catch (e) {
      debugPrint("Erreur vérification: $e");
    }
  }

  Future<void> _confirmWithCode() async {
    if (_userConfirmationCode.length < 4) return;

    setState(() {
      _status = 'confirming';
      _isLoading = true;
    });

    final result = await _nochPayService.confirmPaymentWithCode(
      transactionId: _transactionId,
      confirmationCode: _userConfirmationCode,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() => _status = 'success');
      await _completePayment();
    } else {
      setState(() {
        _status = 'pending';
        _error = result['error'] ?? 'Code invalide';
        _isLoading = false;
      });
    }
  }

  Future<void> _completePayment() async {
    _statusTimer?.cancel();
    
    final updatedInvoice = widget.invoice.copyWith(status: 'paid');
    await _db.updateInvoice(updatedInvoice);
    await _notificationService.notifyInvoicePaid(widget.invoice.invoiceNumber);
    await _notificationService.notifyPaymentReceived(widget.invoice.totalAmount);
    await _nochPayService.removePendingTransaction(_transactionId);

    if (!mounted) return;
    widget.onSuccess();
    Navigator.pop(context);
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: themeProvider.cardColor,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Paiement NochPay", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.textColor)),
            const SizedBox(height: 20),
            _buildStatusContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContent() {
    switch (_status) {
      case 'initializing': return const CircularProgressIndicator();
      case 'pending': return _buildPendingView();
      case 'success': return const Icon(Icons.check_circle, color: Colors.green, size: 50);
      case 'failed': return const Icon(Icons.error, color: Colors.red, size: 50);
      default: return const CircularProgressIndicator();
    }
  }

  Widget _buildPendingView() {
    return Column(
      children: [
        const Text("Veuillez confirmer sur votre téléphone"),
        TextField(onChanged: (v) => _userConfirmationCode = v),
        ElevatedButton(onPressed: _confirmWithCode, child: const Text("Confirmer"))
      ],
    );
  }
}