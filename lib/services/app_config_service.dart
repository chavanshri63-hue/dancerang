import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// App configuration service with Firestore backend.
class AppConfigService extends ChangeNotifier {
  static final AppConfigService _instance = AppConfigService._internal();
  factory AppConfigService() => _instance;
  AppConfigService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Contact information
  String _studioPhone = '+91 98765 43210';
  String _studioWhatsApp = '919999999999';
  String _studioEmail = 'info@dancerang.com';
  String _studioLocation = 'Mumbai, India';

  // Getters
  String get studioPhone => _studioPhone;
  String get studioWhatsAppNumber => _studioWhatsApp;
  String get studioEmail => _studioEmail;
  String get studioLocation => _studioLocation;

  // Initialize and load data from Firestore
  Future<void> initialize() async {
    try {
      final doc = await _firestore.collection('app_config').doc('contact_info').get();
      if (doc.exists) {
        final data = doc.data()!;
        _studioPhone = data['phone'] ?? _studioPhone;
        _studioWhatsApp = data['whatsapp'] ?? _studioWhatsApp;
        _studioEmail = data['email'] ?? _studioEmail;
        _studioLocation = data['location'] ?? _studioLocation;
        notifyListeners();
      }
    } catch (e) {
    }
  }

  // Update contact information in Firestore
  Future<void> updateContactInfo({
    String? phone,
    String? whatsapp,
    String? email,
    String? location,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      if (phone != null) {
        _studioPhone = phone.trim();
        updateData['phone'] = _studioPhone;
      }
      if (whatsapp != null) {
        _studioWhatsApp = whatsapp.trim();
        updateData['whatsapp'] = _studioWhatsApp;
      }
      if (email != null) {
        _studioEmail = email.trim();
        updateData['email'] = _studioEmail;
      }
      if (location != null) {
        _studioLocation = location.trim();
        updateData['location'] = _studioLocation;
      }

      if (updateData.isNotEmpty) {
        await _firestore.collection('app_config').doc('contact_info').set(
          updateData,
          SetOptions(merge: true),
        );
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  // Legacy method for backward compatibility
  void updateStudioWhatsAppNumber(String newNumber) {
    updateContactInfo(whatsapp: newNumber);
  }
}


