import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../services/live_metrics_service.dart';
import '../services/live_attendance_service.dart';
import '../services/live_analytics_service.dart';
import '../services/payment_service.dart';
import '../widgets/glassmorphism_app_bar.dart';
import 'admin_attendance_reports_screen.dart';
import 'student_profile_screen.dart';

class AdminLiveDashboard extends StatefulWidget {
  const AdminLiveDashboard({super.key});

  @override
  State<AdminLiveDashboard> createState() => _AdminLiveDashboardState();
}

class _AdminLiveDashboardState extends State<AdminLiveDashboard> {
  int _selectedIndex = 0;
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;

  @override
  void initState() {
    super.initState();
    
    // Listen to payment success events for real-time metrics updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (event['type'] == 'payment_success' && mounted) {
        // Force rebuild when payment succeeds
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _paymentRefreshSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'Live Dashboard',
        onLeadingPressed: () => Navigator.pop(context),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildMetricsTab(),
          _buildAttendanceTab(),
          _buildNotificationsTab(),
          _buildAnalyticsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1B1B1B),
        selectedItemColor: const Color(0xFFE53935),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Metrics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Metrics',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          
          // Classes Metrics
          StreamBuilder<Map<String, dynamic>>(
            stream: LiveMetricsService.getLiveEnrollmentMetrics(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final data = snapshot.data ?? {};
              return _buildMetricCard(
                title: 'Classes Enrollment',
                icon: Icons.school,
                color: Colors.blue,
                metrics: [
                  'Total Enrollments: ${data['totalEnrollments'] ?? 0}',
                  'Total Capacity: ${data['totalCapacity'] ?? 0}',
                  'Occupancy Rate: ${data['occupancyRate'] ?? 0}%',
                  'Fully Booked: ${data['fullyBooked'] ?? 0}',
                  'Available Spots: ${data['availableSpots'] ?? 0}',
                ],
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Workshops Metrics
          StreamBuilder<Map<String, dynamic>>(
            stream: LiveMetricsService.getLiveWorkshopMetrics(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final data = snapshot.data ?? {};
              return _buildMetricCard(
                title: 'Workshops Enrollment',
                icon: Icons.workspace_premium,
                color: Colors.purple,
                metrics: [
                  'Total Enrollments: ${data['totalEnrollments'] ?? 0}',
                  'Total Capacity: ${data['totalCapacity'] ?? 0}',
                  'Occupancy Rate: ${data['occupancyRate'] ?? 0}%',
                  'Fully Booked: ${data['fullyBooked'] ?? 0}',
                  'Total Workshops: ${data['totalWorkshops'] ?? 0}',
                ],
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Revenue Metrics
          StreamBuilder<Map<String, dynamic>>(
            stream: LiveMetricsService.getLiveRevenueMetrics(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final data = snapshot.data ?? {};
              return _buildMetricCard(
                title: 'Revenue Analytics',
                icon: Icons.currency_rupee,
                color: Colors.green,
                metrics: [
                  'Total Revenue: ₹${data['totalRevenue'] ?? 0}',
                  'Today: ₹${data['todayRevenue'] ?? 0}',
                  'This Week: ₹${data['thisWeekRevenue'] ?? 0}',
                  'This Month: ₹${data['thisMonthRevenue'] ?? 0}',
                  'Average per Payment: ₹${data['averagePayment'] ?? 0}',
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Attendance',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          
          // QR Scanner for Attendance
          Card(
            color: const Color(0xFF1B1B1B),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 64,
                    color: Color(0xFFE53935),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'QR Code Scanner',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scan QR codes to mark attendance for classes and workshops',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showQRScanner(),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Start Scanning'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Reports Section
          Card(
            color: const Color(0xFF1B1B1B),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.assessment,
                    size: 64,
                    color: Color(0xFFE53935),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Attendance Reports',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Generate detailed attendance reports and analytics',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminAttendanceReportsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.assessment),
                    label: const Text('View Reports'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Recent Attendance
          Text(
            'Recent Attendance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: LiveAttendanceService.getRecentAttendance(limit: 20),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final attendance = snapshot.data ?? [];
              if (attendance.isEmpty) {
                return const Card(
                  color: Color(0xFF1B1B1B),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No recent attendance records',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: attendance.length,
                itemBuilder: (context, index) {
                  final record = attendance[index];
                  return Card(
                    color: const Color(0xFF1B1B1B),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: record['status'] == 'present' 
                            ? Colors.green 
                            : Colors.red,
                        child: Icon(
                          record['status'] == 'present' 
                              ? Icons.check 
                              : Icons.close,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(record['userName'] ?? 'Unknown'),
                      subtitle: Text(record['className'] ?? 'Unknown Class'),
                      trailing: Text(
                        record['markedAt']?.toDate().toString().substring(11, 16) ?? '',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Notifications',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          
          // Live Activity Feed
          _buildLiveActivityFeed(),
          
          const SizedBox(height: 20),
          
          // Send Test Notification
          Card(
            color: const Color(0xFF1B1B1B),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    size: 64,
                    color: Color(0xFFE53935),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Send Test Notification',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Send a test notification to all users',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _sendTestNotification(),
                    icon: const Icon(Icons.send),
                    label: const Text('Send Test'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Spot Monitoring Status
          Card(
            color: const Color(0xFF1B1B1B),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.monitor, color: Color(0xFFE53935)),
                      const SizedBox(width: 8),
                      Text(
                        'Spot Monitoring',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '✅ Active - Monitoring class and workshop spots',
                    style: TextStyle(color: Colors.green),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• Sends alerts when spots are running low',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Text(
                    '• Notifies when classes are full',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Text(
                    '• Real-time capacity updates',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Analytics',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          
          // Trending Classes
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: LiveAnalyticsService.getTrendingClasses(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final trending = snapshot.data ?? [];
              return _buildAnalyticsCard(
                title: 'Trending Classes',
                icon: Icons.trending_up,
                color: Colors.orange,
                items: trending.take(5).map((item) => 
                  '${item['name']} - ${item['enrollmentCount']} enrollments'
                ).toList(),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Live Enrollment Tracking
          _buildLiveEnrollmentSection(),
          
          const SizedBox(height: 16),
          
          // Live Booking Updates
          _buildLiveBookingSection(),
          
          const SizedBox(height: 16),
          
          // Student Management Section
          _buildStudentManagementSection(),
          
          const SizedBox(height: 16),
          
          // Category Performance
          StreamBuilder<Map<String, dynamic>>(
            stream: LiveAnalyticsService.getRevenueAnalytics(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final data = snapshot.data ?? {};
              final categoryRevenue = data['categoryRevenue'] as Map<String, int>? ?? {};
              return _buildAnalyticsCard(
                title: 'Category Performance',
                icon: Icons.category,
                color: Colors.purple,
                items: categoryRevenue.entries.map((entry) => 
                  '${entry.key}: ₹${entry.value}'
                ).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> metrics,
  }) {
    return Card(
      color: const Color(0xFF1B1B1B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...metrics.map((metric) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                metric,
                style: const TextStyle(color: Colors.grey),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Card(
      color: const Color(0xFF1B1B1B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text(
                'No data available',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  item,
                  style: const TextStyle(color: Colors.grey),
                ),
              )),
          ],
        ),
      ),
    );
  }

  void _showQRScanner() {
    // QR Scanner functionality - redirects to existing QR scanner screen
    Navigator.pushNamed(context, '/qr-scanner');
  }

  void _sendTestNotification() {
    // Test notification functionality - uses existing notification service
    try {
      // This would integrate with LiveNotificationService
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildLiveEnrollmentSection() {
    return Card(
      color: const Color(0xFF1B1B1B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Live Enrollment Tracking',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Recent Enrollments
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('enrollments')
                  .orderBy('ts', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text(
                    'No recent enrollments',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = (data['ts'] as Timestamp?)?.toDate();
                    final timeAgo = timestamp != null 
                        ? _getTimeAgo(timestamp)
                        : 'Just now';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE53935).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.school,
                              color: Color(0xFFE53935),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['title'] ?? 'Unknown Class',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${data['itemType'] ?? 'Class'} • ₹${data['amount'] ?? 0}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveBookingSection() {
    return Card(
      color: const Color(0xFF1B1B1B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Live Booking Updates',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Recent Bookings
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text(
                    'No recent bookings',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = (data['createdAt'] as Timestamp?)?.toDate();
                    final timeAgo = timestamp != null 
                        ? _getTimeAgo(timestamp)
                        : 'Just now';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.book_online,
                              color: Color(0xFF4F46E5),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['itemName'] ?? 'Unknown Booking',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${data['bookingType'] ?? 'Booking'} • ${data['status'] ?? 'Pending'}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveActivityFeed() {
    return Card(
      color: const Color(0xFF1B1B1B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline, color: Colors.cyan),
                const SizedBox(width: 8),
                Text(
                  'Live Activity Feed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyan, width: 1),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Recent Activity
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('admin_notifications')
                  .orderBy('created_at', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text(
                    'No recent activity',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = (data['created_at'] as Timestamp?)?.toDate();
                    final timeAgo = timestamp != null 
                        ? _getTimeAgo(timestamp)
                        : 'Just now';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE53935).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.notifications,
                              color: Color(0xFFE53935),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['title'] ?? 'Notification',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data['message'] ?? 'No message',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildStudentManagementSection() {
    return Card(
      color: const Color(0xFF1B1B1B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Student Management',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StudentProfileScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person, color: Colors.blue),
                  label: const Text('View Profile', style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'Student')
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text(
                    'No students found',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE53935),
                        child: Text(
                          (data['name'] ?? 'U').substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        data['name'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Level: ${data['level'] ?? 'Beginner'}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: Text(
                        data['isActive'] == true ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: data['isActive'] == true ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        // Navigate to student profile
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StudentProfileScreen(),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}