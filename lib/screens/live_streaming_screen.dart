import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/payment_service.dart';
import 'video_player_screen.dart';
import 'subscription_plans_screen.dart';

class LiveStreamingScreen extends StatefulWidget {
  const LiveStreamingScreen({super.key});

  @override
  State<LiveStreamingScreen> createState() => _LiveStreamingScreenState();
}

class _LiveStreamingScreenState extends State<LiveStreamingScreen> {
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;

  @override
  void initState() {
    super.initState();
    
    // Listen to payment success events for real-time subscription updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (event['type'] == 'payment_success' && event['paymentType'] == 'subscription' && mounted) {
        // Force rebuild when subscription payment succeeds
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _paymentRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _enableLiveClassNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to enable notifications'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get upcoming live classes
      final now = DateTime.now();
      final upcomingSnapshot = await FirebaseFirestore.instance
          .collection('onlineVideos')
          .where('isLive', isEqualTo: true)
          .where('status', isEqualTo: 'published')
          .get();

      int notificationCount = 0;
      for (var doc in upcomingSnapshot.docs) {
        final data = doc.data();
        final startTime = data['startTime'] as Timestamp?;
        
        if (startTime != null) {
          final startDateTime = startTime.toDate();
          // Only schedule if start time is in the future
          if (startDateTime.isAfter(now)) {
            final title = (data['title'] ?? 'Live Dance Class').toString();
            final notificationId = doc.id.hashCode;
            
            // Schedule notification 5 minutes before start
            final notificationTime = startDateTime.subtract(const Duration(minutes: 5));
            
            // Notification scheduling disabled
          }
        }
      }

      // Save notification preference to user's document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'liveClassNotificationsEnabled': true,
        'liveClassNotificationsUpdatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notificationCount > 0
                ? 'Notifications enabled! You will be notified about $notificationCount upcoming live class${notificationCount > 1 ? 'es' : ''}'
                : 'Notifications enabled! You will be notified when live classes are scheduled.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enabling notifications: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'Live Classes',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('onlineVideos')
            .where('isLive', isEqualTo: true)
            .where('status', isEqualTo: 'published')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
          }
          
          final docs = snapshot.data?.docs ?? [];
          
          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final title = (d['title'] ?? '').toString();
              final desc = (d['description'] ?? '').toString();
              final thumb = (d['thumbnail'] ?? '').toString();
              final videoUrl = (d['url'] ?? '').toString();
              final views = (d['views'] ?? 0) as int;
              final likes = (d['likes'] ?? 0) as int;
              final section = (d['section'] ?? '').toString();
              final isPaidContent = d['isPaidContent'] == true;
              final videoId = docs[index].id;
              final instructorName = (d['instructorName'] ?? 'Instructor').toString();
              final startTime = d['startTime'] as Timestamp?;
              final endTime = d['endTime'] as Timestamp?;
              
              return _LiveStreamCard(
                videoId: videoId,
                title: title,
                description: desc,
                thumbnail: thumb,
                videoUrl: videoUrl,
                views: views,
                likes: likes,
                section: section,
                isPaidContent: isPaidContent,
                instructorName: instructorName,
                startTime: startTime,
                endTime: endTime,
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 16),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.live_tv,
              size: 64,
              color: Color(0xFFE53935),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Live Classes Right Now',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for live dance sessions',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _enableLiveClassNotifications,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Notify Me',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStreamCard extends StatelessWidget {
  final String videoId;
  final String title;
  final String description;
  final String thumbnail;
  final String videoUrl;
  final int views;
  final int likes;
  final String section;
  final bool isPaidContent;
  final String instructorName;
  final Timestamp? startTime;
  final Timestamp? endTime;

  const _LiveStreamCard({
    required this.videoId,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.videoUrl,
    required this.views,
    required this.likes,
    required this.section,
    required this.isPaidContent,
    required this.instructorName,
    required this.startTime,
    required this.endTime,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isLiveNow = startTime != null && 
        now.isAfter(startTime!.toDate()) && 
        (endTime == null || now.isBefore(endTime!.toDate()));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('subscriptions')
          .limit(1)
          .snapshots(),
      builder: (context, subscriptionSnapshot) {
        final hasActiveSubscription = subscriptionSnapshot.hasData && 
            subscriptionSnapshot.data != null &&
            subscriptionSnapshot.data!.docs.isNotEmpty &&
            (subscriptionSnapshot.data!.docs.first.data()['status'] == 'active');

        return Card(
          elevation: 8,
          shadowColor: const Color(0xFFE53935).withOpacity(0.3),
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isLiveNow 
                  ? const Color(0xFFE53935).withOpacity(0.5)
                  : const Color(0xFF4F46E5).withOpacity(0.22),
              width: isLiveNow ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () {
              if (!isPaidContent || hasActiveSubscription) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      videoId: videoId,
                      title: title,
                      description: description,
                      videoUrl: videoUrl,
                      thumbnail: thumbnail,
                      isLive: true,
                      isPaidContent: isPaidContent,
                      section: section,
                      views: views,
                      likes: likes,
                    ),
                  ),
                );
              }
            },
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: const Color(0xFF262626),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (thumbnail.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                              child: Image.network(
                                thumbnail,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            )
                          else
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFE53935).withOpacity(0.3),
                                    const Color(0xFF4F46E5).withOpacity(0.3),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.live_tv,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                            ),
                          // Live indicator
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isLiveNow 
                                    ? const Color(0xFFE53935).withOpacity(0.9)
                                    : const Color(0xFF4F46E5).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isLiveNow ? Icons.circle : Icons.schedule,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isLiveNow ? 'LIVE NOW' : 'SCHEDULED',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Viewers count
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.visibility, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$views',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title.isEmpty ? 'Live Dance Class' : title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPaidContent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Premium',
                                    style: TextStyle(
                                      color: Color(0xFFE53935),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.person, color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                instructorName,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  section,
                                  style: const TextStyle(
                                    color: Color(0xFF4F46E5),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (description.isNotEmpty)
                            Text(
                              description,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.favorite, color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              Text('$likes', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                              const Spacer(),
                              if (startTime != null)
                                Text(
                                  _formatTime(startTime!.toDate()),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isPaidContent && !hasActiveSubscription)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.lock,
                              color: Color(0xFFE53935),
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Premium Live Class',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Subscribe to join live sessions',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SubscriptionPlansScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE53935),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: const Text(
                                'Subscribe Now',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.isNegative) {
      return 'Started ${(-difference.inMinutes)}m ago';
    } else if (difference.inDays > 0) {
      return 'Starts in ${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return 'Starts in ${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return 'Starts in ${difference.inMinutes}m';
    } else {
      return 'Starting now';
    }
  }
}
