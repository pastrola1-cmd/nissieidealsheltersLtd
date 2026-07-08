import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';
import 'package:nissie_ideal_shelters/services/notification_service.dart';
import 'package:nissie_ideal_shelters/providers/auth_provider.dart';

class NotificationState {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final String? errorMessage;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    String? errorMessage,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  late final SupabaseService _supabaseService;
  late final NotificationService _notificationService;
  RealtimeChannel? _subscriptionChannel;
  String? _subscribedUserId;

  @override
  NotificationState build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    _notificationService = ref.watch(notificationServiceProvider);

    final authState = ref.watch(authProvider);
    final profile = authState.profile;

    if (profile != null) {
      if (_subscribedUserId != profile.id) {
        _subscribedUserId = profile.id;
        Future.microtask(() {
          loadNotifications(profile.id);
          _registerFcmToken(profile.id);
          _subscribeToRealtime(profile.id);
        });
        return const NotificationState(isLoading: true);
      }
      return state;
    } else {
      if (_subscribedUserId != null) {
        _subscribedUserId = null;
        _cleanupSubscription();
      }
      ref.onDispose(() {
        _cleanupSubscription();
      });
      return const NotificationState();
    }
  }

  Future<void> loadNotifications(String userId) async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _supabaseService.getNotifications(userId);
      state = NotificationState(notifications: list, isLoading: false);
    } catch (e) {
      state = NotificationState(
        notifications: state.notifications,
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _registerFcmToken(String userId) async {
    try {
      final token = await _notificationService.getFcmToken();
      if (token != null) {
        await _supabaseService.updateFcmToken(userId, token);
      }
    } catch (e) {
      // Ignored defensively
    }
  }

  void _subscribeToRealtime(String userId) {
    _cleanupSubscription();

    try {
      _subscriptionChannel = _supabaseService.client
          .channel('public:notifications:user_id=eq.$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final newJson = payload.newRecord;
              if (newJson.isNotEmpty) {
                final newNotif = NotificationModel.fromJson(newJson);
                state = state.copyWith(
                  notifications: [newNotif, ...state.notifications],
                );
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Supabase real-time subscription failed: $e');
    }
  }

  void _cleanupSubscription() {
    if (_subscriptionChannel != null) {
      try {
        _supabaseService.client.removeChannel(_subscriptionChannel!);
      } catch (e) {
        // Ignored
      }
      _subscriptionChannel = null;
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      final updated = await _supabaseService.markNotificationRead(id);
      final updatedList = state.notifications.map((n) => n.id == id ? updated : n).toList();
      state = state.copyWith(notifications: updatedList);
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final profile = ref.read(authProvider).profile;
    if (profile == null) return;

    try {
      await _supabaseService.markAllNotificationsRead(profile.id);
      final updatedList = state.notifications.map((n) => n.copyWith(read: true)).toList();
      state = state.copyWith(notifications: updatedList);
    } catch (e) {
      debugPrint('Failed to mark all notifications as read: $e');
    }
  }
}

final notificationProvider = NotifierProvider<NotificationNotifier, NotificationState>(() {
  return NotificationNotifier();
});
