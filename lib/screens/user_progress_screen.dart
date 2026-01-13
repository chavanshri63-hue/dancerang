import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';
import 'video_player_screen.dart';

class UserProgressScreen extends StatefulWidget {
  const UserProgressScreen({super.key});

  @override
  State<UserProgressScreen> createState() => _UserProgressScreenState();
}

class _UserProgressScreenState extends State<UserProgressScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'My Progress',
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE53935),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Watched'),
            Tab(text: 'In Progress'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWatchedVideos(),
          _buildInProgressVideos(),
          _buildCompletedVideos(),
        ],
      ),
    );
  }

  Widget _buildWatchedVideos() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('watchHistory')
          .orderBy('watchedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
        }
        
        final docs = snapshot.data?.docs ?? [];
        
        if (docs.isEmpty) {
          return _buildEmptyState('No watched videos yet', Icons.history);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final watchData = docs[index].data();
            final videoId = watchData['videoId'] as String;
            final watchedAt = watchData['watchedAt'] as Timestamp;
            final watchDuration = watchData['watchDuration'] as int? ?? 0;
            final totalDuration = watchData['totalDuration'] as int? ?? 0;
            final progress = totalDuration > 0 ? (watchDuration / totalDuration) : 0.0;
            
            return _buildWatchHistoryCard(
              videoId: videoId,
              watchedAt: watchedAt,
              progress: progress,
              watchDuration: watchDuration,
              totalDuration: totalDuration,
            );
          },
        );
      },
    );
  }

  Widget _buildInProgressVideos() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('watchHistory')
          .where('isCompleted', isEqualTo: false)
          .orderBy('lastWatchedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
        }
        
        final docs = snapshot.data?.docs ?? [];
        
        if (docs.isEmpty) {
          return _buildEmptyState('No videos in progress', Icons.play_circle_outline);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final watchData = docs[index].data();
            final videoId = watchData['videoId'] as String;
            final lastWatchedAt = watchData['lastWatchedAt'] as Timestamp;
            final watchDuration = watchData['watchDuration'] as int? ?? 0;
            final totalDuration = watchData['totalDuration'] as int? ?? 0;
            final progress = totalDuration > 0 ? (watchDuration / totalDuration) : 0.0;
            
            return _buildInProgressCard(
              videoId: videoId,
              lastWatchedAt: lastWatchedAt,
              progress: progress,
              watchDuration: watchDuration,
              totalDuration: totalDuration,
            );
          },
        );
      },
    );
  }

  Widget _buildCompletedVideos() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('watchHistory')
          .where('isCompleted', isEqualTo: true)
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
        }
        
        final docs = snapshot.data?.docs ?? [];
        
        if (docs.isEmpty) {
          return _buildEmptyState('No completed videos yet', Icons.check_circle_outline);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final watchData = docs[index].data();
            final videoId = watchData['videoId'] as String;
            final completedAt = watchData['completedAt'] as Timestamp;
            final totalDuration = watchData['totalDuration'] as int? ?? 0;
            
            return _buildCompletedCard(
              videoId: videoId,
              completedAt: completedAt,
              totalDuration: totalDuration,
            );
          },
        );
      },
    );
  }

  Widget _buildWatchHistoryCard({
    required String videoId,
    required Timestamp watchedAt,
    required double progress,
    required int watchDuration,
    required int totalDuration,
  }) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('onlineVideos').doc(videoId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final videoData = snapshot.data!.data();
        if (videoData == null) return const SizedBox.shrink();
        
        final title = (videoData['title'] ?? '').toString();
        final thumbnail = (videoData['thumbnail'] ?? '').toString();
        final section = (videoData['section'] ?? '').toString();
        final views = (videoData['views'] ?? 0) as int;
        final likes = (videoData['likes'] ?? 0) as int;
        final videoUrl = (videoData['url'] ?? '').toString();
        final isLive = videoData['isLive'] == true;
        final isPaidContent = videoData['isPaidContent'] == true;
        
        return _ProgressVideoCard(
          videoId: videoId,
          title: title,
          thumbnail: thumbnail,
          section: section,
          views: views,
          likes: likes,
          videoUrl: videoUrl,
          isLive: isLive,
          isPaidContent: isPaidContent,
          progress: progress,
          watchDuration: watchDuration,
          totalDuration: totalDuration,
          watchedAt: watchedAt,
          showProgress: true,
        );
      },
    );
  }

  Widget _buildInProgressCard({
    required String videoId,
    required Timestamp lastWatchedAt,
    required double progress,
    required int watchDuration,
    required int totalDuration,
  }) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('onlineVideos').doc(videoId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final videoData = snapshot.data!.data();
        if (videoData == null) return const SizedBox.shrink();
        
        final title = (videoData['title'] ?? '').toString();
        final thumbnail = (videoData['thumbnail'] ?? '').toString();
        final section = (videoData['section'] ?? '').toString();
        final views = (videoData['views'] ?? 0) as int;
        final likes = (videoData['likes'] ?? 0) as int;
        final videoUrl = (videoData['url'] ?? '').toString();
        final isLive = videoData['isLive'] == true;
        final isPaidContent = videoData['isPaidContent'] == true;
        
        return _ProgressVideoCard(
          videoId: videoId,
          title: title,
          thumbnail: thumbnail,
          section: section,
          views: views,
          likes: likes,
          videoUrl: videoUrl,
          isLive: isLive,
          isPaidContent: isPaidContent,
          progress: progress,
          watchDuration: watchDuration,
          totalDuration: totalDuration,
          watchedAt: lastWatchedAt,
          showProgress: true,
        );
      },
    );
  }

  Widget _buildCompletedCard({
    required String videoId,
    required Timestamp completedAt,
    required int totalDuration,
  }) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('onlineVideos').doc(videoId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final videoData = snapshot.data!.data();
        if (videoData == null) return const SizedBox.shrink();
        
        final title = (videoData['title'] ?? '').toString();
        final thumbnail = (videoData['thumbnail'] ?? '').toString();
        final section = (videoData['section'] ?? '').toString();
        final views = (videoData['views'] ?? 0) as int;
        final likes = (videoData['likes'] ?? 0) as int;
        final videoUrl = (videoData['url'] ?? '').toString();
        final isLive = videoData['isLive'] == true;
        final isPaidContent = videoData['isPaidContent'] == true;
        
        return _ProgressVideoCard(
          videoId: videoId,
          title: title,
          thumbnail: thumbnail,
          section: section,
          views: views,
          likes: likes,
          videoUrl: videoUrl,
          isLive: isLive,
          isPaidContent: isPaidContent,
          progress: 1.0,
          watchDuration: totalDuration,
          totalDuration: totalDuration,
          watchedAt: completedAt,
          showProgress: false,
          isCompleted: true,
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start watching videos to see your progress here',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProgressVideoCard extends StatelessWidget {
  final String videoId;
  final String title;
  final String thumbnail;
  final String section;
  final int views;
  final int likes;
  final String videoUrl;
  final bool isLive;
  final bool isPaidContent;
  final double progress;
  final int watchDuration;
  final int totalDuration;
  final Timestamp watchedAt;
  final bool showProgress;
  final bool isCompleted;

  const _ProgressVideoCard({
    required this.videoId,
    required this.title,
    required this.thumbnail,
    required this.section,
    required this.views,
    required this.likes,
    required this.videoUrl,
    required this.isLive,
    required this.isPaidContent,
    required this.progress,
    required this.watchDuration,
    required this.totalDuration,
    required this.watchedAt,
    required this.showProgress,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shadowColor: const Color(0xFF4F46E5).withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.22)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerScreen(
                videoId: videoId,
                title: title,
                description: '',
                videoUrl: videoUrl,
                thumbnail: thumbnail,
                isLive: isLive,
                isPaidContent: isPaidContent,
                section: section,
                views: views,
                likes: likes,
              ),
            ),
          );
        },
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 120,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: thumbnail.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(thumbnail, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.play_circle_fill, color: Color(0xFF4F46E5), size: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title.isEmpty ? 'Untitled' : title,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCompleted)
                              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                          ],
                        ),
                        const SizedBox(height: 4),
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
                        const SizedBox(height: 8),
                        if (showProgress) ...[
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isCompleted ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        Row(
                          children: [
                            Icon(Icons.visibility, color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text('$views', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(width: 12),
                            Icon(Icons.favorite, color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text('$likes', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const Spacer(),
                            Text(
                              _formatDate(watchedAt.toDate()),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isCompleted)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                  ),
                  child: const Text(
                    'COMPLETED',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 10,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
