// lib/screens/notifications/notification_screen.dart
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

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  NotificationService? _notificationService;

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
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final bgColor = themeProvider.backgroundColor;
    final shadowColor = themeProvider.shadowColor;

    _notificationService = context.watch<NotificationService>();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: subTextColor,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
          tabs: const [
            Tab(text: 'Toutes'),
            Tab(text: 'Non lues'),
          ],
        ),
        actions: [
          if (_notificationService != null &&
              _notificationService!.notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textColor),
              onSelected: (value) async {
                if (value == 'mark_all_read') {
                  await _notificationService?.markAllAsRead();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Toutes les notifications marquées comme lues'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else if (value == 'delete_all') {
                  _showDeleteAllDialog(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'mark_all_read',
                  child: Row(
                    children: [
                      Icon(Icons.done_all, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Tout marquer comme lu'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Tout supprimer', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _notificationService == null
          ? const Center(child: CircularProgressIndicator())
          : _notificationService!.notifications.isEmpty
              ? _buildEmptyState(isDark, textColor, subTextColor)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNotificationList(false, isDark, textColor, subTextColor, cardColor, shadowColor, primaryColor),
                    _buildNotificationList(true, isDark, textColor, subTextColor, cardColor, shadowColor, primaryColor),
                  ],
                ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor, Color subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 32,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune notification',
            style: TextStyle(
              fontSize: 18,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vous serez notifié des activités importantes',
            style: TextStyle(fontSize: 14, color: subTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(
    bool onlyUnread,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color shadowColor,
    Color primaryColor,
  ) {
    final notifications = onlyUnread
        ? _notificationService!.unreadNotifications
        : _notificationService!.notifications;

    if (notifications.isEmpty) {
      return Center(
        child: Text(
          onlyUnread ? 'Aucune notification non lue' : 'Aucune notification',
          style: TextStyle(
            color: subTextColor.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationTile(
          notification,
          isDark,
          textColor,
          subTextColor,
          cardColor,
          shadowColor,
          primaryColor,
        );
      },
    );
  }

  Widget _buildNotificationTile(
    AppNotification notification,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color shadowColor,
    Color primaryColor,
  ) {
    final isUnread = !notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 24,
        ),
      ),
      onDismissed: (direction) async {
        await _notificationService?.deleteNotification(notification.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification supprimée'),
              backgroundColor: Colors.grey,
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnread ? primaryColor.withOpacity(0.2) : (isDark ? Colors.grey[800]! : Colors.grey[100]!),
            width: isUnread ? 1.5 : 0.5,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: notification.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              notification.icon,
              color: notification.color,
              size: 22,
            ),
          ),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
              fontSize: 14,
              color: textColor,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                notification.body,
                style: TextStyle(
                  fontSize: 13,
                  color: isUnread ? textColor : subTextColor.withOpacity(0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                notification.timeAgo,
                style: TextStyle(
                  fontSize: 11,
                  color: subTextColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
          trailing: isUnread
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          onTap: () async {
            if (!notification.isRead) {
              await _notificationService?.markAsRead(notification.id);
            }
            _handleNotificationTap(context, notification);
          },
        ),
      ),
    );
  }

  void _handleNotificationTap(BuildContext context, AppNotification notification) {
    // Redirection en fonction du type de référence
    if (notification.referenceType == 'invoice' && notification.referenceId != null) {
      context.push('/dashboard/invoices/${notification.referenceId}');
    } else if (notification.referenceType == 'product') {
      context.push('/dashboard/stock');
    } else if (notification.referenceType == 'client') {
      context.push('/dashboard/clients');
    } else if (notification.referenceType == 'reminder') {
      context.push('/dashboard/reminders');
    } else if (notification.referenceType == 'subscription') {
      context.push('/dashboard/subscription');
    } else {
      // Redirection par défaut vers le tableau de bord
      context.push('/dashboard');
    }
  }

  void _showDeleteAllDialog(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final subTextColor = themeProvider.subTextColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        title: const Text(
          'Supprimer toutes les notifications',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          'Cette action est irréversible. Voulez-vous vraiment supprimer toutes les notifications ?',
          style: TextStyle(color: subTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: subTextColor),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _notificationService?.deleteAllNotifications();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Toutes les notifications ont été supprimées'),
                    backgroundColor: Colors.grey,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer tout'),
          ),
        ],
      ),
    );
  }
}