// lib/screens/dashboard/widgets/payment_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
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
      color: const Color(0xFFFBC02D), // Jaune/Ambre contrasté pour le dark mode
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
        const SnackBar(content: Text('Numéro de téléphone invalide (9 chiffres requis)')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    // Simuler le paiement
    await Future.delayed(const Duration(seconds: 2));

    // Mettre à jour le statut de la facture
    final updatedInvoice = _selectedInvoice!.copyWith(status: 'paid');
    await _db.updateInvoice(updatedInvoice);

    if (mounted) {
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
      // Évite que le clavier virtuel ne cache le formulaire
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
            // Handle de glissement
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
            Text(
              'Paiement Mobile Money',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sélectionnez une facture et effectuez le paiement',
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 20),

            // Contenu dynamique
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
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Aucune facture impayée',
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
                      // Sélection de la facture
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.grey[50],
                          border: Border.all(
                            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
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
                            style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
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

                      // Montant à payer affiché en évidence
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
                              'Montant à payer',
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

                      // Méthode de paiement
                      Text(
                        'Méthode de paiement',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._paymentMethods.map((method) => _buildPaymentMethodTile(method, isDark, textColor)),
                      const SizedBox(height: 20),

                      // Numéro de téléphone
                      TextFormField(
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Numéro de téléphone',
                          labelStyle: TextStyle(color: subTextColor),
                          hintText: '6X XX XX XX XX',
                          hintStyle: TextStyle(color: subTextColor.withOpacity(0.5)),
                          prefixIcon: Icon(Icons.phone, color: subTextColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                        ),
                        onChanged: (value) {
                          setState(() => _phoneNumber = value);
                        },
                      ),
                      const SizedBox(height: 24),

                      // Bouton de validation de l'action
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _processPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
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
                                  'Confirmer le paiement',
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
      ),
    );
  }

  Widget _buildPaymentMethodTile(PaymentMethod method, bool isDark, Color textColor) {
    final isSelected = _selectedMethod == method.id;
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedMethod = method.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? method.color.withOpacity(isDark ? 0.15 : 0.08) 
              : (isDark ? Colors.grey[900] : Colors.grey[50]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? method.color : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
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