import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:async';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/payment_service.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  
  const StudentDetailScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _studentData;
  List<Map<String, dynamic>> _enrollments = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  List<Map<String, dynamic>> _paymentHistory = [];
  Map<DateTime, List<Map<String, dynamic>>> _calendarEvents = {};
  bool _isLoading = true;
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStudentData();
    
    // Listen to payment success events for real-time updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (event['type'] == 'payment_success' && mounted) {
        // Refresh student data when payment succeeds
        _loadStudentData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _paymentRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadStudentData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load student basic data
      final studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .get();
      
      if (studentDoc.exists) {
        _studentData = studentDoc.data();
      }

      // Load enrollments
      await _loadEnrollments();
      
      // Load attendance records
      await _loadAttendanceRecords();
      
      // Load payment history
      await _loadPaymentHistory();
      
      // Process calendar events
      _processCalendarEvents();
      
    } catch (e) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEnrollments() async {
    try {
      
      final enrollmentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .collection('enrollments')
          .orderBy('enrolledAt', descending: true)
          .get();


      _enrollments = enrollmentsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'itemType': data['itemType'] ?? 'class',
          'itemId': data['itemId'] ?? '',
          'itemName': data['itemName'] ?? 'Unknown',
          'status': data['status'] ?? 'enrolled',
          'enrolledAt': data['enrolledAt']?.toDate(),
          'amount': data['amount'] ?? 0,
          'completedSessions': data['completedSessions'] ?? 0,
          'totalSessions': data['totalSessions'] ?? 1,
          'lastSessionAt': data['lastSessionAt']?.toDate(),
        };
      }).toList();
      
    } catch (e) {
    }
  }

  Future<void> _loadAttendanceRecords() async {
    try {
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: widget.studentId)
          .orderBy('markedAt', descending: true)
          .get();

      _attendanceRecords = attendanceSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'classId': data['classId'] ?? '',
          'className': data['className'] ?? 'Unknown Class',
          'markedAt': data['markedAt']?.toDate() ?? DateTime.now(),
          'status': data['status'] ?? 'present',
          'isLate': data['isLate'] ?? false,
          'lateMinutes': data['lateMinutes'] ?? 0,
        };
      }).toList();
    } catch (e) {
    }
  }

  Future<void> _loadPaymentHistory() async {
    try {
      
      // Try the indexed query first
      final paymentsSnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('user_id', isEqualTo: widget.studentId)
          .where('status', isEqualTo: 'success')
          .orderBy('created_at', descending: true)
          .get();


      _paymentHistory = paymentsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'amount': data['amount'] ?? 0,
          'description': data['description'] ?? 'Payment',
          'createdAt': data['created_at']?.toDate() ?? DateTime.now(),
          'paymentType': data['payment_type'] ?? 'class_fee',
        };
      }).toList();
    } catch (e) {
      
      // Fallback: Load all payments and filter client-side
      try {
        final allPaymentsSnapshot = await FirebaseFirestore.instance
            .collection('payments')
            .get();


        _paymentHistory = allPaymentsSnapshot.docs
            .where((doc) {
              final data = doc.data();
              return data['user_id'] == widget.studentId && 
                     data['status'] == 'success';
            })
            .map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'amount': data['amount'] ?? 0,
                'description': data['description'] ?? 'Payment',
                'createdAt': data['created_at']?.toDate() ?? DateTime.now(),
                'paymentType': data['payment_type'] ?? 'class_fee',
              };
            })
            .toList()
          ..sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
          
      } catch (fallbackError) {
        _paymentHistory = [];
      }
    }
  }

  void _processCalendarEvents() {
    _calendarEvents.clear();
    
    // Add attendance records to calendar
    for (final record in _attendanceRecords) {
      final date = record['markedAt'] as DateTime;
      final dateKey = DateTime(date.year, date.month, date.day);
      
      if (_calendarEvents[dateKey] == null) {
        _calendarEvents[dateKey] = [];
      }
      
      _calendarEvents[dateKey]!.add({
        'type': 'attendance',
        'title': record['className'],
        'time': '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
        'status': record['status'],
        'isLate': record['isLate'],
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: widget.studentName,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white70,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Activities'),
            Tab(text: 'Attendance'),
            Tab(text: 'Payments'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white70))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildActivitiesTab(),
                _buildAttendanceTab(),
                _buildPaymentsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    if (_studentData == null) {
      return const Center(child: Text('Student data not found', style: TextStyle(color: Colors.white70)));
    }

    final joinDate = _studentData!['createdAt']?.toDate() ?? DateTime.now();
    final totalSpent = _paymentHistory.fold<double>(0, (sum, payment) => sum + (payment['amount'] as num).toDouble());
    final totalClasses = _enrollments.where((e) => e['itemType'] == 'class').length;
    final totalWorkshops = _enrollments.where((e) => e['itemType'] == 'workshop').length;
    final attendanceRate = _calculateAttendanceRate();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Info Card
          _buildInfoCard(
            'Basic Information',
            [
              _buildInfoRow('Name', _studentData!['name'] ?? 'Unknown'),
              _buildInfoRow('Email', _studentData!['email'] ?? 'Not provided'),
              _buildInfoRow('Phone', _studentData!['phone'] ?? 'Not provided'),
              _buildInfoRow('Level', _studentData!['level'] ?? 'Beginner'),
              _buildInfoRow('Join Date', '${joinDate.day}/${joinDate.month}/${joinDate.year}'),
              _buildInfoRow('Status', _studentData!['isActive'] == true ? 'Active' : 'Inactive'),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Total Spent', '₹${totalSpent.toStringAsFixed(0)}', Icons.payments, Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Classes', totalClasses.toString(), Icons.school, Colors.blue),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Workshops', totalWorkshops.toString(), Icons.event, Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Attendance', '${attendanceRate.toStringAsFixed(0)}%', Icons.trending_up, Colors.purple),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enrollments Section
          _buildSectionCard(
            'Current Enrollments',
            _enrollments.where((e) => e['status'] == 'enrolled').map((enrollment) {
              return _buildActivityItem(
                icon: enrollment['itemType'] == 'class' ? Icons.school : Icons.event,
                title: enrollment['itemName'],
                subtitle: '${enrollment['completedSessions']}/${enrollment['totalSessions']} sessions completed',
                status: enrollment['status'],
                color: enrollment['itemType'] == 'class' ? Colors.blue : Colors.orange,
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Recent Activities
          _buildSectionCard(
            'Recent Activities',
            _attendanceRecords.take(10).map((record) {
              final date = record['markedAt'] as DateTime;
              return _buildActivityItem(
                icon: Icons.qr_code_scanner,
                title: 'Attended ${record['className']}',
                subtitle: '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                status: record['isLate'] ? 'Late' : 'On Time',
                color: record['isLate'] ? Colors.orange : Colors.green,
              );
            }).toList(),
          ),
          
          // Show message if no data
          if (_enrollments.isEmpty && _attendanceRecords.isEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoCard(
              'No Activities Yet',
              [
                const Text(
                  'This student hasn\'t enrolled in any classes or workshops yet.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Activities will appear here once the student:',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text('• Enrolls in a class or workshop', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Text('• Attends their first session', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Text('• Makes their first payment', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
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
          // Calendar
          _buildCalendarCard(),
          
          const SizedBox(height: 16),
          
          // Attendance List
          _buildSectionCard(
            'Attendance History',
            _attendanceRecords.map((record) {
              final date = record['markedAt'] as DateTime;
              return _buildAttendanceItem(
                className: record['className'],
                date: date,
                status: record['status'],
                isLate: record['isLate'],
                lateMinutes: record['lateMinutes'],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment Summary
          _buildInfoCard(
            'Payment Summary',
            [
              _buildInfoRow('Total Paid', '₹${_paymentHistory.fold<double>(0, (sum, p) => sum + (p['amount'] as num).toDouble()).toStringAsFixed(0)}'),
              _buildInfoRow('Total Payments', _paymentHistory.length.toString()),
              _buildInfoRow('Last Payment', _paymentHistory.isNotEmpty ? _formatDate(_paymentHistory.first['createdAt']) : 'None'),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Payment History
          _buildSectionCard(
            'Payment History',
            _paymentHistory.isNotEmpty ? _paymentHistory.map((payment) {
              return _buildPaymentItem(
                amount: payment['amount'],
                description: payment['description'],
                date: payment['createdAt'],
                type: payment['paymentType'],
              );
            }).toList() : [
              const Text(
                'No payment history found for this student.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Payments will appear here once the student makes their first payment.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Card(
      elevation: 6,
      color: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Calendar',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TableCalendar<Map<String, dynamic>>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: DateTime.now(),
              eventLoader: (day) => _calendarEvents[day] ?? [],
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: Colors.white70),
                defaultTextStyle: TextStyle(color: Colors.white),
                todayTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                selectedTextStyle: TextStyle(color: Colors.white),
                selectedDecoration: BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 16),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white70),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white70),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white70),
                weekendStyle: TextStyle(color: Colors.white70),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                // Handle day selection
              },
              selectedDayPredicate: (day) {
                return false; // No specific day selected
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 6,
      color: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      color: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      elevation: 6,
      color: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (children.isEmpty)
              const Text(
                'No data available',
                style: TextStyle(color: Colors.white70),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceItem({
    required String className,
    required DateTime date,
    required String status,
    required bool isLate,
    required int lateMinutes,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  className,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isLate)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${lateMinutes}m late',
                style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem({
    required int amount,
    required String description,
    required DateTime date,
    required String type,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.payments, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  _formatDate(date),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '₹$amount',
            style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  double _calculateAttendanceRate() {
    if (_attendanceRecords.isEmpty) return 0.0;
    
    final totalSessions = _enrollments.fold<int>(0, (sum, e) => sum + (e['totalSessions'] as int));
    final attendedSessions = _attendanceRecords.length;
    
    if (totalSessions == 0) return 0.0;
    return (attendedSessions / totalSessions) * 100;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
