import 'dart:async';
import 'package:flutter/foundation.dart';
import 'subscription_renewal_service.dart';

/// Background service to run automatic subscription renewals
/// This runs periodically to check for subscriptions that need renewal
class BackgroundRenewalService {
  static Timer? _renewalTimer;
  static bool _isRunning = false;

  /// Start the background renewal service
  /// Runs every hour to check for renewals
  static void start() {
    if (_isRunning) {
      return;
    }

    _isRunning = true;

    // Run immediately on start
    _runRenewalCheck();

    // Then run every hour
    _renewalTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _runRenewalCheck(),
    );

  }

  /// Stop the background renewal service
  static void stop() {
    if (!_isRunning) {
      return;
    }

    _renewalTimer?.cancel();
    _renewalTimer = null;
    _isRunning = false;

  }

  /// Run the renewal check
  static Future<void> _runRenewalCheck() async {
    try {
      await SubscriptionRenewalService.processAutomaticRenewals();
    } catch (e) {
      // Don't rethrow to prevent service from stopping
    }
  }

  /// Check if service is running
  static bool get isRunning => _isRunning;

  /// Force run renewal check (for testing)
  static Future<void> forceRunRenewalCheck() async {
    await _runRenewalCheck();
  }

  /// Get service status
  static Map<String, dynamic> getStatus() {
    return {
      'isRunning': _isRunning,
      'nextCheck': _renewalTimer?.isActive == true ? 'In 1 hour' : 'Not scheduled',
    };
  }
}
