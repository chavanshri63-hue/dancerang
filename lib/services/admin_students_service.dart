import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// AdminStudentsService provides admin-only functionality for managing student lists
/// in classes and workshops
class AdminStudentsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get enrolled students for a specific class (Admin/Faculty)
  static Stream<List<Map<String, dynamic>>> getClassEnrolledStudents(String classId) {
    // First try the new class_enrollments collection
    return _firestore
        .collection('class_enrollments')
        .where('classId', isEqualTo: classId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .asyncMap((enrollmentSnapshot) async {
      List<Map<String, dynamic>> students = [];
      
      // If we have data from class_enrollments, use it
      if (enrollmentSnapshot.docs.isNotEmpty) {
        for (var enrollmentDoc in enrollmentSnapshot.docs) {
          final enrollmentData = enrollmentDoc.data();
          final userId = enrollmentData['user_id'] as String?;
          
          if (userId != null) {
            try {
              // Get user details
              final userDoc = await _firestore.collection('users').doc(userId).get();
              if (userDoc.exists) {
                final userData = userDoc.data()!;
                students.add({
                  'userId': userId,
                  'name': userData['name'] ?? userData['displayName'] ?? 'Unknown',
                  'email': userData['email'] ?? '',
                  'phone': userData['phone'] ?? '',
                  'enrollmentDate': enrollmentData['createdAt'],
                  'completedSessions': enrollmentData['completedSessions'] ?? 0,
                  'totalSessions': enrollmentData['totalSessions'] ?? 1,
                  'remainingSessions': enrollmentData['remainingSessions'] ?? 0,
                  'packageName': enrollmentData['packageName'] ?? 'Unknown Package',
                  'paymentStatus': enrollmentData['paymentStatus'] ?? 'pending',
                  'lastAttendanceDate': enrollmentData['lastAttendanceDate'],
                  'enrollmentId': enrollmentDoc.id,
                });
              }
            } catch (e) {
            }
          }
        }
      } else {
        // Fallback: Check users/{userId}/enrollments (canonical) then enrolments (legacy)
        
        // Get all users and check their enrolments subcollection
        final usersSnapshot = await _firestore.collection('users').get();
        
        for (var userDoc in usersSnapshot.docs) {
          final userId = userDoc.id;
          try {
            // Check if this user has enrollment for this class
            var enrollmentDoc = await _firestore
                .collection('users')
                .doc(userId)
                .collection('enrollments')
                .doc(classId)
                .get();
            if (!enrollmentDoc.exists) {
              enrollmentDoc = await _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('enrollments')
                  .doc(classId)
                  .get();
            }
            
            if (enrollmentDoc.exists) {
              final enrollmentData = enrollmentDoc.data()!;
              final userData = userDoc.data();
              
              // Check if enrollment is active
              if (enrollmentData['status'] == 'enrolled' && 
                  enrollmentData['itemType'] == 'class' &&
                  enrollmentData['itemId'] == classId) {
                
                students.add({
                  'userId': userId,
                  'name': userData['name'] ?? userData['displayName'] ?? 'Unknown',
                  'email': userData['email'] ?? '',
                  'phone': userData['phone'] ?? '',
                  'enrollmentDate': enrollmentData['enrolledAt'],
                  'completedSessions': enrollmentData['completedSessions'] ?? 0,
                  'totalSessions': enrollmentData['totalSessions'] ?? 1,
                  'remainingSessions': (enrollmentData['totalSessions'] ?? 1) - (enrollmentData['completedSessions'] ?? 0),
                  'packageName': enrollmentData['packageName'] ?? 'Unknown Package',
                  'paymentStatus': 'paid', // Assume paid if enrolled
                  'lastAttendanceDate': enrollmentData['lastSessionAt'],
                  'enrollmentId': enrollmentDoc.id,
                });
              }
            }
          } catch (e) {
          }
        }
      }
      
      return students;
    });
  }

  /// Get enrolled students for a specific workshop (Admin/Faculty)
  static Stream<List<Map<String, dynamic>>> getWorkshopEnrolledStudents(String workshopId) {
    // First try the main enrolments collection
    return _firestore
        .collection('enrollments')
        .where('status', isEqualTo: 'enrolled')
        .where('itemType', isEqualTo: 'workshop')
        .where('itemId', isEqualTo: workshopId)
        .snapshots()
        .asyncMap((enrollmentSnapshot) async {
      List<Map<String, dynamic>> students = [];
      
      // If we have data from main enrolments collection, use it
      if (enrollmentSnapshot.docs.isNotEmpty) {
        for (var enrollmentDoc in enrollmentSnapshot.docs) {
          final enrollmentData = enrollmentDoc.data();
          final userId = enrollmentData['user_id'] as String?;
          
          if (userId != null) {
            try {
              // Get user details
              final userDoc = await _firestore.collection('users').doc(userId).get();
              if (userDoc.exists) {
                final userData = userDoc.data()!;
                students.add({
                  'userId': userId,
                  'name': userData['name'] ?? userData['displayName'] ?? 'Unknown',
                  'email': userData['email'] ?? '',
                  'phone': userData['phone'] ?? '',
                  'enrollmentDate': enrollmentData['enrolledAt'],
                  'completedSessions': enrollmentData['completedSessions'] ?? 0,
                  'totalSessions': enrollmentData['totalSessions'] ?? 1,
                  'lastSessionAt': enrollmentData['lastSessionAt'],
                  'enrollmentId': enrollmentDoc.id,
                });
              }
            } catch (e) {
            }
          }
        }
      } else {
        // Fallback: Check users/{userId}/enrollments (canonical) then enrolments (legacy)
        
        // Get all users and check their enrolments subcollection
        final usersSnapshot = await _firestore.collection('users').get();
        
        for (var userDoc in usersSnapshot.docs) {
          final userId = userDoc.id;
          try {
            // Check if this user has enrollment for this workshop
            var enrollmentDoc = await _firestore
                .collection('users')
                .doc(userId)
                .collection('enrollments')
                .doc(workshopId)
                .get();
            if (!enrollmentDoc.exists) {
              enrollmentDoc = await _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('enrollments')
                  .doc(workshopId)
                  .get();
            }
            
            if (enrollmentDoc.exists) {
              final enrollmentData = enrollmentDoc.data()!;
              final userData = userDoc.data();
              
              // Check if enrollment is active
              if (enrollmentData['status'] == 'enrolled' && 
                  enrollmentData['itemType'] == 'workshop' &&
                  enrollmentData['itemId'] == workshopId) {
                
                students.add({
                  'userId': userId,
                  'name': userData['name'] ?? userData['displayName'] ?? 'Unknown',
                  'email': userData['email'] ?? '',
                  'phone': userData['phone'] ?? '',
                  'enrollmentDate': enrollmentData['enrolledAt'],
                  'completedSessions': enrollmentData['completedSessions'] ?? 0,
                  'totalSessions': enrollmentData['totalSessions'] ?? 1,
                  'lastSessionAt': enrollmentData['lastSessionAt'],
                  'enrollmentId': enrollmentDoc.id,
                });
              }
            }
          } catch (e) {
          }
        }
      }
      
      return students;
    });
  }

  /// Get class attendance for a specific class (Admin only)
  static Stream<List<Map<String, dynamic>>> getClassAttendance(String classId) {
    return _firestore
        .collection('attendance')
        .where('classId', isEqualTo: classId)
        .orderBy('markedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList());
  }

  /// Get workshop attendance for a specific workshop (Admin only)
  static Stream<List<Map<String, dynamic>>> getWorkshopAttendance(String workshopId) {
    return _firestore
        .collection('attendance')
        .where('workshopId', isEqualTo: workshopId)
        .orderBy('markedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList());
  }

  /// Get live attendance stats for a class (Admin only)
  static Stream<Map<String, dynamic>> getClassLiveStats(String classId) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return {};
      
      final data = doc.data()!;
      return {
        'classId': classId,
        'className': data['name'] ?? 'Unknown Class',
        'totalEnrolled': data['currentBookings'] ?? data['enrolledCount'] ?? 0,
        'attendanceCount': data['attendanceCount'] ?? 0,
        'liveAttendanceCount': data['liveAttendanceCount'] ?? 0,
        'maxStudents': data['maxStudents'] ?? 20,
        'attendanceRate': data['currentBookings'] != null && data['currentBookings'] > 0 
            ? ((data['attendanceCount'] ?? 0) / data['currentBookings'] * 100).round()
            : 0,
        'lastAttendanceUpdate': data['lastAttendanceUpdate'],
      };
    });
  }

  /// Get live attendance stats for a workshop (Admin only)
  static Stream<Map<String, dynamic>> getWorkshopLiveStats(String workshopId) {
    return _firestore
        .collection('workshops')
        .doc(workshopId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return {};
      
      final data = doc.data()!;
      return {
        'workshopId': workshopId,
        'workshopName': data['name'] ?? 'Unknown Workshop',
        'totalEnrolled': data['currentBookings'] ?? data['enrolledCount'] ?? 0,
        'attendanceCount': data['attendanceCount'] ?? 0,
        'liveAttendanceCount': data['liveAttendanceCount'] ?? 0,
        'maxStudents': data['maxStudents'] ?? 20,
        'attendanceRate': data['currentBookings'] != null && data['currentBookings'] > 0 
            ? ((data['attendanceCount'] ?? 0) / data['currentBookings'] * 100).round()
            : 0,
        'lastAttendanceUpdate': data['lastAttendanceUpdate'],
      };
    });
  }

  /// Get all classes with live stats (Admin only)
  static Stream<List<Map<String, dynamic>>> getAllClassesWithStats() {
    return _firestore
        .collection('classes')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'classId': doc.id,
            'name': data['name'] ?? 'Unknown Class',
            'instructor': data['instructor'] ?? 'Unknown',
            'dateTime': data['dateTime'],
            'duration': data['duration'] ?? 60,
            'maxStudents': data['maxStudents'] ?? 20,
            'currentBookings': data['currentBookings'] ?? data['enrolledCount'] ?? 0,
            'attendanceCount': data['attendanceCount'] ?? 0,
            'liveAttendanceCount': data['liveAttendanceCount'] ?? 0,
            'attendanceRate': data['currentBookings'] != null && data['currentBookings'] > 0 
                ? ((data['attendanceCount'] ?? 0) / data['currentBookings'] * 100).round()
                : 0,
            'lastAttendanceUpdate': data['lastAttendanceUpdate'],
          };
        }).toList());
  }

  /// Get all workshops with live stats (Admin only)
  static Stream<List<Map<String, dynamic>>> getAllWorkshopsWithStats() {
    return _firestore
        .collection('workshops')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'workshopId': doc.id,
            'name': data['name'] ?? 'Unknown Workshop',
            'instructor': data['instructor'] ?? 'Unknown',
            'dateTime': data['dateTime'],
            'duration': data['duration'] ?? 120,
            'maxStudents': data['maxStudents'] ?? 20,
            'currentBookings': data['currentBookings'] ?? data['enrolledCount'] ?? 0,
            'attendanceCount': data['attendanceCount'] ?? 0,
            'liveAttendanceCount': data['liveAttendanceCount'] ?? 0,
            'attendanceRate': data['currentBookings'] != null && data['currentBookings'] > 0 
                ? ((data['attendanceCount'] ?? 0) / data['currentBookings'] * 100).round()
                : 0,
            'lastAttendanceUpdate': data['lastAttendanceUpdate'],
          };
        }).toList());
  }

  /// Remove student from class (Admin only)
  static Future<Map<String, dynamic>> removeStudentFromClass(String classId, String userId) async {
    try {
      // Remove from user's enrollments (canonical)
      var userEnrollmentQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .where('itemId', isEqualTo: classId)
          .where('itemType', isEqualTo: 'class')
          .get();

      for (var doc in userEnrollmentQuery.docs) {
        await doc.reference.delete();
      }

      // Also remove from legacy user enrolments
      userEnrollmentQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .where('itemId', isEqualTo: classId)
          .where('itemType', isEqualTo: 'class')
          .get();

      for (var doc in userEnrollmentQuery.docs) {
        await doc.reference.delete();
      }

      // Remove from global enrollments
      final globalEnrollmentQuery = await _firestore
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('itemId', isEqualTo: classId)
          .where('itemType', isEqualTo: 'class')
          .get();

      for (var doc in globalEnrollmentQuery.docs) {
        await doc.reference.delete();
      }

      // Update class booking count
      await _firestore.collection('classes').doc(classId).update({
        'currentBookings': FieldValue.increment(-1),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Student removed from class successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error removing student from class: $e',
      };
    }
  }

  /// Remove student from workshop (Admin only)
  static Future<Map<String, dynamic>> removeStudentFromWorkshop(String workshopId, String userId) async {
    try {
      // Remove from user's enrollments (canonical)
      var userEnrollmentQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .where('itemId', isEqualTo: workshopId)
          .where('itemType', isEqualTo: 'workshop')
          .get();

      for (var doc in userEnrollmentQuery.docs) {
        await doc.reference.delete();
      }

      // Also remove from legacy user enrolments
      userEnrollmentQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .where('itemId', isEqualTo: workshopId)
          .where('itemType', isEqualTo: 'workshop')
          .get();

      for (var doc in userEnrollmentQuery.docs) {
        await doc.reference.delete();
      }

      // Remove from global enrollments
      final globalEnrollmentQuery = await _firestore
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('itemId', isEqualTo: workshopId)
          .where('itemType', isEqualTo: 'workshop')
          .get();

      for (var doc in globalEnrollmentQuery.docs) {
        await doc.reference.delete();
      }

      // Update workshop booking count
      await _firestore.collection('workshops').doc(workshopId).update({
        'currentBookings': FieldValue.increment(-1),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Student removed from workshop successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error removing student from workshop: $e',
      };
    }
  }
}
