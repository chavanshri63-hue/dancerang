import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SubscriptionExpiryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check and update expired subscriptions for all users
  static Future<void> checkAllExpiredSubscriptions() async {
    try {
      final now = Timestamp.now();
      
      // Get all active subscriptions that have expired
      final expiredSubscriptions = await _firestore
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .where('endDate', isLessThan: now)
          .get();

      for (final doc in expiredSubscriptions.docs) {
        await _expireSubscription(doc.id, doc.data());
      }

    } catch (e) {
    }
  }

  /// Expire a specific subscription
  static Future<void> _expireSubscription(String subscriptionId, Map<String, dynamic> data) async {
    try {
      final userId = data['userId'] as String;
      
      // Update global subscription
      await _firestore.collection('subscriptions').doc(subscriptionId).update({
        'status': 'expired',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user subscription
      final userSubscriptions = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('planId', isEqualTo: data['planId'])
          .where('status', isEqualTo: 'active')
          .get();

      for (final userSub in userSubscriptions.docs) {
        await userSub.reference.update({
          'status': 'expired',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Send notification to user about expired subscription
      await _sendExpiryNotification(userId, data);

    } catch (e) {
    }
  }

  /// Send expiry notification to user
  static Future<void> _sendExpiryNotification(String userId, Map<String, dynamic> subscriptionData) async {
    try {
      // Check if notification already sent today
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      
      final notificationCheck = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('type', isEqualTo: 'subscription_expired')
          .where('data.planId', isEqualTo: subscriptionData['planId'])
          .where('createdAt', isGreaterThan: Timestamp.fromDate(todayStart))
          .limit(1)
          .get();

      if (notificationCheck.docs.isNotEmpty) {
        return; // Already sent today
      }

      await _firestore.collection('users').doc(userId).collection('notifications').add({
        'title': 'Subscription Expired',
        'body': 'Your subscription has expired. Renew to continue accessing premium content.',
        'message': 'Your subscription has expired. Renew to continue accessing premium content.',
        'type': 'subscription_expired',
        'priority': 'high',
        'read': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'planId': subscriptionData['planId'],
          'action': 'renew_subscription',
        },
      });
    } catch (e) {
    }
  }

  /// Check if user has active subscription
  static Future<bool> hasActiveSubscription(String userId) async {
    try {
      final now = Timestamp.now();
      
      final subscription = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .where('endDate', isGreaterThan: now)
          .limit(1)
          .get();

      return subscription.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get user's subscription details
  static Future<Map<String, dynamic>?> getActiveSubscription(String userId) async {
    try {
      final now = Timestamp.now();
      
      final subscription = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .where('endDate', isGreaterThan: now)
          .limit(1)
          .get();

      if (subscription.docs.isNotEmpty) {
        return subscription.docs.first.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Renew subscription (extend by 1 month)
  static Future<bool> renewSubscription(String userId, String planId) async {
    try {
      final now = Timestamp.now();
      final newEndDate = DateTime.now();
      newEndDate.add(const Duration(days: 30)); // Add 30 days

      // Update user subscription
      final userSubscriptions = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('planId', isEqualTo: planId)
          .where('status', isEqualTo: 'active')
          .get();

      if (userSubscriptions.docs.isNotEmpty) {
        await userSubscriptions.docs.first.reference.update({
          'endDate': Timestamp.fromDate(newEndDate),
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update global subscription
        final globalSubscriptions = await _firestore
            .collection('subscriptions')
            .where('userId', isEqualTo: userId)
            .where('planId', isEqualTo: planId)
            .where('status', isEqualTo: 'active')
            .get();

        if (globalSubscriptions.docs.isNotEmpty) {
          await globalSubscriptions.docs.first.reference.update({
            'endDate': Timestamp.fromDate(newEndDate),
            'status': 'active',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get subscription expiry date for current user
  static Future<DateTime?> getCurrentUserExpiryDate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final subscription = await getActiveSubscription(user.uid);
      if (subscription != null && subscription['endDate'] != null) {
        final timestamp = subscription['endDate'] as Timestamp;
        return timestamp.toDate();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
