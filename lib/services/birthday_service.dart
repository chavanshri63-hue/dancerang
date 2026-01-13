import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'live_notification_service.dart';

/// Service to check and send birthday wishes automatically
class BirthdayService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check all users and send birthday wishes if it's their birthday
  static Future<void> checkAndSendBirthdayWishes() async {
    try {
      final today = DateTime.now();
      final todayMonth = today.month;
      final todayDay = today.day;


      // Get all users with DOB
      final usersSnapshot = await _firestore
          .collection('users')
          .where('dob', isNotEqualTo: null)
          .get();

      int birthdayCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        try {
          final userData = userDoc.data();
          final dobString = userData['dob'] as String?;
          
          if (dobString == null || dobString.isEmpty) continue;

          // Parse DOB (ISO 8601 format: YYYY-MM-DD)
          final dob = DateTime.tryParse(dobString);
          if (dob == null) continue;

          // Check if today is their birthday (ignore year)
          if (dob.month == todayMonth && dob.day == todayDay) {
            final userName = userData['name'] ?? 'User';
            final userId = userDoc.id;

            // Check if birthday wish already sent today
            final todayStart = DateTime(today.year, today.month, today.day);
            final birthdayCheck = await _firestore
                .collection('users')
                .doc(userId)
                .collection('notifications')
                .where('type', isEqualTo: 'birthday')
                .where('createdAt', isGreaterThan: Timestamp.fromDate(todayStart))
                .limit(1)
                .get();

            if (birthdayCheck.docs.isEmpty) {
              // Send birthday wish notification
              await _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('notifications')
                  .add({
                'title': '🎉 Happy Birthday!',
                'body': 'Wishing you a wonderful birthday, $userName! May your special day be filled with joy and dance!',
                'message': 'Wishing you a wonderful birthday, $userName! May your special day be filled with joy and dance!',
                'type': 'birthday',
                'priority': 'normal',
                'read': false,
                'isRead': false,
                'createdAt': FieldValue.serverTimestamp(),
                'data': {
                  'userId': userId,
                  'userName': userName,
                },
              });
              
              // Send local notification
              try {
                await LiveNotificationService.sendBirthdayWishNotification(
                  userName: userName,
                  userId: userId,
                );
              } catch (e) {
                // Ignore notification errors
              }
              
              birthdayCount++;
            }
          }
        } catch (e) {
          continue;
        }
      }

    } catch (e) {
    }
  }
}

