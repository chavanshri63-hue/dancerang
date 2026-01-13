import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';
import 'video_player_screen.dart';
import 'subscription_plans_screen.dart';

class AIRecommendationsScreen extends StatefulWidget {
  const AIRecommendationsScreen({super.key});

  @override
  State<AIRecommendationsScreen> createState() => _AIRecommendationsScreenState();
}

class _AIRecommendationsScreenState extends State<AIRecommendationsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTimeRange = '7d';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        title: 'AI Recommendations',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4F46E5),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'For You'),
            Tab(text: 'Trending'),
            Tab(text: 'Similar'),
            Tab(text: 'New'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildForYouTab(),
          _buildTrendingTab(),
          _buildSimilarTab(),
          _buildNewTab(),
        ],
      ),
    );
  }

  Widget _buildForYouTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('watchHistory')
          .orderBy('lastWatchedAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, watchHistorySnapshot) {
        if (watchHistorySnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
        }

        final watchHistory = watchHistorySnapshot.data?.docs ?? [];
        
        if (watchHistory.isEmpty) {
          return _buildEmptyRecommendations();
        }

        // Get user's preferred styles from watch history
        final preferredStyles = _getPreferredStyles(watchHistory);
        
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('onlineVideos')
              .where('section', whereIn: preferredStyles.isNotEmpty ? preferredStyles : ['Bollywood', 'Hip-Hop', 'Contemporary'])
              .orderBy('views', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
            }
            
            final docs = snapshot.data?.docs ?? [];
            
            if (docs.isEmpty) {
              return _buildEmptyRecommendations();
            }

            return _buildRecommendationsList(docs, 'Personalized for You', Icons.auto_awesome);
          },
        );
      },
    );
  }

  Widget _buildTrendingTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('onlineVideos')
          .orderBy('views', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
        }
        
        final docs = snapshot.data?.docs ?? [];
        
        if (docs.isEmpty) {
          return _buildEmptyRecommendations();
        }

        return _buildRecommendationsList(docs, 'Trending Now', Icons.trending_up);
      },
    );
  }

  Widget _buildSimilarTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('watchHistory')
          .orderBy('lastWatchedAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, lastWatchedSnapshot) {
        if (lastWatchedSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
        }

        final lastWatched = lastWatchedSnapshot.data?.docs;
        
        if (lastWatched == null || lastWatched.isEmpty) {
          return _buildEmptyRecommendations();
        }

        final lastVideoId = lastWatched.first.data()['videoId'] as String;
        
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('onlineVideos')
              .doc(lastVideoId)
              .snapshots(),
          builder: (context, videoSnapshot) {
            if (!videoSnapshot.hasData) {
              return _buildEmptyRecommendations();
            }

            final videoData = videoSnapshot.data!.data();
            if (videoData == null) return _buildEmptyRecommendations();

            final section = videoData['section'] as String? ?? 'Bollywood';
            
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('onlineVideos')
                  .where('section', isEqualTo: section)
                  .orderBy('likes', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, similarSnapshot) {
                if (similarSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
                }
                
                final docs = similarSnapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return _buildEmptyRecommendations();
                }

                return _buildRecommendationsList(docs, 'Similar to Your Last Watch', Icons.compare_arrows);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNewTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('onlineVideos')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
        }
        
        final docs = snapshot.data?.docs ?? [];
        
        if (docs.isEmpty) {
          return _buildEmptyRecommendations();
        }

        return _buildRecommendationsList(docs, 'Newly Added', Icons.new_releases);
      },
    );
  }

  Widget _buildRecommendationsList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, String title, IconData icon) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title, icon),
          const SizedBox(height: 16),
          ...docs.map((doc) {
            final d = doc.data();
            final title = (d['title'] ?? '').toString();
            final desc = (d['description'] ?? '').toString();
            final thumb = (d['thumbnail'] ?? '').toString();
            final isLive = d['isLive'] == true;
            final isPaidContent = d['isPaidContent'] == true;
            final videoUrl = (d['url'] ?? '').toString();
            final views = (d['views'] ?? 0) as int;
            final likes = (d['likes'] ?? 0) as int;
            final section = (d['section'] ?? '').toString();
            final videoId = doc.id;
            final createdAt = d['createdAt'] as Timestamp?;
            
            return _AIRecommendationCard(
              videoId: videoId,
              title: title,
              description: desc,
              thumbnail: thumb,
              videoUrl: videoUrl,
              isLive: isLive,
              isPaidContent: isPaidContent,
              views: views,
              likes: likes,
              section: section,
              createdAt: createdAt,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4F46E5).withOpacity(0.2),
            const Color(0xFF10B981).withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Powered by AI',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'AI',
              style: TextStyle(
                color: Color(0xFF4F46E5),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRecommendations() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 64,
              color: Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Building Your Recommendations',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Watch a few videos to get personalized recommendations',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _tabController.animateTo(3); // Go to New tab
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Explore New Videos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getPreferredStyles(List<QueryDocumentSnapshot<Map<String, dynamic>>> watchHistory) {
    final styleCounts = <String, int>{};
    
    for (final doc in watchHistory) {
      final data = doc.data();
      final videoId = data['videoId'] as String;
      
      // In a real implementation, you'd fetch the video data to get the section
      // For now, we'll use a simplified approach
      styleCounts['Bollywood'] = (styleCounts['Bollywood'] ?? 0) + 1;
    }
    
    // Return top 3 preferred styles
    final sortedStyles = styleCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedStyles.take(3).map((e) => e.key).toList();
  }
}

class _AIRecommendationCard extends StatelessWidget {
  final String videoId;
  final String title;
  final String description;
  final String thumbnail;
  final String videoUrl;
  final bool isLive;
  final bool isPaidContent;
  final int views;
  final int likes;
  final String section;
  final Timestamp? createdAt;

  const _AIRecommendationCard({
    required this.videoId,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.videoUrl,
    required this.isLive,
    required this.isPaidContent,
    required this.views,
    required this.likes,
    required this.section,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
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

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Card(
            elevation: 6,
            shadowColor: const Color(0xFF4F46E5).withOpacity(0.15),
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.22)),
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
                        isLive: isLive,
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
                  Row(
                    children: [
                      Container(
                        width: 160,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFF262626),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                        child: thumbnail.isNotEmpty
                            ? ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                                child: Image.network(thumbnail, fit: BoxFit.cover),
                              )
                            : const Center(
                                child: Icon(Icons.play_circle_fill, color: Color(0xFF4F46E5), size: 32),
                              ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title.isEmpty ? 'Untitled' : title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isLive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE53935).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFE53935).withOpacity(0.5)),
                                      ),
                                      child: const Text('LIVE', style: TextStyle(color: Color(0xFFE53935), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              Text(
                                description,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.visibility, color: Colors.white70, size: 14),
                                  const SizedBox(width: 4),
                                  Text('${_formatNumber(views)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  const SizedBox(width: 12),
                                  Icon(Icons.favorite, color: Colors.white70, size: 14),
                                  const SizedBox(width: 4),
                                  Text('${_formatNumber(likes)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  const Spacer(),
                                  if (createdAt != null)
                                    Text(
                                      _formatDate(createdAt!.toDate()),
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isPaidContent && !hasActiveSubscription)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.lock,
                                color: Color(0xFFE53935),
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Premium Content',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Subscribe to access',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SubscriptionPlansScreen()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE53935),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Subscribe',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
          ),
        );
      },
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
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
