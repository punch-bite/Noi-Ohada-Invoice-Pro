// lib/screens/dashboard/widgets/dashboard_activities.dart
import 'package:flutter/material.dart';
import '../../../models/dashboard_stats.dart';

class DashboardActivities extends StatelessWidget {
  const DashboardActivities({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 600;

    return Row(
      children: [
        Expanded(
          flex: isSmall ? 1 : 2,
          child: _NotificationsCard(),
        ),
        if (!isSmall) ...[
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: _ActivitiesCard(),
          ),
        ],
      ],
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final notifications = NotificationItem.sampleNotifications;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '5',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...notifications.map((notification) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: notification.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      notification.icon,
                      color: notification.color,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.isUrgent ? FontWeight.w600 : FontWeight.normal,
                        color: notification.isUrgent ? Colors.black87 : Colors.grey[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (notification.isUrgent)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _ActivitiesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final activities = ActivityItem.sampleActivities;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activités récentes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...activities.take(4).map((activity) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 4,
                    color: Colors.blue[300],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activity.title,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}