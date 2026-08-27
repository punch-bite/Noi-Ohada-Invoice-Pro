// lib/screens/teams/team_invitations_screen.dart
//
// 📥 Mes invitations — liste des invitations d'équipe EN ATTENTE avec
// boutons Accepter / Refuser. L'invité a reçu un toast (notification) et un
// email à l'invitation ; le propriétaire est prévenu à l'acceptation.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/team_service.dart';

class TeamInvitationsScreen extends StatefulWidget {
  const TeamInvitationsScreen({super.key});

  @override
  State<TeamInvitationsScreen> createState() => _TeamInvitationsScreenState();
}

class _TeamInvitationsScreenState extends State<TeamInvitationsScreen> {
  final TeamService _teamService = TeamService();
  List<Map<String, dynamic>> _invitations = [];
  bool _isLoading = true;
  // Invitation en cours de traitement (id) pour désactiver ses boutons.
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<AppAuthProvider>().user?.id ?? '';
    if (uid.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final list = await _teamService.getMyInvitations(uid);
      if (mounted) {
        setState(() {
          _invitations = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _respond(String id, bool accept) async {
    final uid = context.read<AppAuthProvider>().user?.id ?? '';
    if (uid.isEmpty || _busyId != null) return;
    setState(() => _busyId = id);
    try {
      if (accept) {
        await _teamService.acceptInvitation(
          invitationId: id,
          requestedBy: uid,
        );
      } else {
        await _teamService.declineInvitation(
          invitationId: id,
          requestedBy: uid,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Invitation acceptée 🎉 Bienvenue dans l\'équipe !'
                : 'Invitation refusée',
          ),
          backgroundColor: accept ? Colors.green : Colors.grey,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final bgColor = theme.backgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Mes invitations', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/teams'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invitations.isEmpty
              ? _emptyState(isDark, textColor)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _invitations.length,
                  itemBuilder: (context, index) =>
                      _invitationCard(_invitations[index]),
                ),
    );
  }

  Widget _invitationCard(Map<String, dynamic> inv) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final primaryColor = theme.primaryColor;
    final id = (inv['id'] ?? '').toString();
    final teamName = (inv['teamName'] ?? 'Votre équipe').toString();
    final inviterName = (inv['inviterName'] ?? 'Un membre').toString();
    final isAdminInvite = (inv['role'] ?? 'member') == 'admin';
    final busy = _busyId == id;

    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: primaryColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.12),
                  child: Icon(Icons.group_add, color: primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teamName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Invitée par $inviterName • '
                        '${isAdminInvite ? 'Administrateur' : 'Membre'}',
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _respond(id, false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Refuser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : () => _respond(id, true),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Accepter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(bool isDark, Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mark_email_read_outlined,
              size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucune invitation en attente',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Les invitations que vous recevez apparaîtront ici.',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
