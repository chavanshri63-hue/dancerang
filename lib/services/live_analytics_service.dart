import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config/app_config.dart';

class LiveAnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get trending classes based on recent enrollments
  static Stream<List<Map<String, dynamic>>> getTrendingClasses() {
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
        
        // Calculate trend score based on occupancy rate and recent activity
        final trendScore = _calculateTrendScore(data, currentBookings, maxStudents);
        
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Class',
          'instructor': data['instructor'] ?? 'Unknown',
          'category': data['category'] ?? 'General',
          'currentBookings': currentBookings,
          'maxStudents': maxStudents,
          'occupancyRate': occupancyRate,
          'trendScore': trendScore,
          'imageUrl': data['imageUrl'] ?? '',
          'level': data['level'] ?? AppConfig.defaultLevel,
          'price': data['price'] ?? AppConfig.defaultPrice,
        };
      }).toList()
        ..sort((a, b) => b['trendScore'].compareTo(a['trendScore']));
    });
  }

  /// Get trending workshops
  static Stream<List<Map<String, dynamic>>> getTrendingWorkshops() {
    return _firestore
        .collection('workshops')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final maxParticipants = data['maxParticipants'] ?? 20;
        final currentParticipants = data['currentParticipants'] ?? data['enrolledCount'] ?? 0;
        final occupancyRate = maxParticipants > 0 ? (currentParticipants / maxParticipants * 100).round() : 0;
        
        final trendScore = _calculateTrendScore(data, currentParticipants, maxParticipants);
        
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Unknown Workshop',
          'instructor': data['instructor'] ?? 'Unknown',
          'category': data['category'] ?? 'General',
          'currentParticipants': currentParticipants,
          'maxParticipants': maxParticipants,
          'occupancyRate': occupancyRate,
          'trendScore': trendScore,
          'imageUrl': data['imageUrl'] ?? '',
          'level': data['level'] ?? 'All Levels',
          'price': data['price'] ?? 0,
          'date': data['date'] ?? 'TBA',
          'time': data['time'] ?? 'TBA',
        };
      }).toList()
        ..sort((a, b) => b['trendScore'].compareTo(a['trendScore']));
    });
  }

  /// Calculate trend score for an item
  static double _calculateTrendScore(Map<String, dynamic> data, int currentEnrollments, int maxCapacity) {
    final occupancyRate = maxCapacity > 0 ? (currentEnrollments / maxCapacity) : 0;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
    
    // Base score from occupancy rate
    double score = occupancyRate * 100;
    
    // Bonus for recent activity
    if (updatedAt != null) {
      final hoursSinceUpdate = DateTime.now().difference(updatedAt).inHours;
      if (hoursSinceUpdate < 24) {
        score += 20; // Recent activity bonus
      }
    }
    
    // Bonus for new items
    if (createdAt != null) {
      final daysSinceCreation = DateTime.now().difference(createdAt).inDays;
      if (daysSinceCreation < 7) {
        score += 30; // New item bonus
      }
    }
    
    // Category popularity bonus
    final category = data['category'] ?? '';
    switch (category.toLowerCase()) {
      case 'hip hop':
        score += 15;
        break;
      case 'bollywood':
        score += 10;
        break;
      case 'contemporary':
        score += 12;
        break;
      case 'salsa':
        score += 8;
        break;
    }
    
    return score;
  }

  /// Get popular categories
  static Stream<List<Map<String, dynamic>>> getPopularCategories() {
    return _firestore
        .collection('classes')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      Map<String, Map<String, dynamic>> categoryStats = {};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] ?? 'General';
        final currentBookings = data['currentBookings'] ?? data['enrolledCount'] ?? 0;
        
        if (!categoryStats.containsKey(category)) {
          categoryStats[category] = {
            'category': category,
            'totalEnrollments': 0,
            'totalClasses': 0,
            'averageOccupancy': 0,
          };
        }
        
        categoryStats[category]!['totalEnrollments'] += currentBookings;
        categoryStats[category]!['totalClasses'] += 1;
      }
      
      // Calculate average occupancy for each category
      categoryStats.forEach((category, stats) {
        final totalClasses = stats['totalClasses'] as int;
        if (totalClasses > 0) {
          stats['averageOccupancy'] = (stats['totalEnrollments'] as int) / totalClasses;
        }
      });
      
      return categoryStats.values.toList()
        ..sort((a, b) => (b['totalEnrollments'] as int).compareTo(a['totalEnrollments'] as int));
    });
  }

  /// Get user engagement analytics
  static Stream<Map<String, dynamic>> getUserEngagementAnalytics() {
    return _firestore
        .collection('users')
        .snapshots()
        .asyncMap((snapshot) async {
      int totalUsers = snapshot.docs.length;
      int activeUsers = 0;
      int enrolledUsers = 0;
      int newUsersToday = 0;
      int newUsersThisWeek = 0;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final lastActive = (data['lastActive'] as Timestamp?)?.toDate();
        
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

      // Check enrolled users
      final enrollmentSnapshot = await _firestore
          .collection('users')
          .where('enrollments', isNull: false)
          .get();
      
      enrolledUsers = enrollmentSnapshot.docs.length;
      
      return {
        'totalUsers': totalUsers,
        'activeUsers': activeUsers,
        'enrolledUsers': enrolledUsers,
        'newUsersToday': newUsersToday,
        'newUsersThisWeek': newUsersThisWeek,
        'activityRate': totalUsers > 0 ? (activeUsers / totalUsers * 100).round() : 0,
        'enrollmentRate': totalUsers > 0 ? (enrolledUsers / totalUsers * 100).round() : 0,
      };
    });
  }

  /// Get revenue analytics
  static Stream<Map<String, dynamic>> getRevenueAnalytics() {
    return _firestore
        .collection('payments')
        .where('status', isEqualTo: 'paid')
        .snapshots()
        .map((snapshot) {
      int totalRevenue = 0;
      int todayRevenue = 0;
      int thisWeekRevenue = 0;
      int thisMonthRevenue = 0;
      Map<String, int> categoryRevenue = {};

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final amount = data['amount'] ?? 0;
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? now;
        final itemType = data['itemType'] ?? 'class';
        
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
        
        // Track revenue by category
        if (!categoryRevenue.containsKey(itemType)) {
          categoryRevenue[itemType] = 0;
        }
        categoryRevenue[itemType] = categoryRevenue[itemType]! + (amount as int);
      }

      return {
        'totalRevenue': totalRevenue,
        'todayRevenue': todayRevenue,
        'thisWeekRevenue': thisWeekRevenue,
        'thisMonthRevenue': thisMonthRevenue,
        'categoryRevenue': categoryRevenue,
        'totalTransactions': snapshot.docs.length,
        'averageTransaction': snapshot.docs.length > 0 ? (totalRevenue / snapshot.docs.length).round() : 0,
      };
    });
  }

  /// Get class performance analytics
  static Stream<List<Map<String, dynamic>>> getClassPerformanceAnalytics() {
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
          'instructor': data['instructor'] ?? 'Unknown',
          'category': data['category'] ?? 'General',
          'currentBookings': currentBookings,
          'maxStudents': maxStudents,
          'occupancyRate': occupancyRate,
          'performance': _getPerformanceRating(occupancyRate),
          'trend': _getTrendDirection(data),
        };
      }).toList()
        ..sort((a, b) => b['occupancyRate'].compareTo(a['occupancyRate']));
    });
  }

  static String _getPerformanceRating(int occupancyRate) {
    if (occupancyRate >= 90) return 'Excellent';
    if (occupancyRate >= 70) return 'Good';
    if (occupancyRate >= 50) return 'Average';
    if (occupancyRate >= 30) return 'Below Average';
    return 'Poor';
  }

  static String _getTrendDirection(Map<String, dynamic> data) {
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
    if (updatedAt == null) return 'Stable';
    
    final hoursSinceUpdate = DateTime.now().difference(updatedAt).inHours;
    if (hoursSinceUpdate < 24) return 'Rising';
    if (hoursSinceUpdate < 168) return 'Stable';
    return 'Declining';
  }
}

/// Trending Classes Widget
class TrendingClassesWidget extends StatelessWidget {
  const TrendingClassesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔥 Trending Classes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: LiveAnalyticsService.getTrendingClasses(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final trendingClasses = snapshot.data!.take(3).toList();
              
              return Column(
                children: trendingClasses.map((classData) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.trending_up,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              classData['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'by ${classData['instructor']}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${classData['occupancyRate']}% full • ${classData['category']}',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${classData['trendScore'].round()}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Popular Categories Widget
class PopularCategoriesWidget extends StatelessWidget {
  const PopularCategoriesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Popular Categories',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: LiveAnalyticsService.getPopularCategories(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final categories = snapshot.data!.take(5).toList();
              
              return Column(
                children: categories.map((category) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category['category'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${category['totalEnrollments']} enrollments',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${category['totalClasses']} classes',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
