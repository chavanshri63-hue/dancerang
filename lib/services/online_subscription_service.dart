import 'package:cloud_firestore/cloud_firestore.dart';

import 'iap_service.dart';

class OnlineSubscriptionService {
  OnlineSubscriptionService._();

  /// Single allowed Play product for online videos.
  static const String monthlyProductId = 'online_monthly_900';

  /// Loads the active monthly plan from Firestore (if present) and returns
  /// normalized purchase metadata for server verification + UI messaging.
  static Future<Map<String, dynamic>> loadMonthlyPlan() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('subscription_plans')
        .where('active', isEqualTo: true)
        .where('billingCycle', isEqualTo: 'monthly')
        .orderBy('priority')
        .limit(5)
        .get();

    // Prefer a plan that explicitly points to our single allowed product id.
    QueryDocumentSnapshot<Map<String, dynamic>>? picked;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final explicit = (data['storeProductId'] ??
              data['productId'] ??
              data['playProductId'] ??
              data['appStoreProductId'])
          ?.toString()
          .trim();
      if (explicit == monthlyProductId) {
        picked = doc;
        break;
      }
    }
    picked ??= snapshot.docs.isNotEmpty ? snapshot.docs.first : null;

    final data = picked?.data() ?? <String, dynamic>{};
    final planId = picked?.id ?? 'monthly';
    final planName = (data['name'] ?? 'Monthly Online Classes').toString();
    final billingCycle = (data['billingCycle'] ?? 'monthly').toString();
    final amount = (data['price'] as num?)?.toInt() ?? 900;

    return {
      'planId': planId,
      'planName': planName,
      'planType': 'monthly',
      'billingCycle': billingCycle,
      'amount': amount,
      // Always use the single monthly product id.
      'productId': monthlyProductId,
    };
  }

  /// Starts the Play Store purchase flow for the online subscription.
  static Future<Map<String, dynamic>> purchaseMonthly() async {
    final plan = await loadMonthlyPlan();
    final productId = (plan['productId'] ?? '').toString().trim();
    return IapService.instance.purchaseSubscription(
      productId: productId,
      metadata: plan,
    );
  }
}

