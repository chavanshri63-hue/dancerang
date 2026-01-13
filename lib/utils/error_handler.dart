import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// ErrorHandler provides centralized error handling and user-friendly error messages
/// 
/// This utility class provides:
/// - Firebase-specific error message translation
/// - User-friendly error messages for UI display
/// - Error logging and crash reporting integration
/// - Network and authentication error handling
class ErrorHandler {
  static void handleError(dynamic error, StackTrace stackTrace, {String? context}) {
    // Log error for debugging
    
    // In production, you might want to send this to a crash reporting service
    // like Firebase Crashlytics or Sentry
    if (kReleaseMode) {
      // Send to crash reporting service
      _sendToCrashReporting(error, stackTrace, context);
    }
  }
  
  static String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return _getFirebaseAuthErrorMessage(error);
    } else if (error is FirebaseException) {
      return _getFirebaseErrorMessage(error);
    } else if (error is Exception) {
      return error.toString();
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get user-friendly error message for UI display
  static String getUserFriendlyMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return _getUserFriendlyAuthMessage(error);
    } else if (error is FirebaseException) {
      return _getUserFriendlyFirebaseMessage(error);
    } else if (error.toString().contains('network')) {
      return 'Please check your internet connection and try again.';
    } else if (error.toString().contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (error.toString().contains('permission')) {
      return 'You don\'t have permission to perform this action.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  static String _getUserFriendlyAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'No account found with this phone number.';
      case 'wrong-password':
        return 'Incorrect verification code. Please try again.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please check and try again.';
      case 'invalid-verification-id':
        return 'Verification session expired. Please request a new code.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  static String _getUserFriendlyFirebaseMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You don\'t have permission to access this data.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again later.';
      case 'deadline-exceeded':
        return 'Request timed out. Please try again.';
      case 'resource-exhausted':
        return 'Service is busy. Please try again later.';
      case 'unauthenticated':
        return 'Please log in to continue.';
      case 'not-found':
        return 'Requested data not found.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
  
  static String _getFirebaseAuthErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format. Please check and try again.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'app-not-authorized':
        return 'App not authorized for phone verification.';
      case 'missing-phone-number':
        return 'Phone number is required.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please check and try again.';
      case 'invalid-verification-id':
        return 'Verification session expired. Please request a new OTP.';
      case 'session-expired':
        return 'Verification session expired. Please request a new OTP.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this phone number.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'requires-recent-login':
        return 'Please log in again to perform this action.';
      default:
        return 'Authentication failed: ${error.message ?? 'Unknown error'}';
    }
  }
  
  static String _getFirebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Permission denied. You don\'t have access to this resource.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again later.';
      case 'deadline-exceeded':
        return 'Request timeout. Please try again.';
      case 'resource-exhausted':
        return 'Resource exhausted. Please try again later.';
      case 'unauthenticated':
        return 'Please log in to continue.';
      case 'not-found':
        return 'Resource not found.';
      case 'already-exists':
        return 'Resource already exists.';
      case 'failed-precondition':
        return 'Operation failed due to a precondition.';
      case 'aborted':
        return 'Operation was aborted. Please try again.';
      case 'out-of-range':
        return 'Value is out of range.';
      case 'unimplemented':
        return 'This feature is not implemented yet.';
      case 'internal':
        return 'Internal error. Please try again later.';
      case 'data-loss':
        return 'Data loss occurred. Please try again.';
      case 'cancelled':
        return 'Operation was cancelled.';
      default:
        return 'Firebase error: ${error.message ?? 'Unknown error'}';
    }
  }
  
  static void _sendToCrashReporting(dynamic error, StackTrace stackTrace, String? context) {
    // Crash reporting integration with Firebase Crashlytics
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: context ?? 'Unhandled error',
        fatal: false,
      );
    } catch (e) {
      // If Crashlytics fails, at least log in debug mode
      if (kDebugMode) {
        print('Error reporting to Crashlytics: $e');
      }
    }
  }
  
  static bool isNetworkError(dynamic error) {
    if (error is FirebaseException) {
      return error.code == 'network-request-failed' || 
             error.code == 'unavailable' ||
             error.code == 'deadline-exceeded';
    }
    return error.toString().toLowerCase().contains('network') ||
           error.toString().toLowerCase().contains('connection') ||
           error.toString().toLowerCase().contains('timeout');
  }
  
  static bool isAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      return true;
    }
    return error.toString().toLowerCase().contains('auth') ||
           error.toString().toLowerCase().contains('permission') ||
           error.toString().toLowerCase().contains('unauthorized');
  }
  
  static bool isValidationError(dynamic error) {
    if (error is FirebaseAuthException) {
      return error.code == 'invalid-phone-number' ||
             error.code == 'invalid-verification-code' ||
             error.code == 'weak-password' ||
             error.code == 'email-already-in-use';
    }
    return error.toString().toLowerCase().contains('invalid') ||
           error.toString().toLowerCase().contains('validation');
  }
}
