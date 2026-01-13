import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class PaymentValidityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int validityDays = 40;
  static final StreamController<Map<String, dynamic>> _validityController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  static Stream<Map<String, dynamic>> get validityStream => _validityController.stream;

  /// Check and update payment validity for all users
  static Future<void> checkAllUsersValidity() async {
    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Student')
          .get();

      for (final userDoc in usersSnapshot.docs) {
        await _checkUserValidity(userDoc.id);
      }
    } catch (e) {
    }
  }

  /// Check validity for a specific user
  static Future<void> _checkUserValidity(String userId) async {
    try {
      // Get user's active enrollments
      final enrollmentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .where('status', isEqualTo: 'enrolled')
          .get();

      final now = DateTime.now();
      final validityThreshold = now.subtract(const Duration(days: validityDays));

      for (final enrollmentDoc in enrollmentsSnapshot.docs) {
        final enrollmentData = enrollmentDoc.data();
        final paymentTimestamp = enrollmentData['ts'] as Timestamp?;
        
        if (paymentTimestamp != null) {
          final paymentDate = paymentTimestamp.toDate();
          
          if (paymentDate.isBefore(validityThreshold)) {
            // Payment expired
            await _handleExpiredPayment(userId, enrollmentDoc.id, enrollmentData);
          } else {
            // Check if approaching expiry (5 days before)
            final expiryDate = paymentDate.add(const Duration(days: validityDays));
            final daysUntilExpiry = expiryDate.difference(now).inDays;
            
            if (daysUntilExpiry <= 5 && daysUntilExpiry > 0) {
              await _sendExpiryReminder(userId, enrollmentDoc.id, enrollmentData, daysUntilExpiry);
            }
          }
        }
      }
    } catch (e) {
    }
  }

  /// Handle expired payment
  static Future<void> _handleExpiredPayment(
    String userId, 
    String enrollmentId, 
    Map<String, dynamic> enrollmentData
  ) async {
    try {
      // Update enrollment status
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .doc(enrollmentId)
          .update({
        'status': 'expired',
        'expiredAt': FieldValue.serverTimestamp(),
      });

      // Notification sending disabled

    } catch (e) {
    }
  }

  /// Send expiry reminder
  static Future<void> _sendExpiryReminder(
    String userId,
    String enrollmentId,
    Map<String, dynamic> enrollmentData,
    int daysUntilExpiry
  ) async {
    try {
      // Check if reminder already sent today
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      
      final reminderCheck = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('type', isEqualTo: 'payment_reminder')
          .where('data.enrollmentId', isEqualTo: enrollmentId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(todayStart))
          .limit(1)
          .get();

      if (reminderCheck.docs.isNotEmpty) {
        return; // Already sent today
      }

      final itemName = enrollmentData['title'] ?? enrollmentData['itemName'] ?? 'Class';
      final reminderMessage = daysUntilExpiry == 0
          ? 'Your payment validity for "$itemName" expires today. Please renew to continue.'
          : 'Your payment validity for "$itemName" expires in $daysUntilExpiry days. Please renew soon.';

      // Send notification to user
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': daysUntilExpiry == 0 ? '⏰ Payment Expires Today!' : '⏰ Payment Expiring Soon',
        'body': reminderMessage,
        'message': reminderMessage,
        'type': 'payment_reminder',
        'priority': daysUntilExpiry == 0 ? 'high' : 'medium',
        'read': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'enrollmentId': enrollmentId,
          'itemName': itemName,
          'daysUntilExpiry': daysUntilExpiry,
        },
      });

    } catch (e) {
    }
  }

  /// Get user's validity status
  static Future<Map<String, dynamic>> getUserValidityStatus(String userId) async {
    try {
      final enrollmentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .where('status', isEqualTo: 'enrolled')
          .get();

      final now = DateTime.now();
      final validityThreshold = now.subtract(const Duration(days: validityDays));
      
      int activeEnrollments = 0;
      int expiringSoon = 0;
      int expired = 0;

      for (final enrollmentDoc in enrollmentsSnapshot.docs) {
        final enrollmentData = enrollmentDoc.data();
        final paymentTimestamp = enrollmentData['ts'] as Timestamp?;
        
        if (paymentTimestamp != null) {
          final paymentDate = paymentTimestamp.toDate();
          activeEnrollments++;
          
          if (paymentDate.isBefore(validityThreshold)) {
            expired++;
          } else {
            final expiryDate = paymentDate.add(const Duration(days: validityDays));
            final daysUntilExpiry = expiryDate.difference(now).inDays;
            
            if (daysUntilExpiry <= 5) {
              expiringSoon++;
            }
          }
        }
      }

      return {
        'activeEnrollments': activeEnrollments,
        'expiringSoon': expiringSoon,
        'expired': expired,
        'validityDays': validityDays,
      };
    } catch (e) {
      return {
        'activeEnrollments': 0,
        'expiringSoon': 0,
        'expired': 0,
        'validityDays': validityDays,
      };
    }
  }

  static void dispose() {
    _validityController.close();
  }
}
