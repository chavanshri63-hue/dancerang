part of '../home_screen.dart';

// Studio Tab
class StudioTab extends StatefulWidget {
  const StudioTab({super.key});

  @override
  State<StudioTab> createState() => _StudioTabState();
}
class _StudioTabState extends State<StudioTab> with TickerProviderStateMixin {
  late TabController _tabController;
  final PageController _galleryController = PageController();
  int _currentGalleryIndex = 0;
  
  // Studio data from Firebase
  List<String> _studioImages = [];
  Map<String, dynamic> _studioData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStudioData();
  }

  Future<void> _loadStudioData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('studioData')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _studioData = {
            'weekdayRate': data['weekdayRate'] ?? 1000,
            'weekendRate': data['weekendRate'] ?? 1200,
            'packageWeekdayRate': data['packageWeekdayRate'] ?? 700,
            'packageWeekendRate': data['packageWeekendRate'] ?? 800,
            'packageMinHours': data['packageMinHours'] ?? 5,
            'capacity': data['capacity'] ?? '30-40 people max',
            'gracePeriod': data['gracePeriod'] ?? '15 min grace period',
            'equipment': List<String>.from(data['equipment'] ?? [
              'Sound System',
              'Professional Lights',
              'Air Conditioning',
              'Full-length Mirrors',
              'Dance Floor',
              'Storage Space',
            ]),
            'rules': List<String>.from(data['rules'] ?? [
              '15 minutes grace period for setup',
              'Noise levels must be maintained',
              'Equipment must be handled carefully',
              'No food or drinks in studio',
              'Clean up after use',
              'Booking cancellation 2 hours prior',
            ]),
          };
          _isLoading = false;
        });
      } else {
        _setDefaultStudioData();
      }
    } catch (e) {
      _setDefaultStudioData();
    }
  }

  Map<String, dynamic> _getDefaultStudioData() {
    return {
      'weekdayRate': 1000,
      'weekendRate': 1200,
      'packageWeekdayRate': 700,
      'packageWeekendRate': 800,
      'packageMinHours': 5,
      'capacity': '30-40 people max',
      'gracePeriod': '15 min grace period',
      'equipment': [
        'Sound System',
        'Professional Lights',
        'Air Conditioning',
        'Full-length Mirrors',
        'Dance Floor',
        'Storage Space',
      ],
      'rules': [
        '15 minutes grace period for setup',
        'Noise levels must be maintained',
          'Equipment must be handled carefully',
          'No food or drinks in studio',
          'Clean up after use',
          'Booking cancellation 2 hours prior',
        ],
      };
  }

  void _setDefaultStudioData() {
    setState(() {
      _studioData = _getDefaultStudioData();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _galleryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Studio Booking',
        actions: [
          // QR Scanner options for Admin/Faculty
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseAuth.instance.currentUser != null 
                ? FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).snapshots()
                : const Stream.empty(),
            builder: (context, userSnapshot) {
              final userRole = userSnapshot.data?.data()?['role']?.toString().toLowerCase() ?? '';
              final isAdminOrFaculty = userRole == 'admin' || userRole == 'faculty';
              
              if (!isAdminOrFaculty) {
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calendar_today, color: Colors.white),
                      onPressed: _showAvailabilityCalendar,
                    ),
                    IconButton(
                      icon: const Icon(Icons.history, color: Colors.white),
                      onPressed: _showBookingHistory,
                    ),
                  ],
                );
              }
              
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_today, color: Colors.white),
                    onPressed: _showAvailabilityCalendar,
                  ),
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.white),
                    onPressed: _showBookingHistory,
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('appSettings')
            .doc('studioData')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading studio data: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data?.data();
          final studioData = data != null ? {
            'weekdayRate': data['weekdayRate'] ?? 1000,
            'weekendRate': data['weekendRate'] ?? 1200,
            'packageWeekdayRate': data['packageWeekdayRate'] ?? 700,
            'packageWeekendRate': data['packageWeekendRate'] ?? 800,
            'packageMinHours': data['packageMinHours'] ?? 5,
            'capacity': data['capacity'] ?? '30-40 people max',
            'gracePeriod': data['gracePeriod'] ?? '15 min grace period',
            'equipment': List<String>.from(data['equipment'] ?? [
              'Sound System',
              'Professional Lights',
              'Air Conditioning',
              'Full-length Mirrors',
              'Dance Floor',
              'Storage Space',
            ]),
            'rules': List<String>.from(data['rules'] ?? [
              '15 minutes grace period for setup',
              'Noise levels must be maintained',
              'Equipment must be handled carefully',
              'No food or drinks in studio',
              'Clean up after use',
              'Booking cancellation 2 hours prior',
            ]),
          } : _getDefaultStudioData();

          return SingleChildScrollView(
            child: Column(
              children: [
                // Studio Banner Carousel (same as home)
                _StudioBannerCarousel(),
                const SizedBox(height: 16),
                _buildPricingSection(studioData),
                _buildEquipmentSection(studioData),
                _buildStudioRulesSection(studioData),
                _buildContactSection(),
                const SizedBox(height: 100), // Space for floating button
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'studio_tab_book_button',
        onPressed: _showBookingForm,
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.event_available),
        label: const Text('Book Studio'),
      ),
    );
  }

  Widget _buildStudioGallery(List<String> images, Map<String, dynamic> studioData) {
    // Ensure current index is valid
    if (images.isNotEmpty && _currentGalleryIndex >= images.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _galleryController.hasClients) {
          _galleryController.jumpToPage(0);
          setState(() {
            _currentGalleryIndex = 0;
          });
        }
      });
    }
    
    return Column(
      children: [
        // Studio Gallery Slider
        Container(
          height: 250,
          margin: const EdgeInsets.all(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PageView.builder(
                controller: _galleryController,
                physics: images.length > 1 
                    ? const PageScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                scrollDirection: Axis.horizontal,
                onPageChanged: (index) {
                  if (mounted) {
                    setState(() {
                      _currentGalleryIndex = index;
                    });
                  }
                },
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        cacheWidth: 800,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: const Color(0xFF1B1B1B),
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                color: const Color(0xFFE53935),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFF1B1B1B),
                            child: const Center(
                              child: Icon(
                                Icons.image,
                                color: Colors.white30,
                                size: 48,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      images.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentGalleryIndex == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Photos & Videos Tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildMediaCard('Photos', Icons.photo_library, Colors.blue),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Studio Info Cards
        _buildInfoCard('Capacity', studioData['capacity'] ?? '30-40 people max', Icons.people),
        _buildInfoCard('Time Management', studioData['gracePeriod'] ?? '15 min grace period', Icons.access_time),
        _buildInfoCard('Noise Policy', 'Sound level guidelines apply', Icons.volume_up),
      ],
    );
  }

  Widget _buildMediaCard(String title, IconData icon, Color color) {
    return Card(
      color: const Color(0xFF1B1B1B),
      child: InkWell(
        onTap: () => _showMediaViewer(title),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                '${_studioImages.length} images',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMediaViewer(String type) {
    _showImageGallery();
  }

  void _showImageGallery() {
    if (_studioImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images available')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Studio Images', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: PageView.builder(
            itemCount: _studioImages.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(_studioImages[index]),
                    fit: BoxFit.contain,
                    onError: (exception, stackTrace) {
                    },
                  ),
                ),
              );
            },
          ),
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


  Widget _buildInfoCard(String title, String subtitle, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: const Color(0xFF1B1B1B),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFE53935)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }

  Widget _buildPricingSection(Map<String, dynamic> studioData) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Studio Pricing',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Regular Pricing
          _buildPricingCard(
            'Regular Rates',
            [
              _buildPricingItem('Weekdays', '₹${studioData['weekdayRate'] ?? 1000}/hour'),
              _buildPricingItem('Weekends', '₹${studioData['weekendRate'] ?? 1200}/hour'),
            ],
            Colors.blue,
          ),
          
          const SizedBox(height: 16),
          
          // Package Deals
          _buildPricingCard(
            'Package Deals',
            [
              _buildPricingItem('Weekdays (${studioData['packageMinHours'] ?? 5}+ hours)', '₹${studioData['packageWeekdayRate'] ?? 700}/hour'),
              _buildPricingItem('Weekends (${studioData['packageMinHours'] ?? 5}+ hours)', '₹${studioData['packageWeekendRate'] ?? 800}/hour'),
            ],
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(String title, List<Widget> items, Color color) {
    return Card(
      color: const Color(0xFF1B1B1B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildPricingItem(String label, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStudioRulesSection(Map<String, dynamic> studioData) {
    final rules = List<String>.from(studioData['rules'] ?? []);
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Studio Rules & Policies',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF1B1B1B),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...rules.map((rule) => _buildRuleItem('• $rule')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String rule) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(rule, style: const TextStyle(color: Colors.white70)),
    );
  }

  Widget _buildEquipmentSection(Map<String, dynamic> studioData) {
    final equipment = List<String>.from(studioData['equipment'] ?? []);
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Studio Equipment',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...equipment.map((item) => _buildEquipmentCard(item, 'Professional equipment', _getEquipmentIcon(item))),
        ],
      ),
    );
  }

  IconData _getEquipmentIcon(String equipment) {
    switch (equipment.toLowerCase()) {
      case 'sound system':
        return Icons.speaker;
      case 'professional lights':
        return Icons.lightbulb;
      case 'air conditioning':
        return Icons.ac_unit;
      case 'full-length mirrors':
        return Icons.visibility;
      case 'dance floor':
        return Icons.directions_run;
      case 'storage space':
        return Icons.storage;
      default:
        return Icons.build;
    }
  }

  Widget _buildEquipmentCard(String title, String description, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFF1B1B1B),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4F46E5), size: 32),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(description, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact Studio',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF1B1B1B),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('app_config')
                    .doc('contact_info')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'Error loading contact info',
                      style: TextStyle(color: Colors.red),
                    );
                  }
                  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  
                  final data = snapshot.data?.data() ?? {};
                  final phone = data['phone'] ?? '+91 98765 43210';
                  final whatsapp = data['whatsapp'] ?? '919999999999';
                  final email = data['email'] ?? 'info@dancerang.com';
                  
                  return Column(
                    children: [
                      _buildContactItem(Icons.phone, 'Call Studio Manager', phone),
                      _buildContactItem(Icons.message, 'WhatsApp Booking', whatsapp),
                      _buildContactItem(Icons.email, 'Email Support', email),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF262626)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white70)),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String contactInfo) {
    return InkWell(
      onTap: () => _handleContact(icon, contactInfo),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF4F46E5)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white)),
                  Text(
                    contactInfo,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  // Action Methods
  void _showAvailabilityCalendar() {
    showDialog(
      context: context,
      builder: (context) => StudioAvailabilityCalendar(),
    );
  }
  // Check for booking conflicts
  Future<Map<String, dynamic>> _checkBookingConflicts(DateTime date, TimeOfDay time, int duration) async {
    try {
      final startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      final endTime = startTime.add(Duration(hours: duration));
      
      // Get all bookings for the selected date
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('studioBookings')
          .where('date', isEqualTo: Timestamp.fromDate(date))
          .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
          .get();

      for (final doc in bookingsSnapshot.docs) {
        final bookingData = doc.data();
        final bookingTime = bookingData['time'] as String;
        final bookingDuration = bookingData['duration'] as int;
        
        // Parse booking time
        final timeParts = bookingTime.split(':');
        final bookingStart = DateTime(
          date.year, 
          date.month, 
          date.day, 
          int.parse(timeParts[0]), 
          int.parse(timeParts[1])
        );
        final bookingEnd = bookingStart.add(Duration(hours: bookingDuration));
        
        // Check for time overlap
        if (startTime.isBefore(bookingEnd) && endTime.isAfter(bookingStart)) {
          return {
            'hasConflict': true,
            'message': 'Time slot overlaps with existing booking from ${bookingTime} to ${bookingEnd.hour.toString().padLeft(2, '0')}:${bookingEnd.minute.toString().padLeft(2, '0')}',
          };
        }
      }
      
      return {'hasConflict': false, 'message': ''};
    } catch (e) {
      return {'hasConflict': true, 'message': 'Error checking conflicts: $e'};
    }
  }
  void _showBookingHistory() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to view bookings')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF1B1B1B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('My Studio Bookings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('studioBookings')
                      .where('userId', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white70));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('No bookings yet', style: TextStyle(color: Colors.white70)),
                      );
                    }
                    final docs = [...snapshot.data!.docs];
                    // Client-side sort by createdAt desc to avoid index requirement
                    docs.sort((a, b) {
                      final ta = a.data()['createdAt'];
                      final tb = b.data()['createdAt'];
                      final da = ta is Timestamp ? ta.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                      final db = tb is Timestamp ? tb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                      return db.compareTo(da);
                    });
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final d = docs[index].data();
                        final status = (d['status'] as String? ?? 'pending');
                        final date = (d['date'] is Timestamp) ? (d['date'] as Timestamp).toDate() : null;
                        final time = (d['time'] as String? ?? '');
                        final duration = (d['duration'] as int? ?? 1);
                        final amount = (d['advanceAmount'] as int? ?? 0);
                        return GestureDetector(
                          onTap: () => _showBookingDetails(docs[index].id, d),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        date != null ? 'Date: ${date.day}/${date.month}/${date.year}  •  $time' : 'Date: —  •  $time',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Duration: ${duration}h', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      const SizedBox(height: 8),
                                      _statusBadge(status),
                                    ],
                                  ),
                                ),
                                Text('₹$amount', style: const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'confirmed':
        color = const Color(0xFF10B981);
        break;
      case 'in_progress':
        color = const Color(0xFFFF9800);
        break;
      case 'completed':
        color = const Color(0xFF4F46E5);
        break;
      default:
        color = const Color(0xFFE53935); // pending/cancelled
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showBookingDetails(String bookingId, Map<String, dynamic> booking) {
    final date = (booking['date'] is Timestamp) ? (booking['date'] as Timestamp).toDate() : null;
    final time = (booking['time'] as String? ?? '');
    final duration = (booking['duration'] as int? ?? 1);
    final name = (booking['name'] as String? ?? '—');
    final branch = (booking['branch'] as String? ?? '—');
    final totalAmount = (booking['totalAmount'] as int? ?? 0);
    final advanceAmount = (booking['advanceAmount'] as int? ?? 0);
    final finalAmount = (booking['finalAmount'] as int? ?? 0);
    final pendingAmount = finalAmount > 0 ? finalAmount : (totalAmount - advanceAmount);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Booking Details', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $name', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              date != null ? 'Date: ${date.day}/${date.month}/${date.year}' : 'Date: —',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text('Time: $time', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Duration: ${duration}h', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Branch: $branch', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Text('Total Amount: ₹$totalAmount', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 4),
            Text('Paid Amount: ₹$advanceAmount', style: const TextStyle(color: Colors.greenAccent)),
            const SizedBox(height: 4),
            Text('Pending Amount: ₹${pendingAmount < 0 ? 0 : pendingAmount}', style: const TextStyle(color: Colors.orangeAccent)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (pendingAmount > 0)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _payPendingAmount(bookingId, booking, pendingAmount);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
              ),
              child: const Text('Pay Pending'),
            ),
        ],
      ),
    );
  }

  Future<void> _payPendingAmount(String bookingId, Map<String, dynamic> booking, int pendingAmount) async {
    final choice = await PaymentOptionDialog.show(context);
    if (choice == null) return;
    final dateIso = (booking['date'] is Timestamp)
        ? (booking['date'] as Timestamp).toDate().toIso8601String()
        : '';
    if (choice == PaymentChoice.cash) {
      final paymentId = PaymentService.generatePaymentId();
      final res = await PaymentService.requestCashPayment(
        paymentId: paymentId,
        amount: pendingAmount,
        description: 'Studio Booking Pending: ${booking['duration'] ?? 1}h',
        paymentType: 'studio_booking',
        itemId: bookingId,
        metadata: {
          'booking_id': bookingId,
          'name': booking['name'] ?? '',
          'phone': booking['phone'] ?? '',
          'purpose': booking['purpose'] ?? '',
          'date': dateIso,
          'time': booking['time'] ?? '',
          'duration': booking['duration'] ?? 1,
          'total_amount': booking['totalAmount'] ?? pendingAmount,
          'advance_amount': booking['advanceAmount'] ?? 0,
          'final_amount': pendingAmount,
          'payment_stage': 'pending',
        },
      );
      if (res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sent for admin confirmation (cash payment)'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    if (choice == PaymentChoice.online) {
      final paymentId = PaymentService.generatePaymentId();
      final result = await PaymentService.processPayment(
        paymentId: paymentId,
        amount: pendingAmount,
        description: 'Studio Booking Pending: ${booking['duration'] ?? 1}h',
        paymentType: 'studio_booking',
        itemId: bookingId,
        metadata: {
          'booking_id': bookingId,
          'name': booking['name'] ?? '',
          'phone': booking['phone'] ?? '',
          'purpose': booking['purpose'] ?? '',
          'date': dateIso,
          'time': booking['time'] ?? '',
          'duration': booking['duration'] ?? 1,
          'total_amount': booking['totalAmount'] ?? pendingAmount,
          'advance_amount': booking['advanceAmount'] ?? 0,
          'final_amount': pendingAmount,
          'payment_stage': 'pending',
        },
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Redirecting to payment...'), backgroundColor: Colors.orange),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${result['error'] ?? 'Unknown error'}'), backgroundColor: Colors.red),
        );
      }
    }
  }


  void _selectDate() {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
  }

  void _selectTime() {
    showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
  }

  void _selectDuration() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Select Duration', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(8, (index) {
            final hours = index + 1;
            return ListTile(
              title: Text('$hours hour${hours > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Selected $hours hour${hours > 1 ? 's' : ''}')),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  void _showBookingForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingFormDialog(studioData: _studioData),
    );
  }

  void _showBookingConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Confirm Booking', style: TextStyle(color: Colors.white)),
        content: const Text('Proceed with payment?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Booking confirmed! WhatsApp notification sent.'),
                  backgroundColor: Color(0xFF4F46E5),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            child: const Text('Pay & Book'),
          ),
        ],
      ),
    );
  }

  void _handleContact(IconData icon, String contactInfo) async {
    try {
      if (icon == Icons.phone) {
        // Make phone call
        final phoneNumber = contactInfo.replaceAll(RegExp(r'[^\d+]'), '');
        final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);
        } else {
          _showErrorSnackBar('Cannot make phone call to $contactInfo');
        }
      } else if (icon == Icons.message) {
        // Open WhatsApp
        final phoneNumber = contactInfo.replaceAll(RegExp(r'[^\d]'), '');
        final Uri whatsappUri = Uri.parse('https://wa.me/$phoneNumber');
        if (await canLaunchUrl(whatsappUri)) {
          await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        } else {
          _showErrorSnackBar('Cannot open WhatsApp with $contactInfo');
        }
      } else if (icon == Icons.email) {
        // Open email client
        final Uri emailUri = Uri(
          scheme: 'mailto',
          path: contactInfo,
          query: 'subject=Studio Booking Inquiry&body=Hello, I would like to inquire about studio booking.',
        );
        if (await canLaunchUrl(emailUri)) {
          await launchUrl(emailUri);
        } else {
          _showErrorSnackBar('Cannot open email client for $contactInfo');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Booking Form Dialog
class _BookingFormDialog extends StatefulWidget {
  final Map<String, dynamic> studioData;
  
  const _BookingFormDialog({required this.studioData});

  @override
  _BookingFormDialogState createState() => _BookingFormDialogState();
}
class _BookingFormDialogState extends State<_BookingFormDialog> {
  static const List<String> _fallbackBranches = ['Balewadi', 'Wakad'];
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _selectedDuration = 1;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  List<String> _branches = [];
  String _selectedBranch = '';
  Map<String, Map<String, List<String>>> _availabilityOverrides = {};
  List<Map<String, String>> _weeklyBlockedRanges = [];

  @override
  void initState() {
    super.initState();
    _loadAvailabilitySettings();
    _loadBranches();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      await BranchesService.initializeDefaultBranches();
      final branches = await BranchesService.getAllBranches();
      final seen = <String>{};
      _branches = branches
          .map((branch) => branch.name.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e[0].toUpperCase() + e.substring(1))
          .where((e) => seen.add(e.toLowerCase()))
          .toList();
      if (_branches.isEmpty) {
        _branches = List<String>.from(_fallbackBranches);
      }
      _branches.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (_selectedBranch.isEmpty && _branches.isNotEmpty) {
        _selectedBranch = _branches.first;
      }
      if (mounted) setState(() {});
    } catch (e) {
      _branches = List<String>.from(_fallbackBranches);
      if (_selectedBranch.isEmpty && _branches.isNotEmpty) {
        _selectedBranch = _branches.first;
      }
      if (mounted) setState(() {});
    }
  }
  Future<void> _loadAvailabilitySettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('studioAvailability')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _availabilityOverrides = Map<String, Map<String, List<String>>>.from(
            (data['overrides'] ?? {}).map<String, Map<String, List<String>>>((k, v) => MapEntry(
                  k as String,
                  {
                    'availableTimes': List<String>.from((v['availableTimes'] ?? []) as List),
                    'blockedTimes': List<String>.from((v['blockedTimes'] ?? []) as List),
                  },
                )),
          );
          _weeklyBlockedRanges = List<Map<String, String>>.from(
            (data['weeklyRule']?['blockedRanges'] ?? []).map<Map<String, String>>((r) => {
                  'start': r['start'] as String,
                  'end': r['end'] as String,
                }),
          );
        });
      } else {
      }
    } catch (e) {
    }
  }

  String _formatDateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isBlockedByWeeklyRule(String time) {
    // time: HH:00
    final hour = int.parse(time.split(':')[0]);
    for (final range in _weeklyBlockedRanges) {
      final startHour = int.parse(range['start']!.split(':')[0]);
      final endHour = int.parse(range['end']!.split(':')[0]);
      if (hour >= startHour && hour < endHour) return true;
    }
    return false;
  }

  bool _isAvailableForDate(DateTime date, String time) {
    final key = _formatDateKey(date);
    final override = _availabilityOverrides[key];
    if (override != null) {
      if (override['blockedTimes']!.contains(time)) {
        return false;
      }
      if (override['availableTimes']!.contains(time)) {
        return true;
      }
    }
    // Default: available unless weekly rule blocks it
    final isBlockedByWeekly = _isBlockedByWeeklyRule(time);
    if (isBlockedByWeekly) {
    }
    return !isBlockedByWeekly;
  }

  // Check for booking conflicts
  Future<Map<String, dynamic>> _checkBookingConflicts(DateTime date, TimeOfDay time, int duration) async {
    try {
      final startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      final endTime = startTime.add(Duration(hours: duration));
      
      // Check if admin has blocked any part of this time slot
      for (int hour = time.hour; hour < time.hour + duration; hour++) {
        final timeSlot = '${hour.toString().padLeft(2, '0')}:00';
        if (!_isAvailableForDate(date, timeSlot)) {
          return {
            'hasConflict': true,
            'message': 'This time slot is blocked by admin availability settings',
          };
        }
      }
      
      // Get all bookings for the selected date
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('studioBookings')
          .where('date', isEqualTo: Timestamp.fromDate(date))
          .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
          .get();

      for (final doc in bookingsSnapshot.docs) {
        final bookingData = doc.data();
        final bookingTime = bookingData['time'] as String;
        final bookingDuration = bookingData['duration'] as int;
        
        // Parse booking time
        final timeParts = bookingTime.split(':');
        final bookingStart = DateTime(
          date.year, 
          date.month, 
          date.day, 
          int.parse(timeParts[0]), 
          int.parse(timeParts[1])
        );
        final bookingEnd = bookingStart.add(Duration(hours: bookingDuration));
        
        // Check for time overlap
        if (startTime.isBefore(bookingEnd) && endTime.isAfter(bookingStart)) {
          return {
            'hasConflict': true,
            'message': 'Time slot overlaps with existing booking from ${bookingTime} to ${bookingEnd.hour.toString().padLeft(2, '0')}:${bookingEnd.minute.toString().padLeft(2, '0')}',
          };
        }
      }
      
      return {'hasConflict': false, 'message': ''};
    } catch (e) {
      return {'hasConflict': true, 'message': 'Error checking conflicts: $e'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B1B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Book Studio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          
          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Booking Details Section
                  _buildSectionTitle('Booking Details'),
                  const SizedBox(height: 16),
                  
                  _buildFormField(
                    'Select Date',
                    _selectedDate != null 
                        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                        : 'Choose date',
                    Icons.calendar_today,
                    () => _selectDate(),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildFormField(
                    'Select Time',
                    _selectedTime != null 
                        ? _selectedTime!.format(context)
                        : 'Choose time',
                    Icons.access_time,
                    () => _selectTime(),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildFormField(
                    'Duration',
                    '$_selectedDuration hour${_selectedDuration > 1 ? 's' : ''}',
                    Icons.timer,
                    () => _selectDuration(),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  if (_branches.isNotEmpty)
                    _buildBranchDropdown(),
                  
                  const SizedBox(height: 24),
                  
                  // Personal Details Section
                  _buildSectionTitle('Personal Details'),
                  const SizedBox(height: 16),
                  
                  _buildTextField('Full Name', _nameController, Icons.person),
                  const SizedBox(height: 12),
                  _buildTextField('Phone Number', _phoneController, Icons.phone),
                  const SizedBox(height: 12),
                  _buildTextField('Purpose of Booking', _purposeController, Icons.description),
                  
                  const SizedBox(height: 24),
                  
                  // Pricing Summary
                  _buildPricingSummary(),
                  
                  const SizedBox(height: 24),
                  
                  // Payment Options
                  _buildPaymentOptions(),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildBranchDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Branch', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF262626),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF404040)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _branches.contains(_selectedBranch)
                  ? _selectedBranch
                  : (_branches.isNotEmpty ? _branches.first : null),
              isExpanded: true,
              dropdownColor: const Color(0xFF1B1B1B),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE53935)),
              items: _branches
                  .map((branch) => DropdownMenuItem(value: branch, child: Text(branch)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedBranch = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormField(String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF404040)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFE53935)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: const Color(0xFFE53935)),
        filled: true,
        fillColor: const Color(0xFF262626),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF404040)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF404040)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
        ),
      ),
    );
  }

  Widget _buildPricingSummary() {
    final isWeekend = _selectedDate?.weekday == DateTime.saturday || _selectedDate?.weekday == DateTime.sunday;
    final isPackage = _selectedDuration >= (widget.studioData['packageMinHours'] ?? 5);
    
    int rate;
    if (isPackage) {
      rate = isWeekend 
          ? (widget.studioData['packageWeekendRate'] ?? 800)
          : (widget.studioData['packageWeekdayRate'] ?? 700);
    } else {
      rate = isWeekend 
          ? (widget.studioData['weekendRate'] ?? 1200)
          : (widget.studioData['weekdayRate'] ?? 1000);
    }
    
    final totalAmount = rate * _selectedDuration;
    final advanceAmount = (totalAmount * 0.5).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pricing Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Rate per hour:', style: TextStyle(color: Colors.white70)),
              Text('₹$rate/hour', style: const TextStyle(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Duration:', style: TextStyle(color: Colors.white70)),
              Text('$_selectedDuration hour${_selectedDuration > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount:', style: TextStyle(color: Colors.white70)),
              Text('₹$totalAmount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(color: Color(0xFF404040)),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Advance Payment (50%):', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
              Text('₹$advanceAmount', style: const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Options',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Pay 50% Now Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _processBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Pay 50% Now & Book',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Pay Full Amount Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _processFullPayment,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE53935)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Pay Full Amount',
              style: TextStyle(color: Color(0xFFE53935), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
      
      // Show available times for the selected date
      _showAvailableTimesForDate(date);
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }
  // Show available times for selected date
  void _showAvailableTimesForDate(DateTime date) async {
    try {
      // Get all bookings for the selected date
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('studioBookings')
          .where('date', isEqualTo: Timestamp.fromDate(date))
          .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
          .get();

      final bookedTimes = <Map<String, dynamic>>[];
      for (final doc in bookingsSnapshot.docs) {
        final bookingData = doc.data();
        final bookingTime = bookingData['time'] as String;
        final duration = bookingData['duration'] as int;
        final name = bookingData['name'] as String;
        final status = bookingData['status'] as String;
        
        // Calculate end time
        final timeParts = bookingTime.split(':');
        final startHour = int.parse(timeParts[0]);
        final startMinute = int.parse(timeParts[1]);
        final endHour = startHour + duration;
        final endTime = '${endHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
        
        bookedTimes.add({
          'startTime': bookingTime,
          'endTime': endTime,
          'duration': duration,
          'name': name,
          'status': status,
        });
      }

      // Generate available time slots (9 AM to 10 PM, 1-hour slots)
      final availableSlots = <String>[];
      for (int hour = 9; hour <= 22; hour++) {
        final timeSlot = '${hour.toString().padLeft(2, '0')}:00';
        
        // Check if admin has blocked this time slot
        if (!_isAvailableForDate(date, timeSlot)) {
          continue; // Skip this time slot - admin has blocked it
        }
        
        // Check if this time slot conflicts with any existing booking
        bool hasConflict = false;
        for (final booking in bookedTimes) {
          final bookingStart = booking['startTime'] as String;
          final bookingEnd = booking['endTime'] as String;
          
          // Parse booking times
          final startParts = bookingStart.split(':');
          final endParts = bookingEnd.split(':');
          final bookingStartHour = int.parse(startParts[0]);
          final bookingEndHour = int.parse(endParts[0]);
          
          // Check if our time slot overlaps with the booking
          if (hour >= bookingStartHour && hour < bookingEndHour) {
            hasConflict = true;
            break;
          }
        }
        
        if (!hasConflict) {
          availableSlots.add(timeSlot);
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1B1B1B),
            title: Text(
              'Available Times - ${date.day}/${date.month}/${date.year}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bookedTimes.isNotEmpty) ...[
                    const Text(
                      'Booked Times:',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...bookedTimes.map((booking) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: booking['status'] == 'confirmed' 
                                  ? Colors.green 
                                  : booking['status'] == 'in_progress'
                                      ? Colors.blue
                                      : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${booking['startTime']} - ${booking['endTime']} (${booking['name']} - ${booking['duration']}h)',
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),
                  ],
                  
                  const Text(
                    'Available Times:',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  if (availableSlots.isEmpty)
                    const Text(
                      'No available time slots for this date',
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableSlots.map((time) => GestureDetector(
                        onTap: () {
                          final timeParts = time.split(':');
                          final selectedTime = TimeOfDay(
                            hour: int.parse(timeParts[0]),
                            minute: int.parse(timeParts[1]),
                          );
                          setState(() {
                            _selectedTime = selectedTime;
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Time selected: $time'),
                              backgroundColor: const Color(0xFFE53935),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            time,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      )).toList(),
                    ),
                ],
              ),
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
    } catch (e) {
    }
  }

  void _selectDuration() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Select Duration', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(8, (index) {
            final hours = index + 1;
            return ListTile(
              title: Text('$hours hour${hours > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white)),
              onTap: () {
                setState(() {
                  _selectedDuration = hours;
                });
                Navigator.pop(context);
              },
            );
          }),
        ),
      ),
    );
  }
  void _processBooking() async {
    if (_selectedDate == null || _selectedTime == null || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    if (_selectedBranch.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a branch')),
      );
      return;
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to book studio time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check for booking conflicts first
    final conflictCheck = await _checkBookingConflicts(_selectedDate!, _selectedTime!, _selectedDuration);
    if (conflictCheck['hasConflict']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Time slot conflict: ${conflictCheck['message']}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Calculate amount (50% advance)
    final totalAmount = _calculateTotalAmount();
    final advanceAmount = (totalAmount * 0.5).round();

    // Create studio booking first
    final bookingRef = FirebaseFirestore.instance.collection('studioBookings').doc();
    final bookingId = bookingRef.id;

    final bookingData = {
      'bookingId': bookingId,
      'userId': user.uid,
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'purpose': _purposeController.text.trim(),
      'branch': _selectedBranch,
      'date': Timestamp.fromDate(_selectedDate!),
      'time': '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
      'duration': _selectedDuration,
      'status': 'pending',
      'totalAmount': totalAmount,
      'advanceAmount': advanceAmount,
      'finalAmount': totalAmount - advanceAmount,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await bookingRef.set(bookingData);
      
      // Choose payment method for advance amount
      final choice = await PaymentOptionDialog.show(context);
      if (choice == PaymentChoice.cash) {
        final paymentId = PaymentService.generatePaymentId();
        final res = await PaymentService.requestCashPayment(
          paymentId: paymentId,
          amount: advanceAmount,
          description: 'Studio Booking Advance: ${_selectedDuration}h on ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
          paymentType: 'studio_booking',
          itemId: bookingId,
          metadata: {
            'booking_id': bookingId,
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'purpose': _purposeController.text.trim(),
            'branch': _selectedBranch,
            'date': _selectedDate!.toIso8601String(),
            'time': '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
            'duration': _selectedDuration,
            'total_amount': totalAmount,
            'advance_amount': advanceAmount,
            'final_amount': totalAmount - advanceAmount,
          },
        );
        Navigator.pop(context);
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sent for admin confirmation (cash payment)'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      if (choice == PaymentChoice.online) {
        final paymentId = PaymentService.generatePaymentId();
        final result = await PaymentService.processPayment(
          paymentId: paymentId,
          amount: advanceAmount,
          description: 'Studio Booking Advance: ${_selectedDuration}h on ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
          paymentType: 'studio_booking',
          itemId: bookingId,
          metadata: {
            'booking_id': bookingId,
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'purpose': _purposeController.text.trim(),
            'branch': _selectedBranch,
            'date': _selectedDate!.toIso8601String(),
            'time': '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
            'duration': _selectedDuration,
            'total_amount': totalAmount,
            'advance_amount': advanceAmount,
            'final_amount': totalAmount - advanceAmount,
          },
        );

        Navigator.pop(context);
        
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Redirecting to payment...'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: ${result['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _processFullPayment() async {
    if (_selectedDate == null || _selectedTime == null || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    if (_selectedBranch.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a branch')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to book studio time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final conflictCheck = await _checkBookingConflicts(_selectedDate!, _selectedTime!, _selectedDuration);
    if (conflictCheck['hasConflict']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Time slot conflict: ${conflictCheck['message']}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final totalAmount = _calculateTotalAmount();
    final bookingRef = FirebaseFirestore.instance.collection('studioBookings').doc();
    final bookingId = bookingRef.id;
    final bookingData = {
      'bookingId': bookingId,
      'userId': user.uid,
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'purpose': _purposeController.text.trim(),
      'branch': _selectedBranch,
      'date': Timestamp.fromDate(_selectedDate!),
      'time': '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
      'duration': _selectedDuration,
      'status': 'pending',
      'totalAmount': totalAmount,
      'advanceAmount': totalAmount,
      'finalAmount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await bookingRef.set(bookingData);
      final choice = await PaymentOptionDialog.show(context);
      if (choice == PaymentChoice.cash) {
        final paymentId = PaymentService.generatePaymentId();
        final res = await PaymentService.requestCashPayment(
          paymentId: paymentId,
          amount: totalAmount,
          description: 'Studio Booking Full: ${_selectedDuration}h on ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
          paymentType: 'studio_booking',
          itemId: bookingId,
          metadata: {
            'booking_id': bookingId,
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'purpose': _purposeController.text.trim(),
            'branch': _selectedBranch,
            'date': _selectedDate!.toIso8601String(),
            'time': '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
            'duration': _selectedDuration,
            'total_amount': totalAmount,
            'advance_amount': totalAmount,
            'final_amount': 0,
            'payment_stage': 'full',
          },
        );
        Navigator.pop(context);
        if (res['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sent for admin confirmation (cash payment)'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      if (choice == PaymentChoice.online) {
        final paymentId = PaymentService.generatePaymentId();
        final result = await PaymentService.processPayment(
          paymentId: paymentId,
          amount: totalAmount,
          description: 'Studio Booking Full: ${_selectedDuration}h on ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
          paymentType: 'studio_booking',
          itemId: bookingId,
          metadata: {
            'booking_id': bookingId,
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'purpose': _purposeController.text.trim(),
            'branch': _selectedBranch,
            'date': _selectedDate!.toIso8601String(),
            'time': '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
            'duration': _selectedDuration,
            'total_amount': totalAmount,
            'advance_amount': totalAmount,
            'final_amount': 0,
            'payment_stage': 'full',
          },
        );
        Navigator.pop(context);
        if (!mounted) return;
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Redirecting to payment...'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: ${result['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _calculateTotalAmount() {
    // Get rates from studio data
    final weekdayRate = widget.studioData['weekdayRate'] ?? 1000;
    final weekendRate = widget.studioData['weekendRate'] ?? 1200;
    
    // Check if selected date is weekend (Saturday = 6, Sunday = 7)
    final isWeekend = _selectedDate?.weekday == 6 || _selectedDate?.weekday == 7;
    final hourlyRate = isWeekend ? weekendRate : weekdayRate;
    
    return hourlyRate * _selectedDuration;
  }
}
