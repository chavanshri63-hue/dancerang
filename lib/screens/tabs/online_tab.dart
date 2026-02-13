part of '../home_screen.dart';

// Online Tab
class OnlineTab extends StatefulWidget {
  const OnlineTab({super.key});

  @override
  State<OnlineTab> createState() => _OnlineTabState();
}
class _OnlineTabState extends State<OnlineTab> {
  @override
  void initState() {
    super.initState();
    // If the user already purchased on Play but activation failed earlier,
    // restore purchases to trigger server verification again.
    IapService.instance.syncPurchases();
  }

  void _showSubscriptionPlans() {
    showDialog(
      context: context,
      builder: (context) => const _SubscriptionPlansDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stylesCollection = 'onlineStyles';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'Online Classes',
        leading: IconButton(
          icon: const Icon(Icons.live_tv, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LiveStreamingScreen()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VideoSearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OfflineDownloadsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroBanner(),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection(stylesCollection)
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Color(0xFFE53935)),
                  );
                }
                
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading styles: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                final styles = snapshot.data?.docs ?? [];
                
                if (styles.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No dance styles available',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                
                styles.sort((a, b) {
                  final aData = a.data();
                  final bData = b.data();
                  final aPriority = (aData['priority'] ?? 0) as int;
                  final bPriority = (bData['priority'] ?? 0) as int;
                  if (aPriority != bPriority) {
                    return aPriority.compareTo(bPriority);
                  }
                  final aName = (aData['name'] ?? '').toString().toLowerCase();
                  final bName = (bData['name'] ?? '').toString().toLowerCase();
                  return aName.compareTo(bName);
                });

                return Column(
                  children: [
                    ...styles.map((doc) {
                      final data = doc.data();
                      final style = DanceStyle(
                        id: doc.id,
                        name: data['name'] ?? '',
                        description: data['description'] ?? '',
                        icon: data['icon'] ?? 'directions_run',
                        color: data['color'] ?? '#E53935',
                        isActive: data['isActive'] ?? true,
                        priority: data['priority'] ?? 0,
                        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      );
                      return _buildDynamicStyleSection(style);
                    }).toList(),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Card(
      elevation: 8,
      shadowColor: const Color(0xFFE53935).withOpacity(0.2),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFFE53935).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      margin: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFE53935).withOpacity(0.12),
              const Color(0xFF4F46E5).withOpacity(0.10),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.video_library_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Master Dance Styles',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Learn from the best instructors with premium video content',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C3A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF3A3A4A).withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Welcome to DanceRang Online Learning',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyleSection(String styleName, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                styleName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StyleVideoScreen(styleName: styleName, styleColor: color),
                    ),
                  );
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: _VideoSectionBuilder(
            styleName: styleName,
            icon: icon,
            color: color,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDynamicStyleSection(DanceStyle style) {
    final icon = DanceStylesService.getIconData(style.icon);
    final color = DanceStylesService.getColorFromHex(style.color);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (style.description.isNotEmpty)
                      Text(
                        style.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StyleVideoScreen(
                        styleName: style.name, 
                        styleColor: color,
                      ),
                    ),
                  );
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: _VideoSectionBuilder(
            styleName: style.name,
            icon: icon,
            color: color,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionContent(String section) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: section == 'All' 
          ? FirebaseFirestore.instance
              .collection('onlineVideos')
              .where('status', isEqualTo: 'published')
              .orderBy('createdAt', descending: true)
              .snapshots()
          : FirebaseFirestore.instance
              .collection('onlineVideos')
              .where('section', isEqualTo: section)
              .where('status', isEqualTo: 'published')
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
        }
        
        final docs = snapshot.data?.docs ?? [];
        
        // Debug logging
        for (var doc in docs) {
          final data = doc.data();
        }
        
        if (docs.isEmpty) {
          return _buildEmptyState(section);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final d = docs[index].data();
            final title = (d['title'] ?? '').toString();
            final desc = (d['description'] ?? '').toString();
            final thumb = (d['thumbnail'] ?? '').toString();
            final isLive = d['isLive'] == true;
            final isPaidContent = d['isPaidContent'] == true;
            final videoSection = (d['section'] ?? '').toString();
            final videoUrl = (d['videoUrl'] ?? d['url'] ?? '').toString();
            final views = (d['views'] ?? 0) as int;
            final likes = (d['likes'] ?? 0) as int;
            final videoId = docs[index].id;
            
            return _OnlineVideoCard(
              videoId: videoId,
              title: title, 
              description: desc, 
              thumbnail: thumb, 
              videoUrl: videoUrl,
              isLive: isLive,
              isPaidContent: isPaidContent,
              section: videoSection,
              views: views,
              likes: likes,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String section) {
    final sectionIcons = {
      'All': Icons.video_library,
      'Tutorials': Icons.school,
      'Choreography': Icons.directions_run,
      'Practice': Icons.fitness_center,
      'Live Recordings': Icons.live_tv,
      'Announcements': Icons.campaign,
    };

    final sectionDescriptions = {
      'All': 'No videos available yet',
      'Tutorials': 'No tutorial videos yet',
      'Choreography': 'No choreography videos yet', 
      'Practice': 'No practice videos yet',
      'Live Recordings': 'No live recordings yet',
      'Announcements': 'No announcements yet',
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            sectionIcons[section] ?? Icons.video_library,
            size: 64,
            color: const Color(0xFF6B7280),
          ),
          const SizedBox(height: 16),
          Text(
            sectionDescriptions[section] ?? 'No videos available',
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new content',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
class _OnlineVideoCard extends StatelessWidget {
  final String videoId;
  final String title;
  final String description;
  final String thumbnail;
  final String videoUrl;
  final bool isLive;
  final bool isPaidContent;
  final String section;
  final int views;
  final int likes;
  const _OnlineVideoCard({
    required this.videoId,
    required this.title, 
    required this.description, 
    required this.thumbnail, 
    required this.videoUrl,
    required this.isLive,
    required this.isPaidContent,
    required this.section,
    required this.views,
    required this.likes,
  });

  Future<bool> _getSubscriptionStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return false;
      }

      // Use a more efficient query with timeout
      final subscriptionSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .where('endDate', isGreaterThan: Timestamp.now())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 3));

      return subscriptionSnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use cached subscription status instead of StreamBuilder for each card
    return FutureBuilder<bool>(
      future: _getSubscriptionStatus(),
      builder: (context, subscriptionSnapshot) {
        final hasActiveSubscription = subscriptionSnapshot.hasData && 
            subscriptionSnapshot.data == true;
        
        // Lock only paid videos if subscription is missing
        final isLocked = isPaidContent && !hasActiveSubscription;

        return Card(
          elevation: 6,
          shadowColor: const Color(0xFF4F46E5).withOpacity( 0.15),
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isLocked 
                ? const Color(0xFFE53935).withOpacity(0.3)
                : const Color(0xFF4F46E5).withOpacity(0.22)
            ),
          ),
          child: InkWell(
            onTap: () {
              if (!isLocked) {
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
                              child: Image.network(
                                thumbnail, 
                                fit: BoxFit.cover,
                                color: isLocked ? Colors.grey : null,
                                colorBlendMode: isLocked ? BlendMode.saturation : null,
                              ),
                            )
                          : Icon(
                              Icons.play_circle_fill, 
                              color: isLocked ? Colors.grey : const Color(0xFFE53935), 
                              size: 32
                            ),
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
                                  style: TextStyle(
                                    color: isLocked ? Colors.grey : Colors.white, 
                                    fontWeight: FontWeight.w600
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isLive && !isLocked)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935).withOpacity( 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE53935).withOpacity( 0.5)),
                                  ),
                                  child: const Text('LIVE', style: TextStyle(color: Color(0xFFE53935), fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (section.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLocked 
                                  ? Colors.grey.withOpacity(0.2)
                                  : const Color(0xFF4F46E5).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                section,
                                style: TextStyle(
                                  color: isLocked ? Colors.grey : const Color(0xFF4F46E5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            description, 
                            style: TextStyle(
                              color: isLocked ? Colors.grey : Colors.white70, 
                              fontSize: 12
                            ), 
                            maxLines: 2, 
                            overflow: TextOverflow.ellipsis
                          ),
                          if (isLocked) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.lock,
                                  color: Colors.grey,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Subscribe to unlock',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isLocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
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
                            'Subscribe to access all videos',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => const _SubscriptionPlansDialog(),
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
                              'Subscribe Now',
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
        );
      },
    );
  }
}
class _VideoSectionBuilder extends StatelessWidget {
  final String styleName;
  final IconData icon;
  final Color color;

  const _VideoSectionBuilder({
    required this.styleName,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null && !DemoSession.isActive) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              'Please login to view videos',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('onlineVideos')
          .where('section', isEqualTo: styleName)
          .where('status', isEqualTo: 'published')
          .snapshots(),
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading videos: ${snapshot.error}',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // Client-side sorting and limiting while index builds
        final sortedDocs = docs
          ..sort((a, b) {
            final aTime = a.data()['createdAt'] as Timestamp?;
            final bTime = b.data()['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // Descending order
          });
        
        final limitedDocs = sortedDocs.take(10).toList();

        if (limitedDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: color.withOpacity(0.5)),
                const SizedBox(height: 8),
                Text(
                  'No videos yet',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          key: ValueKey('videos_$styleName'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: limitedDocs.length,
          itemBuilder: (context, index) {
            final d = limitedDocs[index].data();
            final title = (d['title'] ?? '').toString();
            final desc = (d['description'] ?? '').toString();
            final thumb = (d['thumbnail'] ?? '').toString();
            final isLive = d['isLive'] == true;
            final isPaidContent = d['isPaidContent'] == true;
            final videoUrl = (d['videoUrl'] ?? d['url'] ?? '').toString();
            final views = (d['views'] ?? 0) as int;
            final likes = (d['likes'] ?? 0) as int;
            final videoId = limitedDocs[index].id;
            
            return Container(
              width: 180,
              height: 200,
              margin: const EdgeInsets.only(right: 12),
              child: _StyleVideoCard(
                videoId: videoId,
                title: title,
                description: desc,
                thumbnail: thumb,
                videoUrl: videoUrl,
                isLive: isLive,
                isPaidContent: isPaidContent,
                views: views,
                likes: likes,
                styleColor: color,
              ),
            );
          },
        );
      },
    );
  }
}

class _StyleVideoCard extends StatelessWidget {
  final String videoId;
  final String title;
  final String description;
  final String thumbnail;
  final String videoUrl;
  final bool isLive;
  final bool isPaidContent;
  final int views;
  final int likes;
  final Color styleColor;

  const _StyleVideoCard({
    required this.videoId,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.videoUrl,
    required this.isLive,
    required this.isPaidContent,
    required this.views,
    required this.likes,
    required this.styleColor,
  });

  Future<bool> _getSubscriptionStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return false;
      }

      // Use a more efficient query with timeout
      final subscriptionSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .where('endDate', isGreaterThan: Timestamp.now())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 3));

      return subscriptionSnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _getSubscriptionStatus(),
      builder: (context, subscriptionSnapshot) {
        final hasActiveSubscription = subscriptionSnapshot.hasData && 
            subscriptionSnapshot.data == true;
        
        // Lock only paid videos if subscription is missing
        final isLocked = isPaidContent && !hasActiveSubscription;

        return Card(
          elevation: 4,
          shadowColor: isLocked 
            ? const Color(0xFFE53935).withOpacity(0.15)
            : styleColor.withOpacity(0.15),
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isLocked 
                ? const Color(0xFFE53935).withOpacity(0.3)
                : styleColor.withOpacity(0.22)
            ),
          ),
          child: InkWell(
            onTap: () {
              if (!isLocked) {
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
                      section: 'Style',
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF262626),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: thumbnail.isNotEmpty
                            ? ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                child: Image.network(
                                  thumbnail, 
                                  fit: BoxFit.cover, 
                                  width: double.infinity,
                                  color: isLocked ? Colors.grey : null,
                                  colorBlendMode: isLocked ? BlendMode.saturation : null,
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.play_circle_fill, 
                                  color: isLocked ? Colors.grey : styleColor, 
                                  size: 32
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title.isEmpty ? 'Untitled' : title,
                              style: TextStyle(
                                color: isLocked ? Colors.grey : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isLocked) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.lock,
                                    color: Colors.grey,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Subscribe',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (isLive && !isLocked)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (isLocked)
                  Positioned.fill(
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => const _SubscriptionPlansDialog(),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock,
                                color: const Color(0xFFE53935),
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Subscribe',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
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
}
