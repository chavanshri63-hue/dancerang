import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';

class AdminAnalyticsDashboardScreen extends StatefulWidget {
  const AdminAnalyticsDashboardScreen({super.key});

  @override
  State<AdminAnalyticsDashboardScreen> createState() => _AdminAnalyticsDashboardScreenState();
}

class _AdminAnalyticsDashboardScreenState extends State<AdminAnalyticsDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _analytics = {};
  String _selectedPeriod = '7 days';
  String _selectedMetric = 'views';

  final List<String> _periods = ['7 days', '30 days', '90 days', '1 year'];
  final List<String> _metrics = ['views', 'likes', 'comments', 'downloads'];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Calculate date range
      final now = DateTime.now();
      final days = _getDaysFromPeriod(_selectedPeriod);
      final startDate = now.subtract(Duration(days: days));

      // Load video analytics
      final videosSnapshot = await FirebaseFirestore.instance
          .collection('onlineVideos')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(startDate))
          .get();

      // Load user analytics
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      // Load subscription analytics
      final subscriptionsSnapshot = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(startDate))
          .get();

      // Calculate metrics
      double totalViews = 0;
      double totalLikes = 0;
      double totalComments = 0;
      double totalDownloads = 0;
      Map<String, double> styleViews = {};
      Map<String, double> instructorViews = {};
      List<Map<String, dynamic>> topVideos = [];

      for (var doc in videosSnapshot.docs) {
        final data = doc.data();
        final views = data['views'] ?? 0;
        final likes = data['likes'] ?? 0;
        final comments = data['comments'] ?? 0;
        final downloads = data['downloads'] ?? 0;
        final style = data['danceStyle'] ?? 'Unknown';
        final instructor = data['instructor'] ?? 'Unknown';

        totalViews += views.toDouble();
        totalLikes += likes.toDouble();
        totalComments += comments.toDouble();
        totalDownloads += downloads.toDouble();

        styleViews[style] = (styleViews[style] ?? 0) + views.toDouble();
        instructorViews[instructor] = (instructorViews[instructor] ?? 0) + views.toDouble();

        topVideos.add({
          'id': doc.id,
          'title': data['title'] ?? 'Untitled',
          'views': views,
          'likes': likes,
          'style': style,
          'instructor': instructor,
        });
      }

      // Sort top videos
      topVideos.sort((a, b) => (b['views'] as int).compareTo(a['views'] as int));

      setState(() {
        _analytics = {
          'totalVideos': videosSnapshot.docs.length,
          'totalUsers': usersSnapshot.docs.length,
          'totalSubscriptions': subscriptionsSnapshot.docs.length,
          'totalViews': totalViews,
          'totalLikes': totalLikes,
          'totalComments': totalComments,
          'totalDownloads': totalDownloads,
          'styleViews': styleViews,
          'instructorViews': instructorViews,
          'topVideos': topVideos.take(10).toList(),
          'period': _selectedPeriod,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading analytics: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _getDaysFromPeriod(String period) {
    switch (period) {
      case '7 days':
        return 7;
      case '30 days':
        return 30;
      case '90 days':
        return 90;
      case '1 year':
        return 365;
      default:
        return 7;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Analytics Dashboard',
        actions: [
          DropdownButton<String>(
            value: _selectedPeriod,
            items: _periods.map((period) {
              return DropdownMenuItem(
                value: period,
                child: Text(period, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPeriod = value!;
              });
              _loadAnalytics();
            },
            underline: Container(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview Cards
                  _buildOverviewCards(),
                  const SizedBox(height: 20),
                  
                  // Charts Section
                  _buildChartsSection(),
                  const SizedBox(height: 20),
                  
                  // Top Videos
                  _buildTopVideosSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Videos',
          _analytics['totalVideos'].toString(),
          Icons.video_library,
          const Color(0xFFE53935),
        ),
        _buildMetricCard(
          'Total Views',
          _analytics['totalViews'].toString(),
          Icons.visibility,
          const Color(0xFF4F46E5),
        ),
        _buildMetricCard(
          'Total Likes',
          _analytics['totalLikes'].toString(),
          Icons.favorite,
          const Color(0xFF10B981),
        ),
        _buildMetricCard(
          'Total Users',
          _analytics['totalUsers'].toString(),
          Icons.people,
          const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance by Dance Style',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Style Views Chart
            _buildStyleChart(),
            const SizedBox(height: 20),
            
            Text(
              'Performance by Instructor',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Instructor Views Chart
            _buildInstructorChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleChart() {
    final styleViews = _analytics['styleViews'] as Map<String, double>;
    final sortedStyles = styleViews.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sortedStyles.take(5).map((entry) {
        final percentage = styleViews.values.isNotEmpty
            ? (entry.value / styleViews.values.reduce((a, b) => a + b)) * 100
            : 0.0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  entry.key,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              Expanded(
                flex: 5,
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE53935)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.value.toInt()}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInstructorChart() {
    final instructorViews = _analytics['instructorViews'] as Map<String, double>;
    final sortedInstructors = instructorViews.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sortedInstructors.take(5).map((entry) {
        final percentage = instructorViews.values.isNotEmpty
            ? (entry.value / instructorViews.values.reduce((a, b) => a + b)) * 100
            : 0.0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  entry.key,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              Expanded(
                flex: 5,
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.value.toInt()}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopVideosSection() {
    final topVideos = _analytics['topVideos'] as List<Map<String, dynamic>>;
    
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Performing Videos',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topVideos.length,
              itemBuilder: (context, index) {
                final video = topVideos[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
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
                              video['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${video['style']} • ${video['instructor']}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${video['views']} views',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${video['likes']} likes',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
