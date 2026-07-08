import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nissie_ideal_shelters/core/constants/app_colors.dart';
import 'package:nissie_ideal_shelters/core/enums/enums.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';
import 'package:nissie_ideal_shelters/providers/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _getIconForType(String type) {
    switch (type) {
      case 'signup':
        return Icons.person_add_rounded;
      case 'partner_approved':
        return Icons.verified_rounded;
      case 'lead_created':
        return Icons.person_pin_rounded;
      case 'inspection_booked':
        return Icons.calendar_month_rounded;
      case 'lead_stage_changed':
        return Icons.alt_route_rounded;
      case 'commission_approved':
        return Icons.monetization_on_rounded;
      case 'withdrawal_resolved':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'signup':
        return AppColors.info;
      case 'partner_approved':
        return AppColors.success;
      case 'lead_created':
        return AppColors.secondary;
      case 'inspection_booked':
        return AppColors.warning;
      case 'lead_stage_changed':
        return AppColors.accent;
      case 'commission_approved':
        return AppColors.success;
      case 'withdrawal_resolved':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  void _handleTap(BuildContext context, WidgetRef ref, NotificationModel notification, UserRole role) {
    // 1. Mark as read
    if (!notification.read) {
      ref.read(notificationProvider.notifier).markAsRead(notification.id);
    }

    // 2. Navigate based on type and user role
    switch (notification.type) {
      case 'signup':
        if (role == UserRole.admin || role == UserRole.platformAdmin) {
          context.go('/admin/partners');
        }
        break;
      case 'partner_approved':
        if (role == UserRole.partner) {
          context.go('/partner/dashboard');
        }
        break;
      case 'lead_created':
      case 'lead_stage_changed':
        if (role == UserRole.admin || role == UserRole.platformAdmin) {
          context.go('/admin/leads');
        } else if (role == UserRole.manager) {
          context.go('/manager/leads');
        } else if (role == UserRole.marketer) {
          context.go('/marketer/leads');
        } else if (role == UserRole.partner) {
          context.go('/partner/leads');
        }
        break;
      case 'inspection_booked':
        if (role == UserRole.admin || role == UserRole.platformAdmin) {
          context.push('/admin/inspections');
        } else if (role == UserRole.partner) {
          context.push('/partner/inspections');
        } else if (role == UserRole.buyer) {
          context.go('/buyer/inspections');
        }
        break;
      case 'commission_approved':
      case 'withdrawal_resolved':
        if (role == UserRole.partner) {
          context.go('/partner/earnings');
        }
        break;
      default:
        // No navigation for unknown type
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final userProfile = ref.watch(authProvider).profile;
    final userRole = userProfile?.role ?? UserRole.buyer;

    final unreadCount = state.notifications.where((n) => !n.read).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0.8,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: () {
                ref.read(notificationProvider.notifier).markAllAsRead();
              },
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Mark all read'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: state.isLoading && state.notifications.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : state.notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: () async {
                    if (userProfile != null) {
                      await ref
                          .read(notificationProvider.notifier)
                          .loadNotifications(userProfile.id);
                    }
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    itemCount: state.notifications.length,
                    itemBuilder: (context, index) {
                      final notification = state.notifications[index];
                      return _buildNotificationCard(context, ref, notification, userRole);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 64,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'All caught up!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You don\'t have any notifications right now. We\'ll let you know when something important happens.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    WidgetRef ref,
    NotificationModel notification,
    UserRole role,
  ) {
    final icon = _getIconForType(notification.type);
    final color = _getColorForType(notification.type);
    final formattedTime = DateFormat.yMMMd().add_jm().format(notification.createdAt);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: notification.read ? AppColors.border : AppColors.accent.withValues(alpha: 0.15),
          width: notification.read ? 1.0 : 1.5,
        ),
      ),
      color: notification.read ? AppColors.surface : AppColors.accent.withValues(alpha: 0.02),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _handleTap(context, ref, notification, role),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification Type Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Notification Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: notification.read ? FontWeight.w600 : FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!notification.read)
                          Container(
                            margin: const EdgeInsets.only(left: 8, top: 4),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: notification.read ? AppColors.textSecondary : AppColors.textPrimary.withValues(alpha: 0.85),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
