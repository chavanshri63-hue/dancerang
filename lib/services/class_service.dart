import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/class_model.dart';

/// ClassService handles all dance class-related operations
/// 
/// This service provides:
/// - Class fetching and filtering by category, level, date
/// - Class booking and enrollment management
/// - Attendance tracking and statistics
/// - Search functionality for classes
class ClassService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _classesCollection = 'classes';
  static const String _attendanceCollection = 'attendance';

  // Get all available classes
  static Future<List<DanceClass>> getAllClasses() async {
    try {
      // Now using orderBy since indexes are deployed
      final QuerySnapshot snapshot = await _firestore
          .collection(_classesCollection)
          .where('isAvailable', isEqualTo: true)
          .orderBy('dateTime')
          .limit(50) // Add limit to prevent performance issues
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => DanceClass.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
      } else {
        // No classes found in Firestore
        return [];
      }
    } catch (e) {
      // Provide more specific error handling
      if (e.toString().contains('permission-denied')) {
      } else if (e.toString().contains('unavailable')) {
      } else if (e.toString().contains('deadline-exceeded')) {
      }
      return [];
    }
  }

  // Get classes happening today (by role)
  static Future<List<DanceClass>> getTodaysClasses({required String role, required String? userId}) async {
    try {
      final DateTime now = DateTime.now();
      final DateTime start = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

      Query query = _firestore
          .collection(_classesCollection)
          .where('isAvailable', isEqualTo: true)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('dateTime');

      // Narrow by role when possible
      if (role.toLowerCase() == 'faculty' && userId != null) {
        query = query.where('instructorId', isEqualTo: userId);
      }

      // For students, fetch all today and filter by booking membership (best-effort)
      final QuerySnapshot snapshot = await query.get();
      List<DanceClass> allToday = snapshot.docs.map((doc) {
        final map = doc.data() as Map<String, dynamic>;
        if ((map['id'] as String?) == null || (map['id'] as String?)!.isEmpty) {
          map['id'] = doc.id;
        }
        return DanceClass.fromMap(map);
      }).toList();

      if (role.toLowerCase() == 'student' && userId != null) {
        try {
          // Check user's confirmed bookings for today
          final bookings = await _firestore
              .collection('users')
              .doc(userId)
              .collection('bookings')
              .where('status', isEqualTo: 'confirmed')
              .get();
          final Set<String> bookedIds = bookings.docs
              .map((d) => (d.data() as Map<String, dynamic>)['classId'] as String)
              .toSet();
          allToday = allToday.where((c) => bookedIds.contains(c.id)).toList();
        } catch (_) {}
      }

      return allToday;
    } catch (e) {
      return [];
    }
  }

  // Get the next upcoming class for a user (by role)
  static Future<DanceClass?> getNextClass({required String role, required String? userId}) async {
    try {
      final DateTime now = DateTime.now();
      Query query = _firestore
          .collection(_classesCollection)
          .where('isAvailable', isEqualTo: true)
          .where('dateTime', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('dateTime')
          .limit(10);

      if (role.toLowerCase() == 'faculty' && userId != null) {
        query = query.where('instructorId', isEqualTo: userId);
      }

      final QuerySnapshot snapshot = await query.get();
      List<DanceClass> upcoming = snapshot.docs.map((doc) {
        final map = doc.data() as Map<String, dynamic>;
        if ((map['id'] as String?) == null || (map['id'] as String?)!.isEmpty) {
          map['id'] = doc.id;
        }
        return DanceClass.fromMap(map);
      }).toList();

      if (role.toLowerCase() == 'student' && userId != null) {
        try {
          final bookings = await _firestore
              .collection('users')
              .doc(userId)
              .collection('bookings')
              .where('status', isEqualTo: 'confirmed')
              .get();
          final Set<String> bookedIds = bookings.docs
              .map((d) => (d.data() as Map<String, dynamic>)['classId'] as String)
              .toSet();
          upcoming = upcoming.where((c) => bookedIds.contains(c.id)).toList();
        } catch (_) {}
      }

      return upcoming.isNotEmpty ? upcoming.first : null;
    } catch (e) {
      return null;
    }
  }

  // Compute basic attendance percentage for a student (best-effort)
  static Future<double?> getAttendancePercent({required String userId}) async {
    try {
      final QuerySnapshot all = await _firestore
          .collection(_attendanceCollection)
          .where('userId', isEqualTo: userId)
          .get();
      if (all.docs.isEmpty) return null;
      final docs = all.docs.map((d) => d.data() as Map<String, dynamic>).toList();
      final total = docs.length;
      final present = docs.where((m) => (m['status'] ?? 'absent') == 'present').length;
      return total == 0 ? null : (present / total) * 100.0;
    } catch (e) {
      return null;
    }
  }

  // Get classes by category
  static Future<List<DanceClass>> getClassesByCategory(String category) async {
    try {
      // Now using orderBy since indexes are deployed
      final QuerySnapshot snapshot = await _firestore
          .collection(_classesCollection)
          .where('category', isEqualTo: category)
          .where('isAvailable', isEqualTo: true)
          .orderBy('dateTime')
          .limit(30) // Add limit to prevent performance issues
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => DanceClass.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
      } else {
        // No classes found in Firestore for category
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Get classes by level
  static Future<List<DanceClass>> getClassesByLevel(String level) async {
    try {
      // Now using orderBy since indexes are deployed
      final QuerySnapshot snapshot = await _firestore
          .collection(_classesCollection)
          .where('level', isEqualTo: level)
          .where('isAvailable', isEqualTo: true)
          .orderBy('dateTime')
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => DanceClass.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
      } else {
        // No classes found in Firestore for level
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Search classes
  static Future<List<DanceClass>> searchClasses(String query) async {
    try {
      // Try real Firestore query first
      final QuerySnapshot snapshot = await _firestore
          .collection(_classesCollection)
          .where('isAvailable', isEqualTo: true)
          .limit(20) // Add limit to prevent performance issues
          .get();

      if (snapshot.docs.isNotEmpty) {
        final allClasses = snapshot.docs
            .map((doc) => DanceClass.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        return allClasses.where((classItem) {
          return classItem.name.toLowerCase().contains(query.toLowerCase()) ||
                 classItem.instructor.toLowerCase().contains(query.toLowerCase()) ||
                 classItem.category.toLowerCase().contains(query.toLowerCase());
        }).toList();
      } else {
        // No classes found in Firestore for search
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Book a class
  static Future<bool> bookClass(String classId, String userId) async {
    try {
      final classRef = _firestore.collection(_classesCollection).doc(classId);
      
      await _firestore.runTransaction((transaction) async {
        final classDoc = await transaction.get(classRef);
        
        if (!classDoc.exists) {
          throw Exception('Class not found');
        }
        
        final classData = classDoc.data() as Map<String, dynamic>;
        final currentBookings = classData['currentBookings'] ?? 0;
        final maxStudents = classData['maxStudents'] ?? 20;
        
        if (currentBookings >= maxStudents) {
          throw Exception('Class is fully booked');
        }
        
        // Update class bookings
        transaction.update(classRef, {
          'currentBookings': currentBookings + 1,
        });
        
        // Add booking to user's bookings
        await _firestore.collection('users').doc(userId).collection('bookings').add({
          'classId': classId,
          'bookingDate': FieldValue.serverTimestamp(),
          'status': 'confirmed',
        });
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get user's booked classes
  static Future<List<DanceClass>> getUserBookings(String userId) async {
    try {
      final QuerySnapshot bookingsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookings')
          .where('status', isEqualTo: 'confirmed')
          .get();

      final List<String> classIds = bookingsSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .map((data) => data['classId'] as String)
          .toList();

      if (classIds.isEmpty) return [];

      final QuerySnapshot classesSnapshot = await _firestore
          .collection(_classesCollection)
          .where(FieldPath.documentId, whereIn: classIds)
          .get();

      return classesSnapshot.docs.map((doc) {
        final map = doc.data() as Map<String, dynamic>;
        if ((map['id'] as String?) == null || (map['id'] as String?)!.isEmpty) {
          map['id'] = doc.id;
        }
        return DanceClass.fromMap(map);
      }).toList();
    } catch (e) {
      return [];
    }
  }

}
