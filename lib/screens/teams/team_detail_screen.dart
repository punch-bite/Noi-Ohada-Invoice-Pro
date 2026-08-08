// lib/screens/teams/team_detail_screen.dart
//
// 👥 Détail d'une équipe : membres, statistiques claires et DONNÉES PARTAGÉES
// (factures / produits / clients). Chaque membre peut partager ses données
// avec la team en @mentionnant ses collègues (notifications envoyées).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/shared_invoice.dart';
import '../../models/team.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/database_service.dart';
import '../../services/stock_service.dart';
import '../../services/team_service.dart';

class TeamDetailScreen extends StatefulWidget {
  final String teamId;
  const TeamDetailScreen({super.key, required this.teamId});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  final TeamService _teamService = TeamService();
  final DatabaseService _db = DatabaseService();
  final StockService _stockService = StockService();

  Team? _team;
  bool _isLoading = true;
  Map<String, Map<String, String>> _profiles = {};
  List<SharedInvoice> _shares = [];
  Map<String, dynamic> _stats = {};
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final team = await _teamService.getTeam(widget.teamId);
    if (team != null) {
      final results = await Future.wait([
        _teamService.getMemberProfiles(widget.teamId),
        _teamService.getSharedResourcesByTeam(widget.teamId),
        _teamService.getTeamShareStats(widget.teamId),
      ]);
      if (!mounted) return;
      setState(() {
        _team = team;
        _profiles = results[0] as Map<String, Map<String, String>>;
        _shares = results[1] as List<SharedInvoice>;
        _stats = results[2] as Map<String, dynamic>;
        _isLoading = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _team = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final auth = context.watch<AppAuthProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final primaryColor = theme.primaryColor;
    final bgColor = theme.backgroundColor;
    final userId = auth.user?.id;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_team == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Équipe non trouvée',
                style: TextStyle(color: textColor),
              ),
            ],
          ),
        ),
      );
    }

    final isOwner = _team!.isOwnerOf(userId!);
    final isAdmin = _team!.isAdmin(userId);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          _team!.name,
          style: TextStyle(color: textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isOwner || isAdmin)
            IconButton(
              icon: Icon(Icons.person_add, color: textColor),
              onPressed: () => context.push('/teams/${_team!.id}/invite'),
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textColor),
            onSelected: (value) {
              if (value == 'leave') _leaveTeam();
              if (value == 'delete' && isOwner) _deleteTeam();
            },
            itemBuilder: (context) => [
              if (!isOwner)
                const PopupMenuItem(
                  value: 'leave',
                  child: Text('Quitter l\'équipe', style: TextStyle(color: Colors.orange)),
                ),
              if (isOwner)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer l\'équipe', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description
              if (_team!.description.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _team!.description,
                    style: TextStyle(color: subTextColor),
                  ),
                ),
              const SizedBox(height: 16),

              // ===== Statistiques =====
              Row(
                children: [
                  _statCard(
                    label: 'Membres',
                    value: _team!.memberIds.length.toString(),
                    icon: Icons.people,
                    color: Colors.blue,
                    isDark: isDark,
                    textColor: textColor,
                  ),
                  const SizedBox(width: 12),
                  _statCard(
                    label: 'Administrateurs',
                    value: _team!.adminIds.length.toString(),
                    icon: Icons.admin_panel_settings,
                    color: Colors.purple,
                    isDark: isDark,
                    textColor: textColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ===== Statistiques de partage =====
              _buildShareStats(isDark, textColor, subTextColor),
              const SizedBox(height: 24),

              // ===== Liste des membres =====
              Text(
                'Membres (${_team!.memberIds.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _team!.memberIds.length,
                itemBuilder: (context, index) {
                  final memberId = _team!.memberIds[index];
                  final isAdminMember = _team!.adminIds.contains(memberId);
                  final isOwnerMember = _team!.ownerId == memberId;

                  return _memberTile(
                    memberId,
                    isAdminMember,
                    isOwnerMember,
                    isOwner,
                    isAdmin,
                    userId,
                    isDark,
                    textColor,
                    subTextColor,
                    primaryColor,
                  );
                },
              ),
              const SizedBox(height: 24),

              // ===== Données partagées =====
              _buildSharedSection(isDark, textColor, subTextColor),
            ],
          ),
        ),
      ),
      floatingActionButton: _sharing
          ? null
          : FloatingActionButton.extended(
              onPressed: _openShareSheet,
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.ios_share),
              label: const Text('Partager'),
            ),
    );
  }

  // ===== STATS DE PARTAGE =====
  Widget _buildShareStats(bool isDark, Color textColor, Color subTextColor) {
    final invoices = (_stats['distinctInvoices'] as num?)?.toInt() ?? 0;
    final products = (_stats['distinctProducts'] as num?)?.toInt() ?? 0;
    final clients = (_stats['distinctClients'] as num?)?.toInt() ?? 0;
    final amount = (_stats['totalAmount'] as num?)?.toDouble() ?? 0;
    final fmt = _fmt(amount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, size: 18, color: textColor),
              const SizedBox(width: 8),
              Text(
                'Données partagées',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniStat('🧾 Factures', invoices.toString(), Colors.blue),
              const SizedBox(width: 12),
              _miniStat('📦 Produits', products.toString(), Colors.orange),
              const SizedBox(width: 12),
              _miniStat('👤 Clients', clients.toString(), Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.attach_money, size: 16, color: Colors.teal),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Total factures partagées : $fmt',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // ===== DONNÉES PARTAGÉES =====
  Widget _buildSharedSection(bool isDark, Color textColor, Color subTextColor) {
    final invoices = _shares.where((s) => s.resourceType == 'invoice').toList();
    final products = _shares.where((s) => s.resourceType == 'product').toList();
    final clients = _shares.where((s) => s.resourceType == 'client').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Données partagées avec l\'équipe',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 4),
        Text(
          'Factures, produits et clients accessibles par toute l\'équipe.',
          style: TextStyle(fontSize: 12, color: subTextColor),
        ),
        const SizedBox(height: 12),

        if (_shares.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.share_outlined,
                    size: 32,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aucune donnée partagée pour le moment.',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Touchez « Partager » pour partager une facture, un produit ou un client.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          _sharedGroup('🧾 Factures', invoices, isDark, textColor, subTextColor),
          const SizedBox(height: 12),
          _sharedGroup('📦 Produits', products, isDark, textColor, subTextColor),
          const SizedBox(height: 12),
          _sharedGroup('👤 Clients', clients, isDark, textColor, subTextColor),
        ],
      ],
    );
  }

  Widget _sharedGroup(
    String title,
    List<SharedInvoice> items,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${items.length})',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (s) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.link, size: 18, color: Colors.teal),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.resourceName.isEmpty ? s.invoiceId : s.resourceName,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Partagé par ${_displayName(s.sharedBy)}',
                        style: TextStyle(color: subTextColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Rendre privé',
                  icon: Icon(Icons.close, size: 18, color: subTextColor),
                  onPressed: () => _revokeShare(s),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _revokeShare(SharedInvoice share) async {
    await _teamService.revokeSharedInvoice(share.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Partage révoqué'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
    _loadData();
  }

  // ===== PARTAGE AVEC @MENTIONS =====
  Future<void> _openShareSheet() async {
    final auth = context.read<AppAuthProvider>();
    final uid = auth.user?.id ?? '';
    if (uid.isEmpty) return;

    // Candidats @mention : tous les membres sauf moi.
    final candidates = <String>{
      _team!.ownerId,
      ..._team!.adminIds,
      ..._team!.memberIds,
    }..remove(uid);

    setState(() => _sharing = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _ShareSheet(
          candidates: candidates.toList(),
          profiles: _profiles,
          onShare: (type, resourceIds, memberIds) =>
              _performShare(type, resourceIds, memberIds, uid),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _performShare(
    String type,
    List<String> resourceIds,
    List<String> memberIds,
    String uid,
  ) async {
    if (resourceIds.isEmpty || memberIds.isEmpty) return;
    // Récupère les noms pour un affichage lisible.
    final names = await _resourceNames(type, resourceIds);
    for (var i = 0; i < resourceIds.length; i++) {
      await _teamService.shareResource(
        resourceId: resourceIds[i],
        resourceType: type,
        resourceName: names[i] ?? resourceIds[i],
        teamId: _team!.id,
        sharedBy: uid,
        sharedWith: memberIds,
      );
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Donnée partagée avec l\'équipe'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    _loadData();
  }

  Future<List<String?>> _resourceNames(String type, List<String> ids) async {
    if (type == 'product') {
      final all = await _stockService.getProducts();
      final map = {for (final p in all) p.id: p.name};
      return ids.map((id) => map[id]).toList();
    } else if (type == 'client') {
      final all = await _db.getClients();
      final map = {for (final c in all) c.id: c.name};
      return ids.map((id) => map[id]).toList();
    } else {
      final all = await _db.getInvoices();
      final map = {for (final i in all) i.id: i.invoiceNumber};
      return ids.map((id) => map[id]).toList();
    }
  }

  String _displayName(String uid) {
    final name = _profiles[uid]?['name'] ?? '';
    if (name.isNotEmpty) return name;
    final email = _profiles[uid]?['email'] ?? '';
    if (email.isNotEmpty) return email;
    return uid == context.read<AppAuthProvider>().user?.id ? 'Moi' : 'Membre';
  }

  String _fmt(double amount) =>
      '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ')} FCFA';

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color textColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberTile(
    String memberId,
    bool isAdmin,
    bool isOwner,
    bool canManage,
    bool isCurrentAdmin,
    String currentUserId,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
  ) {
    final name = _profiles[memberId]?['name'] ?? '';
    final email = _profiles[memberId]?['email'] ?? '';
    final label = memberId == currentUserId
        ? 'Moi'
        : (name.isNotEmpty ? name : 'Membre #${memberId.substring(0, 6)}');
    final sub = memberId == currentUserId
        ? (email.isNotEmpty ? email : 'Vous')
        : (email.isNotEmpty ? email : 'membre');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isAdmin
                ? Colors.purple.withOpacity(0.2)
                : Colors.blue.withOpacity(0.2),
            child: Text(
              (name.isNotEmpty ? name : memberId).substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isAdmin ? Colors.purple : Colors.blue,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isOwner ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  sub,
                  style: TextStyle(color: subTextColor, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    if (isOwner)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Propriétaire',
                          style: TextStyle(fontSize: 9, color: Colors.amber),
                        ),
                      ),
                    if (isAdmin && !isOwner)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(fontSize: 9, color: Colors.purple),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (canManage && memberId != currentUserId)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 16, color: subTextColor),
              onSelected: (value) async {
                if (value == 'promote') {
                  await _teamService.promoteToAdmin(_team!.id, memberId);
                  _loadData();
                } else if (value == 'demote') {
                  await _teamService.demoteFromAdmin(_team!.id, memberId);
                  _loadData();
                } else if (value == 'remove') {
                  await _teamService.removeMember(_team!.id, memberId);
                  _loadData();
                }
              },
              itemBuilder: (context) => [
                if (!isAdmin && !isOwner)
                  const PopupMenuItem(
                    value: 'promote',
                    child: Text('Promouvoir admin'),
                  ),
                if (isAdmin && !isOwner)
                  const PopupMenuItem(
                    value: 'demote',
                    child: Text('Rétrograder'),
                  ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Retirer', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _leaveTeam() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter l\'équipe'),
        content: const Text('Voulez-vous vraiment quitter cette équipe ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _teamService.removeMember(_team!.id, context.read<AppAuthProvider>().user!.id);
      if (mounted) context.pop();
    }
  }

  Future<void> _deleteTeam() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'équipe'),
        content: const Text('Cette action est irréversible. Voulez-vous vraiment supprimer cette équipe ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _teamService.deleteTeam(_team!.id);
      if (mounted) context.pop();
    }
  }
}

// ============================================================
//  Feuille de partage : choisir un type, des ressources et
//  @mentionner les membres de l'équipe.
// ============================================================
class _ShareSheet extends StatefulWidget {
  final List<String> candidates;
  final Map<String, Map<String, String>> profiles;
  final Future<void> Function(
      String type, List<String> resourceIds, List<String> memberIds) onShare;

  const _ShareSheet({
    required this.candidates,
    required this.profiles,
    required this.onShare,
  });

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final DatabaseService _db = DatabaseService();
  final StockService _stockService = StockService();

  String _type = 'invoice';
  final Set<String> _selectedResources = {};
  final Set<String> _selectedMembers = {};
  List<({String id, String label})> _resources = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    setState(() {
      _loading = true;
      _selectedResources.clear();
    });
    List<({String id, String label})> items = [];
    if (_type == 'product') {
      final products = await _stockService.getProducts();
      items = products.map((p) => (id: p.id, label: p.name)).toList();
    } else if (_type == 'client') {
      final clients = await _db.getClients();
      items = clients.map((c) => (id: c.id, label: c.name)).toList();
    } else {
      final invoices = await _db.getInvoices();
      items = invoices
          .map((i) =>
              (id: i.id, label: '${i.invoiceNumber} — ${_fmt(i.totalAmount)}'))
          .toList();
    }
    if (!mounted) return;
    setState(() {
      _resources = items;
      _loading = false;
    });
  }

  String _fmt(double amount) =>
      '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ')} FCFA';

  String _memberLabel(String uid) {
    final name = widget.profiles[uid]?['name'] ?? '';
    if (name.isNotEmpty) return name;
    final email = widget.profiles[uid]?['email'] ?? '';
    if (email.isNotEmpty) return email;
    return 'Membre #${uid.substring(0, 6)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.ios_share, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Partager avec l\'équipe',
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: theme.subTextColor, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ===== Type de ressource =====
          Text(
            'Type de donnée',
            style: TextStyle(
              color: theme.subTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _typeChip('invoice', '🧾 Factures', theme),
              const SizedBox(width: 8),
              _typeChip('product', '📦 Produits', theme),
              const SizedBox(width: 8),
              _typeChip('client', '👤 Clients', theme),
            ],
          ),
          const SizedBox(height: 12),

          // ===== Ressources =====
          Text(
            'Sélectionnez ${_type == 'invoice' ? 'la facture' : _type == 'product' ? 'le produit' : 'le client'}',
            style: TextStyle(
              color: theme.subTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            flex: 3,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _resources.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun élément de ce type.',
                          style: TextStyle(color: theme.subTextColor),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _resources.length,
                        itemBuilder: (context, index) {
                          final r = _resources[index];
                          final selected = _selectedResources.contains(r.id);
                          return CheckboxListTile(
                            dense: true,
                            value: selected,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selectedResources.add(r.id);
                              } else {
                                _selectedResources.remove(r.id);
                              }
                            }),
                            title: Text(
                              r.label,
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            activeColor: theme.primaryColor,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                          );
                        },
                      ),
          ),
          const SizedBox(height: 8),

          // ===== Membres (@mention) =====
          Text(
            'Mentionner (@) les membres',
            style: TextStyle(
              color: theme.subTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            flex: 2,
            child: widget.candidates.isEmpty
                ? Center(
                    child: Text(
                      'Aucun autre membre à mentionner.',
                      style: TextStyle(color: theme.subTextColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.candidates.length,
                    itemBuilder: (context, index) {
                      final uid = widget.candidates[index];
                      final selected = _selectedMembers.contains(uid);
                      return CheckboxListTile(
                        dense: true,
                        value: selected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedMembers.add(uid);
                          } else {
                            _selectedMembers.remove(uid);
                          }
                        }),
                        title: Text(
                          '@${_memberLabel(uid)}',
                          style: TextStyle(
                            color: selected
                                ? theme.primaryColor
                                : theme.textColor,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        activeColor: theme.primaryColor,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed:
                  _selectedResources.isEmpty || _selectedMembers.isEmpty
                      ? null
                      : () {
                          widget.onShare(
                            _type,
                            _selectedResources.toList(),
                            _selectedMembers.toList(),
                          );
                        },
              icon: const Icon(Icons.send),
              label: Text(
                'Partager (${_selectedResources.length}) avec ${_selectedMembers.length} membre(s)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String value, String label, ThemeProvider theme) {
    final selected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _type = value);
          _loadResources();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? theme.primaryColor.withValues(alpha: 0.12)
                : theme.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? theme.primaryColor : theme.dividerColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? theme.primaryColor : theme.textColor,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}