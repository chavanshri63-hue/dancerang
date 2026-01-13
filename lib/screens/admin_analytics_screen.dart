import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glassmorphism_app_bar.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> with TickerProviderStateMixin {
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
        title: 'Analytics Dashboard',
        actions: [
          DropdownButton<String>(
            value: _selectedTimeRange,
            dropdownColor: const Color(0xFF1B1B1B),
            style: const TextStyle(color: Colors.white),
            items: const [
              DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
              DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
              DropdownMenuItem(value: '90d', child: Text('Last 90 days')),
              DropdownMenuItem(value: '1y', child: Text('Last year')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedTimeRange = value ?? '7d';
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE53935),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Videos'),
            Tab(text: 'Users'),
            Tab(text: 'Revenue'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildVideosTab(),
          _buildUsersTab(),
          _buildRevenueTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 24),
          _buildTopVideosChart(),
          const SizedBox(height: 24),
          _buildUserEngagementChart(),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('onlineVideos').snapshots(),
      builder: (context, videoSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, userSnapshot) {
            final totalVideos = videoSnapshot.data?.docs.length ?? 0;
            final totalUsers = userSnapshot.data?.docs.length ?? 0;
            final totalViews = videoSnapshot.data?.docs.fold<int>(0, (sum, doc) {
              return sum + ((doc.data()['views'] ?? 0) as int);
            }) ?? 0;
            final totalLikes = videoSnapshot.data?.docs.fold<int>(0, (sum, doc) {
              return sum + ((doc.data()['likes'] ?? 0) as int);
            }) ?? 0;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  'Total Videos',
                  totalVideos.toString(),
                  Icons.video_library,
                  const Color(0xFF4F46E5),
                ),
                _buildStatCard(
                  'Total Users',
                  totalUsers.toString(),
                  Icons.people,
                  const Color(0xFF10B981),
                ),
                _buildStatCard(
                  'Total Views',
                  _formatNumber(totalViews),
                  Icons.visibility,
                  const Color(0xFFF59E0B),
                ),
                _buildStatCard(
                  'Total Likes',
                  _formatNumber(totalLikes),
                  Icons.favorite,
                  const Color(0xFFE53935),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 6,
      shadowColor: color.withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.22)),
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
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopVideosChart() {
    return Card(
      elevation: 6,
      shadowColor: const Color(0xFF4F46E5).withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Performing Videos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('onlineVideos')
                  .orderBy('views', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No videos yet',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return Column(
                  children: docs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final doc = entry.value;
                    final data = doc.data();
                    final title = (data['title'] ?? 'Untitled').toString();
                    final views = (data['views'] ?? 0) as int;
                    final likes = (data['likes'] ?? 0) as int;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B1B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Color(0xFF4F46E5),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.visibility, color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Text('$views', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    const SizedBox(width: 12),
                                    Icon(Icons.favorite, color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Text('$likes', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserEngagementChart() {
    return Card(
      elevation: 6,
      shadowColor: const Color(0xFF10B981).withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Engagement',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
                }
                
                final docs = snapshot.data?.docs ?? [];
                final totalUsers = docs.length;
                final activeUsers = docs.where((doc) {
                  final data = doc.data();
                  final lastActive = data['lastActive'] as Timestamp?;
                  if (lastActive == null) return false;
                  final daysSinceActive = DateTime.now().difference(lastActive.toDate()).inDays;
                  return daysSinceActive <= 7;
                }).length;
                
                final engagementRate = totalUsers > 0 ? (activeUsers / totalUsers * 100) : 0.0;

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildEngagementMetric(
                            'Total Users',
                            totalUsers.toString(),
                            const Color(0xFF4F46E5),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildEngagementMetric(
                            'Active Users',
                            activeUsers.toString(),
                            const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B1B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Engagement Rate',
                                style: TextStyle(color: Colors.white70),
                              ),
                              Text(
                                '${engagementRate.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: engagementRate / 100,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementMetric(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildVideoAnalytics(),
        ],
      ),
    );
  }

  Widget _buildVideoAnalytics() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('onlineVideos').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
        }
        
        final docs = snapshot.data?.docs ?? [];
        
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No videos to analyze',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        // Calculate analytics
        final totalVideos = docs.length;
        final publishedVideos = docs.where((doc) => doc.data()['status'] == 'published').length;
        final draftVideos = docs.where((doc) => doc.data()['status'] == 'draft').length;
        final paidVideos = docs.where((doc) => doc.data()['isPaidContent'] == true).length;
        final freeVideos = docs.where((doc) => doc.data()['isPaidContent'] == false).length;
        final liveVideos = docs.where((doc) => doc.data()['isLive'] == true).length;

        return Column(
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard('Published', publishedVideos.toString(), Icons.publish, const Color(0xFF10B981)),
                _buildStatCard('Drafts', draftVideos.toString(), Icons.edit, const Color(0xFFF59E0B)),
                _buildStatCard('Paid Content', paidVideos.toString(), Icons.paid, const Color(0xFFE53935)),
                _buildStatCard('Free Content', freeVideos.toString(), Icons.free_breakfast, const Color(0xFF4F46E5)),
              ],
            ),
            const SizedBox(height: 24),
            _buildVideoPerformanceTable(docs),
          ],
        );
      },
    );
  }

  Widget _buildVideoPerformanceTable(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return Card(
      elevation: 6,
      shadowColor: const Color(0xFF4F46E5).withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Video Performance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...docs.take(10).map((doc) {
              final data = doc.data();
              final title = (data['title'] ?? 'Untitled').toString();
              final views = (data['views'] ?? 0) as int;
              final likes = (data['likes'] ?? 0) as int;
              final section = (data['section'] ?? '').toString();
              final publishStatus = (data['status'] ?? 'draft').toString();
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        section,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '$views',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '$likes',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: publishStatus == 'published' 
                              ? const Color(0xFF10B981).withOpacity(0.2)
                              : const Color(0xFFF59E0B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          publishStatus,
                          style: TextStyle(
                            color: publishStatus == 'published' 
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildUserAnalytics(),
        ],
      ),
    );
  }

  Widget _buildUserAnalytics() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(1000).snapshots(), // Limit for performance
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
        }
        
        final docs = snapshot.data?.docs ?? [];
        
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No users to analyze',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        // Calculate user analytics
        final totalUsers = docs.length;
        final students = docs.where((doc) => doc.data()['role'] == 'student').length;
        final faculty = docs.where((doc) => doc.data()['role'] == 'faculty').length;
        final admins = docs.where((doc) => doc.data()['role'] == 'admin').length;

        return Column(
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard('Students', students.toString(), Icons.school, const Color(0xFF4F46E5)),
                _buildStatCard('Faculty', faculty.toString(), Icons.person, const Color(0xFF10B981)),
                _buildStatCard('Admins', admins.toString(), Icons.admin_panel_settings, const Color(0xFFE53935)),
                _buildStatCard('Total Users', totalUsers.toString(), Icons.people, const Color(0xFFF59E0B)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildRevenueTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRevenueAnalytics(),
        ],
      ),
    );
  }

  Widget _buildRevenueAnalytics() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('subscriptions', isNull: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
        }
        
        final docs = snapshot.data?.docs ?? [];
        
        // Calculate revenue metrics
        final totalSubscribers = docs.length;
        final monthlyRevenue = totalSubscribers * 299; // Assuming ₹299/month
        final annualRevenue = monthlyRevenue * 12;

        return Column(
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard('Subscribers', totalSubscribers.toString(), Icons.subscriptions, const Color(0xFF4F46E5)),
                _buildStatCard('Monthly Revenue', '₹${_formatNumber(monthlyRevenue)}', Icons.monetization_on, const Color(0xFF10B981)),
                _buildStatCard('Annual Revenue', '₹${_formatNumber(annualRevenue)}', Icons.trending_up, const Color(0xFFE53935)),
                _buildStatCard('Conversion Rate', '${(totalSubscribers / 100 * 100).toStringAsFixed(1)}%', Icons.percent, const Color(0xFFF59E0B)),
              ],
            ),
          ],
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
}
