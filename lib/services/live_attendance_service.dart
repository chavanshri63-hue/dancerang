import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/qr_stub.dart';
import 'package:cloud_functions/cloud_functions.dart';

// String extension for capitalization
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class LiveAttendanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Scan QR code and mark attendance
  static Future<Map<String, dynamic>> scanAndMarkAttendance({
    required String qrData,
    required String userId,
    required String userName,
  }) async {
    try {
      // Parse QR code data
      if (!qrData.startsWith('dancerang_attendance:')) {
        return {
          'success': false,
          'message': 'Invalid QR code format',
        };
      }

      final parts = qrData.split(':')[1].split('_');
      if (parts.length != 2) {
        return {
          'success': false,
          'message': 'Invalid QR code data',
        };
      }

      final classId = parts[0];
      final timestamp = int.tryParse(parts[1]);
      
      if (timestamp == null) {
        return {
          'success': false,
          'message': 'Invalid timestamp in QR code',
        };
      }

      final classTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      
      // Check if attendance is within valid time window (30 minutes before to 15 minutes after)
      final timeDiff = now.difference(classTime).inMinutes;
      if (timeDiff < -30 || timeDiff > 15) {
        return {
          'success': false,
          'message': 'Attendance window closed. Please arrive on time.',
        };
      }

      // Check if user is enrolled in this class - check both enrollments and class_enrollments
      final enrollmentCheck = await _firestore
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('itemId', isEqualTo: classId)
          .where('status', isEqualTo: 'enrolled')
          .limit(1)
          .get();

      // Also check canonical class_enrollments for expiry and sessions
      QueryDocumentSnapshot<Map<String, dynamic>>? canonicalEnrollment;
      try {
        final canonical = await _firestore
            .collection('class_enrollments')
            .where('userId', isEqualTo: userId)
            .where('classId', isEqualTo: classId)
            .limit(1)
            .get();
        if (canonical.docs.isNotEmpty) {
          canonicalEnrollment = canonical.docs.first;
        }
      } catch (_) {}

      if (enrollmentCheck.docs.isEmpty && canonicalEnrollment == null) {
        return {
          'success': false,
          'message': 'You are not enrolled in this class',
        };
      }

      // Check if enrollment is expired or completed
      if (canonicalEnrollment != null) {
        final enrollmentData = canonicalEnrollment.data();
        final status = enrollmentData['status'] as String? ?? '';
        final endDate = enrollmentData['endDate'] as Timestamp?;
        final remainingSessions = (enrollmentData['remainingSessions'] as num?)?.toInt() ?? 0;

        // Check if expired
        if (status == 'expired' || (endDate != null && endDate.toDate().isBefore(now))) {
          return {
            'success': false,
            'message': 'Classes khatam ho gaye h. Please join again to continue.',
          };
        }

        // Check if completed (no sessions remaining)
        if (status == 'completed' || remainingSessions <= 0) {
          return {
            'success': false,
            'message': 'Classes khatam ho gaye h. Please join again to continue.',
          };
        }
      } else if (enrollmentCheck.docs.isNotEmpty) {
        // Fallback: check enrollment from enrollments collection
        final enrollmentData = enrollmentCheck.docs.first.data();
        final status = enrollmentData['status'] as String? ?? '';
        final endDate = enrollmentData['endDate'] as Timestamp?;
        final remainingSessions = (enrollmentData['remainingSessions'] as num?)?.toInt() ?? 0;

        // Check if expired
        if (status == 'expired' || status == 'completed') {
          return {
            'success': false,
            'message': 'Classes khatam ho gaye h. Please join again to continue.',
          };
        }

        if (endDate != null && endDate.toDate().isBefore(now)) {
          return {
            'success': false,
            'message': 'Classes khatam ho gaye h. Please join again to continue.',
          };
        }

        // Check remaining sessions
        if (remainingSessions <= 0) {
          return {
            'success': false,
            'message': 'Classes khatam ho gaye h. Please join again to continue.',
          };
        }
      }

      // Check if already marked attendance
      final existingAttendance = await _firestore
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (existingAttendance.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'Attendance already marked for this class',
        };
      }

      // Mark attendance
      await _firestore.collection('attendance').add({
        'classId': classId,
        'userId': userId,
        'userName': userName,
        'markedAt': FieldValue.serverTimestamp(),
        'classTime': Timestamp.fromDate(classTime),
        'status': 'present',
        'isLate': timeDiff > 0,
        'lateMinutes': timeDiff > 0 ? timeDiff : 0,
      });

      // Update class attendance count (only if class document exists)
      try {
        final classDoc = await _firestore.collection('classes').doc(classId).get();
        if (classDoc.exists) {
          await _firestore.collection('classes').doc(classId).update({
            'attendanceCount': FieldValue.increment(1),
            'lastAttendanceUpdate': FieldValue.serverTimestamp(),
          });
        } else {
        }
      } catch (e) {
      }

      // Update user's session progress in enrollment
      await _updateUserSessionProgress(userId, classId);
      
      // Trigger home screen stats update
      await _triggerHomeStatsUpdate(userId);

      return {
        'success': true,
        'message': 'Attendance marked successfully!',
        'isLate': timeDiff > 0,
        'lateMinutes': timeDiff > 0 ? timeDiff : 0,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error marking attendance: $e',
      };
    }
  }

  /// Mark workshop attendance (simpler than class attendance)
  static Future<Map<String, dynamic>> markWorkshopAttendance({
    required String userId,
    required String userName,
    String? workshopId,
  }) async {
    try {
      // Resolve workshopId: if not provided, pick first enrolled
      String? resolvedWorkshopId = workshopId;
      if (resolvedWorkshopId == null) {
        final enrollmentSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('enrollments')
            .where('status', isEqualTo: 'enrolled')
            .get();

        final workshopEnrollments = enrollmentSnapshot.docs
            .where((doc) => doc.data()['itemType'] == 'workshop')
            .toList();

        if (workshopEnrollments.isEmpty) {
          return {
            'success': false,
            'message': 'Student is not enrolled in any workshops',
          };
        }

        final enrollmentDoc = workshopEnrollments.first;
        final enrollmentData = enrollmentDoc.data();
        resolvedWorkshopId = enrollmentData['itemId'] as String?;
      }
      
      if (resolvedWorkshopId == null) {
        return {
          'success': false,
          'message': 'Invalid workshop enrollment',
        };
      }

      // Check if already marked attendance for this workshop today (workshop_attendance)
      final existingAttendance = await _firestore
          .collection('workshop_attendance')
          .where('workshopId', isEqualTo: resolvedWorkshopId)
          .where('userId', isEqualTo: userId)
          .get();

      // Check if attendance already marked today (client-side filtering)
      final now = DateTime.now();
      final todayAttendance = existingAttendance.docs.where((doc) {
        final markedAt = (doc.data()['markedAt'] as Timestamp?)?.toDate();
        if (markedAt == null) return false;
        return markedAt.year == now.year && 
               markedAt.month == now.month && 
               markedAt.day == now.day;
      }).toList();

      if (todayAttendance.isNotEmpty) {
        return {
          'success': false,
          'message': 'Attendance already marked for this workshop today',
        };
      }

      // Get workshop name for attendance record
      final workshopDoc = await _firestore.collection('workshops').doc(resolvedWorkshopId).get();
      final workshopName = workshopDoc.data()?['name'] ?? 'Unknown Workshop';

      // Mark workshop attendance in dedicated collection
      await _firestore.collection('workshop_attendance').add({
        'workshopId': resolvedWorkshopId,
        'workshopName': workshopName,
        'userId': userId,
        'userName': userName,
        'markedAt': FieldValue.serverTimestamp(),
        'status': 'present',
        'type': 'workshop',
      });

      // Update workshop attendance count and live stats (only if workshop document exists)
      try {
        final workshopDoc = await _firestore.collection('workshops').doc(resolvedWorkshopId).get();
        if (workshopDoc.exists) {
          await _firestore.collection('workshops').doc(resolvedWorkshopId).update({
            'attendanceCount': FieldValue.increment(1),
            'lastAttendanceUpdate': FieldValue.serverTimestamp(),
            'liveAttendanceCount': FieldValue.increment(1),
          });
        } else {
        }
      } catch (e) {
      }

      // Update user's workshop session progress
      await _updateWorkshopSessionProgress(userId, resolvedWorkshopId);

      // Update global attendance stats
      await _updateGlobalAttendanceStats('workshop');
      
      // Trigger home screen stats update
      await _triggerHomeStatsUpdate(userId);

      return {
        'success': true,
        'message': 'Workshop attendance marked successfully!',
        'workshopId': resolvedWorkshopId,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error marking workshop attendance: $e',
      };
    }
  }

  /// Mark workshop attendance via Cloud Function (uses server privileges)
  /// Use when client Firestore rules deny direct writes for faculty/admin scans
  static Future<Map<String, dynamic>> markWorkshopAttendanceServer({
    required String userId,
    required String userName,
    String? workshopId,
  }) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final HttpsCallable callable = functions.httpsCallable('markWorkshopAttendance');
      final result = await callable.call(<String, dynamic>{
        'userId': userId,
        'userName': userName,
        if (workshopId != null) 'workshopId': workshopId,
      });

      final data = (result.data as Map).cast<String, dynamic>();
      return {
        'success': data['success'] == true,
        'message': data['message'] ?? (data['success'] == true ? 'Workshop attendance marked successfully!' : 'Failed to mark attendance'),
        'workshopId': data['workshopId'] ?? workshopId,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error marking workshop attendance (server): $e',
      };
    }
  }

  /// Mark class attendance directly (without QR data)
  static Future<Map<String, dynamic>> markClassAttendance({
    required String userId,
    required String userName,
  }) async {
    try {
      // Check if user has any enrolled classes (simplified query)
      final enrollmentSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .where('status', isEqualTo: 'enrolled')
          .get();

      // Filter for classes only
      final classEnrollments = enrollmentSnapshot.docs
          .where((doc) => doc.data()['itemType'] == 'class')
          .toList();

      if (classEnrollments.isEmpty) {
        return {
          'success': false,
          'message': 'Student is not enrolled in any classes',
        };
      }

      // Prefer an active, non-expired enrollment
      final now = DateTime.now();
      final validEnrollments = classEnrollments.where((doc) {
        final data = doc.data();
        final endTs = data['endDate'];
        if (endTs is Timestamp) {
          final end = endTs.toDate();
          if (end.isBefore(now)) return false;
        }
        return true;
      }).toList();

      // Try to use canonical enrollment (class_enrollments) to enforce sessions
      QueryDocumentSnapshot<Map<String, dynamic>>? canonicalEnrollment;
      String? classId;
      try {
        final canonical = await _firestore
            .collection('class_enrollments')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();
        if (canonical.docs.isNotEmpty) {
          canonicalEnrollment = canonical.docs.first;
          classId = canonicalEnrollment.data()['classId'] as String?;
        }
      } catch (_) {}

      if (classId == null) {
        final enrollment = validEnrollments.isNotEmpty ? validEnrollments.first : classEnrollments.first;
        final enrollmentData = enrollment.data();
        classId = enrollmentData['itemId'] as String?;
      }

      if (classId == null) {
        return {
          'success': false,
          'message': 'Invalid class enrollment data',
        };
      }

      // Check remaining sessions if canonical enrollment exists
      if (canonicalEnrollment != null) {
        final int remaining = (canonicalEnrollment.data()['remainingSessions'] as num?)?.toInt() ?? 0;
        if (remaining <= 0) {
          return {
            'success': false,
            'message': 'No sessions remaining. Please renew to continue.',
          };
        }
      }

      // Check if attendance already marked today (simplified query to avoid index requirement)
      final existingAttendance = await _firestore
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .where('userId', isEqualTo: userId)
          .get();

      // Check if attendance already marked today (client-side filtering)
      final todayAttendance = existingAttendance.docs.where((doc) {
        final markedAt = (doc.data()['markedAt'] as Timestamp?)?.toDate();
        if (markedAt == null) return false;
        return markedAt.year == now.year && 
               markedAt.month == now.month && 
               markedAt.day == now.day;
      }).toList();

      if (todayAttendance.isNotEmpty) {
        return {
          'success': false,
          'message': 'Attendance already marked for this class today',
        };
      }

      // Get class name for attendance record
      final classDoc = await _firestore.collection('classes').doc(classId).get();
      if (!classDoc.exists) {
        return {
          'success': false,
          'message': 'Class not found. Please contact admin to fix enrollment data.',
        };
      }
      final className = classDoc.data()?['name'] ?? 'Unknown Class';

      // Mark class attendance
      await _firestore.collection('attendance').add({
        'classId': classId,
        'className': className,
        'userId': userId,
        'userName': userName,
        'markedAt': FieldValue.serverTimestamp(),
        'status': 'present',
        'type': 'class',
      });

      // Update class attendance count and live stats (only if class document exists)
      try {
        final classDoc = await _firestore.collection('classes').doc(classId).get();
        if (classDoc.exists) {
          await _firestore.collection('classes').doc(classId).update({
            'attendanceCount': FieldValue.increment(1),
            'lastAttendanceUpdate': FieldValue.serverTimestamp(),
            'liveAttendanceCount': FieldValue.increment(1),
          });
        } else {
        }
      } catch (e) {
      }

      // Update user's session progress
      await _updateUserSessionProgress(userId, classId);

      // Decrement remainingSessions and mark as completed if needed (canonical class_enrollments)
      if (canonicalEnrollment != null) {
        try {
          final data = canonicalEnrollment.data();
          final int total = (data['totalSessions'] as num?)?.toInt() ?? 0;
          final int completed = (data['completedSessions'] as num?)?.toInt() ?? 0;
          final int newCompleted = completed + 1;
          final int newRemaining = total > 0 ? (total - newCompleted) : 0;
          final Map<String, dynamic> updates = {
            'completedSessions': newCompleted,
            'remainingSessions': newRemaining,
            'lastSessionAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          // Mark as completed when no sessions remaining
          if (newRemaining <= 0) {
            updates['status'] = 'completed';
            updates['completedAt'] = FieldValue.serverTimestamp();
          }
          await canonicalEnrollment.reference.update(updates);
        } catch (e) {
        }
      }

      // Update global attendance stats
      await _updateGlobalAttendanceStats('class');

      return {
        'success': true,
        'message': 'Class attendance marked successfully!',
        'classId': classId,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error marking class attendance: $e',
      };
    }
  }

  /// Update user's workshop session progress when attendance is marked
  static Future<void> _updateWorkshopSessionProgress(String userId, String workshopId) async {
    try {
      // Get user's enrollment for this workshop from global enrollments collection
      final globalEnrollmentSnapshot = await _firestore
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('itemId', isEqualTo: workshopId)
          .where('status', isEqualTo: 'enrolled')
          .limit(1)
          .get();

      if (globalEnrollmentSnapshot.docs.isNotEmpty) {
        final globalEnrollmentDoc = globalEnrollmentSnapshot.docs.first;
        
        // Mark workshop as completed (1/1 sessions) in global collection
        await globalEnrollmentDoc.reference.update({
          'completedSessions': 1,
          'remainingSessions': 0,
          'status': 'completed',
          'lastSessionAt': FieldValue.serverTimestamp(),
          'completedAt': FieldValue.serverTimestamp(),
          'workshopCompleted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update user subcollection: users/{userId}/enrollments/{workshopId}
        try {
          final userEnrollmentRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('enrollments')
              .doc(workshopId);
          
          final userEnrollmentDoc = await userEnrollmentRef.get();
          if (userEnrollmentDoc.exists) {
            await userEnrollmentRef.update({
              'completedSessions': 1,
              'remainingSessions': 0,
              'status': 'completed',
              'lastSessionAt': FieldValue.serverTimestamp(),
              'completedAt': FieldValue.serverTimestamp(),
              'workshopCompleted': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
        }

      }
    } catch (e) {
    }
  }

  /// Update user's session progress when attendance is marked
  static Future<void> _updateUserSessionProgress(String userId, String classId) async {
    try {
      // Get user's enrollment for this class from global enrollments collection
      final enrollmentSnapshot = await _firestore
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('itemId', isEqualTo: classId)
          .where('status', isEqualTo: 'enrolled')
          .limit(1)
          .get();

      if (enrollmentSnapshot.docs.isNotEmpty) {
        final enrollmentDoc = enrollmentSnapshot.docs.first;
        final enrollmentData = enrollmentDoc.data();
        
        // Get current session counts
        final currentCompleted = (enrollmentData['completedSessions'] as num?)?.toInt() ?? 0;
        final currentRemaining = (enrollmentData['remainingSessions'] as num?)?.toInt() ?? 0;
        final totalSessions = (enrollmentData['totalSessions'] as num?)?.toInt() ?? (currentCompleted + currentRemaining);
        final newCompleted = currentCompleted + 1;
        final newRemaining = currentRemaining > 0 ? currentRemaining - 1 : 0;
        
        // Check if class is completed (no sessions remaining)
        final bool isCompleted = newRemaining <= 0;
        
        // Prepare updates for global enrollments collection
        final Map<String, dynamic> globalUpdates = {
          'completedSessions': newCompleted,
          'remainingSessions': newRemaining,
          'lastSessionAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        // If completed, update status to 'completed'
        if (isCompleted) {
          globalUpdates['status'] = 'completed';
          globalUpdates['completedAt'] = FieldValue.serverTimestamp();
        }
        
        // Update global enrollments collection
        await enrollmentDoc.reference.update(globalUpdates);
        
        // Update user subcollection: users/{userId}/enrollments/{classId}
        try {
          final userEnrollmentRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('enrollments')
              .doc(classId);
          
          final userEnrollmentDoc = await userEnrollmentRef.get();
          if (userEnrollmentDoc.exists) {
            final Map<String, dynamic> userUpdates = {
              'completedSessions': newCompleted,
              'remainingSessions': newRemaining,
              'lastSessionAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            };
            
            if (isCompleted) {
              userUpdates['status'] = 'completed';
              userUpdates['completedAt'] = FieldValue.serverTimestamp();
            }
            
            await userEnrollmentRef.update(userUpdates);
          }
        } catch (e) {
        }

      }
    } catch (e) {
    }
  }

  /// Trigger home screen stats update after attendance marking
  static Future<void> _triggerHomeStatsUpdate(String userId) async {
    try {
      // Update a trigger document to notify home screen of stats change
      await _firestore
          .collection('user_stats_triggers')
          .doc(userId)
          .set({
        'lastAttendanceUpdate': FieldValue.serverTimestamp(),
        'userId': userId,
      }, SetOptions(merge: true));
    } catch (e) {
    }
  }

  /// Get live attendance for a class
  static Stream<List<Map<String, dynamic>>> getLiveAttendance(String classId) {
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

  /// Get live workshop attendance stream (dedicated collection)
  static Stream<List<Map<String, dynamic>>> getLiveWorkshopAttendance(String workshopId) {
    return _firestore
        .collection('workshop_attendance')
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

  /// Get user's attendance history
  static Stream<List<Map<String, dynamic>>> getUserAttendanceHistory(String userId) {
    return _firestore
        .collection('attendance')
        .where('userId', isEqualTo: userId)
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

  /// Get recent attendance across all classes (admin view)
  static Stream<List<Map<String, dynamic>>> getRecentAttendance({int limit = 20}) {
    return _firestore
        .collection('attendance')
        .orderBy('markedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
              };
            }).toList());
  }

  /// Update global attendance statistics
  static Future<void> _updateGlobalAttendanceStats(String type) async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // Update daily stats
      await _firestore.collection('stats').doc('daily').set({
        'date': todayStr,
        '${type}Attendance': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update overall stats
      await _firestore.collection('stats').doc('overall').set({
        'total${type.capitalize()}Attendance': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
    }
  }

  /// Get class attendance statistics
  static Future<Map<String, dynamic>> getClassAttendanceStats(String classId) async {
    try {
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .get();

      final totalMarked = attendanceSnapshot.docs.length;
      final lateCount = attendanceSnapshot.docs
          .where((doc) => doc.data()['isLate'] == true)
          .length;
      final onTimeCount = totalMarked - lateCount;

      final classDoc = await _firestore.collection('classes').doc(classId).get();
      final classData = classDoc.data();
      final maxStudents = classData?['maxStudents'] ?? 20;
      final enrollmentCount = classData?['currentBookings'] ?? classData?['enrolledCount'] ?? 0;

      return {
        'totalMarked': totalMarked,
        'onTime': onTimeCount,
        'late': lateCount,
        'enrolled': enrollmentCount,
        'maxStudents': maxStudents,
        'attendanceRate': enrollmentCount > 0 ? (totalMarked / enrollmentCount * 100).round() : 0,
      };
    } catch (e) {
      return {
        'totalMarked': 0,
        'onTime': 0,
        'late': 0,
        'enrolled': 0,
        'maxStudents': 0,
        'attendanceRate': 0,
      };
    }
  }
}

/// QR Code Scanner Widget
class AttendanceQRScanner extends StatefulWidget {
  final Function(String) onQRCodeScanned;
  final String classId;
  final DateTime classTime;

  const AttendanceQRScanner({
    super.key,
    required this.onQRCodeScanned,
    required this.classId,
    required this.classTime,
  });

  @override
  State<AttendanceQRScanner> createState() => _AttendanceQRScannerState();
}

class _AttendanceQRScannerState extends State<AttendanceQRScanner> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool flashOn = false;
  bool frontCamera = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
              await controller?.toggleFlash();
              setState(() {
                flashOn = !flashOn;
              });
            },
            icon: Icon(
              flashOn ? Icons.flash_on : Icons.flash_off,
              color: flashOn ? Colors.yellow : Colors.grey,
            ),
          ),
          IconButton(
            onPressed: () async {
              await controller?.flipCamera();
              setState(() {
                frontCamera = !frontCamera;
              });
            },
            icon: Icon(
              frontCamera ? Icons.camera_front : Icons.camera_rear,
            ),
          ),
        ],
      ),
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: Colors.red,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 300,
        ),
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null) {
        widget.onQRCodeScanned(scanData.code!);
      }
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

/// Live Attendance Dashboard Widget
class LiveAttendanceDashboard extends StatelessWidget {
  final String classId;
  final String className;

  const LiveAttendanceDashboard({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text('Live Attendance - $className'),
        backgroundColor: const Color(0xFF1B1B1B),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Statistics Card
          FutureBuilder<Map<String, dynamic>>(
            future: LiveAttendanceService.getClassAttendanceStats(classId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final stats = snapshot.data!;
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Live Attendance Stats',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Present', stats['totalMarked'].toString(), Colors.green),
                        _buildStatItem('On Time', stats['onTime'].toString(), Colors.blue),
                        _buildStatItem('Late', stats['late'].toString(), Colors.orange),
                        _buildStatItem('Rate', '${stats['attendanceRate']}%', Colors.purple),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Live Attendance List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: LiveAttendanceService.getLiveAttendance(classId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }
                
                final attendanceList = snapshot.data ?? [];
                
                if (attendanceList.isEmpty) {
                  return const Center(
                    child: Text(
                      'No attendance marked yet',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: attendanceList.length,
                  itemBuilder: (context, index) {
                    final attendance = attendanceList[index];
                    final isLate = attendance['isLate'] == true;
                    final markedAt = (attendance['markedAt'] as Timestamp?)?.toDate();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B1B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isLate ? Colors.orange : Colors.green,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isLate ? Icons.schedule : Icons.check_circle,
                            color: isLate ? Colors.orange : Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  attendance['userName'] ?? 'Unknown',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (markedAt != null)
                                  Text(
                                    'Marked at ${markedAt.hour}:${markedAt.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isLate)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '+${attendance['lateMinutes']} min',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
