import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class AttendanceAlertService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int missedClassesThreshold = 3;
  static final StreamController<Map<String, dynamic>> _alertController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  static Stream<Map<String, dynamic>> get alertStream => _alertController.stream;

  /// Check attendance for all students and send alerts
  static Future<void> checkAllStudentsAttendance() async {
    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Student')
          .get();

      for (final userDoc in usersSnapshot.docs) {
        await _checkStudentAttendance(userDoc.id);
      }
    } catch (e) {
    }
  }

  /// Check attendance for a specific student
  static Future<void> _checkStudentAttendance(String userId) async {
    try {
      // Get user's enrollments
      final enrollmentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .where('status', isEqualTo: 'enrolled')
          .get();

      for (final enrollmentDoc in enrollmentsSnapshot.docs) {
        final enrollmentData = enrollmentDoc.data();
        final itemId = enrollmentDoc.id;
        final itemType = enrollmentData['itemType'] ?? 'class';
        
        await _checkItemAttendance(userId, itemId, itemType, enrollmentData);
      }
    } catch (e) {
    }
  }

  /// Check attendance for a specific class/workshop
  static Future<void> _checkItemAttendance(
    String userId,
    String itemId,
    String itemType,
    Map<String, dynamic> enrollmentData
  ) async {
    try {
      // Get attendance records for this specific item
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .where('classId', isEqualTo: itemId)
          .get();

      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));
      
      int totalSessions = 0;
      int attendedSessions = 0;
      int missedSessions = 0;

      // Count recent attendance for this item
      for (final doc in attendanceSnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        
        if (timestamp != null && timestamp.isAfter(oneWeekAgo)) {
          totalSessions++;
          attendedSessions++;
        }
      }

      // For now, we'll skip the alert logic since we don't have session data
      // This can be enhanced later when session data is available
    } catch (e) {
    }
  }

  /// Send attendance alert
  static Future<void> _sendAttendanceAlert(
    String userId,
    String itemId,
    String itemType,
    Map<String, dynamic> enrollmentData,
    int missedSessions,
    int totalSessions,
    int attendedSessions
  ) async {
    try {
      // Check if alert already sent today
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      
      final alertCheck = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('type', isEqualTo: 'attendance_alert')
          .where('data.itemId', isEqualTo: itemId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(todayStart))
          .limit(1)
          .get();

      if (alertCheck.docs.isNotEmpty) {
        return; // Already sent today
      }

      final itemName = enrollmentData['title'] ?? 'Unknown';
      final attendanceRate = totalSessions > 0 ? (attendedSessions / totalSessions * 100).round() : 0;

      // Send notification to user
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': '⚠️ Low Attendance Alert',
        'body': 'You have missed $missedSessions out of $totalSessions sessions in "$itemName". Your attendance rate is $attendanceRate%.',
        'message': 'You have missed $missedSessions out of $totalSessions sessions in "$itemName". Your attendance rate is $attendanceRate%.',
        'type': 'attendance_alert',
        'priority': 'high',
        'read': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'itemId': itemId,
          'itemType': itemType,
          'itemName': itemName,
          'missedSessions': missedSessions,
          'totalSessions': totalSessions,
          'attendedSessions': attendedSessions,
          'attendanceRate': attendanceRate,
        },
      });

    } catch (e) {
    }
  }

  /// Get student's attendance summary
  static Future<Map<String, dynamic>> getStudentAttendanceSummary(String userId) async {
    try {
      // Get all attendance records for the user
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .get();

      // Get user's enrollments
      final enrollmentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .where('status', isEqualTo: 'enrolled')
          .get();

      int totalAttendance = attendanceSnapshot.docs.length;
      int onTimeCount = 0;
      int lateCount = 0;
      int missedSessions = 0;
      List<Map<String, dynamic>> itemSummaries = [];

      // Process attendance records
      Map<String, int> classAttendance = {};
      for (final doc in attendanceSnapshot.docs) {
        final data = doc.data();
        final className = data['className'] ?? 'Unknown';
        final isLate = data['isLate'] ?? false;
        
        classAttendance[className] = (classAttendance[className] ?? 0) + 1;
        
        if (isLate) {
          lateCount++;
        } else {
          onTimeCount++;
        }
      }

      // Process enrollments to get item summaries
      for (final enrollmentDoc in enrollmentsSnapshot.docs) {
        final enrollmentData = enrollmentDoc.data();
        final itemId = enrollmentDoc.id;
        final itemType = enrollmentData['itemType'] ?? 'class';
        final itemName = enrollmentData['title'] ?? 'Unknown';

        // Count attendance for this specific item
        int itemAttendedSessions = 0;
        for (final doc in attendanceSnapshot.docs) {
          final data = doc.data();
          if (data['classId'] == itemId) {
            itemAttendedSessions++;
          }
        }

        itemSummaries.add({
          'itemId': itemId,
          'itemName': itemName,
          'itemType': itemType,
          'attendedSessions': itemAttendedSessions,
          'attendanceRate': itemAttendedSessions > 0 ? 100 : 0, // Simplified for now
        });
      }

      final overallAttendanceRate = totalAttendance > 0 ? (onTimeCount / totalAttendance * 100).round() : 0;

      return {
        'totalSessions': totalAttendance,
        'attendedSessions': totalAttendance,
        'missedSessions': missedSessions,
        'overallAttendanceRate': overallAttendanceRate,
        'onTimeCount': onTimeCount,
        'lateCount': lateCount,
        'itemSummaries': itemSummaries,
        'needsAlert': false, // Simplified for now
      };
    } catch (e) {
      return {
        'totalSessions': 0,
        'attendedSessions': 0,
        'missedSessions': 0,
        'overallAttendanceRate': 0,
        'onTimeCount': 0,
        'lateCount': 0,
        'itemSummaries': [],
        'needsAlert': false,
      };
    }
  }

  static void dispose() {
    _alertController.close();
  }
}
