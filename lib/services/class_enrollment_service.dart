import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/class_enrollment_model.dart';
import 'payment_service.dart';
import '../utils/error_handler.dart';

/// Service for managing class enrollments with session tracking
class ClassEnrollmentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _enrollmentsCollection = 'class_enrollments';
  static const String _attendanceCollection = 'attendance';

  /// Enroll student in a class with a package
  static Future<Map<String, dynamic>> enrollInClass({
    required String classId,
    required String className,
    required ClassPackage package,
    required String userId,
  }) async {
    try {
      // Check if user is already actively enrolled (before transaction)
      final existingEnrollment = await _firestore
          .collection(_enrollmentsCollection)
          .where('user_id', isEqualTo: userId)
          .where('classId', isEqualTo: classId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (existingEnrollment.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'You are already enrolled in this class',
        };
      }

      // Also check global enrollments for 'enrolled' status
      final existingGlobalEnrolled = await _firestore
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('itemId', isEqualTo: classId)
          .where('status', isEqualTo: 'enrolled')
          .limit(1)
          .get();

      if (existingGlobalEnrolled.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'You are already enrolled in this class',
        };
      }

      // Clean up stale pending_payment enrollments (older than 30 minutes)
      await _cleanupStalePendingEnrollments(userId, classId);

      // Archive old completed enrollments so re-join works cleanly
      await _archiveCompletedEnrollments(userId, classId);

      // Use transaction to atomically check capacity and create enrollment
      final transactionResult = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {

        // Check class capacity (atomic check)
        final classRef = _firestore.collection('classes').doc(classId);
        final classDoc = await transaction.get(classRef);
        
        if (!classDoc.exists) {
          return {
            'success': false,
            'message': 'Class not found',
          };
        }

        final classData = classDoc.data() ?? {};
        final maxStudents = (classData['maxStudents'] as num?)?.toInt() ?? 20;
        final currentBookings = (classData['currentBookings'] as num?)?.toInt() ?? 
                                (classData['enrolledCount'] as num?)?.toInt() ?? 0;

        if (currentBookings >= maxStudents) {
          return {
            'success': false,
            'message': 'Class is fully booked. Please try another class.',
        };
      }

      // Create enrollment record
      final enrollmentId = _firestore.collection(_enrollmentsCollection).doc().id;
      final now = DateTime.now();
      final endDate = now.add(Duration(days: package.validityDays));

      final enrollment = ClassEnrollment(
        id: enrollmentId,
        userId: userId,
        classId: classId,
        className: className,
        packageId: package.id,
        packageName: package.name,
        totalSessions: package.totalSessions,
        completedSessions: 0,
        remainingSessions: package.totalSessions,
        startDate: now,
        endDate: endDate,
        status: 'pending_payment',
        packagePrice: package.price,
        paymentStatus: 'pending',
        attendanceHistory: [],
        createdAt: now,
        updatedAt: now,
      );

        // Save enrollment in transaction
        final enrollmentRef = _firestore.collection(_enrollmentsCollection).doc(enrollmentId);
        transaction.set(enrollmentRef, enrollment.toMap());

        // Return enrollment ID for payment processing
        return {
          'success': true,
          'enrollmentId': enrollmentId,
          'message': 'Enrollment created. Proceed with payment.',
        };
      });

      // If transaction succeeded, proceed with payment
      if (transactionResult['success'] == true) {
        final enrollmentId = transactionResult['enrollmentId'] as String;
        final now = DateTime.now();

      // Process payment
      final paymentResult = await PaymentService.processPayment(
        paymentId: 'enrollment_${enrollmentId}_${now.millisecondsSinceEpoch}',
        amount: package.price.toInt(),
        description: '${package.name} - ${className}',
        paymentType: 'class_enrollment',
        itemId: enrollmentId,
        metadata: {
          'classId': classId,
          'className': className,
          'packageId': package.id,
          'packageName': package.name,
          'totalSessions': package.totalSessions,
        },
      );

      if (paymentResult['success'] == true) {
          // Fulfill enrollment after successful payment — retry up to 3 times
          bool fulfilled = false;
          Exception? lastError;
          for (int attempt = 0; attempt < 3 && !fulfilled; attempt++) {
            try {
              await _firestore.runTransaction((transaction) async {
                final enrollmentRef = _firestore.collection(_enrollmentsCollection).doc(enrollmentId);
                transaction.update(enrollmentRef, {
                  'paymentStatus': 'paid',
                  'status': 'active',
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                final userEnrollRef = _firestore
                    .collection('users')
                    .doc(userId)
                    .collection('enrollments')
                    .doc(classId);
                transaction.set(userEnrollRef, {
                  'itemId': classId,
                  'itemType': 'class',
                  'status': 'enrolled',
                  'enrolledAt': FieldValue.serverTimestamp(),
                  'totalSessions': package.totalSessions,
                  'completedSessions': 0,
                  'packageId': package.id,
                  'packageName': package.name,
                }, SetOptions(merge: true));

                final classRef = _firestore.collection('classes').doc(classId);
                final classDoc = await transaction.get(classRef);
                String actualClassName = className;
                if (classDoc.exists) {
                  actualClassName = classDoc.data()?['name'] ?? className;
                }

                final globalEnrollRef = _firestore.collection('enrollments').doc();
                transaction.set(globalEnrollRef, {
                  'userId': userId,
                  'user_id': userId,
                  'itemId': classId,
                  'itemType': 'class',
                  'status': 'enrolled',
                  'enrolledAt': FieldValue.serverTimestamp(),
                  'className': actualClassName,
                  'totalSessions': package.totalSessions,
                  'completedSessions': 0,
                  'remainingSessions': package.totalSessions,
                  'packageId': package.id,
                  'packageName': package.name,
                  'packagePrice': package.price,
                  'paymentStatus': 'paid',
                  'enrollmentId': enrollmentId,
                });

                transaction.update(classRef, {
                  'enrolledCount': FieldValue.increment(1),
                  'currentBookings': FieldValue.increment(1),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              });
              fulfilled = true;
            } catch (e) {
              lastError = e is Exception ? e : Exception(e.toString());
              if (attempt < 2) {
                await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
              }
            }
          }

          if (fulfilled) {
            return {
              'success': true,
              'message': 'Successfully enrolled in class!',
              'enrollmentId': enrollmentId,
            };
          } else {
            // Payment succeeded but enrollment fulfillment failed — mark for reconciliation
            try {
              await _firestore
                  .collection(_enrollmentsCollection)
                  .doc(enrollmentId)
                  .update({
                'paymentStatus': 'paid',
                'status': 'payment_success_unfulfilled',
                'updatedAt': FieldValue.serverTimestamp(),
                'fulfillmentError': lastError?.toString(),
              });
            } catch (_) {}
            ErrorHandler.handleError(
              lastError ?? Exception('Enrollment fulfillment failed after payment'),
              StackTrace.current,
              context: 'fulfilling enrollment after payment (all retries failed)',
            );
            return {
              'success': false,
              'message': 'Payment was successful but enrollment could not be completed. Please contact support.',
            };
          }
      } else {
        // Payment failed — clean up the pending enrollment
        try {
          await _firestore
              .collection(_enrollmentsCollection)
              .doc(enrollmentId)
              .update({
            'paymentStatus': 'failed',
            'status': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (cleanupErr, cleanupStack) {
          ErrorHandler.handleError(cleanupErr, cleanupStack, context: 'cleaning up failed enrollment');
        }

        return {
          'success': false,
          'message': paymentResult['message'] ?? 'Payment failed',
        };
        }
      } else {
        // Transaction failed (duplicate or capacity exceeded)
        return transactionResult;
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'enrolling in class');
      return {
        'success': false,
        'message': ErrorHandler.getUserFriendlyMessage(e),
      };
    }
  }

  /// Get user's active enrollments
  static Future<List<ClassEnrollment>> getUserEnrollments(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_enrollmentsCollection)
          .where('user_id', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ClassEnrollment.fromMap(doc.data()))
          .toList();
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'fetching user enrollments');
      return [];
    }
  }

  /// Get enrollment by ID
  static Future<ClassEnrollment?> getEnrollmentById(String enrollmentId) async {
    try {
      final doc = await _firestore
          .collection(_enrollmentsCollection)
          .doc(enrollmentId)
          .get();

      if (doc.exists) {
        return ClassEnrollment.fromMap(doc.data()!);
      }
      return null;
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'fetching enrollment by ID');
      return null;
    }
  }

  /// Mark attendance and update session count
  static Future<Map<String, dynamic>> markAttendance({
    required String enrollmentId,
    required String classId,
    required String className,
    required String markedBy,
    required String markedByName,
    String status = 'present',
    String? notes,
  }) async {
    try {
      final enrollment = await getEnrollmentById(enrollmentId);
      if (enrollment == null) {
        return {
          'success': false,
          'message': 'Enrollment not found',
        };
      }

      // Check if attendance already marked today
      final today = DateTime.now();
      final todayAttendance = enrollment.attendanceHistory.where((record) {
        return record.attendanceDate.year == today.year &&
               record.attendanceDate.month == today.month &&
               record.attendanceDate.day == today.day;
      }).toList();

      if (todayAttendance.isNotEmpty) {
        return {
          'success': false,
          'message': 'Attendance already marked for today',
        };
      }

      // Create attendance record
      final attendanceRecord = AttendanceRecord(
        id: _firestore.collection(_attendanceCollection).doc().id,
        attendanceDate: today,
        classId: classId,
        className: className,
        markedBy: markedBy,
        markedByName: markedByName,
        status: status,
        notes: notes,
      );

      // Update enrollment
      final updatedAttendanceHistory = List<AttendanceRecord>.from(enrollment.attendanceHistory);
      updatedAttendanceHistory.add(attendanceRecord);

      final newCompletedSessions = status == 'present' 
          ? enrollment.completedSessions + 1 
          : enrollment.completedSessions;
      final newRemainingSessions = enrollment.totalSessions - newCompletedSessions;

      await _firestore
          .collection(_enrollmentsCollection)
          .doc(enrollmentId)
          .update({
        'completedSessions': newCompletedSessions,
        'remainingSessions': newRemainingSessions,
        'lastAttendanceDate': FieldValue.serverTimestamp(),
        'attendanceHistory': updatedAttendanceHistory.map((record) => record.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also update the user's enrollments subcollection
      await _firestore
          .collection('users')
          .doc(enrollment.userId)
          .collection('enrollments')
          .doc(classId)
          .update({
        'completedSessions': newCompletedSessions,
        'lastSessionAt': FieldValue.serverTimestamp(),
      });
      // Update the user's enrollments subcollection
      await _firestore
          .collection('users')
          .doc(enrollment.userId)
          .collection('enrollments')
          .doc(classId)
          .set({
        'completedSessions': newCompletedSessions,
        'lastSessionAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update global enrollments collection
      final globalEnrollment = await _firestore
          .collection('enrollments')
          .where('enrollmentId', isEqualTo: enrollmentId)
          .limit(1)
          .get();

      if (globalEnrollment.docs.isNotEmpty) {
        await _firestore
            .collection('enrollments')
            .doc(globalEnrollment.docs.first.id)
            .update({
          'completedSessions': newCompletedSessions,
          'remainingSessions': newRemainingSessions,
          'lastSessionAt': FieldValue.serverTimestamp(),
        });
      }

      // Update global enrollments collection (canonical)
      final globalEnrollmentCanonical = await _firestore
          .collection('enrollments')
          .where('enrollmentId', isEqualTo: enrollmentId)
          .limit(1)
          .get();

      if (globalEnrollmentCanonical.docs.isNotEmpty) {
        await _firestore
            .collection('enrollments')
            .doc(globalEnrollmentCanonical.docs.first.id)
            .set({
          'completedSessions': newCompletedSessions,
          'remainingSessions': newRemainingSessions,
          'lastSessionAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Create attendance record in main attendance collection
      await _firestore
          .collection(_attendanceCollection)
          .add({
        'enrollmentId': enrollmentId,
        'userId': enrollment.userId,
        'classId': classId,
        'className': className,
        'markedBy': markedBy,
        'markedByName': markedByName,
        'status': status,
        'notes': notes,
        'markedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Attendance marked successfully',
        'completedSessions': newCompletedSessions,
        'remainingSessions': newRemainingSessions,
      };
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'marking attendance');
      return {
        'success': false,
        'message': ErrorHandler.getUserFriendlyMessage(e),
      };
    }
  }

  /// Clean up stale pending_payment enrollments (older than 30 minutes)
  static Future<void> _cleanupStalePendingEnrollments(String userId, String classId) async {
    try {
      final staleCutoff = DateTime.now().subtract(const Duration(minutes: 30));
      final stalePending = await _firestore
          .collection(_enrollmentsCollection)
          .where('user_id', isEqualTo: userId)
          .where('classId', isEqualTo: classId)
          .where('status', isEqualTo: 'pending_payment')
          .get();

      for (final doc in stalePending.docs) {
        final createdAt = doc.data()['createdAt'];
        DateTime? createdTime;
        if (createdAt is Timestamp) {
          createdTime = createdAt.toDate();
        }
        if (createdTime == null || createdTime.isBefore(staleCutoff)) {
          await doc.reference.update({
            'status': 'cancelled',
            'paymentStatus': 'expired',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'cleaning up stale pending enrollments');
    }
  }

  /// Archive old completed enrollments before re-enrollment
  static Future<void> _archiveCompletedEnrollments(String userId, String classId) async {
    try {
      // Archive completed records in global enrollments collection
      final completedGlobal = await _firestore
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('itemId', isEqualTo: classId)
          .where('status', isEqualTo: 'completed')
          .get();

      for (final doc in completedGlobal.docs) {
        await doc.reference.update({
          'status': 're_enrolled',
          'archivedAt': FieldValue.serverTimestamp(),
        });
      }

      // Archive completed record in user's enrollments subcollection
      final userEnrollRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .doc(classId);
      final userEnrollDoc = await userEnrollRef.get();
      if (userEnrollDoc.exists && userEnrollDoc.data()?['status'] == 'completed') {
        await userEnrollRef.update({
          'status': 're_enrolled',
          'archivedAt': FieldValue.serverTimestamp(),
        });
      }

      // Archive completed records in canonical class_enrollments collection
      final completedCanonical = await _firestore
          .collection(_enrollmentsCollection)
          .where('user_id', isEqualTo: userId)
          .where('classId', isEqualTo: classId)
          .where('status', isEqualTo: 'completed')
          .get();

      for (final doc in completedCanonical.docs) {
        await doc.reference.update({
          'status': 're_enrolled',
          'archivedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Best-effort archival; don't block enrollment if this fails
    }
  }

  /// Get students enrolled in a class (for faculty/admin)
  static Stream<List<ClassEnrollment>> getClassEnrollments(String classId) {
    return _firestore
        .collection(_enrollmentsCollection)
        .where('classId', isEqualTo: classId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ClassEnrollment.fromMap(doc.data()))
            .toList());
  }

  /// Get enrollment statistics for admin
  static Future<Map<String, dynamic>> getEnrollmentStats() async {
    try {
      final snapshot = await _firestore
          .collection(_enrollmentsCollection)
          .get();

      int totalEnrollments = 0;
      int activeEnrollments = 0;
      int completedEnrollments = 0;
      int expiredEnrollments = 0;
      double totalRevenue = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalEnrollments++;
        
        final status = data['status'] as String? ?? 'active';
        final paymentStatus = data['paymentStatus'] as String? ?? 'pending';
        final price = (data['packagePrice'] as num?)?.toDouble() ?? 0;

        if (paymentStatus == 'paid') {
          totalRevenue += price;
        }

        switch (status) {
          case 'active':
            activeEnrollments++;
            break;
          case 'completed':
            completedEnrollments++;
            break;
          case 'expired':
            expiredEnrollments++;
            break;
        }
      }

      return {
        'totalEnrollments': totalEnrollments,
        'activeEnrollments': activeEnrollments,
        'completedEnrollments': completedEnrollments,
        'expiredEnrollments': expiredEnrollments,
        'totalRevenue': totalRevenue,
      };
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'fetching enrollment stats');
      return {
        'totalEnrollments': 0,
        'activeEnrollments': 0,
        'completedEnrollments': 0,
        'expiredEnrollments': 0,
        'totalRevenue': 0,
      };
    }
  }

  /// Check and update expired enrollments
  static Future<void> updateExpiredEnrollments() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection(_enrollmentsCollection)
          .where('status', isEqualTo: 'active')
          .get();

      final batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final endDate = (data['endDate'] as Timestamp?)?.toDate();
        
        if (endDate != null && now.isAfter(endDate)) {
          batch.update(doc.reference, {
            'status': 'expired',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'updating expired enrollments');
    }
  }

  /// Get available class packages
  static Future<List<ClassPackage>> getAvailablePackages() async {
    try {
      final snapshot = await _firestore
          .collection('class_packages')
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      if (snapshot.docs.isEmpty) {
        // Return default packages if none in Firestore
        return _getDefaultPackages();
      }

      return snapshot.docs
          .map((doc) => ClassPackage.fromMap(doc.data()))
          .toList();
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'fetching available packages');
      return _getDefaultPackages();
    }
  }

  /// Default packages if none in Firestore
  static List<ClassPackage> _getDefaultPackages() {
    return [
      ClassPackage(
        id: 'monthly_8',
        name: 'Monthly 8 Sessions',
        description: 'Perfect for regular practice',
        price: 3500,
        totalSessions: 8,
        validityDays: 30,
        features: [
          '8 dance sessions',
          'Valid for 1 month',
          'Priority booking',
          'Progress tracking',
        ],
        category: 'monthly',
        isRecommended: true,
      ),
      ClassPackage(
        id: 'monthly_12',
        name: 'Monthly 12 Sessions',
        description: 'Best value for dedicated dancers',
        price: 4800,
        totalSessions: 12,
        validityDays: 30,
        features: [
          '12 dance sessions',
          'Valid for 1 month',
          'Priority booking',
          'Progress tracking',
          'Free practice sessions',
        ],
        category: 'monthly',
        originalPrice: 6000,
      ),
      ClassPackage(
        id: 'quarterly_24',
        name: 'Quarterly 24 Sessions',
        description: 'Great for consistent learning',
        price: 10000,
        totalSessions: 24,
        validityDays: 90,
        features: [
          '24 dance sessions',
          'Valid for 3 months',
          'Priority booking',
          'Progress tracking',
          'Free practice sessions',
          'Personal feedback',
        ],
        category: 'quarterly',
        originalPrice: 12000,
      ),
      ClassPackage(
        id: 'annual_96',
        name: 'Annual 96 Sessions',
        description: 'Ultimate dance journey',
        price: 35000,
        totalSessions: 96,
        validityDays: 365,
        features: [
          '96 dance sessions',
          'Valid for 1 year',
          'Priority booking',
          'Progress tracking',
          'Free practice sessions',
          'Personal feedback',
          'Exclusive workshops',
          'Free merchandise',
        ],
        category: 'annual',
        originalPrice: 42000,
      ),
    ];
  }
}
