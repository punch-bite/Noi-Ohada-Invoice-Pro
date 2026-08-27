import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/notification.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/notification_service.dart';
import '../../services/team_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.primaryColor,
          labelColor: theme.primaryColor,
          tabs: const [Tab(text: 'Toutes'), Tab(text: 'Non lues')],
        ),
        actions: [_buildPopupMenu(context)],
      ),
      body: Consumer<NotificationService>(
        builder: (context, service, _) {
          if (service.notifications.isEmpty) return _buildEmptyState();
          return TabBarView(
            controller: _tabController,
            children: [
              _NotificationList(notifications: service.notifications),
              _NotificationList(notifications: service.unreadNotifications),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context) {
    return PopupMenuButton(
      onSelected: (value) {
        final service = context.read<NotificationService>();
        value == 'read' ? service.markAllAsRead() : _confirmDeleteAll(context);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'read', child: Text('Tout marquer lu')),
        const PopupMenuItem(value: 'del', child: Text('Tout supprimer', style: TextStyle(color: Colors.red))),
      ],
    );
  }

  Widget _buildEmptyState() => const Center(child: Text("Aucune notification pour le moment."));

  void _confirmDeleteAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer tout ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          TextButton(
            onPressed: () {
              context.read<NotificationService>().deleteAllNotifications();
              Navigator.pop(ctx);
            },
            child: const Text("Confirmer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// Composant de liste optimisé
class _NotificationList extends StatelessWidget {
  final List<AppNotification> notifications;
  const _NotificationList({required this.notifications});

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) return const Center(child: Text("Aucun élément"));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: notifications.length,
      itemBuilder: (_, i) => _NotificationTile(notification: notifications[i]),
    );
  }
}

// Composant de tuile extrait pour la performance
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  /// Traite une invitation d'équipe (Accepter / Refuser) directement depuis
  /// la notification, puis rafraîchit la liste.
  Future<void> _respondInvite(BuildContext context, bool accept) async {
    final auth = context.read<AppAuthProvider>();
    final uid = auth.user?.id ?? '';
    final invitationId = notification.referenceId;
    if (uid.isEmpty || invitationId == null || invitationId.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      if (accept) {
        await TeamService().acceptInvitation(
          invitationId: invitationId,
          requestedBy: uid,
        );
      } else {
        await TeamService().declineInvitation(
          invitationId: invitationId,
          requestedBy: uid,
        );
      }
      if (!context.mounted) return;
      final service = context.read<NotificationService>();
      await service.markAsRead(notification.id);
      await service.refresh();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Invitation acceptée 🎉 Bienvenue dans l\'équipe !'
                : 'Invitation refusée',
          ),
          backgroundColor: accept ? Colors.green : Colors.grey,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isTeamInvite = notification.type == 'team_invite';

    return Dismissible(
      key: Key(notification.id),
      onDismissed: (_) =>
          context.read<NotificationService>().deleteNotification(notification.id),
      child: Card(
        color: theme.cardColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(notification.icon, color: notification.color),
              title: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: notification.isRead
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
              ),
              subtitle: Text(notification.body),
              onTap: () {
                context.read<NotificationService>().markAsRead(notification.id);
                // Redirection ici...
              },
            ),
            // 🤝 Invitation d'équipe : boutons Accepter / Refuser.
            if (isTeamInvite)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _respondInvite(context, false),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Refuser'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(
                            color: Colors.red.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _respondInvite(context, true),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Accepter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}