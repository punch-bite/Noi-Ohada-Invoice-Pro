import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/notification.dart';
import '../../providers/theme_provider.dart';
import '../../services/notification_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Dismissible(
      key: Key(notification.id),
      onDismissed: (_) => context.read<NotificationService>().deleteNotification(notification.id),
      child: Card(
        color: theme.cardColor,
        child: ListTile(
          leading: Icon(notification.icon, color: notification.color),
          title: Text(notification.title, style: TextStyle(fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold)),
          subtitle: Text(notification.body),
          onTap: () {
            context.read<NotificationService>().markAsRead(notification.id);
            // Redirection ici...
          },
        ),
      ),
    );
  }
}