import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glassmorphism_app_bar.dart';

class VideoAnalyticsScreen extends StatefulWidget {
  final String videoId;
  final String videoTitle;
  
  const VideoAnalyticsScreen({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  @override
  State<VideoAnalyticsScreen> createState() => _VideoAnalyticsScreenState();
}

class _VideoAnalyticsScreenState extends State<VideoAnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _videoData;
  List<Map<String, dynamic>> _viewsHistory = [];
  List<Map<String, dynamic>> _likes = [];

  @override
  void initState() {
    super.initState();
    _loadVideoAnalytics();
  }

  Future<void> _loadVideoAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      // Load video data
      final videoDoc = await FirebaseFirestore.instance
          .collection('onlineVideos')
          .doc(widget.videoId)
          .get();

      if (videoDoc.exists) {
        setState(() {
          _videoData = videoDoc.data();
        });
      }

      // Load views history (last 30 days)
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      
      final viewsSnapshot = await FirebaseFirestore.instance
          .collection('videoViews')
          .where('videoId', isEqualTo: widget.videoId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('timestamp')
          .get();

      // Load likes
      final likesSnapshot = await FirebaseFirestore.instance
          .collection('videoLikes')
          .where('videoId', isEqualTo: widget.videoId)
          .get();

      // Process views history
      Map<String, int> dailyViews = {};
      for (var doc in viewsSnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final dateKey = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
        dailyViews[dateKey] = (dailyViews[dateKey] ?? 0) + 1;
      }

      // Process likes
      List<Map<String, dynamic>> likes = [];
      for (var doc in likesSnapshot.docs) {
        final data = doc.data();
        likes.add({
          'id': doc.id,
          'userName': data['userName'] ?? 'Anonymous',
          'createdAt': data['createdAt'],
        });
      }

      setState(() {
        _viewsHistory = dailyViews.entries.map((entry) {
          return {
            'date': entry.key,
            'views': entry.value,
          };
        }).toList();
        _likes = likes;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Video Analytics',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Overview
                  _buildVideoOverview(),
                  const SizedBox(height: 20),
                  
                  // Key Metrics
                  _buildKeyMetrics(),
                  const SizedBox(height: 20),
                  
                  // Views Chart
                  _buildViewsChart(),
                  const SizedBox(height: 20),
                  
                  // Comments section removed
                ],
              ),
            ),
    );
  }

  Widget _buildVideoOverview() {
    if (_videoData == null) return const SizedBox.shrink();
    
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.videoTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_videoData!['danceStyle'] ?? 'Unknown'} • ${_videoData!['instructor'] ?? 'Unknown'}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${_videoData!['duration'] ?? 0} minutes',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 16),
                Icon(Icons.visibility, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${_videoData!['views'] ?? 0} views',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 16),
                Icon(Icons.favorite, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${_videoData!['likes'] ?? 0} likes',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetrics() {
    final totalViews = _videoData?['views'] ?? 0;
    final totalLikes = _videoData?['likes'] ?? 0;
    final engagementRate = totalViews > 0 ? (totalLikes / totalViews * 100) : 0.0;
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Views',
          totalViews.toString(),
          Icons.visibility,
          const Color(0xFF4F46E5),
        ),
        _buildMetricCard(
          'Total Likes',
          totalLikes.toString(),
          Icons.favorite,
          const Color(0xFFE53935),
        ),
        _buildMetricCard(
          'Engagement',
          '${engagementRate.toStringAsFixed(1)}%',
          Icons.trending_up,
          const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewsChart() {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Views Over Time (Last 30 Days)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            if (_viewsHistory.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No view data available',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _viewsHistory.length,
                  itemBuilder: (context, index) {
                    final day = _viewsHistory[index];
                    final maxViews = _viewsHistory.isNotEmpty
                        ? _viewsHistory.map((d) => d['views'] as int).reduce((a, b) => a > b ? a : b)
                        : 1;
                    final height = (day['views'] as int) / maxViews * 150;
                    
                    return Container(
                      width: 40,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: height,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${day['views']}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

}
