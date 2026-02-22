import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ClassEnrollmentExpiryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Expire all active class enrollments whose endDate has passed
  static Future<void> expireAllIfNeeded() async {
    try {
      final now = Timestamp.now();

      // Global canonical collection
      final expired = await _firestore
          .collection('class_enrollments')
          .where('status', isEqualTo: 'active')
          .where('endDate', isLessThan: now)
          .get();

      for (final doc in expired.docs) {
        final data = doc.data();
        final String userId = data['userId'] ?? data['user_id'] ?? '';
        final String classId = data['classId'] ?? data['class_id'] ?? '';
        final String className = data['className'] ?? data['class_name'] ?? 'Class';

        await doc.reference.update({
          'status': 'expired',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update user subcollections (canonical + legacy) best-effort
        if (userId.isNotEmpty && classId.isNotEmpty) {
          try {
            final userEnroll = await _firestore
                .collection('users')
                .doc(userId)
                .collection('enrollments')
                .doc(classId)
                .get();
            if (userEnroll.exists) {
              await userEnroll.reference.update({
                'status': 'expired',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error updating user enrollment status: $e');
            }
          }

          try {
            final userLegacy = await _firestore
                .collection('users')
                .doc(userId)
                .collection('enrollments')
                .doc(classId)
                .get();
            if (userLegacy.exists) {
              await userLegacy.reference.update({
                'status': 'expired',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error updating legacy user enrollment: $e');
            }
          }

          // Update global enrollments collection
          try {
            final globalEnrollment = await _firestore
                .collection('enrollments')
                .where('userId', isEqualTo: userId)
                .where('itemId', isEqualTo: classId)
                .where('status', isEqualTo: 'enrolled')
                .limit(1)
                .get();
            if (globalEnrollment.docs.isNotEmpty) {
              await globalEnrollment.docs.first.reference.update({
                'status': 'expired',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error updating global enrollment: $e');
            }
          }

          // Decrement class enrollment count atomically with all updates
          try {
            // Get global enrollment document reference first (transaction can't use queries)
            final globalEnrollment = await _firestore
                .collection('enrollments')
                .where('userId', isEqualTo: userId)
                .where('itemId', isEqualTo: classId)
                .where('status', isEqualTo: 'enrolled')
                .limit(1)
                .get();
            
            final globalEnrollRef = globalEnrollment.docs.isNotEmpty 
                ? globalEnrollment.docs.first.reference 
                : null;

            await _firestore.runTransaction((transaction) async {
              final classRef = _firestore.collection('classes').doc(classId);
              final userEnrollRef = _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('enrollments')
                  .doc(classId);
              
              // All reads first
              final classDoc = await transaction.get(classRef);
              final userEnrollDoc = await transaction.get(userEnrollRef);
              
              // All writes after reads
              if (classDoc.exists) {
                // Update class count
                transaction.update(classRef, {
                  'enrolledCount': FieldValue.increment(-1),
                  'currentBookings': FieldValue.increment(-1),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                // Update user enrollment
                if (userEnrollDoc.exists) {
                  transaction.update(userEnrollRef, {
                    'status': 'expired',
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }

                // Update global enrollment if found
                if (globalEnrollRef != null) {
                  transaction.update(globalEnrollRef, {
                    'status': 'expired',
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }
              }
            });
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error in transaction for expiring enrollment: $e');
            }
          }

          // Notification sending disabled
        }
      }

      if (kDebugMode) {
      }
    } catch (e) {
      // If index is still building, fall back to client-side filter to avoid blocking
      if (e is FirebaseException && e.code == 'failed-precondition') {
        try {
          final now = Timestamp.now();
          final activeSnap = await _firestore
              .collection('class_enrollments')
              .where('status', isEqualTo: 'active')
              .get();

          int expiredCount = 0;
          for (final doc in activeSnap.docs) {
            final data = doc.data();
            final endTs = data['endDate'];
            if (endTs is Timestamp && endTs.compareTo(now) < 0) {
              expiredCount++;
              final String userId = data['userId'] ?? data['user_id'] ?? '';
              final String classId = data['classId'] ?? data['class_id'] ?? '';

              await doc.reference.update({
                'status': 'expired',
                'updatedAt': FieldValue.serverTimestamp(),
              });

              if (userId.isNotEmpty && classId.isNotEmpty) {
                final String className = data['className'] ?? data['class_name'] ?? 'Class';

                try {
                  final userEnroll = await _firestore
                      .collection('users')
                      .doc(userId)
                      .collection('enrollments')
                      .doc(classId)
                      .get();
                  if (userEnroll.exists) {
                    await userEnroll.reference.update({
                      'status': 'expired',
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                  }
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Error updating user enrollment status in batch: $e');
                  }
                }

                try {
                  final userLegacy = await _firestore
                      .collection('users')
                      .doc(userId)
                      .collection('enrollments')
                      .doc(classId)
                      .get();
                  if (userLegacy.exists) {
                    await userLegacy.reference.update({
                      'status': 'expired',
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                  }
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Error updating legacy user enrollment in batch: $e');
                  }
                }

                // Update global enrollments collection
                try {
                  final globalEnrollment = await _firestore
                      .collection('enrollments')
                      .where('userId', isEqualTo: userId)
                      .where('itemId', isEqualTo: classId)
                      .where('status', isEqualTo: 'enrolled')
                      .limit(1)
                      .get();
                  if (globalEnrollment.docs.isNotEmpty) {
                    await globalEnrollment.docs.first.reference.update({
                      'status': 'expired',
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                  }
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Error updating global enrollment in batch: $e');
                  }
                }

                // Decrement class enrollment count atomically with all updates
                try {
                  // Get global enrollment document reference first (transaction can't use queries)
                  final globalEnrollment = await _firestore
                      .collection('enrollments')
                      .where('userId', isEqualTo: userId)
                      .where('itemId', isEqualTo: classId)
                      .where('status', isEqualTo: 'enrolled')
                      .limit(1)
                      .get();
                  
                  final globalEnrollRef = globalEnrollment.docs.isNotEmpty 
                      ? globalEnrollment.docs.first.reference 
                      : null;

                  await _firestore.runTransaction((transaction) async {
                    final classRef = _firestore.collection('classes').doc(classId);
                    final userEnrollRef = _firestore
                        .collection('users')
                        .doc(userId)
                        .collection('enrollments')
                        .doc(classId);
                    
                    // All reads first
                    final classDoc = await transaction.get(classRef);
                    final userEnrollDoc = await transaction.get(userEnrollRef);
                    
                    // All writes after reads
                    if (classDoc.exists) {
                      // Update class count
                      transaction.update(classRef, {
                        'enrolledCount': FieldValue.increment(-1),
                        'currentBookings': FieldValue.increment(-1),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      // Update user enrollment
                      if (userEnrollDoc.exists) {
                        transaction.update(userEnrollRef, {
                          'status': 'expired',
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                      }

                      // Update global enrollment if found
                      if (globalEnrollRef != null) {
                        transaction.update(globalEnrollRef, {
                          'status': 'expired',
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                      }
                    }
                  });
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('Error in batch transaction for expiring enrollment: $e');
                  }
                }

                // Notification sending disabled
              }
            }
          }
          if (kDebugMode) {
          }
        } catch (e2) {
        }
      } else {
      }
    }
  }
}


