import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// AdminStudentsService provides admin-only functionality for managing student lists
/// in classes and workshops
class AdminStudentsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, Map<String, dynamic>> _userCache = {};

  /// Get enrolled students for a specific class (Admin/Faculty)
  static Stream<List<Map<String, dynamic>>> getClassEnrolledStudents(String classId) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? classEnrollSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? legacyEnrollSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? globalEnrollSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? attendanceSub;
    Timer? debounce;

    List<QueryDocumentSnapshot<Map<String, dynamic>>> classEnrollDocs = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> legacyEnrollDocs = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> globalEnrollDocs = [];
    Map<String, int> attendanceCounts = {};

    Future<void> computeAndEmit() async {
      final Map<String, Map<String, dynamic>> enrollmentByUser = {};
      final Map<String, int> priorityByUser = {};

      void addEnrollment(Map<String, dynamic> enrollmentData, String enrollmentId, int priority) {
        final userId =
            (enrollmentData['user_id'] ?? enrollmentData['userId'] ?? '').toString();
        if (userId.isEmpty) return;
        final current = priorityByUser[userId] ?? -1;
        if (priority < current) return;
        priorityByUser[userId] = priority;
        enrollmentByUser[userId] = {
          ...enrollmentData,
          'enrollmentId': enrollmentId,
        };
      }

      for (final doc in classEnrollDocs) {
        addEnrollment(doc.data(), doc.id, 2);
      }
      for (final doc in legacyEnrollDocs) {
        addEnrollment(doc.data(), doc.id, 2);
      }
      for (final doc in globalEnrollDocs) {
        addEnrollment(doc.data(), doc.id, 1);
      }

      if (enrollmentByUser.isEmpty) {
        controller.add([]);
        return;
      }

      final userIds = enrollmentByUser.keys.toList();
      final Map<String, Map<String, dynamic>> userDataMap = {};
      final List<Future<void>> fetches = [];
      for (final userId in userIds) {
        final cached = _userCache[userId];
        if (cached != null) {
          userDataMap[userId] = cached;
          continue;
        }
        fetches.add(_firestore.collection('users').doc(userId).get().then((doc) {
          final data = doc.data() ?? {};
          _userCache[userId] = data;
          userDataMap[userId] = data;
        }).catchError((_) {
          _userCache[userId] = {};
          userDataMap[userId] = {};
        }));
      }
      if (fetches.isNotEmpty) {
        await Future.wait(fetches);
      }

      final List<Map<String, dynamic>> students = [];
      for (final userId in userIds) {
        final enrollmentData = enrollmentByUser[userId] ?? {};
        final userData = userDataMap[userId] ?? {};
        int total = (enrollmentData['totalSessions'] ?? 0) as int;
        if (total <= 0) {
          final classDoc = await _firestore.collection('classes').doc(classId).get();
          final classData = classDoc.data() ?? {};
          total = (classData['numberOfSessions'] ?? 8) as int;
        }
        final completedFromEnroll = (enrollmentData['completedSessions'] ?? 0) as int;
        final completedFromAttendance = attendanceCounts[userId] ?? 0;
        final completed = completedFromAttendance > 0 ? completedFromAttendance : completedFromEnroll;
        final remaining = total - completed;
        students.add({
          'userId': userId,
          'name': userData['name'] ?? userData['displayName'] ?? 'Unknown',
          'email': userData['email'] ?? '',
          'phone': userData['phone'] ?? '',
          'enrollmentDate': enrollmentData['createdAt'] ??
              enrollmentData['enrolledAt'] ??
              enrollmentData['enrolled_at'],
          'completedSessions': completed,
          'totalSessions': total,
          'remainingSessions': enrollmentData['remainingSessions'] ??
              (remaining < 0 ? 0 : remaining),
          'packageName': enrollmentData['packageName'] ?? 'Unknown Package',
          'paymentStatus': enrollmentData['paymentStatus'] ?? 'paid',
          'lastAttendanceDate': enrollmentData['lastAttendanceDate'] ??
              enrollmentData['lastSessionAt'],
          'enrollmentId': enrollmentData['enrollmentId'],
        });
      }

      controller.add(students);
    }

    void scheduleCompute() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 200), () {
        computeAndEmit();
      });
    }

    classEnrollSub = _firestore
        .collection('class_enrollments')
        .where('classId', isEqualTo: classId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snap) {
      classEnrollDocs = snap.docs;
      scheduleCompute();
    });

    legacyEnrollSub = _firestore
        .collection('class_enrollments')
        .where('class_id', isEqualTo: classId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snap) {
      legacyEnrollDocs = snap.docs;
      scheduleCompute();
    });

    globalEnrollSub = _firestore
        .collection('enrollments')
        .where('status', isEqualTo: 'enrolled')
        .where('itemType', isEqualTo: 'class')
        .where('itemId', isEqualTo: classId)
        .snapshots()
        .listen((snap) {
      globalEnrollDocs = snap.docs;
      scheduleCompute();
    });

    attendanceSub = _firestore
        .collection('attendance')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .listen((snap) {
      final Map<String, int> counts = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final userId = (data['userId'] ?? '').toString();
        if (userId.isEmpty) continue;
        final status = (data['status'] ?? 'present').toString().toLowerCase();
        if (status == 'absent') continue;
        counts[userId] = (counts[userId] ?? 0) + 1;
      }
      attendanceCounts = counts;
      scheduleCompute();
    });

    controller.onCancel = () async {
      await classEnrollSub?.cancel();
      await legacyEnrollSub?.cancel();
      await globalEnrollSub?.cancel();
      await attendanceSub?.cancel();
      debounce?.cancel();
    };

    return controller.stream;
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
