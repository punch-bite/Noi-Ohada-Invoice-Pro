// lib/screens/stock/create_delivery_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/stock_service.dart';
import '../../../models/delivery.dart';

class CreateDeliveryScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final DeliveryType type;
  
  const CreateDeliveryScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.type,
  });

  @override
  State<CreateDeliveryScreen> createState() => _CreateDeliveryScreenState();
}

class _CreateDeliveryScreenState extends State<CreateDeliveryScreen> {
  final StockService _stockService = StockService();
  final _formKey = GlobalKey<FormState>();
  
  final _quantityController = TextEditingController();
  final _referenceController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _referenceController.dispose();
    _clientNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveDelivery() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final delivery = Delivery(
      productId: widget.productId,
      productName: widget.productName,
      quantity: int.parse(_quantityController.text),
      type: widget.type.toString(),
      reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
      clientName: _clientNameController.text.trim().isEmpty ? null : _clientNameController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    await _stockService.addDelivery(delivery);

    setState(() => _isLoading = false);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final bgColor = themeProvider.backgroundColor;
    final inputFillColor = themeProvider.inputFillColor;
    final inputBorderColor = themeProvider.inputBorderColor;

    final isIncoming = widget.type == DeliveryType.incoming;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          isIncoming ? 'Réception de stock' : 'Livraison',
          style: TextStyle(color: textColor),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saveDelivery,
            child: Text(
              'Valider',
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                color: cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        'Produit',
                        widget.productName,
                        isDark,
                        textColor,
                        subTextColor,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Type',
                        isIncoming ? 'Réception' : 'Livraison',
                        isDark,
                        textColor,
                        subTextColor,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _quantityController,
                        label: 'Quantité *',
                        hint: '0',
                        icon: Icons.numbers,
                        isDark: isDark,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        primaryColor: primaryColor,
                        inputFillColor: inputFillColor,
                        inputBorderColor: inputBorderColor,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Veuillez saisir la quantité';
                          }
                          if (int.tryParse(value) == null || int.parse(value) <= 0) {
                            return 'Quantité invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _referenceController,
                        label: 'N° de référence',
                        hint: 'Facture, commande, etc.',
                        icon: Icons.receipt,
                        isDark: isDark,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        primaryColor: primaryColor,
                        inputFillColor: inputFillColor,
                        inputBorderColor: inputBorderColor,
                      ),
                      if (isIncoming) ...[
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _clientNameController,
                          label: 'Fournisseur',
                          hint: 'Nom du fournisseur',
                          icon: Icons.business,
                          isDark: isDark,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primaryColor: primaryColor,
                          inputFillColor: inputFillColor,
                          inputBorderColor: inputBorderColor,
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _clientNameController,
                          label: 'Client',
                          hint: 'Nom du client',
                          icon: Icons.person,
                          isDark: isDark,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primaryColor: primaryColor,
                          inputFillColor: inputFillColor,
                          inputBorderColor: inputBorderColor,
                        ),
                      ],
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _notesController,
                        label: 'Notes',
                        hint: 'Informations complémentaires',
                        icon: Icons.note,
                        isDark: isDark,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        primaryColor: primaryColor,
                        inputFillColor: inputFillColor,
                        inputBorderColor: inputBorderColor,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bouton Valider
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveDelivery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isIncoming ? Colors.green : Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isIncoming ? 'Valider la réception' : 'Valider la livraison',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: subTextColor,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color primaryColor,
    required Color inputFillColor,
    required Color inputBorderColor,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int? maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: subTextColor),
        hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
        prefixIcon: Icon(icon, color: primaryColor),
        filled: true,
        fillColor: inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}