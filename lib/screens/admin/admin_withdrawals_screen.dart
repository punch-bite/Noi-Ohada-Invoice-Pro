// lib/screens/admin/admin_withdrawals_screen.dart
//
// 💸 Retraits — épuré : filtre segmenté, cards bordées, actions animées.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    _withdrawals = await _wallet.getAllWithdrawals(
      status: _filter == 'pending' ? 'pending' : null,
    );

    final userIds = _withdrawals
        .map((w) => w['userId']?.toString() ?? '')
        .where((u) => u.isNotEmpty)
        .toSet();
    for (final uid in userIds) {
      if (_userEmails.containsKey(uid)) continue;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
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
    final messenger = ScaffoldMessenger.of(context);

    final ok = await _wallet.setWithdrawalStatus(
      withdrawalId: id,
      status: status,
      processedBy: auth.user?.email ?? 'admin',
    );
    if (!mounted) return;
    setState(() => _processing = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Retrait ${status == 'paid' ? 'payé ✅' : 'refusé'}'
            : 'Erreur lors du traitement'),
        backgroundColor: ok ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    if (ok) await _load();
  }

  String _fmt(double amount) =>
      '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ')} FCFA';

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final text = theme.textColor;
    final sub = theme.subTextColor;
    final bg = theme.backgroundColor;
    final primary = theme.primaryColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Retraits',
          style: TextStyle(
            color: text,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filtre segmenté
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _filterBtn('pending', 'En attente', primary, text),
                  _filterBtn('all', 'Toutes', primary, text),
                ],
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: primary))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: primary,
                    child: _withdrawals.isEmpty
                        ? _emptyState(text, sub, primary)
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(20, 0, 20, 32),
                            itemCount: _withdrawals.length,
                            itemBuilder: (context, index) => _buildCard(
                              _withdrawals[index],
                              isDark,
                              text,
                              sub,
                              primary,
                              theme.cardColor,
                              index: index,
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterBtn(
      String value, String label, Color primary, Color text) {
    final selected = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _filter = value);
          _load();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : text,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    Map<String, dynamic> w,
    bool isDark,
    Color text,
    Color sub,
    Color primary,
    Color card, {
    required int index,
  }) {
    final id = w['id']?.toString() ?? '';
    final userId = w['userId']?.toString() ?? '';
    final amount = (w['amount'] as num?)?.toDouble() ?? 0;
    final phone = w['phone']?.toString() ?? '';
    final status = (w['status'] ?? 'pending').toString();
    final isPending = status == 'pending';

    final statusColor = status == 'paid'
        ? const Color(0xFF10B981)
        : status == 'rejected'
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);
    final statusLabel = status == 'paid'
        ? 'Payé'
        : status == 'rejected'
            ? 'Refusé'
            : 'En attente';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPending
                ? statusColor.withValues(alpha: 0.4)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04)),
            width: 1,
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
                      Text(
                        _fmt(amount),
                        style: TextStyle(
                          color: text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userEmails[userId] ?? userId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: sub, fontSize: 12),
                      ),
                      if (phone.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.phone_rounded,
                                  size: 11, color: sub.withValues(alpha: 0.8)),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: TextStyle(color: sub, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _processing ? null : () => _process(id, 'rejected'),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Refuser'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(
                            color: Colors.redAccent.withValues(alpha: 0.5),
                            width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _processing ? null : () => _process(id, 'paid'),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Marquer payé'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      )
          .animate()
          .fadeIn(
            delay: Duration(milliseconds: 30 + (index * 40)),
            duration: 300.ms,
          )
          .slideY(
            begin: 0.05,
            end: 0,
            duration: 300.ms,
            curve: Curves.easeOut,
          ),
    );
  }

  Widget _emptyState(Color text, Color sub, Color primary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.account_balance_wallet_outlined,
                  size: 40, color: primary),
            ),
            const SizedBox(height: 22),
            Text(
              'Aucune demande',
              style: TextStyle(
                color: text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les demandes de retrait s\'afficheront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: sub, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}