import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'payment_service.dart';

/// Service for handling automatic subscription renewals
/// Similar to Netflix's automatic renewal system
class SubscriptionRenewalService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check and process automatic renewals for all active subscriptions
  static Future<void> processAutomaticRenewals() async {
    try {
      
      // Check if user is authenticated before proceeding
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      // Check if user is admin before proceeding
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        
        final userRole = userDoc.data()?['role'] as String?;
        if (userRole != 'admin' && userRole != 'Admin') {
          return;
        }
      } catch (e) {
        return;
      }

      // Get all active subscriptions that are due for renewal
      // Note: Using a simpler query to avoid index requirements
      final now = DateTime.now();
      QuerySnapshot<Map<String, dynamic>> renewalQuery;
      
      try {
        // Use a simpler approach - get all subscriptions and filter client-side
        // This avoids the complex index requirement
        renewalQuery = await _firestore
            .collectionGroup('subscriptions')
            .get();
      } catch (e) {
        return;
      }

      // Filter subscriptions that need renewal
      final subscriptionsToRenew = renewalQuery.docs.where((doc) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final autoRenew = data['autoRenew'] as bool? ?? false;
        final nextRenewalDate = data['nextRenewalDate'] as Timestamp?;
        final paymentProvider = (data['paymentProvider'] ?? data['source'] ?? data['store'] ?? '')
            .toString()
            .toLowerCase();

        // Skip store-managed subscriptions (Play Store / App Store)
        if (paymentProvider.contains('play') || paymentProvider.contains('app_store') || paymentProvider.contains('iap')) {
          return false;
        }
        
        // Only process active subscriptions
        if (status != 'active' || !autoRenew || nextRenewalDate == null) return false;
        
        final renewalDateTime = nextRenewalDate.toDate();
        return renewalDateTime.isBefore(now) || renewalDateTime.isAtSameMomentAs(now);
      }).toList();


      for (final doc in subscriptionsToRenew) {
        try {
          await _processSingleRenewal(doc);
        } catch (e) {
          // Continue with other renewals even if one fails
        }
      }

    } catch (e) {
      // Don't throw the error to prevent app crashes
    }
  }

  /// Process renewal for a single subscription
  static Future<void> _processSingleRenewal(QueryDocumentSnapshot<Map<String, dynamic>> subscriptionDoc) async {
    final subscriptionData = subscriptionDoc.data();
    final subscriptionId = subscriptionDoc.id;
    final userId = subscriptionDoc.reference.parent.parent?.id;
    
    if (userId == null) {
      return;
    }

    final planId = subscriptionData['planId'] as String?;
    final planName = subscriptionData['planName'] as String?;
    final amount = subscriptionData['amount'] as int?;
    final billingCycle = subscriptionData['billingCycle'] as String?;

    if (planId == null || amount == null || billingCycle == null) {
      return;
    }


    try {
      // Attempt automatic payment
      final paymentResult = await _processAutomaticPayment(
        userId: userId,
        subscriptionId: subscriptionId,
        amount: amount,
        planName: planName ?? 'Subscription Renewal',
        billingCycle: billingCycle,
      );

      if (paymentResult['success'] == true) {
        // Update subscription with new dates
        await _updateSubscriptionAfterRenewal(
          userId: userId,
          subscriptionId: subscriptionId,
          billingCycle: billingCycle,
          paymentId: paymentResult['paymentId'],
        );
        
      } else {
        // Handle failed payment
        await _handleFailedRenewal(
          userId: userId,
          subscriptionId: subscriptionId,
          reason: paymentResult['message'] ?? 'Payment failed',
        );
        
      }
    } catch (e) {
      await _handleFailedRenewal(
        userId: userId,
        subscriptionId: subscriptionId,
        reason: e.toString(),
      );
    }
  }

  /// Process automatic payment for renewal
  static Future<Map<String, dynamic>> _processAutomaticPayment({
    required String userId,
    required String subscriptionId,
    required int amount,
    required String planName,
    required String billingCycle,
  }) async {
    try {
      // Use existing payment service for consistency
      final paymentId = 'renewal_${subscriptionId}_${DateTime.now().millisecondsSinceEpoch}';
      
      final result = await PaymentService.processPayment(
        paymentId: paymentId,
        amount: amount,
        description: '$planName - $billingCycle renewal',
        paymentType: 'subscription_renewal',
        itemId: subscriptionId,
        metadata: {
          'userId': userId,
          'planName': planName,
          'billingCycle': billingCycle,
          'isRenewal': true,
        },
      );

      return {
        'success': result['success'] == true,
        'paymentId': paymentId,
        'message': result['message'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Payment processing error: $e',
      };
    }
  }

  /// Update subscription after successful renewal
  static Future<void> _updateSubscriptionAfterRenewal({
    required String userId,
    required String subscriptionId,
    required String billingCycle,
    required String paymentId,
  }) async {
    final now = DateTime.now();
    final nextRenewalDate = _calculateNextRenewalDate(now, billingCycle);

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('subscriptions')
        .doc(subscriptionId)
        .update({
      'lastRenewalDate': Timestamp.fromDate(now),
      'nextRenewalDate': Timestamp.fromDate(nextRenewalDate),
      'endDate': Timestamp.fromDate(nextRenewalDate),
      'renewalCount': FieldValue.increment(1),
      'lastPaymentId': paymentId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Add renewal history
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('subscriptions')
        .doc(subscriptionId)
        .collection('renewalHistory')
        .add({
      'renewalDate': Timestamp.fromDate(now),
      'paymentId': paymentId,
      'amount': await _getSubscriptionAmount(subscriptionId),
      'billingCycle': billingCycle,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Handle failed renewal
  static Future<void> _handleFailedRenewal({
    required String userId,
    required String subscriptionId,
    required String reason,
  }) async {
    final now = DateTime.now();
    
    // Update subscription status
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('subscriptions')
        .doc(subscriptionId)
        .update({
      'status': 'payment_failed',
      'lastFailureDate': Timestamp.fromDate(now),
      'failureReason': reason,
      'retryCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Add failure to history
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('subscriptions')
        .doc(subscriptionId)
        .collection('renewalHistory')
        .add({
      'renewalDate': Timestamp.fromDate(now),
      'status': 'failed',
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Send notification to user about failed payment
    await _sendRenewalFailureNotification(userId, subscriptionId, reason);
  }

  /// Calculate next renewal date based on billing cycle
  static DateTime _calculateNextRenewalDate(DateTime currentDate, String billingCycle) {
    switch (billingCycle) {
      case 'monthly':
        return DateTime(
          currentDate.year,
          currentDate.month + 1,
          currentDate.day,
        );
      case 'quarterly':
        return DateTime(
          currentDate.year,
          currentDate.month + 3,
          currentDate.day,
        );
      case 'annual':
        return DateTime(
          currentDate.year + 1,
          currentDate.month,
          currentDate.day,
        );
      default:
        return currentDate.add(const Duration(days: 30));
    }
  }

  /// Get subscription amount for renewal
  static Future<int> _getSubscriptionAmount(String subscriptionId) async {
    try {
      // Find the subscription document across all users
      final subscriptionQuery = await _firestore
          .collectionGroup('subscriptions')
          .where(FieldPath.documentId, isEqualTo: subscriptionId)
          .limit(1)
          .get();
      
      if (subscriptionQuery.docs.isNotEmpty) {
        return subscriptionQuery.docs.first.data()['amount'] as int? ?? 0;
      }
      
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Send notification about failed renewal
  static Future<void> _sendRenewalFailureNotification(
    String userId,
    String subscriptionId,
    String reason,
  ) async {
    try {
      // This would integrate with your notification service
      // For now, just log the failure
      
      // You can add actual notification sending here
      // await NotificationService.sendNotification(
      //   userId: userId,
      //   title: 'Subscription Renewal Failed',
      //   body: 'Your subscription renewal failed. Please update your payment method.',
      // );
    } catch (e) {
    }
  }

  /// Enable/disable auto-renewal for a subscription
  static Future<bool> setAutoRenewal({
    required String userId,
    required String subscriptionId,
    required bool autoRenew,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .doc(subscriptionId)
          .update({
        'autoRenew': autoRenew,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get renewal history for a subscription
  static Future<List<Map<String, dynamic>>> getRenewalHistory({
    required String userId,
    required String subscriptionId,
  }) async {
    try {
      final historySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .doc(subscriptionId)
          .collection('renewalHistory')
          .orderBy('createdAt', descending: true)
          .get();

      return historySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Check if user has active subscription
  static Future<bool> hasActiveSubscription(String userId) async {
    try {
      final now = DateTime.now();
      final subscriptionSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .where('endDate', isGreaterThan: Timestamp.fromDate(now))
          .limit(1)
          .get();

      return subscriptionSnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get user's current subscription details
  static Future<Map<String, dynamic>?> getCurrentSubscription(String userId) async {
    try {
      final now = DateTime.now();
      final subscriptionSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .where('endDate', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('endDate', descending: true)
          .limit(1)
          .get();

      if (subscriptionSnapshot.docs.isNotEmpty) {
        final doc = subscriptionSnapshot.docs.first;
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
}
