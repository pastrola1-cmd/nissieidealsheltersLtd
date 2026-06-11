import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  bool _firebaseInitialized = false;

  /// Initializes Firebase and FCM defensively.
  /// If configuration is missing or it fails, it will catch the error and proceed.
  Future<void> initialize() async {
    if (_firebaseInitialized) return;

    try {
      // Defensive initialization - might throw if no google-services.json exists
      await Firebase.initializeApp();
      _firebaseInitialized = true;
      
      // Request permission
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Handle foreground messages if needed
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Handle foreground message
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
        }
      });
    } catch (e) {
      debugPrint('Firebase Messaging initialization failed (expected on local sandbox): $e');
      _firebaseInitialized = false;
    }
  }

  /// Fetches the FCM token, returning null if Firebase initialization failed.
  Future<String?> getFcmToken() async {
    if (!_firebaseInitialized) {
      // Try to initialize in case it wasn't yet
      await initialize();
    }

    if (!_firebaseInitialized) return null;

    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
      return null;
    }
  }
}
