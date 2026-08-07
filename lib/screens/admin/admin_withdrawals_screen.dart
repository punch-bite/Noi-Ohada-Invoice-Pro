// lib/screens/admin/admin_withdrawals_screen.dart
//
// 💰 ADMIN : traitement des demandes de retrait du portefeuille marchand.
// Liste les demandes (pending), permet de les marquer `paid` (le solde est
// décrémenté) ou `rejected`.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/wallet_service.dart';

class AdminWithdrawalsScreen extends StatefulWidget {
  const AdminWithdrawalsScreen({super.key});

  @override
  State<AdminWithdrawalsScreen> createState() => _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends State<AdminWithdrawalsScreen> {
  final WalletService _wallet = WalletService();
  List<Map<String, dynamic>> _withdrawals = [];
  final Map<String, String> _userEmails = {};
  bool _loading = true;
  bool _processing = false;
  String _filter = 'pending'; // 'pending' | 'all'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _withdrawals = await _wallet.getAllWithdrawals(
      status: _filter == 'pending' ? 'pending' : null,
    );
    // Résout les emails des utilisateurs pour un affichage lisible.
    final userIds = _withdrawals
        .map((w) => w['userId']?.toString() ?? '')
        .where((u) => u.isNotEmpty)
        .toSet();
    for (final uid in userIds) {
      if (_userEmails.containsKey(uid)) continue;
      try {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        _userEmails[uid] = doc.data()?['email']?.toString() ?? uid;
      } catch (_) {
        _userEmails[uid] = uid;
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _process(String id, String status) async {
    if (_processing) return;
    setState(() => _processing = true);
    final auth = context.read<AppAuthProvider>();
    final ok = await _wallet.setWithdrawalStatus(
      withdrawalId: id,
      status: status,
      processedBy: auth.user?.email ?? 'admin',
    );
    if (!mounted) return;
    setState(() => _processing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Retrait ${status == 'paid' ? 'payé ✅' : 'refusé'}'
            : 'Erreur lors du traitement'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    if (ok) await _load();
  }

  String _fmt(double amount) =>
      '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ')} FCFA';

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('💸 Demandes de retrait',
            style: TextStyle(color: text, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Filtre
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                _filterChip('pending', 'En attente', isDark, text),
                const SizedBox(width: 8),
                _filterChip('all', 'Toutes', isDark, text),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _withdrawals.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Text('Aucune demande de retrait.',
                                    style: TextStyle(color: Colors.grey)),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _withdrawals.length,
                            itemBuilder: (context, index) =>
                                _buildCard(_withdrawals[index], isDark, text, sub),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, bool isDark, Color text) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _filter = value);
        _load();
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
      labelStyle: TextStyle(
        color: selected ? Colors.white : text,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> w, bool isDark, Color text, Color sub) {
    final id = w['id']?.toString() ?? '';
    final userId = w['userId']?.toString() ?? '';
    final amount = (w['amount'] as num?)?.toDouble() ?? 0;
    final phone = w['phone']?.toString() ?? '';
    final status = (w['status'] ?? 'pending').toString();
    final isPending = status == 'pending';

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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending
              ? Colors.orange.withValues(alpha: 0.4)
              : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_fmt(amount),
                        style: TextStyle(
                            color: text,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      _userEmails[userId] ?? userId,
                      style: TextStyle(color: sub, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (phone.isNotEmpty)
                      Text('📱 $phone',
                          style: TextStyle(color: sub, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _processing ? null : () => _process(id, 'rejected'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Refuser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _processing ? null : () => _process(id, 'paid'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Marquer payé'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
