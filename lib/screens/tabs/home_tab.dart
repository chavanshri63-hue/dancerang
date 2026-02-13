part of '../home_screen.dart';

// Live banners from Firestore
class _LiveBannerCarousel extends StatefulWidget {
  const _LiveBannerCarousel({super.key});
  @override
  State<_LiveBannerCarousel> createState() => _LiveBannerCarouselState();
}

class _LiveBannerCarouselState extends State<_LiveBannerCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.96);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AdminService.readBannersJson(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(height: 280);
        }
        final raw = snapshot.data!;
        if (raw.isEmpty) {
          // Fallback placeholder when no active banners
          return SizedBox(
            height: 280,
            child: Card(
              elevation: 8,
              shadowColor: const Color(0xFFE53935).withValues(alpha: 0.3),
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.4), width: 2),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.campaign_rounded,
                      size: 48,
                      color: const Color(0xFFE53935).withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No banners yet',
                      style: const TextStyle(
                        color: Color(0xFFF9FAFB), 
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Banners will appear here',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final banners = raw.map((m) => AppBanner.fromMap(m)).where((b) => b.isActive).toList()
          ..sort((a, b) => a.sort.compareTo(b.sort));
        if (banners.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _controller,
                itemCount: banners.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final b = banners[i];
                  final title = b.title;
                  final imageUrl = b.imageUrl;
                  final ctaText = b.ctaText;
                  final ctaLink = b.ctaLink;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Card(
                      elevation: 8,
                      shadowColor: const Color(0xFFE53935).withValues(alpha: 0.3),
                      color: Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.4), width: 2),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: ctaLink == null || ctaLink.isEmpty ? null : () async {
                          try {
                            final uri = Uri.parse(ctaLink);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Cannot open: $ctaLink'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error opening link: $e'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (imageUrl.isNotEmpty && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')))
                                Image.network(
                                  imageUrl, 
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: const Color(0xFF111111),
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
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Color(0xFFF9FAFB), 
                                        fontSize: 24, 
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black,
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    if (ctaText != null && ctaText.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFE53935).withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          ctaText, 
                                          style: const TextStyle(
                                            color: Colors.white, 
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 16,
                                            letterSpacing: 0.5,
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
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(banners.length, (i) {
                final active = i == _index;
                return Container(
                  width: active ? 10 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFE53935) : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

// Studio banners carousel (same as home banners)
class _StudioBannerCarousel extends StatefulWidget {
  const _StudioBannerCarousel();
  @override
  State<_StudioBannerCarousel> createState() => _StudioBannerCarouselState();
}

class _StudioBannerCarouselState extends State<_StudioBannerCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.9);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AdminService.readStudioBannersJson(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(height: 200);
        }
        final raw = snapshot.data!;
        if (raw.isEmpty) {
          // Fallback placeholder when no active banners
          return SizedBox(
            height: 280,
            child: Card(
              elevation: 8,
              shadowColor: const Color(0xFFE53935).withValues(alpha: 0.3),
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.4), width: 2),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.campaign_rounded,
                      size: 48,
                      color: const Color(0xFFE53935).withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No banners yet',
                      style: const TextStyle(
                        color: Color(0xFFF9FAFB), 
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Banners will appear here',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final banners = raw.map((m) => AppBanner.fromMap(m)).where((b) => b.isActive).toList()
          ..sort((a, b) => a.sort.compareTo(b.sort));
        if (banners.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _controller,
                itemCount: banners.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final b = banners[i];
                  final title = b.title;
                  final imageUrl = b.imageUrl;
                  final ctaText = b.ctaText;
                  final ctaLink = b.ctaLink;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Card(
                      elevation: 8,
                      shadowColor: const Color(0xFFE53935).withValues(alpha: 0.3),
                      color: Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.4), width: 2),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: ctaLink == null || ctaLink.isEmpty ? null : () async {
                          try {
                            final uri = Uri.parse(ctaLink);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Cannot open: $ctaLink'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error opening link: $e'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (imageUrl.isNotEmpty && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')))
                                Image.network(
                                  imageUrl, 
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: const Color(0xFF111111),
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
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Color(0xFFF9FAFB), 
                                        fontSize: 24, 
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black,
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    if (ctaText != null && ctaText.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFE53935).withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          ctaText, 
                                          style: const TextStyle(
                                            color: Colors.white, 
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 16,
                                            letterSpacing: 0.5,
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
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(banners.length, (i) {
                final active = i == _index;
                return Container(
                  width: active ? 10 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFE53935) : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

// Role-aware Today section placeholder
class _TodaySection extends StatelessWidget {
  final String role;
  final String? userId;
  const _TodaySection({required this.role, this.userId});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TodayData>(
      future: _loadToday(role: role, userId: userId),
      builder: (context, snap) {
        final data = snap.data;
        final subtitle = () {
          if (snap.connectionState == ConnectionState.waiting) {
            return 'Loading today\'s overview...';
          }
          if (data == null) {
            return role.toLowerCase() == 'admin'
                ? 'Admin summary will appear here'
                : role.toLowerCase() == 'faculty'
                    ? 'Your classes and attendance shortcuts'
                    : 'Your next class will appear here';
          }
          if (role.toLowerCase() == 'admin') {
            final occ = data.occupancy.toStringAsFixed(0);
            final alerts = (data.alerts ?? []).isNotEmpty ? ' • Alerts: ${(data.alerts ?? []).length}' : '';
            return 'Today: ${data.todaysClasses} classes • Occupancy $occ%$alerts';
          } else if (role.toLowerCase() == 'faculty') {
            final first = data.firstClassTime != null ? ' • First: ${data.firstClassTime}' : '';
            final alerts = (data.alerts ?? []).isNotEmpty ? ' • Alerts: ${(data.alerts ?? []).length}' : '';
            return 'Today: ${data.todaysClasses} classes • Pending: ${data.pendingAttendance}$first$alerts';
          } else {
            final n = data.note != null ? ' • ${data.note}' : '';
            return (data.nextClassTitle ?? 'No upcoming class today') + n;
          }
        }();

        return Card(
      elevation: 6,
      shadowColor: const Color(0xFFE53935).withValues(alpha: 0.2),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFFE53935).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  role.toLowerCase() == 'admin' ? Icons.dashboard : role.toLowerCase() == 'faculty' ? Icons.event_available : Icons.schedule,
                  color: const Color(0xFFE53935),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox.shrink(),
                  ],
                ),
              ),
              const SizedBox.shrink(),
            ],
          ),
        ),
      ),
      );
      },
    );
  }
}

class _TodayData {
  final int todaysClasses;
  final double occupancy;
  final int pendingAttendance;
  final String? nextClassTitle;
  final String? firstClassTime; // faculty
  final String? note; // student
  final List<String>? alerts; // admin/faculty
  const _TodayData({
    this.todaysClasses = 0,
    this.occupancy = 0,
    this.pendingAttendance = 0,
    this.nextClassTitle,
    this.firstClassTime,
    this.note,
    this.alerts,
  });
}

Future<_TodayData> _loadToday({required String role, String? userId}) async {
  try {
    if (role.toLowerCase() == 'admin') {
      final count = await AdminService.getTodaysClassesCount();
      final occ = await AdminService.getOccupancyPercentToday();
      // Get real-time alerts from admin service
      final List<String> alerts = await _getAdminAlerts();
      return _TodayData(todaysClasses: count, occupancy: occ, alerts: alerts);
    }
    if (role.toLowerCase() == 'faculty') {
      final count = await AdminService.getTodaysClassesCount(instructorId: userId);
      final pending = userId == null ? 0 : await AdminService.getPendingAttendanceCountForFaculty(userId);
      String? first;
      try {
        final todays = await cls.ClassService.getTodaysClasses(role: 'faculty', userId: userId);
        if (todays.isNotEmpty) {
          first = todays.first.formattedTime;
        }
      } catch (_) {}
      final List<String> alerts = await _getFacultyAlerts(userId);
      return _TodayData(todaysClasses: count, pendingAttendance: pending, firstClassTime: first, alerts: alerts);
    }
    // student
    final next = await cls.ClassService.getNextClass(role: 'student', userId: userId);
    final title = next == null ? null : '${next.name} • ${next.formattedTime}';
    const note = 'Arrive 10 mins early';
    return _TodayData(nextClassTitle: title, note: note);
  } catch (e) {
    return const _TodayData();
  }
}

// Helper function to get admin alerts
Future<List<String>> _getAdminAlerts() async {
  try {
    List<String> alerts = [];
    
    // Check for underbooked classes
    final classesSnapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('isAvailable', isEqualTo: true)
        .get();
    
    for (final doc in classesSnapshot.docs) {
      final data = doc.data();
      final maxStudents = data['maxStudents'] ?? 20;
      final enrolledCount = data['enrolledCount'] ?? 0;
      
      if (enrolledCount < (maxStudents * 0.3)) {
        final className = data['name'] ?? 'Class';
        alerts.add('$className underbooked');
      }
    }
    
    // Check for pending approvals
    final approvalsSnapshot = await FirebaseFirestore.instance
        .collection('approvals')
        .where('status', isEqualTo: 'pending')
        .get();
    
    if (approvalsSnapshot.docs.isNotEmpty) {
      alerts.add('${approvalsSnapshot.docs.length} approvals pending');
    }
    
    return alerts.take(3).toList();
  } catch (e) {
    return [];
  }
}

// Helper function to get faculty alerts
Future<List<String>> _getFacultyAlerts(String? userId) async {
  try {
    if (userId == null) return [];
    
    List<String> alerts = [];
    
    // Check for students with low attendance
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .get();
    
    for (final doc in studentsSnapshot.docs) {
      final data = doc.data();
      final attendance = data['attendancePercent'] ?? 100.0;
      if (attendance < 50) {
        final name = data['name'] ?? 'Student';
        alerts.add('$name • ${attendance.toStringAsFixed(0)}% attendance');
      }
    }
    
    // Check for late marks
    final lateMarksSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('instructorId', isEqualTo: userId)
        .where('status', isEqualTo: 'late')
        .get();
    
    if (lateMarksSnapshot.docs.length >= 2) {
      alerts.add('${lateMarksSnapshot.docs.length} late marks');
    }
    
    return alerts.take(2).toList();
  } catch (e) {
    return [];
  }
}

// Helper function to get revenue MTD
Future<String> _getRevenueMTD() async {
  try {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    final paymentsSnapshot = await FirebaseFirestore.instance
        .collection('payments')
        .where('status', whereIn: ['success', 'paid'])
        .get();
    
    double totalRevenue = 0;
    for (final doc in paymentsSnapshot.docs) {
      final data = doc.data();
      final ts = (data['created_at'] ?? data['createdAt'] ?? data['updated_at']);
      if (ts is Timestamp) {
        final dt = ts.toDate();
        if (!dt.isAfter(startOfMonth)) {
          continue;
        }
      }
      final amount = (data['amount'] ?? 0).toDouble();
      totalRevenue += amount;
    }
    
    return '₹${totalRevenue.toStringAsFixed(0)}';
  } catch (e) {
    return '₹0';
  }
}

// Home Tab
class HomeTab extends StatefulWidget {
  final String? backgroundImageUrl;
  const HomeTab({super.key, this.backgroundImageUrl});

  @override
  State<HomeTab> createState() => _HomeTabState();
}
class _HomeTabState extends State<HomeTab> {
  int _bannerReload = 0;
  final AppConfigService _config = AppConfigService();

  void _refreshBanners() {
    setState(() {
      _bannerReload++;
    });
  }

  Future<void> _refreshHomeData() async {
    // Refresh banners
    _refreshBanners();
    
    // Add a small delay to show refresh indicator
    await Future.delayed(const Duration(milliseconds: 500));
    
    // You can add more refresh logic here like:
    // - Refresh user data
    // - Refresh notifications
    // - Refresh any cached data
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'DanceRang',
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseAuth.instance.currentUser != null
                ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('notifications')
                    .where('read', isEqualTo: false)
                    .snapshots()
                : null,
            builder: (context, snapshot) {
              final unreadCount = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_rounded, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: widget.backgroundImageUrl != null && widget.backgroundImageUrl!.isNotEmpty
            ? BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(widget.backgroundImageUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.6),
                    BlendMode.darken,
                  ),
                ),
              )
            : null,
        child: RefreshIndicator(
          onRefresh: _refreshHomeData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rotating Banner Carousel (Firestore)
              _LiveBannerCarousel(key: ValueKey(_bannerReload)),

              const SizedBox(height: 16),

              

              // Welcome card + Quick Actions (real user data only)
              Builder(builder: (context) {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  if (DemoSession.isActive) {
                    return const _DemoHomeContent();
                  }
                  return const Center(
                    child: Text(
                      'Please login to continue',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  );
                }
                
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _HomeSkeleton();
                    }
                    final userData = snapshot.data?.data();
                    final isDemoUser = user.isAnonymous || userData?['isDemo'] == true;
                    final userName = isDemoUser
                        ? 'Demo'
                        : (userData?['name'] ?? 'DanceRang User');
                    final userRole = isDemoUser
                        ? 'Demo'
                        : (userData?['role'] ?? 'Student');
                    
                    return Column(
                      children: [
                        _WelcomeCard(role: userRole.toLowerCase(), userName: userName),
                        const SizedBox(height: 12),
                        // Add payment status card for students
                        if (userRole.toLowerCase() == 'student') ...[
                          // Student stats cards removed
                        ],
                        // Add teaching status card for faculty
                        if (userRole.toLowerCase() == 'faculty') ...[
                          // Faculty stats cards removed
                        ],
                        // Add admin stats card for admin
                        if (userRole.toLowerCase() == 'admin') ...[
                          _AdminStatsCard(userId: user.uid),
                          const SizedBox(height: 12),
                        ],
                        const _AboutGradientMiniCard(),
                        const SizedBox(height: 16),
                        // Compact Icon Grid for main features
                        if (userRole.toLowerCase() == 'student' || userRole.toLowerCase() == 'faculty' || userRole.toLowerCase() == 'admin') ...[
                          _buildCompactIconGrid(context, userRole.toLowerCase()),
                          const SizedBox(height: 16),
                        ],
                        _MainFeaturesGrid(
                          role: userRole.toLowerCase(),
                          items: _getRoleBasedFeatures(userRole.toLowerCase()),
                        ),
                        const SizedBox(height: 16),
                        _RoleEnhancements(role: userRole.toLowerCase(), userId: user.uid),
                      ],
                    );
                  },
                );
              }),

              const SizedBox(height: 16),

              // Five main dashboard items as larger boxes in a grid
              // _MainFeaturesGrid(
              //   items: const [
              //     _Feature(
              //       title: 'Attendance',
              //       icon: Icons.qr_code_rounded,
              //       accent: Color(0xFF42A5F5), // Blue 400
              //     ),
              //     _Feature(
              //       title: 'Workshops',
              //       icon: Icons.event_rounded,
              //       accent: Color(0xFF66BB6A), // Green 400
              //     ),
              //     _Feature(
              //       title: 'Updates',
              //       icon: Icons.campaign_rounded,
              //       accent: Color(0xFFFFB300), // Amber 400
              //     ),
              //     _Feature(
              //       title: 'Event Choreography',
              //       icon: Icons.celebration_rounded,
              //       accent: Color(0xFFAB47BC), // Purple 400
              //     ),
              //     _Feature(
              //       title: 'Gallery',
              //       icon: Icons.photo_library_rounded,
              //       accent: Color(0xFFEC407A), // Pink 400
              //     ),
              //   ],
              // ),

              const SizedBox(height: 16),

              // Social Feed (images/videos) - place at bottom
              const _HomeFeed(),
            ],
          ),
        ),
        ),
      ),
    );
  }

}

// Dashboard Card Widget
class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String number;
  final String label;

  const _DashboardCard({
    required this.icon,
    required this.number,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1F2937), // Dark charcoal
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 24, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              number,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1B1D22), // Dark charcoal
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF9FAFB), // Light gray
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple banner carousel placeholder
class _BannerCarousel extends StatefulWidget {
  final int maxItems;
  const _BannerCarousel({this.maxItems = 5});
  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.9);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = [
      'Welcome to DanceRang',
      'New Workshops this week',
      'Join our Online Classes',
      'Event Choreo Packages',
      'Explore Gallery',
    ].take(widget.maxItems).toList();
    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Card(
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Banner: ${banners[i]}'), behavior: SnackBarBehavior.floating),
                      );
                    },
                    child: Container(
                      alignment: Alignment.center,
                      child: Text(
                        banners[i],
                        style: const TextStyle(color: Color(0xFFF9FAFB), fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(banners.length, (i) {
            final active = i == _index;
            return Container(
              width: active ? 10 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFE53935) : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// Welcome card widget
class _WelcomeCard extends StatelessWidget {
  final String role;
  final String userName;
  const _WelcomeCard({required this.role, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 8,
      shadowColor: const Color(0xFFE53935).withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFFE53935).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.waving_hand_rounded, 
                      color: Color(0xFFE53935), 
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Welcome!', 
                    style: TextStyle(
                      color: Color(0xFFF9FAFB), 
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_outline, color: Colors.white70, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Color(0xFFF9FAFB), 
                      fontSize: 14, 
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE53935).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      role.toUpperCase(), 
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 11, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      role == 'admin'
                          ? 'Manage your dance studio'
                          : role == 'faculty'
                              ? 'Teach and inspire students'
                              : 'Learn and grow with us',
                      style: const TextStyle(
                        color: Colors.white70, 
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoHomeContent extends StatelessWidget {
  const _DemoHomeContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _WelcomeCard(role: 'demo', userName: 'Demo'),
        const SizedBox(height: 12),
      ],
    );
  }
}

// Simple social feed list
class _HomeFeed extends StatelessWidget {
  const _HomeFeed();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('feed')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white70));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Feed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            ...docs.map((d) => _FeedCard(data: d.data())).toList(),
          ],
        );
      },
    );
  }
}

class _FeedCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _FeedCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final type = (data['type'] as String?) ?? 'image';
    final url = (data['url'] as String?) ?? '';
    final caption = (data['caption'] as String?) ?? '';
    final isImage = type == 'image';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: isImage
                ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.network(url, fit: BoxFit.cover),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.black26),
                      const Center(child: Icon(Icons.play_circle_fill, size: 56, color: Colors.white70)),
                    ],
                  ),
          ),
          // Description/Caption below photo
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              caption.isNotEmpty ? caption : 'No description',
              style: TextStyle(
                color: caption.isNotEmpty ? Colors.white : Colors.white54,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Main feature card with two actions (primary/secondary)
class _MainFeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTapPrimary;
  final String primaryLabel;
  final VoidCallback onTapSecondary;
  final String secondaryLabel;

  const _MainFeatureCard({
    required this.title,
    required this.icon,
    required this.onTapPrimary,
    required this.primaryLabel,
    required this.onTapSecondary,
    required this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1B1D22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFE53935)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: Color(0xFFF9FAFB), fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onTapPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(primaryLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onTapSecondary,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE53935),
                      side: const BorderSide(color: Color(0xFFE53935)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(secondaryLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Grid wrapper for the five main features
class _MainFeaturesGrid extends StatelessWidget {
  final List<_Feature> items;
  final String? role;
  const _MainFeaturesGrid({required this.items, this.role});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final f = items[index];
        return _MainFeatureBox(
          title: f.title, 
          icon: f.icon, 
          accent: f.accent,
          role: role,
        );
      },
    );
  }
}

class _Feature {
  final String title;
  final IconData icon;
  final Color accent;
  const _Feature({
    required this.title,
    required this.icon,
    this.accent = const Color(0xFFE53935),
  });
}
// Function to get role-based features
List<_Feature> _getRoleBasedFeatures(String role) {
  switch (role) {
    case 'student':
      return const [
        _Feature(
          title: 'Workshops',
          icon: Icons.event_rounded,
          accent: Color(0xFF66BB6A),
        ),
        _Feature(
          title: 'Updates',
          icon: Icons.campaign_rounded,
          accent: Color(0xFFFFB300),
        ),
        _Feature(
          title: 'Event Choreography',
          icon: Icons.celebration_rounded,
          accent: Color(0xFFAB47BC),
        ),
        _Feature(
          title: 'Gallery',
          icon: Icons.photo_library_rounded,
          accent: Color(0xFFEC407A),
        ),
      ];
    case 'faculty':
      return const [
        _Feature(
          title: 'Workshops',
          icon: Icons.event_rounded,
          accent: Color(0xFF66BB6A),
        ),
        _Feature(
          title: 'Updates',
          icon: Icons.campaign_rounded,
          accent: Color(0xFFFFB300),
        ),
        _Feature(
          title: 'Event Choreography',
          icon: Icons.celebration_rounded,
          accent: Color(0xFFAB47BC),
        ),
        _Feature(
          title: 'Gallery',
          icon: Icons.photo_library_rounded,
          accent: Color(0xFFEC407A),
        ),
      ];
    case 'admin':
      return const [
        _Feature(
          title: 'Workshops',
          icon: Icons.event_rounded,
          accent: Color(0xFF66BB6A),
        ),
        _Feature(
          title: 'Updates',
          icon: Icons.campaign_rounded,
          accent: Color(0xFFFFB300),
        ),
        _Feature(
          title: 'Event Choreography',
          icon: Icons.celebration_rounded,
          accent: Color(0xFFAB47BC),
        ),
        _Feature(
          title: 'Gallery',
          icon: Icons.photo_library_rounded,
          accent: Color(0xFFEC407A),
        ),
      ];
    default:
      return const [
        _Feature(
          title: 'Attendance',
          icon: Icons.qr_code_rounded,
          accent: Color(0xFF42A5F5),
        ),
        _Feature(
          title: 'Workshops',
          icon: Icons.event_rounded,
          accent: Color(0xFF66BB6A),
        ),
        _Feature(
          title: 'Updates',
          icon: Icons.campaign_rounded,
          accent: Color(0xFFFFB300),
        ),
        _Feature(
          title: 'Event Choreography',
          icon: Icons.celebration_rounded,
          accent: Color(0xFFAB47BC),
        ),
        _Feature(
          title: 'Gallery',
          icon: Icons.photo_library_rounded,
          accent: Color(0xFFEC407A),
        ),
      ];
  }
}

// Larger box-style feature tile
class _MainFeatureBox extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final String? role;

  const _MainFeatureBox({
    required this.title,
    required this.icon,
    required this.accent,
    this.role,
  });

  void _handleFeatureTap(BuildContext context) {
    // Role-based feature handling (works for both real users and demo mode)
    switch (title) {
      case 'Live Dashboard':
        _showLiveDashboard(context);
        break;
      case 'Attendance':
        if (role?.toLowerCase() == 'admin') {
          _showAdminAttendance(context);
        } else if (role?.toLowerCase() == 'faculty') {
          _showFacultyAttendance(context);
        } else {
          _showStudentAttendance(context);
        }
        break;
      case 'Students':
        _showStudentManagement(context);
        break;
      case 'Workshops':
        if (role?.toLowerCase() == 'admin') {
          _showAdminWorkshops(context);
        } else if (role?.toLowerCase() == 'faculty') {
          _showFacultyWorkshops(context);
        } else {
          _showStudentWorkshops(context);
        }
        break;
      case 'Updates':
        _showUpdates(context);
        break;
      case 'Event Choreography':
        _showEventChoreography(context);
        break;
      case 'Gallery':
        _showGallery(context);
        break;
      case 'Payment Reminders':
        _showPaymentReminders(context);
        break;
      default:
        _showComingSoon(context, title);
    }
  }

  void _showLiveDashboard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminLiveDashboard(),
      ),
    );
  }

  void _showAdminAttendance(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceScreen(role: 'admin'),
      ),
    );
  }

  void _showFacultyAttendance(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceScreen(role: 'faculty'),
      ),
    );
  }

  void _showStudentAttendance(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceScreen(role: 'student'),
      ),
    );
  }

  void _showStudentProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StudentProfileScreen(),
      ),
    );
  }

  void _showAdminWorkshops(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyWorkshopsScreen(role: 'admin'),
      ),
    );
  }

  void _showFacultyWorkshops(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyWorkshopsScreen(role: 'faculty'),
      ),
    );
  }

  void _showStudentWorkshops(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyWorkshopsScreen(role: 'student'),
      ),
    );
  }

  void _showMyClasses(BuildContext context) {
    // MyClassesScreen deleted - functionality removed
  }


  void _showStudentManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StudentManagementScreen(),
      ),
    );
  }

  void _showUpdates(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdatesScreen(role: 'all'),
      ),
    );
  }

  void _showEventChoreography(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventChoreographyScreen(role: 'all'),
      ),
    );
  }

  void _showGallery(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GalleryScreen(role: 'all'),
      ),
    );
  }

  void _showPaymentReminders(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PaymentReminderScreen(),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 4,
      shadowColor: accent.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleFeatureTap(context),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFF9FAFB),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios, size: 14, color: accent.withValues(alpha: 0.9)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
