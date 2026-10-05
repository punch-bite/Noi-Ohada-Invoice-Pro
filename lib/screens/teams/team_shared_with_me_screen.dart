// lib/screens/teams/team_shared_with_me_screen.dart
//
// 🔐 « Mes accès équipe » : liste les ressources (factures / produits /
// clients) auxquelles le membre courant a accès — en lecture seule ou en
// lecture + écriture — via son équipe.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/shared_invoice.dart';
import '../../models/team.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/team_service.dart';
import '../../widgets/glass_widgets.dart';

class TeamSharedWithMeScreen extends StatefulWidget {
  final String teamId;
  const TeamSharedWithMeScreen({super.key, required this.teamId});

  @override
  State<TeamSharedWithMeScreen> createState() =>
      _TeamSharedWithMeScreenState();
}

class _TeamSharedWithMeScreenState extends State<TeamSharedWithMeScreen> {
  final TeamService _teamService = TeamService();

  Team? _team;
  List<SharedInvoice> _shares = [];
  Map<String, Map<String, String>> _profiles = {};
  bool _isLoading = true;
  String _filter = 'all'; // 'all' | 'invoice' | 'product' | 'client'

  String get _uid => context.read<AppAuthProvider>().user?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    if (_uid.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final team = await _teamService.getTeam(widget.teamId);
      if (team == null) {
        if (mounted) {
          setState(() {
            _team = null;
            _isLoading = false;
          });
        }
        return;
      }
      final results = await Future.wait([
        _teamService.getAccessibleShares(teamId: widget.teamId, userId: _uid),
        _teamService.getMemberProfiles(widget.teamId),
      ]);
      if (!mounted) return;
      setState(() {
        _team = team;
        _shares = results[0] as List<SharedInvoice>;
        _profiles = results[1] as Map<String, Map<String, String>>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('⚠️ TeamSharedWithMe: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _canWrite(SharedInvoice s) {
    if (_team == null) return false;
    return s.canWrite(_uid) || _team!.canWriteShared(_uid);
  }

  String _displayName(String uid) {
    final name = _profiles[uid]?['name'] ?? '';
    if (name.isNotEmpty) return name;
    final email = _profiles[uid]?['email'] ?? '';
    if (email.isNotEmpty) return email;
    return uid == _uid ? 'Moi' : 'Membre #${uid.substring(0, 6)}';
  }

  List<SharedInvoice> get _filtered {
    if (_filter == 'all') return _shares;
    return _shares.where((s) => s.resourceType == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final primaryColor = theme.primaryColor;

    if (_isLoading) {
      return GlassScaffold(
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (_team == null) {
      return GlassScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/teams'),
          ),
        ),
        body: Center(
          child:
              Text('Équipe non trouvée', style: TextStyle(color: textColor)),
        ),
      );
    }

    final invoices =
        _shares.where((s) => s.resourceType == 'invoice').toList();
    final products =
        _shares.where((s) => s.resourceType == 'product').toList();
    final clients = _shares.where((s) => s.resourceType == 'client').toList();

    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/teams'),
        ),
        title: Text(
          'Mes accès équipe',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.folder_shared_outlined,
                          color: primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _team!.name,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_shares.length} ressource${_shares.length > 1 ? 's' : ''} accessible${_shares.length > 1 ? 's' : ''}',
                            style: TextStyle(
                                color: subTextColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _filterChip('all', 'Tout', _shares.length, theme),
                    const SizedBox(width: 8),
                    _filterChip(
                        'invoice', '🧾 Factures', invoices.length, theme),
                    const SizedBox(width: 8),
                    _filterChip(
                        'product', '📦 Produits', products.length, theme),
                    const SizedBox(width: 8),
                    _filterChip(
                        'client', '👤 Clients', clients.length, theme),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_filtered.isEmpty)
                _emptyState(textColor, subTextColor)
              else
                ..._filtered
                    .map((s) => _shareTile(s, textColor, subTextColor)),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(
      String value, String label, int count, ThemeProvider theme) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.primaryColor.withValues(alpha: 0.12)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? theme.primaryColor
                : theme.dividerColor.withValues(alpha: 0.6),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: selected ? theme.primaryColor : theme.textColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? theme.primaryColor.withValues(alpha: 0.18)
                    : theme.dividerColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? theme.primaryColor
                      : theme.subTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(Color textColor, Color subTextColor) {
    return GlassCard(
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.lock_open_outlined,
              size: 40,
              color: subTextColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Aucune ressource partagée avec vous',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Vos collègues doivent vous mentionner (@) lors d\'un partage '
              'pour que vous y ayez accès.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: subTextColor, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shareTile(
      SharedInvoice s, Color textColor, Color subTextColor) {
    final canWrite = _canWrite(s);
    final accent = canWrite ? Colors.green : Colors.blueGrey;
    final icon = s.resourceType == 'invoice'
        ? Icons.receipt_long_rounded
        : s.resourceType == 'product'
            ? Icons.inventory_2_rounded
            : Icons.person_rounded;
    final theme = context.watch<ThemeProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openShare(s),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.resourceName.isEmpty ? s.invoiceId : s.resourceName,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Partagé par ${_displayName(s.sharedBy)}',
                      style: TextStyle(color: subTextColor, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        canWrite
                            ? '✍️ Lecture + écriture'
                            : '👁️ Lecture seule',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                canWrite ? Icons.edit_outlined : Icons.visibility_outlined,
                size: 18,
                color: subTextColor.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openShare(SharedInvoice s) {
    if (s.resourceType == 'invoice') {
      final canWrite = _canWrite(s);
      context.push(
        '/dashboard/invoices/${s.invoiceId}',
        extra: {'fromTeam': true, 'canWrite': canWrite},
      );
    } else if (s.resourceType == 'product') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ouverture produit — bientôt disponible'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ouverture client — bientôt disponible'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}