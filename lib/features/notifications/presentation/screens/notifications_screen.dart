import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/app_notification.dart';
import '../bloc/notification_bloc.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: Text('Please login first.')));
    }

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () {
              context.read<NotificationBloc>().add(MarkAllNotificationsAsRead(authState.user.uid));
            },
            child: const Text('Mark all as read', style: TextStyle(color: AppColors.white, fontSize: 13)),
          ),
        ],
      ),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state is NotificationLoading || state is NotificationInitial) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
          } else if (state is NotificationError) {
            return Center(child: Text('Error: ${state.message}', style: const TextStyle(color: AppColors.errorRed)));
          } else if (state is NotificationLoaded) {
            final notifications = state.notifications;
            
            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('No notifications yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return _NotificationTile(
                  notification: notif,
                  userId: authState.user.uid,
                );
              },
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final String userId;

  const _NotificationTile({required this.notification, required this.userId});

  IconData _getIconData(String type) {
    switch (type) {
      case 'payment_received': return Icons.monetization_on;
      case 'listing_expiry': return Icons.access_time_filled;
      case 'new_message': return Icons.chat_bubble;
      case 'pickup_confirmed': return Icons.star_rate_rounded;
      case 'new_order': return Icons.inventory_2;
      default: return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'payment_received': return AppColors.primaryGreen;
      case 'listing_expiry': return AppColors.errorRed;
      case 'new_message': return Colors.blue;
      case 'pickup_confirmed': return AppColors.warningAmber;
      case 'new_order': return Colors.purple;
      default: return AppColors.textGrey;
    }
  }

  String _getTimeString(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    return DateFormat('MMM d').format(time);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (!notification.isRead) {
          context.read<NotificationBloc>().add(MarkNotificationAsRead(userId, notification.id));
        }

        // Deep Link routing logic
        if (notification.deepLink != null && notification.deepLink!.isNotEmpty) {
           context.push(notification.deepLink!);
           return;
        }

        final type = notification.type;
        final data = notification.data;
        if (type == 'new_message' && data['chatId'] != null) {
          context.push('/chat/${data["chatId"]}');
        } else if (type == 'payment_received') {
          context.push('/wallet');
        } else if (type == 'pickup_confirmed' && data['orderId'] != null) {
          context.push('/rate/${data["orderId"]}');
        } else if (type == 'listing_expiry') {
          context.push('/listings');
        } else if (type == 'new_order') {
          context.push('/orders');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: notification.isRead ? AppColors.white : AppColors.primaryGreen.withOpacity(0.05),
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getIconColor(notification.type).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_getIconIconColor(notification.type) ? _getIconData(notification.type) : _getIconData(notification.type), size: 24, color: _getIconColor(notification.type)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: notification.isRead ? AppColors.textGrey : AppColors.textDark.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _getTimeString(notification.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: notification.isRead ? Colors.grey[400] : AppColors.primaryGreen,
                fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  bool _getIconIconColor(String type) => true; // Dummy helper to appease static analyzer parsing
}
