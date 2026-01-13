import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/payment_service.dart';

class ClassHistoryScreen extends StatefulWidget {
  const ClassHistoryScreen({super.key});

  @override
  State<ClassHistoryScreen> createState() => _ClassHistoryScreenState();
}

class _ClassHistoryScreenState extends State<ClassHistoryScreen> {
  List<Map<String, dynamic>> _classHistory = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _loadClassHistory();
    
    // Listen to payment success events for real-time enrollment updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (event['type'] == 'payment_success' && 
          (event['paymentType'] == 'class' || event['paymentType'] == 'class_fee') && mounted) {
        // Refresh class history when class payment succeeds
        _loadClassHistory();
      }
    });
  }

  @override
  void dispose() {
    _paymentRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadClassHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load attendance history
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .get();
      
      // Sort in memory to avoid index requirement
      final attendanceDocs = attendanceSnapshot.docs.toList()
        ..sort((a, b) {
          final aTime = (a.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bTime = (b.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });

      // Load enrollment history
      final enrollmentSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('enrollments')
          .orderBy('ts', descending: true)
          .get();

      List<Map<String, dynamic>> history = [];

      // Process attendance records
      for (final doc in attendanceDocs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        
        if (timestamp != null) {
          history.add({
            'type': 'attendance',
            'id': doc.id,
            'className': data['className'] ?? 'Unknown Class',
            'instructor': data['instructor'] ?? 'Unknown',
            'timestamp': timestamp,
            'status': data['status'] ?? 'present',
            'isLate': data['isLate'] ?? false,
            'itemType': 'class',
          });
        }
      }

      // Process enrollment records (only classes and workshops, not studio bookings)
      for (final doc in enrollmentSnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['ts'] as Timestamp?)?.toDate();
        final itemType = data['itemType'] ?? 'class';
        
        // Only include classes and workshops, exclude studio bookings
        if (timestamp != null && (itemType == 'class' || itemType == 'workshop')) {
          history.add({
            'type': 'enrollment',
            'id': doc.id,
            'className': data['title'] ?? 'Unknown',
            'instructor': data['instructor'] ?? 'Unknown',
            'timestamp': timestamp,
            'status': data['status'] ?? 'enrolled',
            'itemType': itemType,
            'amount': data['amount'] ?? 0,
          });
        }
      }

      // Sort by timestamp
      history.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

      setState(() {
        _classHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredHistory {
    if (_selectedFilter == 'all') return _classHistory;
    
    return _classHistory.where((record) {
      switch (_selectedFilter) {
        case 'attendance':
          return record['type'] == 'attendance';
        case 'enrollment':
          return record['type'] == 'enrollment';
        case 'classes':
          return record['itemType'] == 'class';
        case 'workshops':
          return record['itemType'] == 'workshop';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Class History',
        leading: const SizedBox.shrink(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : Column(
              children: [
                _buildFilters(),
                _buildStats(),
                _buildHistoryList(),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.all(16),
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
            'Filter History',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Attendance', 'attendance'),
                const SizedBox(width: 8),
                _buildFilterChip('Enrollments', 'enrollment'),
                const SizedBox(width: 8),
                _buildFilterChip('Classes', 'classes'),
                const SizedBox(width: 8),
                _buildFilterChip('Workshops', 'workshops'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: const Color(0xFFE53935).withOpacity(0.2),
      checkmarkColor: const Color(0xFFE53935),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFFE53935) : Colors.white70,
      ),
    );
  }

  Widget _buildStats() {
    final filteredHistory = _filteredHistory;
    final attendanceCount = filteredHistory.where((r) => r['type'] == 'attendance').length;
    final enrollmentCount = filteredHistory.where((r) => r['type'] == 'enrollment').length;
    final classCount = filteredHistory.where((r) => r['itemType'] == 'class').length;
    final workshopCount = filteredHistory.where((r) => r['itemType'] == 'workshop').length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard('Attendance', attendanceCount.toString(), Colors.green),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard('Enrollments', enrollmentCount.toString(), Colors.blue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard('Classes', classCount.toString(), Colors.orange),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard('Workshops', workshopCount.toString(), Colors.purple),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    final filteredHistory = _filteredHistory;
    
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'History (${filteredHistory.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _getDateRange(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredHistory.isEmpty
                  ? const Center(
                      child: Text(
                        'No history found',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredHistory.length,
                      itemBuilder: (context, index) {
                        final record = filteredHistory[index];
                        return _buildHistoryCard(record);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> record) {
    final timestamp = record['timestamp'] as DateTime;
    final isAttendance = record['type'] == 'attendance';
    final isLate = record['isLate'] ?? false;
    final status = record['status'] as String;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getCardColor(record),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getBorderColor(record)),
      ),
      child: Row(
        children: [
          Icon(
            _getIcon(record),
            color: _getIconColor(record),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['className'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${record['instructor']} • ${_formatDate(timestamp)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                if (isAttendance) ...[
                  Row(
                    children: [
                      Text(
                        status == 'present' ? (isLate ? 'Late' : 'Present') : 'Absent',
                        style: TextStyle(
                          color: status == 'present' 
                              ? (isLate ? Colors.orange : Colors.green)
                              : Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(timestamp),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Text(
                        'Enrolled',
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (record['amount'] != null)
                        Text(
                          '₹${record['amount']}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
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
    );
  }

  Color _getCardColor(Map<String, dynamic> record) {
    if (record['type'] == 'attendance') {
      final status = record['status'] as String;
      if (status == 'present') {
        return record['isLate'] == true 
            ? Colors.orange.withOpacity(0.1)
            : Colors.green.withOpacity(0.1);
      } else {
        return Colors.red.withOpacity(0.1);
      }
    } else {
      return Colors.blue.withOpacity(0.1);
    }
  }

  Color _getBorderColor(Map<String, dynamic> record) {
    if (record['type'] == 'attendance') {
      final status = record['status'] as String;
      if (status == 'present') {
        return record['isLate'] == true 
            ? Colors.orange.withOpacity(0.3)
            : Colors.green.withOpacity(0.3);
      } else {
        return Colors.red.withOpacity(0.3);
      }
    } else {
      return Colors.blue.withOpacity(0.3);
    }
  }

  IconData _getIcon(Map<String, dynamic> record) {
    if (record['type'] == 'attendance') {
      final status = record['status'] as String;
      if (status == 'present') {
        return record['isLate'] == true ? Icons.schedule : Icons.check_circle;
      } else {
        return Icons.cancel;
      }
    } else {
      return Icons.school;
    }
  }

  Color _getIconColor(Map<String, dynamic> record) {
    if (record['type'] == 'attendance') {
      final status = record['status'] as String;
      if (status == 'present') {
        return record['isLate'] == true ? Colors.orange : Colors.green;
      } else {
        return Colors.red;
      }
    } else {
      return Colors.blue;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'enrolled':
        return Colors.green;
      case 'expired':
        return Colors.red;
      case 'cancelled':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getDateRange() {
    if (_classHistory.isEmpty) return 'No data';
    
    final first = _classHistory.last['timestamp'] as DateTime;
    final last = _classHistory.first['timestamp'] as DateTime;
    
    return '${_formatDate(first)} - ${_formatDate(last)}';
  }
}
