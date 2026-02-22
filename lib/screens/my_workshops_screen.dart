import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/payment_service.dart';
import '../widgets/payment_option_dialog.dart';
import '../utils/error_handler.dart';
import 'add_edit_workshop_screen.dart';
import 'workshop_qr_display_screen.dart';
import 'qr_scanner_screen.dart';

class MyWorkshopsScreen extends StatefulWidget {
  final String role; // 'student' | 'faculty' | 'admin'
  const MyWorkshopsScreen({super.key, required this.role});

  @override
  State<MyWorkshopsScreen> createState() => _MyWorkshopsScreenState();
}

class _MyWorkshopsScreenState extends State<MyWorkshopsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      // Remove currency symbols, commas, spaces and non-digits
      final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleaned.isEmpty) return 0;
      return int.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  bool _isAdminOrFaculty() {
    final role = widget.role.toLowerCase();
    return role == 'admin' || role == 'faculty';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _getTabCount(), vsync: this);
    // switched to stream-based loading
    _isLoading = false;
    
    // Listen to payment success events for real-time workshop updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (event['type'] == 'payment_success' && 
          (event['paymentType'] == 'workshop' || event['paymentType'] == 'event_choreography') && mounted) {
        // Force rebuild when workshop payment succeeds
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _paymentRefreshSubscription?.cancel();
    super.dispose();
  }

  int _getTabCount() {
    switch (widget.role) {
      case 'admin':
        return 3; // Upcoming, Enrolled, Manage
      case 'faculty':
      case 'student':
        return 2; // Upcoming, My Workshops
      default:
        return 2;
    }
  }

  List<String> _getTabTitles() {
    switch (widget.role) {
      case 'admin':
        return ['Upcoming', 'Enrolled', 'Manage'];
      case 'faculty':
      case 'student':
        return ['Upcoming', 'My Workshops'];
      default:
        return ['Upcoming', 'Enrolled'];
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: _getAppBarTitle(),
        actions: [
          if (widget.role == 'admin')
            IconButton(
              onPressed: _addWorkshop,
              icon: const Icon(Icons.add, color: Colors.white70),
            ),
          if (_isAdminOrFaculty())
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QRScannerScreen(workshopMode: true),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white70),
              tooltip: 'Workshop Scanner',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white70,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _getTabTitles().map((title) => Tab(text: title)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            )
          : TabBarView(
              controller: _tabController,
              children: _buildTabViews(),
            ),
    );
  }

  String _getAppBarTitle() {
    switch (widget.role) {
      case 'admin':
        return 'Workshop Management';
      case 'faculty':
        return 'Workshops';
      case 'student':
        return 'My Workshops';
      default:
        return 'Workshops';
    }
  }

  List<Widget> _buildTabViews() {
    switch (widget.role) {
      case 'admin':
        return [
          _buildUpcomingWorkshops(),
          _buildEnrolledWorkshops(),
          _buildManageWorkshops(),
        ];
      case 'faculty':
      case 'student':
        return [
          _buildUpcomingWorkshops(),
          _buildEnrolledWorkshops(),
        ];
      default:
        return [
          _buildUpcomingWorkshops(),
          _buildEnrolledWorkshops(),
        ];
    }
  }

  Widget _buildUpcomingWorkshops() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('workshops')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFE53935),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error Loading Workshops',
            subtitle: 'Failed to load workshops',
          );
        }

        List<QueryDocumentSnapshot<Map<String, dynamic>>> workshops = snapshot.data?.docs ?? [];
        // Client-side sort by createdAt desc to avoid composite index issues when field is missing
        workshops.sort((a, b) {
          final ta = (a.data()['createdAt'] as Timestamp?);
          final tb = (b.data()['createdAt'] as Timestamp?);
          final da = ta?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = tb?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
        if (workshops.isEmpty) {
          return _buildEmptyState(
            icon: Icons.event_outlined,
            title: 'No Workshops Available',
            subtitle: 'No workshops are currently available',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: workshops.length,
          itemBuilder: (context, index) {
            final doc = workshops[index];
            final data = doc.data();
            final workshop = WorkshopData(
              id: doc.id,
              title: data['title'] ?? 'Unknown Workshop',
              instructor: data['instructor'] ?? 'Unknown Instructor',
              date: data['date'] ?? 'TBA',
              time: data['time'] ?? 'TBA',
              price: _toInt(data['price']),
              imageUrl: data['imageUrl'] ?? '',
              description: data['description'] ?? '',
              maxParticipants: _toInt(data['maxParticipants']),
              currentParticipants: _toInt(data['currentParticipants'] ?? 0) > 0 
                  ? _toInt(data['currentParticipants'])
                  : _toInt(data['enrolledCount'] ?? data['participant_count'] ?? 0),
              isEnrolled: false, // Will be updated by StreamBuilder
              category: data['category'] ?? 'General',
              level: data['level'] ?? 'All Levels',
              location: data['location'] ?? 'TBA',
              duration: data['duration'] ?? 'TBA',
            );
            return _buildWorkshopCardWithEnrollmentCheck(workshop, isUpcoming: true);
          },
        );
      },
    );
  }

  Widget _buildEnrolledWorkshops() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _buildEmptyState(
        icon: Icons.person_off,
        title: 'Not Logged In',
        subtitle: 'Please log in to view your enrolled workshops',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('enrollments')
          .where('itemType', whereIn: ['workshop'])
          .where('status', isEqualTo: 'enrolled')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFE53935),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error Loading Workshops',
            subtitle: 'Failed to load your enrolled workshops: ${snapshot.error}',
          );
        }

        final enrolments = snapshot.data?.docs ?? [];
        
        if (enrolments.isEmpty) {
          return _buildEmptyState(
            icon: Icons.event_outlined,
            title: 'No Workshops Found',
            subtitle: 'You haven\'t enrolled in any workshops yet',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: enrolments.length,
          itemBuilder: (context, index) {
            final enrolment = enrolments[index].data();
            final workshopId = enrolment['itemId'] as String?;
            
            if (workshopId == null) return const SizedBox.shrink();
            
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('workshops')
                  .doc(workshopId)
                  .snapshots(),
              builder: (context, workshopSnapshot) {
                if (!workshopSnapshot.hasData || !workshopSnapshot.data!.exists) {
                  return const SizedBox.shrink();
                }
                
                final workshopData = workshopSnapshot.data!.data()!;
                final enrolledWorkshopData = WorkshopData(
                  id: workshopId,
                  title: workshopData['title'] ?? 'Unknown Workshop',
                  instructor: workshopData['instructor'] ?? 'Unknown Instructor',
                  date: workshopData['date'] ?? 'TBA',
                  time: workshopData['time'] ?? 'TBA',
                  price: _toInt(workshopData['price']),
                  imageUrl: workshopData['imageUrl'] ?? '',
                  description: workshopData['description'] ?? '',
                  maxParticipants: _toInt(workshopData['maxParticipants']),
                  currentParticipants: _toInt(workshopData['currentParticipants'] ?? 0) > 0 
                      ? _toInt(workshopData['currentParticipants'])
                      : _toInt(workshopData['enrolledCount'] ?? 0),
                  isEnrolled: true,
                  category: workshopData['category'] ?? 'General',
                  level: workshopData['level'] ?? 'All Levels',
                  location: workshopData['location'] ?? 'TBA',
                  duration: workshopData['duration'] ?? 'TBA',
                  paymentStatus: 'Paid',
                );
                
                return _buildWorkshopCardWithEnrollmentCheck(enrolledWorkshopData, isUpcoming: false);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildManageWorkshops() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('workshops')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFE53935),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error Loading Workshops',
            subtitle: 'Failed to load workshops',
          );
        }

        final workshops = snapshot.data?.docs ?? [];
        if (workshops.isEmpty) {
          return _buildEmptyState(
            icon: Icons.event_outlined,
            title: 'No Workshops Found',
            subtitle: 'No workshops are currently available',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: workshops.length,
          itemBuilder: (context, index) {
            final doc = workshops[index];
            final data = doc.data();
            final workshop = WorkshopData(
              id: doc.id,
              title: data['title'] ?? 'Unknown Workshop',
              instructor: data['instructor'] ?? 'Unknown Instructor',
              date: data['date'] ?? 'TBA',
              time: data['time'] ?? 'TBA',
              price: _toInt(data['price']),
              imageUrl: data['imageUrl'] ?? '',
              description: data['description'] ?? '',
              maxParticipants: _toInt(data['maxParticipants']),
              currentParticipants: _toInt(data['currentParticipants'] ?? 0) > 0 
                  ? _toInt(data['currentParticipants'])
                  : _toInt(data['enrolledCount'] ?? data['participant_count'] ?? 0),
              isEnrolled: false,
              category: data['category'] ?? 'General',
              level: data['level'] ?? 'All Levels',
              location: data['location'] ?? 'TBA',
              duration: data['duration'] ?? 'TBA',
            );
            return _buildAdminWorkshopCard(workshop);
          },
        );
      },
    );
  }

  Widget _buildWorkshopCardWithEnrollmentCheck(WorkshopData workshop, {required bool isUpcoming}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _buildWorkshopCard(workshop, isUpcoming: isUpcoming);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('enrollments')
          .doc(workshop.id)
          .snapshots(),
      builder: (context, enrollmentSnapshot) {
        final enrollmentData = enrollmentSnapshot.data?.data();
        final isEnrolled = enrollmentSnapshot.data?.exists == true && 
                          (enrollmentData?['status'] == 'enrolled');
        final isCompleted = enrollmentData?['workshopCompleted'] == true;
        final completedSessions = enrollmentData?['completedSessions'] ?? 0;
        
        // Also get real-time workshop data for participant count
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('workshops')
              .doc(workshop.id)
              .snapshots(),
          builder: (context, workshopSnapshot) {
            final workshopData = workshopSnapshot.data?.data() ?? {};
            final currentParticipants = _toInt(workshopData['currentParticipants'] ?? 0) > 0 
                ? _toInt(workshopData['currentParticipants'])
                : _toInt(workshopData['enrolledCount'] ?? 
                         workshopData['participant_count'] ?? 
                         workshop.currentParticipants);
            
            final updatedWorkshop = WorkshopData(
              id: workshop.id,
              title: workshop.title,
              instructor: workshop.instructor,
              date: workshop.date,
              time: workshop.time,
              price: workshop.price,
              imageUrl: workshop.imageUrl,
              description: workshop.description,
              maxParticipants: workshop.maxParticipants,
              currentParticipants: currentParticipants,
              isEnrolled: isEnrolled,
              category: workshop.category,
              level: workshop.level,
              location: workshop.location,
              duration: workshop.duration,
              paymentStatus: workshop.paymentStatus,
            );
            return _buildWorkshopCard(updatedWorkshop, isUpcoming: isUpcoming, isCompleted: isCompleted, completedSessions: completedSessions);
          },
        );
      },
    );
  }

  Widget _buildWorkshopCard(WorkshopData workshop, {required bool isUpcoming, bool isCompleted = false, int completedSessions = 0}) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: workshop.isEnrolled
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Workshop Image
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                color: const Color(0xFF111111),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Background image or placeholder
                    workshop.imageUrl.isNotEmpty
                        ? Image.network(
                            workshop.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.event,
                                  color: Color(0xFFE53935),
                                  size: 60,
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Icon(
                              Icons.event,
                              color: Color(0xFFE53935),
                              size: 60,
                            ),
                          ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                    // Category badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(workshop.category).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          workshop.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Level badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          workshop.level,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Enrolled badge
                    if (workshop.isEnrolled)
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'ENROLLED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Workshop Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workshop.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        workshop.instructor,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        workshop.date,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        workshop.time,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        workshop.location,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (workshop.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      workshop.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '₹${workshop.price}',
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${workshop.currentParticipants}/${workshop.maxParticipants} participants',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: TextButton(
                            onPressed: () => _viewDetails(workshop),
                            child: const Text(
                              'View Details',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isUpcoming && !workshop.isEnrolled) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE53935).withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextButton(
                              onPressed: () => _joinWorkshop(workshop),
                              child: const Text(
                                'Join Now',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (!isUpcoming && workshop.isEnrolled) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isCompleted 
                                    ? [const Color(0xFF059669), const Color(0xFF047857)]
                                    : [const Color(0xFF10B981), const Color(0xFF059669)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: (isCompleted ? const Color(0xFF059669) : const Color(0xFF10B981)).withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextButton.icon(
                              onPressed: isCompleted ? null : () => _showWorkshopQRCode(workshop),
                              icon: Icon(
                                isCompleted ? Icons.check_circle : Icons.qr_code, 
                                size: 16
                              ),
                              label: Text(
                                isCompleted ? 'Joined' : 'My QR Code',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminWorkshopCard(WorkshopData workshop) {
    return Card(
      elevation: 4,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workshop.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by ${workshop.instructor}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editWorkshop(workshop);
                        break;
                      case 'delete':
                        _deleteWorkshop(workshop);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  workshop.date,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  workshop.time,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.people, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${workshop.currentParticipants}/${workshop.maxParticipants} participants',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '₹${workshop.price}',
                  style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'hip hop':
        return const Color(0xFFE53935);
      case 'bollywood':
        return const Color(0xFFFF9800);
      case 'contemporary':
        return const Color(0xFF2196F3);
      case 'salsa':
        return const Color(0xFF4CAF50);
      case 'classical':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF607D8B);
    }
  }

  void _viewDetails(WorkshopData workshop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WorkshopDetailsModal(
        workshop: workshop,
        isAdminOrFaculty: _isAdminOrFaculty(),
      ),
    );
  }

  void _joinWorkshop(WorkshopData workshop) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to join workshop'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Parse amount from price
      final String raw = workshop.price.toString().replaceAll('₹', '').replaceAll(',', '').trim();
      final int rupees = int.tryParse(raw) ?? 0;

      if (rupees <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid workshop price'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final choice = await PaymentOptionDialog.show(context);
      if (choice == PaymentChoice.cash) {
        final paymentId = PaymentService.generatePaymentId();
        final res = await PaymentService.requestCashPayment(
          paymentId: paymentId,
          amount: rupees,
          description: 'Workshop: ${workshop.title}',
          paymentType: 'workshop',
          itemId: workshop.id,
          metadata: {
            'workshop_name': workshop.title,
            'instructor': workshop.instructor,
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
          amount: rupees,
          description: 'Workshop: ${workshop.title}',
          paymentType: 'workshop',
          itemId: workshop.id,
          metadata: {
            'workshop_name': workshop.title,
            'instructor': workshop.instructor,
          },
        );

        if (result['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Redirecting to payment...'),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed to start: ${result['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'starting workshop payment');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showWorkshopQRCode(WorkshopData workshop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkshopQRDisplayScreen(workshopId: workshop.id),
      ),
    );
  }

  void _addWorkshop() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditWorkshopScreen(),
      ),
    );
  }

  void _editWorkshop(WorkshopData workshop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditWorkshopScreen(
          workshop: AddEditWorkshopData(
            id: workshop.id,
            title: workshop.title,
            instructor: workshop.instructor,
            date: workshop.date,
            time: workshop.time,
            price: workshop.price,
            description: workshop.description,
            category: workshop.category,
            level: workshop.level,
            location: workshop.location,
            duration: workshop.duration,
            maxParticipants: workshop.maxParticipants,
            currentParticipants: workshop.currentParticipants,
            imageUrl: workshop.imageUrl,
            isEnrolled: workshop.isEnrolled,
            paymentStatus: 'paid', // Default value
          ),
        ),
      ),
    );
  }

  void _deleteWorkshop(WorkshopData workshop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text(
          'Delete Workshop',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${workshop.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('workshops')
            .doc(workshop.id)
            .delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Workshop deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e, stackTrace) {
        ErrorHandler.handleError(e, stackTrace, context: 'deleting workshop');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting workshop: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _WorkshopDetailsModal extends StatelessWidget {
  final WorkshopData workshop;
  final bool isAdminOrFaculty;

  const _WorkshopDetailsModal({required this.workshop, required this.isAdminOrFaculty});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    workshop.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
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
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Workshop Image
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF111111),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: workshop.imageUrl.isNotEmpty
                          ? Image.network(
                              workshop.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.event,
                                    color: Color(0xFFE53935),
                                    size: 60,
                                  ),
                                );
                              },
                            )
                          : const Center(
                              child: Icon(
                                Icons.event,
                                color: Color(0xFFE53935),
                                size: 60,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Workshop Title
                  Text(
                    workshop.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Instructor
                  Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFFE53935), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        workshop.instructor,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Details
                  _buildDetailRow('Date', workshop.date),
                  _buildDetailRow('Time', workshop.time),
                  _buildDetailRow('Location', workshop.location),
                  _buildDetailRow('Duration', workshop.duration),
                  _buildDetailRow('Level', workshop.level),
                  _buildDetailRow('Category', workshop.category),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  if (workshop.description.isNotEmpty) ...[
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      workshop.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Price
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE53935).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.currency_rupee,
                          color: Color(0xFFE53935),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${workshop.price}',
                          style: const TextStyle(
                            color: Color(0xFFE53935),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${workshop.currentParticipants}/${workshop.maxParticipants} participants',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  if (isAdminOrFaculty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showEnrolledList(context),
                        icon: const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 18),
                        label: const Text(
                          'View Enrolled',
                          style: TextStyle(color: Colors.white70),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEnrolledList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Enrolled Students',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('enrollments')
                      .where('itemType', isEqualTo: 'workshop')
                      .where('itemId', isEqualTo: workshop.id)
                      .where('status', whereIn: ['enrolled', 'completed'])
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading enrolments: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    }
                    final enrolDocs = snapshot.data?.docs ?? [];
                    if (enrolDocs.isEmpty) {
                      return const Center(
                        child: Text('No students enrolled yet', style: TextStyle(color: Colors.white70)),
                      );
                    }
                    return ListView.separated(
                      itemCount: enrolDocs.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                      itemBuilder: (context, index) {
                        final enrol = enrolDocs[index].data();
                        final userId = enrol['userId'] as String?;
                        final completed = enrol['completedSessions'] ?? 0;
                        final total = enrol['totalSessions'] ?? 1;
                        final isAttended = enrol['status'] == 'completed';
                        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: userId == null
                              ? null
                              : FirebaseFirestore.instance.collection('users').doc(userId).get(),
                          builder: (context, userSnap) {
                            final name = userSnap.data?.data()?['name'] ?? userSnap.data?.data()?['displayName'] ?? 'Student';
                            final phone = userSnap.data?.data()?['phone'] ?? '';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isAttended
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : const Color(0xFFE53935).withValues(alpha: 0.15),
                                child: Icon(
                                  isAttended ? Icons.check_circle : Icons.person,
                                  color: isAttended ? Colors.green : const Color(0xFFE53935),
                                ),
                              ),
                              title: Text(name, style: const TextStyle(color: Colors.white)),
                              subtitle: Text(
                                phone.isNotEmpty ? '+91 $phone' : 'Progress: $completed/$total',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isAttended ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isAttended ? 'Attended' : 'Enrolled',
                                  style: TextStyle(
                                    color: isAttended ? Colors.green : Colors.orange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('enrollments')
                          .where('itemType', isEqualTo: 'workshop')
                          .where('itemId', isEqualTo: workshop.id)
                          .where('status', whereIn: ['enrolled', 'completed'])
                          .snapshots(),
                      builder: (context, s) {
                        final docs = s.data?.docs ?? [];
                        final totalCount = docs.length;
                        final attendedCount = docs.where((d) => d.data()['status'] == 'completed').length;
                        return Text(
                          'Total enrolled: $totalCount  |  Attended: $attendedCount',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        );
                      },
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

class WorkshopData {
  final String id;
  final String title;
  final String instructor;
  final String date;
  final String time;
  final int price;
  final String imageUrl;
  final String description;
  final int maxParticipants;
  final int currentParticipants;
  final bool isEnrolled;
  final String category;
  final String level;
  final String location;
  final String duration;
  final String? paymentStatus;

  WorkshopData({
    required this.id,
    required this.title,
    required this.instructor,
    required this.date,
    required this.time,
    required this.price,
    required this.imageUrl,
    required this.description,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.isEnrolled,
    required this.category,
    required this.level,
    required this.location,
    required this.duration,
    this.paymentStatus,
  });
}