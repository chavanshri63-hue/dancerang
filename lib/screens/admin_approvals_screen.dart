import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/payment_service.dart';

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> {
  String _selectedFilter = 'all'; // 'all', 'cash_payment', 'workshop', 'banner'
  final Map<String, String> _userNameCache = {};

  Future<void> _sendUserNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
    String priority = 'high',
    Map<String, dynamic>? data,
  }) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      await functions.httpsCallable('sendUserNotification').call({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'priority': priority,
        if (data != null) 'data': data,
      });
    } catch (_) {
      // Best-effort; core approval/enrollment should not fail due to push issues.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: const GlassmorphismAppBar(title: 'Pending Approvals'),
      body: Column(
        children: [
          // Filter buttons
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Cash Payments', 'cash_payment'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Workshops', 'workshop'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Banners', 'banner'),
                ],
              ),
            ),
          ),
          // Approvals list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getApprovalsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No pending approvals',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                final approvals = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: approvals.length,
                  itemBuilder: (context, index) {
                    final doc = approvals[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildApprovalCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: const Color(0xFFE53935),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Stream<QuerySnapshot> _getApprovalsStream() {
    Query query = FirebaseFirestore.instance
        .collection('approvals')
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true);

    if (_selectedFilter != 'all') {
      query = query.where('type', isEqualTo: _selectedFilter);
    }

    return query.snapshots();
  }

  Widget _buildApprovalCard(String approvalId, Map<String, dynamic> data) {
    final type = data['type'] ?? 'unknown';
    final title = data['title'] ?? 'Approval Request';
    final message = data['message'] ?? '';
    final createdAt = data['created_at'] as Timestamp?;
    final paymentId = data['payment_id'] as String?;
    final userId = data['user_id'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getTypeColor(type).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getTypeIcon(type), color: _getTypeColor(type), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (type == 'cash_payment' && userId != null && userId.trim().isNotEmpty)
                        FutureBuilder<String>(
                          future: _getUserName(userId),
                          builder: (context, snap) {
                            final name = (snap.data ?? '').trim();
                            return Text(
                              name.isEmpty ? 'Student: —' : 'Student: $name',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            );
                          },
                        ),
                      if (type == 'cash_payment' && userId != null && userId.trim().isNotEmpty)
                        const SizedBox(height: 4),
                      Text(
                        message,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _formatDate(createdAt.toDate()),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _rejectApproval(approvalId, paymentId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _approveApproval(approvalId, paymentId, userId, type, data),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getUserName(String userId) async {
    final cached = _userNameCache[userId];
    if (cached != null) return cached;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final data = doc.data() ?? {};
      final name = (data['name'] ?? data['displayName'] ?? data['fullName'] ?? '').toString().trim();
      _userNameCache[userId] = name;
      return name;
    } catch (_) {
      _userNameCache[userId] = '';
      return '';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'cash_payment':
        return const Color(0xFFF59E0B);
      case 'workshop':
        return const Color(0xFF66BB6A);
      case 'banner':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFFE53935);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'cash_payment':
        return Icons.payment;
      case 'workshop':
        return Icons.event;
      case 'banner':
        return Icons.image;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _approveApproval(
    String approvalId,
    String? paymentId,
    String? userId,
    String type,
    Map<String, dynamic> data,
  ) async {
    if (!mounted) return;

    try {
      
      // Update approval status
      await FirebaseFirestore.instance
          .collection('approvals')
          .doc(approvalId)
          .update({
        'status': 'approved',
        'approved_at': FieldValue.serverTimestamp(),
        'approved_by': FirebaseAuth.instance.currentUser?.uid,
      });

      // If it's a cash payment, update payment status and trigger enrollment
      if (type == 'cash_payment' && paymentId != null) {
        try {
          // Get userId from approval data if not provided
          final approvalUserId = userId ?? data['user_id'] as String?;
          await _approveCashPayment(paymentId, approvalUserId, data);
          
          // Don't send approval notification here - enrollment notification will be sent
          // This prevents duplicate notifications
        } catch (e) {
          rethrow; // Re-throw to show error to user
        }
      } else {
        // Send approval notification for other types
        if (userId != null) {
          final description = data['message'] as String? ?? data['title'] as String? ?? 'Request';
          await _sendUserNotification(
            userId: userId,
            title: '✅ Request Approved!',
            body: 'Your $type request for "$description" has been approved!',
            type: 'approval_approved',
            data: {
              'approvalType': type,
              'description': description,
              'status': 'approved',
            },
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Approval granted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveCashPayment(
    String paymentId,
    String? userId,
    Map<String, dynamic> approvalData,
  ) async {
    try {
      
      // Update payment status to 'success' (same as online payment)
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .update({
        'status': 'success',
        'payment_method': 'cash',
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Get payment details to determine enrollment type
      final paymentDoc = await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .get();

      if (!paymentDoc.exists) {
        throw Exception('Payment document not found: $paymentId');
      }

      final paymentData = paymentDoc.data() ?? {};
      final paymentType = paymentData['payment_type'] as String? ?? '';
      final itemId = paymentData['item_id'] as String? ?? '';
      
      // Get userId from payment if not provided, or from approval data
      final paymentUserId = userId ?? 
          paymentData['user_id'] as String? ?? 
          approvalData['user_id'] as String?;
      

      if (paymentUserId == null || itemId.isEmpty) {
        throw Exception('Missing userId or itemId for enrollment. userId: $paymentUserId, itemId: $itemId');
      }


      // Trigger enrollment based on payment type
      if (paymentType == 'class_fee') {
        await _enrollInClass(paymentUserId, itemId);
      } else if (paymentType == 'workshop') {
        await _enrollInWorkshop(paymentUserId, itemId);
      } else if (paymentType == 'event_choreography') {
        await _confirmEventChoreoBooking(paymentUserId, itemId, paymentId);
      } else if (paymentType == 'studio_booking') {
        await _confirmStudioBooking(paymentUserId, itemId, paymentId);
      } else {
      }
      
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _confirmEventChoreoBooking(String userId, String bookingId, String paymentId) async {
    try {
      final bookingRef = FirebaseFirestore.instance.collection('eventChoreoBookings').doc(bookingId);
      
      // Update booking status
      await bookingRef.update({
        'status': 'confirmed',
        'paymentId': paymentId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify user via existing refresh mechanism
      PaymentService.triggerEnrollmentRefresh(
        paymentType: 'event_choreography',
        itemId: bookingId,
        userId: userId,
      );

      // Notify student (push + in-app)
      await _sendUserNotification(
        userId: userId,
        title: '✅ Booking Confirmed!',
        body: 'Your event choreography booking is confirmed.',
        type: 'event_choreography',
        data: {'bookingId': bookingId, 'paymentId': paymentId},
      );


    } catch (e) {
      rethrow;
    }
  }

  Future<void> _enrollInClass(String userId, String classId) async {
    try {
      
      // Get class details first
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .get();

      if (!classDoc.exists) {
        throw Exception('Class not found: $classId');
      }

      final classData = classDoc.data() ?? {};
      final className = classData['name'] as String? ?? 'Unknown Class';
      
      // Get numberOfSessions from class, default to 12 if not set
      final classNumberOfSessions = classData['numberOfSessions'] != null 
          ? (classData['numberOfSessions'] as num).toInt() 
          : 12;
      
      // Check if already enrolled - but don't return early, ensure all collections are synced
      final existingEnrollment = await FirebaseFirestore.instance
          .collection('class_enrollments')
          .where('user_id', isEqualTo: userId)
          .where('classId', isEqualTo: classId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      final existingEnrolments = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('itemId', isEqualTo: classId)
          .where('status', isEqualTo: 'enrolled')
          .where('itemType', isEqualTo: 'class')
          .limit(1)
          .get();

      final userEnrollmentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .doc(classId)
          .get();

      final isAlreadyEnrolled = existingEnrollment.docs.isNotEmpty || 
          existingEnrolments.docs.isNotEmpty ||
          (userEnrollmentDoc.exists && userEnrollmentDoc.data()?['status'] == 'enrolled');

      if (isAlreadyEnrolled) {
        // Ensure all collections are in sync
        if (!userEnrollmentDoc.exists || userEnrollmentDoc.data()?['status'] != 'enrolled') {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('enrollments')
              .doc(classId)
              .set({
            'itemId': classId,
            'itemType': 'class',
            'status': 'enrolled',
            'enrolledAt': FieldValue.serverTimestamp(),
            'totalSessions': classNumberOfSessions,
            'completedSessions': 0,
            'remainingSessions': classNumberOfSessions,
            'packageId': 'default',
            'packageName': 'Monthly Package',
          }, SetOptions(merge: true));
        }
        
        // Skip notification here - will be sent after enrollment creation below
        // This prevents duplicate notifications when user is already enrolled
        
        await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .update({
          'updated_at': FieldValue.serverTimestamp(),
        });
        return;
      }

      // Not enrolled yet - create new enrollment
      // Default package: 1 month
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 30));
      final enrollmentId = FirebaseFirestore.instance.collection('class_enrollments').doc().id;

      // Create enrollment record
      await FirebaseFirestore.instance
          .collection('class_enrollments')
          .doc(enrollmentId)
          .set({
        'id': enrollmentId,
        'user_id': userId,
        'userId': userId,
        'classId': classId,
        'className': className,
        'packageId': 'default',
        'packageName': 'Monthly Package',
        'totalSessions': classNumberOfSessions,
        'completedSessions': 0,
        'remainingSessions': classNumberOfSessions,
        'startDate': Timestamp.fromDate(now),
        'endDate': Timestamp.fromDate(endDate),
        'status': 'active',
        'packagePrice': 0, // Already paid via cash
        'paymentStatus': 'paid',
        'attendanceHistory': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add to user's enrollments subcollections
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .doc(classId)
          .set({
        'itemId': classId,
        'itemType': 'class',
        'status': 'enrolled',
        'enrolledAt': FieldValue.serverTimestamp(),
        'totalSessions': classNumberOfSessions,
        'completedSessions': 0,
        'remainingSessions': classNumberOfSessions,
        'packageId': 'default',
        'packageName': 'Monthly Package',
      });

      // Add to global enrollments collections
      await FirebaseFirestore.instance.collection('enrollments').add({
        'userId': userId,
        'user_id': userId,
        'itemId': classId,
        'itemType': 'class',
        'status': 'enrolled',
        'enrolledAt': FieldValue.serverTimestamp(),
        'className': className,
        'totalSessions': classNumberOfSessions,
        'completedSessions': 0,
        'remainingSessions': classNumberOfSessions,
        'packageId': 'default',
        'packageName': 'Monthly Package',
        'packagePrice': 0,
        'paymentStatus': 'paid',
        'enrollmentId': enrollmentId,
      });

      // Update class participant count (same as payment success flow)
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .update({
        'participant_count': FieldValue.increment(1),
        'currentBookings': FieldValue.increment(1),
        'enrolledCount': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Trigger enrollment refresh events (same as payment success)
      PaymentService.triggerEnrollmentRefresh(
        paymentType: 'class_fee',
        itemId: classId,
        userId: userId,
      );

      // Notify student (push + in-app) after cash approval enrollment
      await _sendUserNotification(
        userId: userId,
        title: '✅ Successfully Enrolled!',
        body: 'You\'re now enrolled in "$className" class',
        type: 'enrollment',
        data: {'itemType': 'class', 'itemId': classId, 'itemName': className},
      );
      
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _enrollInWorkshop(String userId, String workshopId) async {
    try {
      // Get workshop details
      final workshopDoc = await FirebaseFirestore.instance
          .collection('workshops')
          .doc(workshopId)
          .get();

      if (!workshopDoc.exists) {
        return;
      }

      final workshopData = workshopDoc.data() ?? {};
      final workshopName = workshopData['name'] ?? workshopData['title'] ?? 'Unknown Workshop';
      
      // Check if already enrolled
      final existingEnrollment = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('itemId', isEqualTo: workshopId)
          .where('status', isEqualTo: 'enrolled')
          .where('itemType', isEqualTo: 'workshop')
          .limit(1)
          .get();

      if (existingEnrollment.docs.isNotEmpty) {
        // User already enrolled - just ensure workshop metadata is updated
        await FirebaseFirestore.instance
            .collection('workshops')
            .doc(workshopId)
            .update({
          'updated_at': FieldValue.serverTimestamp(),
        });
        return;
      }

      // Create enrollment in workshop_enrollments (legacy)
      await FirebaseFirestore.instance
          .collection('workshop_enrollments')
          .add({
        'user_id': userId,
        'workshop_id': workshopId,
        'enrolled_at': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // Add to user's enrollments subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .doc(workshopId)
          .set({
        'itemId': workshopId,
        'itemType': 'workshop',
        'status': 'enrolled',
        'enrolledAt': FieldValue.serverTimestamp(),
        'totalSessions': 1,
        'completedSessions': 0,
        'remainingSessions': 1,
      });

      // Add to global enrollments collection (same as classes)
      await FirebaseFirestore.instance.collection('enrollments').add({
        'userId': userId,
        'user_id': userId,
        'itemId': workshopId,
        'itemType': 'workshop',
        'status': 'enrolled',
        'enrolledAt': FieldValue.serverTimestamp(),
        'workshopName': workshopName,
        'totalSessions': 1,
        'completedSessions': 0,
        'remainingSessions': 1,
        'paymentStatus': 'paid',
      });

      // Update workshop participant count (ensure increment, not decrement)
      final workshopRef = FirebaseFirestore.instance
          .collection('workshops')
          .doc(workshopId);
      
      // Update with increment
      await workshopRef.update({
        'enrolledCount': FieldValue.increment(1),
        'currentParticipants': FieldValue.increment(1),
        'participant_count': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Trigger enrollment refresh events (same as classes)
      PaymentService.triggerEnrollmentRefresh(
        paymentType: 'workshop',
        itemId: workshopId,
        userId: userId,
      );

      // Notify student (push + in-app) after cash approval workshop enrollment
      await _sendUserNotification(
        userId: userId,
        title: '✅ Successfully Enrolled!',
        body: 'You\'re now enrolled in "$workshopName" workshop',
        type: 'enrollment',
        data: {'itemType': 'workshop', 'itemId': workshopId, 'itemName': workshopName},
      );


    } catch (e) {
      rethrow;
    }
  }

  Future<void> _confirmStudioBooking(String userId, String bookingId, String paymentId) async {
    try {
      final bookingRef = FirebaseFirestore.instance.collection('studioBookings').doc(bookingId);
      final snap = await bookingRef.get();
      if (!snap.exists) {
        return;
      }

      await bookingRef.update({
        'status': 'confirmed',
        'paymentId': paymentId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify student (push + in-app)
      await _sendUserNotification(
        userId: userId,
        title: '✅ Studio Booking Confirmed!',
        body: 'Your studio booking is confirmed.',
        type: 'studio_booking',
        data: {'bookingId': bookingId, 'paymentId': paymentId},
      );


    } catch (e) {
      rethrow;
    }
  }

  Future<void> _rejectApproval(String approvalId, String? paymentId) async {
    if (!mounted) return;

    try {
      // Update approval status
      await FirebaseFirestore.instance
          .collection('approvals')
          .doc(approvalId)
          .update({
        'status': 'rejected',
        'rejected_at': FieldValue.serverTimestamp(),
        'rejected_by': FirebaseAuth.instance.currentUser?.uid,
      });

      // If it's a cash payment, also update payment status
      if (paymentId != null) {
        await FirebaseFirestore.instance
            .collection('payments')
            .doc(paymentId)
            .update({
          'status': 'failed',
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      // Send rejection notification to user
      final approvalData = await FirebaseFirestore.instance
          .collection('approvals')
          .doc(approvalId)
          .get();
      final approvalDataMap = approvalData.data();
      final userId = approvalDataMap?['user_id'] as String?;
      if (userId != null) {
        final type = approvalDataMap?['type'] as String? ?? 'request';
        final description = approvalDataMap?['message'] as String? ?? approvalDataMap?['title'] as String? ?? 'Request';
        await _sendUserNotification(
          userId: userId,
          title: '❌ Request Rejected',
          body: 'Your $type request for "$description" has been rejected.',
          type: 'approval_rejected',
          data: {
            'approvalType': type,
            'description': description,
            'status': 'rejected',
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Approval rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

