import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';
import 'video_player_screen.dart';
import 'subscription_plans_screen.dart';
import '../services/subscription_renewal_service.dart';
import '../services/payment_service.dart';

class VideoSearchScreen extends StatefulWidget {
  const VideoSearchScreen({super.key});

  @override
  State<VideoSearchScreen> createState() => _VideoSearchScreenState();
}

class _VideoSearchScreenState extends State<VideoSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  String _selectedSort = 'Newest';
  bool _showPaidOnly = false;
  bool _showFreeOnly = false;

  final List<String> _filters = ['All', 'Bollywood', 'Hip-Hop', 'Contemporary', 'Classical', 'Fusion', 'Beginner', 'Advanced'];
  final List<String> _sortOptions = ['Newest', 'Oldest', 'Most Viewed', 'Most Liked', 'A-Z', 'Z-A'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'Search Videos',
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildActiveFilters(),
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search videos, instructors, styles...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF4F46E5)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildActiveFilters() {
    if (_selectedFilter == 'All' && _selectedSort == 'Newest' && !_showPaidOnly && !_showFreeOnly) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_selectedFilter != 'All')
            _buildFilterChip('Style: $_selectedFilter', () {
              setState(() {
                _selectedFilter = 'All';
              });
            }),
          if (_selectedSort != 'Newest')
            _buildFilterChip('Sort: $_selectedSort', () {
              setState(() {
                _selectedSort = 'Newest';
              });
            }),
          if (_showPaidOnly)
            _buildFilterChip('Paid Only', () {
              setState(() {
                _showPaidOnly = false;
              });
            }),
          if (_showFreeOnly)
            _buildFilterChip('Free Only', () {
              setState(() {
                _showFreeOnly = false;
              });
            }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        backgroundColor: const Color(0xFF4F46E5).withOpacity(0.2),
        deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white70),
        onDeleted: onRemove,
        side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.3)),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchQuery.isEmpty && _selectedFilter == 'All' && !_showPaidOnly && !_showFreeOnly) {
      return _buildEmptyState();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _buildSearchQuery(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
        }
        
        final docs = snapshot.data?.docs ?? [];
        
        if (docs.isEmpty) {
          return _buildNoResultsState();
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
            final section = (d['section'] ?? '').toString();
            final videoId = docs[index].id;
            
            return _SearchVideoCard(
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
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildSearchQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('onlineVideos');

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      // Note: Firestore doesn't support full-text search natively
      // This is a basic implementation - in production, you'd use Algolia or similar
      query = query.where('title', isGreaterThanOrEqualTo: _searchQuery)
                  .where('title', isLessThan: _searchQuery + 'z');
    }

    // Apply section filter
    if (_selectedFilter != 'All') {
      query = query.where('section', isEqualTo: _selectedFilter);
    }

    // Apply paid/free filter
    if (_showPaidOnly) {
      query = query.where('isPaidContent', isEqualTo: true);
    } else if (_showFreeOnly) {
      query = query.where('isPaidContent', isEqualTo: false);
    }

    // Apply sorting
    switch (_selectedSort) {
      case 'Newest':
        query = query.orderBy('createdAt', descending: true);
        break;
      case 'Oldest':
        query = query.orderBy('createdAt', descending: false);
        break;
      case 'Most Viewed':
        query = query.orderBy('views', descending: true);
        break;
      case 'Most Liked':
        query = query.orderBy('likes', descending: true);
        break;
      case 'A-Z':
        query = query.orderBy('title', descending: false);
        break;
      case 'Z-A':
        query = query.orderBy('title', descending: true);
        break;
    }

    return query.limit(50).snapshots();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Search for Videos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find your favorite dance videos by style, instructor, or title',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Results Found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search terms or filters',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // Style Filter
              const Text(
                'Dance Style',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setModalState(() {
                        _selectedFilter = selected ? filter : 'All';
                      });
                    },
                    selectedColor: const Color(0xFF4F46E5).withOpacity(0.3),
                    checkmarkColor: Colors.white,
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 20),
              
              // Sort Options
              const Text(
                'Sort By',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _sortOptions.map((sort) {
                  final isSelected = _selectedSort == sort;
                  return FilterChip(
                    label: Text(sort),
                    selected: isSelected,
                    onSelected: (selected) {
                      setModalState(() {
                        _selectedSort = selected ? sort : 'Newest';
                      });
                    },
                    selectedColor: const Color(0xFF4F46E5).withOpacity(0.3),
                    checkmarkColor: Colors.white,
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 20),
              
              // Content Type
              const Text(
                'Content Type',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Paid Content', style: TextStyle(color: Colors.white)),
                      value: _showPaidOnly,
                      onChanged: (value) {
                        setModalState(() {
                          _showPaidOnly = value ?? false;
                          if (_showPaidOnly) _showFreeOnly = false;
                        });
                      },
                      activeColor: const Color(0xFF4F46E5),
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Free Content', style: TextStyle(color: Colors.white)),
                      value: _showFreeOnly,
                      onChanged: (value) {
                        setModalState(() {
                          _showFreeOnly = value ?? false;
                          if (_showFreeOnly) _showPaidOnly = false;
                        });
                      },
                      activeColor: const Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchVideoCard extends StatelessWidget {
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

  const _SearchVideoCard({
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
        
        // All videos are now locked unless user has active subscription
        final isLocked = !hasActiveSubscription;

        return Card(
          elevation: 6,
          shadowColor: isLocked 
            ? const Color(0xFFE53935).withOpacity(0.15)
            : const Color(0xFF4F46E5).withOpacity(0.15),
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
                                color: isLocked ? Colors.grey : const Color(0xFF4F46E5), 
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

class _SubscriptionPlansDialog extends StatefulWidget {
  const _SubscriptionPlansDialog();

  @override
  State<_SubscriptionPlansDialog> createState() => _SubscriptionPlansDialogState();
}

class _SubscriptionPlansDialogState extends State<_SubscriptionPlansDialog> {
  bool _isMonthlyLoading = false;
  bool _isQuarterlyLoading = false;

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
              onSubscribe: () => _handleSubscribe('monthly', 900, 'monthly'),
            ),
            const SizedBox(height: 12),
            _PlanCard(
              name: '3-Month Plan',
              price: '₹2,300',
              cycle: '3 months',
              description: 'Access all videos for 3 months',
              isPopular: true,
              isLoading: _isQuarterlyLoading,
              onSubscribe: () => _handleSubscribe('quarterly', 2300, 'quarterly'),
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

  Future<void> _handleSubscribe(String planType, int amount, String billingCycle) async {
    // Set appropriate loading state based on plan type
    if (planType == 'monthly') {
      if (_isMonthlyLoading) return;
      setState(() {
        _isMonthlyLoading = true;
      });
    } else {
      if (_isQuarterlyLoading) return;
      setState(() {
        _isQuarterlyLoading = true;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Please login to subscribe');
        return;
      }

      // Generate payment ID
      final paymentId = 'sub_${DateTime.now().millisecondsSinceEpoch}_$planType';
      
      // Process payment using PaymentService
      final result = await PaymentService.processPayment(
        paymentId: paymentId,
        amount: amount,
        description: '$planType subscription plan',
        paymentType: 'subscription',
        itemId: planType,
        metadata: {
          'planType': planType,
          'billingCycle': billingCycle,
          'amount': amount,
        },
      );

      // Check if payment was initiated successfully (not completed yet)
      if (result['success'] == true) {
        // Payment gateway opened successfully, close dialog
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment gateway opened. Complete payment to unlock videos.'),
              backgroundColor: Color(0xFF4F46E5),
            ),
          );
        }
      } else {
        _showError('Failed to open payment gateway. Please try again.');
      }
    } catch (e) {
      _showError('Payment failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          if (planType == 'monthly') {
            _isMonthlyLoading = false;
          } else {
            _isQuarterlyLoading = false;
          }
        });
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
