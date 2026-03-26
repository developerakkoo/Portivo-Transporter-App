import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/helpers.dart';
import '../data/models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../providers/navigation_state_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<NotificationProvider>(context, listen: false)
            .loadNotifications(refresh: true);
      }
    });
  }

  void _onNotificationTap(NotificationModel notification) {
    final tripId = notification.tripId;
    if (tripId != null) {
      Provider.of<NotificationProvider>(context, listen: false)
          .markAsRead(notification.id);
      Provider.of<NavigationStateProvider>(context, listen: false)
          .requestTripHighlight(tripId, subTabIndex: 3);
      Navigator.of(context).pop();
    } else {
      Provider.of<NotificationProvider>(context, listen: false)
          .markAsRead(notification.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, _) {
              if (notificationProvider.unreadCount == 0) {
                return const SizedBox.shrink();
              }
              return TextButton(
                onPressed: () async {
                  await notificationProvider.markAllAsRead();
                },
                child: const Text('Mark all read'),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, _) {
          if (notificationProvider.isLoading &&
              notificationProvider.notifications.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (notificationProvider.notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      size: 64.0,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 24.0),
                    Text(
                      'No notifications yet',
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      'You\'ll see notifications about new trip bookings and other updates here.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                notificationProvider.loadNotifications(refresh: true),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: notificationProvider.notifications.length,
              itemBuilder: (context, index) {
                final n = notificationProvider.notifications[index];
                return _buildNotificationItem(n, textTheme);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel n, TextTheme textTheme) {
    final hasTripLink = n.tripId != null;

    return InkWell(
      onTap: () => _onNotificationTap(n),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        color: n.read ? AppColors.background : AppColors.offWhite,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              n.type == 'TRIP_BOOKED' ? Icons.inventory_2_outlined : Icons.notifications_outlined,
              color: n.read ? AppColors.textMuted : AppColors.primary,
              size: 24.0,
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: n.read ? FontWeight.w500 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    n.message,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    Helpers.formatDateTime(n.createdAt),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12.0,
                    ),
                  ),
                  if (hasTripLink) ...[
                    const SizedBox(height: 8.0),
                    Text(
                      'Tap to view trip',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
