import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'payment_service.dart';

class IapService {
  IapService._();

  static final IapService instance = IapService._();
  static InAppPurchase get _iap => InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  Completer<Map<String, dynamic>>? _purchaseCompleter;
  String? _pendingProductId;
  Map<String, dynamic>? _pendingMetadata;
  String? _lastDeliverError;

  static String resolveProductId({
    required String billingCycle,
    String? explicitId,
    String? planId,
  }) {
    final explicit = explicitId?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    final safePlanId = (planId ?? '').trim();
    if (safePlanId.isEmpty) return '';
    final safeCycle = billingCycle.trim();
    if (safeCycle.isEmpty) return safePlanId;
    return '${safePlanId}_$safeCycle';
  }

  Future<Map<String, dynamic>> purchaseSubscription({
    required String productId,
    Map<String, dynamic>? metadata,
  }) async {
    _ensurePurchaseListener();

    final safeProductId = productId.trim();
    if (safeProductId.isEmpty) {
      return {
        'success': false,
        'message': 'Subscription product is not configured yet.',
      };
    }

    final isAvailable = await _iap.isAvailable();
    if (!isAvailable) {
      return {
        'success': false,
        'message': 'In-app purchases are not available on this device.',
      };
    }

    final response = await _iap.queryProductDetails({safeProductId});
    if (response.error != null) {
      return {
        'success': false,
        'message': response.error!.message,
      };
    }

    if (response.productDetails.isEmpty) {
      final notFound = response.notFoundIDs.map((e) => e.toString()).toList();
      return {
        'success': false,
        'message': notFound.isNotEmpty
            ? 'Subscription product not found in store. (productId: $safeProductId, notFound: ${notFound.join(', ')})'
            : 'Subscription product not found in store. (productId: $safeProductId)',
      };
    }

    // For subscriptions on Android (Play Billing v5+), include an offerToken when available.
    ProductDetails productDetails = response.productDetails.first;
    if (defaultTargetPlatform == TargetPlatform.android) {
      for (final pd in response.productDetails) {
        if (pd is GooglePlayProductDetails) {
          // Prefer a subscription offer that contains a token.
          final tok = (pd.offerToken ?? '').trim();
          productDetails = pd;
          if (tok.isNotEmpty) break;
        }
      }
    }
    final PurchaseParam purchaseParam = (defaultTargetPlatform == TargetPlatform.android &&
            productDetails is GooglePlayProductDetails)
        ? GooglePlayPurchaseParam(
            productDetails: productDetails,
            applicationUserName: FirebaseAuth.instance.currentUser?.uid,
            offerToken: productDetails.offerToken,
          )
        : PurchaseParam(productDetails: productDetails);

    _pendingProductId = safeProductId;
    _pendingMetadata = metadata ?? {};
    _purchaseCompleter = Completer<Map<String, dynamic>>();

    final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    if (!started) {
      _clearPending();
      return {
        'success': false,
        'message': 'Unable to start the purchase flow.',
      };
    }

    try {
      return await _purchaseCompleter!.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          _clearPending();
          return {
            'success': false,
            'message': 'Purchase timed out. Please try again.',
          };
        },
      );
    } catch (e) {
      _clearPending();
      return {
        'success': false,
        'message': 'Purchase failed. Please try again.',
      };
    }
  }

  void _ensurePurchaseListener() {
    if (_purchaseSub != null) return;
    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        _completeWithError('Purchase failed. Please try again.');
      },
    );
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (_pendingProductId != null && purchase.productID != _pendingProductId) {
        continue;
      }

      if (purchase.status == PurchaseStatus.pending) {
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        _completeWithError(purchase.error?.message ?? 'Purchase failed.');
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final delivered = await _deliverPurchase(purchase);
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        if (delivered) {
          _completeWithSuccess();
        } else {
          _completeWithError(_lastDeliverError ?? 'Purchase completed but activation failed.');
        }
      }
    }
  }

  Future<bool> _deliverPurchase(PurchaseDetails purchase) async {
    _lastDeliverError = null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _lastDeliverError = 'Please login again and try.';
      return false;
    }

    final metadata = _pendingMetadata ?? {};
    final planId = (metadata['planId'] ?? 'monthly').toString();
    final planName = (metadata['planName'] ?? 'Monthly Plan').toString();
    final planType = (metadata['planType'] ?? 'monthly').toString();
    final billingCycle = (metadata['billingCycle'] ?? 'monthly').toString();
    final amount = (metadata['amount'] as num?)?.toInt() ?? 900;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return false; // Play Store verification only for now
    }

    final store = 'play_store';
    final purchaseToken = _resolvePurchaseToken(purchase);
    if (purchaseToken.isEmpty) {
      _lastDeliverError = 'Activation failed: purchase token missing.';
      return false;
    }

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final verify = functions.httpsCallable('verifyPlaySubscription');
      final resp = await verify.call({
        'productId': purchase.productID,
        'purchaseToken': purchaseToken,
        'planId': planId,
        'planName': planName,
        'planType': planType,
        'billingCycle': billingCycle,
        'amount': amount,
        'store': store,
      });

      if (resp.data?['ok'] != true) {
        _lastDeliverError = (resp.data?['message'] ?? 'Activation failed.').toString();
        return false;
      }

      PaymentService.notifySubscriptionPurchase(
        planId: planId,
        billingCycle: billingCycle,
        productId: purchase.productID,
        store: store,
      );

      return true;
    } catch (e) {
      _lastDeliverError = e.toString();
      return false;
    }
  }

  String _resolvePurchaseToken(PurchaseDetails purchase) {
    final serverData = purchase.verificationData.serverVerificationData.trim();
    if (serverData.isNotEmpty) {
      // Sometimes the token is returned directly, sometimes wrapped in JSON.
      if (!serverData.startsWith('{')) return serverData;
      try {
        final decoded = jsonDecode(serverData) as Map<String, dynamic>;
        final token = (decoded['purchaseToken'] ?? '').toString().trim();
        if (token.isNotEmpty) return token;
      } catch (_) {}
    }

    final localData = purchase.verificationData.localVerificationData.trim();
    if (localData.isEmpty) {
      return '';
    }

    try {
      final decoded = jsonDecode(localData) as Map<String, dynamic>;
      final token = (decoded['purchaseToken'] ?? '').toString().trim();
      if (token.isNotEmpty) return token;
    } catch (_) {}

    return '';
  }

  /// Re-check purchases from Play and re-run server verification.
  /// Useful when the Play purchase succeeded but activation failed.
  Future<void> syncPurchases() async {
    try {
      _ensurePurchaseListener();
      await _iap.restorePurchases();
    } catch (_) {
      // Ignore sync failures; UI can still attempt purchase manually.
    }
  }

  void _completeWithSuccess() {
    if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
      _purchaseCompleter!.complete({
        'success': true,
        'message': 'Subscription activated successfully.',
      });
    }
    _clearPending();
  }

  void _completeWithError(String message) {
    if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
      _purchaseCompleter!.complete({
        'success': false,
        'message': message,
      });
    }
    _clearPending();
  }

  void _clearPending() {
    _pendingProductId = null;
    _pendingMetadata = null;
    _purchaseCompleter = null;
    _lastDeliverError = null;
  }

  void dispose() {
    _purchaseSub?.cancel();
    _purchaseSub = null;
    _clearPending();
  }
}
