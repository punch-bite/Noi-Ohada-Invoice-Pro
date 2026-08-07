// lib/screens/dashboard/widgets/payment_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/database_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/enkap_service.dart';
import '../../../widgets/enkap_checkout_dialog.dart';
import '../../../models/invoice.dart';
import '../../../models/invoice_status.dart';

class PaymentBottomSheet extends StatefulWidget {
  final VoidCallback onPaymentComplete;
  
  const PaymentBottomSheet({
    super.key,
    required this.onPaymentComplete,
  });

  @override
  State<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet> {
  final DatabaseService _db = DatabaseService();
  final NotificationService _notificationService = NotificationService();
  List<Invoice> _invoices = [];
  Invoice? _selectedInvoice;
  bool _isLoading = true;
  bool _isProcessing = false;

  // Méthode de paiement choisie : 'cash' | mobile money | carte
  String _selectedMethod = 'cash';
  String _phoneNumber = '';

  static final List<PaymentMethod> _paymentMethods = [
    PaymentMethod(
      id: 'cash',
      name: 'Cash (validation manuelle)',
      icon: Icons.payments_outlined,
      color: Colors.green,
    ),
    PaymentMethod(
      id: EnkapService.methodOrangeMoney,
      name: 'Orange Money',
      icon: Icons.phone_android,
      color: Colors.orange,
    ),
    PaymentMethod(
      id: EnkapService.methodMtnMoney,
      name: 'MTN Mobile Money',
      icon: Icons.phone_android,
      color: const Color(0xFFFFD700),
    ),
    PaymentMethod(
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
    _loadUnpaidInvoices();
  }

  Future<void> _loadUnpaidInvoices() async {
    setState(() => _isLoading = true);
    final allInvoices = await _db.getInvoices();
    // On exclut uniquement les factures déjà payées ou annulées.
    final payable = allInvoices
        .where(
          (inv) => !InvoiceStatus.fromValue(inv.status).isPaid &&
              !InvoiceStatus.fromValue(inv.status).isCancelled,
        )
        .toList();
    setState(() {
      _invoices = payable;
      _isLoading = false;
    });
  }

  String _nextManualStatus(Invoice invoice) {
    final current = InvoiceStatus.fromValue(invoice.status);
    switch (current) {
      case InvoiceStatus.draft:
        return InvoiceStatus.sent.value;
      case InvoiceStatus.sent:
      case InvoiceStatus.overdue:
        return InvoiceStatus.paid.value;
      default:
        return InvoiceStatus.sent.value;
    }
  }

  String _statusActionLabel(Invoice invoice) {
    switch (InvoiceStatus.fromValue(invoice.status)) {
      case InvoiceStatus.draft:
        return 'Marquer comme envoyée';
      case InvoiceStatus.sent:
      case InvoiceStatus.overdue:
        return 'Confirmer le paiement (manuel)';
      default:
        return 'Confirmer le paiement (manuel)';
    }
  }

  /// Point d'entrée unique : route vers le bon flux selon le moyen choisi.
  Future<void> _processPayment() async {
    if (_selectedInvoice == null) {
      _showSnackBar('Veuillez sélectionner une facture', Colors.orange);
      return;
    }

    if (_selectedMethod == 'cash') {
      await _processCashPayment();
    } else {
      await _processOnlinePayment();
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

  /// Lance le paiement en ligne via ENKAP (Orange Money / MTN / Carte).
  /// Le client règle sur la page sécurisée E-nkap (invite USSD avec son
  /// code secret pour le Mobile Money, ou carte) ; la confirmation est
  /// vérifiée automatiquement puis la facture est marquée payée.
  Future<void> _processOnlinePayment() async {
    final invoice = _selectedInvoice!;

    final isCard = _selectedMethod == EnkapService.methodCard;
    if (!isCard && (_phoneNumber.isEmpty || _phoneNumber.length < 9)) {
      _showSnackBar(
        'Veuillez saisir un numéro de téléphone valide (9 chiffres)',
        Colors.orange,
      );
      return;
    }

    final methodName = _paymentMethods
        .firstWhere((m) => m.id == _selectedMethod,
            orElse: () => _paymentMethods.first)
        .name;
    final reference =
        'FAC${invoice.invoiceNumber}-${DateTime.now().millisecondsSinceEpoch}';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => EnkapCheckoutDialog(
        amount: invoice.totalAmount,
        currency: 'XAF',
        description: 'Paiement facture ${invoice.invoiceNumber}',
        merchantReference: reference,
        providerName: methodName,
        phoneNumber: _phoneNumber,
        onSuccess: () async {
          await _markInvoicePaid(invoice);
          if (!mounted) return;
          widget.onPaymentComplete();
          Navigator.pop(dialogContext);
          Navigator.pop(context);
        },
        onCancel: () {},
      ),
    );
  }

  /// Marque la facture comme payée après confirmation ENKAP.
  Future<void> _markInvoicePaid(Invoice invoice) async {
    final updated = invoice.copyWith(
      status: InvoiceStatus.paid.value,
      isSynced: false,
    );
    await _db.updateInvoice(updated);
    await _notificationService.notifyInvoicePaid(invoice.invoiceNumber);
    await _notificationService.notifyPaymentReceived(invoice.totalAmount);
  }

  Future<void> _processCashPayment() async {
    if (_selectedInvoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une facture')),
      );
      return;
    }

    final invoice = _selectedInvoice!;
    final current = InvoiceStatus.fromValue(invoice.status);
    final nextStatus = _nextManualStatus(invoice);

    setState(() => _isProcessing = true);

    // ✅ Validation manuelle du cycle de facturation :
    // - brouillon  → envoyée
    // - envoyée/en retard → payée  (confirmation manuelle du commerçant)
    if (nextStatus == InvoiceStatus.paid.value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Confirmer le paiement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vous êtes sur le point de marquer cette facture comme payée.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Facture : ${invoice.invoiceNumber}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Montant : ${invoice.totalAmount.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Confirmez-vous avoir bien reçu le paiement ?',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() => _isProcessing = false);
        return;
      }
    }

    // ✅ Applique la transition manuelle du cycle.
    final updatedInvoice = invoice.copyWith(
      status: nextStatus,
      isSynced: false,
    );
    await _db.updateInvoice(updatedInvoice);
    await _notificationService.notifyInvoicePaid(invoice.invoiceNumber);
    await _notificationService.notifyPaymentReceived(invoice.totalAmount);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: current == InvoiceStatus.draft
            ? const Text('Facture marquée comme envoyée ✅')
            : const Text('Paiement confirmé manuellement ✅'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    widget.onPaymentComplete();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final primaryColor = themeProvider.primaryColor;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.verified_user_outlined,
                    color: primaryColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Validation manuelle du paiement',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sélectionnez une facture puis validez manuellement le paiement reçu',
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_invoices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.green, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Aucune facture à valider',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.grey[50],
                          border: Border.all(
                            color: isDark
                                ? Colors.grey[800]!
                                : Colors.grey[200]!,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Invoice>(
                            value: _selectedInvoice,
                            isExpanded: true,
                            dropdownColor: cardColor,
                            hint: Text(
                              'Sélectionner une facture',
                              style: TextStyle(color: subTextColor),
                            ),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            items: _invoices.map((invoice) {
                              return DropdownMenuItem(
                                value: invoice,
                                child: Text(
                                  '${invoice.invoiceNumber} - '
                                  '${invoice.totalAmount.toStringAsFixed(0)} FCFA'
                                  '  (${InvoiceStatus.labelFromValue(invoice.status)})',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedInvoice = value);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Montant à valider',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            Text(
                              _selectedInvoice != null
                                  ? '${_selectedInvoice!.totalAmount.toStringAsFixed(0)} FCFA'
                                  : '-',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                        const SizedBox(height: 20),

                      // Moyen de paiement
                      Text(
                        'Moyen de paiement',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._paymentMethods.map(
                        (method) => _buildPaymentMethodTile(
                          method,
                          isDark,
                          textColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_selectedMethod != 'cash' &&
                          _selectedMethod != EnkapService.methodCard) ...[
                        TextFormField(
                          enabled: !_isProcessing,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Numéro de téléphone du client',
                            labelStyle: TextStyle(color: subTextColor),
                            hintText: '6X XX XX XX XX',
                            hintStyle: TextStyle(
                                color: subTextColor.withOpacity(0.5)),
                            prefixIcon: Icon(Icons.phone, color: subTextColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor:
                                isDark ? Colors.grey[900] : Colors.grey[100],
                          ),
                          onChanged: (value) =>
                              setState(() => _phoneNumber = value),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_selectedMethod == 'cash' &&
                          _selectedInvoice != null) ...[
                        Text(
                          'Cycle de validation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildStatusRow(_selectedInvoice!),
                        const SizedBox(height: 20),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _processPayment,
                          icon: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _selectedMethod == 'cash'
                                      ? (_selectedInvoice != null &&
                                              InvoiceStatus.fromValue(
                                                      _selectedInvoice!
                                                          .status) ==
                                                  InvoiceStatus.draft
                                          ? Icons.send_outlined
                                          : Icons.check_circle_outline)
                                      : Icons.lock_clock_outlined,
                                  size: 20,
                                ),
                          label: Text(
                            _isProcessing
                                ? 'Traitement...'
                                : _selectedInvoice == null
                                    ? 'Sélectionner une facture'
                                    : _selectedMethod == 'cash'
                                        ? _statusActionLabel(_selectedInvoice!)
                                        : 'Initier le paiement en ligne',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedMethod == 'cash'
                                ? (_selectedInvoice != null &&
                                        InvoiceStatus.fromValue(
                                                _selectedInvoice!.status) ==
                                            InvoiceStatus.draft
                                    ? Colors.blue
                                    : Colors.green)
                                : primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline,
                              size: 14, color: subTextColor),
                          const SizedBox(width: 6),
                          Text(
                            _selectedMethod == 'cash'
                                ? 'Validation manuelle — cash reçu'
                                : 'Paiement sécurisé via E-nkap',
                            style: TextStyle(
                                fontSize: 12, color: subTextColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(Invoice invoice) {
    final cycle = InvoiceStatus.values;
    final current = InvoiceStatus.fromValue(invoice.status);
    final currentIndex = cycle.indexWhere((s) => s.value == current.value);

    return Row(
      children: cycle.map((status) {
        final idx = cycle.indexOf(status);
        final isReached = idx <= currentIndex;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      isReached ? status.color : Colors.grey.withOpacity(0.2),
                  child: Icon(
                    idx < currentIndex ? Icons.check : Icons.circle,
                    size: idx < currentIndex ? 16 : 10,
                    color: isReached ? Colors.white : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 9,
                    color: isReached ? status.color : Colors.grey,
                    fontWeight:
                        isReached ? FontWeight.w600 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentMethodTile(
    PaymentMethod method,
    bool isDark,
    Color textColor,
  ) {
    final isSelected = _selectedMethod == method.id;

    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? method.color.withOpacity(isDark ? 0.15 : 0.08)
              : (isDark ? Colors.grey[900] : Colors.grey[50]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? method.color
                : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
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
            if (isSelected)
              Icon(Icons.check_circle, color: method.color, size: 20),
          ],
        ),
      ),
    );
  }
}

class PaymentMethod {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const PaymentMethod({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}