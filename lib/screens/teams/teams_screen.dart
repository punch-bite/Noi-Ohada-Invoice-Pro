import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/team_service.dart';
import '../../models/team.dart';
import '../../widgets/glass_widgets.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final TeamService _teamService = TeamService();
  List<Team> _teams = [];
  bool _isLoading = true;
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
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadPendingInvites() async {
    final auth = context.read<AppAuthProvider>();
    final uid = auth.user?.id ?? '';
    if (uid.isEmpty) return;
    try {
      final invites = await _teamService.getMyInvitations(uid);
      if (mounted) setState(() => _pendingInvites = invites.length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final hasTeamAccess = context.watch<SubscriptionProvider>().hasTeamAccess;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          'Équipes',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontFamily: 'Manrope'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: theme.accentGold),
            onPressed: () => _openCreate(context, hasTeamAccess),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_pendingInvites > 0)
                  _invitationsBanner(context, theme),
                if (!hasTeamAccess)
                  _premiumLockCard(context, theme),
                if (_teams.isEmpty)
                  _emptyState(context, theme, hasTeamAccess)
                else
                  ..._teams.map((t) => _teamCard(t, theme)),
              ],
            ),
    );
  }

  Widget _invitationsBanner(BuildContext context, ThemeProvider theme) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.push('/teams/invitations'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.mail_outline, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_pendingInvites invitation(s) en attente',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Acceptez pour rejoindre une équipe',
                  style: TextStyle(
                    color: theme.subTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.accentGold),
        ],
      ),
    );
  }

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

  Widget _premiumLockCard(BuildContext context, ThemeProvider theme) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: theme.accentGold, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Équipe premium',
                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Passez à un plan payant pour créer et gérer vos équipes.',
                  style: TextStyle(fontSize: 12, color: theme.subTextColor),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => context.push('/subscription'),
            child: const Text('Débloquer', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _teamCard(Team team, ThemeProvider theme) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.push('/teams/${team.id}'),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.primaryColor.withValues(alpha: 0.2),
            child: Text(
              team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
              style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${team.memberIds.length} membre(s)',
                  style: TextStyle(color: theme.subTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.subTextColor),
        ],
      ),
    );
  }

  Widget _emptyState(
    BuildContext context,
    ThemeProvider theme,
    bool hasTeamAccess,
  ) {
    return SizedBox(
      height: 340,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.groups, size: 64, color: theme.subTextColor),
              const SizedBox(height: 16),
              Text(
                'Aucune équipe',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                hasTeamAccess
                    ? 'Créez votre première équipe pour collaborer.'
                    : 'Créez vos équipes avec un abonnement premium.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.subTextColor, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _openCreate(context, hasTeamAccess),
                icon: Icon(hasTeamAccess ? Icons.add : Icons.workspace_premium),
                label: Text(hasTeamAccess ? 'Créer une équipe' : 'Débloquer l\'équipe'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}