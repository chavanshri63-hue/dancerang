import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LiveNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _classesSubscription;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _workshopsSubscription;

  // Track recently shown notifications to prevent duplicates
  static final Map<String, DateTime> _recentNotifications = {};

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );
    
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    try {
      final bool? initialized = await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized == null || !initialized) {
        return;
      }
    } catch (e) {
      return;
    }

    // Request permissions for Android 13+ (non-blocking)
    try {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final currentStatus = await androidImplementation.areNotificationsEnabled();
        if (currentStatus == null || !currentStatus) {
          await androidImplementation.requestNotificationsPermission();
        }
      }
    } catch (e) {
      // Ignore permission request errors
    }

    // Create Android notification channels (required for Android 8.0+)
    try {
      // Default channel (matches AndroidManifest)
      const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
        'dancerang_default_channel',
        'DanceRang Notifications',
        description: 'General notifications for DanceRang',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      
      // FCM messages channel
      const AndroidNotificationChannel fcmChannel = AndroidNotificationChannel(
        'fcm_messages',
        'FCM Messages',
        description: 'Notifications from Firebase Cloud Messaging',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      
      // Spot alerts channel
      const AndroidNotificationChannel spotChannel = AndroidNotificationChannel(
        'spot_alerts',
        'Spot Alerts',
        description: 'Notifications for class/workshop spot availability',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      
      // Enrollment channel
      const AndroidNotificationChannel enrollmentChannel = AndroidNotificationChannel(
        'enrollments',
        'Enrollment Updates',
        description: 'Notifications for successful enrollments',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      
      // Payment channel
      const AndroidNotificationChannel paymentChannel = AndroidNotificationChannel(
        'payments',
        'Payment Updates',
        description: 'Notifications for payment confirmations',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      
      // Class reminders channel
      const AndroidNotificationChannel classReminderChannel = AndroidNotificationChannel(
        'class_reminders',
        'Class Reminders',
        description: 'Notifications for upcoming classes',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      
      // Waitlist channel
      const AndroidNotificationChannel waitlistChannel = AndroidNotificationChannel(
        'waitlist',
        'Waitlist Updates',
        description: 'Notifications for waitlist updates',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      
      // Social channel
      const AndroidNotificationChannel socialChannel = AndroidNotificationChannel(
        'social',
        'Social Updates',
        description: 'Notifications for friend activities',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: false,
      );

      // Try to create channels - will work on Android, fail silently on iOS
      try {
        final androidImplementation = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidImplementation != null) {
          await androidImplementation.createNotificationChannel(defaultChannel);
          await androidImplementation.createNotificationChannel(fcmChannel);
          await androidImplementation.createNotificationChannel(spotChannel);
          await androidImplementation.createNotificationChannel(enrollmentChannel);
          await androidImplementation.createNotificationChannel(paymentChannel);
          await androidImplementation.createNotificationChannel(classReminderChannel);
          await androidImplementation.createNotificationChannel(waitlistChannel);
          await androidImplementation.createNotificationChannel(socialChannel);
        }
      } catch (e) {
        // Ignore channel creation errors - will work anyway
      }
    } catch (e) {
      // Ignore channel creation errors
    }

    _initialized = true;
  }

  /// Check and request notification permissions if needed
  static Future<bool> _ensurePermissions() async {
    try {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted = await androidImplementation.areNotificationsEnabled();
        if (granted == null || !granted) {
          final requested = await androidImplementation.requestNotificationsPermission();
          return requested ?? true; // Default to true if null
        }
        return true;
      }
      // iOS - request permissions explicitly and check status
      final iosImplementation = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        // Request permissions if not already granted
        final result = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        // On iOS, always try to show notification even if permission check fails
        // The AppDelegate will handle foreground notifications
        return result ?? true;
      }
      // If no platform implementation found, assume permission granted
      return true;
    } catch (e) {
      // On error, assume permission granted to allow notifications
      return true;
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    if (response.payload != null && response.payload!.isNotEmpty) {
      // Parse payload and navigate accordingly
      final payload = response.payload!;
      
      // Handle different notification types
      if (payload.startsWith('class_')) {
        // Navigate to class details or home screen
        // Navigation will be handled by app's navigation system
      } else if (payload.startsWith('workshop_')) {
        // Navigate to workshop details
      } else if (payload.startsWith('enrollment_')) {
        // Navigate to enrollments screen
      } else if (payload == 'payment_success') {
        // Navigate to payment history
      } else if (payload == 'class_reminder') {
        // Navigate to classes screen
      } else if (payload == 'spot_available') {
        // Navigate to classes/workshops screen
      } else if (payload == 'waitlist_added') {
        // Navigate to waitlist
      } else if (payload == 'friend_enrollment') {
        // Navigate to social/classes screen
      }
    }
  }

  /// Monitor class/workshop spots and send notifications
  static void startSpotMonitoring() {
    // Monitor classes
    _classesSubscription = _firestore
        .collection('classes')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          _checkClassSpots(change.doc);
        }
      }
    });

    // Monitor workshops
    _workshopsSubscription = _firestore
        .collection('workshops')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          _checkWorkshopSpots(change.doc);
        }
      }
    });
  }

  /// Stop monitoring streams to avoid leaks (called on app cleanup)
  static Future<void> stopSpotMonitoring() async {
    try {
      await _classesSubscription?.cancel();
      await _workshopsSubscription?.cancel();
      _classesSubscription = null;
      _workshopsSubscription = null;
    } catch (e) {
    }
  }

  static void _checkClassSpots(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final name = data['name'] ?? 'Class';
    final maxStudents = data['maxStudents'] ?? 20;
    final currentBookings = data['currentBookings'] ?? data['enrolledCount'] ?? 0;
    final availableSpots = maxStudents - currentBookings;

    if (availableSpots <= 2 && availableSpots > 0) {
      _sendSpotAlert(
        title: '🔥 Only $availableSpots spots left!',
        body: 'Hurry up! "$name" is almost full. Book now!',
        payload: 'class_${doc.id}',
      );
    } else if (availableSpots == 0) {
      _sendSpotAlert(
        title: '❌ Class Full!',
        body: '"$name" is now fully booked. Check other classes.',
        payload: 'class_${doc.id}',
      );
    }
  }

  static void _checkWorkshopSpots(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final title = data['title'] ?? 'Workshop';
    final maxParticipants = data['maxParticipants'] ?? 20;
    final currentParticipants = data['currentParticipants'] ?? data['enrolledCount'] ?? 0;
    final availableSpots = maxParticipants - currentParticipants;

    if (availableSpots <= 2 && availableSpots > 0) {
      _sendSpotAlert(
        title: '🔥 Only $availableSpots spots left!',
        body: 'Hurry up! "$title" workshop is almost full. Join now!',
        payload: 'workshop_${doc.id}',
      );
    } else if (availableSpots == 0) {
      _sendSpotAlert(
        title: '❌ Workshop Full!',
        body: '"$title" workshop is now fully booked. Check other workshops.',
        payload: 'workshop_${doc.id}',
      );
    }
  }

  static Future<void> _sendSpotAlert({
    required String title,
    required String body,
    required String payload,
  }) async {
    await initialize();
    await _ensurePermissions();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'spot_alerts',
      'Spot Alerts',
      channelDescription: 'Notifications for class/workshop spot availability',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      ongoing: false,
      channelShowBadge: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      // Ignore notification errors
    }
  }

  /// Send enrollment notification
  static Future<void> sendEnrollmentNotification({
    required String itemName,
    required String itemType,
    required String userId,
  }) async {
    // Ensure initialized
    await initialize();
    // Request permissions in background (non-blocking)
    _ensurePermissions();
    
    final title = '✅ Successfully Enrolled!';
    final body = 'You\'re now enrolled in "$itemName" $itemType';
    
    // Always try to show notification
    {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'enrollments',
        'Enrollment Updates',
        channelDescription: 'Notifications for successful enrollments',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        autoCancel: true,
        ongoing: false,
        channelShowBadge: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show local notification - ensure it displays even in foreground
      try {
        final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
        // Use await to ensure notification is shown
        final result = await _notifications.show(
          notificationId,
          title,
          body,
          notificationDetails,
          payload: 'enrollment_$itemType',
        );
        // On iOS, result might be null but notification should still show
      } catch (e) {
        // Don't silently fail - log error if needed
      }
    }

    // Save to Firestore
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'message': body,
        'type': 'enrollment',
        'priority': 'high',
        'read': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'itemName': itemName,
          'itemType': itemType,
        },
      });
    } catch (e) {
      // Ignore Firestore errors
    }
  }

  /// Send class starting notification
  static Future<void> sendClassStartingNotification({
    required String className,
    required String instructor,
    required DateTime startTime,
  }) async {
    await initialize();
    await _ensurePermissions();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'class_reminders',
      'Class Reminders',
      channelDescription: 'Notifications for upcoming classes',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      ongoing: false,
      channelShowBadge: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 2147483647,
        '⏰ Class Starting Soon!',
        '"$className" with $instructor starts in 10 minutes',
        notificationDetails,
        payload: 'class_reminder',
      );
    } catch (e) {
      // Ignore notification errors
    }
  }

  /// Send payment success notification
  static Future<void> sendPaymentSuccessNotification({
    required String amount,
    required String itemName,
    String? userId,
  }) async {
    // Ensure initialized
    await initialize();
    // Request permissions in background (non-blocking)
    _ensurePermissions();
    
    final title = '💳 Payment Successful!';
    final body = '₹$amount paid for "$itemName"';
    
    // Always try to show notification
    {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'payments',
        'Payment Updates',
        channelDescription: 'Notifications for payment confirmations',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        autoCancel: true,
        ongoing: false,
        channelShowBadge: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show local notification
      try {
        final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
        await _notifications.show(
          notificationId,
          title,
          body,
          notificationDetails,
          payload: 'payment_success',
        );
      } catch (e) {
        // Ignore notification errors
      }
    }

    // Save to Firestore if userId provided
    if (userId != null) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add({
          'title': title,
          'body': body,
          'message': body,
          'type': 'payment',
          'priority': 'high',
          'read': false,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'data': {
            'amount': amount,
            'itemName': itemName,
          },
        });
      } catch (e) {
        // Ignore Firestore errors
      }
    }
  }

  /// Send waitlist notification
  static Future<void> sendWaitlistNotification({
    required String itemName,
    required int position,
  }) async {
    await initialize();
    await _ensurePermissions();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'waitlist',
      'Waitlist Updates',
      channelDescription: 'Notifications for waitlist updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      ongoing: false,
      channelShowBadge: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 2147483647,
        '📋 Added to Waitlist',
        'You\'re #$position on the waitlist for "$itemName"',
        notificationDetails,
        payload: 'waitlist_added',
      );
    } catch (e) {
      // Ignore notification errors
    }
  }

  /// Send spot available notification
  static Future<void> sendSpotAvailableNotification({
    required String itemName,
    required String itemType,
    required String userId,
  }) async {
    await initialize();
    await _ensurePermissions();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'spot_alerts',
      'Spot Alerts',
      channelDescription: 'Notifications for available spots',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      ongoing: false,
      channelShowBadge: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 2147483647,
        '🎉 Spot Available!',
        'A spot opened up for "$itemName" $itemType. Book now!',
        notificationDetails,
        payload: 'spot_available',
      );
    } catch (e) {
      // Ignore notification errors
    }
  }

  /// Send friend enrollment notification
  static Future<void> sendFriendEnrollmentNotification({
    required String friendName,
    required String itemName,
    required String itemType,
    required String friendId,
  }) async {
    await initialize();
    await _ensurePermissions();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'social',
      'Social Updates',
      channelDescription: 'Notifications for friend activities',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: false,
      playSound: true,
      autoCancel: true,
      ongoing: false,
      channelShowBadge: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 2147483647,
        '👥 Friend Activity',
        '$friendName just enrolled in "$itemName" $itemType',
        notificationDetails,
        payload: 'friend_enrollment',
      );
    } catch (e) {
      // Ignore notification errors
    }
  }

  /// Show local notification (for FCM foreground messages)
  /// Prevents duplicate notifications within 5 seconds
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    await initialize();
    final hasPermission = await _ensurePermissions();
    
    if (!hasPermission) {
      return;
    }

    final notificationKey = '$title|$body';
    final now = DateTime.now();
    
    if (_recentNotifications.containsKey(notificationKey)) {
      final lastShown = _recentNotifications[notificationKey]!;
      final diff = now.difference(lastShown);
      if (diff.inSeconds < 5) {
        return;
      }
    }
    
    // Track this notification
    _recentNotifications[notificationKey] = now;
    
    // Clean up old entries (older than 10 seconds)
    _recentNotifications.removeWhere((key, timestamp) {
      return now.difference(timestamp).inSeconds > 10;
    });

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'fcm_messages',
      'FCM Messages',
      channelDescription: 'Notifications from Firebase Cloud Messaging',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      // Ignore notification errors
    }
  }

  /// Send cash payment request notification
  static Future<void> sendCashPaymentRequestNotification({
    required String amount,
    required String description,
    required String userId,
  }) async {
    await initialize();
    await _ensurePermissions();
    
    final title = '💰 Cash Payment Request';
    final body = '₹$amount for $description - Pending admin approval';
    
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'payments',
        'Payment Updates',
        channelDescription: 'Notifications for payment confirmations',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        autoCancel: true,
        ongoing: false,
        channelShowBadge: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      try {
        final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
        await _notifications.show(
          notificationId,
          title,
          body,
          notificationDetails,
          payload: 'cash_payment_request',
        );
    } catch (e) {
      // Ignore notification errors
    }

    // Save to Firestore
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'message': body,
        'type': 'cash_payment_request',
        'priority': 'normal',
        'read': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'amount': amount,
          'description': description,
        },
      });
    } catch (e) {
      // Ignore Firestore errors
    }
  }

  /// Send approval notification
  static Future<void> sendApprovalNotification({
    required String userId,
    required String type,
    required String description,
    bool isApproved = true,
  }) async {
    await initialize();
    _ensurePermissions();
    
    final title = isApproved ? '✅ Request Approved!' : '❌ Request Rejected';
    final body = isApproved 
        ? 'Your $type request for "$description" has been approved!'
        : 'Your $type request for "$description" has been rejected.';
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'approvals',
      'Approval Updates',
      channelDescription: 'Notifications for approval status',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      ongoing: false,
      channelShowBadge: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: isApproved ? 'approval_approved' : 'approval_rejected',
      );
    } catch (e) {
      // Ignore notification errors
    }

    // Save to Firestore
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'message': body,
        'type': isApproved ? 'approval_approved' : 'approval_rejected',
        'priority': 'high',
        'read': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'type': type,
          'description': description,
          'status': isApproved ? 'approved' : 'rejected',
        },
      });
    } catch (e) {
      // Ignore Firestore errors
    }
  }

  /// Send new class notification
  static Future<void> sendNewClassNotification({
    required String className,
    required String instructor,
    required String userId,
    String? dateTime,
  }) async {
    await initialize();
    _ensurePermissions();
    
    final title = '🆕 New Class Available!';
    final body = dateTime != null
        ? '"$className" with $instructor - $dateTime'
        : '"$className" with $instructor';
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'general',
      'General Updates',
      channelDescription: 'General notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      ongoing: false,
      channelShowBadge: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: 'new_class',
      );
    } catch (e) {
      // Ignore notification errors
    }

    // Save to Firestore
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'message': body,
        'type': 'new_class',
        'priority': 'normal',
        'read': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'className': className,
          'instructor': instructor,
          'dateTime': dateTime,
        },
      });
    } catch (e) {
      // Ignore Firestore errors
    }
  }

  /// Send new workshop notification
  static Future<void> sendNewWorkshopNotification({
    required String workshopTitle,
    required String instructor,
    required String userId,
    String? date,
    String? time,
  }) async {
    await initialize();
    _ensurePermissions();
    
    final title = '🆕 New Workshop Available!';
    final body = date != null && time != null
        ? '"$workshopTitle" with $instructor - $date at $time'
        : '"$workshopTitle" with $instructor';
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'general',
      'General Updates',
      channelDescription: 'General notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      ongoing: false,
      channelShowBadge: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: 'new_workshop',
      );
    } catch (e) {
      // Ignore notification errors
    }

    // Save to Firestore
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'message': body,
        'type': 'new_workshop',
        'priority': 'normal',
        'read': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'workshopTitle': workshopTitle,
          'instructor': instructor,
          'date': date,
          'time': time,
        },
      });
    } catch (e) {
      // Ignore Firestore errors
    }
  }

  /// Send birthday wish notification
  static Future<void> sendBirthdayWishNotification({
    required String userName,
    required String userId,
  }) async {
    await initialize();
    _ensurePermissions();
    
    final title = '🎉 Happy Birthday!';
    final body = 'Wishing you a wonderful birthday, $userName! May your special day be filled with joy and dance!';
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'general',
      'General Updates',
      channelDescription: 'General notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      ongoing: false,
      channelShowBadge: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: 'birthday',
      );
    } catch (e) {
      // Ignore notification errors
    }
  }

  /// Send welcome notification on login
  static Future<void> sendWelcomeNotification({
    required String userName,
    required String userId,
  }) async {
    await initialize();
    _ensurePermissions();
    
    final title = '👋 Welcome back, $userName!';
    final body = 'We\'re excited to have you back. Check out our latest classes and workshops!';
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'general',
      'General Updates',
      channelDescription: 'General notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      ongoing: false,
      channelShowBadge: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: 'welcome',
      );
    } catch (e) {
      // Ignore notification errors
    }

    // Save to Firestore
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'message': body,
        'type': 'welcome',
        'priority': 'normal',
        'read': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'userName': userName,
        },
      });
    } catch (e) {
      // Ignore Firestore errors
    }
  }

  /// Test notification - for debugging
  static Future<void> sendTestNotification() async {
    await initialize();
    await _ensurePermissions();

    // Save to Firestore first so it appears in-app
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .add({
          'title': '🧪 Test Notification',
          'body': 'If you see this, local notifications are working!',
          'message': 'If you see this, local notifications are working!',
          'type': 'test',
          'priority': 'normal',
          'read': false,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Ignore Firestore errors
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'fcm_messages',
      'FCM Messages',
      channelDescription: 'Notifications from Firebase Cloud Messaging',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
      await _notifications.show(
        notificationId,
        '🧪 Test Notification',
        'If you see this, local notifications are working!',
        notificationDetails,
        payload: 'test',
      );
    } catch (e) {
      rethrow;
    }
  }
}
