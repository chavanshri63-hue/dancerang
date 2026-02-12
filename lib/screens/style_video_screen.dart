import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';
import 'video_player_screen.dart';
import '../services/subscription_renewal_service.dart';
import '../services/iap_service.dart';
import '../services/online_subscription_service.dart';

class StyleVideoScreen extends StatefulWidget {
  final String styleName;
  final Color styleColor;

  const StyleVideoScreen({
    super.key,
    required this.styleName,
    required this.styleColor,
  });

  @override
  State<StyleVideoScreen> createState() => _StyleVideoScreenState();
}

class _StyleVideoScreenState extends State<StyleVideoScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: widget.styleName,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('onlineVideos')
            .where('section', isEqualTo: widget.styleName)
            .where('status', isEqualTo: 'published')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
          }
          
          final docs = snapshot.data?.docs ?? [];
          
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library,
                    size: 64,
                    color: widget.styleColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No ${widget.styleName} videos yet',
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
              final videoUrl = (d['url'] ?? '').toString();
              final views = (d['views'] ?? 0) as int;
              final likes = (d['likes'] ?? 0) as int;
              final videoId = docs[index].id;
              
              return _StyleVideoListCard(
                videoId: videoId,
                title: title,
                description: desc,
                thumbnail: thumb,
                videoUrl: videoUrl,
                isLive: isLive,
                isPaidContent: isPaidContent,
                views: views,
                likes: likes,
                styleColor: widget.styleColor,
              );
            },
          );
        },
      ),
    );
  }
}

class _StyleVideoListCard extends StatelessWidget {
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

  const _StyleVideoListCard({
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
      if (user == null) return false;

      // Use the subscription renewal service for better accuracy
      return await SubscriptionRenewalService.hasActiveSubscription(user.uid);
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
          elevation: 6,
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
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 140,
                        height: 100,
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
                                color: isLocked ? Colors.grey : styleColor, 
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
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isLive && !isLocked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE53935).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE53935).withOpacity(0.5)),
                                    ),
                                    child: const Text('LIVE', style: TextStyle(color: Color(0xFFE53935), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: TextStyle(
                                color: isLocked ? Colors.grey : Colors.white70, 
                                fontSize: 12
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock,
                              color: Color(0xFFE53935),
                              size: 24,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Premium Content',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Subscribe to access',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 8),
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text(
                                'Subscribe',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
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

class _SubscriptionPlansDialog extends StatefulWidget {
  const _SubscriptionPlansDialog();

  @override
  State<_SubscriptionPlansDialog> createState() => _SubscriptionPlansDialogState();
}

class _SubscriptionPlansDialogState extends State<_SubscriptionPlansDialog> {
  bool _isMonthlyLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.subscriptions,
                  color: Color(0xFFE53935),
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Choose Your Plan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 6),
            
            // Description
            const Text(
              'Unlock all online dance videos',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // Plans
            _PlanCard(
              name: 'Monthly Plan',
              price: '₹900',
              cycle: 'month',
              description: 'Access all videos for 1 month',
              isPopular: false,
              isLoading: _isMonthlyLoading,
              onSubscribe: _handleSubscribe,
            ),
            
            const SizedBox(height: 24),
            
            // Features
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                      SizedBox(width: 8),
                      Text('Unlimited video access', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                      SizedBox(width: 8),
                      Text('HD quality videos', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                      SizedBox(width: 8),
                      Text('Offline downloads', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                      SizedBox(width: 8),
                      Text('Auto-renewal', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubscribe() async {
    if (_isMonthlyLoading) return;
    setState(() => _isMonthlyLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Please login to subscribe');
        return;
      }

      final result = await OnlineSubscriptionService.purchaseMonthly();

      // Check if payment was initiated successfully (not completed yet)
      if (result['success'] == true) {
        // Payment gateway opened successfully, close dialog
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complete the purchase to unlock videos.'),
              backgroundColor: Color(0xFF4F46E5),
            ),
          );
        }
      } else {
        _showError(result['message'] ?? 'Failed to start purchase. Please try again.');
      }
    } catch (e) {
      _showError('Payment failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isMonthlyLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final String cycle;
  final String description;
  final bool isPopular;
  final bool isLoading;
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.cycle,
    required this.description,
    required this.isPopular,
    required this.isLoading,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isPopular ? const Color(0xFFE53935).withOpacity(0.1) : const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? const Color(0xFFE53935).withOpacity(0.5) : const Color(0xFF4F46E5).withOpacity(0.3),
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'BEST VALUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                price,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/$cycle',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPopular ? const Color(0xFFE53935) : const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Subscribe for $price',
                      style: const TextStyle(
                        fontSize: 16,
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
}
