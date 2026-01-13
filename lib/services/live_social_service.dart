import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'live_notification_service.dart';

class LiveSocialService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add friend
  static Future<Map<String, dynamic>> addFriend({
    required String friendId,
    required String friendName,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'User not authenticated',
        };
      }

      if (user.uid == friendId) {
        return {
          'success': false,
          'message': 'Cannot add yourself as a friend',
        };
      }

      // Check if already friends
      final friendshipCheck = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: user.uid)
          .where('friendId', isEqualTo: friendId)
          .limit(1)
          .get();

      if (friendshipCheck.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'Already friends with this user',
        };
      }

      // Add friendship
      await _firestore.collection('friendships').add({
        'userId': user.uid,
        'friendId': friendId,
        'friendName': friendName,
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add reverse friendship
      await _firestore.collection('friendships').add({
        'userId': friendId,
        'friendId': user.uid,
        'friendName': user.displayName ?? 'User',
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Friend added successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error adding friend: $e',
      };
    }
  }

  /// Get user's friends
  static Stream<List<Map<String, dynamic>>> getUserFriends(String userId) {
    return _firestore
        .collection('friendships')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList());
  }

  /// Get friends attending a class/workshop
  static Stream<List<Map<String, dynamic>>> getFriendsAttending({
    required String itemId,
    required String itemType,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('friendships')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .asyncMap((friendsSnapshot) async {
      final friendIds = friendsSnapshot.docs.map((doc) => doc.data()['friendId'] as String).toList();
      
      if (friendIds.isEmpty) return <Map<String, dynamic>>[];

      List<Map<String, dynamic>> attendingFriends = [];

      // Check which friends are enrolled
      for (final friendId in friendIds) {
        final enrollmentCheck = await _firestore
            .collection('users')
            .doc(friendId)
            .collection('enrollments')
            .doc(itemId)
            .get();

        if (enrollmentCheck.exists && enrollmentCheck.data()?['status'] == 'enrolled') {
          final friendData = await _firestore.collection('users').doc(friendId).get();
          attendingFriends.add({
            'friendId': friendId,
            'friendName': friendData.data()?['name'] ?? 'Friend',
            'friendEmail': friendData.data()?['email'] ?? '',
            'enrolledAt': enrollmentCheck.data()?['enrolledAt'],
          });
        }
      }

      return attendingFriends;
    });
  }

  /// Send friend notification when enrolling
  static Future<void> notifyFriendsOnEnrollment({
    required String itemId,
    required String itemType,
    required String itemName,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get user's friends
      final friendsSnapshot = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (final doc in friendsSnapshot.docs) {
        final friendId = doc.data()['friendId'] as String;
        
        // Send notification to friend
        await LiveNotificationService.sendFriendEnrollmentNotification(
          friendName: user.displayName ?? 'Your friend',
          itemName: itemName,
          itemType: itemType,
          friendId: friendId,
        );
      }
    } catch (e) {
    }
  }

  /// Get social proof data for a class/workshop
  static Stream<Map<String, dynamic>> getSocialProof({
    required String itemId,
    required String itemType,
  }) {
    return _firestore
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .collection('enrollments')
        .doc(itemId)
        .snapshots()
        .asyncMap((enrollmentSnapshot) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {'friendsAttending': 0, 'totalEnrolled': 0};

      // Get total enrolled count
      final itemDoc = await _firestore
          .collection(itemType == 'class' ? 'classes' : 'workshops')
          .doc(itemId)
          .get();

      final itemData = itemDoc.data();
      final totalEnrolled = itemType == 'class'
          ? (itemData?['currentBookings'] ?? itemData?['enrolledCount'] ?? 0)
          : (itemData?['currentParticipants'] ?? itemData?['enrolledCount'] ?? 0);

      // Get friends attending
      int friendsAttending = 0;
      final friendsSnapshot = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (final doc in friendsSnapshot.docs) {
        final friendId = doc.data()['friendId'] as String;
        final friendEnrollment = await _firestore
            .collection('users')
            .doc(friendId)
            .collection('enrollments')
            .doc(itemId)
            .get();

        if (friendEnrollment.exists && friendEnrollment.data()?['status'] == 'enrolled') {
          friendsAttending++;
        }
      }

      return {
        'friendsAttending': friendsAttending,
        'totalEnrolled': totalEnrolled,
        'socialProof': friendsAttending > 0 ? '${friendsAttending} of your friends are attending' : null,
      };
    });
  }

  /// Get recent enrollments by friends
  static Stream<List<Map<String, dynamic>>> getFriendsRecentActivity() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('friendships')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .asyncMap((friendsSnapshot) async {
      final friendIds = friendsSnapshot.docs.map((doc) => doc.data()['friendId'] as String).toList();
      
      if (friendIds.isEmpty) return <Map<String, dynamic>>[];

      List<Map<String, dynamic>> activities = [];

      for (final friendId in friendIds) {
        final enrollmentsSnapshot = await _firestore
            .collection('users')
            .doc(friendId)
            .collection('enrollments')
            .where('status', isEqualTo: 'enrolled')
            .orderBy('enrolledAt', descending: true)
            .limit(3)
            .get();

        for (final enrollment in enrollmentsSnapshot.docs) {
          final data = enrollment.data();
          final itemId = data['itemId'] as String;
          final itemType = data['itemType'] as String;
          
          // Get item details
          final itemDoc = await _firestore
              .collection(itemType == 'class' ? 'classes' : 'workshops')
              .doc(itemId)
              .get();

          if (itemDoc.exists) {
            final itemData = itemDoc.data()!;
            activities.add({
              'friendId': friendId,
              'friendName': friendsSnapshot.docs
                  .firstWhere((doc) => doc.data()['friendId'] == friendId)
                  .data()['friendName'],
              'itemId': itemId,
              'itemName': itemData['name'] ?? itemData['title'] ?? 'Unknown',
              'itemType': itemType,
              'enrolledAt': data['enrolledAt'],
            });
          }
        }
      }

      activities.sort((a, b) => (b['enrolledAt'] as Timestamp).compareTo(a['enrolledAt'] as Timestamp));
      return activities.take(10).toList();
    });
  }

  /// Get trending among friends
  static Stream<List<Map<String, dynamic>>> getTrendingAmongFriends() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('friendships')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .asyncMap((friendsSnapshot) async {
      final friendIds = friendsSnapshot.docs.map((doc) => doc.data()['friendId'] as String).toList();
      
      if (friendIds.isEmpty) return <Map<String, dynamic>>[];

      Map<String, Map<String, dynamic>> itemCounts = {};

      for (final friendId in friendIds) {
        final enrollmentsSnapshot = await _firestore
            .collection('users')
            .doc(friendId)
            .collection('enrollments')
            .where('status', isEqualTo: 'enrolled')
            .get();

        for (final enrollment in enrollmentsSnapshot.docs) {
          final data = enrollment.data();
          final itemId = data['itemId'] as String;
          final itemType = data['itemType'] as String;
          
          if (!itemCounts.containsKey(itemId)) {
            itemCounts[itemId] = {
              'itemId': itemId,
              'itemType': itemType,
              'friendCount': 0,
              'friends': <String>[],
            };
          }
          
          itemCounts[itemId]!['friendCount']++;
          itemCounts[itemId]!['friends'].add(friendId);
        }
      }

      // Get item details for trending items
      List<Map<String, dynamic>> trendingItems = [];
      for (final entry in itemCounts.entries) {
        final itemId = entry.key;
        final itemData = entry.value;
        final itemType = itemData['itemType'] as String;
        
        final itemDoc = await _firestore
            .collection(itemType == 'class' ? 'classes' : 'workshops')
            .doc(itemId)
            .get();

        if (itemDoc.exists) {
          final docData = itemDoc.data()!;
          trendingItems.add({
            'itemId': itemId,
            'itemName': docData['name'] ?? docData['title'] ?? 'Unknown',
            'itemType': itemType,
            'friendCount': itemData['friendCount'],
            'friends': itemData['friends'],
            'category': docData['category'] ?? 'General',
            'instructor': docData['instructor'] ?? 'Unknown',
          });
        }
      }

      trendingItems.sort((a, b) => (b['friendCount'] as int).compareTo(a['friendCount'] as int));
      return trendingItems.take(5).toList();
    });
  }
}

/// Social Proof Widget
class SocialProofWidget extends StatelessWidget {
  final String itemId;
  final String itemType;

  const SocialProofWidget({
    super.key,
    required this.itemId,
    required this.itemType,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: LiveSocialService.getSocialProof(itemId: itemId, itemType: itemType),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final socialProof = snapshot.data!;
        final friendsAttending = socialProof['friendsAttending'] as int;
        final totalEnrolled = socialProof['totalEnrolled'] as int;

        if (friendsAttending == 0 && totalEnrolled < 5) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.people,
                color: Colors.blue,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  friendsAttending > 0
                      ? '$friendsAttending of your friends are attending • $totalEnrolled total enrolled'
                      : '$totalEnrolled people have enrolled',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Friends Activity Widget
class FriendsActivityWidget extends StatelessWidget {
  const FriendsActivityWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '👥 Friends Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: LiveSocialService.getFriendsRecentActivity(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final activities = snapshot.data!;
              
              if (activities.isEmpty) {
                return const Center(
                  child: Text(
                    'No recent activity from friends',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }
              
              return Column(
                children: activities.take(5).map((activity) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue.withValues(alpha: 0.2),
                        child: Text(
                          (activity['friendName'] as String).substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${activity['friendName']} enrolled in',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              activity['itemName'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          activity['itemType'],
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
