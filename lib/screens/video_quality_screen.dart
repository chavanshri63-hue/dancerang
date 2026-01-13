import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/payment_service.dart';

class VideoQualityScreen extends StatefulWidget {
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

  const VideoQualityScreen({
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
  State<VideoQualityScreen> createState() => _VideoQualityScreenState();
}

class _VideoQualityScreenState extends State<VideoQualityScreen> {
  late VideoPlayerController _controller;
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
  String _selectedQuality = 'auto';
  bool _isQualityMenuVisible = false;
  bool _isBuffering = false;
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;

  final Map<String, String> _qualityOptions = {
    'auto': 'Auto',
    '1080p': '1080p HD',
    '720p': '720p HD',
    '480p': '480p',
    '360p': '360p',
    '240p': '240p',
  };

  @override
  void initState() {
    super.initState();
    _preloadVideo();
    _checkSubscriptionStatus();
    _incrementViews();
    
    // Listen to payment success events for real-time subscription updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (event['type'] == 'payment_success' && event['paymentType'] == 'subscription' && mounted) {
        // Refresh subscription status when subscription payment succeeds
        _checkSubscriptionStatus();
      }
    });
  }

  Future<void> _preloadVideo() async {
    // Preload video URL to improve loading speed
    try {
      final uri = Uri.parse(widget.videoUrl);
      // This helps with DNS resolution and initial connection
      await uri.resolve('').toFilePath();
    } catch (e) {
      // Ignore preload errors, continue with normal initialization
    }
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: false,
          mixWithOthers: false,
        ),
        // Add buffering optimization
        httpHeaders: {
          'Cache-Control': 'max-age=7200',
          'Connection': 'keep-alive',
          'Range': 'bytes=0-',
          'Accept-Encoding': 'gzip, deflate',
        },
      );
      
      // Add timeout for initialization
      await _controller.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Video initialization timeout');
        },
      );
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
          _totalDuration = _controller.value.duration;
        });
        
        _controller.addListener(_videoListener);
        
        // Set volume and prepare for playback
        await _controller.setVolume(1.0);
        
        // Force play immediately after initialization
        setState(() {
          _isPlaying = true;
        });
        
        // Start playing without delay
        _controller.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load video: ${e.toString()}');
      }
    }
  }

  void _videoListener() {
    if (mounted) {
      // Throttle UI updates to prevent lag
      final newPosition = _controller.value.position;
      final newIsPlaying = _controller.value.isPlaying;
      final newIsBuffering = _controller.value.isBuffering;
      
      // Always update playing state immediately
      if (newIsPlaying != _isPlaying) {
        setState(() {
          _isPlaying = newIsPlaying;
        });
      }
      
      // Only update position if changed significantly (every 1 second)
      if ((newPosition.inSeconds != _currentPosition.inSeconds) || 
          (newIsBuffering != _isBuffering)) {
        setState(() {
          _currentPosition = newPosition;
          _isBuffering = newIsBuffering;
        });
      }
      
      // Track progress every 10 seconds
      if (newPosition.inSeconds % 10 == 0 && newPosition.inSeconds > 0) {
        _trackProgress();
      }
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final subscriptionSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _isSubscribed = subscriptionSnapshot.docs.isNotEmpty &&
              subscriptionSnapshot.docs.first.data()['status'] == 'active';
        });
      }
    } catch (e) {
    }
  }

  Future<void> _incrementViews() async {
    try {
      await FirebaseFirestore.instance
          .collection('onlineVideos')
          .doc(widget.videoId)
          .update({
        'views': FieldValue.increment(1),
      });
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
      final isCompleted = progress >= 0.9;

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
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  void _seekTo(Duration position) {
    _controller.seekTo(position);
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
                    color: _playbackSpeed == speedValue ? const Color(0xFF4F46E5) : Colors.white,
                    fontWeight: _playbackSpeed == speedValue ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  _controller.setPlaybackSpeed(speedValue);
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

  void _showQualityMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Video Quality',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ..._qualityOptions.entries.map((entry) {
              final isSelected = _selectedQuality == entry.key;
              return ListTile(
                title: Text(
                  entry.value,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF4F46E5)) : null,
                onTap: () {
                  setState(() => _selectedQuality = entry.key);
                  Navigator.pop(context);
                  _applyQualitySettings();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _applyQualitySettings() {
    // In a real implementation, you would:
    // 1. Get different quality URLs from your backend
    // 2. Switch to the appropriate video stream
    // 3. Handle adaptive bitrate streaming
    
    // For now, we'll just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switching to ${_qualityOptions[_selectedQuality]} quality...'),
        backgroundColor: const Color(0xFF4F46E5),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
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

  @override
  void dispose() {
    _paymentRefreshSubscription?.cancel();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPaidContent && !_isSubscribed) {
      return _buildPaywall();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullscreen ? null : GlassmorphismAppBar(
        title: widget.title,
        actions: [
          IconButton(
            icon: const Icon(Icons.hd, color: Colors.white),
            onPressed: () => _showQualityMenu(),
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.white),
            onPressed: _toggleFullscreen,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            )
          : _isInitialized
              ? _buildVideoPlayer()
              : _buildErrorState(),
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
                    const Text(
                      'This video requires an active subscription to view.',
                      style: TextStyle(
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
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          
          // Buffering Indicator
          if (_isBuffering)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4F46E5),
                strokeWidth: 3,
              ),
            ),
          
          // Quality Indicator
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _qualityOptions[_selectedQuality] ?? 'Auto',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
                    // Top Controls
                    Padding(
                      padding: const EdgeInsets.all(16),
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
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.hd, color: Colors.white),
                            onPressed: () => _showQualityMenu(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.fullscreen, color: Colors.white),
                            onPressed: _toggleFullscreen,
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Bottom Controls
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Progress Bar
                          Row(
                            children: [
                              Text(
                                _formatDuration(_currentPosition),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: const Color(0xFF4F46E5),
                                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                                    thumbColor: const Color(0xFF4F46E5),
                                    overlayColor: const Color(0xFF4F46E5).withOpacity(0.2),
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
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Control Buttons
                          Row(
                            children: [
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
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  _isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: _isLiked ? const Color(0xFFE53935) : Colors.white,
                                ),
                                onPressed: _toggleLike,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.likes + (_isLiked ? 1 : 0)}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${widget.views + 1} views',
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
            ),
        ],
      ),
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
          Text(
            'Please check your internet connection and try again.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _initializeVideo();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
