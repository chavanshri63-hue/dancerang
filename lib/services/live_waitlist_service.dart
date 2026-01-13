import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'live_notification_service.dart';

class LiveWaitlistService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add user to waitlist
  static Future<Map<String, dynamic>> addToWaitlist({
    required String itemId,
    required String itemType, // 'class' or 'workshop'
    required String userId,
    required String userName,
    required String itemName,
  }) async {
    try {
      // Check if already enrolled
      final enrollmentCheck = await _firestore
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .doc(itemId)
          .get();

      if (enrollmentCheck.exists && enrollmentCheck.data()?['status'] == 'enrolled') {
        return {
          'success': false,
          'message': 'You are already enrolled in this item',
        };
      }

      // Check if already on waitlist
      final waitlistCheck = await _firestore
          .collection('waitlist')
          .where('itemId', isEqualTo: itemId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'waiting')
          .limit(1)
          .get();

      if (waitlistCheck.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'You are already on the waitlist for this item',
        };
      }

      // Get current waitlist position
      final waitlistSnapshot = await _firestore
          .collection('waitlist')
          .where('itemId', isEqualTo: itemId)
          .where('status', isEqualTo: 'waiting')
          .orderBy('joinedAt', descending: false)
          .get();

      final position = waitlistSnapshot.docs.length + 1;

      // Add to waitlist
      await _firestore.collection('waitlist').add({
        'itemId': itemId,
        'itemType': itemType,
        'userId': userId,
        'userName': userName,
        'itemName': itemName,
        'position': position,
        'status': 'waiting',
        'joinedAt': FieldValue.serverTimestamp(),
        'notifiedAt': null,
      });

      // Send notification
      await LiveNotificationService.sendWaitlistNotification(
        itemName: itemName,
        position: position,
      );

      return {
        'success': true,
        'message': 'Added to waitlist at position $position',
        'position': position,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error adding to waitlist: $e',
      };
    }
  }

  /// Remove user from waitlist
  static Future<Map<String, dynamic>> removeFromWaitlist({
    required String itemId,
    required String userId,
  }) async {
    try {
      final waitlistQuery = await _firestore
          .collection('waitlist')
          .where('itemId', isEqualTo: itemId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'waiting')
          .limit(1)
          .get();

      if (waitlistQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'You are not on the waitlist for this item',
        };
      }

      await waitlistQuery.docs.first.reference.delete();

      // Update positions for remaining waitlist members
      await _updateWaitlistPositions(itemId);

      return {
        'success': true,
        'message': 'Removed from waitlist',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error removing from waitlist: $e',
      };
    }
  }

  /// Get user's waitlist positions
  static Stream<List<Map<String, dynamic>>> getUserWaitlist(String userId) {
    return _firestore
        .collection('waitlist')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'waiting')
        .orderBy('joinedAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList());
  }

  /// Get waitlist for a specific item
  static Stream<List<Map<String, dynamic>>> getItemWaitlist(String itemId) {
    return _firestore
        .collection('waitlist')
        .where('itemId', isEqualTo: itemId)
        .where('status', isEqualTo: 'waiting')
        .orderBy('joinedAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList());
  }

  /// Check for available spots and notify waitlist
  static Future<void> checkAndNotifyWaitlist({
    required String itemId,
    required String itemType,
  }) async {
    try {
      // Get item capacity
      final itemDoc = await _firestore
          .collection(itemType == 'class' ? 'classes' : 'workshops')
          .doc(itemId)
          .get();

      if (!itemDoc.exists) return;

      final itemData = itemDoc.data()!;
      final maxCapacity = itemType == 'class' 
          ? (itemData['maxStudents'] ?? 20)
          : (itemData['maxParticipants'] ?? 20);
      final currentEnrollments = itemType == 'class'
          ? (itemData['currentBookings'] ?? itemData['enrolledCount'] ?? 0)
          : (itemData['currentParticipants'] ?? itemData['enrolledCount'] ?? 0);

      final availableSpots = maxCapacity - currentEnrollments;

      if (availableSpots <= 0) return;

      // Get waitlist members
      final waitlistSnapshot = await _firestore
          .collection('waitlist')
          .where('itemId', isEqualTo: itemId)
          .where('status', isEqualTo: 'waiting')
          .orderBy('joinedAt', descending: false)
          .limit(availableSpots)
          .get();

      // Notify waitlist members
      for (int i = 0; i < waitlistSnapshot.docs.length; i++) {
        final doc = waitlistSnapshot.docs[i];
        final data = doc.data();
        final userId = data['userId'];
        final userName = data['userName'];
        final itemName = data['itemName'];

        // Send notification
        await LiveNotificationService.sendSpotAvailableNotification(
          itemName: itemName,
          itemType: itemType,
          userId: userId,
        );

        // Update waitlist status
        await doc.reference.update({
          'status': 'notified',
          'notifiedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update remaining positions
      await _updateWaitlistPositions(itemId);
    } catch (e) {
    }
  }

  /// Update waitlist positions after changes
  static Future<void> _updateWaitlistPositions(String itemId) async {
    try {
      final waitlistSnapshot = await _firestore
          .collection('waitlist')
          .where('itemId', isEqualTo: itemId)
          .where('status', isEqualTo: 'waiting')
          .orderBy('joinedAt', descending: false)
          .get();

      for (int i = 0; i < waitlistSnapshot.docs.length; i++) {
        await waitlistSnapshot.docs[i].reference.update({
          'position': i + 1,
        });
      }
    } catch (e) {
    }
  }

  /// Get waitlist statistics
  static Future<Map<String, dynamic>> getWaitlistStats(String itemId) async {
    try {
      final waitlistSnapshot = await _firestore
          .collection('waitlist')
          .where('itemId', isEqualTo: itemId)
          .where('status', isEqualTo: 'waiting')
          .get();

      return {
        'totalWaitlist': waitlistSnapshot.docs.length,
        'averageWaitTime': 0, // Can be calculated based on historical data
        'conversionRate': 0, // Can be calculated based on historical data
      };
    } catch (e) {
      return {
        'totalWaitlist': 0,
        'averageWaitTime': 0,
        'conversionRate': 0,
      };
    }
  }
}

/// Waitlist Widget
class WaitlistWidget extends StatelessWidget {
  final String itemId;
  final String itemType;
  final String itemName;
  final int maxCapacity;
  final int currentEnrollments;

  const WaitlistWidget({
    super.key,
    required this.itemId,
    required this.itemType,
    required this.itemName,
    required this.maxCapacity,
    required this.currentEnrollments,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final availableSpots = maxCapacity - currentEnrollments;
    final isFullyBooked = availableSpots <= 0;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: LiveWaitlistService.getUserWaitlist(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final userWaitlist = snapshot.data!;
        final isOnWaitlist = userWaitlist.any((item) => item['itemId'] == itemId);

        if (!isFullyBooked && !isOnWaitlist) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFullyBooked ? Colors.orange : Colors.blue,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isFullyBooked ? Icons.schedule : Icons.person_add,
                    color: isFullyBooked ? Colors.orange : Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isFullyBooked ? 'Fully Booked' : 'On Waitlist',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isFullyBooked && !isOnWaitlist) ...[
                Text(
                  'This $itemType is fully booked. Join the waitlist to be notified when spots open up.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _joinWaitlist(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Join Waitlist'),
                  ),
                ),
              ] else if (isOnWaitlist) ...[
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: LiveWaitlistService.getItemWaitlist(itemId),
                  builder: (context, waitlistSnapshot) {
                    if (!waitlistSnapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final waitlist = waitlistSnapshot.data!;
                    final userPosition = waitlist.indexWhere((item) => item['userId'] == user.uid) + 1;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You are #$userPosition on the waitlist',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total waitlist: ${waitlist.length} people',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _leaveWaitlist(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Leave Waitlist'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _joinWaitlist(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await LiveWaitlistService.addToWaitlist(
      itemId: itemId,
      itemType: itemType,
      userId: user.uid,
      userName: user.displayName ?? 'User',
      itemName: itemName,
    );

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _leaveWaitlist(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await LiveWaitlistService.removeFromWaitlist(
      itemId: itemId,
      userId: user.uid,
    );

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
