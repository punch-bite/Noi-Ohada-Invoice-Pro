// lib/screens/dev/enkap_test_screen.dart
//
// 🧪 Écran de TEST du paiement ENKAP (Orange Money / MTN / Carte) de bout en
// bout : crée une commande réelle, ouvre la page E-nkap et vérifie la
// confirmation. Utilisé pour valider l'intégration avant la production.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/enkap_service.dart';
import '../../widgets/enkap_checkout_dialog.dart';

class EnkapTestScreen extends StatefulWidget {
  const EnkapTestScreen({super.key});

  @override
  State<EnkapTestScreen> createState() => _EnkapTestScreenState();
}

class _EnkapTestScreenState extends State<EnkapTestScreen> {
  final _amountController = TextEditingController(text: '100');
  final _phoneController = TextEditingController(text: '650000000');
  String _selectedMethod = EnkapService.methodOrangeMoney;
  bool _processing = false;

  final List<({String id, String name, IconData icon, Color color})>
      _methods = [
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
      name: 'Carte bancaire',
      icon: Icons.credit_card,
      color: Colors.purple,
    ),
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _testPayment() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      _snack('Montant invalide', Colors.orange);
      return;
    }
    final isCard = _selectedMethod == EnkapService.methodCard;
    if (!isCard && (_phoneController.text.length < 9)) {
      _snack('Numéro de téléphone invalide', Colors.orange);
      return;
    }

    setState(() => _processing = true);
    final method = _methods.firstWhere((m) => m.id == _selectedMethod);
    final reference = 'TEST-${DateTime.now().millisecondsSinceEpoch}';

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => EnkapCheckoutDialog(
          amount: amount,
          currency: 'XAF',
          description: 'Test de paiement NOI OHADA',
          merchantReference: reference,
          providerName: method.name,
          phoneNumber: isCard ? null : _phoneController.text,
          customerName: 'Test Client',
          customerEmail: 'test@noi-ohada.cm',
          onSuccess: () {
            if (mounted) setState(() => _processing = false);
            _snack('✅ Paiement confirmé ! Réf : $reference', Colors.green);
          },
          onCancel: () {
            if (mounted) setState(() => _processing = false);
            _snack('Paiement annulé', Colors.orange);
          },
        ),
      );
    } finally {
      // Ne jamais laisser le bouton sur « spinner » si le dialogue se ferme
      // sans callback (filet de sécurité).
      if (mounted && _processing) setState(() => _processing = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;
    final primary = theme.primaryColor;
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('🧪 Test paiement E-nkap',
            style: TextStyle(color: text, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Crée une vraie commande ENKAP, ouvre la page de paiement '
                'puis vérifie la confirmation (Orange Money / MTN / Carte).',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            Text('Montant (XAF)',
                style: TextStyle(color: sub, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: text),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.payments_outlined, color: primary),
              ),
            ),
            const SizedBox(height: 16),
            Text('Numéro de téléphone (Mobile Money)',
                style: TextStyle(color: sub, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: text),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.phone, color: primary),
              ),
            ),
            const SizedBox(height: 20),
            Text('Méthode de paiement',
                style: TextStyle(color: sub, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._methods.map((m) {
              final selected = _selectedMethod == m.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedMethod = m.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? m.color.withValues(alpha: 0.12)
                        : (isDark ? Colors.grey[900] : Colors.grey[50]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? m.color : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(m.icon, color: m.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(m.name,
                            style: TextStyle(
                                color: text,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
                      ),
                      if (selected) Icon(Icons.check_circle, color: m.color),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _processing ? null : _testPayment,
                icon: _processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.payment),
                label: const Text('Tester le paiement',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '⚠️ Ne réalisez le paiement qu\'avec un petit montant de test.',
                style: TextStyle(color: sub, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
