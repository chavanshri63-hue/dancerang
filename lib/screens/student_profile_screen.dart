import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';
import 'class_history_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _userData = {};
  Map<String, dynamic> _attendanceStats = {};
  Map<String, dynamic> _enrollmentStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load user profile data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        _userData = userDoc.data()!;
      }

      // Load attendance statistics
      await _loadAttendanceStats(user.uid);

      // Load enrollment statistics
      await _loadEnrollmentStats(user.uid);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAttendanceStats(String userId) async {
    try {
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .get();

      int totalAttendance = attendanceSnapshot.docs.length;
      int onTimeCount = 0;
      int lateCount = 0;
      int absentCount = 0;

      Map<String, int> classAttendance = {};
      Map<String, int> monthlyAttendance = {};

      for (final doc in attendanceSnapshot.docs) {
        final data = doc.data();
        final isLate = data['isLate'] ?? false;
        final status = data['status'] ?? 'present';
        final className = data['className'] ?? 'Unknown';
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

        if (status == 'present') {
          if (isLate) {
            lateCount++;
          } else {
            onTimeCount++;
          }
        } else {
          absentCount++;
        }

        // Track class-wise attendance
        classAttendance[className] = (classAttendance[className] ?? 0) + 1;

        // Track monthly attendance
        if (timestamp != null) {
          final monthKey = '${timestamp.year}-${timestamp.month}';
          monthlyAttendance[monthKey] = (monthlyAttendance[monthKey] ?? 0) + 1;
        }
      }

      _attendanceStats = {
        'totalAttendance': totalAttendance,
        'onTimeCount': onTimeCount,
        'lateCount': lateCount,
        'absentCount': absentCount,
        'punctualityRate': totalAttendance > 0 ? (onTimeCount / totalAttendance * 100).round() : 0,
        'classAttendance': classAttendance,
        'monthlyAttendance': monthlyAttendance,
      };
    } catch (e) {
      _attendanceStats = {
        'totalAttendance': 0,
        'onTimeCount': 0,
        'lateCount': 0,
        'absentCount': 0,
        'punctualityRate': 0,
        'classAttendance': {},
        'monthlyAttendance': {},
      };
    }
  }

  Future<void> _loadEnrollmentStats(String userId) async {
    try {
      // Load from new enrolments collection
      final enrollmentSnapshot = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .get();

      int totalEnrollments = enrollmentSnapshot.docs.length;
      int activeEnrollments = 0;
      int expiredEnrollments = 0;
      int completedEnrollments = 0;
      double totalSpent = 0;
      int totalSessions = 0;
      int completedSessions = 0;

      Map<String, dynamic> packageEnrollments = {};

      for (final doc in enrollmentSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'enrolled';
        final packageName = data['packageName'] ?? 'Unknown Package';
        final packagePrice = (data['amount'] ?? 0).toDouble();
        final totalSessionsCount = (data['totalSessions'] ?? 0) as int;
        final completedSessionsCount = (data['completedSessions'] ?? 0) as int;

        totalSpent += packagePrice;
        totalSessions += totalSessionsCount;
        completedSessions += completedSessionsCount;

        switch (status) {
          case 'enrolled':
            activeEnrollments++;
            break;
          case 'expired':
            expiredEnrollments++;
            break;
          case 'completed':
            completedEnrollments++;
            break;
        }

        packageEnrollments[packageName] = ((packageEnrollments[packageName] as int?) ?? 0) + 1;
      }

      _enrollmentStats = {
        'totalEnrollments': totalEnrollments,
        'activeEnrollments': activeEnrollments,
        'expiredEnrollments': expiredEnrollments,
        'completedEnrollments': completedEnrollments,
        'totalSpent': totalSpent,
        'totalSessions': totalSessions,
        'completedSessions': completedSessions,
        'packageEnrollments': packageEnrollments,
      };
    } catch (e) {
      _enrollmentStats = {
        'totalEnrollments': 0,
        'activeEnrollments': 0,
        'expiredEnrollments': 0,
        'completedEnrollments': 0,
        'totalSpent': 0,
        'totalSessions': 0,
        'completedSessions': 0,
        'packageEnrollments': {},
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'My Profile',
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white70,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Attendance'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildAttendanceTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProfileCard(),
          const SizedBox(height: 16),
          _buildQuickStats(),
          const SizedBox(height: 16),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE53935),
            ),
            child: (_userData['photoUrl'] != null && _userData['photoUrl'].isNotEmpty) || (_userData['profilePhoto'] != null && _userData['profilePhoto'].isNotEmpty)
                ? ClipOval(
                    child: Image.network(
                      _userData['photoUrl'] ?? _userData['profilePhoto'],
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            (_userData['name'] ?? 'U').substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Text(
                      (_userData['name'] ?? 'U').substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            _userData['name'] ?? 'Unknown User',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _userData['email'] ?? 'No email',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Level: ${_userData['level'] ?? 'Beginner'}',
            style: const TextStyle(
              color: Color(0xFFE53935),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Attendance',
            '${_attendanceStats['totalAttendance']}',
            'Total Classes',
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Punctuality',
            '${_attendanceStats['punctualityRate']}%',
            'On Time Rate',
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Enrollments',
            '${_enrollmentStats['activeEnrollments']}',
            'Active Classes',
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: color.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildActivityItem(
            Icons.school,
            'Active Enrollments',
            '${_enrollmentStats['activeEnrollments']} classes/workshops',
            Colors.green,
          ),
          const SizedBox(height: 8),
          _buildActivityItem(
            Icons.check_circle,
            'Total Attendance',
            '${_attendanceStats['totalAttendance']} classes attended',
            Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildActivityItem(
            Icons.schedule,
            'Punctuality',
            '${_attendanceStats['punctualityRate']}% on time',
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(IconData icon, String title, String subtitle, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAttendanceOverview(),
          const SizedBox(height: 16),
          _buildClassAttendanceChart(),
          const SizedBox(height: 16),
          _buildMonthlyAttendanceChart(),
        ],
      ),
    );
  }

  Widget _buildAttendanceOverview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAttendanceStat('Present', '${_attendanceStats['onTimeCount']}', Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAttendanceStat('Late', '${_attendanceStats['lateCount']}', Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAttendanceStat('Absent', '${_attendanceStats['absentCount']}', Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassAttendanceChart() {
    final classAttendance = _attendanceStats['classAttendance'] as Map<String, int>;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Class-wise Attendance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (classAttendance.isEmpty)
            const Text(
              'No attendance data available',
              style: TextStyle(color: Colors.white70),
            )
          else
            ...classAttendance.entries.map((entry) {
              final maxAttendance = classAttendance.values.reduce((a, b) => a > b ? a : b);
              final percentage = maxAttendance > 0 ? (entry.value / maxAttendance * 100).round() : 0;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          '${entry.value} classes',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: entry.value / maxAttendance,
                      backgroundColor: Colors.grey.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage >= 70 ? Colors.green : percentage >= 40 ? Colors.orange : Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildMonthlyAttendanceChart() {
    final monthlyAttendance = _attendanceStats['monthlyAttendance'] as Map<String, int>;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Attendance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (monthlyAttendance.isEmpty)
            const Text(
              'No monthly data available',
              style: TextStyle(color: Colors.white70),
            )
          else
            ...monthlyAttendance.entries.map((entry) {
              final dateParts = entry.key.split('-');
              final month = int.parse(dateParts[1]);
              final year = int.parse(dateParts[0]);
              final monthName = _getMonthName(month);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$monthName $year',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      '${entry.value} classes',
                      style: const TextStyle(color: Color(0xFFE53935), fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }






  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
