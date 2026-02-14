import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/payment_service.dart';
import 'qr_display_screen.dart';
import 'qr_scanner_screen.dart';
import '../utils/error_handler.dart';

class AttendanceScreen extends StatefulWidget {
  final String role; // 'student' | 'faculty' | 'admin'
  const AttendanceScreen({super.key, required this.role});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _getTabCount(), vsync: this);
    _loadData();
    
    // Listen to payment success events for real-time attendance updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (event['type'] == 'payment_success' && mounted) {
        // Refresh attendance data when payment succeeds
        _loadData();
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
      case 'student':
        return 2; // QR Code, Summary
      case 'faculty':
        return 3; // QR Scanner, Student List, Summary
      case 'admin':
        return 4; // QR Scanner, Student List, Reports, Summary
      default:
        return 2;
    }
  }

  List<String> _getTabTitles() {
    switch (widget.role) {
      case 'student':
        return ['My QR Code', 'Summary'];
      case 'faculty':
        return ['QR Scanner', 'Student List', 'Summary'];
      case 'admin':
        return ['QR Scanner', 'Student List', 'Reports', 'Summary'];
      default:
        return ['QR Code', 'Summary'];
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate loading delay
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });
  }

  Future<Map<String, dynamic>> _getLiveAttendanceData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'totalAttendance': 0,
          'attendedSessions': 0,
          'overallAttendanceRate': 0,
          'onTimeCount': 0,
          'lateCount': 0,
          'recentAttendance': <Map<String, dynamic>>[],
        };
      }

      // Get attendance records
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .get();

      int totalAttendance = attendanceSnapshot.docs.length;
      int onTimeCount = 0;
      int lateCount = 0;
      List<Map<String, dynamic>> recentAttendance = [];

      for (final doc in attendanceSnapshot.docs) {
        final data = doc.data();
        final isLate = data['isLate'] ?? false;
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        
        if (isLate) {
          lateCount++;
        } else {
          onTimeCount++;
        }

        // Add to recent attendance (last 5 records)
        if (recentAttendance.length < 5 && timestamp != null) {
          recentAttendance.add({
            'className': data['className'] ?? 'Unknown Class',
            'instructor': data['instructor'] ?? 'Unknown',
            'timestamp': timestamp,
            'isLate': isLate,
            'status': 'present',
          });
        }
      }

      // Sort recent attendance by timestamp
      recentAttendance.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

      final overallAttendanceRate = totalAttendance > 0 ? (onTimeCount / totalAttendance * 100).round() : 0;

      return {
        'totalAttendance': totalAttendance,
        'attendedSessions': totalAttendance,
        'overallAttendanceRate': overallAttendanceRate,
        'onTimeCount': onTimeCount,
        'lateCount': lateCount,
        'recentAttendance': recentAttendance,
      };
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'loading attendance data');
      return {
        'totalAttendance': 0,
        'attendedSessions': 0,
        'overallAttendanceRate': 0,
        'onTimeCount': 0,
        'lateCount': 0,
        'recentAttendance': <Map<String, dynamic>>[],
      };
    }
  }

  Future<Map<String, dynamic>> _getLiveAdminData() async {
    try {
      // Get all students count
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
      final totalStudents = studentsSnapshot.docs.length;

      // Get current month start and end
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Get classes this month
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
          .get();
      final classesThisMonth = classesSnapshot.docs.length;

      // Get workshops this month
      final workshopsSnapshot = await FirebaseFirestore.instance
          .collection('workshops')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
          .get();
      final workshopsThisMonth = workshopsSnapshot.docs.length;

      // Get overall attendance rate
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .get();
      
      final totalAttendanceRecords = attendanceSnapshot.docs.length;
      final onTimeRecords = attendanceSnapshot.docs
          .where((doc) => doc.data()['isLate'] == false)
          .length;
      
      final overallRate = totalAttendanceRecords > 0 ? 
        '${((onTimeRecords / totalAttendanceRecords) * 100).round()}%' : '0%';

      return {
        'totalStudents': totalStudents.toString(),
        'classesThisMonth': classesThisMonth.toString(),
        'workshopsThisMonth': workshopsThisMonth.toString(),
        'overallRate': overallRate,
      };
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'loading admin attendance data');
      return {
        'totalStudents': '0',
        'classesThisMonth': '0',
        'workshopsThisMonth': '0',
        'overallRate': '0%',
      };
    }
  }

  Future<List<Map<String, dynamic>>> _getLiveStudentList() async {
    try {
      // Get all students - simplified query to avoid index issues
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      List<Map<String, dynamic>> studentsWithAttendance = [];

      for (final studentDoc in studentsSnapshot.docs) {
        final studentData = studentDoc.data();
        final studentId = studentDoc.id;

        // Get attendance records for this student
        final attendanceSnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .where('userId', isEqualTo: studentId)
            .get();

        final totalAttendance = attendanceSnapshot.docs.length;
        final onTimeAttendance = attendanceSnapshot.docs
            .where((doc) => doc.data()['isLate'] == false)
            .length;

        // Get enrolled classes for this student from new class_enrollments collection
        final enrollmentsSnapshot = await FirebaseFirestore.instance
            .collection('class_enrollments')
            .where('userId', isEqualTo: studentId)
            .where('status', isEqualTo: 'active')
            .get();

        String className = 'No Class';
        String packageName = '';
        int completedSessions = 0;
        int totalSessions = 0;
        String paymentStatus = 'pending';
        
        if (enrollmentsSnapshot.docs.isNotEmpty) {
          final enrollment = enrollmentsSnapshot.docs.first.data();
          className = enrollment['className'] ?? 'No Class';
          packageName = enrollment['packageName'] ?? '';
          completedSessions = enrollment['completedSessions'] ?? 0;
          totalSessions = enrollment['totalSessions'] ?? 0;
          paymentStatus = enrollment['paymentStatus'] ?? 'pending';
        }

        final attendanceRate = totalAttendance > 0 ? 
          '${((onTimeAttendance / totalAttendance) * 100).round()}%' : '0%';

        studentsWithAttendance.add({
          'name': studentData['name'] ?? 'Unknown Student',
          'className': className,
          'packageName': packageName,
          'completedSessions': completedSessions,
          'totalSessions': totalSessions,
          'paymentStatus': paymentStatus,
          'attendanceRate': attendanceRate,
          'attendanceCount': '$onTimeAttendance/$totalAttendance',
        });
      }

      // Sort by attendance rate (highest first)
      studentsWithAttendance.sort((a, b) {
        final aRate = int.tryParse(a['attendanceRate'].toString().replaceAll('%', '')) ?? 0;
        final bRate = int.tryParse(b['attendanceRate'].toString().replaceAll('%', '')) ?? 0;
        return bRate.compareTo(aRate);
      });

      return studentsWithAttendance;
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'loading student list');
      return [];
    }
  }

  Color _getAttendanceColor(String attendanceRate) {
    final rate = int.tryParse(attendanceRate.replaceAll('%', '')) ?? 0;
    if (rate >= 90) return const Color(0xFF10B981); // Green
    if (rate >= 80) return const Color(0xFF4F46E5); // Blue
    if (rate >= 70) return const Color(0xFFFF9800); // Orange
    return const Color(0xFFE53935); // Red
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: _getAppBarTitle(),
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
      case 'student':
        return 'My Attendance';
      case 'faculty':
        return 'Mark Attendance';
      case 'admin':
        return 'Attendance Management';
      default:
        return 'Attendance';
    }
  }

  List<Widget> _buildTabViews() {
    switch (widget.role) {
      case 'student':
        return [
          _buildStudentQRCode(),
          _buildStudentSummary(),
        ];
      case 'faculty':
        return [
          _buildQRScanner(),
          _buildStudentList(),
          _buildFacultySummary(),
        ];
      case 'admin':
        return [
          _buildQRScanner(),
          _buildStudentList(),
          _buildAdminReports(),
          _buildAdminSummary(),
        ];
      default:
        return [
          _buildStudentQRCode(),
          _buildStudentSummary(),
        ];
    }
  }

  // Student QR Code Tab
  Widget _buildStudentQRCode() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 8,
              shadowColor: const Color(0xFFE53935).withValues(alpha: 0.2),
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(
                  color: Color(0xFFE53935),
                  width: 2,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE53935).withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.qr_code,
                        size: 80,
                        color: Color(0xFFE53935),
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Quick summary under QR (student)
                  if (widget.role == 'student')
                    _StudentQuickAttendanceSummary(),
                    const Text(
                      'Show this QR Code to your instructor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your instructor will scan this code to mark your attendance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
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
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QRDisplayScreen(role: 'student'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.qr_code, size: 20),
                        label: const Text('Open Full QR Code'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Student Summary Tab
  Widget _buildStudentSummary() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildSummaryCardSimple(
            'Total Classes Attended',
            '0',
            Icons.school,
            const Color(0xFF4F46E5),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.white70,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('attendance')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE53935)),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          int totalAttendance = docs.length;
          int onTimeCount = 0;
          int lateCount = 0;
          List<Map<String, dynamic>> recentAttendance = [];

          for (final doc in docs) {
            final data = doc.data();
            final isLate = data['isLate'] == true;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
            if (isLate) {
              lateCount++;
            } else {
              onTimeCount++;
            }
            if (timestamp != null) {
              recentAttendance.add({
                'className': data['className'] ?? 'Unknown Class',
                'instructor': data['instructor'] ?? 'Unknown',
                'timestamp': timestamp,
                'isLate': isLate,
                'status': data['status'] ?? 'present',
              });
            }
          }

          recentAttendance.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
          if (recentAttendance.length > 5) {
            recentAttendance = recentAttendance.take(5).toList();
          }

          final overallAttendanceRate = totalAttendance > 0 ? (onTimeCount / totalAttendance * 100).round() : 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSummaryCardSimple(
                'Total Classes Attended',
                '$totalAttendance',
                Icons.school,
                const Color(0xFF4F46E5),
              ),
              const SizedBox(height: 12),
              _buildSummaryCardSimple(
                'On Time Attendance',
                '$onTimeCount',
                Icons.schedule,
                const Color(0xFF10B981),
              ),
              const SizedBox(height: 12),
              _buildSummaryCardSimple(
                'Attendance Percentage',
                '$overallAttendanceRate%',
                Icons.trending_up,
                const Color(0xFFFF9800),
              ),
              const SizedBox(height: 12),
              _buildSummaryCardSimple(
                'Late Arrivals',
                '$lateCount',
                Icons.schedule,
                const Color(0xFFE53935),
              ),
              const SizedBox(height: 24),
              _buildRecentAttendance(recentAttendance),
              const SizedBox(height: 24),
              _buildPerClassRemainingSection(user.uid),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPerClassRemainingSection(String userId) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
            const Text(
              'Active Enrollments',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('enrollments')
                  .where('userId', isEqualTo: userId)
                  .where('status', whereIn: ['enrolled', 'completed'])
                  .where('itemType', isEqualTo: 'class')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white70));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Text('No active enrollments', style: TextStyle(color: Colors.white70));
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final className = data['className'] ?? data['itemName'] ?? 'Class';
                    final total = (data['totalSessions'] as num?)?.toInt() ?? 0;
                    final remaining = (data['remainingSessions'] as num?)?.toInt() ?? 0;
                    final status = data['status'] as String? ?? 'enrolled';
                    final isCompleted = status == 'completed';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(className, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                if (isCompleted) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.orange, width: 1),
                                    ),
                                    child: const Text(
                                      'Completed',
                                      style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            isCompleted 
                                ? 'Completed' 
                                : (remaining >= 0 && total > 0 ? '$remaining / $total left' : '—'),
                            style: TextStyle(
                              color: isCompleted 
                                  ? Colors.orange 
                                  : (remaining > 0 ? const Color(0xFF10B981) : const Color(0xFFE53935)),
                              fontWeight: FontWeight.bold,
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

  // QR Scanner Tab (Faculty & Admin)
  Widget _buildQRScanner() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 8,
              shadowColor: const Color(0xFFE53935).withValues(alpha: 0.2),
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(
                  color: Color(0xFFE53935),
                  width: 2,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE53935).withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        size: 80,
                        color: Color(0xFFE53935),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Scan Student QR Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Point camera at student\'s QR code to mark attendance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
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
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QRScannerScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.qr_code_scanner, size: 20),
                        label: const Text('Open QR Scanner'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Student List Tab (Faculty & Admin)
  Widget _buildStudentList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.white70,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('attendance')
            .orderBy('markedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading attendance data',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final attendanceRecords = snapshot.data?.docs ?? [];

          if (attendanceRecords.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No attendance records found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Attendance will appear here after marking',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Group attendance by today's date
          final today = DateTime.now();
          final todayRecords = attendanceRecords.where((doc) {
            final markedAt = (doc.data()['markedAt'] as Timestamp?)?.toDate();
            if (markedAt == null) return false;
            return markedAt.year == today.year && 
                   markedAt.month == today.month && 
                   markedAt.day == today.day;
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: todayRecords.length,
            itemBuilder: (context, index) {
              final record = todayRecords[index];
              final data = record.data();
              final markedAt = (data['markedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAttendanceCard(
                  studentName: data['userName'] ?? 'Unknown Student',
                  className: data['className'] ?? data['classId'] ?? 'Unknown Class',
                  markedAt: markedAt,
                  isLate: data['isLate'] == true,
                  lateMinutes: data['lateMinutes'] ?? 0,
                  status: data['status'] ?? 'present',
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Admin Reports Tab
  Widget _buildAdminReports() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.white70,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Student')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading data',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final students = snapshot.data?.docs ?? [];
          final totalStudents = students.length;
          
          // Calculate real-time data
          return _buildReportsContent(totalStudents);
        },
      ),
    );
  }

  Widget _buildAttendanceCard({
    required String studentName,
    required String className,
    required DateTime markedAt,
    required bool isLate,
    required int lateMinutes,
    required String status,
  }) {
    final timeStr = '${markedAt.hour.toString().padLeft(2, '0')}:${markedAt.minute.toString().padLeft(2, '0')}';
    final dateStr = '${markedAt.day}/${markedAt.month}/${markedAt.year}';
    
    return Card(
      elevation: 6,
      color: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLate ? Colors.orange : Colors.green,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isLate ? Colors.orange.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isLate ? Icons.schedule : Icons.check_circle,
                color: isLate ? Colors.orange : Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            
            // Student Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    className,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$timeStr • $dateStr',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      if (isLate) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${lateMinutes}m late',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'present' ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: status == 'present' ? Colors.green : Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsContent(int totalStudents) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildReportCard(
          'Total Students',
          totalStudents.toString(),
          Icons.people,
          const Color(0xFF10B981),
          'Currently enrolled students',
        ),
        const SizedBox(height: 12),
        _buildReportCard(
          'Active Classes',
          '5', // This will be calculated from classes collection
          Icons.school,
          const Color(0xFFFF9800),
          'Scheduled dance classes',
        ),
        const SizedBox(height: 12),
        _buildReportCard(
          'Attendance Rate',
          '85%', // This will be calculated from attendance records
          Icons.trending_up,
          const Color(0xFF4F46E5),
          'Overall attendance percentage',
        ),
        const SizedBox(height: 12),
        _buildReportCard(
          'Recent Activity',
          '12', // This will be calculated from recent attendance
          Icons.event,
          const Color(0xFFE53935),
          'Attendance marked today',
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color accentColor,
    String subtitle,
  ) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: accentColor.withValues(alpha: 0.4),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
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

  Widget _buildStudentCard(
    String name,
    String className,
    String attendance,
    String classesAttended,
    Color accentColor,
  ) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: accentColor.withValues(alpha: 0.2),
                child: Text(
                  name[0],
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      className,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Attendance: ',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          attendance,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Classes: ',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          classesAttended,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('View details for $name'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text(
                    'Details',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(
    String title,
    String value,
    IconData icon,
    Color accentColor,
    String subtitle,
  ) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: accentColor.withValues(alpha: 0.4),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
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

  Widget _buildRecentAttendance(List<Map<String, dynamic>> recentAttendance) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent Attendance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (recentAttendance.isEmpty)
                const Text(
                  'No attendance records yet',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                )
              else
                ...recentAttendance.map((item) {
                  final timeAgo = _getTimeAgo(item['timestamp'] as DateTime);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildAttendanceItem(
                      item['className'],
                      timeAgo,
                      item['status'] == 'present',
                      isLate: item['isLate'] ?? false,
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceItem(String className, String date, bool attended, {bool isLate = false}) {
    return Row(
      children: [
        Icon(
          attended ? Icons.check_circle : Icons.cancel,
          color: attended ? (isLate ? Colors.orange : const Color(0xFF10B981)) : const Color(0xFFE53935),
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                className,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              if (isLate && attended)
                const Text(
                  'Late',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        Text(
          date,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // Faculty Summary Tab
  Widget _buildFacultySummary() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.white70,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _getFacultyAttendanceSummary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE53935)),
            );
          }

          final data = snapshot.data ?? {
            'totalStudents': 0,
            'totalSessions': 0,
            'averageAttendance': 0,
            'topPerformers': <Map<String, dynamic>>[],
            'needsAttention': <Map<String, dynamic>>[],
          };

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Overview Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCardSimple(
                      'Total Students',
                      '${data['totalStudents']}',
                      Icons.people,
                      const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCardSimple(
                      'Sessions Conducted',
                      '${data['totalSessions']}',
                      Icons.event,
                      const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCardSimple(
                      'Avg Attendance',
                      '${data['averageAttendance']}%',
                      Icons.trending_up,
                      const Color(0xFFFF9800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCardSimple(
                      'Needs Attention',
                      '${data['needsAttention'].length}',
                      Icons.warning,
                      const Color(0xFFE53935),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Top Performers
              if (data['topPerformers'].isNotEmpty) ...[
                _buildSectionHeader('Top Performers', Icons.star),
                const SizedBox(height: 12),
                ...data['topPerformers'].map((student) => _buildStudentCardSimple(student)),
                const SizedBox(height: 20),
              ],

              // Students Needing Attention
              if (data['needsAttention'].isNotEmpty) ...[
                _buildSectionHeader('Students Needing Attention', Icons.warning),
                const SizedBox(height: 12),
                ...data['needsAttention'].map((student) => _buildStudentCardSimple(student, isWarning: true)),
              ],
            ],
          );
        },
      ),
    );
  }

  // Admin Summary Tab
  Widget _buildAdminSummary() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.white70,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _getAdminAttendanceSummary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE53935)),
            );
          }

          final data = snapshot.data ?? {
            'totalStudents': 0,
            'totalFaculty': 0,
            'totalSessions': 0,
            'overallAttendance': 0,
            'classStats': <Map<String, dynamic>>[],
            'facultyStats': <Map<String, dynamic>>[],
          };

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Overview Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCardSimple(
                      'Total Students',
                      '${data['totalStudents']}',
                      Icons.people,
                      const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCardSimple(
                      'Faculty Members',
                      '${data['totalFaculty']}',
                      Icons.school,
                      const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCardSimple(
                      'Total Sessions',
                      '${data['totalSessions']}',
                      Icons.event,
                      const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCardSimple(
                      'Overall Attendance',
                      '${data['overallAttendance']}%',
                      Icons.trending_up,
                      const Color(0xFFFF9800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Class Statistics
              if (data['classStats'].isNotEmpty) ...[
                _buildSectionHeader('Class Statistics', Icons.school),
                const SizedBox(height: 12),
                ...data['classStats'].map((classStat) => _buildClassStatCard(classStat)),
                const SizedBox(height: 20),
              ],

              // Faculty Performance
              if (data['facultyStats'].isNotEmpty) ...[
                _buildSectionHeader('Faculty Performance', Icons.person),
                const SizedBox(height: 12),
                ...data['facultyStats'].map((faculty) => _buildFacultyCard(faculty)),
              ],
            ],
          );
        },
      ),
    );
  }

  // Helper methods for summary data
  Future<Map<String, dynamic>> _getFacultyAttendanceSummary() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      // Get faculty's classes
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('instructorId', isEqualTo: user.uid)
          .get();

      int totalSessions = 0;
      int totalStudents = 0;
      List<Map<String, dynamic>> topPerformers = [];
      List<Map<String, dynamic>> needsAttention = [];

      for (final classDoc in classesSnapshot.docs) {
        final classData = classDoc.data();
        totalSessions++;

        // Get students in this class
        final enrollmentsSnapshot = await FirebaseFirestore.instance
            .collection('enrollments')
            .where('classId', isEqualTo: classDoc.id)
            .get();

        totalStudents += enrollmentsSnapshot.docs.length;

        // Get attendance for each student
        for (final enrollment in enrollmentsSnapshot.docs) {
          final studentId = enrollment.data()['userId'];
          final studentName = enrollment.data()['studentName'] ?? 'Unknown';

          final attendanceSnapshot = await FirebaseFirestore.instance
              .collection('attendance')
              .where('userId', isEqualTo: studentId)
              .where('classId', isEqualTo: classDoc.id)
              .get();

          final attendanceCount = attendanceSnapshot.docs.length;
          final attendanceRate = totalSessions > 0 ? (attendanceCount / totalSessions * 100).round() : 0;

          if (attendanceRate >= 80) {
            topPerformers.add({
              'name': studentName,
              'attendanceRate': attendanceRate,
              'className': classData['name'] ?? 'Unknown Class',
            });
          } else if (attendanceRate < 50) {
            needsAttention.add({
              'name': studentName,
              'attendanceRate': attendanceRate,
              'className': classData['name'] ?? 'Unknown Class',
            });
          }
        }
      }

      // Sort and limit results
      topPerformers.sort((a, b) => (b['attendanceRate'] as int).compareTo(a['attendanceRate'] as int));
      needsAttention.sort((a, b) => (a['attendanceRate'] as int).compareTo(b['attendanceRate'] as int));

      return {
        'totalStudents': totalStudents,
        'totalSessions': totalSessions,
        'averageAttendance': totalSessions > 0 ? (topPerformers.length / totalStudents * 100).round() : 0,
        'topPerformers': topPerformers.take(5).toList(),
        'needsAttention': needsAttention.take(5).toList(),
      };
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'loading faculty attendance summary');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getAdminAttendanceSummary() async {
    try {
      // Get all students
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Student')
          .get();

      // Get all faculty
      final facultySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Faculty')
          .get();

      // Get all classes
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .get();

      int totalSessions = classesSnapshot.docs.length;
      List<Map<String, dynamic>> classStats = [];
      List<Map<String, dynamic>> facultyStats = [];

      // Calculate class statistics
      for (final classDoc in classesSnapshot.docs) {
        final classData = classDoc.data();
        final className = classData['name'] ?? 'Unknown Class';
        final instructorId = classData['instructorId'];

        // Get attendance for this class
        final attendanceSnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .where('classId', isEqualTo: classDoc.id)
            .get();

        final attendanceCount = attendanceSnapshot.docs.length;
        final enrollmentCount = classData['enrolledCount'] ?? 0;
        final attendanceRate = enrollmentCount > 0 ? (attendanceCount / enrollmentCount * 100).round() : 0;

        classStats.add({
          'name': className,
          'attendanceRate': attendanceRate,
          'enrollmentCount': enrollmentCount,
          'attendanceCount': attendanceCount,
        });
      }

      // Calculate faculty statistics
      for (final facultyDoc in facultySnapshot.docs) {
        final facultyData = facultyDoc.data();
        final facultyName = facultyData['name'] ?? 'Unknown Faculty';

        // Get classes taught by this faculty
        final facultyClassesSnapshot = await FirebaseFirestore.instance
            .collection('classes')
            .where('instructorId', isEqualTo: facultyDoc.id)
            .get();

        int totalFacultySessions = facultyClassesSnapshot.docs.length;
        int totalFacultyAttendance = 0;

        for (final classDoc in facultyClassesSnapshot.docs) {
          final attendanceSnapshot = await FirebaseFirestore.instance
              .collection('attendance')
              .where('classId', isEqualTo: classDoc.id)
              .get();
          totalFacultyAttendance += attendanceSnapshot.docs.length;
        }

        final facultyAttendanceRate = totalFacultySessions > 0 ? 
            (totalFacultyAttendance / totalFacultySessions * 100).round() : 0;

        facultyStats.add({
          'name': facultyName,
          'classesCount': totalFacultySessions,
          'attendanceRate': facultyAttendanceRate,
        });
      }

      // Sort results
      classStats.sort((a, b) => (b['attendanceRate'] as int).compareTo(a['attendanceRate'] as int));
      facultyStats.sort((a, b) => (b['attendanceRate'] as int).compareTo(a['attendanceRate'] as int));

      return {
        'totalStudents': studentsSnapshot.docs.length,
        'totalFaculty': facultySnapshot.docs.length,
        'totalSessions': totalSessions,
        'overallAttendance': classStats.isNotEmpty ? 
            (classStats.map((c) => c['attendanceRate'] as int).reduce((a, b) => a + b) / classStats.length).round() : 0,
        'classStats': classStats.take(5).toList(),
        'facultyStats': facultyStats.take(5).toList(),
      };
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'loading admin attendance summary');
      return {};
    }
  }

  // UI Helper methods for summary tabs
  Widget _buildSummaryCardSimple(String title, String value, IconData icon, Color color) {
    return Card(
      color: const Color(0xFF1B1B1B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
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
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFE53935), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCardSimple(Map<String, dynamic> student, {bool isWarning = false}) {
    return Card(
      color: const Color(0xFF1B1B1B),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isWarning ? const Color(0xFFE53935) : const Color(0xFF10B981),
          child: Text(
            student['name'][0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          student['name'],
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          '${student['className']} • ${student['attendanceRate']}% attendance',
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: Icon(
          isWarning ? Icons.warning : Icons.star,
          color: isWarning ? const Color(0xFFE53935) : const Color(0xFFFF9800),
        ),
      ),
    );
  }

  Widget _buildClassStatCard(Map<String, dynamic> classStat) {
    return Card(
      color: const Color(0xFF1B1B1B),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF3B82F6),
          child: Icon(Icons.school, color: Colors.white),
        ),
        title: Text(
          classStat['name'],
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          '${classStat['attendanceCount']}/${classStat['enrollmentCount']} students',
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: Text(
          '${classStat['attendanceRate']}%',
          style: TextStyle(
            color: classStat['attendanceRate'] >= 80 ? const Color(0xFF10B981) : 
                   classStat['attendanceRate'] >= 60 ? const Color(0xFFFF9800) : const Color(0xFFE53935),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFacultyCard(Map<String, dynamic> faculty) {
    return Card(
      color: const Color(0xFF1B1B1B),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF8B5CF6),
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          faculty['name'],
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          '${faculty['classesCount']} classes',
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: Text(
          '${faculty['attendanceRate']}%',
          style: TextStyle(
            color: faculty['attendanceRate'] >= 80 ? const Color(0xFF10B981) : 
                   faculty['attendanceRate'] >= 60 ? const Color(0xFFFF9800) : const Color(0xFFE53935),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _StudentQuickAttendanceSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .orderBy('markedAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final docs = snapshot.data!.docs;
        final total = docs.length;
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Classes attended: $total',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}