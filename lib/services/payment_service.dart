import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:async';
import '../screens/receipt_screen.dart';
import 'live_notification_service.dart';

/// PaymentService handles all payment-related operations using Razorpay
/// 
/// This service provides:
/// - Payment processing for classes, workshops, and events
/// - Razorpay integration with proper signature verification
/// - Payment history and status tracking
/// - Error handling and user feedback
class PaymentService {
  // Global navigator key to navigate from service callbacks
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  // Razorpay instance
  static Razorpay? _razorpay;
  static String _publicKeyId = const String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: '',
  );
  
  // Global refresh controller for cross-screen updates
  static final StreamController<Map<String, dynamic>> _refreshController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Stream for listening to payment success events
  static Stream<Map<String, dynamic>> get refreshStream => _refreshController.stream;
  
  // Payment status constants
  static const String paymentPending = 'pending';
  static const String paymentSuccess = 'success';
  static const String paymentFailed = 'failed';
  static const String paymentCancelled = 'cancelled';
  static const String paymentPendingCash = 'pending_cash';

  /// Initialize payment service
  static void initialize() {
    if (_razorpay != null) return;
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    // Best-effort: load Razorpay key from Firestore if not provided via --dart-define
    // Firestore fetch is lightweight; cached in memory for this process.
    // Do not block app startup; background load.
    // ignore: discarded_futures
    _ensureRazorpayKeyLoaded();
  }

  static Future<void> _ensureRazorpayKeyLoaded() async {
    if (_publicKeyId.isNotEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('razorpay')
          .get();
      final data = snap.data() ?? {};
      final keyId = (data['keyId'] ?? '').toString().trim();
      if (keyId.isNotEmpty) {
        _publicKeyId = keyId;
      } else {
      }
    } catch (e) {
    }
  }

  /// Process payment for classes/workshops
  static Future<Map<String, dynamic>> processPayment({
    required String paymentId,
    required int amount,
    required String description,
    required String paymentType, // 'class_fee', 'workshop', 'event'
    required String itemId, // class_id or workshop_id
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create payment record in Firestore
      final paymentData = {
        'id': paymentId,
        'user_id': user.uid,
        'amount': amount,
        'description': description,
        'payment_type': paymentType,
        'payment_method': 'online',
        'item_id': itemId,
        'status': paymentPending,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      };

      // Save payment record (do not block order creation)
      final paymentWrite = FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .set(paymentData);

      // Create Razorpay order via Cloud Function (amount in paise)
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final createOrder = functions.httpsCallable('createRazorpayOrder');
      final receipt = 'rcpt_$paymentId';
      // Razorpay expects amount in paise. Convert rupees -> paise
      // Validate to prevent overflow (max 2^31 / 100 = ~21M rupees)
      if (amount > 21474836) {
        throw Exception('Payment amount too large. Maximum allowed: ₹21,474,836');
      }
      final int amountPaise = amount * 100;
      final orderFuture = createOrder.call({
        'amount': amountPaise, // in paise
        'receipt': receipt,
      });
      final keyFuture = _ensureRazorpayKeyLoaded();

      final orderResp = await orderFuture;
      await keyFuture;
      await paymentWrite;

      final data = Map<String, dynamic>.from((orderResp.data ?? {}) as Map);
      final orderId = (data['orderId'] ?? '') as String;
      final orderAmount = (data['amount'] ?? amount) as int;
      final currency = (data['currency'] ?? 'INR') as String;
      if (orderId.isEmpty) {
        throw Exception('ORDER_ID_MISSING');
      }

      // Open Razorpay Checkout
      final options = {
        'key': _publicKeyId,
        'amount': orderAmount, // in paise
        'currency': currency,
        'name': 'DanceRang',
        'description': description,
        'order_id': orderId,
        'retry': {'enabled': true, 'max_count': 1},
        'method': {
          'upi': true,
          'netbanking': true,
          'card': true,
          'wallet': true,
        },
        'prefill': {
          'contact': user.phoneNumber ?? '',
          'email': user.email ?? '',
          'name': user.displayName ?? 'DanceRang User',
        },
        'theme': {'color': '#E53935'},
      };

      _pendingPaymentContext = _PendingPaymentContext(
        paymentId: paymentId,
        amount: amount,
        orderId: orderId,
      );

      if (_publicKeyId.isEmpty) {
        throw Exception('Missing Razorpay key. Configure appSettings/razorpay.keyId or pass --dart-define=RAZORPAY_KEY_ID=...');
      }
      _razorpay!.open(options);

      // The result will arrive via event handlers; return pending
      return {
        'success': true,
        'payment_id': paymentId,
        'status': paymentPending,
        'order_id': orderId,
      };
      
    } on FirebaseFunctionsException catch (e) {
      final details = (e.details is Map)
          ? (((e.details as Map)['message']) ?? e.message)
          : e.message;
      
      // Handle specific error codes with user-friendly messages
      String userFriendlyError = 'Payment processing failed. Please try again.';
      
      if (e.code == 'invalid-argument' || 
          details?.toString().contains('INVALID_AMOUNT') == true ||
          details?.toString().contains('CREATE_ORDER_FAILED') == true) {
        // Amount validation failed - show friendly message
        userFriendlyError = 'Invalid payment amount. Please check the amount and try again.';
      } else if (e.code == 'failed-precondition' || 
                 details?.toString().contains('MISSING_KEYS') == true) {
        userFriendlyError = 'Payment service configuration error. Please contact support.';
      } else if (e.code == 'unauthenticated') {
        userFriendlyError = 'Please login to continue with payment.';
      } else if (details != null && details.toString().isNotEmpty) {
        // Use the details if available
        userFriendlyError = details.toString();
      }
      
      return {
        'success': false,
        'error': userFriendlyError,
        'payment_id': paymentId,
      };
    } catch (e) {
      String userFriendlyError = 'Payment processing failed. Please try again.';
      
      // Provide more specific error messages
      if (e.toString().contains('network')) {
        userFriendlyError = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('timeout')) {
        userFriendlyError = 'Request timeout. Please try again.';
      } else if (e.toString().contains('permission')) {
        userFriendlyError = 'Permission denied. Please contact support.';
      } else if (e.toString().contains('INVALID_AMOUNT') || 
                 e.toString().contains('invalid amount')) {
        userFriendlyError = 'Invalid payment amount. Please check the amount and try again.';
      }
      
      return {
        'success': false,
        'error': userFriendlyError,
        'payment_id': paymentId,
      };
    }
  }

  /// Create a pending cash payment to be approved by admin
  static Future<Map<String, dynamic>> requestCashPayment({
    required String paymentId,
    required int amount,
    required String description,
    required String paymentType,
    required String itemId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final paymentRef = FirebaseFirestore.instance.collection('payments').doc(paymentId);
      // Create payment document (no pre-read to avoid permission issues for new docs)
      await paymentRef.set({
        'id': paymentId,
        'user_id': user.uid,
        'amount': amount,
        'description': description,
        'payment_type': paymentType,
        'payment_method': 'cash',
        'item_id': itemId,
        'status': paymentPendingCash,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      });


      // Create approval item
      try {
        await FirebaseFirestore.instance.collection('approvals').add({
          'type': 'cash_payment',
          'status': 'pending',
          'title': 'Cash Payment',
          'message': '₹$amount for $description',
          'payment_id': paymentId,
          'payment_type': paymentType,
          'item_id': itemId,
          'user_id': user.uid,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Approval creation failed, but continue
      }

      // Send notification to user
      try {
        await LiveNotificationService.sendCashPaymentRequestNotification(
          amount: amount.toString(),
          description: description,
          userId: user.uid,
        );
      } catch (e) {
        // Ignore notification errors
      }

      return {'success': true, 'status': paymentPendingCash, 'payment_id': paymentId};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }


  // Removed client-side simulation to avoid bypassing backend verification/enrollment

  static _PendingPaymentContext? _pendingPaymentContext;

  static Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final ctx = _pendingPaymentContext;
      if (ctx == null) {
        return;
      }

      // Additional validation - ensure this is a genuine success
      if (response.paymentId == null || response.paymentId!.isEmpty) {
        await _updatePaymentStatus(ctx.paymentId, paymentFailed);
        return;
      }

      // Confirm and fulfill on backend atomically (signature verify + writes + notifications)
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final confirm = functions.httpsCallable('confirmRazorpayPayment');
      final safeOrderId = (response.orderId?.isNotEmpty == true) ? response.orderId : ctx.orderId;
      final safePaymentId = response.paymentId;
      final safeSignature = response.signature;

      if (safeOrderId == null || safePaymentId == null || safeSignature == null) {
        await _updatePaymentStatus(ctx.paymentId, paymentFailed);
        return;
      }


      // Extract classId/workshopId, userId, amount from our pending context and Firestore payment doc
      final user = FirebaseAuth.instance.currentUser;
      final paymentSnap = await FirebaseFirestore.instance.collection('payments').doc(ctx.paymentId).get();
      final paymentData = paymentSnap.data() ?? {};
      final classId = (paymentData['item_id'] ?? '') as String; // for 'class_fee'
      final workshopId = (paymentData['item_id'] ?? '') as String; // for 'workshop'
      final paymentType = (paymentData['payment_type'] ?? 'class_fee') as String;
      final amount = (paymentData['amount'] ?? ctx.amount) as int;

      
      final resp = await confirm.call({
        'orderId': safeOrderId,
        'paymentId': safePaymentId,
        'signature': safeSignature,
        'classId': paymentType == 'class_fee' ? classId : null,
        'workshopId': paymentType == 'workshop' ? workshopId : null,
        'bookingId': paymentType == 'event_choreography' ? classId : null,
        'studioBookingId': paymentType == 'studio_booking' ? classId : null,
        'subscriptionId': paymentType == 'subscription' ? classId : null,
        'itemType': paymentType,
        'userId': user?.uid,
        'amount': amount,
        'razorpayPaymentId': safePaymentId, // Actual Razorpay payment ID
        'razorpayOrderId': safeOrderId, // Actual Razorpay order ID
        'planType': paymentData['metadata']?['planType'],
        'billingCycle': paymentData['metadata']?['billingCycle'],
      });
      
      // Verify backend confirmation was successful
      if (resp.data?['ok'] != true) {
        await _updatePaymentStatus(ctx.paymentId, paymentFailed);
        return;
      }
      await _updatePaymentStatus(ctx.paymentId, paymentSuccess);

      // Send payment success notification
      try {
        final itemName = paymentData['description'] ?? 
            (paymentType == 'class_fee' ? 'Class Fee' : 
             paymentType == 'workshop' ? 'Workshop' : 
             paymentType == 'subscription' ? 'Subscription' : 'Payment');
        await LiveNotificationService.sendPaymentSuccessNotification(
          amount: amount.toString(),
          itemName: itemName,
          userId: user?.uid,
        );
      } catch (e) {
        // Ignore notification errors
      }

      // Send enrollment notification for class/workshop enrollments
      if ((paymentType == 'class_fee' || paymentType == 'workshop') && user?.uid != null) {
        try {
          final itemId = paymentType == 'class_fee' ? classId : workshopId;
          if (itemId.isNotEmpty) {
            final itemName = paymentData['description'] ?? 
                (paymentType == 'class_fee' ? 'Class' : 'Workshop');
            await LiveNotificationService.sendEnrollmentNotification(
              itemName: itemName,
              itemType: paymentType == 'class_fee' ? 'class' : 'workshop',
              userId: user!.uid,
            );
          }
        } catch (e) {
          // Ignore notification errors
        }
      }

      // Trigger global refresh for all screens
      _refreshController.add({
        'type': 'payment_success',
        'paymentType': paymentType,
        'paymentId': ctx.paymentId,
        'itemId': classId.isNotEmpty ? classId : workshopId,
        'amount': amount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'userId': user?.uid,
      });

      // Also trigger home stats update
      await _triggerHomeStatsUpdate(user?.uid);

      
      
      // Trigger enrollment refresh for real-time updates
      _refreshController.add({
        'type': 'enrollment_updated',
        'paymentType': paymentType,
        'itemId': classId.isNotEmpty ? classId : workshopId,
        'userId': user?.uid,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Handle different payment types
      if (paymentType == 'subscription') {
        // For subscriptions, show success message and refresh UI
        final nav = PaymentService.navigatorKey.currentState;
        if (nav != null) {
          ScaffoldMessenger.of(nav.context).showSnackBar(
            SnackBar(
              content: Text('${paymentData['metadata']?['planType'] ?? 'Subscription'} activated successfully! All videos are now unlocked.'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        // For other payments, navigate to receipt screen
        try {
          final refreshed = await FirebaseFirestore.instance
              .collection('payments')
              .doc(ctx.paymentId)
              .get();
          final payment = {'id': ctx.paymentId, ...?refreshed.data()};
          final nav = PaymentService.navigatorKey.currentState;
          nav?.push(
            MaterialPageRoute(
              builder: (_) => ReceiptScreen(payment: payment),
            ),
          );
        } catch (e) {
          if (kDebugMode) {
            print('Error navigating to receipt screen: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in payment success handler: $e');
      }
    } finally {
      _pendingPaymentContext = null;
    }
  }

  static Future<void> _handlePaymentError(PaymentFailureResponse response) async {
    try {
      final ctx = _pendingPaymentContext;
      if (ctx == null) return;
      await _updatePaymentStatus(ctx.paymentId, paymentFailed);
      
      // Show error message for subscriptions
      final nav = PaymentService.navigatorKey.currentState;
      if (nav != null) {
        String errorMessage = 'Payment failed. Please try again.';
        
        // Check error code and message for specific error types
        if (response.code == 'PAYMENT_CANCELLED' || 
            response.message?.toLowerCase().contains('cancelled') == true) {
          errorMessage = 'Payment cancelled. You can try again anytime.';
        } else if (response.code == 'NETWORK_ERROR' || 
                   response.message?.toLowerCase().contains('network') == true) {
          errorMessage = 'Network error. Please check your connection and try again.';
        }
        
        ScaffoldMessenger.of(nav.context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: const Color(0xFFE53935),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
    } finally {
      _pendingPaymentContext = null;
    }
  }

  static Future<void> _handleExternalWallet(ExternalWalletResponse response) async {
    // No-op; handled by Razorpay UI. Keep context to await success/error callbacks.
  }

  /// Update payment status in Firestore
  static Future<void> _updatePaymentStatus(String paymentId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
        'transaction_id': status == paymentSuccess 
            ? 'TXN_${DateTime.now().millisecondsSinceEpoch}'
            : null,
      });
    } catch (e) {
    }
  }

  // Client-side enrollment writes removed; enrollment is handled by Cloud Functions after verification

  /// Get payment history for user
  static Future<List<Map<String, dynamic>>> getPaymentHistory(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Trigger home screen stats update after payment success
  static Future<void> _triggerHomeStatsUpdate(String? userId) async {
    if (userId == null) return;
    try {
      // Update a trigger document to notify home screen of stats change
      await FirebaseFirestore.instance
          .collection('user_stats_triggers')
          .doc(userId)
          .set({
        'lastPaymentUpdate': FieldValue.serverTimestamp(),
        'userId': userId,
      }, SetOptions(merge: true));
    } catch (e) {
    }
  }

  /// Get pending payments for user
  static Future<List<Map<String, dynamic>>> getPendingPayments(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('user_id', isEqualTo: userId)
          .where('status', isEqualTo: paymentPending)
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Cancel payment
  static Future<bool> cancelPayment(String paymentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .update({
        'status': paymentCancelled,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Generate unique payment ID
  static String generatePaymentId() {
    return 'PAY_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Format amount for display
  static String formatAmount(int amount) {
    return '₹${amount.toString()}';
  }

  /// Get payment status color
  static Color getPaymentStatusColor(String status) {
    switch (status) {
      case paymentSuccess:
        return Colors.green;
      case paymentFailed:
        return Colors.red;
      case paymentPending:
        return Colors.orange;
      case paymentCancelled:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  /// Get payment status text
  static String getPaymentStatusText(String status) {
    switch (status) {
      case paymentSuccess:
        return 'Success';
      case paymentFailed:
        return 'Failed';
      case paymentPending:
        return 'Pending';
      case paymentCancelled:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  /// Trigger enrollment refresh event (for admin approvals)
  static void triggerEnrollmentRefresh({
    required String paymentType,
    required String itemId,
    required String userId,
  }) {
    _refreshController.add({
      'type': 'enrollment_updated',
      'paymentType': paymentType,
      'itemId': itemId,
      'userId': userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Notify listeners about subscription purchases from Play/App Store
  static void notifySubscriptionPurchase({
    required String planId,
    required String billingCycle,
    required String productId,
    required String store,
  }) {
    _refreshController.add({
      'type': 'payment_success',
      'paymentType': 'subscription',
      'itemId': planId,
      'billingCycle': billingCycle,
      'productId': productId,
      'store': store,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Dispose the refresh controller
  static void dispose() {
    _refreshController.close();
  }
}

class _PendingPaymentContext {
  final String paymentId;
  final int amount;
  final String orderId;
  _PendingPaymentContext({required this.paymentId, required this.amount, required this.orderId});
}
