import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';

class AdminStudentAnalyticsScreen extends StatefulWidget {
  const AdminStudentAnalyticsScreen({super.key});

  @override
  State<AdminStudentAnalyticsScreen> createState() => _AdminStudentAnalyticsScreenState();
}

class _AdminStudentAnalyticsScreenState extends State<AdminStudentAnalyticsScreen> {
  String _selectedTab = 'overview';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'Student Analytics',
        onLeadingPressed: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _buildTab('overview', 'Overview', Icons.dashboard),
          _buildTab('classes', 'Dance Classes', Icons.school),
          _buildTab('workshops', 'Workshops', Icons.event),
          _buildTab('studio', 'Studio Bookings', Icons.business),
          _buildTab('events', 'Event Choreography', Icons.celebration),
        ],
      ),
    );
  }

  Widget _buildTab(String tabId, String title, IconData icon) {
    final isSelected = _selectedTab == tabId;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = tabId),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE53935).withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFFE53935) : Colors.white70,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFE53935) : Colors.white70,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'overview':
        return _buildOverviewTab();
      case 'classes':
        return _buildDanceClassesTab();
      case 'workshops':
        return _buildWorkshopsTab();
      case 'studio':
        return _buildStudioBookingsTab();
      case 'events':
        return _buildEventChoreographyTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRevenueCard(),
          const SizedBox(height: 16),
          _buildQuickStatsCard(),
          const SizedBox(height: 16),
          _buildRecentActivityCard(),
        ],
      ),
    );
  }

  Widget _buildRevenueCard() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.currency_rupee, color: const Color(0xFF4CAF50), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Revenue Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              // Listen to all payments; filtering/tolerance handled in code to avoid index mismatches
              stream: _firestore.collection('payments').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final payments = snapshot.data!.docs;
                double totalRevenue = 0;
                double danceClassRevenue = 0;
                double workshopRevenue = 0;
                double studioRevenue = 0;
                double eventRevenue = 0;

                for (final doc in payments) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? data['payment_status'] ?? '').toString().toLowerCase();
                  // Accept both 'paid' and 'success'
                  final isPaid = status == 'paid' || status == 'success';
                  if (!isPaid) continue;

                  final rawAmount = data['amount'] ?? data['amount_paise'];
                  // If amount_paise present, convert to INR
                  final double amount = rawAmount is int
                      ? (data.containsKey('amount_paise') ? rawAmount / 100.0 : rawAmount.toDouble())
                      : (rawAmount is double ? rawAmount : 0.0);

                  totalRevenue += amount;

                  // Tolerant payment type resolution
                  final String type = (() {
                    final t1 = data['payment_type']?.toString().toLowerCase();
                    final t2 = data['paymentType']?.toString().toLowerCase();
                    final itemType = data['itemType']?.toString().toLowerCase();
                    final inferred = data['workshopId'] != null
                        ? 'workshop'
                        : (data['classId'] != null
                            ? 'class'
                            : (data['studioBookingId'] != null
                                ? 'studio'
                                : (data['bookingId'] != null ? 'event' : null)));
                    return (t1 ?? t2 ?? itemType ?? inferred ?? 'unknown');
                  })();

                  switch (type) {
                    case 'class':
                      danceClassRevenue += amount;
                      break;
                    case 'workshop':
                      workshopRevenue += amount;
                      break;
                    case 'studio':
                    case 'studio_booking':
                      studioRevenue += amount;
                      break;
                    case 'event':
                    case 'event_choreo':
                      eventRevenue += amount;
                      break;
                    default:
                      // Unknown types contribute to total only
                      break;
                  }
                }

                return Column(
                  children: [
                    _buildRevenueItem('Total Revenue', totalRevenue, const Color(0xFF4CAF50)),
                    const SizedBox(height: 12),
                    _buildRevenueItem('Dance Classes', danceClassRevenue, const Color(0xFFFFC107)),
                    const SizedBox(height: 12),
                    _buildRevenueItem('Workshops', workshopRevenue, const Color(0xFFE53935)),
                    const SizedBox(height: 12),
                    _buildRevenueItem('Studio Bookings', studioRevenue, const Color(0xFF2196F3)),
                    const SizedBox(height: 12),
                    _buildRevenueItem('Event Choreography', eventRevenue, const Color(0xFF9C27B0)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueItem(String title, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatsCard() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: const Color(0xFF2196F3), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Quick Stats',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Students - Fixed to use proper enrolments collection with real-time data
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Total Students', 'Error', const Color(0xFF4CAF50)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Active Students', 'Error', const Color(0xFF4CAF50)),
                      ),
                    ],
                  );
                }

                if (!snapshot.hasData) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Total Students', 'Loading...', const Color(0xFF4CAF50)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Active Students', 'Loading...', const Color(0xFF4CAF50)),
                      ),
                    ],
                  );
                }

                final users = snapshot.data!.docs;
                final totalStudents = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final role = (data['role'] ?? '').toString().toLowerCase();
                  return role == 'student';
                }).length;
                final activeStudents = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final role = (data['role'] ?? '').toString().toLowerCase();
                  return role == 'student' && (data['isActive'] == true);
                }).length;

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatItem('Total Students', totalStudents.toString(), const Color(0xFF4CAF50)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatItem('Active Students', activeStudents.toString(), const Color(0xFF4CAF50)),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            // Workshops and Studio Bookings
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('workshops').snapshots(),
                    builder: (context, wsnap) {
                      final count = wsnap.hasData ? wsnap.data!.docs.length : 0;
                      return _buildStatItem('Total Workshops', count.toString(), const Color(0xFFE53935));
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('studioBookings').snapshots(),
                    builder: (context, bsnap) {
                      final count = bsnap.hasData ? bsnap.data!.docs.length : 0;
                      return _buildStatItem('Studio Bookings', count.toString(), const Color(0xFF2196F3));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
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
            title,
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

  Widget _buildRecentActivityCard() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: const Color(0xFFFF9800), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'No recent activity',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDanceClassesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildDanceClassesStats(),
          const SizedBox(height: 16),
          _buildDanceClassesList(),
        ],
      ),
    );
  }

  Widget _buildDanceClassesStats() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFFFC107).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: const Color(0xFFFFC107), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Dance Classes Statistics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Dance Class Students', 'Error', const Color(0xFFFFC107)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Active', 'Error', const Color(0xFF4CAF50)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Inactive', 'Error', const Color(0xFFF44336)),
                      ),
                    ],
                  );
                }

                if (!snapshot.hasData) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Dance Class Students', 'Loading...', const Color(0xFFFFC107)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Active', 'Loading...', const Color(0xFF4CAF50)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Inactive', 'Loading...', const Color(0xFFF44336)),
                      ),
                    ],
                  );
                }

                final users = snapshot.data!.docs;
                final totalStudents = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final role = (data['role'] ?? '').toString().toLowerCase();
                  return role == 'student';
                }).length;
                
                final activeStudents = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final role = (data['role'] ?? '').toString().toLowerCase();
                  return role == 'student' && (data['isActive'] == true);
                }).length;
                
                final inactiveStudents = totalStudents - activeStudents;

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatItem('Dance Class Students', totalStudents.toString(), const Color(0xFFFFC107)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatItem('Active', activeStudents.toString(), const Color(0xFF4CAF50)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatItem('Inactive', inactiveStudents.toString(), const Color(0xFFF44336)),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDanceClassesList() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFFFC107).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: const Color(0xFFFFC107), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Dance Classes Students',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading students: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs;
                final students = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final role = (data['role'] ?? '').toString().toLowerCase();
                  return role == 'student';
                }).toList();

                if (students.isEmpty) {
                  return const Center(
                    child: Text(
                      'No students found',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final data = student.data() as Map<String, dynamic>;
                    data['id'] = student.id;
                    data['userName'] = data['name'] ?? data['displayName'] ?? 'Unknown User';
                    data['userEmail'] = data['email'] ?? '';
                    data['status'] = data['isActive'] == true ? 'active' : 'inactive';
                    data['className'] = 'Dance Class'; // Default class name
                    data['packageName'] = 'General Package'; // Default package name
                    data['completedSessions'] = 0;
                    data['totalSessions'] = 0;
                    data['paymentStatus'] = 'pending';
                    
                    return _buildStudentCard(data, 'class');
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkshopsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildWorkshopsStats(),
          const SizedBox(height: 16),
          _buildWorkshopsList(),
        ],
      ),
    );
  }

  Widget _buildWorkshopsStats() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, color: const Color(0xFFE53935), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Workshops Statistics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('workshops').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Total Workshops', 'Error', const Color(0xFFE53935)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Total Participants', 'Error', const Color(0xFF4CAF50)),
                      ),
                    ],
                  );
                }

                if (!snapshot.hasData) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Total Workshops', 'Loading...', const Color(0xFFE53935)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Total Participants', 'Loading...', const Color(0xFF4CAF50)),
                      ),
                    ],
                  );
                }

                final workshops = snapshot.data!.docs;
                final totalParticipants = workshops.fold<int>(0, (sum, doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return sum + ((data['enrolledCount'] ?? data['currentParticipants'] ?? 0) as int);
                });

                final activeWorkshops = workshops.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['isActive'] ?? data['isAvailable'] ?? true) == true;
                }).length;

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatItem('Total Workshops', workshops.length.toString(), const Color(0xFFE53935)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatItem('Active Workshops', activeWorkshops.toString(), const Color(0xFF4CAF50)),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('enrollments').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Total Participants', 'Error', const Color(0xFF4CAF50)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Active Participants', 'Error', const Color(0xFF10B981)),
                      ),
                    ],
                  );
                }

                if (!snapshot.hasData) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Total Participants', 'Loading...', const Color(0xFF4CAF50)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Active Participants', 'Loading...', const Color(0xFF10B981)),
                      ),
                    ],
                  );
                }

                final enrolments = snapshot.data!.docs;
                final workshopEnrolments = enrolments.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['itemType'] ?? '').toString().toLowerCase() == 'workshop';
                }).toList();

                final activeWorkshopEnrolments = workshopEnrolments.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? '').toString().toLowerCase();
                  return status == 'enrolled' || status == 'active';
                }).toList();

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatItem('Total Participants', workshopEnrolments.length.toString(), const Color(0xFF4CAF50)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatItem('Active Participants', activeWorkshopEnrolments.length.toString(), const Color(0xFF10B981)),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkshopsList() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, color: const Color(0xFFE53935), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Workshops History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('workshops').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading workshops: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final workshops = snapshot.data!.docs;

                if (workshops.isEmpty) {
                  return const Center(
                    child: Text(
                      'No workshops found',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: workshops.length,
                  itemBuilder: (context, index) {
                    final workshop = workshops[index];
                    final data = workshop.data() as Map<String, dynamic>;
                    data['id'] = workshop.id; // Add document ID
                    return _buildWorkshopCard(data);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkshopCard(Map<String, dynamic> workshop) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).cardColor.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.2),
          child: const Icon(Icons.event, color: Color(0xFFE53935)),
        ),
        title: Text(
          workshop['title'] ?? 'Untitled Workshop',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${workshop['date'] ?? workshop['startDate'] ?? 'TBD'}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Participants: ${workshop['enrolledCount'] ?? workshop['currentParticipants'] ?? 0}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Price: ${workshop['price'] ?? workshop['amount'] ?? 'TBD'}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFFE53935)),
          onPressed: () => _showWorkshopDetails(workshop),
        ),
      ),
    );
  }

  Widget _buildStudioBookingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStudioBookingsStats(),
          const SizedBox(height: 16),
          _buildStudioBookingsList(),
        ],
      ),
    );
  }

  Widget _buildStudioBookingsStats() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: const Color(0xFF2196F3), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Studio Bookings Statistics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('studioBookings').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Total Bookings', 'Error', const Color(0xFF2196F3)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Confirmed', 'Error', const Color(0xFF4CAF50)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Pending', 'Error', const Color(0xFFFF9800)),
                      ),
                    ],
                  );
                }

                if (!snapshot.hasData) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Total Bookings', 'Loading...', const Color(0xFF2196F3)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Confirmed', 'Loading...', const Color(0xFF4CAF50)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Pending', 'Loading...', const Color(0xFFFF9800)),
                      ),
                    ],
                  );
                }

                final bookings = snapshot.data!.docs;
                final confirmedBookings = bookings.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? '').toString().toLowerCase();
                  return status == 'confirmed' || status == 'approved';
                }).toList();

                final pendingBookings = bookings.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? '').toString().toLowerCase();
                  return status == 'pending' || status == 'waiting';
                }).toList();

                final cancelledBookings = bookings.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? '').toString().toLowerCase();
                  return status == 'cancelled' || status == 'rejected';
                }).toList();

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem('Total Bookings', bookings.length.toString(), const Color(0xFF2196F3)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatItem('Confirmed', confirmedBookings.length.toString(), const Color(0xFF4CAF50)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem('Pending', pendingBookings.length.toString(), const Color(0xFFFF9800)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatItem('Cancelled', cancelledBookings.length.toString(), const Color(0xFFF44336)),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioBookingsList() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: const Color(0xFF2196F3), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Studio Bookings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('studioBookings').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading studio bookings: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final bookings = snapshot.data!.docs;

                if (bookings.isEmpty) {
                  return const Center(
                    child: Text(
                      'No studio bookings found',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    final data = booking.data() as Map<String, dynamic>;
                    data['id'] = booking.id; // Add document ID
                    return _buildStudioBookingCard(data);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioBookingCard(Map<String, dynamic> booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).cardColor.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF2196F3).withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2196F3).withValues(alpha: 0.2),
          child: const Icon(Icons.business, color: Color(0xFF2196F3)),
        ),
        title: Text(
          booking['title'] ?? 'Studio Booking',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${booking['date'] ?? booking['bookingDate'] ?? 'TBD'}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Time: ${booking['time'] ?? booking['startTime'] ?? 'TBD'}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Status: ${booking['status'] ?? 'pending'}',
              style: TextStyle(
                color: (booking['status'] ?? '').toString().toLowerCase() == 'confirmed' 
                    ? const Color(0xFF4CAF50) 
                    : const Color(0xFFFF9800),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFF2196F3)),
          onPressed: () => _showStudioBookingDetails(booking),
        ),
      ),
    );
  }

  Widget _buildEventChoreographyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildEventChoreographyStats(),
          const SizedBox(height: 16),
          _buildEventChoreographyList(),
        ],
      ),
    );
  }

  Widget _buildEventChoreographyStats() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.celebration, color: const Color(0xFF9C27B0), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Event Choreography Statistics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('eventChoreoBookings').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Total Bookings', 'Error', const Color(0xFF9C27B0)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Confirmed', 'Error', const Color(0xFF4CAF50)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Pending', 'Error', const Color(0xFFFF9800)),
                      ),
                    ],
                  );
                }

                if (!snapshot.hasData) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Total Bookings', 'Loading...', const Color(0xFF9C27B0)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Confirmed', 'Loading...', const Color(0xFF4CAF50)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem('Pending', 'Loading...', const Color(0xFFFF9800)),
                      ),
                    ],
                  );
                }

                final bookings = snapshot.data!.docs;
                final confirmedBookings = bookings.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? '').toString().toLowerCase();
                  return status == 'confirmed' || status == 'approved';
                }).toList();

                final pendingBookings = bookings.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? '').toString().toLowerCase();
                  return status == 'pending' || status == 'waiting';
                }).toList();

                final cancelledBookings = bookings.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? '').toString().toLowerCase();
                  return status == 'cancelled' || status == 'rejected';
                }).toList();

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem('Total Bookings', bookings.length.toString(), const Color(0xFF9C27B0)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatItem('Confirmed', confirmedBookings.length.toString(), const Color(0xFF4CAF50)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem('Pending', pendingBookings.length.toString(), const Color(0xFFFF9800)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatItem('Cancelled', cancelledBookings.length.toString(), const Color(0xFFF44336)),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventChoreographyList() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.celebration, color: const Color(0xFF9C27B0), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Event Choreography Bookings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('eventChoreoBookings').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading event choreography bookings: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final bookings = snapshot.data!.docs;

                if (bookings.isEmpty) {
                  return const Center(
                    child: Text(
                      'No event choreography bookings found',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    final data = booking.data() as Map<String, dynamic>;
                    data['id'] = booking.id; // Add document ID
                    return _buildEventChoreographyCard(data);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventChoreographyCard(Map<String, dynamic> booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).cardColor.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF9C27B0).withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF9C27B0).withValues(alpha: 0.2),
          child: const Icon(Icons.celebration, color: Color(0xFF9C27B0)),
        ),
        title: Text(
          booking['eventType'] ?? 'Event Choreography',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${booking['eventDate'] ?? booking['date'] ?? 'TBD'}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Event Type: ${booking['eventType'] ?? booking['type'] ?? 'N/A'}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Status: ${booking['status'] ?? 'pending'}',
              style: TextStyle(
                color: (booking['status'] ?? '').toString().toLowerCase() == 'confirmed' 
                    ? const Color(0xFF4CAF50) 
                    : const Color(0xFFFF9800),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFF9C27B0)),
          onPressed: () => _showEventChoreographyDetails(booking),
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> data, String type) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).cardColor.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: const Color(0xFFFFC107).withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFC107).withValues(alpha: 0.2),
          child: const Icon(Icons.person, color: Color(0xFFFFC107)),
        ),
        title: Text(
          data['userName'] ?? 'Unknown User',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: ${data['status'] ?? 'active'}',
              style: TextStyle(
                color: (data['status'] == 'active') ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Class: ${data['className'] ?? 'Unknown Class'}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              'Package: ${data['packageName'] ?? 'Unknown Package'}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              'Sessions: ${data['completedSessions'] ?? 0}/${data['totalSessions'] ?? 0}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              'Payment: ${data['paymentStatus'] ?? 'pending'}',
              style: TextStyle(
                color: (data['paymentStatus'] == 'paid') ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: data['status'] == 'active' ? 'Deactivate Student' : 'Activate Student',
              child: IconButton(
                icon: Icon(
                  data['status'] == 'active' ? Icons.pause : Icons.play_arrow,
                  color: data['status'] == 'active' ? const Color(0xFFFF9800) : const Color(0xFF4CAF50),
                ),
                onPressed: () => _toggleStudentStatus(data),
              ),
            ),
            Tooltip(
              message: 'View Student Details',
              child: IconButton(
                icon: const Icon(Icons.info, color: Color(0xFF2196F3)),
                onPressed: () => _showStudentDetails(data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWorkshopDetails(Map<String, dynamic> workshop) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          workshop['title'] ?? 'Workshop Details',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${workshop['date'] ?? 'TBD'}', style: const TextStyle(color: Colors.white70)),
            Text('Time: ${workshop['time'] ?? 'TBD'}', style: const TextStyle(color: Colors.white70)),
            Text('Participants: ${workshop['enrolledCount'] ?? 0}', style: const TextStyle(color: Colors.white70)),
            Text('Price: ${workshop['price'] ?? 'TBD'}', style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  void _showStudioBookingDetails(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          booking['title'] ?? 'Studio Booking Details',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${booking['date'] ?? 'TBD'}', style: const TextStyle(color: Colors.white70)),
            Text('Time: ${booking['time'] ?? 'TBD'}', style: const TextStyle(color: Colors.white70)),
            Text('Status: ${booking['status'] ?? 'pending'}', style: const TextStyle(color: Colors.white70)),
            Text('Purpose: ${booking['purpose'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  void _showEventChoreographyDetails(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          booking['eventType'] ?? 'Event Choreography Details',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event Date: ${booking['eventDate'] ?? 'TBD'}', style: const TextStyle(color: Colors.white70)),
            Text('Status: ${booking['status'] ?? 'pending'}', style: const TextStyle(color: Colors.white70)),
            Text('Requirements: ${booking['requirements'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }


  void _toggleStudentStatus(Map<String, dynamic> data) async {
    try {
      final userId = data['id'];
      final currentStatus = data['status'] ?? 'active';
      final newStatus = currentStatus == 'active' ? 'inactive' : 'active';
      final newIsActive = newStatus == 'active';
      
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: User ID not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Text('Updating student status...'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );

      // Update status in users collection
      await _firestore.collection('users').doc(userId).update({
        'isActive': newIsActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Student status updated to $newStatus'),
            backgroundColor: newStatus == 'active' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStudentDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          data['userName'] ?? 'Student Details',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${data['userName'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70)),
            Text('Status: ${data['status'] ?? 'active'}', style: const TextStyle(color: Colors.white70)),
            Text('Enrollment Date: ${data['enrolledAt'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70)),
            Text('Type: ${data['itemType'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }
}
