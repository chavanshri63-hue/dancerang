part of '../home_screen.dart';

// Profile Tab
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
          );
        }

        final userData = snapshot.data?.data();
        final userRole = userData?['role'] ?? 'Student';

        // Pass the real-time role to ProfileScreen
        return ProfileScreen(role: userRole.toLowerCase());
      },
    );
  }
}

class _EnrolButton extends StatefulWidget {
  final String danceClassId;
  final String danceClassName;
  final bool isFull;
  final VoidCallback onBook;
  final String? enrollmentStatus;
  const _EnrolButton({required this.danceClassId, required this.danceClassName, required this.isFull, required this.onBook, this.enrollmentStatus});

  @override
  State<_EnrolButton> createState() => _EnrolButtonState();
}
class _EnrolButtonState extends State<_EnrolButton> {

  Widget _buildEnrollmentUI(bool enrolled, bool isCompleted) {
    if (enrolled && !isCompleted) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check_circle, size: 14),
                  label: const Text('Enrolled', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => _showExitClassDialog(widget.danceClassId, widget.danceClassName),
                  icon: const Icon(Icons.exit_to_app, size: 14),
                  label: const Text('Exit Class', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    if (isCompleted) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  label: const Text('Completed', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: widget.isFull ? null : widget.onBook,
                  icon: const Icon(Icons.replay, size: 14),
                  label: const Text('Re-join', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return ElevatedButton.icon(
      onPressed: widget.isFull ? null : widget.onBook,
      icon: const Icon(Icons.book_online, size: 16),
      label: Text(widget.isFull ? 'Full' : 'Join Now'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/login');
        },
        icon: const Icon(Icons.login, size: 16),
        label: const Text('Login to Book'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
        ),
      );
    }
    
    if (widget.enrollmentStatus != null) {
      final enrolled = widget.enrollmentStatus == 'enrolled' || widget.enrollmentStatus == 'completed';
      final isCompleted = widget.enrollmentStatus == 'completed';
      return _buildEnrollmentUI(enrolled, isCompleted);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('enrollments')
          .doc(widget.danceClassId)
          .snapshots(),
      builder: (context, userEnrollmentSnap) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
              .collection('enrollments')
          .where('userId', isEqualTo: user.uid)
          .where('itemId', isEqualTo: widget.danceClassId)
              .where('status', whereIn: ['enrolled', 'completed'])
              .limit(1)
          .snapshots(),
          builder: (context, globalEnrollmentSnap) {
            final userStatus = (userEnrollmentSnap.hasData && userEnrollmentSnap.data!.exists)
                ? (userEnrollmentSnap.data!.data()?['status'] as String?)
                : null;
            final userEnrolled = userStatus == 'enrolled' || userStatus == 'completed';
            final globalEnrolled = globalEnrollmentSnap.hasData && 
                globalEnrollmentSnap.data!.docs.isNotEmpty;
            final enrolled = userEnrolled || globalEnrolled;
            final isCompleted = userStatus == 'completed' || 
                (globalEnrollmentSnap.hasData && 
                 globalEnrollmentSnap.data!.docs.any((doc) => doc.data()['status'] == 'completed'));
        
            return _buildEnrollmentUI(enrolled, isCompleted);
          },
        );
      },
    );
  }

  void _showExitClassDialog(String classId, String className) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1B1B),
          title: const Text(
            'Exit Class',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to exit "$className"?\n\nThis action cannot be undone and you will lose access to this class.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _exitFromClass(classId, className);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Exit Class'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exitFromClass(String classId, String className) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFE53935),
          ),
        ),
      );

      // Find enrollment in global enrolments collection
      final enrollmentQuery = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('userId', isEqualTo: user.uid)
          .where('itemId', isEqualTo: classId)
          .where('status', whereIn: ['enrolled', 'completed'])
          .limit(1)
          .get();

      if (enrollmentQuery.docs.isEmpty) {
        Navigator.of(context).pop(); // Close loading
        _showErrorSnackBar('Enrollment not found');
        return;
      }

      final enrollmentDoc = enrollmentQuery.docs.first;
      final enrollmentData = enrollmentDoc.data();
      
      // Debug: Check if userId matches
      
      // Verify userId matches
      if (enrollmentData['userId'] != user.uid) {
        Navigator.of(context).pop(); // Close loading
        _showErrorSnackBar('User ID mismatch in enrollment record');
        return;
      }

      // Update enrollment status to 'unenrolled' using direct reference
      try {
        // First, ensure userId is set correctly
        await enrollmentDoc.reference.update({
          'userId': user.uid, // Ensure userId is set
          'status': 'unenrolled',
          'unenrolledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e, stackTrace) {
        ErrorHandler.handleError(e, stackTrace, context: 'updating enrollment');
        Navigator.of(context).pop(); // Close loading
        _showErrorSnackBar(ErrorHandler.getUserFriendlyMessage(e));
        return;
      }

      // Also update user's subcollection if it exists
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('enrollments')
            .doc(classId)
            .update({
          'status': 'unenrolled',
          'unenrolledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e, stackTrace) {
        ErrorHandler.handleError(e, stackTrace, context: 'updating user enrollment subcollection');
      }

      // Also update legacy class_enrollments so admin/faculty list updates
      try {
        final classEnrollments = FirebaseFirestore.instance
            .collection('class_enrollments');
        final directQuery = await classEnrollments
            .where('classId', isEqualTo: classId)
            .where('user_id', isEqualTo: user.uid)
            .where('status', isEqualTo: 'active')
            .get();
        for (final doc in directQuery.docs) {
          await doc.reference.update({
            'status': 'unenrolled',
            'unenrolledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        final directQueryAlt = await classEnrollments
            .where('classId', isEqualTo: classId)
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'active')
            .get();
        for (final doc in directQueryAlt.docs) {
          await doc.reference.update({
            'status': 'unenrolled',
            'unenrolledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        final legacyQuery = await classEnrollments
            .where('class_id', isEqualTo: classId)
            .where('user_id', isEqualTo: user.uid)
            .where('status', isEqualTo: 'active')
            .get();
        for (final doc in legacyQuery.docs) {
          await doc.reference.update({
            'status': 'unenrolled',
            'unenrolledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        final legacyQueryAlt = await classEnrollments
            .where('class_id', isEqualTo: classId)
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'active')
            .get();
        for (final doc in legacyQueryAlt.docs) {
          await doc.reference.update({
            'status': 'unenrolled',
            'unenrolledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e, stackTrace) {
        ErrorHandler.handleError(e, stackTrace, context: 'updating legacy enrollment');
      }

      // Decrement class enrollment count
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .update({
        'enrolledCount': FieldValue.increment(-1),
        'lastEnrollmentUpdate': FieldValue.serverTimestamp(),
      });

      // Trigger home stats update
      await _triggerHomeStatsUpdate(user.uid);
      
      // Emit class exit event for real-time updates
      EventController().emitEnrollmentRemoved(classId, user.uid);

      // Notification sending disabled

      // Close loading
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully exited $className'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'exiting class');
      Navigator.of(context).pop();
      _showErrorSnackBar(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  Future<void> _triggerHomeStatsUpdate(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('user_stats_triggers')
          .doc(userId)
          .set({
        'lastAttendanceUpdate': FieldValue.serverTimestamp(),
        'lastPaymentUpdate': FieldValue.serverTimestamp(),
        'userId': userId,
      }, SetOptions(merge: true));
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'triggering home stats update');
    }
  }

  /// Clean up invalid enrollments with non-existent class IDs
  Future<void> _cleanupInvalidEnrollments(String userId) async {
    try {
      final enrollmentsSnapshot = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'enrolled')
          .get();

      for (final enrollment in enrollmentsSnapshot.docs) {
        final data = enrollment.data();
        final itemId = data['itemId'];
        
        if (itemId != null && itemId.isNotEmpty && itemId != 'monthly') {
          try {
            final classDoc = await FirebaseFirestore.instance
                .collection('classes')
                .doc(itemId)
                .get();
            
            if (!classDoc.exists) {
              await enrollment.reference.update({
                'status': 'invalid',
                'invalidReason': 'Class not found',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (e, stackTrace) {
            ErrorHandler.handleError(e, stackTrace, context: 'validating enrollment class');
          }
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'cleaning up invalid enrollments');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Payment Status Card Widget with Session Tracking
/* Removed student Payment Status Card */
class _PaymentStatusCard extends StatefulWidget {
  final String? userId;

  const _PaymentStatusCard({
    this.userId,
  });

  @override
  State<_PaymentStatusCard> createState() => _PaymentStatusCardState();
}
class _PaymentStatusCardState extends State<_PaymentStatusCard> {
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;
  StreamSubscription<ClassEvent>? _classEventSubscription;
  final EventController _eventController = EventController();

  @override
  void initState() {
    super.initState();
    // Listen to payment success events for real-time updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (mounted && (event['type'] == 'payment_success' || event['type'] == 'enrollment_updated')) {
        setState(() {
          // Force rebuild when payment succeeds or enrollment updates
        });
      }
    });
    
    // Listen to class events for real-time updates (class exit, enrollment changes)
    _classEventSubscription = _eventController.eventStream.listen((event) {
      if (mounted && (event.type == ClassEventType.classDeleted || 
                     event.type == ClassEventType.enrollmentRemoved)) {
        setState(() {
          // Force rebuild when class is exited or enrollment is removed
        });
      }
    });
    
    // Clean up invalid enrollments on initialization
    if (widget.userId != null) {
      _cleanupInvalidEnrollmentsForUser(widget.userId!);
    }
  }

  @override
  void dispose() {
    _paymentRefreshSubscription?.cancel();
    _classEventSubscription?.cancel();
    super.dispose();
  }

  /// Clean up invalid enrollments with non-existent class IDs for this user
  Future<void> _cleanupInvalidEnrollmentsForUser(String userId) async {
    try {
      final enrollmentsSnapshot = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'enrolled')
          .get();

      for (final enrollment in enrollmentsSnapshot.docs) {
        final data = enrollment.data();
        final itemId = data['itemId'];
        
        if (itemId != null && itemId.isNotEmpty && itemId != 'monthly') {
          try {
            final classDoc = await FirebaseFirestore.instance
                .collection('classes')
                .doc(itemId)
                .get();
            
            if (!classDoc.exists) {
              await enrollment.reference.update({
                'status': 'invalid',
                'invalidReason': 'Class not found',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (e, stackTrace) {
            ErrorHandler.handleError(e, stackTrace, context: 'validating user enrollment class');
          }
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'cleaning up user invalid enrollments');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.userId != null
          ? FirebaseFirestore.instance
              .collection('enrollments')
              .where('userId', isEqualTo: widget.userId)
              .where('status', isEqualTo: 'enrolled')
              .orderBy('enrolledAt', descending: true)
              .snapshots()
          : null,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (snapshot.hasError) {
          return _buildErrorCard('Error loading enrollment data');
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          
          // Try multiple alternative queries
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('enrollments')
                .where('userId', isEqualTo: widget.userId)
                .where('status', isEqualTo: 'enrolled')
                .orderBy('enrolledAt', descending: true)
                .snapshots(),
            builder: (context, altSnapshot) {
              if (altSnapshot.hasData && altSnapshot.data!.docs.isNotEmpty) {
                final enrollment = altSnapshot.data!.docs.first;
                final enrollmentData = enrollment.data();
                
                
                final className = enrollmentData['className'] ?? 'Class';
                final totalSessions = enrollmentData['totalSessions'] ?? 8;
                final completedSessions = enrollmentData['completedSessions'] ?? 0;
                final remainingSessions = enrollmentData['remainingSessions'] ?? (totalSessions - completedSessions);
                final packagePrice = enrollmentData['packagePrice'] ?? 0.0;
                final paymentStatus = enrollmentData['paymentStatus'] ?? 'paid';
                final endDate = (enrollmentData['endDate'] as Timestamp?)?.toDate();
                final lastAttendanceDate = (enrollmentData['lastAttendanceDate'] as Timestamp?)?.toDate();
                
                
                return _buildPaymentCard(
                  context,
                  className: className,
                  completedSessions: completedSessions,
                  totalSessions: totalSessions,
                  remainingSessions: remainingSessions,
                  packagePrice: packagePrice,
                  paymentStatus: paymentStatus,
                  endDate: endDate,
                  lastAttendanceDate: lastAttendanceDate,
                  enrollmentId: enrollment.id,
                );
              }
              
              // Try class_enrollments collection as final fallback
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('class_enrollments')
                    .where('userId', isEqualTo: widget.userId)
                    .where('status', isEqualTo: 'active')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, classEnrollmentSnapshot) {
                  if (classEnrollmentSnapshot.hasData && classEnrollmentSnapshot.data!.docs.isNotEmpty) {
                    final enrollment = classEnrollmentSnapshot.data!.docs.first;
                    final enrollmentData = enrollment.data();
                    
                    final className = enrollmentData['className'] ?? 'Class';
                    final totalSessions = enrollmentData['totalSessions'] ?? 8;
                    final completedSessions = enrollmentData['completedSessions'] ?? 0;
                    final remainingSessions = enrollmentData['remainingSessions'] ?? (totalSessions - completedSessions);
                    final packagePrice = enrollmentData['packagePrice'] ?? 0.0;
                    final paymentStatus = enrollmentData['paymentStatus'] ?? 'paid';
                    final endDate = (enrollmentData['endDate'] as Timestamp?)?.toDate();
                    final lastAttendanceDate = (enrollmentData['lastAttendanceDate'] as Timestamp?)?.toDate();
                    
                    return _buildPaymentCard(
                      context,
                      className: className,
                      completedSessions: completedSessions,
                      totalSessions: totalSessions,
                      remainingSessions: remainingSessions,
                      packagePrice: packagePrice,
                      paymentStatus: paymentStatus,
                      endDate: endDate,
                      lastAttendanceDate: lastAttendanceDate,
                      enrollmentId: enrollment.id,
                    );
                  }
                  
                  return _buildNoClassesCard();
                },
              );
            },
          );
        }

        // Get the most recent active enrollment (already sorted by orderBy)
        final enrollments = snapshot.data!.docs;
        if (enrollments.isEmpty) {
          return _buildNoClassesCard();
        }

        // Filter out monthly packages and invalid enrollments
        final validEnrollments = enrollments.where((enrollment) {
          final data = enrollment.data();
          final itemId = data['itemId'];
          final itemType = data['itemType'];
          final status = data['status'];
          
          // Skip monthly packages and invalid enrollments
          if (itemId == 'monthly' || itemId == null) {
            return false;
          }
          
          // Only include actual class enrollments with 'enrolled' status (exclude invalid)
          final isValid = itemType == 'class' && 
                         itemId != null && 
                         itemId.isNotEmpty && 
                         status == 'enrolled' &&
                         status != 'invalid';
          
          if (!isValid) {
          }
          
          return isValid;
        }).toList();
        
        // Note: Invalid enrollment cleanup is handled in _cleanupInvalidEnrollmentsForUser()

        if (validEnrollments.isEmpty) {
          return _buildNoClassesCard();
        }

        final enrollment = validEnrollments.first;
        final enrollmentData = enrollment.data();


                // Extract enrollment data directly from enrolments collection
                final className = enrollmentData['itemType'] == 'class' 
                    ? (enrollmentData['className'] ?? enrollmentData['title'] ?? 'Class')
                    : (enrollmentData['title'] ?? enrollmentData['className'] ?? 'Class');
                
                // If className is still "Unknown Class", try to get actual class name
                String actualClassName = className;
                if (className == 'Unknown Class' || className == 'Class') {
                  // Try to get class name from actual class document
                  final itemId = enrollmentData['itemId'];
                  if (itemId != null && itemId != 'monthly') {
                    // This is a real class ID, fetch the actual class name
                    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance
                          .collection('classes')
                          .doc(itemId)
                          .get(),
                      builder: (context, classSnapshot) {
                        
                        if (classSnapshot.hasData && classSnapshot.data!.exists) {
                          final classData = classSnapshot.data!.data()!;
                          final realClassName = classData['name'] ?? classData['title'] ?? 'Class';
                          
                          return _buildPaymentCard(
                            context,
                            className: realClassName,
                            completedSessions: enrollmentData['completedSessions'] ?? 0,
                            totalSessions: enrollmentData['totalSessions'] ?? 8,
                            remainingSessions: (enrollmentData['totalSessions'] ?? 8) - (enrollmentData['completedSessions'] ?? 0),
                            packagePrice: (enrollmentData['amount'] ?? 0).toDouble(),
                            paymentStatus: enrollmentData['paymentStatus'] ?? 'paid',
                            endDate: (enrollmentData['endDate'] as Timestamp?)?.toDate(),
                            lastAttendanceDate: (enrollmentData['lastSessionAt'] as Timestamp?)?.toDate(),
                            enrollmentId: enrollment.id,
                          );
                        } else {
                          // Class document not found - show fallback
                          
                          // Try to find correct class ID from available classes
                          return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            future: FirebaseFirestore.instance
                                .collection('classes')
                                .where('isAvailable', isEqualTo: true)
                                .limit(1)
                                .get(),
                            builder: (context, classesSnapshot) {
                              if (classesSnapshot.hasData && classesSnapshot.data!.docs.isNotEmpty) {
                                final classDoc = classesSnapshot.data!.docs.first;
                                final classData = classDoc.data();
                                final correctClassName = classData['name'] ?? 'Class';
                                
                                return _buildPaymentCard(
                                  context,
                                  className: correctClassName,
                                  completedSessions: enrollmentData['completedSessions'] ?? 0,
                                  totalSessions: enrollmentData['totalSessions'] ?? 8,
                                  remainingSessions: (enrollmentData['totalSessions'] ?? 8) - (enrollmentData['completedSessions'] ?? 0),
                                  packagePrice: (enrollmentData['amount'] ?? 0).toDouble(),
                                  paymentStatus: enrollmentData['paymentStatus'] ?? 'paid',
                                  endDate: (enrollmentData['endDate'] as Timestamp?)?.toDate(),
                                  lastAttendanceDate: (enrollmentData['lastSessionAt'] as Timestamp?)?.toDate(),
                                  enrollmentId: enrollment.id,
                                );
                              }
                              
                              return _buildPaymentCard(
                                context,
                                className: 'Enrolled Class',
                                completedSessions: enrollmentData['completedSessions'] ?? 0,
                                totalSessions: enrollmentData['totalSessions'] ?? 8,
                                remainingSessions: (enrollmentData['totalSessions'] ?? 8) - (enrollmentData['completedSessions'] ?? 0),
                                packagePrice: (enrollmentData['amount'] ?? 0).toDouble(),
                                paymentStatus: enrollmentData['paymentStatus'] ?? 'paid',
                                endDate: (enrollmentData['endDate'] as Timestamp?)?.toDate(),
                                lastAttendanceDate: (enrollmentData['lastSessionAt'] as Timestamp?)?.toDate(),
                                enrollmentId: enrollment.id,
                              );
                            },
                          );
                          
                          // Try to find class by name or use fallback
                          return _buildPaymentCard(
                            context,
                            className: 'Enrolled Class',
                            completedSessions: enrollmentData['completedSessions'] ?? 0,
                            totalSessions: enrollmentData['totalSessions'] ?? 8,
                            remainingSessions: (enrollmentData['totalSessions'] ?? 8) - (enrollmentData['completedSessions'] ?? 0),
                            packagePrice: (enrollmentData['amount'] ?? 0).toDouble(),
                            paymentStatus: enrollmentData['paymentStatus'] ?? 'paid',
                            endDate: (enrollmentData['endDate'] as Timestamp?)?.toDate(),
                            lastAttendanceDate: (enrollmentData['lastSessionAt'] as Timestamp?)?.toDate(),
                            enrollmentId: enrollment.id,
                          );
                        }
                      },
                    );
                  } else {
                    actualClassName = 'Package Enrollment'; // For monthly packages
                  }
                }
                final totalSessions = enrollmentData['totalSessions'] ?? 8;
                final completedSessions = enrollmentData['completedSessions'] ?? 0;
                final remainingSessions = totalSessions - completedSessions;
                final packagePrice = (enrollmentData['amount'] ?? 0).toDouble();
                final paymentStatus = enrollmentData['paymentStatus'] ?? 'paid';
                final endDate = (enrollmentData['endDate'] as Timestamp?)?.toDate();
                final lastAttendanceDate = (enrollmentData['lastSessionAt'] as Timestamp?)?.toDate();
        
        return _buildPaymentCard(
          context,
          className: actualClassName,
          completedSessions: completedSessions,
          totalSessions: totalSessions,
          remainingSessions: remainingSessions,
          packagePrice: packagePrice,
          paymentStatus: paymentStatus,
          endDate: endDate,
          lastAttendanceDate: lastAttendanceDate,
          enrollmentId: enrollment.id,
        );
      },
    );
  }


  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(width: 16),
          Text(
            'Loading payment status...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoClassesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B7280), Color(0xFF9CA3AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.school_outlined, color: Colors.white, size: 24),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'No active enrollments',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(
    BuildContext context, {
    required String className,
    required int completedSessions,
    required int totalSessions,
    required int remainingSessions,
    required double packagePrice,
    required String paymentStatus,
    DateTime? endDate,
    DateTime? lastAttendanceDate,
    required String enrollmentId,
  }) {
    final progress = totalSessions > 0 ? completedSessions / totalSessions : 0.0;
    final isPaymentDue = remainingSessions <= 1 || (endDate != null && DateTime.now().isAfter(endDate));
    final isExpired = endDate != null && DateTime.now().isAfter(endDate);
    final needsPayment = paymentStatus == 'pending' || paymentStatus == 'failed';

    return Card(
      color: context != null ? Theme.of(context!).cardColor : const Color(0xFF1F2937),
      elevation: 8,
      shadowColor: (isPaymentDue ? const Color(0xFFDC2626) : const Color(0xFF374151)).withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: (isPaymentDue ? const Color(0xFFDC2626) : const Color(0xFF374151)).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context != null ? Theme.of(context!).cardColor : const Color(0xFF1F2937),
              context != null ? Theme.of(context!).cardColor.withValues(alpha: 0.8) : const Color(0xFF374151),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPaymentDue ? Icons.warning_rounded : Icons.school_rounded,
                      color: isPaymentDue ? const Color(0xFFDC2626) : const Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isPaymentDue ? 'Payment Due!' : 'Payment Status',
                    style: const TextStyle(
                      color: Color(0xFFF9FAFB),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                className,
                style: const TextStyle(
                  color: Color(0xFFF9FAFB),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$completedSessions/$totalSessions sessions completed',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: (isPaymentDue ? const Color(0xFFDC2626) : const Color(0xFF3B82F6)).withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isPaymentDue ? const Color(0xFFDC2626) : const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPaymentDue 
                              ? 'Payment due: ₹${packagePrice.toInt()}'
                              : '$remainingSessions sessions left',
                          style: const TextStyle(
                            color: Color(0xFFF9FAFB),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (endDate != null)
                          Text(
                            isExpired 
                                ? 'Expired: ${_formatDate(endDate)}'
                                : 'Valid until: ${_formatDate(endDate)}',
                            style: TextStyle(
                              color: isExpired ? const Color(0xFFDC2626) : const Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                        if (lastAttendanceDate != null)
                          Text(
                            'Last attended: ${_formatDate(lastAttendanceDate)}',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isPaymentDue && context != null)
                    ElevatedButton(
                      onPressed: () => _handlePayment(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Pay Now',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference < 7) return 'In $difference days';
    if (difference < 30) return 'In ${(difference / 7).round()} weeks';
    return 'In ${(difference / 30).round()} months';
  }

  void _handlePayment(BuildContext context) async {
    // Navigate to payment screen or show payment dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Redirecting to payment...'),
        backgroundColor: Colors.orange,
      ),
    );
    
    // TODO: Navigate to payment screen with enrollment details
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (context) => PaymentScreen(enrollmentId: enrollmentId),
    // ));
  }
}

// Admin Stats Card Widget
class _AdminStatsCard extends StatefulWidget {
  final String? userId;

  const _AdminStatsCard({
    this.userId,
  });

  @override
  State<_AdminStatsCard> createState() => _AdminStatsCardState();
}

class _AdminStatsCardState extends State<_AdminStatsCard> {
  final EventController _eventController = EventController();
  StreamSubscription<ClassEvent>? _eventSubscription;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    // Listen to class events and refresh stats card
    _eventSubscription = _eventController.eventStream.listen((event) {
      if (mounted) {
        setState(() {
          _refreshKey++;
        });
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: ValueKey(_refreshKey),
      stream: widget.userId != null
          ? FirebaseFirestore.instance
              .collection('users')
              .snapshots()
          : null,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (!snapshot.hasData) {
          return _buildNoDataCard();
        }

        if (snapshot.hasError) {
          return _buildNoDataCard();
        }

        final users = snapshot.data!.docs;
        final totalStudents = users.where((doc) {
          final role = (doc.data()['role'] ?? '').toString().toLowerCase();
          return role == 'student';
        }).length;
        final totalFaculty = users.where((doc) {
          final role = (doc.data()['role'] ?? '').toString().toLowerCase();
          return role == 'faculty';
        }).length;
        
        // Get real active classes count
        return FutureBuilder<int>(
          future: _getActiveClassesCount(),
          builder: (context, classesSnapshot) {
            final activeClasses = classesSnapshot.data ?? 0;
            
            // Get real pending tasks count
            return FutureBuilder<int>(
              future: _getPendingTasksCount(),
              builder: (context, tasksSnapshot) {
                final pendingTasks = tasksSnapshot.data ?? 0;
                
                return _buildAdminCard(
                  context,
                  totalStudents: totalStudents,
                  totalFaculty: totalFaculty,
                  activeClasses: activeClasses,
                  pendingTasks: pendingTasks,
                );
              },
            );
          },
        );
      },
    );
  }


  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF374151), width: 1.5),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      ),
    );
  }

  Widget _buildNoDataCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF374151), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            color: const Color(0xFF8B5CF6),
            size: 24,
          ),
          const SizedBox(height: 8),
          const Text(
            'No Data Available',
            style: TextStyle(
              color: Color(0xFFF9FAFB),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Data will appear once users are added',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<int> _getActiveClassesCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('isAvailable', isEqualTo: true)
          .get();
      return snapshot.docs.length;
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'fetching available classes count');
      return 0;
    }
  }

  Future<int> _getPendingTasksCount() async {
    try {
      // Count pending attendance approvals
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('status', isEqualTo: 'pending')
          .get();
      
      // Count pending workshop approvals
      final workshopSnapshot = await FirebaseFirestore.instance
          .collection('workshops')
          .where('status', isEqualTo: 'pending')
          .get();
      
  // Count pending banner approvals
      final bannerSnapshot = await FirebaseFirestore.instance
          .collection('banners')
          .where('status', isEqualTo: 'pending')
          .get();
  
  // Count pending cash payments
  int cashCount = 0;
  try {
    final cashSnapshot = await FirebaseFirestore.instance
        .collection('approvals')
        .where('status', isEqualTo: 'pending')
        .where('type', isEqualTo: 'cash_payment')
        .get();
    cashCount = cashSnapshot.docs.length;
  } catch (e, stackTrace) {
    ErrorHandler.handleError(e, stackTrace, context: 'fetching pending cash payments');
  }
      
      return attendanceSnapshot.docs.length + 
             workshopSnapshot.docs.length + 
             bannerSnapshot.docs.length +
             cashCount;
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'fetching pending tasks count');
      return 0;
    }
  }

  Widget _buildAdminCard(
    BuildContext? context, {
    required int totalStudents,
    required int totalFaculty,
    required int activeClasses,
    required int pendingTasks,
  }) {
    return Card(
      color: context != null ? Theme.of(context!).cardColor : const Color(0xFF1F2937),
      elevation: 8,
      shadowColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context != null ? Theme.of(context!).cardColor : const Color(0xFF1F2937),
              context != null ? Theme.of(context!).cardColor.withValues(alpha: 0.8) : const Color(0xFF374151),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      color: Color(0xFFF9FAFB),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Students: $totalStudents',
                          style: const TextStyle(
                            color: Color(0xFFF9FAFB),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Faculty: $totalFaculty',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Classes: $activeClasses',
                          style: const TextStyle(
                            color: Color(0xFFF9FAFB),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pending: $pendingTasks',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (totalStudents + totalFaculty) / 200, // Assuming max 200 total users
                backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Compact Icon Grid Widget
Widget _buildCompactIconGrid(BuildContext context, String role) {
  // For student role: align Attendance with Workshops (left), Payment with Updates (right)
  // For faculty role: align Attendance with Workshops (left), Students with Updates (right)
  // For admin: move icons slightly to the right
  if (role == 'student') {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Attendance icon aligned with Workshops card (left column) - moved more left
        Expanded(
            child: Transform.translate(
              offset: const Offset(-8, 0), // Move Attendance icon to the left
          child: _buildCompactAttendanceIcon(
            context: context,
            userId: FirebaseAuth.instance.currentUser?.uid,
          ),
        ),
          ),
          const SizedBox(width: 12), // Match grid crossAxisSpacing
          // Payment icon aligned with Updates card (right column) - moved a bit right
        Expanded(
            child: Transform.translate(
              offset: const Offset(8, 0), // Move Payment icon to the right
          child: _buildCompactIconItem(
            context: context,
            title: 'Payment',
            icon: Icons.payment_rounded,
            color: const Color(0xFFF59E0B),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PaymentHistoryScreen(),
              ),
            ),
          ),
        ),
          ),
        ],
      ),
    );
  } else if (role == 'faculty') {
    // For faculty: align Attendance with Workshops (left), Students with Updates (right)
    // Build items directly without Expanded wrapper to avoid nesting
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Attendance icon aligned with Workshops card (left column) - moved more left
        Expanded(
            child: Transform.translate(
              offset: const Offset(-8, 0), // Move Attendance icon to the left
          child: _buildCompactIconItem(
            context: context,
            title: 'Attendance',
            icon: Icons.qr_code_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QRScannerScreen(),
              ),
            ),
          ),
        ),
          ),
          const SizedBox(width: 12), // Match grid crossAxisSpacing
          // Students icon aligned with Updates card (right column) - moved a bit right
        Expanded(
            child: Transform.translate(
              offset: const Offset(8, 0), // Move Students icon to the right
          child: _buildCompactIconItem(
            context: context,
            title: 'Students',
            icon: Icons.people_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentManagementScreen(),
              ),
            ),
          ),
        ),
          ),
        ],
      ),
    );
  } else {
    // For admin: move icons slightly to the right
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.only(left: 20), // Shift right
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: _getCompactIconItems(context, role),
      ),
    );
  }
}
List<Widget> _getCompactIconItems(BuildContext context, String role) {
  switch (role) {
    case 'student':
      return [
        Expanded(
          child: _buildCompactAttendanceIcon(
            context: context,
            userId: FirebaseAuth.instance.currentUser?.uid,
          ),
        ),
        Expanded(
          child: _buildCompactIconItem(
            context: context,
            title: 'Payment',
            icon: Icons.payment_rounded,
            color: const Color(0xFFF59E0B),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PaymentHistoryScreen(),
              ),
            ),
          ),
        ),
      ];
    case 'faculty':
      return [
        Expanded(
          child: _buildCompactIconItem(
            context: context,
            title: 'Attendance',
            icon: Icons.qr_code_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QRScannerScreen(),
              ),
            ),
          ),
        ),
        Expanded(
          child: _buildCompactIconItem(
            context: context,
            title: 'Students',
            icon: Icons.people_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentManagementScreen(),
              ),
            ),
          ),
        ),
      ];
    case 'admin':
      return [
        Expanded(
          child: _buildCompactIconItem(
            context: context,
            title: 'Attendance',
            icon: Icons.qr_code_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttendanceScreen(role: 'admin'),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildCompactIconItem(
            context: context,
            title: 'Students',
            icon: Icons.people_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentManagementScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildCompactIconItem(
            context: context,
            title: 'Reports',
            icon: Icons.analytics_rounded,
            color: const Color(0xFFF59E0B),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminLiveDashboard(),
              ),
            ),
          ),
        ),
      ];
    default:
      return [];
  }
}

// Real-time attendance icon with session tracking
Widget _buildCompactAttendanceIcon({
  required BuildContext context,
  required String? userId,
}) {
  if (userId == null) {
    return _buildCompactIconItem(
      context: context,
      title: 'Attendance',
      icon: Icons.qr_code_rounded,
      color: const Color(0xFF3B82F6),
      onTap: () {},
    );
  }

  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('enrollments')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'enrolled')
        .orderBy('enrolledAt', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      int totalSessions = 0;
      int completedSessions = 0;
      bool hasActiveEnrollment = false;

      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
        hasActiveEnrollment = true;
        for (final doc in snapshot.data!.docs) {
          final data = doc.data();
          totalSessions += (data['totalSessions'] ?? 0) as int;
          completedSessions += (data['completedSessions'] ?? 0) as int;
        }
      } else {
        // Try alternative query with userId field
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('enrollments')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'enrolled')
              .orderBy('enrolledAt', descending: true)
              .snapshots(),
          builder: (context, altSnapshot) {
            int altTotalSessions = 0;
            int altCompletedSessions = 0;
            bool altHasActiveEnrollment = false;

            if (altSnapshot.hasData && altSnapshot.data!.docs.isNotEmpty) {
              altHasActiveEnrollment = true;
              for (final doc in altSnapshot.data!.docs) {
                final data = doc.data();
                altTotalSessions += (data['totalSessions'] ?? 0) as int;
                altCompletedSessions += (data['completedSessions'] ?? 0) as int;
              }
            }

            final altProgress = altTotalSessions > 0 ? (altCompletedSessions / altTotalSessions) : 0.0;
            final altRemainingSessions = altTotalSessions - altCompletedSessions;

            return _buildCompactIconItem(
              context: context,
              title: altHasActiveEnrollment ? 'Attendance\n$altCompletedSessions/$altTotalSessions' : 'Attendance',
              icon: Icons.qr_code_rounded,
              color: altHasActiveEnrollment 
                  ? (altRemainingSessions <= 2 ? const Color(0xFFEF4444) : const Color(0xFF3B82F6))
                  : const Color(0xFF6B7280),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QRDisplayScreen(role: 'student'),
                ),
              ),
              badge: altHasActiveEnrollment && altRemainingSessions <= 2 ? altRemainingSessions.toString() : null,
            );
          },
        );
      }

      final progress = totalSessions > 0 ? (completedSessions / totalSessions) : 0.0;
      final remainingSessions = totalSessions - completedSessions;

      return _buildCompactIconItem(
        context: context,
        title: hasActiveEnrollment ? 'Attendance\n$completedSessions/$totalSessions' : 'Attendance',
        icon: Icons.qr_code_rounded,
        color: hasActiveEnrollment 
            ? (remainingSessions <= 2 ? const Color(0xFFEF4444) : const Color(0xFF3B82F6))
            : const Color(0xFF6B7280),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QRDisplayScreen(role: 'student'),
          ),
        ),
        badge: hasActiveEnrollment && remainingSessions <= 2 ? remainingSessions.toString() : null,
      );
    },
  );
}

Widget _buildCompactIconItem({
  required BuildContext context,
  required String title,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
  String? badge,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Stack(
      children: [
        Container(
          height: 64, // Fixed height for consistent sizing
          width: double.infinity, // Take full width of Expanded parent
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                title,
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (badge != null)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              constraints: const BoxConstraints(
                minWidth: 14,
                minHeight: 14,
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    ),
  );
}

// Style Management Modal
class _StyleManagementModal extends StatefulWidget {
  final List<String> categories;
  final VoidCallback onCategoriesUpdated;

  const _StyleManagementModal({
    required this.categories,
    required this.onCategoriesUpdated,
  });

  @override
  State<_StyleManagementModal> createState() => _StyleManagementModalState();
}

class _StyleManagementModalState extends State<_StyleManagementModal> {
  final TextEditingController _newStyleController = TextEditingController();
  final TextEditingController _editStyleController = TextEditingController();
  String? _editingStyle;
  bool _isLoading = false;

  @override
  void dispose() {
    _newStyleController.dispose();
    _editStyleController.dispose();
    super.dispose();
  }

  Future<void> _addNewStyle() async {
    final styleName = _newStyleController.text.trim();
    if (styleName.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final newStyle = DanceStyle(
        id: '', // Will be set by Firestore
        name: styleName,
        description: '',
        icon: 'directions_run',
        color: '#E53935',
        isActive: true,
        priority: 0,
        createdAt: now,
        updatedAt: now,
      );
      
      await ClassStylesService.addStyle(newStyle);
      _newStyleController.clear();
      widget.onCategoriesUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Style added successfully!'),
            backgroundColor: Color(0xFFE53935),
          ),
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'adding dance style');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editStyle(String oldName, String newName) async {
    if (newName.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Find the style by name and update it
      final styles = await ClassStylesService.getAllStylesForAdmin();
      final styleToUpdate = styles.firstWhere(
        (style) => style.name == oldName,
        orElse: () => throw Exception('Style not found'),
      );
      
      final updatedStyle = DanceStyle(
        id: styleToUpdate.id,
        name: newName,
        description: styleToUpdate.description,
        icon: styleToUpdate.icon,
        color: styleToUpdate.color,
        isActive: styleToUpdate.isActive,
        priority: styleToUpdate.priority,
        createdAt: styleToUpdate.createdAt,
        updatedAt: DateTime.now(),
      );
      
      await ClassStylesService.updateStyle(styleToUpdate.id, updatedStyle);
      
      _editStyleController.clear();
      if (!mounted) return;
      setState(() {
        _editingStyle = null;
      });
      widget.onCategoriesUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Style updated successfully!'),
            backgroundColor: Color(0xFFE53935),
          ),
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'updating dance style');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteStyle(String styleName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text(
          'Delete Style',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "$styleName"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await ClassStylesService.deleteStyle(styleName);
        widget.onCategoriesUpdated();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Style deleted successfully!'),
              backgroundColor: Color(0xFFE53935),
            ),
          );
        }
      } catch (e, stackTrace) {
        ErrorHandler.handleError(e, stackTrace, context: 'deleting dance style');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ErrorHandler.getUserFriendlyMessage(e)),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B1B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Manage Dance Styles',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),
          // Add new style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newStyleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Add new dance style...',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE53935)),
                      ),
                    ),
                    onSubmitted: (_) => _addNewStyle(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _addNewStyle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.add),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Styles list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.categories.length,
              itemBuilder: (context, index) {
                final style = widget.categories[index];
                final isEditing = _editingStyle == style;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: const Color(0xFF2A2A2A),
                  child: ListTile(
                    title: isEditing
                        ? TextField(
                            controller: _editStyleController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white30),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFE53935)),
                              ),
                            ),
                            onSubmitted: (value) => _editStyle(style, value),
                          )
                        : Text(
                            style,
                            style: const TextStyle(color: Colors.white),
                          ),
                    trailing: isEditing
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _editStyle(style, _editStyleController.text),
                                icon: const Icon(Icons.check, color: Colors.green),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _editingStyle = null;
                                    _editStyleController.clear();
                                  });
                                },
                                icon: const Icon(Icons.close, color: Colors.red),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _editingStyle = style;
                                    _editStyleController.text = style;
                                  });
                                },
                                icon: const Icon(Icons.edit, color: Color(0xFFE53935)),
                              ),
                              IconButton(
                                onPressed: () => _deleteStyle(style),
                                icon: const Icon(Icons.delete, color: Colors.red),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Subscription Plans Bottom Sheet
class _SubscriptionPlansBottomSheet extends StatefulWidget {
  const _SubscriptionPlansBottomSheet();

  @override
  State<_SubscriptionPlansBottomSheet> createState() => _SubscriptionPlansBottomSheetState();
}
class _SubscriptionPlansBottomSheetState extends State<_SubscriptionPlansBottomSheet> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B1B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.subscriptions, color: Color(0xFFE53935), size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Choose Your Plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),
          // Plans list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('subscription_plans')
                  .where('active', isEqualTo: true)
                  .orderBy('priority')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
                }

                final plans = snapshot.data?.docs ?? [];
                if (plans.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.subscriptions, size: 64, color: Color(0xFF6B7280)),
                        SizedBox(height: 16),
                        Text(
                          'No subscription plans available',
                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final plan = plans[index].data();
                    final planId = plans[index].id;
                    return _SubscriptionPlanCard(
                      planId: planId,
                      name: plan['name'] ?? 'Plan',
                      price: plan['price'] ?? 0,
                      billingCycle: plan['billingCycle'] ?? 'monthly',
                      description: plan['description'] ?? '',
                      priority: plan['priority'] ?? 0,
                      trialDays: plan['trialDays'] ?? 0,
                      onSubscribe: () => _handleSubscribe(planId, plan),
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

  Future<void> _handleSubscribe(String planId, Map<String, dynamic> plan) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Please login to subscribe');
        return;
      }

      final amount = (plan['price'] as num).toInt();
      final name = plan['name'] ?? 'Subscription Plan';
      final billingCycle = plan['billingCycle'] ?? 'monthly';
      final explicitProductId = (plan['storeProductId'] ??
              plan['productId'] ??
              plan['playProductId'] ??
              plan['appStoreProductId'])
          ?.toString();
      final productId = IapService.resolveProductId(
        billingCycle: billingCycle.toString(),
        explicitId: explicitProductId,
        planId: planId,
      );

      if (productId.isEmpty) {
        _showError('Subscription product is not configured yet.');
        return;
      }

      final result = await IapService.instance.purchaseSubscription(
        productId: productId,
        metadata: {
          'planId': planId,
          'planName': name,
          'billingCycle': billingCycle,
          'amount': amount,
        },
      );

      if (result['success'] == true) {
        _showSuccess('Complete the purchase to activate your subscription.');
        Navigator.pop(context);
        // Force refresh of the online screen
        if (mounted) {
          setState(() {
            // This will trigger a rebuild of the online screen
          });
        }
      } else {
        _showError(result['message'] ?? 'Payment failed');
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'processing payment');
      _showError(ErrorHandler.getUserFriendlyMessage(e));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SubscriptionPlanCard extends StatelessWidget {
  final String planId;
  final String name;
  final int price;
  final String billingCycle;
  final String description;
  final int priority;
  final int trialDays;
  final VoidCallback onSubscribe;

  const _SubscriptionPlanCard({
    required this.planId,
    required this.name,
    required this.price,
    required this.billingCycle,
    required this.description,
    required this.priority,
    required this.trialDays,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final isPopular = priority == 1;
    final cycleText = billingCycle == 'annual' ? 'year' : 
                     billingCycle == 'quarterly' ? 'quarter' : 'month';

    return Card(
      elevation: isPopular ? 8 : 4,
      shadowColor: isPopular ? const Color(0xFFE53935).withOpacity(0.3) : const Color(0xFF4F46E5).withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPopular ? const Color(0xFFE53935).withOpacity(0.5) : const Color(0xFF4F46E5).withOpacity(0.22),
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Container(
        decoration: isPopular ? BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFE53935).withOpacity(0.1),
              const Color(0xFF4F46E5).withOpacity(0.05),
            ],
          ),
        ) : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isPopular)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'POPULAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '₹$price',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/$cycleText',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              if (trialDays > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '$trialDays days free trial',
                  style: TextStyle(
                    color: const Color(0xFF10B981),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular ? const Color(0xFFE53935) : const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Subscribe Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Subscription Plans Dialog
class _SubscriptionPlansDialog extends StatefulWidget {
  const _SubscriptionPlansDialog();

  @override
  State<_SubscriptionPlansDialog> createState() => _SubscriptionPlansDialogState();
}

class _SubscriptionPlansDialogState extends State<_SubscriptionPlansDialog> {
  bool _isMonthlyLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.subscriptions,
                    color: Color(0xFFE53935),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Choose Your Plan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Unlock all online dance videos',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              
              // Monthly Plan (single plan)
              _PlanCard(
                name: 'Monthly Plan',
                price: 900,
                cycle: 'month',
                description: 'Access all videos for 1 month',
                isPopular: true,
                onSubscribe: _handleSubscribe,
                isLoading: _isMonthlyLoading,
              ),
              
              const SizedBox(height: 16),
              
              // Features
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 8),
                        Text('Unlimited video access', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 8),
                        Text('HD quality videos', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 8),
                        Text('Offline downloads', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 8),
                        Text('Auto-renewal', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubscribe() async {
    if (_isMonthlyLoading) return;
    setState(() {
      _isMonthlyLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Please login to subscribe');
        return;
      }
      final result = await OnlineSubscriptionService.purchaseMonthly();

      if (result['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Subscription activated successfully.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        _showError(result['message'] ?? 'Subscription failed. Please try again.');
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'processing subscription');
      _showError(ErrorHandler.getUserFriendlyMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _isMonthlyLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
      ),
    );
  }
}

// Individual Plan Card
class _PlanCard extends StatelessWidget {
  final String name;
  final int price;
  final String cycle;
  final String description;
  final bool isPopular;
  final VoidCallback onSubscribe;
  final bool isLoading;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.cycle,
    required this.description,
    required this.isPopular,
    required this.onSubscribe,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isPopular ? const Color(0xFFE53935).withOpacity(0.1) : const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? const Color(0xFFE53935).withOpacity(0.5) : const Color(0xFF4F46E5).withOpacity(0.3),
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'BEST VALUE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '₹$price',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/$cycle',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSubscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPopular ? const Color(0xFFE53935) : const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Subscribe for ₹$price',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
/* Removed Today's Stats Card for Students */
class _TodayStatsCard extends StatelessWidget {
  final String? userId;

  const _TodayStatsCard({this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 6,
      shadowColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
      color: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.today_rounded,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Today\'s Overview',
                  style: TextStyle(
                    color: Color(0xFFF9FAFB),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('enrollments')
                  .where('userId', isEqualTo: userId)
                  .where('status', isEqualTo: 'enrolled')
                  .snapshots(),
              builder: (context, enrollmentSnapshot) {
                if (enrollmentSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF3B82F6),
                      strokeWidth: 2,
                    ),
                  );
                }

                if (!enrollmentSnapshot.hasData || enrollmentSnapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No enrolled classes today',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                final enrollments = enrollmentSnapshot.data!.docs;
                // Filter for class enrollments only (client-side filtering)
                final classEnrollments = enrollments
                    .where((doc) => doc.data()['itemType'] == 'class')
                    .toList();
                final classIds = classEnrollments.map((doc) => doc.data()['itemId'] as String).toList();

                // Handle empty classIds to avoid whereIn error
                if (classIds.isEmpty) {
                  return const Center(
                    child: Text(
                      'No enrolled classes today',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('classes')
                      .where(FieldPath.documentId, whereIn: classIds)
                      .where('isAvailable', isEqualTo: true)
                      .snapshots(),
                  builder: (context, classesSnapshot) {
                    if (classesSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF3B82F6),
                          strokeWidth: 2,
                        ),
                      );
                    }

                    final classes = classesSnapshot.data?.docs ?? [];
                    final today = DateTime.now();
                    final todayClasses = classes.where((classDoc) {
                      final data = classDoc.data();
                      final dateTime = data['dateTime'] as Timestamp?;
                      if (dateTime != null) {
                        final classDate = dateTime.toDate();
                        return classDate.year == today.year &&
                               classDate.month == today.month &&
                               classDate.day == today.day;
                      }
                      return false;
                    }).toList();

                    final todayClassIds = todayClasses.map((doc) => doc.id).toList();

                    // Handle empty todayClassIds to avoid whereIn error
                    if (todayClassIds.isEmpty) {
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enrolled Today',
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '0',
                                  style: const TextStyle(
                                    color: Color(0xFFF9FAFB),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attended Today',
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '0',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('attendance')
                          .where('userId', isEqualTo: userId)
                          .where('classId', whereIn: todayClassIds)
                          .where('markedAt', isGreaterThan: Timestamp.fromDate(
                            DateTime(today.year, today.month, today.day),
                          ))
                          .snapshots(),
                      builder: (context, attendanceSnapshot) {
                        final attendedToday = attendanceSnapshot.data?.docs.length ?? 0;
                        final enrolledToday = todayClasses.length;

                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enrolled Today',
                                    style: const TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$enrolledToday',
                                    style: const TextStyle(
                                      color: Color(0xFFF9FAFB),
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Attended Today',
                                    style: const TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$attendedToday',
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}