import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../services/subscription_renewal_service.dart';
import '../services/payment_service.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../widgets/glassmorphism_app_bar.dart';
import 'video_comments_screen.dart';
import 'offline_downloads_screen.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnail;
  final bool isLive;
  final bool isPaidContent;
  final String section;
  final int views;
  final int likes;

  const VideoPlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnail,
    required this.isLive,
    required this.isPaidContent,
    required this.section,
    required this.views,
    required this.likes,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isPlaying = false;
  bool _isLiked = false;
  bool _isSubscribed = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isFullscreen = false;
  bool _isLoading = true;
  bool _isBuffering = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isDownloaded = false;
  http.Client? _downloadClient;
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;

  @override
  void initState() {
    super.initState();
    // Check subscription status first before showing UI
    _checkSubscriptionStatusAndInitialize();
    _incrementViews();
    _checkIfDownloaded();
    
    // Listen to payment success events for real-time subscription updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (event['type'] == 'payment_success' && event['paymentType'] == 'subscription' && mounted) {
        // Refresh subscription status when subscription payment succeeds
        _checkSubscriptionStatusAndInitialize();
      }
    });
  }


  Future<void> _checkSubscriptionStatusAndInitialize() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      bool hasActiveSubscription = false;
      
      if (user != null) {
        // Try primary subscription check first
        try {
          final subscriptionSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('subscriptions')
              .where('status', isEqualTo: 'active')
              .where('endDate', isGreaterThan: Timestamp.now())
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 5));
          
          hasActiveSubscription = subscriptionSnapshot.docs.isNotEmpty;
        } catch (e) {
          // Try fallback method
          try {
            hasActiveSubscription = await _checkSubscriptionFallback();
          } catch (fallbackError) {
            hasActiveSubscription = false;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _isSubscribed = hasActiveSubscription;
          // Keep loading true until video is initialized
        });
        
        // Skip preload check to avoid additional network calls
        // Initialize video directly
        await _initializeVideo();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubscribed = false;
        });
        await _initializeVideo();
      }
    }
  }

  Future<void> _preloadVideo() async {
    try {
      if (widget.videoUrl.isNotEmpty && !widget.videoUrl.startsWith('/') && !widget.videoUrl.startsWith('file://')) {
        // Check if network video URL is accessible
        final response = await http.head(Uri.parse(widget.videoUrl)).timeout(
          const Duration(seconds: 5),
          onTimeout: () => http.Response('', 408),
        );
        
        if (response.statusCode != 200) {
          throw Exception('Video URL not accessible: ${response.statusCode}');
        }
        
      }
    } catch (e) {
      // Continue anyway, let video player handle the error
    }
  }


  Future<void> _initializeVideo() async {
    try {
      // Validate video URL
      if (widget.videoUrl.isEmpty) {
        throw Exception('Video URL is empty');
      }
      
      
      // Check if it's a local file path or network URL
      if (widget.videoUrl.startsWith('/') || widget.videoUrl.startsWith('file://')) {
        // Local file
        final file = File(widget.videoUrl.replaceFirst('file://', ''));
        if (!await file.exists()) {
          throw Exception('Local video file not found');
        }
        
        _controller = VideoPlayerController.file(
          file,
          videoPlayerOptions: VideoPlayerOptions(
            allowBackgroundPlayback: false,
            mixWithOthers: false,
          ),
        );
      } else {
        // Network URL with minimal headers to avoid issues
        final videoUri = Uri.parse(widget.videoUrl);
        if (!videoUri.hasScheme || (!videoUri.scheme.startsWith('http'))) {
          throw Exception('Invalid video URL format');
        }
        
        _controller = VideoPlayerController.networkUrl(
          videoUri,
          videoPlayerOptions: VideoPlayerOptions(
            allowBackgroundPlayback: false,
            mixWithOthers: false,
          ),
        );
      }
      
      // Initialize with longer timeout and retry mechanism
      int retryCount = 0;
      const maxRetries = 2;
      
      while (retryCount < maxRetries) {
        try {
          await _controller!.initialize().timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Video initialization timeout');
            },
          );
          break; // Success, exit retry loop
        } catch (e) {
          retryCount++;
          
          if (retryCount >= maxRetries) {
            throw e; // Re-throw if all retries failed
          }
          
          // Wait a bit before retry
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
          _totalDuration = _controller!.value.duration;
        });
        
        _controller!.addListener(_videoListener);
        
        // Set volume
        await _controller!.setVolume(1.0);
        
        
        // Start playing immediately
        _controller!.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _handleVideoError(e.toString());
      }
    }
  }

  void _handleVideoError(String error) {
    // Show error with retry option
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isInitialized = false;
      });
    }
  }

  // Fallback method to check subscription without timeout
  Future<bool> _checkSubscriptionFallback() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Simple query without complex conditions
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final endDate = data['endDate'] as Timestamp?;
        
        if (status == 'active' && endDate != null) {
          final endDateTime = endDate.toDate();
          if (endDateTime.isAfter(DateTime.now())) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;
    
    try {
      // Throttle UI updates to prevent lag
      final newPosition = _controller!.value.position;
      final newIsPlaying = _controller!.value.isPlaying;
      final newIsBuffering = _controller!.value.isBuffering;
      
      // Only update playing state if changed
      if (newIsPlaying != _isPlaying) {
        if (mounted) {
          setState(() {
            _isPlaying = newIsPlaying;
          });
        }
      }
      
      // Only update position if changed significantly (every 2 seconds)
      if ((newPosition.inSeconds != _currentPosition.inSeconds) || 
          (newIsBuffering != _isBuffering)) {
        if (mounted) {
          setState(() {
            _currentPosition = newPosition;
            _isBuffering = newIsBuffering;
          });
        }
      }
      
      // Track progress every 30 seconds (reduced frequency)
      if (newPosition.inSeconds % 30 == 0 && newPosition.inSeconds > 0) {
        _trackProgress();
      }
    } catch (e) {
    }
  }


  Future<void> _incrementViews() async {
    try {
      // Only increment views for online videos, not downloaded ones
      if (!widget.videoUrl.startsWith('/') && !widget.videoUrl.startsWith('file://')) {
        await FirebaseFirestore.instance
            .collection('onlineVideos')
            .doc(widget.videoId)
            .update({
          'views': FieldValue.increment(1),
        });
      }
    } catch (e) {
    }
  }

  Future<void> _trackProgress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final watchDuration = _currentPosition.inMilliseconds;
      final totalDuration = _totalDuration.inMilliseconds;
      final progress = totalDuration > 0 ? (watchDuration / totalDuration) : 0.0;
      final isCompleted = progress >= 0.9; // 90% watched = completed

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('watchHistory')
          .doc(widget.videoId)
          .set({
        'videoId': widget.videoId,
        'watchDuration': watchDuration,
        'totalDuration': totalDuration,
        'progress': progress,
        'isCompleted': isCompleted,
        'lastWatchedAt': FieldValue.serverTimestamp(),
        'watchedAt': FieldValue.serverTimestamp(),
        if (isCompleted) 'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Silently handle progress tracking errors - not critical for user experience
      // Removed debug print for better performance
    }
  }

  Future<void> _toggleLike() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final increment = _isLiked ? -1 : 1;
      await FirebaseFirestore.instance
          .collection('onlineVideos')
          .doc(widget.videoId)
          .update({
        'likes': FieldValue.increment(increment),
      });

      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
        });
      }
    } catch (e) {
      _showError('Failed to update like: ${e.toString()}');
    }
  }

  void _togglePlayPause() {
    if (_controller != null && _controller!.value.isPlaying) {
      _controller!.pause();
    } else if (_controller != null) {
      _controller!.play();
    }
  }

  void _seekTo(Duration position) {
    if (_controller != null) {
      _controller!.seekTo(position);
    }
  }

  void _changePlaybackSpeed() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Playback Speed',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...['0.5x', '0.75x', '1.0x', '1.25x', '1.5x', '2.0x'].map((speed) {
              final speedValue = double.parse(speed.replaceAll('x', ''));
              return ListTile(
                title: Text(
                  speed,
                  style: TextStyle(
                    color: _playbackSpeed == speedValue ? const Color(0xFFE53935) : Colors.white,
                    fontWeight: _playbackSpeed == speedValue ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  if (_controller != null) {
                    _controller!.setPlaybackSpeed(speedValue);
                  }
                  setState(() => _playbackSpeed = speedValue);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
  }

  Future<void> _checkIfDownloaded() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/Downloads');
      final fileName = '${widget.title.replaceAll(RegExp(r'[^\w\s-]'), '')}.mp4';
      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);
      
      final exists = await file.exists();
      if (mounted) {
        setState(() {
          _isDownloaded = exists;
        });
      }
    } catch (e) {
    }
  }

  void _downloadVideo() async {
    if (_isDownloading) {
      // Stop download if already downloading
      _stopDownload();
      return;
    }
    
    if (_isDownloaded) {
      // If already downloaded, open offline downloads
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OfflineDownloadsScreen(),
        ),
      );
      return;
    }
    
    if (mounted) {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });
    }

    try {
      // Get downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Create video file path
      final fileName = '${widget.title.replaceAll(RegExp(r'[^\w\s-]'), '')}.mp4';
      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);

      // Download video with progress tracking
      _downloadClient = http.Client();
      final request = http.Request('GET', Uri.parse(widget.videoUrl));
      final streamedResponse = await _downloadClient!.send(request);
      
      if (streamedResponse.statusCode == 200) {
        final totalBytes = streamedResponse.contentLength ?? 0;
        int downloadedBytes = 0;
        
        final sink = file.openWrite();
        
        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          
          if (totalBytes > 0 && mounted) {
            setState(() {
              _downloadProgress = downloadedBytes / totalBytes;
            });
          }
        }
        
        await sink.close();
        
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadProgress = 0.0;
            _isDownloaded = true;
          });
        }
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.title} downloaded successfully!'),
              backgroundColor: const Color(0xFFE53935),
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OfflineDownloadsScreen(),
                    ),
                  );
                },
              ),
            ),
          );
        }
      } else {
        throw Exception('Failed to download video');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  void _stopDownload() {
    _downloadClient?.close();
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
    }
  }


  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorWithRetry(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _isInitialized = false;
                });
                _initializeVideo();
              }
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _paymentRefreshSubscription?.cancel();
    _downloadClient?.close();
    if (_controller != null) {
      try {
        if (_controller!.value.isInitialized) {
          _controller!.removeListener(_videoListener);
        }
        _controller!.dispose();
      } catch (e) {
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking subscription status
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFFE53935),
              ),
              SizedBox(height: 16),
              Text(
                'Loading video...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show paywall if content is paid and user is not subscribed
    if (widget.isPaidContent && !_isSubscribed) {
      return _buildPaywall();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullscreen ? null : GlassmorphismAppBar(
        title: widget.title,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE53935)),
            )
          : _isInitialized
              ? _isFullscreen ? _buildFullscreenVideo() : _buildVideoPlayerWithRelated()
              : _buildErrorState(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFE53935),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to load video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please check your internet connection and try again.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _isInitialized = false;
              });
              _initializeVideo();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaywall() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(title: 'Premium Content'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.lock,
                      color: Color(0xFFE53935),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Premium Content',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Color(0xFFE53935),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This video requires an active subscription to view.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate to subscription plans
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Subscribe Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenVideo() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Stack(
        children: [
          // Fullscreen Video Player
          Center(
            child: AspectRatio(
              aspectRatio: _controller?.value.aspectRatio ?? 16/9,
              child: _controller != null ? VideoPlayer(_controller!) : Container(),
            ),
          ),
          
          // Buffering Indicator
          if (_isBuffering)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE53935),
                strokeWidth: 3,
              ),
            ),
          
          // Fullscreen Controls Overlay
          if (_showControls)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    // Top Controls - Only back button
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          if (widget.isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935).withOpacity(0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, color: Colors.white, size: 8),
                                  SizedBox(width: 6),
                                  Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Bottom Controls
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress Bar
                          Row(
                            children: [
                              Text(
                                _formatDuration(_currentPosition),
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: const Color(0xFFE53935),
                                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                                    thumbColor: const Color(0xFFE53935),
                                    overlayColor: const Color(0xFFE53935).withOpacity(0.2),
                                  ),
                                  child: Slider(
                                    value: _currentPosition.inMilliseconds.toDouble(),
                                    max: _totalDuration.inMilliseconds.toDouble(),
                                    onChanged: (value) {
                                      _seekTo(Duration(milliseconds: value.toInt()));
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_totalDuration),
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Control Buttons - Center: Play/Speed, Right: Exit Fullscreen
                          Row(
                            children: [
                              // Left side - Video Title
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              
                              // Center - Play/Pause and Speed controls
                              IconButton(
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.speed, color: Colors.white),
                                onPressed: _changePlaybackSpeed,
                              ),
                              const SizedBox(width: 8),
                              Stack(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _isDownloaded 
                                        ? Icons.arrow_forward_ios 
                                        : _isDownloading 
                                          ? Icons.stop 
                                          : Icons.download,
                                      color: _isDownloaded ? const Color(0xFF4CAF50) : Colors.white,
                                    ),
                                    onPressed: _downloadVideo,
                                  ),
                                  if (_isDownloading)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black.withOpacity(0.7),
                                        ),
                                        child: CircularProgressIndicator(
                                          value: _downloadProgress,
                                          strokeWidth: 2,
                                          color: const Color(0xFFE53935),
                                          backgroundColor: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              const SizedBox(width: 8),
                              
                              // Right side - Exit Fullscreen button
                              IconButton(
                                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                                onPressed: _toggleFullscreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerWithRelated() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _buildVideoPlayer(),
        ),
        Expanded(
          flex: 2,
          child: _buildRelatedVideos(),
        ),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Stack(
        children: [
          // Video Player
          Center(
            child: AspectRatio(
              aspectRatio: _controller?.value.aspectRatio ?? 16/9,
              child: _controller != null ? VideoPlayer(_controller!) : Container(),
            ),
          ),
          
          // Buffering Indicator
          if (_isBuffering)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE53935),
                strokeWidth: 3,
              ),
            ),
          
          // Manual Play Button (if video is stuck)
          if (_isInitialized && !_isPlaying && !_isBuffering && !_isLoading)
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 64,
                  ),
                  onPressed: () {
                    if (_controller != null) {
                      _controller!.play();
                    }
                    setState(() {
                      _isPlaying = true;
                    });
                  },
                ),
              ),
            ),
          
          // Controls Overlay
          if (_showControls)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    // Top Controls - Only LIVE indicator and comments
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Spacer(),
                          if (widget.isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935).withOpacity(0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, color: Colors.white, size: 8),
                                  SizedBox(width: 6),
                                  Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Bottom Controls
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress Bar
                          Row(
                            children: [
                              Text(
                                _formatDuration(_currentPosition),
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: const Color(0xFFE53935),
                                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                                    thumbColor: const Color(0xFFE53935),
                                    overlayColor: const Color(0xFFE53935).withOpacity(0.2),
                                  ),
                                  child: Slider(
                                    value: _currentPosition.inMilliseconds.toDouble(),
                                    max: _totalDuration.inMilliseconds.toDouble(),
                                    onChanged: (value) {
                                      _seekTo(Duration(milliseconds: value.toInt()));
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_totalDuration),
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Control Buttons - Center: Play/Speed, Right: Fullscreen
                          Row(
                            children: [
                              // Left side - Video Title
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              
                              // Center - Play/Pause and Speed controls
                              IconButton(
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.speed, color: Colors.white),
                                onPressed: _changePlaybackSpeed,
                              ),
                              const SizedBox(width: 8),
                              Stack(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _isDownloaded 
                                        ? Icons.arrow_forward_ios 
                                        : _isDownloading 
                                          ? Icons.stop 
                                          : Icons.download,
                                      color: _isDownloaded ? const Color(0xFF4CAF50) : Colors.white,
                                    ),
                                    onPressed: _downloadVideo,
                                  ),
                                  if (_isDownloading)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black.withOpacity(0.7),
                                        ),
                                        child: CircularProgressIndicator(
                                          value: _downloadProgress,
                                          strokeWidth: 2,
                                          color: const Color(0xFFE53935),
                                          backgroundColor: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              const SizedBox(width: 8),
                              
                              // Right side - Fullscreen button
                              IconButton(
                                icon: const Icon(Icons.fullscreen, color: Colors.white),
                                onPressed: _toggleFullscreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRelatedVideos() {
    return Container(
      color: const Color(0xFF1B1B1B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'More from ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.section,
                  style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _RelatedVideosList(section: widget.section),
          ),
        ],
      ),
    );
  }
}

class _RelatedVideosList extends StatefulWidget {
  final String section;

  const _RelatedVideosList({required this.section});

  @override
  State<_RelatedVideosList> createState() => _RelatedVideosListState();
}

class _RelatedVideosListState extends State<_RelatedVideosList> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _cachedVideos;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('onlineVideos')
          .where('section', isEqualTo: widget.section)
          .where('status', isEqualTo: 'published')
          .get();

      if (mounted) {
        setState(() {
          _cachedVideos = snapshot.docs;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
    }

    if (_hasError) {
      return const Center(
        child: Text(
          'Error loading videos',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final docs = _cachedVideos ?? [];
    
    // Client-side sorting and limiting
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
      return const Center(
        child: Text(
          'No related videos',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: limitedDocs.length,
      itemBuilder: (context, index) {
        final d = limitedDocs[index].data();
        final title = (d['title'] ?? '').toString();
        final desc = (d['description'] ?? '').toString();
        final thumb = (d['thumbnail'] ?? '').toString();
        final isLive = d['isLive'] == true;
        final isPaidContent = d['isPaidContent'] == true;
        final videoUrl = (d['url'] ?? '').toString();
        final views = (d['views'] ?? 0) as int;
        final likes = (d['likes'] ?? 0) as int;
        final videoId = limitedDocs[index].id;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _RelatedVideoCard(
            videoId: videoId,
            title: title,
            description: desc,
            thumbnail: thumb,
            videoUrl: videoUrl,
            isLive: isLive,
            isPaidContent: isPaidContent,
            views: views,
            likes: likes,
          ),
        );
      },
    );
  }

}

class _RelatedVideoCard extends StatelessWidget {
  final String videoId;
  final String title;
  final String description;
  final String thumbnail;
  final String videoUrl;
  final bool isLive;
  final bool isPaidContent;
  final int views;
  final int likes;

  const _RelatedVideoCard({
    required this.videoId,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.videoUrl,
    required this.isLive,
    required this.isPaidContent,
    required this.views,
    required this.likes,
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

        return InkWell(
          onTap: () {
            if (!isPaidContent || hasActiveSubscription) {
              Navigator.pushReplacement(
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
                    section: 'Related',
                    views: views,
                    likes: likes,
                  ),
                ),
              );
            }
          },
          child: Row(
            children: [
              Container(
                width: 120,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: thumbnail.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(thumbnail, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.play_circle_fill, color: Color(0xFFE53935), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Untitled' : title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.visibility, color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Text('$views', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 12),
                        Icon(Icons.favorite, color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Text('$likes', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        if (isPaidContent && !hasActiveSubscription) ...[
                          const Spacer(),
                          const Icon(Icons.lock, color: Color(0xFFE53935), size: 16),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}