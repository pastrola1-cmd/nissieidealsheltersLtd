// ignore_for_file: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:ppn/core/enums/enums.dart';
import 'package:ppn/models/models.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/providers/auth_state.dart';
import 'package:ppn/services/supabase_service.dart';
import 'package:ppn/services/notification_service.dart';
import 'package:ppn/providers/notification_provider.dart';

// Fake implementations for testing
class FakeAuthNotifier extends AuthNotifier {
  final Profile? testProfile;
  FakeAuthNotifier(this.testProfile);

  @override
  AuthState build() {
    return AuthState(
      isAuthenticated: testProfile != null,
      profile: testProfile,
    );
  }
}

class MockSupabaseService extends SupabaseService {
  final List<NotificationModel> mockNotifications;
  final List<String> markedReadIds = [];
  bool markedAllReadCalled = false;
  String? updatedFcmTokenUserId;
  String? updatedFcmTokenValue;

  MockSupabaseService(this.mockNotifications);

  @override
  Future<List<NotificationModel>> getNotifications(String userId) async {
    return mockNotifications;
  }

  @override
  Future<NotificationModel> markNotificationRead(String id) async {
    markedReadIds.add(id);
    final match = mockNotifications.firstWhere((n) => n.id == id);
    return match.copyWith(read: true);
  }

  @override
  Future<void> markAllNotificationsRead(String userId) async {
    markedAllReadCalled = true;
  }

  @override
  Future<Profile> updateFcmToken(String userId, String token) async {
    updatedFcmTokenUserId = userId;
    updatedFcmTokenValue = token;
    return Profile(
      id: userId,
      role: UserRole.partner,
      status: PartnerStatus.approved,
      createdAt: DateTime.now(),
      fcmToken: token,
    );
  }
}

class MockNotificationService extends NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<String?> getFcmToken() async {
    return 'fake-fcm-token-123';
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    // Statically initialize Supabase in-memory client for testing
    await sb.Supabase.initialize(
      url: 'https://wzotqxrmewmgqetpahrm.supabase.co',
      publishableKey: 'dummy-anon-key',
    );
  });

  group('Notification Model Serialization Tests', () {
    test('Should correctly serialize and deserialize NotificationModel', () {
      final now = DateTime.now();
      final json = {
        'id': 'notif-123',
        'company_id': 'company-456',
        'user_id': 'user-789',
        'title': 'Test Notification',
        'body': 'This is a test notification body.',
        'type': 'lead_created',
        'read': false,
        'created_at': now.toIso8601String(),
      };

      final notif = NotificationModel.fromJson(json);

      expect(notif.id, 'notif-123');
      expect(notif.companyId, 'company-456');
      expect(notif.userId, 'user-789');
      expect(notif.title, 'Test Notification');
      expect(notif.body, 'This is a test notification body.');
      expect(notif.type, 'lead_created');
      expect(notif.read, false);
      expect(notif.createdAt.year, now.year);

      final backToJson = notif.toJson();
      expect(backToJson['id'], 'notif-123');
      expect(backToJson['read'], false);
    });

    test('Should support copyWith', () {
      final notif = NotificationModel(
        id: 'notif-1',
        companyId: 'comp-1',
        userId: 'user-1',
        title: 'Title',
        body: 'Body',
        type: 'signup',
        read: false,
        createdAt: DateTime.now(),
      );

      final updated = notif.copyWith(read: true);
      expect(updated.read, true);
      expect(updated.id, 'notif-1');
    });
  });

  group('NotificationNotifier Provider Tests', () {
    late Profile partnerProfile;
    late List<NotificationModel> mockNotifications;

    setUp(() {
      partnerProfile = Profile(
        id: 'partner-1',
        companyId: 'company-1',
        role: UserRole.partner,
        fullName: 'Partner Test',
        phone: '12345678',
        email: 'partner@test.com',
        status: PartnerStatus.approved,
        createdAt: DateTime.now(),
      );

      mockNotifications = [
        NotificationModel(
          id: 'notif-1',
          companyId: 'company-1',
          userId: 'partner-1',
          title: 'Lead Stage Changed',
          body: 'Your lead was updated.',
          type: 'lead_stage_changed',
          read: false,
          createdAt: DateTime.now(),
        ),
        NotificationModel(
          id: 'notif-2',
          companyId: 'company-1',
          userId: 'partner-1',
          title: 'Payout Approved',
          body: 'Your payout is approved.',
          type: 'withdrawal_resolved',
          read: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ];
    });

    test('Should load notifications and fetch FCM token on build', () async {
      final mockDb = MockSupabaseService(mockNotifications);
      final mockFcm = MockNotificationService();

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthNotifier(partnerProfile)),
          supabaseServiceProvider.overrideWithValue(mockDb),
          notificationServiceProvider.overrideWithValue(mockFcm),
        ],
      );

      addTearDown(container.dispose);

      // Trigger the notifier read
      final state = container.read(notificationProvider);
      
      // Initially, it starts with an empty list before microtask runs
      expect(state.notifications, isEmpty);

      // Wait for the microtask to finish loading
      await Future.delayed(Duration.zero);

      final updatedState = container.read(notificationProvider);
      expect(updatedState.notifications.length, 2);
      expect(updatedState.notifications[0].id, 'notif-1');
      expect(updatedState.notifications[1].read, true);

      // Verify FCM token registration was called
      expect(mockDb.updatedFcmTokenUserId, 'partner-1');
      expect(mockDb.updatedFcmTokenValue, 'fake-fcm-token-123');
    });

    test('Should mark notification as read', () async {
      final mockDb = MockSupabaseService(mockNotifications);
      final mockFcm = MockNotificationService();

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthNotifier(partnerProfile)),
          supabaseServiceProvider.overrideWithValue(mockDb),
          notificationServiceProvider.overrideWithValue(mockFcm),
        ],
      );

      addTearDown(container.dispose);

      // Trigger build
      container.read(notificationProvider);

      await Future.delayed(Duration.zero);

      // Call markAsRead
      await container.read(notificationProvider.notifier).markAsRead('notif-1');

      final updatedState = container.read(notificationProvider);
      expect(updatedState.notifications.firstWhere((n) => n.id == 'notif-1').read, true);
      expect(mockDb.markedReadIds, contains('notif-1'));
    });

    test('Should mark all notifications as read', () async {
      final mockDb = MockSupabaseService(mockNotifications);
      final mockFcm = MockNotificationService();

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthNotifier(partnerProfile)),
          supabaseServiceProvider.overrideWithValue(mockDb),
          notificationServiceProvider.overrideWithValue(mockFcm),
        ],
      );

      addTearDown(container.dispose);

      // Trigger build
      container.read(notificationProvider);

      await Future.delayed(Duration.zero);

      // Call markAllAsRead
      await container.read(notificationProvider.notifier).markAllAsRead();

      final updatedState = container.read(notificationProvider);
      expect(updatedState.notifications.every((n) => n.read), true);
      expect(mockDb.markedAllReadCalled, true);
    });
  });
}
