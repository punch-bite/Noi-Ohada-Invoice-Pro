import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/nochpay_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/invoice.dart';
import 'package:share_plus/share_plus.dart';

class NochPayPaymentDialog extends StatefulWidget {
  final Invoice invoice;
  final String phoneNumber;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;
  final String paymentMethod;

  const NochPayPaymentDialog({
    super.key,
    required this.invoice,
    required this.phoneNumber,
    required this.onSuccess,
    required this.onCancel,
    this.paymentMethod = NochPayService.methodOrangeMoney,
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
  String _error = '';
  String _paymentUrl = '';
  bool _isLoading = false;
  String _userConfirmationCode = '';

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
        paymentMethod: widget.paymentMethod,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        setState(() {
          _status = 'failed';
          _error = result['error'] ?? 'Erreur d\'initialisation';
          _isLoading = false;
        });
        return;
      }

      final reference = (result['reference'] ?? result['transaction_id']) as String;

      setState(() {
        _transactionId = reference;
        _status = 'pending';
        _isLoading = false;
      });

      await _nochPayService.savePendingTransaction(
        transactionId: reference,
        invoiceId: widget.invoice.id,
        phoneNumber: widget.phoneNumber,
        amount: widget.invoice.totalAmount,
        invoiceNumber: widget.invoice.invoiceNumber,
        paymentMethod: widget.paymentMethod,
      );

      // 🔥 Gestion du flux selon le moyen de paiement :
      //   - Mobile Money → déclenchement USSD (invite sur le téléphone du client).
      //   - Carte bancaire → lien de paiement sécurisé (Collect) à copier/envoyer.
      final isCard =
          widget.paymentMethod == NochPayService.methodCard;

      if (isCard) {
        // Carte bancaire : afficher le lien NotchPay Collect
        final authorizationUrl = result['authorization_url'] as String?;
                _paymentUrl = (authorizationUrl != null && authorizationUrl.isNotEmpty)
            ? authorizationUrl
            : 'https://pay.notchpay.co/payments/$reference';
        setState(() {});
        // On surveille aussi le statut pour détecter le règlement par carte.
        _startAutoCheck();
      } else {
        // Mobile Money : déclencher la confirmation USSD
        final ussd = await _nochPayService.processMobileMoneyUSSD(
          reference: reference,
          method: widget.paymentMethod,
          phoneNumber: widget.phoneNumber,
        );
        if (ussd['success'] != true) {
          if (!mounted) return;
          setState(() {
            _status = 'failed';
            _error = ussd['error'] ?? 'Erreur lors de la demande USSD';
          });
          return;
        }
        _startAutoCheck();
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
      if (!mounted ||
          _status == 'success' ||
          _status == 'failed' ||
          checks >= maxChecks) {
        timer.cancel();
        return;
      }
      checks++;
      await _checkPaymentStatus();
    });
  }

    /// Partage le lien de paiement sécurisé (par SMS / WhatsApp / copie)
  /// quand le client choisit de payer par carte bancaire via NotchPay Collect.
  Future<void> _sharePaymentLink() async {
    final message = 'Veuillez régler votre facture '
        '${widget.invoice.invoiceNumber} '
        'd\'un montant de ${widget.invoice.totalAmount.toStringAsFixed(0)} FCFA '
        'via ce lien sécurisé : $_paymentUrl';
    await SharePlus.instance.share(ShareParams(text: message));
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

    final updatedInvoice =
        widget.invoice.copyWith(status: 'paid', isSynced: false);
    await _db.updateInvoice(updatedInvoice);
    await _notificationService.notifyInvoicePaid(widget.invoice.invoiceNumber);
    await _notificationService
        .notifyPaymentReceived(widget.invoice.totalAmount);
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
            Text("Paiement NochPay",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor)),
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
        return const CircularProgressIndicator();
      case 'pending':
        return _buildPendingView();
      default:
        return const CircularProgressIndicator();
    }
  }

    Widget _buildPendingView() {
    final isCard = widget.paymentMethod == NochPayService.methodCard;

    if (isCard) {
      // 🔴 Carte bancaire → lien sécurisé NotchPay Collect à transmettre au client.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.credit_card,
              size: 48, color: Colors.purple.shade300),
          const SizedBox(height: 12),
          const Text(
            'Paiement par carte bancaire',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Envoyez ce lien sécurisé à votre client pour qu\'il règle '
            'par carte bancaire. Le paiement sera détecté automatiquement.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SelectableText(
            _paymentUrl,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _sharePaymentLink,
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Envoyer le lien'),
              ),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _paymentUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Lien de paiement copié ✅'),
                        duration: Duration(seconds: 2)),
                  );
                },
                child: const Text('Copier'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _confirmWithCode,
            child: const Text('J\'ai reçu le paiement', style: TextStyle(color: Colors.green)),
          ),
        ],
      );
    }

    // ✅ Mobile Money (USSD) → le client reçoit une invite USSD sur son téléphone.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.smartphone,
            size: 48, color: Colors.orange.shade400),
        const SizedBox(height: 12),
        const Text(
          'Invite USSD envoyée',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        const Text(
          'Votre client va recevoir une invite USSD sur son téléphone.\n'
          'Demandez-lui de saisir son code PIN pour confirmer le paiement.\n'
          'Le statut est vérifié automatiquement…',
          style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const CircularProgressIndicator(strokeWidth: 2),
      ],
    );
  }
}
