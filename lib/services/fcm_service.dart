import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'live_notification_service.dart';

/// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  // Show local notification for background messages
  if (message.notification != null) {
    await LiveNotificationService.showLocalNotification(
      title: message.notification!.title ?? 'Notification',
      body: message.notification!.body ?? '',
      payload: message.data.toString(),
    );
  }
}

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static String? _currentToken;

  /// Initialize FCM service
  static Future<void> initialize() async {
    try {
      // Request permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Get FCM token even if provisional (for iOS)
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        await _getToken();
        
        // Setup token refresh listener
        _messaging.onTokenRefresh.listen((newToken) {
          _saveToken(newToken);
        });

        // Setup foreground message handler
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Setup message opened app handler
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // Check if app was opened from notification
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
      }
    } catch (e) {
      // Ignore initialization errors
    }
  }

  /// Get FCM token
  static Future<String?> _getToken() async {
    try {
      _currentToken = await _messaging.getToken();
      if (_currentToken != null) {
        await _saveToken(_currentToken!);
      }
      return _currentToken;
    } catch (e) {
      return null;
    }
  }

  /// Save FCM token to Firestore
  static Future<void> _saveToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      _currentToken = token;
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Show local notification
    if (message.notification != null) {
      await LiveNotificationService.showLocalNotification(
        title: message.notification!.title ?? 'Notification',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }

    // Save to Firestore if needed
    if (message.data.isNotEmpty) {
      await _saveNotificationToFirestore(message);
    }
  }

  /// Handle message when app is opened from notification
  static void _handleMessageOpenedApp(RemoteMessage message) {

    // Handle navigation based on message data
    // This will be handled by the app's navigation system
    if (message.data.containsKey('screen')) {
      // Navigate to specific screen if needed
      // Navigation logic can be added here
    }
  }

  /// Save notification to Firestore
  static Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add({
        'title': message.notification?.title ?? message.data['title'] ?? 'Notification',
        'body': message.notification?.body ?? message.data['body'] ?? message.data['message'] ?? '',
        'message': message.notification?.body ?? message.data['body'] ?? message.data['message'] ?? '',
        'type': message.data['type'] ?? 'general',
        'priority': message.data['priority'] ?? 'normal',
        'read': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': message.data,
      });
    } catch (e) {
    }
  }

  /// Get current FCM token
  static String? get currentToken => _currentToken;

  /// Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
    }
  }

  /// Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
    }
  }
}

