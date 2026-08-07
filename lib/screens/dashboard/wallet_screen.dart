// lib/screens/dashboard/wallet_screen.dart
//
// 💰 Portefeuille marchand : solde des encaissements clients (ENKAP), historique
// des crédits et demandes de retrait. Le retrait est traité par la plateforme.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/wallet_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _wallet = WalletService();
  double _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _withdrawals = [];
  bool _loading = true;
  bool _requesting = false;

  String get _uid => context.read<AppAuthProvider>().user?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _uid;
    final results = await Future.wait([
      _wallet.getBalance(uid),
      _wallet.getTransactions(uid),
      _wallet.getWithdrawals(uid),
    ]);
    if (!mounted) return;
    setState(() {
      _balance = results[0] as double;
      _transactions = results[1] as List<Map<String, dynamic>>;
      _withdrawals = results[2] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  String _fmt(double amount) =>
      '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ')} FCFA';

  Future<void> _requestWithdrawal() async {
    final amountController = TextEditingController();
    final phoneController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Demander un retrait'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'La plateforme traite votre retrait (paiement via Mobile Money). '
              'Un solde suffisant est requis.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant (FCFA)',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro de réception (Orange / MTN)',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    final phone = phoneController.text.trim();
    if (amount <= 0) {
      _snack('Montant invalide', Colors.orange);
      return;
    }
    if (phone.length < 9) {
      _snack('Numéro de réception invalide', Colors.orange);
      return;
    }
    if (amount > _balance) {
      _snack('Montant supérieur au solde disponible', Colors.orange);
      return;
    }

    setState(() => _requesting = true);
    final ok = await _wallet.requestWithdrawal(
      userId: _uid,
      amount: amount,
      phone: phone,
    );
    if (!mounted) return;
    setState(() => _requesting = false);
    if (ok) {
      _snack('Demande de retrait envoyée ✅', Colors.green);
      await _load();
    } else {
      _snack('Échec de la demande de retrait', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final primary = theme.primaryColor;
    final bg = theme.backgroundColor;
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('💰 Portefeuille',
            style: TextStyle(color: text, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== Solde =====
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primary, primary.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Solde disponible',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 8),
                          Text(_fmt(_balance),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Text(
                            'Encaissements clients crédités automatiquement à '
                            'chaque paiement en ligne confirmé.',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ===== Bouton retrait =====
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _requesting || _balance <= 0
                            ? null
                            : _requestWithdrawal,
                        icon: _requesting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.account_balance_wallet_outlined),
                        label: Text(
                          _balance <= 0
                              ? 'Retirer (solde vide)'
                              : 'Demander un retrait',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ===== Historique des crédits =====
                    Text('Encaissements',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: text)),
                    const SizedBox(height: 8),
                    if (_transactions.isEmpty)
                      _emptyBox('Aucun encaissement pour le moment.', sub)
                    else
                      ..._transactions.take(20).map((t) => _txTile(t, isDark, text, sub)),
                    const SizedBox(height: 24),

                    // ===== Demandes de retrait =====
                    Text('Demandes de retrait',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: text)),
                    const SizedBox(height: 8),
                    if (_withdrawals.isEmpty)
                      _emptyBox('Aucune demande de retrait.', sub)
                    else
                      ..._withdrawals.take(10).map((w) => _withdrawalTile(w, isDark, text, sub)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _emptyBox(String message, Color sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: sub, fontSize: 13)),
    );
  }

  Widget _txTile(Map<String, dynamic> t, bool isDark, Color text, Color sub) {
    final amount = (t['amount'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_outlined, color: Colors.green, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['description'] ?? 'Encaissement',
                    style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 13)),
                if ((t['reference'] ?? '').toString().isNotEmpty)
                  Text(t['reference'].toString(),
                      style: TextStyle(color: sub, fontSize: 11)),
              ],
            ),
          ),
          Text('+${_fmt(amount)}',
              style: const TextStyle(
                  color: Colors.green, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _withdrawalTile(Map<String, dynamic> w, bool isDark, Color text, Color sub) {
    final amount = (w['amount'] as num?)?.toDouble() ?? 0;
    final status = (w['status'] ?? 'pending').toString();
    final Color statusColor = status == 'paid'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : Colors.orange;
    final String statusLabel = status == 'paid'
        ? 'Payé'
        : status == 'rejected'
            ? 'Refusé'
            : 'En attente';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined, color: statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('-${_fmt(amount)}',
                    style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 13)),
                Text('→ ${w['phone'] ?? ''}',
                    style: TextStyle(color: sub, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(statusLabel,
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
