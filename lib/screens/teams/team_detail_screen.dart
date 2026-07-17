// lib/screens/teams/team_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/team_service.dart';
import '../../models/team.dart';

class TeamDetailScreen extends StatefulWidget {
  final String teamId;
  const TeamDetailScreen({super.key, required this.teamId});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  final TeamService _teamService = TeamService();
  Team? _team;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    setState(() => _isLoading = true);
    _team = await _teamService.getTeam(widget.teamId);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final auth = context.watch<AppAuthProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor ?? Colors.black;
    final subTextColor = theme.subTextColor ?? Colors.grey;
    final primaryColor = theme.primaryColor ?? Colors.blue;
    final bgColor = theme.backgroundColor ?? Colors.white;
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
      body: SingleChildScrollView(
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

            // Statistiques
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
            const SizedBox(height: 24),

            // Liste des membres
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

            // Factures partagées (à venir)
            _buildSharedInvoicesSection(isDark, textColor),
          ],
        ),
      ),
    );
  }

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
            backgroundColor: isAdmin ? Colors.purple.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
            child: Text(
              memberId.isNotEmpty ? memberId[0].toUpperCase() : '?',
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
                  memberId == currentUserId ? 'Moi' : 'Membre #${memberId.substring(0, 6)}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isOwner ? FontWeight.bold : FontWeight.normal,
                  ),
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
                  _loadTeam();
                } else if (value == 'demote') {
                  await _teamService.demoteFromAdmin(_team!.id, memberId);
                  _loadTeam();
                } else if (value == 'remove') {
                  await _teamService.removeMember(_team!.id, memberId);
                  _loadTeam();
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

  Widget _buildSharedInvoicesSection(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Factures partagées',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
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
                  'Aucune facture partagée',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.share),
                  label: const Text('Partager une facture'),
                ),
              ],
            ),
          ),
        ),
      ],
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