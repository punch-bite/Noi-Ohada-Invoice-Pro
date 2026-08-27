import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/team_service.dart';
import '../../models/team.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final TeamService _teamService = TeamService();
  List<Team> _teams = [];
  bool _isLoading = true;
  // Nombre d'invitations d'équipe en attente pour l'utilisateur connecté.
  int _pendingInvites = 0;

  @override
  void initState() {
    super.initState();
    _loadTeams();
    _loadPendingInvites();
  }

  Future<void> _loadTeams() async {
    setState(() => _isLoading = true);
    final auth = context.read<AppAuthProvider>();
    if (auth.user != null) {
      _teams = await _teamService.getUserTeams(auth.user!.id);
    }
    setState(() => _isLoading = false);
  }

  /// Charge le nombre d'invitations en attente (pour afficher la bannière).
  Future<void> _loadPendingInvites() async {
    final auth = context.read<AppAuthProvider>();
    final uid = auth.user?.id ?? '';
    if (uid.isEmpty) return;
    try {
      final invites = await _teamService.getMyInvitations(uid);
      if (mounted) setState(() => _pendingInvites = invites.length);
    } catch (_) {
      // Best-effort : le badge est optionnel.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final bgColor = theme.backgroundColor;
    final hasTeamAccess = context.watch<SubscriptionProvider>().hasTeamAccess;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Équipes', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: textColor),
            onPressed: () => _openCreate(context, hasTeamAccess),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_pendingInvites > 0)
                  _invitationsBanner(context, isDark, textColor),
                if (!hasTeamAccess)
                  _premiumLockCard(context, isDark, textColor),
                if (_teams.isEmpty)
                  _emptyState(context, isDark, textColor, hasTeamAccess)
                else
                  ..._teams.map((t) => _teamCard(t, isDark, textColor)),
              ],
            ),
    );
  }

  /// Bannière « invitations en attente » → ouvre /teams/invitations.
  Widget _invitationsBanner(
    BuildContext context,
    bool isDark,
    Color textColor,
  ) {
    final primaryColor = context.read<ThemeProvider>().primaryColor;
    return Card(
      color: primaryColor.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryColor.withValues(alpha: 0.35)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.mail_outline, color: Colors.white, size: 20),
        ),
        title: Text(
          '$_pendingInvites invitation(s) en attente',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 13.5,
          ),
        ),
        subtitle: Text(
          'Acceptez pour rejoindre une équipe',
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/teams/invitations'),
      ),
    );
  }

  /// Ouvre la création d'équipe — réservée aux abonnés premium / admin.
  void _openCreate(BuildContext context, bool hasTeamAccess) {
    if (!hasTeamAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La création d\'équipe est réservée aux abonnés premium',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      context.push('/subscription');
      return;
    }
    context.push('/teams/create');
  }

  /// Carte de verrouillage premium affichée en tête de liste pour les
  /// utilisateurs gratuits (l'équipe = fonctionnalité Business).
  Widget _premiumLockCard(BuildContext context, bool isDark, Color textColor) {
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFFE9B949).withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFFB8860B), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Équipe premium',
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Passez à un plan payant pour créer et gérer vos équipes.',
                    style: TextStyle(fontSize: 12.5, color: subTextColor),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push('/subscription'),
              child: const Text('Débloquer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamCard(Team team, bool isDark, Color textColor) {
    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 0.5),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withValues(alpha: 0.1),
          child: Text(
            team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(team.name, style: TextStyle(color: textColor)),
        subtitle: Text(
          '${team.memberIds.length} membres',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/teams/${team.id}'),
      ),
    );
  }

  Widget _emptyState(
    BuildContext context,
    bool isDark,
    Color textColor,
    bool hasTeamAccess,
  ) {
    // Hauteur fixe pour centrer l'état vide dans la ListView.
    return SizedBox(
      height: 340,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.groups, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Aucune équipe',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                hasTeamAccess
                    ? 'Créez votre première équipe'
                    : 'Créez vos équipes avec un abonnement premium',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _openCreate(context, hasTeamAccess),
                icon: Icon(hasTeamAccess ? Icons.add : Icons.workspace_premium),
                label: Text(hasTeamAccess ? 'Créer une équipe' : 'Débloquer l\'équipe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}