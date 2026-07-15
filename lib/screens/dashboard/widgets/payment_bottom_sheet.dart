// lib/screens/dashboard/widgets/payment_bottom_sheet.dart
import 'package:flutter/material.dart';
import '../../../services/database_service.dart';
import '../../../models/invoice.dart';

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
  List<Invoice> _invoices = [];
  Invoice? _selectedInvoice;
  String _selectedMethod = 'orange_money';
  String _phoneNumber = '';
  bool _isLoading = true;
  bool _isProcessing = false;

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
  ];

  @override
  void initState() {
    super.initState();
    _loadUnpaidInvoices();
  }

  Future<void> _loadUnpaidInvoices() async {
    setState(() => _isLoading = true);
    final allInvoices = await _db.getInvoices();
    final unpaid = allInvoices.where(
      (inv) => inv.status != 'paid' && inv.status != 'cancelled'
    ).toList();
    setState(() {
      _invoices = unpaid;
      _isLoading = false;
    });
  }

  Future<void> _processPayment() async {
    if (_selectedInvoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une facture')),
      );
      return;
    }

    if (_phoneNumber.isEmpty || _phoneNumber.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro de téléphone invalide')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    // Simuler le paiement
    await Future.delayed(const Duration(seconds: 2));

    // Mettre à jour le statut de la facture
    final updatedInvoice = _selectedInvoice!.copyWith(status: 'paid');
    await _db.updateInvoice(updatedInvoice);

    setState(() => _isProcessing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ Paiement de ${_selectedInvoice!.invoiceNumber} effectué avec succès',
        ),
        backgroundColor: Colors.green,
      ),
    );

    widget.onPaymentComplete();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Paiement Mobile Money',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sélectionnez une facture et effectuez le paiement',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),

          // Contenu
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_invoices.isEmpty)
            const Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 48),
                  SizedBox(height: 8),
                  Text('Aucune facture impayée'),
                ],
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Sélection de la facture
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Invoice>(
                          value: _selectedInvoice,
                          isExpanded: true,
                          hint: const Text('Sélectionner une facture'),
                          items: _invoices.map((invoice) {
                            return DropdownMenuItem(
                              value: invoice,
                              child: Text(
                                '${invoice.invoiceNumber} - ${invoice.totalAmount.toStringAsFixed(0)} FCFA',
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

                    // Montant
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Montant à payer',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _selectedInvoice != null
                                ? '${_selectedInvoice!.totalAmount.toStringAsFixed(0)} FCFA'
                                : '-',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Méthode de paiement
                    const Text(
                      'Méthode de paiement',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._paymentMethods.map((method) => _buildPaymentMethodTile(method)),
                    const SizedBox(height: 16),

                    // Numéro de téléphone
                    TextFormField(
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Numéro de téléphone',
                        hintText: '6X XX XX XX XX',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onChanged: (value) {
                        setState(() => _phoneNumber = value);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Bouton Payer
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _processPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isProcessing
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Traitement en cours...'),
                                ],
                              )
                            : const Text(
                                'Payer',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTile(PaymentMethod method) {
    final isSelected = _selectedMethod == method.id;
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedMethod = method.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? method.color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? method.color : Colors.grey[200]!,
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
                color: isSelected ? method.color : Colors.black87,
              ),
            ),
            const Spacer(),
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

  PaymentMethod({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}