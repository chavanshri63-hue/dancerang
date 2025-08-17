import 'package:url_launcher/url_launcher.dart';

class PaymentsService {
  /// Generic UPI launcher (+ optional app scheme).
  static Future<bool> openUpi({
    required String upiId,
    required String name,
    required num amount,
    String note = '',
    String? preferredAppScheme, // e.g. 'gpay' | 'phonepe' | 'paytm' | 'bhim'
  }) async {
    final amt = amount.toStringAsFixed(2);

    final base = Uri.parse(
      'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(name)}'
      '&am=$amt&cu=INR&tn=${Uri.encodeComponent(note)}',
    );

    // Try preferred app first, then fallback.
    if (preferredAppScheme != null && preferredAppScheme.isNotEmpty) {
      final appUri = Uri.parse(
        '$preferredAppScheme://upi/pay?pa=$upiId&pn=${Uri.encodeComponent(name)}'
        '&am=$amt&cu=INR&tn=${Uri.encodeComponent(note)}',
      );
      final launched = await _tryLaunch(appUri);
      if (launched) return true;
    }
    return _tryLaunch(base);
  }

  /// Convenience used by WorkshopDetailScreen
  static Future<bool> payForWorkshop({
    required String upiId,
    required String name,
    required int amountInr,
    String note = '',
    String? preferredApp, // 'gpay' | 'phonepe' | 'paytm' | 'bhim'
  }) {
    return openUpi(
      upiId: upiId,
      name: name,
      amount: amountInr,
      note: note,
      preferredAppScheme: preferredApp,
    );
  }

  static Future<bool> _tryLaunch(Uri uri) async {
    try {
      if (!await canLaunchUrl(uri)) return false;
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}