import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/dance_styles_service.dart';
import 'admin_analytics_dashboard_screen.dart';
import 'bulk_edit_videos_screen.dart';
import 'video_analytics_screen.dart';

class AdminOnlineManagementScreen extends StatefulWidget {
  const AdminOnlineManagementScreen({super.key});

  @override
  State<AdminOnlineManagementScreen> createState() => _AdminOnlineManagementScreenState();
}

class _AdminOnlineManagementScreenState extends State<AdminOnlineManagementScreen> with TickerProviderStateMixin {
  String _query = '';
  String _selectedSection = 'All';
  String _selectedStatus = 'All';
  bool _showPaidOnly = false;
  bool _showLiveOnly = false;
  String _sortBy = 'createdAt';
  bool _sortDescending = true;
  List<String> _selectedVideos = [];
  bool _isBulkMode = false;
  late TabController _tabController;

  final List<String> _sections = ['All'];

  final List<String> _statuses = ['All', 'draft', 'scheduled', 'published'];
  final List<String> _sortOptions = ['createdAt', 'title', 'views', 'likes', 'section'];

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
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Online Management',
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE53935),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Videos', icon: Icon(Icons.video_library)),
            Tab(text: 'Styles', icon: Icon(Icons.style)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
            Tab(text: 'Live', icon: Icon(Icons.live_tv)),
          ],
        ),
        actions: [
          if (_isBulkMode) ...[
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _selectedVideos.isNotEmpty ? _bulkDelete : null,
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: _selectedVideos.isNotEmpty ? _bulkEdit : null,
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => setState(() {
                _isBulkMode = false;
                _selectedVideos.clear();
              }),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              onPressed: _showFilterDialog,
            ),
            IconButton(
              icon: const Icon(Icons.select_all, color: Colors.white),
              onPressed: () => setState(() => _isBulkMode = true),
            ),
          ],
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_isBulkMode) ...[
            FloatingActionButton(
              backgroundColor: const Color(0xFF10B981),
              onPressed: _bulkPublish,
              child: const Icon(Icons.publish, color: Colors.white),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              backgroundColor: const Color(0xFFF59E0B),
              onPressed: _bulkUnpublish,
              child: const Icon(Icons.unpublished, color: Colors.white),
            ),
            const SizedBox(height: 8),
          ],
        FloatingActionButton(
          backgroundColor: const Color(0xFFE53935),
          onPressed: _handleAddButton,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Videos Tab
          Column(
            children: [
              // Search and Filter Bar
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search videos (title, tags, instructor)...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _query = ''),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1B1B1B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Styles row (real data)
                    _buildSectionChips(),
                    const SizedBox(height: 8),
                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Status: $_selectedStatus', _showStatusFilter),
                          const SizedBox(width: 8),
                          _buildFilterChip('Sort: ${_sortBy} ${_sortDescending ? '↓' : '↑'}', _showSortFilter),
                          const SizedBox(width: 8),
                          if (_showPaidOnly) _buildFilterChip('Paid Only', () => setState(() => _showPaidOnly = false)),
                          if (_showLiveOnly) _buildFilterChip('Live Only', () => setState(() => _showLiveOnly = false)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Stats Bar
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('onlineVideos').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          _buildStatCard('Total', 0),
                          const SizedBox(width: 8),
                          _buildStatCard('Published', 0),
                          const SizedBox(width: 8),
                          _buildStatCard('Draft', 0),
                          const SizedBox(width: 8),
                          _buildStatCard('Live', 0),
                        ],
                      ),
                    );
                  }
                  
                  final docs = snapshot.data?.docs ?? [];
                  final totalVideos = docs.length;
                  final publishedVideos = docs.where((doc) => doc.data()['status'] == 'published').length;
                  final draftVideos = docs.where((doc) => doc.data()['status'] == 'draft').length;
                  final liveVideos = docs.where((doc) => doc.data()['isLive'] == true).length;
                  
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _buildStatCard('Total', totalVideos),
                        const SizedBox(width: 8),
                        _buildStatCard('Published', publishedVideos),
                        const SizedBox(width: 8),
                        _buildStatCard('Draft', draftVideos),
                        const SizedBox(width: 8),
                        _buildStatCard('Live', liveVideos),
                      ],
                    ),
                  );
                },
              ),
              // Videos List
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('onlineVideos')
                      .orderBy(_sortBy, descending: _sortDescending)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
                    }
                    final docs = (snapshot.data?.docs ?? [])
                        .where((d) {
                          final data = d.data();
                          // Search filter
                          if (_query.isNotEmpty) {
                            final title = (data['title'] ?? '').toString().toLowerCase();
                            final tags = (data['tags'] ?? []).join(' ').toString().toLowerCase();
                            final instructor = (data['instructor'] ?? '').toString().toLowerCase();
                            if (!title.contains(_query) && !tags.contains(_query) && !instructor.contains(_query)) {
                              return false;
                            }
                          }
                          // Section filter
                          if (_selectedSection != 'All') {
                            if ((data['section'] ?? '').toString() != _selectedSection) return false;
                          }
                          // Status filter
                          if (_selectedStatus != 'All') {
                            if ((data['status'] ?? 'published').toString() != _selectedStatus) return false;
                          }
                          // Paid content filter
                          if (_showPaidOnly && data['isPaidContent'] != true) return false;
                          // Live filter
                          if (_showLiveOnly && data['isLive'] != true) return false;
                          return true;
                        })
                        .toList();

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('No online videos found', style: TextStyle(color: Colors.white70)),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                      },
                      color: const Color(0xFFE53935),
                      child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final id = docs[index].id;
                        final title = (data['title'] ?? '').toString();
                        final description = (data['description'] ?? '').toString();
                        final url = (data['videoUrl'] ?? data['url'] ?? '').toString();
                        final thumb = (data['thumbnail'] ?? '').toString();
                        final isLive = data['isLive'] == true;
                        final isPaidContent = data['isPaidContent'] == true;
                        final status = (data['status'] ?? 'published').toString();
                        final section = (data['section'] ?? '').toString();
                        final instructor = (data['instructor'] ?? '').toString();
                        final views = (data['views'] ?? 0) as int;
                        final likes = (data['likes'] ?? 0) as int;
                        final duration = (data['duration'] ?? 0) as int;
                        final tags = List<String>.from(data['tags'] ?? []);

                        return _videoTile(
                          id: id,
                          title: title,
                          description: description,
                          url: url,
                          thumbnail: thumb,
                          isLive: isLive,
                          isPaidContent: isPaidContent,
                          status: status,
                          section: section,
                          instructor: instructor,
                          views: views,
                          likes: likes,
                          duration: duration,
                          tags: tags,
                        );
                      },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // Styles Tab
          _buildStylesTab(),
          // Analytics Tab
          _buildAnalyticsTab(),
          // Live Streaming Tab
          _buildLiveStreamingTab(),
        ],
      ),
    );
  }

  Widget _videoTile({
    required String id,
    required String title,
    required String description,
    required String url,
    required String thumbnail,
    required bool isLive,
    required bool isPaidContent,
    required String status,
    required String section,
    required String instructor,
    required int views,
    required int likes,
    required int duration,
    required List<String> tags,
  }) {
    final isSelected = _selectedVideos.contains(id);
    
    return Card(
      elevation: 6,
      shadowColor: isSelected 
          ? const Color(0xFFE53935).withOpacity(0.3)
          : const Color(0xFF4F46E5).withOpacity(0.15),
      color: isSelected 
          ? const Color(0xFFE53935).withOpacity(0.1)
          : Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected 
              ? const Color(0xFFE53935)
              : const Color(0xFF4F46E5).withOpacity(0.22),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: _isBulkMode ? () => _toggleVideoSelection(id) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Selection checkbox (bulk mode)
              if (_isBulkMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleVideoSelection(id),
                  activeColor: const Color(0xFFE53935),
                ),
                const SizedBox(width: 8),
              ],
              // Thumbnail
              Container(
                width: 80,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: thumbnail.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(thumbnail, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.play_circle_fill, color: Color(0xFFE53935), size: 32),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isEmpty ? 'Untitled' : title,
                            style: const TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(status),
                        if (isLive) ...[
                          const SizedBox(width: 4),
                          _buildLiveChip(),
                        ],
                        if (isPaidContent) ...[
                          const SizedBox(width: 4),
                          _buildPaidChip(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Description
                    Text(
                      description,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Meta info
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildMetaChip(Icons.person, instructor.isNotEmpty ? instructor : 'Unknown'),
                        _buildMetaChip(Icons.category, section),
                        _buildMetaChip(Icons.visibility, '$views views'),
                        _buildMetaChip(Icons.favorite, '$likes likes'),
                        if (duration > 0) _buildMetaChip(Icons.timer, _formatDuration(duration)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Tags
                    if (tags.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: tags.take(3).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.16),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                          ),
                          child: Text(
                            '#$tag',
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 10),
                          ),
                        )).toList(),
                      ),
                  ],
                ),
              ),
              // Actions
              if (!_isBulkMode) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  color: const Color(0xFF1B1B1B),
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  onSelected: (v) => _handleVideoAction(v, id),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate', style: TextStyle(color: Colors.white))),
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Text(
                        status == 'published' ? 'Unpublish' : 'Publish',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const PopupMenuItem(value: 'toggle_live', child: Text('Toggle Live', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'analytics', child: Text('View Analytics', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleAddButton() {
    switch (_tabController.index) {
      case 0: // Videos tab
        _openCreateDialog();
        break;
      case 1: // Styles tab
        _addNewStyle();
        break;
      case 2: // Analytics tab
        _showAnalyticsInfo();
        break;
      case 3: // Live Streaming tab
        _startLiveStream();
        break;
    }
  }

  Future<void> _openCreateDialog() async {
    await showDialog(context: context, builder: (_) => const _EditOnlineVideoDialog());
  }

  void _showAnalyticsInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminAnalyticsDashboardScreen(),
      ),
    );
  }

  void _startLiveStream() {
    showDialog(
      context: context,
      builder: (context) => _LiveStreamDialog(),
    );
  }

  Widget _buildLiveStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStreamCard(String id, Map<String, dynamic> data) {
    final title = data['title'] ?? 'Live Class';
    final instructor = data['instructor'] ?? 'Unknown';
    final isActive = data['isActive'] ?? false;
    final viewerCount = data['viewerCount'] ?? 0;
    final createdAt = data['createdAt'] as Timestamp?;
    
    return Card(
      elevation: 4,
      color: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Colors.red : Colors.grey,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.red : Colors.grey,
          child: Icon(
            isActive ? Icons.live_tv : Icons.schedule,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instructor: $instructor',
              style: const TextStyle(color: Colors.white70),
            ),
            if (isActive) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.people, color: Colors.blue, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$viewerCount viewers',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          color: const Color(0xFF1B1B1B),
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          onSelected: (action) => _handleLiveStreamAction(action, id, data),
          itemBuilder: (context) => [
            if (isActive) ...[
              const PopupMenuItem(
                value: 'stop',
                child: Text('Stop Stream', style: TextStyle(color: Colors.red)),
              ),
              const PopupMenuItem(
                value: 'viewers',
                child: Text('View Viewers', style: TextStyle(color: Colors.white)),
              ),
            ] else ...[
              const PopupMenuItem(
                value: 'start',
                child: Text('Start Stream', style: TextStyle(color: Colors.green)),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit', style: TextStyle(color: Colors.white)),
              ),
            ],
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLiveStreamAction(String action, String streamId, Map<String, dynamic> data) async {
    switch (action) {
      case 'start':
        await _startLiveStreamAction(streamId);
        break;
      case 'stop':
        await _stopLiveStreamAction(streamId);
        break;
      case 'viewers':
        _showViewersDialog(streamId, data);
        break;
      case 'edit':
        _editLiveStream(streamId);
        break;
      case 'delete':
        await _deleteLiveStream(streamId);
        break;
    }
  }

  Future<void> _startLiveStreamAction(String streamId) async {
    try {
      await FirebaseFirestore.instance
          .collection('liveStreams')
          .doc(streamId)
          .update({
        'isActive': true,
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Live stream started successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error starting live stream'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopLiveStreamAction(String streamId) async {
    try {
      await FirebaseFirestore.instance
          .collection('liveStreams')
          .doc(streamId)
          .update({
        'isActive': false,
        'endedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Live stream stopped successfully!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error stopping live stream'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showViewersDialog(String streamId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Live Viewers', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people, color: Colors.blue, size: 48),
            const SizedBox(height: 16),
            Text(
              '${data['viewerCount'] ?? 0} viewers are currently watching',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              data['title'] ?? 'Live Class',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _editLiveStream(String streamId) {
    showDialog(
      context: context,
      builder: (context) => _LiveStreamDialog(streamId: streamId),
    );
  }

  Future<void> _deleteLiveStream(String streamId) async {
    try {
      await FirebaseFirestore.instance
          .collection('liveStreams')
          .doc(streamId)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Live stream deleted successfully'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error deleting live stream'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openEditDialog(String id) async {
    await showDialog(context: context, builder: (_) => _EditOnlineVideoDialog(videoId: id));
  }

  Future<void> _deleteVideo(String id) async {
    await FirebaseFirestore.instance.collection('onlineVideos').doc(id).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video deleted'), backgroundColor: Colors.red));
  }

  Future<void> _toggleLive(String id, bool isLive) async {
    await FirebaseFirestore.instance.collection('onlineVideos').doc(id).set({
      'isLive': !isLive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Helper methods for UI components
  Widget _buildFilterChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF404040)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
    );
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Widget _buildSectionChips() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('onlineStyles')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final styles = snapshot.data?.docs ?? [];
        final seen = <String>{};
        final sections = <String>[];
        for (final doc in styles) {
          final data = doc.data();
          final name = (data['name'] as String? ?? '').trim();
          if (name.isEmpty) continue;
          final normalized = name.toLowerCase();
          if (seen.add(normalized)) {
            sections.add(name);
          }
        }
        sections.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        final allSections = ['All', ...sections];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: allSections.map((section) {
              final isSelected = _selectedSection == section;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedSection = section),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE53935).withOpacity(0.15)
                          : const Color(0xFF1B1B1B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFE53935) : const Color(0xFF404040),
                      ),
                    ),
                    child: Text(
                      section,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, int count) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF404040)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: const TextStyle(
                color: Color(0xFFE53935),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'published':
        color = const Color(0xFF10B981);
        break;
      case 'draft':
        color = const Color(0xFFF59E0B);
        break;
      case 'scheduled':
        color = const Color(0xFF3B82F6);
        break;
      default:
        color = const Color(0xFF6B7280);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLiveChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935).withOpacity(0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE53935).withOpacity(0.5)),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(color: Color(0xFFE53935), fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPaidChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withOpacity(0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.5)),
      ),
      child: const Text(
        'PAID',
        style: TextStyle(color: Color(0xFF4F46E5), fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  // Filter dialog methods
  void _showSectionFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Select Section', style: TextStyle(color: Colors.white)),
        content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('onlineStyles')
              .where('isActive', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            final styles = snapshot.data?.docs ?? [];
            final seen = <String>{};
            final sections = <String>[];
            for (final doc in styles) {
              final data = doc.data();
              final name = (data['name'] as String? ?? '').trim();
              if (name.isEmpty) continue;
              final normalized = name.toLowerCase();
              if (seen.add(normalized)) {
                sections.add(name);
              }
            }
            sections.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            final allSections = ['All', ...sections];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: allSections.map((section) => ListTile(
                title: Text(section, style: const TextStyle(color: Colors.white)),
                selected: _selectedSection == section,
                onTap: () {
                  setState(() => _selectedSection = section);
                  Navigator.pop(context);
                },
              )).toList(),
            );
          },
        ),
      ),
    );
  }

  void _showStatusFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Select Status', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _statuses.map((status) => ListTile(
            title: Text(status, style: const TextStyle(color: Colors.white)),
            selected: _selectedStatus == status,
            onTap: () {
              setState(() => _selectedStatus = status);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showSortFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Sort By', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._sortOptions.map((option) => ListTile(
              title: Text(option, style: const TextStyle(color: Colors.white)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_sortBy == option) ...[
                    Icon(
                      _sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
                      color: const Color(0xFFE53935),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
              onTap: () {
                setState(() {
                  if (_sortBy == option) {
                    _sortDescending = !_sortDescending;
                  } else {
                    _sortBy = option;
                    _sortDescending = true;
                  }
                });
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Filters', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Paid Content Only', style: TextStyle(color: Colors.white)),
              value: _showPaidOnly,
              onChanged: (value) => setState(() => _showPaidOnly = value),
              activeColor: const Color(0xFFE53935),
            ),
            SwitchListTile(
              title: const Text('Live Content Only', style: TextStyle(color: Colors.white)),
              value: _showLiveOnly,
              onChanged: (value) => setState(() => _showLiveOnly = value),
              activeColor: const Color(0xFFE53935),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  // Bulk operations
  void _toggleVideoSelection(String videoId) {
    setState(() {
      if (_selectedVideos.contains(videoId)) {
        _selectedVideos.remove(videoId);
      } else {
        _selectedVideos.add(videoId);
      }
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedVideos.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Delete Videos', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete ${_selectedVideos.length} videos? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final batch = FirebaseFirestore.instance.batch();
      for (final videoId in _selectedVideos) {
        batch.delete(FirebaseFirestore.instance.collection('onlineVideos').doc(videoId));
      }
      await batch.commit();
      
      if (!mounted) return;
      setState(() {
        _selectedVideos.clear();
        _isBulkMode = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${_selectedVideos.length} videos'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _bulkEdit() async {
    if (_selectedVideos.isEmpty) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkEditVideosScreen(selectedVideoIds: _selectedVideos),
      ),
    );
    
    if (result == true) {
      // Refresh the list after bulk edit
      setState(() {
        _selectedVideos.clear();
        _isBulkMode = false;
      });
    }
  }

  Future<void> _bulkPublish() async {
    if (_selectedVideos.isEmpty) return;
    
    final batch = FirebaseFirestore.instance.batch();
    for (final videoId in _selectedVideos) {
      batch.update(
        FirebaseFirestore.instance.collection('onlineVideos').doc(videoId),
        {
          'status': 'published',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
    
    if (!mounted) return;
    setState(() {
      _selectedVideos.clear();
      _isBulkMode = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Videos published successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _bulkUnpublish() async {
    if (_selectedVideos.isEmpty) return;
    
    final batch = FirebaseFirestore.instance.batch();
    for (final videoId in _selectedVideos) {
      batch.update(
        FirebaseFirestore.instance.collection('onlineVideos').doc(videoId),
        {
          'status': 'draft',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
    
    if (!mounted) return;
    setState(() {
      _selectedVideos.clear();
      _isBulkMode = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Videos unpublished successfully'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Video actions
  Future<void> _handleVideoAction(String action, String videoId) async {
    switch (action) {
      case 'edit':
        _openEditDialog(videoId);
        break;
      case 'duplicate':
        _duplicateVideo(videoId);
        break;
      case 'toggle_status':
        _toggleVideoStatus(videoId);
        break;
      case 'toggle_live':
        _toggleLive(videoId, false); // We'll get the current state from the data
        break;
      case 'analytics':
        _showVideoAnalytics(videoId);
        break;
      case 'delete':
        _deleteVideo(videoId);
        break;
    }
  }

  Future<void> _duplicateVideo(String videoId) async {
    final doc = await FirebaseFirestore.instance.collection('onlineVideos').doc(videoId).get();
    final data = doc.data() ?? {};
    
    final newData = {
      ...data,
      'title': '${data['title']} (Copy)',
      'status': 'draft',
      'views': 0,
      'likes': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    await FirebaseFirestore.instance.collection('onlineVideos').add(newData);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video duplicated successfully')),
      );
    }
  }

  Future<void> _toggleVideoStatus(String videoId) async {
    final doc = await FirebaseFirestore.instance.collection('onlineVideos').doc(videoId).get();
    final currentStatus = doc.data()?['status'] ?? 'published';
    final newStatus = currentStatus == 'published' ? 'draft' : 'published';
    
    await FirebaseFirestore.instance.collection('onlineVideos').doc(videoId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video ${newStatus == 'published' ? 'published' : 'unpublished'} successfully')),
      );
    }
  }

  void _showVideoAnalytics(String videoId) {
    // Get video title for analytics screen
    FirebaseFirestore.instance
        .collection('onlineVideos')
        .doc(videoId)
        .get()
        .then((doc) {
      if (doc.exists) {
        final title = doc.data()?['title'] ?? 'Unknown Video';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoAnalyticsScreen(
              videoId: videoId,
              videoTitle: title,
            ),
          ),
        );
      }
    });
  }


  Widget _buildStylesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Dance Styles Management',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addNewStyle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 4),
                    Text('Add', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Styles List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('onlineStyles')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            'Error loading styles: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                final styles = (snapshot.data?.docs ?? []).toList()
                  ..sort((a, b) {
                    final aData = a.data();
                    final bData = b.data();
                    final aPriority = _asInt(aData['priority']);
                    final bPriority = _asInt(bData['priority']);
                    if (aPriority != bPriority) {
                      return aPriority.compareTo(bPriority);
                    }
                    final aName = (aData['name'] ?? '').toString().toLowerCase();
                    final bName = (bData['name'] ?? '').toString().toLowerCase();
                    return aName.compareTo(bName);
                  });
                
                if (styles.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.directions_run, color: Colors.white70, size: 40),
                          const SizedBox(height: 12),
                          const Text(
                            'No dance styles found. Add some styles to get started!',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _addDefaultStyles,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('Add Default Styles', style: TextStyle(fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                return ListView.separated(
                  itemCount: styles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final style = styles[index];
                    final data = style.data();
                    final name = data['name'] ?? '';
                    final description = data['description'] ?? '';
                    final icon = data['icon'] ?? 'directions_run';
                    final color = data['color'] ?? '#E53935';
                    final isActive = data['isActive'] ?? true;
                    
                    return _buildStyleCard(
                      id: style.id,
                      name: name,
                      description: description,
                      icon: icon,
                      color: color,
                      isActive: isActive,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAnalyticsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics Dashboard',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          
          // Analytics Content
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.analytics,
                    size: 64,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Analytics Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Real-time analytics and insights coming soon!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStreamingTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Live Streaming Management',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Custom Add Button
              Container(
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: _startLiveStream,
                  icon: const Icon(Icons.live_tv, size: 16),
                  label: const Text('Start Live', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Live Streaming Stats - Real-time
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('liveStreams')
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, activeStreamsSnapshot) {
              final activeStreams = activeStreamsSnapshot.data?.docs.length ?? 0;
              int totalViewers = 0;
              
              // Calculate total viewers from all active streams
              if (activeStreamsSnapshot.hasData) {
                for (final doc in activeStreamsSnapshot.data!.docs) {
                  final data = doc.data();
                  totalViewers += (data['viewerCount'] ?? 0) as int;
                }
              }
              
              return Row(
                children: [
                  Expanded(
                    child: _buildLiveStatCard('Active Streams', '$activeStreams', Icons.live_tv, Colors.red),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLiveStatCard('Total Viewers', '$totalViewers', Icons.people, Colors.blue),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          
          // Live Streaming Features
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('liveStreams')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.live_tv,
                            size: 48,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No Live Streams Yet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Start your first live class!',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _startLiveStream,
                            icon: const Icon(Icons.live_tv, size: 18),
                            label: const Text('Start Live Class'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    return _buildLiveStreamCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }







  Widget _buildStyleCard({
    required String id,
    required String name,
    required String description,
    required String icon,
    required String color,
    required bool isActive,
  }) {
    return Card(
      elevation: 4,
      color: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Color(int.parse(color.replaceFirst('#', '0xFF'))) : Colors.grey,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Color(int.parse(color.replaceFirst('#', '0xFF'))).withOpacity(0.2),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                _getIconData(icon),
                color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive ? Colors.green : Colors.red,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: isActive ? Colors.green : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Actions
            PopupMenuButton<String>(
              color: const Color(0xFF1B1B1B),
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              onSelected: (action) => _handleStyleAction(action, id),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit', style: TextStyle(color: Colors.white)),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(
                    isActive ? 'Deactivate' : 'Activate',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'music_note':
        return Icons.directions_run;
      case 'headphones':
        return Icons.headphones;
      case 'dance':
        return Icons.accessibility_new;
      case 'star':
        return Icons.star;
      case 'favorite':
        return Icons.favorite;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'whatshot':
        return Icons.whatshot;
      case 'celebration':
        return Icons.celebration;
      default:
        return Icons.directions_run;
    }
  }

  void _addNewStyle() {
    showDialog(
      context: context,
      builder: (context) => _StyleEditDialog(),
    );
  }

  Future<void> _addDefaultStyles() async {
    try {
      await OnlineStylesService.initializeDefaultStyles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default dance styles added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding default styles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editStyle(String id) {
    showDialog(
      context: context,
      builder: (context) => _StyleEditDialog(styleId: id),
    );
  }

  Future<void> _handleStyleAction(String action, String styleId) async {
    switch (action) {
      case 'edit':
        _editStyle(styleId);
        break;
      case 'toggle':
        await _toggleStyleStatus(styleId);
        break;
      case 'delete':
        await _deleteStyle(styleId);
        break;
    }
  }

  Future<void> _toggleStyleStatus(String styleId) async {
    final doc = await FirebaseFirestore.instance.collection('onlineStyles').doc(styleId).get();
    final currentStatus = doc.data()?['isActive'] ?? true;
    
    await FirebaseFirestore.instance.collection('onlineStyles').doc(styleId).update({
      'isActive': !currentStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Style ${!currentStatus ? 'activated' : 'deactivated'} successfully'),
          backgroundColor: !currentStatus ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Future<void> _deleteStyle(String styleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Delete Style', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this dance style? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('onlineStyles').doc(styleId).delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Style deleted successfully'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting style: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _EditOnlineVideoDialog extends StatefulWidget {
  final String? videoId;
  const _EditOnlineVideoDialog({this.videoId});

  @override
  State<_EditOnlineVideoDialog> createState() => _EditOnlineVideoDialogState();
}

class _EditOnlineVideoDialogState extends State<_EditOnlineVideoDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  final TextEditingController _thumb = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final TextEditingController _instructor = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _videoFile;
  File? _thumbFile;
  String _section = 'Bollywood';
  bool _isPaidContent = true;
  String _level = 'Beginner';
  String _status = 'published';
  bool _isLive = false;
  bool _loading = false;
  DateTime? _scheduledDate;
  double _uploadProgress = 0.0;
  bool _isUploading = false;
  StreamSubscription? _uploadSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.videoId != null) _load();
  }

  @override
  void dispose() {
    _uploadSubscription?.cancel();
    _title.dispose();
    _desc.dispose();
    _thumb.dispose();
    _tags.dispose();
    _instructor.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance.collection('onlineVideos').doc(widget.videoId).get();
    final d = doc.data() ?? {};
    if (!mounted) return;
    setState(() {
      _title.text = (d['title'] ?? '').toString();
      _desc.text = (d['description'] ?? '').toString();
      _thumb.text = (d['thumbnail'] ?? '').toString();
      _instructor.text = (d['instructor'] ?? '').toString();
      _isLive = d['isLive'] == true;
      _tags.text = (List<String>.from(d['tags'] ?? [])).join(', ');
      _section = (d['section'] ?? 'Bollywood').toString();
      _isPaidContent = d['isPaidContent'] == true;
      _level = (d['level'] ?? 'Beginner').toString();
      _status = (d['status'] ?? 'published').toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: Text(
        widget.videoId == null ? 'Add Online Video' : 'Edit Online Video', 
        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Basic Information
              _buildSectionHeader('Basic Information'),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Video Title *',
                  hintText: 'Enter video title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Enter video description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instructor,
                decoration: const InputDecoration(
                  labelText: 'Instructor *',
                  hintText: 'Enter instructor name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              
              // Video Content
              _buildSectionHeader('Video Content'),
              _buildVideoPicker(),
              const SizedBox(height: 12),
              _buildThumbPicker(),
              const SizedBox(height: 20),
              
              // Categorization
              _buildSectionHeader('Categorization'),
              _buildSectionPicker(),
              const SizedBox(height: 12),
              _buildLevelPicker(),
              const SizedBox(height: 12),
              TextField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                  hintText: 'dance, bollywood, beginner',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              
              // Settings
              _buildSectionHeader('Settings'),
              _buildPaidControls(),
              const SizedBox(height: 12),
              _buildStatusControls(),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Mark as LIVE', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Live videos are shown with LIVE badge', style: TextStyle(color: Colors.white70)),
                value: _isLive,
                onChanged: (v) => setState(() => _isLive = v),
                thumbColor: const WidgetStatePropertyAll(Color(0xFFE53935)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() { 
      _loading = true;
      _isUploading = true;
      _uploadProgress = 0.0;
    });
    try {
      // Require video file for new items
      if (widget.videoId == null && _videoFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a video file')));
        setState(() { 
          _loading = false;
          _isUploading = false;
        });
        return;
      }

      // Ensure status is set to published for new videos
      if (widget.videoId == null && _status != 'published') {
        _status = 'published';
      }

      String? videoUrl;
      String? thumbUrl = _thumb.text.trim().isNotEmpty ? _thumb.text.trim() : null;
      final storage = FirebaseStorage.instance;
      final ts = DateTime.now().millisecondsSinceEpoch;

      Reference? videoRef;
      Reference? thumbRef;

      if (_videoFile != null) {
        WakelockPlus.enable();
        setState(() => _uploadProgress = 0.1);
        videoRef = storage.ref().child('online_videos/$ts.mp4');
        
        final uploadTask = videoRef.putFile(_videoFile!);
        
        _uploadSubscription?.cancel();
        _uploadSubscription = uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          if (mounted) setState(() => _uploadProgress = progress);
        });
        
        await uploadTask;
        videoUrl = await videoRef.getDownloadURL();
        if (mounted) setState(() => _uploadProgress = 0.8);
      }

      if (_thumbFile != null) {
        thumbRef = storage.ref().child('online_videos/thumbs/$ts.jpg');
        await thumbRef.putFile(_thumbFile!);
        thumbUrl = await thumbRef.getDownloadURL();
      }

      if (!mounted) return;

      final tags = _tags.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final data = {
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'instructor': _instructor.text.trim(),
        'section': _section,
        'level': _level,
        'isPaidContent': _isPaidContent,
        'isLive': _isLive,
        'status': _status,
        'tags': tags,
        'views': 0,
        'likes': 0,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (videoUrl != null) 'url': videoUrl,
        if (thumbUrl != null) 'thumbnail': thumbUrl,
        if (_scheduledDate != null) 'scheduledDate': Timestamp.fromDate(_scheduledDate!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (mounted) setState(() => _uploadProgress = 0.9);
      
      try {
        final col = FirebaseFirestore.instance.collection('onlineVideos');
        if (widget.videoId == null) {
          await col.add({
            ...data,
            'createdAt': FieldValue.serverTimestamp(),
            'views': 0,
            'likes': 0,
          });
        } else {
          await col.doc(widget.videoId).set(data, SetOptions(merge: true));
        }
      } catch (firestoreError) {
        if (videoRef != null) {
          try { await videoRef.delete(); } catch (_) {}
        }
        if (thumbRef != null) {
          try { await thumbRef.delete(); } catch (_) {}
        }
        rethrow;
      }
      
      setState(() => _uploadProgress = 1.0);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.videoId == null ? 'Video uploaded successfully!' : 'Video updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload video. Please check your connection and try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (_videoFile != null) {
        WakelockPlus.disable();
      }
      if (mounted) setState(() { 
        _loading = false;
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionPicker() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('onlineStyles')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final styles = snapshot.data?.docs ?? [];
        final seen = <String>{};
        final sections = <String>[];
        for (final doc in styles) {
          final data = doc.data();
          final name = (data['name'] as String? ?? '').trim();
          if (name.isEmpty) continue;
          final normalized = name.toLowerCase();
          if (seen.add(normalized)) {
            sections.add(name);
          }
        }

        // Add default sections if no styles found or stream not ready
        if (sections.isEmpty) {
          sections.addAll(['Bollywood', 'Hip-Hop', 'Contemporary', 'Classical']);
        }

        // Ensure current selection is valid
        sections.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        if (!sections.contains(_section)) {
          _section = sections.isNotEmpty ? sections.first : 'Bollywood';
        }

        return DropdownButtonFormField<String>(
          value: sections.contains(_section) ? _section : null,
          items: sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _section = v ?? 'Bollywood'),
          decoration: const InputDecoration(
            labelText: 'Section *',
            border: OutlineInputBorder(),
          ),
        );
      },
    );
  }

  Widget _buildLevelPicker() {
    final levels = const ['Beginner', 'Intermediate', 'Advanced', 'All'];
    return DropdownButtonFormField<String>(
      value: _level,
      items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
      onChanged: (v) => setState(() => _level = v ?? 'Beginner'),
      decoration: const InputDecoration(
        labelText: 'Level *',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildVideoPicker() {
    return InkWell(
      onTap: () async {
        final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
        if (file != null) {
          setState(() { _videoFile = File(file.path); });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE53935).withOpacity(0.5), width: 2),
        ),
        child: Column(
          children: [
            const Icon(Icons.video_file, color: Color(0xFFE53935), size: 32),
            const SizedBox(height: 8),
            Text(
              _videoFile != null ? 'Video Selected' : 'Select Video from Device',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_videoFile != null) ...[
              const SizedBox(height: 4),
              Text(
                _videoFile!.path.split('/').last,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ] else ...[
              const SizedBox(height: 4),
              const Text(
                'Tap to choose video file',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
            if (_isUploading) ...[
              const SizedBox(height: 12),
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress.isFinite
                        ? _uploadProgress.clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: Colors.grey.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE53935)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _uploadProgress >= 1.0 
                        ? 'Upload Complete! ✅'
                        : '${((_uploadProgress.isFinite ? _uploadProgress.clamp(0.0, 1.0) : 0.0) * 100).toInt()}% uploaded',
                    style: TextStyle(
                      color: _uploadProgress >= 1.0 ? Colors.green : Colors.white70, 
                      fontSize: 12,
                      fontWeight: _uploadProgress >= 1.0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThumbPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final XFile? img = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
            if (img != null) {
              setState(() { _thumbFile = File(img.path); });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF262626),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.5), width: 2),
            ),
            child: Column(
              children: [
                const Icon(Icons.image, color: Color(0xFF4F46E5), size: 32),
                const SizedBox(height: 8),
                Text(
                  _thumbFile != null ? 'Thumbnail Selected' : 'Select Thumbnail Image',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_thumbFile != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _thumbFile!.path.split('/').last,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to choose thumbnail image',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _thumb,
          decoration: const InputDecoration(
            labelText: 'Or enter thumbnail URL (optional)',
            hintText: 'https://example.com/image.jpg',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildPaidControls() {
    return SwitchListTile(
      title: const Text('Paid Content', style: TextStyle(color: Colors.white)),
      subtitle: const Text('Requires subscription to view', style: TextStyle(color: Colors.white70)),
      value: _isPaidContent,
      onChanged: (v) => setState(() => _isPaidContent = v),
      thumbColor: const WidgetStatePropertyAll(Color(0xFFE53935)),
    );
  }

  Widget _buildStatusControls() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _status,
          decoration: const InputDecoration(
            labelText: 'Publish Status *',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'draft', child: Text('Draft')),
            DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
            DropdownMenuItem(value: 'published', child: Text('Published')),
          ],
          onChanged: (v) => setState(() => _status = v ?? 'published'),
        ),
        if (_status == 'scheduled') ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectScheduledDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _scheduledDate != null 
                    ? 'Scheduled: ${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}'
                    : 'Select Date',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _selectScheduledDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _scheduledDate = date);
    }
  }
}

class _StyleEditDialog extends StatefulWidget {
  final String? styleId;
  const _StyleEditDialog({this.styleId});

  @override
  State<_StyleEditDialog> createState() => _StyleEditDialogState();
}

class _StyleEditDialogState extends State<_StyleEditDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedIcon = 'directions_run';
  String _selectedColor = '#E53935';
  bool _isActive = true;
  bool _loading = false;

  final List<String> _icons = [
    'directions_run', 'headphones', 'dance', 'star', 'favorite',
    'local_fire_department', 'whatshot', 'celebration'
  ];

  final List<String> _colors = [
    '#E53935', '#4F46E5', '#10B981', '#F59E0B', '#EF4444',
    '#8B5CF6', '#06B6D4', '#84CC16', '#F97316', '#EC4899'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.styleId != null) {
      _loadStyle();
    }
  }

  Future<void> _loadStyle() async {
    final doc = await FirebaseFirestore.instance
        .collection('onlineStyles')
        .doc(widget.styleId)
        .get();
    
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _nameController.text = data['name'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _selectedIcon = data['icon'] ?? 'directions_run';
        _selectedColor = data['color'] ?? '#E53935';
        _isActive = data['isActive'] ?? true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: Text(
        widget.styleId == null ? 'Add Dance Style' : 'Edit Dance Style',
        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Style Name *',
                  hintText: 'e.g., Bollywood, Hip-Hop',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Describe this dance style',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Icon Selection
              const Text(
                'Select Icon:',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _icons.map((icon) => _buildIconOption(icon)).toList(),
              ),
              const SizedBox(height: 16),
              
              // Color Selection
              const Text(
                'Select Color:',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colors.map((color) => _buildColorOption(color)).toList(),
              ),
              const SizedBox(height: 16),
              
              // Active Status
              SwitchListTile(
                title: const Text('Active', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Show this style in the app', style: TextStyle(color: Colors.white70)),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                thumbColor: const WidgetStatePropertyAll(Color(0xFFE53935)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _saveStyle,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildIconOption(String icon) {
    final isSelected = _selectedIcon == icon;
    return GestureDetector(
      onTap: () => setState(() => _selectedIcon = icon),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFE53935).withOpacity(0.2)
              : const Color(0xFF262626),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFE53935) : Colors.grey,
            width: 2,
          ),
        ),
        child: Icon(
          _getIconData(icon),
          color: isSelected ? const Color(0xFFE53935) : Colors.white70,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildColorOption(String color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'music_note':
        return Icons.directions_run;
      case 'headphones':
        return Icons.headphones;
      case 'dance':
        return Icons.accessibility_new;
      case 'star':
        return Icons.star;
      case 'favorite':
        return Icons.favorite;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'whatshot':
        return Icons.whatshot;
      case 'celebration':
        return Icons.celebration;
      default:
        return Icons.directions_run;
    }
  }

  Future<void> _saveStyle() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a style name')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'icon': _selectedIcon,
        'color': _selectedColor,
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.styleId == null) {
        // For new styles, get the next priority number
        final existingStyles = await FirebaseFirestore.instance
            .collection('onlineStyles')
            .orderBy('priority', descending: true)
            .limit(1)
            .get();
        
        int nextPriority = 0;
        if (existingStyles.docs.isNotEmpty) {
          nextPriority = (existingStyles.docs.first.data()['priority'] ?? 0) + 1;
        }
        
        
        await FirebaseFirestore.instance.collection('onlineStyles').add({
          ...data,
          'priority': nextPriority,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance
            .collection('onlineStyles')
            .doc(widget.styleId)
            .update(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.styleId == null ? 'Style added successfully!' : 'Style updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving style: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _LiveStreamDialog extends StatefulWidget {
  final String? streamId;
  
  const _LiveStreamDialog({this.streamId});
  
  @override
  State<_LiveStreamDialog> createState() => _LiveStreamDialogState();
}

class _LiveStreamDialogState extends State<_LiveStreamDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructorController = TextEditingController();
  
  String _danceStyle = "Bollywood";
  DateTime _scheduledDate = DateTime.now();
  bool _isScheduled = false;
  bool _loading = false;
  
  final List<String> _danceStyles = [
    "Bollywood", "Hip-Hop", "Contemporary", "Classical", 
    "Tutorials", "Choreography", "Practice", "Live Recordings"
  ];
  
  @override
  void initState() {
    super.initState();
    if (widget.streamId != null) {
      _loadLiveStream();
    }
  }
  
  Future<void> _loadLiveStream() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("liveStreams")
          .doc(widget.streamId!)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _titleController.text = data["title"] ?? "";
        _descriptionController.text = data["description"] ?? "";
        _instructorController.text = data["instructor"] ?? "";
        _danceStyle = data["danceStyle"] ?? "Bollywood";
        _isScheduled = data["isScheduled"] ?? false;
        if (data["scheduledDate"] != null) {
          _scheduledDate = (data["scheduledDate"] as Timestamp).toDate();
        }
      }
    } catch (e) {
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: Text(
        widget.streamId == null ? "Start Live Class" : "Edit Live Stream",
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSectionHeader("Basic Information"),
            const SizedBox(height: 16),
            
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Class Title *",
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _instructorController,
              decoration: const InputDecoration(
                labelText: "Instructor Name *",
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _danceStyle,
              decoration: const InputDecoration(
                labelText: "Dance Style",
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: Colors.white70),
              ),
              dropdownColor: const Color(0xFF1B1B1B),
              style: const TextStyle(color: Colors.white),
              items: _danceStyles.map((style) => 
                DropdownMenuItem(value: style, child: Text(style))
              ).toList(),
              onChanged: (value) => setState(() => _danceStyle = value!),
            ),
            const SizedBox(height: 20),
            
            _buildSectionHeader("Scheduling"),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text("Schedule for Later", style: TextStyle(color: Colors.white)),
              value: _isScheduled,
              onChanged: (value) => setState(() => _isScheduled = value),
              thumbColor: const WidgetStatePropertyAll(Color(0xFFE53935)),
            ),
            
            if (_isScheduled) ...[
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.white70),
                title: const Text("Scheduled Date & Time", style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  "${_scheduledDate.day}/${_scheduledDate.month}/${_scheduledDate.year} ${_scheduledDate.hour}:${_scheduledDate.minute.toString().padLeft(2, "0")}",
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                onTap: _selectDateTime,
              ),
            ],
            
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C3A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.live_tv, color: Colors.red, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    "Live Streaming Features",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "• Subscribed users can join automatically\n• Real-time viewer count\n• Chat and interaction features\n• Recording available after stream",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _saveLiveStream,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
          child: _loading 
              ? const SizedBox(
                  width: 18, 
                  height: 18, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                )
              : Text(widget.streamId == null ? "Start Live" : "Update"),
        ),
      ],
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          color: const Color(0xFFE53935),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_scheduledDate),
      );
      
      if (time != null) {
        setState(() {
          _scheduledDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }
  
  Future<void> _saveLiveStream() async {
    if (_titleController.text.trim().isEmpty || _instructorController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all required fields")),
      );
      return;
    }
    
    setState(() => _loading = true);
    
    try {
      final data = {
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "instructor": _instructorController.text.trim(),
        "danceStyle": _danceStyle,
        "isScheduled": _isScheduled,
        "isActive": false,
        "viewerCount": 0,
        "updatedAt": FieldValue.serverTimestamp(),
      };
      
      if (_isScheduled) {
        data["scheduledDate"] = Timestamp.fromDate(_scheduledDate);
      }
      
      final collection = FirebaseFirestore.instance.collection("liveStreams");
      
      if (widget.streamId == null) {
        await collection.add({
          ...data,
          "createdAt": FieldValue.serverTimestamp(),
        });
      } else {
        await collection.doc(widget.streamId).set(data, SetOptions(merge: true));
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.streamId == null 
                  ? "Live class created successfully! You can start streaming anytime."
                  : "Live stream updated successfully!"
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error saving live stream"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
