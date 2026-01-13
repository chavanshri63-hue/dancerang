import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class LiveMetricsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Track pending updates to prevent race conditions
  static final Set<String> _pendingUpdates = <String>{};

  /// Get live enrollment metrics
  static Stream<Map<String, dynamic>> getLiveEnrollmentMetrics() {
    return _firestore
        .collection('classes')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      int totalEnrollments = 0;
      int totalCapacity = 0;
      int fullyBooked = 0;
      int lowEnrollment = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final maxStudents = data['maxStudents'] ?? 20;
        final currentBookings = data['currentBookings'] ?? data['enrolledCount'] ?? 0;
        
        // If currentBookings is 0, try to get actual enrollment count from enrolments collection
        int actualEnrollments = currentBookings as int;
        if (actualEnrollments == 0) {
          final docId = doc.id;
          // Prevent concurrent updates for same document
          if (!_pendingUpdates.contains(docId)) {
            _pendingUpdates.add(docId);
            try {
              final enrollmentSnapshot = await _firestore
                  .collection('enrollments')
                  .where('itemId', isEqualTo: docId)
                  .where('status', isEqualTo: 'enrolled')
                  .where('itemType', isEqualTo: 'class')
                  .get();
              actualEnrollments = enrollmentSnapshot.docs.length;
              
              // Update the class document with actual enrollment count (only if still 0 to avoid race)
              if (actualEnrollments > 0) {
                await _firestore.collection('classes').doc(docId).update({
                  'currentBookings': actualEnrollments,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error updating enrollment count for class ${docId}: $e');
              }
            } finally {
              _pendingUpdates.remove(docId);
            }
          }
        }
        
        totalEnrollments += actualEnrollments;
        totalCapacity += maxStudents as int;
        
        if (actualEnrollments >= maxStudents) {
          fullyBooked++;
        } else if (actualEnrollments < (maxStudents * 0.3)) {
          lowEnrollment++;
        }
      }

      return {
        'totalEnrollments': totalEnrollments,
        'totalCapacity': totalCapacity,
        'occupancyRate': totalCapacity > 0 ? (totalEnrollments / totalCapacity * 100).round() : 0,
        'fullyBooked': fullyBooked,
        'lowEnrollment': lowEnrollment,
        'availableSpots': totalCapacity - totalEnrollments,
      };
    });
  }

  /// Get live revenue metrics
  static Stream<Map<String, dynamic>> getLiveRevenueMetrics() {
    return _firestore
        .collection('payments')
        .where('status', isEqualTo: 'success')
        .snapshots()
        .map((snapshot) {
      int totalRevenue = 0;
      int todayRevenue = 0;
      int thisWeekRevenue = 0;
      int thisMonthRevenue = 0;
      int totalTransactions = snapshot.docs.length;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final amount = data['amount'] ?? 0;
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? 
                         (data['created_at'] as Timestamp?)?.toDate() ?? now;
        
        totalRevenue += amount as int;
        
        if (timestamp.isAfter(todayStart)) {
          todayRevenue += amount as int;
        }
        if (timestamp.isAfter(weekStart)) {
          thisWeekRevenue += amount as int;
        }
        if (timestamp.isAfter(monthStart)) {
          thisMonthRevenue += amount as int;
        }
      }

      return {
        'totalRevenue': totalRevenue,
        'todayRevenue': todayRevenue,
        'thisWeekRevenue': thisWeekRevenue,
        'thisMonthRevenue': thisMonthRevenue,
        'totalTransactions': totalTransactions,
        'averagePayment': totalTransactions > 0 ? (totalRevenue / totalTransactions).round() : 0,
      };
    });
  }

  /// Get live class performance metrics
  static Stream<List<Map<String, dynamic>>> getLiveClassPerformance() {
    return _firestore
        .collection('classes')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final maxStudents = data['maxStudents'] ?? 20;
        final currentBookings = data['currentBookings'] ?? data['enrolledCount'] ?? 0;
        final occupancyRate = maxStudents > 0 ? (currentBookings / maxStudents * 100).round() : 0;
        
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Class',
          'instructor': data['instructor'] ?? AppConfig.defaultInstructor,
          'category': data['category'] ?? AppConfig.defaultCategory,
          'currentBookings': currentBookings,
          'maxStudents': maxStudents,
          'occupancyRate': occupancyRate,
          'availableSpots': maxStudents - currentBookings,
          'isFullyBooked': currentBookings >= maxStudents,
          'isLowEnrollment': currentBookings < (maxStudents * 0.3),
        };
      }).toList();
    });
  }

  /// Get live workshop metrics
  static Stream<Map<String, dynamic>> getLiveWorkshopMetrics() {
    return _firestore
        .collection('workshops')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      int totalEnrollments = 0;
      int totalCapacity = 0;
      int fullyBooked = 0;
      int lowEnrollment = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final maxParticipants = data['maxParticipants'] ?? 20;
        final currentParticipants = data['currentParticipants'] ?? data['enrolledCount'] ?? 0;
        
        totalEnrollments += currentParticipants as int;
        totalCapacity += maxParticipants as int;
        
        if (currentParticipants >= maxParticipants) {
          fullyBooked++;
        } else if (currentParticipants < (maxParticipants * 0.3)) {
          lowEnrollment++;
        }
      }

      return {
        'totalEnrollments': totalEnrollments,
        'totalCapacity': totalCapacity,
        'occupancyRate': totalCapacity > 0 ? (totalEnrollments / totalCapacity * 100).round() : 0,
        'fullyBooked': fullyBooked,
        'lowEnrollment': lowEnrollment,
        'availableSpots': totalCapacity - totalEnrollments,
        'totalWorkshops': snapshot.docs.length,
      };
    });
  }

  /// Get live user activity metrics
  static Stream<Map<String, dynamic>> getLiveUserActivity() {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snapshot) {
      int totalUsers = snapshot.docs.length;
      int activeUsers = 0;
      int newUsersToday = 0;
      int newUsersThisWeek = 0;
      int studentUsers = 0;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final lastActive = (data['lastActive'] as Timestamp?)?.toDate();
        final role = (data['role'] ?? '').toString().toLowerCase();
        
        // Count students specifically
        if (role == 'student') {
          studentUsers++;
        }
        
        if (createdAt != null) {
          if (createdAt.isAfter(todayStart)) {
            newUsersToday++;
          }
          if (createdAt.isAfter(weekStart)) {
            newUsersThisWeek++;
          }
        }
        
        if (lastActive != null && lastActive.isAfter(now.subtract(const Duration(days: 7)))) {
          activeUsers++;
        }
      }

      return {
        'totalUsers': totalUsers,
        'studentUsers': studentUsers,
        'activeUsers': activeUsers,
        'newUsersToday': newUsersToday,
        'newUsersThisWeek': newUsersThisWeek,
        'activityRate': totalUsers > 0 ? (activeUsers / totalUsers * 100).round() : 0,
      };
    });
  }

  /// Get live system alerts
  static Stream<List<Map<String, dynamic>>> getLiveSystemAlerts() {
    return _firestore
        .collection('classes')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      List<Map<String, dynamic>> alerts = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] ?? 'Unknown Class';
        final maxStudents = data['maxStudents'] ?? 20;
        final currentBookings = data['currentBookings'] ?? data['enrolledCount'] ?? 0;
        final availableSpots = maxStudents - currentBookings;
        
        if (availableSpots <= 2 && availableSpots > 0) {
          alerts.add({
            'type': 'low_spots',
            'title': 'Low Spots Alert',
            'message': '"$name" has only $availableSpots spots left',
            'classId': doc.id,
            'priority': 'high',
            'timestamp': DateTime.now(),
          });
        } else if (currentBookings < (maxStudents * 0.3)) {
          alerts.add({
            'type': 'low_enrollment',
            'title': 'Low Enrollment Alert',
            'message': '"$name" has low enrollment (${currentBookings}/${maxStudents})',
            'classId': doc.id,
            'priority': 'medium',
            'timestamp': DateTime.now(),
          });
        }
      }

      return alerts;
    });
  }
}

/// Live Metrics Dashboard Widget
class LiveMetricsDashboard extends StatelessWidget {
  const LiveMetricsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Live Metrics Dashboard'),
        backgroundColor: const Color(0xFF1B1B1B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              // Refresh metrics
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enrollment Metrics
            _buildMetricsCard(
              title: 'Live Enrollment Metrics',
              child: StreamBuilder<Map<String, dynamic>>(
                stream: LiveMetricsService.getLiveEnrollmentMetrics(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final metrics = snapshot.data!;
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricItem('Total Enrollments', metrics['totalEnrollments'].toString(), Colors.blue),
                          _buildMetricItem('Occupancy Rate', '${metrics['occupancyRate']}%', Colors.green),
                          _buildMetricItem('Available Spots', metrics['availableSpots'].toString(), Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricItem('Fully Booked', metrics['fullyBooked'].toString(), Colors.red),
                          _buildMetricItem('Low Enrollment', metrics['lowEnrollment'].toString(), Colors.yellow),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Revenue Metrics
            _buildMetricsCard(
              title: 'Live Revenue Metrics',
              child: StreamBuilder<Map<String, dynamic>>(
                stream: LiveMetricsService.getLiveRevenueMetrics(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final metrics = snapshot.data!;
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricItem('Today', '₹${metrics['todayRevenue']}', Colors.green),
                          _buildMetricItem('This Week', '₹${metrics['thisWeekRevenue']}', Colors.blue),
                          _buildMetricItem('This Month', '₹${metrics['thisMonthRevenue']}', Colors.purple),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricItem('Total Revenue', '₹${metrics['totalRevenue']}', Colors.orange),
                          _buildMetricItem('Transactions', metrics['totalTransactions'].toString(), Colors.cyan),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // User Activity Metrics
            _buildMetricsCard(
              title: 'Live User Activity',
              child: StreamBuilder<Map<String, dynamic>>(
                stream: LiveMetricsService.getLiveUserActivity(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final metrics = snapshot.data!;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem('Total Users', metrics['totalUsers'].toString(), Colors.blue),
                      _buildMetricItem('Active Users', metrics['activeUsers'].toString(), Colors.green),
                      _buildMetricItem('New Today', metrics['newUsersToday'].toString(), Colors.orange),
                    ],
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // System Alerts
            _buildMetricsCard(
              title: 'Live System Alerts',
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: LiveMetricsService.getLiveSystemAlerts(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final alerts = snapshot.data!;
                  
                  if (alerts.isEmpty) {
                    return const Center(
                      child: Text(
                        'No alerts at the moment',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }
                  
                  return Column(
                    children: alerts.take(5).map((alert) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: alert['priority'] == 'high' 
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: alert['priority'] == 'high' ? Colors.red : Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            alert['priority'] == 'high' ? Icons.warning : Icons.info,
                            color: alert['priority'] == 'high' ? Colors.red : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alert['title'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  alert['message'],
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
