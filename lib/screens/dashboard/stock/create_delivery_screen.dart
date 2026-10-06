// lib/screens/stock/create_delivery_screen.dart
//
// 🎨 Réception / Livraison épurée — header coloré par type, formulaire clair.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/stock_service.dart';
import '../../../models/delivery.dart';
import '../../../widgets/glass_widgets.dart';

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
      reference: _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
      clientName: _clientNameController.text.trim().isEmpty
          ? null
          : _clientNameController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    try {
      await _stockService.addDelivery(delivery);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la validation : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;
    final text = theme.textColor;
    final sub = theme.subTextColor;

    final isIncoming = widget.type == DeliveryType.incoming;
    final accentColor =
        isIncoming ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          isIncoming ? 'Réception' : 'Livraison',
          style: TextStyle(
            color: text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: text, size: 22),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveDelivery,
            style: TextButton.styleFrom(
              foregroundColor: accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accentColor),
                  )
                : const Text(
                    'Valider',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor,
                      accentColor.withValues(alpha: 0.75),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        isIncoming
                            ? Icons.south_rounded
                            : Icons.north_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isIncoming
                                ? 'ENTRÉE DE STOCK'
                                : 'SORTIE DE STOCK',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(
                    begin: -0.1,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: 28),

              // ── Section : Détails du mouvement ──
              _sectionLabel('Détails', sub),
              const SizedBox(height: 10),
              _field(
                controller: _quantityController,
                label: 'Quantité',
                hint: '0',
                icon: Icons.numbers_rounded,
                isDark: isDark,
                text: text,
                sub: sub,
                primary: accentColor,
                keyboard: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  if (int.tryParse(v) == null || int.parse(v) <= 0) {
                    return 'Quantité invalide';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
              const SizedBox(height: 12),
              _field(
                controller: _referenceController,
                label: 'Référence',
                hint: 'Facture, commande, bon de livraison…',
                icon: Icons.receipt_long_outlined,
                isDark: isDark,
                text: text,
                sub: sub,
                primary: accentColor,
              ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
              const SizedBox(height: 12),
              _field(
                controller: _clientNameController,
                label: isIncoming ? 'Fournisseur' : 'Client',
                hint: isIncoming
                    ? 'Nom du fournisseur'
                    : 'Nom du client',
                icon: isIncoming
                    ? Icons.business_outlined
                    : Icons.person_outline_rounded,
                isDark: isDark,
                text: text,
                sub: sub,
                primary: accentColor,
              ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
              const SizedBox(height: 24),

              // ── Section : Notes ──
              _sectionLabel('Notes', sub),
              const SizedBox(height: 10),
              _field(
                controller: _notesController,
                label: 'Remarques',
                hint: 'Informations complémentaires (optionnel)',
                icon: Icons.notes_rounded,
                isDark: isDark,
                text: text,
                sub: sub,
                primary: accentColor,
                maxLines: 3,
              ).animate().fadeIn(delay: 250.ms, duration: 300.ms),
              const SizedBox(height: 32),

              // ── Bouton principal ──
              GradientButton(
                label: isIncoming
                    ? 'Valider la réception'
                    : 'Valider la livraison',
                icon: isIncoming ? Icons.south_rounded : Icons.north_rounded,
                height: 54,
                loading: _isLoading,
                gradientColors: isIncoming
                    ? const [Color(0xFF10B981), Color(0xFF34D399)]
                    : const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                onPressed: _saveDelivery,
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String title, Color sub) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: sub,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color text,
    required Color sub,
    required Color primary,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(color: text, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: sub,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: sub.withValues(alpha: 0.5),
          fontSize: 13.5,
        ),
        prefixIcon: Icon(icon, size: 20, color: primary.withValues(alpha: 0.8)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.025),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: primary.withValues(alpha: 0.8),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.red.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.red.withValues(alpha: 0.8),
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        isDense: true,
      ),
    );
  }
}