import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();
  static const String _classesCollection = 'classes';
  static const String _attendanceCollection = 'attendance';

  // Background image management
  static Future<Map<String, String?>> getBackgroundImages() async {
    try {
      final doc = await _firestore
          .collection('appSettings')
          .doc('backgroundImages')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        // Filter out empty strings and convert them to null
        final filtered = <String, String?>{};
        data.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            filtered[key] = value.toString();
          } else {
            filtered[key] = null;
          }
        });
        return filtered;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // ------- Admin/Faculty metrics (lightweight, best-effort) -------
  static Future<int> getTodaysClassesCount({String? instructorId}) async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      Query q = _firestore
          .collection(_classesCollection)
          .where('isAvailable', isEqualTo: true)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(end));
      if (instructorId != null) {
        q = q.where('instructorId', isEqualTo: instructorId);
      }
      final snap = await q.get();
      return snap.size;
    } catch (e) {
      return 0;
    }
  }

  static Future<double> getOccupancyPercentToday() async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final snap = await _firestore
          .collection(_classesCollection)
          .where('isAvailable', isEqualTo: true)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();
      if (snap.docs.isEmpty) return 0.0;
      int booked = 0;
      int capacity = 0;
      for (final d in snap.docs) {
        final m = d.data() as Map<String, dynamic>;
        booked += (m['currentBookings'] ?? 0) as int;
        capacity += (m['maxStudents'] ?? 0) as int;
      }
      if (capacity <= 0) return 0.0;
      return (booked / capacity) * 100.0;
    } catch (e) {
      return 0.0;
    }
  }

  static Future<int> getPendingAttendanceCountForFaculty(String instructorId) async {
    try {
      // Best-effort: count today classes for instructor that don't have full attendance marked
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final classesSnap = await _firestore
          .collection(_classesCollection)
          .where('isAvailable', isEqualTo: true)
          .where('instructorId', isEqualTo: instructorId)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      int pending = 0;
      for (final doc in classesSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final classId = data['id'] ?? doc.id;
        try {
          final attSnap = await _firestore
              .collection(_attendanceCollection)
              .where('classId', isEqualTo: classId)
              .limit(1)
              .get();
          // If no attendance entries, consider pending
          if (attSnap.size == 0) pending++;
        } catch (_) {
          pending++;
        }
      }
      return pending;
    } catch (e) {
      return 0;
    }
  }

  // Get faculty no-show percentage
  static Future<double> getNoShowPercentForFaculty(String instructorId) async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      // Get today's classes for this instructor
      final classesSnap = await _firestore
          .collection(_classesCollection)
          .where('isAvailable', isEqualTo: true)
          .where('instructorId', isEqualTo: instructorId)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      if (classesSnap.docs.isEmpty) return 0.0;

      int totalAttendance = 0;
      int noShows = 0;

      for (final classDoc in classesSnap.docs) {
        final classData = classDoc.data() as Map<String, dynamic>;
        final classId = classData['id'] ?? classDoc.id;
        
        // Get attendance records for this class
        final attSnap = await _firestore
            .collection(_attendanceCollection)
            .where('classId', isEqualTo: classId)
            .get();

        for (final attDoc in attSnap.docs) {
          final attData = attDoc.data() as Map<String, dynamic>;
          totalAttendance++;
          if (attData['status'] == 'absent' || attData['isNoShow'] == true) {
            noShows++;
          }
        }
      }

      if (totalAttendance == 0) return 0.0;
      return (noShows / totalAttendance) * 100.0;
    } catch (e) {
      return 0.0;
    }
  }

  // Get faculty late percentage
  static Future<double> getLatePercentForFaculty(String instructorId) async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      // Get today's classes for this instructor
      final classesSnap = await _firestore
          .collection(_classesCollection)
          .where('isAvailable', isEqualTo: true)
          .where('instructorId', isEqualTo: instructorId)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      if (classesSnap.docs.isEmpty) return 0.0;

      int totalAttendance = 0;
      int lateCount = 0;

      for (final classDoc in classesSnap.docs) {
        final classData = classDoc.data() as Map<String, dynamic>;
        final classId = classData['id'] ?? classDoc.id;
        
        // Get attendance records for this class
        final attSnap = await _firestore
            .collection(_attendanceCollection)
            .where('classId', isEqualTo: classId)
            .get();

        for (final attDoc in attSnap.docs) {
          final attData = attDoc.data() as Map<String, dynamic>;
          if (attData['status'] == 'present') {
            totalAttendance++;
            if (attData['isLate'] == true) {
              lateCount++;
            }
          }
        }
      }

      if (totalAttendance == 0) return 0.0;
      return (lateCount / totalAttendance) * 100.0;
    } catch (e) {
      return 0.0;
    }
  }

  // Get revenue for current month
  static Future<double> getRevenueMTD() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      
      final paymentsSnap = await _firestore
          .collection('payments')
          .where('status', isEqualTo: 'success')
          .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('created_at', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      double totalRevenue = 0.0;
      for (final doc in paymentsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalRevenue += (data['amount'] ?? 0).toDouble();
      }

      return totalRevenue;
    } catch (e) {
      return 0.0;
    }
  }

  static Future<bool> updateBackgroundImage({
    required String screenName,
    required String imageUrl,
  }) async {
    try {
      await _firestore
          .collection('appSettings')
          .doc('backgroundImages')
          .set({
        screenName: imageUrl,
      }, SetOptions(merge: true));
      
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeBackgroundImage({
    required String screenName,
  }) async {
    try {
      await _firestore
          .collection('appSettings')
          .doc('backgroundImages')
          .update({
        screenName: FieldValue.delete(),
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> uploadBackgroundImage({
    required XFile imageFile,
    required String screenName,
  }) async {
    try {
      final ref = _storage.ref().child('backgrounds/$screenName/${DateTime.now().millisecondsSinceEpoch}');
      await ref.putFile(File(imageFile.path));
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  static Future<XFile?> pickImage() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
    } catch (e) {
      return null;
    }
  }

  // Storage-only banners: read/write banners.json
  static Future<List<Map<String, dynamic>>> readBannersJson() async {
    try {
      final ref = _storage.ref().child('app_content/banners/banners.json');
      final data = await ref.getData();
      if (data == null) return [];
      final jsonStr = String.fromCharCodes(data);
      final List<dynamic> parsed = json.decode(jsonStr) as List<dynamic>;
      return parsed.map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v))).toList();
    } on FirebaseException catch (e) {
      // Silently handle object-not-found (expected when file doesn't exist yet)
      if (e.code == 'object-not-found') {
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> writeBannersJson(List<Map<String, dynamic>> banners) async {
    try {
      final ref = _storage.ref().child('app_content/banners/banners.json');
      final jsonStr = json.encode(banners);
      await ref.putData(Uint8List.fromList(jsonStr.codeUnits), SettableMetadata(contentType: 'application/json'));
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> uploadBannerImage(XFile imageFile) async {
    try {
      final ref = _storage.ref().child('app_content/banners/images/${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}');
      await ref.putFile(File(imageFile.path));
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  // Studio banners: read/write studio_banners.json
  static Future<List<Map<String, dynamic>>> readStudioBannersJson() async {
    try {
      final ref = _storage.ref().child('app_content/banners/studio_banners.json');
      final data = await ref.getData();
      if (data == null) return [];
      final jsonStr = String.fromCharCodes(data);
      final List<dynamic> parsed = json.decode(jsonStr) as List<dynamic>;
      return parsed.map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v))).toList();
    } on FirebaseException catch (e) {
      // Silently handle object-not-found (expected when file doesn't exist yet)
      if (e.code == 'object-not-found') {
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> writeStudioBannersJson(List<Map<String, dynamic>> banners) async {
    try {
      final ref = _storage.ref().child('app_content/banners/studio_banners.json');
      final jsonStr = json.encode(banners);
      await ref.putData(Uint8List.fromList(jsonStr.codeUnits), SettableMetadata(contentType: 'application/json'));
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get all available screens for background management
  static List<String> getAvailableScreens() {
    return [
      'loginScreen',
      'otpScreen',
      'homeScreen',
      'classesScreen',
      'studioScreen',
      'onlineScreen',
      'profileScreen',
    ];
  }

  // Get screen display names
  static Map<String, String> getScreenDisplayNames() {
    return {
      'loginScreen': 'Login Screen',
      'otpScreen': 'OTP Verification Screen',
      'homeScreen': 'Home Screen',
      'classesScreen': 'Classes Screen',
      'studioScreen': 'Studio Screen',
      'onlineScreen': 'Online Screen',
      'profileScreen': 'Profile Screen',
    };
  }
}
