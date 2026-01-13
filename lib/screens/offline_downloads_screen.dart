import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../widgets/glassmorphism_app_bar.dart';
import 'video_player_screen.dart';

class OfflineDownloadsScreen extends StatefulWidget {
  const OfflineDownloadsScreen({super.key});

  @override
  State<OfflineDownloadsScreen> createState() => _OfflineDownloadsScreenState();
}

class _OfflineDownloadsScreenState extends State<OfflineDownloadsScreen> {
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};
  List<File> _downloadedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
  }

  Future<void> _loadDownloadedFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/Downloads');
      
      if (await downloadsDir.exists()) {
        final files = downloadsDir.listSync()
            .where((file) => file is File && file.path.endsWith('.mp4'))
            .cast<File>()
            .toList();
        
        if (mounted) {
          setState(() {
            _downloadedFiles = files;
          });
        }
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'Offline Downloads',
      ),
      body: _buildDownloadedTab(),
    );
  }

  Widget _buildDownloadedTab() {
    if (_downloadedFiles.isEmpty) {
      return _buildEmptyDownloads();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _downloadedFiles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final file = _downloadedFiles[index];
        final fileName = file.path.split('/').last;
        final videoTitle = fileName.replaceAll('.mp4', '');
        final fileSize = file.lengthSync();
        final lastModified = file.lastModifiedSync();
        
        return _buildDownloadedFileCard(
          file: file,
          title: videoTitle,
          fileSize: fileSize,
          lastModified: lastModified,
        );
      },
    );
  }


  Widget _buildDownloadedFileCard({
    required File file,
    required String title,
    required int fileSize,
    required DateTime lastModified,
  }) {
    return Card(
      elevation: 6,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () {
          // Play downloaded video
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerScreen(
                videoId: file.path,
                title: title,
                description: 'Downloaded Video',
                videoUrl: file.path,
                thumbnail: '',
                isLive: false,
                isPaidContent: false,
                section: 'Downloaded',
                views: 0,
                likes: 0,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.video_file,
                  color: Color(0xFF4F46E5),
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Downloaded ${_formatDate(lastModified)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatFileSize(fileSize),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF4F46E5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadedVideoCard({
    required String videoId,
    required String downloadPath,
    required Timestamp? downloadDate,
    required int fileSize,
  }) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('onlineVideos').doc(videoId).snapshots(),
      builder: (context, videoSnapshot) {
        if (!videoSnapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final videoData = videoSnapshot.data!.data();
        if (videoData == null) return const SizedBox.shrink();
        
        final title = (videoData['title'] ?? 'Untitled').toString();
        final thumbnail = (videoData['thumbnail'] ?? '').toString();
        final section = (videoData['section'] ?? '').toString();
        final views = (videoData['views'] ?? 0) as int;
        final likes = (videoData['likes'] ?? 0) as int;
        final videoUrl = (videoData['url'] ?? '').toString();
        final isLive = videoData['isLive'] == true;
        final isPaidContent = videoData['isPaidContent'] == true;
        
        return Card(
          elevation: 6,
          shadowColor: const Color(0xFF10B981).withOpacity(0.15),
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.22)),
          ),
          child: InkWell(
            onTap: () {
              // Play downloaded video
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(
                    videoId: videoId,
                    title: title,
                    description: 'Downloaded Video',
                    videoUrl: downloadPath,
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
                            : const Icon(Icons.play_circle_fill, color: Color(0xFF10B981), size: 32),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                section,
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
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
                                  _formatFileSize(fileSize),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                            if (downloadDate != null)
                              Text(
                                'Downloaded ${_formatDate(downloadDate.toDate())}',
                                style: const TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                      'OFFLINE',
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
      },
    );
  }


  Widget _buildEmptyDownloads() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.offline_bolt,
              size: 64,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Downloaded Videos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Download videos to watch offline',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to online videos screen
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Browse Videos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }



  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
