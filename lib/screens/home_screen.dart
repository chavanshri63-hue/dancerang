import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'revenue_details_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/subscription_renewal_service.dart';
import '../widgets/glassmorphism_app_bar.dart';
import '../models/class_model.dart';
import '../services/payment_service.dart';
import '../services/iap_service.dart';
import '../services/online_subscription_service.dart';
import '../widgets/payment_option_dialog.dart';
import 'add_edit_class_screen.dart';
import '../services/admin_service.dart';
import '../services/dance_styles_service.dart';
import '../services/branches_service.dart';
import '../models/banner_model.dart';
import '../services/event_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_config_service.dart';
import '../config/demo_session.dart';
// import 'my_classes_screen.dart'; // Deleted file
import 'attendance_screen.dart';
import 'qr_display_screen.dart';
import 'qr_scanner_screen.dart';
import 'student_profile_screen.dart';
import 'admin_live_dashboard.dart';
import 'profile_screen.dart';
import 'my_workshops_screen.dart';
import 'payment_reminder_screen.dart';
import 'payment_history_screen.dart';
import 'student_management_screen.dart';
import 'notifications_screen.dart';
import 'admin_approvals_screen.dart';
import 'updates_screen.dart';
import 'admin_classes_management_screen.dart';
import 'event_choreography_screen.dart';
import 'gallery_screen.dart';
import 'about_us_screen.dart';
import 'studio_availability_calendar.dart';
import '../services/class_service.dart' as cls;
import '../services/admin_students_service.dart';
import 'subscription_plans_screen.dart';
import 'video_player_screen.dart';
import 'style_video_screen.dart';
import 'video_search_screen.dart';
import 'user_progress_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'live_streaming_screen.dart';
import 'ai_recommendations_screen.dart';
import 'offline_downloads_screen.dart';
import 'single_class_booking_screen.dart';
import 'package_booking_screen.dart';
import '../models/class_enrollment_model.dart';
import '../services/live_notification_service.dart';
import '../services/class_enrollment_service.dart';
import '../services/branches_service.dart';

// Skeleton while loading home content
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) {
    Color base = Colors.white.withValues(alpha: 0.08);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner loading skeleton
        Container(height: 280, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(16))),
        const SizedBox(height: 16),
        // Welcome card loading skeleton
        Container(height: 90, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(16))),
        const SizedBox(height: 16),
        // Quick actions loading skeleton
        Row(
          children: List.generate(4, (i) => Expanded(
            child: Container(height: 80, margin: EdgeInsets.only(right: i<3?8:0), decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(12))),
          )),
        ),
      ],
    );
  }
}

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
 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _backgroundImageUrl;

  List<Widget> get _screens => [
    HomeTab(backgroundImageUrl: _backgroundImageUrl),
    const ClassesTab(),
    const StudioTab(),
    const OnlineTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadBackgroundImage();
  }

  Future<void> _loadBackgroundImage() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('backgroundImages')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _backgroundImageUrl = data['homeScreen'] as String?;
          });
        }
      } else {
        // Set default dance background image
        if (mounted) {
          setState(() {
            _backgroundImageUrl = 'https://images.unsplash.com/photo-1508700929628-666bc8bd84ea?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80';
          });
        }
      }
    } catch (e) {
      // Set default dance background image on error
      if (mounted) {
        setState(() {
          _backgroundImageUrl = 'https://images.unsplash.com/photo-1508700929628-666bc8bd84ea?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80';
        });
      }
    }
  }

  Future<void> _initializeNotifications() async {
    // Notification system disabled
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.white, // White for selected
        unselectedItemColor: Colors.white70,
        selectedLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
        unselectedLabelStyle: const TextStyle(
          color: Colors.grey,
          fontSize: 10,
        ),
        items: [
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _currentIndex == 0 ? const Color(0xFFE53935) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.home_rounded, size: 20),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _currentIndex == 1 ? const Color(0xFFE53935) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.directions_run, size: 20),
            ),
            label: 'Classes',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _currentIndex == 2 ? const Color(0xFFE53935) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.apartment_rounded, size: 20),
            ),
            label: 'Studio',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _currentIndex == 3 ? const Color(0xFFE53935) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.play_circle_rounded, size: 20),
            ),
            label: 'Online',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _currentIndex == 4 ? const Color(0xFFE53935) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person_rounded, size: 20),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
// About Us Card Widget
class _AboutUsCard extends StatelessWidget {
  const _AboutUsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 6,
      shadowColor: const Color(0xFFE53935).withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFFE53935).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AboutUsScreen(),
            ),
          );
        },
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
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded, 
                    color: Color(0xFFE53935), 
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About DanceRang', 
                        style: TextStyle(
                          color: Color(0xFFE53935), 
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Meet our founders and learn about our journey',
                        style: TextStyle(
                          color: Color(0xFFF9FAFB), 
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFFE53935),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutUsLink extends StatelessWidget {
  const _AboutUsLink();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AboutUsScreen()),
          );
        },
        icon: const Icon(Icons.groups_2_outlined, color: Color(0xFFE53935), size: 22),
        label: const Text(
          'About us',
          style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w700, fontSize: 16),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          foregroundColor: const Color(0xFFE53935),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: const Size(0, 0),
        ),
      ),
    );
  }
}

class _AboutGradientMiniCard extends StatelessWidget {
  const _AboutGradientMiniCard();
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AboutUsScreen()),
        );
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.auto_awesome, color: Color(0xFFE53935), size: 20),
            const SizedBox(width: 10),
            const Text(
              'About DanceRang',
              style: TextStyle(
                color: Color(0xFFF9FAFB),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

// Role-based additional enhancements section with real-time data
class _RoleEnhancements extends StatelessWidget {
  final String role; // 'student' | 'faculty' | 'admin'
  final String? userId;
  const _RoleEnhancements({required this.role, this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_EnhanceData>(
      future: _loadEnhance(role: role, userId: userId),
      builder: (context, snap) {
        final data = snap.data;
        final List<Widget> items = role.toLowerCase() == 'admin'
            ? _adminItems(context, data)
            : role.toLowerCase() == 'faculty'
                ? _facultyItems(context, data)
                : _studentItems(context, data);

        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Highlights',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF9FAFB),
              ),
            ),
            const SizedBox(height: 12),
            ...items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)),
          ],
        );
      },
    );
  }

  List<Widget> _studentItems(BuildContext context, _EnhanceData? data) {
    return [
      _smallStatRow([
        _miniStat(context, Icons.local_fire_department, 'Streak', data?.streak ?? '—', Colors.orange),
        _miniStat(context, Icons.percent, 'Attendance', data?.attendancePercent ?? '—', const Color(0xFF42A5F5)),
      ]),
      // Practice Assignments and Recommended For You removed as requested
    ];
  }

  List<Widget> _facultyItems(BuildContext context, _EnhanceData? data) {
    return [
      _infoCard(
        context,
        icon: Icons.pending_actions,
        title: 'Pending Attendance',
        subtitle: data == null ? '—' : '${data.pendingAttendance} classes need completion',
        actionText: 'Complete',
      ),
      _smallStatRow([
        _miniStat(context, Icons.person_off, 'No-shows', data?.noShowPercent ?? '—', Colors.orange),
        _miniStat(context, Icons.timer, 'Late', data?.latePercent ?? '—', const Color(0xFFFFB300)),
      ]),
      _listCard(
        context,
        icon: Icons.rule_folder_outlined,
        title: 'Pending Approvals',
        items: data?.approvals ?? const [],
        onTap: () => _showApprovalsScreen(context),
      ),
    ];
  }

  List<Widget> _adminItems(BuildContext context, _EnhanceData? data) {
    return [
      _smallStatRow([
        _miniStat(context, Icons.people, 'Occupancy', data?.occupancyPercent ?? '—', const Color(0xFF42A5F5)),
      ]),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('payments')
            .where('status', whereIn: ['success', 'paid'])
            .snapshots(),
        builder: (context, snapshot) {
          final now = DateTime.now();
          final startOfMonth = DateTime(now.year, now.month, 1);
          double totalRevenue = 0;
          for (final doc in snapshot.data?.docs ?? []) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = (data['created_at'] ?? data['createdAt'] ?? data['updated_at']);
            if (ts is Timestamp) {
              final dt = ts.toDate();
              if (!dt.isAfter(startOfMonth)) {
                continue;
              }
            }
            totalRevenue += (data['amount'] ?? 0).toDouble();
          }
          final value = '₹${totalRevenue.toStringAsFixed(0)}';
          return _infoCard(
            context,
            icon: Icons.currency_rupee,
            title: 'Revenue (MTD)',
            subtitle: value,
            actionText: 'Details',
            onAction: () => _showRevenueDetails(context),
          );
        },
      ),
      _listCard(
        context,
        icon: Icons.warning_amber_rounded,
        title: 'Risks & Alerts',
        items: data?.risks ?? const [],
      ),
      _listCard(
        context,
        icon: Icons.rule_folder_outlined,
        title: 'Pending Approvals',
        items: data?.approvals ?? const [],
        onTap: () => _showApprovalsScreen(context),
      ),
    ];
  }

  void _showRevenueDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RevenueDetailsScreen()),
    );
  }

  Widget _miniStat(BuildContext context, IconData icon, String label, String value, Color color) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(color: Color(0xFFF9FAFB), fontWeight: FontWeight.bold)),
                  Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallStatRow(List<Widget> children) {
    return Row(children: [
      ...children.asMap().entries.map((e) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: e.key == children.length - 1 ? 0 : 8),
              child: e.value,
            ),
          )),
    ]);
  }

  Widget _infoCard(BuildContext context, {required IconData icon, required String title, String? subtitle, String? actionText, VoidCallback? onAction}) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFE53935)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Color(0xFFF9FAFB), fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                ],
              ),
            ),
            if (actionText != null)
              TextButton(
                onPressed: onAction ?? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(actionText), behavior: SnackBarBehavior.floating),
                  );
                },
                child: Text(actionText),
              ),
          ],
        ),
      ),
    );
  }

  Widget _listCard(BuildContext context, {required IconData icon, required String title, required List<String> items, VoidCallback? onTap}) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.25)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: const Color(0xFFE53935), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title, style: const TextStyle(color: Color(0xFFF9FAFB), fontWeight: FontWeight.w600)),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right, size: 20, color: Colors.white38),
                ],
              ),
              const SizedBox(height: 8),
              ...items.map((t) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.chevron_right, size: 16, color: Colors.white38),
                        const SizedBox(width: 4),
                        Expanded(child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showApprovalsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminApprovalsScreen()),
    );
  }
}

class _EnhanceData {
  final String? attendancePercent; // student
  final String? streak; // student
  final String? nextPaymentDue; // student
  final List<String>? assignments; // student
  final String? progressSnapshot; // student
  final List<String>? recommended; // student

  final String? noShowPercent; // faculty
  final String? latePercent; // faculty
  final int? pendingAttendance; // faculty
  final List<String>? needsAttention; // faculty

  final String? todaysClasses; // admin
  final String? occupancyPercent; // admin
  final String? revenueMTD; // admin
  final List<String>? risks; // admin
  final List<String>? approvals; // admin/faculty
  final String? staffCompliance; // admin

  const _EnhanceData({
    this.attendancePercent,
    this.streak,
    this.nextPaymentDue,
    this.assignments,
    this.progressSnapshot,
    this.recommended,
    this.noShowPercent,
    this.latePercent,
    this.pendingAttendance,
    this.needsAttention,
    this.approvals,
    this.todaysClasses,
    this.occupancyPercent,
    this.revenueMTD,
    this.risks,
    this.staffCompliance,
  });

  _EnhanceData copyWith({
    String? attendancePercent,
    String? streak,
    String? nextPaymentDue,
    List<String>? assignments,
    String? progressSnapshot,
    List<String>? recommended,
    String? noShowPercent,
    String? latePercent,
    int? pendingAttendance,
    List<String>? needsAttention,
    List<String>? approvals,
    String? todaysClasses,
    String? occupancyPercent,
    String? revenueMTD,
    List<String>? risks,
    String? staffCompliance,
  }) {
    return _EnhanceData(
      attendancePercent: attendancePercent ?? this.attendancePercent,
      streak: streak ?? this.streak,
      nextPaymentDue: nextPaymentDue ?? this.nextPaymentDue,
      assignments: assignments ?? this.assignments,
      progressSnapshot: progressSnapshot ?? this.progressSnapshot,
      recommended: recommended ?? this.recommended,
      noShowPercent: noShowPercent ?? this.noShowPercent,
      latePercent: latePercent ?? this.latePercent,
      pendingAttendance: pendingAttendance ?? this.pendingAttendance,
      needsAttention: needsAttention ?? this.needsAttention,
      approvals: approvals ?? this.approvals,
      todaysClasses: todaysClasses ?? this.todaysClasses,
      occupancyPercent: occupancyPercent ?? this.occupancyPercent,
      revenueMTD: revenueMTD ?? this.revenueMTD,
      risks: risks ?? this.risks,
      staffCompliance: staffCompliance ?? this.staffCompliance,
    );
  }
}

Future<List<String>> _getStudentAssignments(String? userId) async {
  if (userId == null) return [];
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('assignments')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(3)
        .get();
    
    return snapshot.docs.map<String>((doc) {
      final data = doc.data();
      return data['title'] ?? 'Assignment';
    }).toList();
  } catch (e) {
    return [];
  }
}

Future<List<String>> _getFacultyNeedsAttention(String? userId) async {
  if (userId == null) return [];
  try {
    // Get students with low attendance in faculty's classes
    final snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('instructorId', isEqualTo: userId)
        .get();
    
    final Map<String, int> studentAttendance = {};
    final Map<String, int> studentLateCount = {};
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final studentId = data['userId'] as String?;
      final status = data['status'] as String?;
      final isLate = data['isLate'] as bool? ?? false;
      
      if (studentId != null) {
        studentAttendance[studentId] = (studentAttendance[studentId] ?? 0) + 1;
        if (isLate) {
          studentLateCount[studentId] = (studentLateCount[studentId] ?? 0) + 1;
        }
      }
    }
    
    List<String> alerts = [];
    for (final entry in studentAttendance.entries) {
      final studentId = entry.key;
      final attendanceCount = entry.value;
      final lateCount = studentLateCount[studentId] ?? 0;
      
      if (attendanceCount < 3) {
        // Get student name
        final studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .get();
        final studentName = studentDoc.data()?['name'] ?? 'Student';
        alerts.add('$studentName • Low attendance');
      }
      
      if (lateCount >= 2) {
        final studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .get();
        final studentName = studentDoc.data()?['name'] ?? 'Student';
        alerts.add('$studentName • $lateCount late marks');
      }
    }
    
    return alerts.take(3).toList();
  } catch (e) {
    return [];
  }
}

Future<List<String>> _getAdminRisks() async {
  try {
    List<String> risks = [];
    
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
        risks.add('$className underbooked');
      }
    }
    
    // Check for failed payments (simplified query to avoid index requirement)
    final failedPaymentsSnapshot = await FirebaseFirestore.instance
        .collection('payments')
        .where('status', isEqualTo: 'failed')
        .get();
    
    // Filter by timestamp in code instead of Firestore query
    final recentFailedPayments = failedPaymentsSnapshot.docs.where((doc) {
      final data = doc.data();
      final timestamp = data['timestamp'] as Timestamp?;
      if (timestamp == null) return false;
      final paymentDate = timestamp.toDate();
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      return paymentDate.isAfter(sevenDaysAgo);
    }).toList();
    
    if (recentFailedPayments.length >= 2) {
      risks.add('${recentFailedPayments.length} failed payments detected');
    }
    
    return risks.take(3).toList();
  } catch (e) {
    return [];
  }
}

Future<List<String>> _getAdminApprovals() async {
  try {
    List<String> approvals = [];
    
    // Check for pending workshops
    final workshopsSnapshot = await FirebaseFirestore.instance
        .collection('workshops')
        .where('status', isEqualTo: 'pending')
        .get();
    
    for (final doc in workshopsSnapshot.docs) {
      final data = doc.data();
      final title = data['title'] ?? 'Workshop';
      approvals.add('Workshop: $title');
    }
    
    // Check for pending banners
    final bannersSnapshot = await FirebaseFirestore.instance
        .collection('banners')
        .where('status', isEqualTo: 'pending')
        .get();
    
    for (final doc in bannersSnapshot.docs) {
      final data = doc.data();
      final title = data['title'] ?? 'Banner';
      approvals.add('Banner: $title');
    }
  
  // Check for pending cash payments
  try {
    final cashSnapshot = await FirebaseFirestore.instance
        .collection('approvals')
        .where('status', isEqualTo: 'pending')
        .where('type', isEqualTo: 'cash_payment')
        .orderBy('created_at', descending: true)
        .limit(3)
        .get();
    for (final doc in cashSnapshot.docs) {
      final msg = doc.data()['message'] ?? 'Cash payment';
      approvals.add('Payment: $msg');
    }
  } catch (e) {
  }
    
    return approvals.take(3).toList();
  } catch (e) {
    return [];
  }
}

Future<List<String>> _getStudentRecommendations(String? userId) async {
  // Recommendations removed with stats cards; return empty list
  return [];
}

Future<_EnhanceData> _loadEnhance({required String role, String? userId}) async {
  try {
    if (role.toLowerCase() == 'student') {
      String? attStr;
      if (userId != null) {
        // Calculate attendance percentage from enrollments (canonical first)
        try {
          var enrollmentsSnapshot = await FirebaseFirestore.instance
              .collection('enrollments')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'enrolled')
              .get();

          if (enrollmentsSnapshot.docs.isEmpty) {
            enrollmentsSnapshot = await FirebaseFirestore.instance
                .collection('enrollments')
                .where('userId', isEqualTo: userId)
                .where('status', isEqualTo: 'enrolled')
                .get();
          }

          if (enrollmentsSnapshot.docs.isNotEmpty) {
            int totalSessions = 0;
            int completedSessions = 0;
            
            for (final doc in enrollmentsSnapshot.docs) {
              final data = doc.data();
              totalSessions += (data['totalSessions'] ?? 0) as int;
              completedSessions += (data['completedSessions'] ?? 0) as int;
            }
            
            if (totalSessions > 0) {
              final percentage = (completedSessions / totalSessions * 100).round();
              attStr = '$percentage%';
            }
          }
        } catch (e) {
        }
      }
      return _EnhanceData(
        attendancePercent: attStr,
        streak: '—',
        nextPaymentDue: '—',
        assignments: await _getStudentAssignments(userId),
        progressSnapshot: '—',
        recommended: const [],
      );
    }
    if (role.toLowerCase() == 'faculty') {
      int pending = 0;
      double noShowPercent = 0.0;
      double latePercent = 0.0;
      if (userId != null) {
        pending = await AdminService.getPendingAttendanceCountForFaculty(userId);
        // noShowPercent = await AdminService.getNoShowPercentForFaculty(userId);
        // latePercent = await AdminService.getLatePercentForFaculty(userId);
      }
      return _EnhanceData(
        pendingAttendance: pending,
        noShowPercent: '${noShowPercent.toStringAsFixed(0)}%',
        latePercent: '${latePercent.toStringAsFixed(0)}%',
        needsAttention: await _getFacultyNeedsAttention(userId),
        approvals: await _getAdminApprovals(),
      );
    }
    // admin
    final count = await AdminService.getTodaysClassesCount();
    final occ = await AdminService.getOccupancyPercentToday();
    // final revenue = await AdminService.getRevenueMTD();
    return _EnhanceData(
      todaysClasses: count.toString(),
      occupancyPercent: '${occ.toStringAsFixed(0)}%',
      revenueMTD: await _getRevenueMTD(),
      risks: await _getAdminRisks(),
      approvals: await _getAdminApprovals(),
      staffCompliance: '—',
    );
  } catch (_) {
    return const _EnhanceData();
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


// Classes Tab
class ClassesTab extends StatefulWidget {
  const ClassesTab({super.key});

  @override
  State<ClassesTab> createState() => _ClassesTabState();
}
class _ClassesTabState extends State<ClassesTab> {
  List<DanceStyle> _danceStyles = [];
  List<String> _categories = [];
  String _selectedCategory = 'all';
  List<String> _branches = [];
  String _selectedBranch = 'all';
  String _searchQuery = '';
  String _audienceFilter = 'all'; // 'all' | 'kids' | 'adults'
  bool _isAdmin = false;
  final EventController _eventController = EventController();
  StreamSubscription<ClassEvent>? _eventSubscription;
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;
  int _refreshKey = 0;

  String _normalizeKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadBranches();
    _checkAdminRole();
    // Listen to class events and refresh classes list
    _eventSubscription = _eventController.eventStream.listen((event) {
      if (mounted) {
        setState(() {
          _refreshKey++;
        });
      }
    });
    
    // Listen to payment success events for real-time enrollment updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (mounted && (event['type'] == 'payment_success' || event['type'] == 'enrollment_updated')) {
        if (event['paymentType'] == 'class_fee' || event['paymentType'] == 'class') {
          // Force refresh enrollment status when payment succeeds
          setState(() {
            _refreshKey++;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(ClassesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-check admin role when widget updates
    _checkAdminRole();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _paymentRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      _danceStyles = await ClassStylesService.getAllStyles();
      _categories = _danceStyles.map((style) => style.name).toList();
      if (mounted) setState(() {});
    } catch (e) {
      _categories = ['Hip Hop', 'Bollywood', 'Contemporary', 'Jazz', 'Ballet', 'Salsa'];
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await BranchesService.getAllBranches();
      final seen = <String>{};
      _branches = branches
          .map((branch) => branch.name.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e[0].toUpperCase() + e.substring(1))
          .where((e) => seen.add(e.toLowerCase()))
          .toList();
      final classSnapshot = await FirebaseFirestore.instance.collection('classes').get();
      for (final doc in classSnapshot.docs) {
        final studio = (doc.data()['studio'] ?? '').toString().trim();
        if (studio.isNotEmpty && seen.add(studio.toLowerCase())) {
          _branches.add(studio);
        }
      }
      _branches.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (mounted) setState(() {});
    } catch (e) {
      _branches = [];
      if (mounted) setState(() {});
    }
  }

  Future<void> _checkAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final role = userDoc.data()?['role'] as String?;
        if (mounted) setState(() {
          _isAdmin = role?.toLowerCase() == 'admin';
        });
      } catch (e) {
        // Error checking admin role
      }
    }
  }

  Stream<List<DanceClass>> _getClassesStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null && !DemoSession.isActive) {
      return Stream.value([]);
    }

    // Show all available classes to everyone (admin, faculty, students)
    // Students can see all classes to join them
    return FirebaseFirestore.instance
        .collection('classes')
        .where('isAvailable', isEqualTo: true)
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return DanceClass.fromMap(data);
      }).toList();
    });
  }

  List<DanceClass> _filterClasses(List<DanceClass> classes) {
    // Audience filter: prefer explicit ageGroup if present; fallback to keyword inference
    List<DanceClass> filtered = classes.where((c) {
      if (_audienceFilter == 'all') return true;
      bool? explicitIsKids;
      if (c.ageGroup != null) {
        explicitIsKids = c.ageGroup!.toLowerCase() == 'kids';
      }
      final name = c.name.toLowerCase();
      final desc = c.description.toLowerCase();
      final inferredKids = name.contains('kid') || name.contains('junior') || name.contains('child') ||
          desc.contains('kid') || desc.contains('junior') || desc.contains('child');
      final isKids = explicitIsKids ?? inferredKids;
      return _audienceFilter == 'kids' ? isKids : !isKids;
    }).toList();

    if (_selectedBranch != 'all') {
      filtered = filtered.where((classItem) {
        return _normalizeKey(classItem.studio) == _normalizeKey(_selectedBranch);
      }).toList();
    }

    if (_searchQuery.isEmpty) return filtered;

    return filtered.where((classItem) {
      return classItem.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             classItem.instructor.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _showLoginPrompt(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text(
          'Login Required',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _bookClass(DanceClass danceClass) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginPrompt('To join a class, please login first');
      return;
    }

    if (danceClass.isFullyBooked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This class is fully booked'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Parse amount from formatted price string like "₹5" or "500"
      final String raw = danceClass.price.replaceAll('₹', '').replaceAll(',', '').trim();
      final int rupees = int.tryParse(raw) ?? 0;
      final int amountRupees = rupees; // Use rupees directly, not paise

      if (amountRupees <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid class price'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show payment option dialog
      final choice = await PaymentOptionDialog.show(context);
      if (choice == null) return; // User cancelled

      if (choice == PaymentChoice.cash) {
        // Request cash payment approval from admin
        final paymentId = PaymentService.generatePaymentId();
        final res = await PaymentService.requestCashPayment(
          paymentId: paymentId,
          amount: amountRupees,
          description: 'Class: ${danceClass.name}',
          paymentType: 'class_fee',
          itemId: danceClass.id,
          metadata: {
            'class_name': danceClass.name,
            'instructor': danceClass.instructor,
          },
        );
        if (res['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sent for admin confirmation (cash payment)'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cash request failed: ${res['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (choice == PaymentChoice.online) {
        final paymentId = PaymentService.generatePaymentId();
        final result = await PaymentService.processPayment(
          paymentId: paymentId,
          amount: amountRupees,
          description: 'Class: ${danceClass.name}',
          paymentType: 'class_fee',
          itemId: danceClass.id,
          metadata: {
            'class_name': danceClass.name,
            'scheduled_at': danceClass.dateTime?.toIso8601String() ?? 'TBD',
          },
        );

        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Redirecting to payment...'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed to start: ${result['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _scheduleClassReminder(DanceClass danceClass) async {
    try {
      // Schedule notification 1 hour before class
      final classDateTime = danceClass.dateTime;
      if (classDateTime == null) return; // Skip if no dateTime
      final reminderTime = classDateTime.subtract(const Duration(hours: 1));
      
      // Notification scheduling disabled
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'Dance Classes',
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              _showSearchDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Audience Filter (centered segmented control)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Center(child: _buildAudienceSegmented()),
          ),
          // Branch Filter
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _branches.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildBranchChip('All', 'all', Icons.location_on);
                      }
                      final branch = _branches[index - 1];
                      return _buildBranchChip(branch, _normalizeKey(branch), Icons.location_on);
                    },
                  ),
                ),
              ],
            ),
          ),
          // Category filter removed as requested
          // Classes List
          Flexible(
            child: StreamBuilder<List<DanceClass>>(
              key: ValueKey(_refreshKey),
              stream: _getClassesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }
                
                final classes = snapshot.data ?? [];
                final filteredClasses = _filterClasses(classes);
                
                if (filteredClasses.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 64,
                          color: Color(0xFF6B7280),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No Enrolled Classes',
                          style: TextStyle(
                            color: Color(0xFFF9FAFB),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Join a class to see it here',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredClasses.length,
                  itemBuilder: (context, index) {
                    final danceClass = filteredClasses[index];
                    return _buildClassCardWithEnrollmentStatus(danceClass);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseAuth.instance.currentUser != null
            ? FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .snapshots()
            : null,
        builder: (context, snapshot) {
          final userRole = snapshot.data?.data()?['role']?.toString().toLowerCase() ?? '';
          final isAdmin = userRole == 'admin';
          final isFaculty = userRole == 'faculty';
          
          if (isAdmin) {
            return FloatingActionButton(
              heroTag: 'classes_tab_add_class_admin',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminClassesManagementScreen(),
                ),
              );
            },
            backgroundColor: const Color(0xFFE53935),
            child: const Icon(Icons.add, color: Colors.white),
            );
          }
          
          if (isFaculty) {
            return FloatingActionButton(
              heroTag: 'classes_tab_add_class_faculty',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddEditClassScreen(),
                  ),
                );
              },
              backgroundColor: const Color(0xFFE53935),
              child: const Icon(Icons.add, color: Colors.white),
            );
          }
          
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildAudienceSegmented() {
    final options = ['all', 'kids', 'adults'];
    final labels = const ['All', 'Kids', 'Adults'];
    final isSelected = options.map((v) => _audienceFilter == v).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(4),
      child: ToggleButtons(
        isSelected: isSelected,
        onPressed: (index) {
          setState(() {
            _audienceFilter = options[index];
          });
        },
        borderRadius: BorderRadius.circular(20),
        constraints: const BoxConstraints(minHeight: 36, minWidth: 90),
        fillColor: const Color(0xFFE53935),
        selectedColor: Colors.white,
        color: Colors.white70,
        selectedBorderColor: const Color(0xFFE53935),
        borderColor: Colors.white.withValues(alpha: 0.2),
        children: labels.map((t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w600))).toList(),
      ),
    );
  }


  Widget _buildCategoryChip(String name, String id, IconData icon) {
    final isSelected = _selectedCategory == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(name),
        avatar: Icon(icon, size: 16),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = id;
          });
        },
        selectedColor: const Color(0xFFE53935),
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFFF9FAFB),
        ),
      ),
    );
  }

  Widget _buildBranchChip(String name, String id, IconData icon) {
    final isSelected = _selectedBranch == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(name),
        avatar: Icon(icon, size: 16),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedBranch = id;
          });
        },
        selectedColor: const Color(0xFFE53935),
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFFF9FAFB),
        ),
      ),
    );
  }

  void _showStyleManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StyleManagementModal(
        categories: _categories,
        onCategoriesUpdated: () {
          _loadCategories();
        },
      ),
    );
  }

  // New method for class card with enrollment status
  Widget _buildClassCardWithEnrollmentStatus(DanceClass danceClass) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return _buildClassCard(danceClass);
    }

    // Check enrollment in user subcollection (more reliable) and global collection (fallback)
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('enrollments')
          .doc(danceClass.id)
          .snapshots(),
      builder: (context, userEnrollmentSnapshot) {
        // Also check global collection as fallback
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
              .collection('enrollments')
          .where('userId', isEqualTo: currentUser.uid)
          .where('itemId', isEqualTo: danceClass.id)
          .where('status', isEqualTo: 'enrolled')
              .limit(1)
          .snapshots(),
          builder: (context, globalEnrollmentSnapshot) {
            final userEnrolled = userEnrollmentSnapshot.hasData && 
                userEnrollmentSnapshot.data!.exists &&
                (userEnrollmentSnapshot.data!.data()?['status'] == 'enrolled');
            final globalEnrolled = globalEnrollmentSnapshot.hasData && 
                globalEnrollmentSnapshot.data!.docs.isNotEmpty;
            final isEnrolled = userEnrolled || globalEnrolled;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Stack(
            children: [
              _buildClassCard(danceClass),
              if (isEnrolled)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Enrolled',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
          },
        );
      },
    );
  }
  Widget _buildClassCard(DanceClass danceClass) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFFE53935).withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Class Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF111318),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (danceClass.imageUrl.isNotEmpty &&
                            (danceClass.imageUrl.startsWith('http://') || danceClass.imageUrl.startsWith('https://')))
                        ? Image.network(
                            danceClass.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.directions_run,
                                color: Color(0xFFE53935),
                                size: 40,
                              );
                            },
                          )
                        : const Icon(
                            Icons.directions_run,
                            color: Color(0xFFE53935),
                            size: 40,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Class Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        danceClass.name,
                        style: const TextStyle(
                          color: Color(0xFFF9FAFB),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by ${danceClass.instructor}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              danceClass.category.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              danceClass.level,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      danceClass.price,
                      style: const TextStyle(
                        color: Color(0xFFE53935),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      danceClass.duration,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Description
            Text(
              danceClass.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // Schedule and Availability
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${danceClass.formattedDate} at ${danceClass.formattedTime}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 12),
            // Action Buttons
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showClassDetails(danceClass),
                  icon: const Icon(Icons.info_outline, size: 14),
                  label: const Text('Details', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE53935),
                    side: const BorderSide(color: Color(0xFFE53935)),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _EnrolButton(danceClassId: danceClass.id, danceClassName: danceClass.name, isFull: danceClass.isFullyBooked, onBook: () => _bookClass(danceClass)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showClassDetails(DanceClass danceClass) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClassDetailsModal(danceClass: danceClass),
    );
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text(
          'Notification Settings',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notifications, color: Color(0xFFE53935)),
              title: const Text(
                'Class Reminders',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Get notified before your classes',
                style: TextStyle(color: Colors.white70),
              ),
              trailing: Switch(
                value: true,
                onChanged: (value) {
                  // Handle notification toggle
                },
                thumbColor: const WidgetStatePropertyAll(Color(0xFFE53935)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Color(0xFFE53935)),
              title: const Text(
                'Schedule Notifications',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                '1 hour and 15 minutes before class',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notification settings saved!'),
                    backgroundColor: Color(0xFFE53935),
                  ),
                );
              },
            ),
            const Divider(color: Color(0xFF262626)),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Color(0xFF4F46E5)),
              title: const Text(
                'Test Notification',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Send a test notification to verify setup',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await LiveNotificationService.sendTestNotification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test notification sent! Check your notifications.'),
                      backgroundColor: Color(0xFF10B981),
                      duration: Duration(seconds: 3),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: const Color(0xFFE53935),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text(
          'Search Classes',
          style: TextStyle(color: Color(0xFFF9FAFB)),
        ),
        content: TextField(
          style: const TextStyle(color: Color(0xFFF9FAFB)),
          decoration: const InputDecoration(
            hintText: 'Search by name or instructor...',
            hintStyle: TextStyle(color: Colors.white70),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}

// Class Details Modal
class _ClassDetailsModal extends StatefulWidget {
  final DanceClass danceClass;

  const _ClassDetailsModal({required this.danceClass});

  @override
  State<_ClassDetailsModal> createState() => _ClassDetailsModalState();
}
class _ClassDetailsModalState extends State<_ClassDetailsModal> {
  @override
  Widget build(BuildContext context) {
    final danceClass = widget.danceClass;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
              color: Colors.white.withOpacity(0.3),
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
                    'Class Details',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
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
                  // Class Image
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF111111),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        danceClass.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.directions_run,
                              color: Color(0xFFE53935),
                              size: 60,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Class Title
                  Text(
                    danceClass.name,
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
                        'Instructor: ${danceClass.instructor}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Class Info Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.category,
                          title: 'Category',
                          value: danceClass.category,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.trending_up,
                          title: 'Level',
                          value: danceClass.level,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.schedule,
                          title: 'Duration',
                          value: danceClass.duration,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.currency_rupee,
                          title: 'Price',
                          value: danceClass.price,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Schedule
                  _buildSectionTitle('Schedule'),
                  _buildClassScheduleCard(danceClass),
                  const SizedBox(height: 20),
                  
                  // Description
                  _buildSectionTitle('Description'),
                  Text(
                    danceClass.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Availability removed as requested
                  const SizedBox(height: 0),
                  const SizedBox(height: 20),
                  
                  // Admin Students List (Admin/Faculty only)
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseAuth.instance.currentUser != null 
                        ? FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).snapshots()
                        : const Stream.empty(),
                    builder: (context, userSnapshot) {
                      final userRole = userSnapshot.data?.data()?['role']?.toString().toLowerCase() ?? '';
                      final isAdminOrFaculty = userRole == 'admin' || userRole == 'faculty';
                      
                      if (!isAdminOrFaculty) {
                        return const SizedBox.shrink();
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Enrolled Students'),
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: StreamBuilder<List<Map<String, dynamic>>>(
                              stream: AdminStudentsService.getClassEnrolledStudents(danceClass.id),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(color: Color(0xFFE53935)),
                                        SizedBox(height: 8),
                                        Text(
                                          'Loading enrolled students...',
                                          style: TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red, size: 32),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Error loading students',
                                          style: const TextStyle(color: Colors.red, fontSize: 14),
                                        ),
                                        Text(
                                          '${snapshot.error}',
                                          style: const TextStyle(color: Colors.red, fontSize: 10),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                
                                final students = snapshot.data ?? [];
                                
                                if (students.isEmpty) {
                                  return const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.school_outlined, color: Colors.white54, size: 48),
                                        SizedBox(height: 12),
                                        Text(
                                          'No students enrolled yet',
                                          style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Students will appear here once they enroll',
                                          style: TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                
                                return ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: students.length,
                                  itemBuilder: (context, index) {
                                    final student = students[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: const Color(0xFFE53935),
                                            child: Text(
                                              student['name'][0].toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  student['name'],
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  student['email'],
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFE53935).withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
                                                      ),
                                                      child: Text(
                                                        '${student['completedSessions']}/${student['totalSessions']} sessions',
                                                        style: const TextStyle(
                                                          color: Color(0xFFE53935),
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: student['paymentStatus'] == 'paid' 
                                                            ? Colors.green.withOpacity(0.2)
                                                            : Colors.orange.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(
                                                          color: student['paymentStatus'] == 'paid' 
                                                              ? Colors.green.withOpacity(0.3)
                                                              : Colors.orange.withOpacity(0.3)
                                                        ),
                                                      ),
                                                      child: Text(
                                                        student['paymentStatus'] == 'paid' ? 'Paid' : 'Pending',
                                                        style: TextStyle(
                                                          color: student['paymentStatus'] == 'paid' 
                                                              ? Colors.green
                                                              : Colors.orange,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Removed QR Scanner button from class details for admin/faculty
                          const SizedBox(height: 0),
                        ],
                      );
                    },
                  ),
                  
                  // Action Buttons - Check enrollment status
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseAuth.instance.currentUser != null
                        ? FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .collection('enrollments')
                            .doc(danceClass.id)
                            .snapshots()
                        : null,
                    builder: (context, userEnrollmentSnap) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseAuth.instance.currentUser != null
                            ? FirebaseFirestore.instance
                                .collection('enrollments')
                                .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                                .where('itemId', isEqualTo: danceClass.id)
                                .where('status', whereIn: ['enrolled', 'completed'])
                                .limit(1)
                                .snapshots()
                            : null,
                        builder: (context, globalEnrollmentSnap) {
                          final userStatus = (userEnrollmentSnap.hasData && userEnrollmentSnap.data!.exists)
                              ? (userEnrollmentSnap.data!.data()?['status'] as String?)
                              : null;
                          final userEnrolled = userStatus == 'enrolled' || userStatus == 'completed';
                          final globalEnrolled = globalEnrollmentSnap.hasData &&
                              globalEnrollmentSnap.data!.docs.isNotEmpty;
                          final isEnrolled = userEnrolled || globalEnrolled;
                          final isCompleted = userStatus == 'completed' || 
                              (globalEnrollmentSnap.hasData && 
                               globalEnrollmentSnap.data!.docs.any((doc) => doc.data()['status'] == 'completed'));

                          return Row(
                            children: [
                              Expanded(
                                child: isEnrolled
                                    ? ElevatedButton.icon(
                                        onPressed: null,
                                        icon: Icon(isCompleted ? Icons.check_circle_outline : Icons.check_circle, size: 18),
                                        label: Text(isCompleted ? 'Completed' : 'Enrolled'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isCompleted ? Colors.orange : Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      )
                                    : ElevatedButton.icon(
                                        onPressed: danceClass.isFullyBooked
                                            ? null
                                            : () => _joinClassNow(context, danceClass),
                                        icon: const Icon(Icons.login, size: 18),
                                        label: Text(danceClass.isFullyBooked ? 'Full' : 'Join Now'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFE53935),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassScheduleCard(DanceClass danceClass) {
    // Get days from class - check multiple sources
    List<String> days = [];
    if (danceClass.days != null && danceClass.days!.isNotEmpty) {
      days = danceClass.days!;
    } else if (danceClass.schedule['days'] != null) {
      days = List<String>.from(danceClass.schedule['days']);
    }
    
    final start = danceClass.startTime ?? danceClass.schedule['startTime']?.toString();
    final end = danceClass.endTime ?? danceClass.schedule['endTime']?.toString();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Schedule', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  days.isNotEmpty ? days.join(', ') : 'Days not set',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                (start != null && end != null) ? '$start - $end' : danceClass.formattedTime,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFE53935), size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showClassPackages(BuildContext context) {
    Navigator.pop(context); // Close details modal first
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClassPackagesModal(danceClass: widget.danceClass),
    );
  }

  Future<void> _joinClassNow(BuildContext context, DanceClass danceClass) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to join this class')),
      );
      return;
    }

    if (danceClass.isFullyBooked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This class is fully booked'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Parse amount from formatted price string like "₹500"
      final String raw = danceClass.price.replaceAll('₹', '').replaceAll(',', '').trim();
      final int amountRupees = int.tryParse(raw) ?? 0;
      if (amountRupees <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid class price'), backgroundColor: Colors.red),
        );
        return;
      }

      // Mirror main card flow: ask payment option
      final choice = await PaymentOptionDialog.show(context);
      if (choice == null) return;

      if (choice == PaymentChoice.cash) {
        final paymentId = PaymentService.generatePaymentId();
        final res = await PaymentService.requestCashPayment(
          paymentId: paymentId,
          amount: amountRupees,
          description: 'Class: ${danceClass.name}',
          paymentType: 'class_fee',
          itemId: danceClass.id,
          metadata: {
            'class_name': danceClass.name,
            'instructor': danceClass.instructor,
          },
        );
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sent for admin confirmation (cash payment)'), backgroundColor: Colors.green),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cash request failed: ${res['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (choice == PaymentChoice.online) {
        final paymentId = PaymentService.generatePaymentId();
        final result = await PaymentService.processPayment(
          paymentId: paymentId,
          amount: amountRupees,
          description: 'Class: ${danceClass.name}',
          paymentType: 'class_fee',
          itemId: danceClass.id,
          metadata: {
            'class_name': danceClass.name,
            'scheduled_at': danceClass.dateTime?.toIso8601String() ?? 'TBD',
          },
        );
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Redirecting to payment...'), backgroundColor: Colors.orange),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment failed to start: ${result['error'] ?? 'Unknown error'}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting payment: $e'), backgroundColor: const Color(0xFFE53935)),
      );
    }
  }
}

// Class Packages Modal
class _ClassPackagesModal extends StatelessWidget {
  final DanceClass danceClass;

  const _ClassPackagesModal({required this.danceClass});

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
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.card_giftcard, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Class Packages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
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
          // Join Now (replace packages)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildClassScheduleCard(danceClass),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _joinClassNow(context, danceClass),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Join Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard({
    required String title,
    required String price,
    String? originalPrice,
    required String description,
    required List<String> features,
    required bool isRecommended,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isRecommended 
            ? const Color(0xFFE53935).withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended 
              ? const Color(0xFFE53935)
              : Colors.white.withOpacity(0.1),
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'RECOMMENDED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                price,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (originalPrice != null) ...[
                const SizedBox(width: 8),
                Text(
                  originalPrice,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFFE53935),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  feature,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecommended 
                    ? const Color(0xFFE53935)
                    : Colors.white.withOpacity(0.1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                isRecommended ? 'Choose Package' : 'Select Package',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassScheduleCard(DanceClass danceClass) {
    // Get days from class - check multiple sources
    List<String> days = [];
    if (danceClass.days != null && danceClass.days!.isNotEmpty) {
      days = danceClass.days!;
    } else if (danceClass.schedule['days'] != null) {
      days = List<String>.from(danceClass.schedule['days']);
    }
    
    final start = danceClass.startTime ?? danceClass.schedule['startTime']?.toString();
    final end = danceClass.endTime ?? danceClass.schedule['endTime']?.toString();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Schedule', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  days.isNotEmpty ? days.join(', ') : 'Days not set',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                (start != null && end != null) ? '$start - $end' : danceClass.formattedTime,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _joinClassNow(BuildContext context, DanceClass danceClass) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to join this class')),
      );
      return;
    }

    try {
      // Compute sessions per month from schedule: days per week * 4
      final List<String> days = danceClass.days ?? List<String>.from(danceClass.schedule['days'] ?? []);
      final int sessionsPerMonth = (days.isNotEmpty ? days.length : 2) * 4;

      // Parse numeric price from class.price (e.g., '₹3500')
      int priceInt = 0;
      try {
        final digits = RegExp(r'\d+').allMatches(danceClass.price).map((m) => m.group(0)).join();
        priceInt = int.tryParse(digits) ?? 0;
      } catch (_) {}

      final ClassPackage monthlyPackage = ClassPackage(
        id: 'monthly_auto_${danceClass.id}',
        name: 'Monthly ${sessionsPerMonth} Sessions',
        description: 'Auto-derived from class schedule',
        price: priceInt.toDouble(),
        totalSessions: sessionsPerMonth,
        validityDays: 30,
        features: ['${sessionsPerMonth} sessions', 'Valid for 1 month'],
        category: 'monthly',
        isRecommended: true,
      );

      // Use shared enrollment flow
      final result = await ClassEnrollmentService.enrollInClass(
        classId: danceClass.id,
        className: danceClass.name,
        package: monthlyPackage,
        userId: user.uid,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enrollment created. Complete payment to confirm.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Failed to start enrollment'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to join: $e'), backgroundColor: const Color(0xFFE53935)),
      );
    }
  }

  void _bookSingleClass(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SingleClassBookingScreen(),
      ),
    );
  }

  void _bookPackage(BuildContext context, String packageType) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PackageBookingScreen(packageType: packageType),
      ),
    );
  }
}

// Studio Tab
class StudioTab extends StatefulWidget {
  const StudioTab({super.key});

  @override
  State<StudioTab> createState() => _StudioTabState();
}
class _StudioTabState extends State<StudioTab> with TickerProviderStateMixin {
  late TabController _tabController;
  final PageController _galleryController = PageController();
  int _currentGalleryIndex = 0;
  
  // Studio data from Firebase
  List<String> _studioImages = [];
  Map<String, dynamic> _studioData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStudioData();
  }

  Future<void> _loadStudioData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('studioData')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _studioData = {
            'weekdayRate': data['weekdayRate'] ?? 1000,
            'weekendRate': data['weekendRate'] ?? 1200,
            'packageWeekdayRate': data['packageWeekdayRate'] ?? 700,
            'packageWeekendRate': data['packageWeekendRate'] ?? 800,
            'packageMinHours': data['packageMinHours'] ?? 5,
            'capacity': data['capacity'] ?? '30-40 people max',
            'gracePeriod': data['gracePeriod'] ?? '15 min grace period',
            'equipment': List<String>.from(data['equipment'] ?? [
              'Sound System',
              'Professional Lights',
              'Air Conditioning',
              'Full-length Mirrors',
              'Dance Floor',
              'Storage Space',
            ]),
            'rules': List<String>.from(data['rules'] ?? [
              '15 minutes grace period for setup',
              'Noise levels must be maintained',
              'Equipment must be handled carefully',
              'No food or drinks in studio',
              'Clean up after use',
              'Booking cancellation 2 hours prior',
            ]),
          };
          _isLoading = false;
        });
      } else {
        _setDefaultStudioData();
      }
    } catch (e) {
      _setDefaultStudioData();
    }
  }

  Map<String, dynamic> _getDefaultStudioData() {
    return {
      'weekdayRate': 1000,
      'weekendRate': 1200,
      'packageWeekdayRate': 700,
      'packageWeekendRate': 800,
      'packageMinHours': 5,
      'capacity': '30-40 people max',
      'gracePeriod': '15 min grace period',
      'equipment': [
        'Sound System',
        'Professional Lights',
        'Air Conditioning',
        'Full-length Mirrors',
        'Dance Floor',
        'Storage Space',
      ],
      'rules': [
        '15 minutes grace period for setup',
        'Noise levels must be maintained',
          'Equipment must be handled carefully',
          'No food or drinks in studio',
          'Clean up after use',
          'Booking cancellation 2 hours prior',
        ],
      };
  }

  void _setDefaultStudioData() {
    setState(() {
      _studioData = _getDefaultStudioData();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _galleryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Studio Booking',
        actions: [
          // QR Scanner options for Admin/Faculty
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseAuth.instance.currentUser != null 
                ? FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).snapshots()
                : const Stream.empty(),
            builder: (context, userSnapshot) {
              final userRole = userSnapshot.data?.data()?['role']?.toString().toLowerCase() ?? '';
              final isAdminOrFaculty = userRole == 'admin' || userRole == 'faculty';
              
              if (!isAdminOrFaculty) {
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calendar_today, color: Colors.white),
                      onPressed: _showAvailabilityCalendar,
                    ),
                    IconButton(
                      icon: const Icon(Icons.history, color: Colors.white),
                      onPressed: _showBookingHistory,
                    ),
                  ],
                );
              }
              
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_today, color: Colors.white),
                    onPressed: _showAvailabilityCalendar,
                  ),
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.white),
                    onPressed: _showBookingHistory,
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('appSettings')
            .doc('studioData')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading studio data: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data?.data();
          final studioData = data != null ? {
            'weekdayRate': data['weekdayRate'] ?? 1000,
            'weekendRate': data['weekendRate'] ?? 1200,
            'packageWeekdayRate': data['packageWeekdayRate'] ?? 700,
            'packageWeekendRate': data['packageWeekendRate'] ?? 800,
            'packageMinHours': data['packageMinHours'] ?? 5,
            'capacity': data['capacity'] ?? '30-40 people max',
            'gracePeriod': data['gracePeriod'] ?? '15 min grace period',
            'equipment': List<String>.from(data['equipment'] ?? [
              'Sound System',
              'Professional Lights',
              'Air Conditioning',
              'Full-length Mirrors',
              'Dance Floor',
              'Storage Space',
            ]),
            'rules': List<String>.from(data['rules'] ?? [
              '15 minutes grace period for setup',
              'Noise levels must be maintained',
              'Equipment must be handled carefully',
              'No food or drinks in studio',
              'Clean up after use',
              'Booking cancellation 2 hours prior',
            ]),
          } : _getDefaultStudioData();

          return SingleChildScrollView(
            child: Column(
              children: [
                // Studio Banner Carousel (same as home)
                _StudioBannerCarousel(),
                const SizedBox(height: 16),
                _buildPricingSection(studioData),
                _buildEquipmentSection(studioData),
                _buildStudioRulesSection(studioData),
                _buildContactSection(),
                const SizedBox(height: 100), // Space for floating button
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'studio_tab_book_button',
        onPressed: _showBookingForm,
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.event_available),
        label: const Text('Book Studio'),
      ),
    );
  }

  Widget _buildStudioGallery(List<String> images, Map<String, dynamic> studioData) {
    // Ensure current index is valid
    if (images.isNotEmpty && _currentGalleryIndex >= images.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _galleryController.hasClients) {
          _galleryController.jumpToPage(0);
          setState(() {
            _currentGalleryIndex = 0;
          });
        }
      });
    }
    
    return Column(
      children: [
        // Studio Gallery Slider
        Container(
          height: 250,
          margin: const EdgeInsets.all(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PageView.builder(
                controller: _galleryController,
                physics: images.length > 1 
                    ? const PageScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                scrollDirection: Axis.horizontal,
                onPageChanged: (index) {
                  if (mounted) {
                    setState(() {
                      _currentGalleryIndex = index;
                    });
                  }
                },
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        cacheWidth: 800,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: const Color(0xFF1B1B1B),
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                color: const Color(0xFFE53935),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFF1B1B1B),
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
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      images.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentGalleryIndex == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Photos & Videos Tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildMediaCard('Photos', Icons.photo_library, Colors.blue),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Studio Info Cards
        _buildInfoCard('Capacity', studioData['capacity'] ?? '30-40 people max', Icons.people),
        _buildInfoCard('Time Management', studioData['gracePeriod'] ?? '15 min grace period', Icons.access_time),
        _buildInfoCard('Noise Policy', 'Sound level guidelines apply', Icons.volume_up),
      ],
    );
  }

  Widget _buildMediaCard(String title, IconData icon, Color color) {
    return Card(
      color: const Color(0xFF1B1B1B),
      child: InkWell(
        onTap: () => _showMediaViewer(title),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                '${_studioImages.length} images',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMediaViewer(String type) {
    _showImageGallery();
  }

  void _showImageGallery() {
    if (_studioImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images available')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Studio Images', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: PageView.builder(
            itemCount: _studioImages.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(_studioImages[index]),
                    fit: BoxFit.contain,
                    onError: (exception, stackTrace) {
                    },
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }


  Widget _buildInfoCard(String title, String subtitle, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: const Color(0xFF1B1B1B),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFE53935)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }

  Widget _buildPricingSection(Map<String, dynamic> studioData) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Studio Pricing',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Regular Pricing
          _buildPricingCard(
            'Regular Rates',
            [
              _buildPricingItem('Weekdays', '₹${studioData['weekdayRate'] ?? 1000}/hour'),
              _buildPricingItem('Weekends', '₹${studioData['weekendRate'] ?? 1200}/hour'),
            ],
            Colors.blue,
          ),
          
          const SizedBox(height: 16),
          
          // Package Deals
          _buildPricingCard(
            'Package Deals',
            [
              _buildPricingItem('Weekdays (${studioData['packageMinHours'] ?? 5}+ hours)', '₹${studioData['packageWeekdayRate'] ?? 700}/hour'),
              _buildPricingItem('Weekends (${studioData['packageMinHours'] ?? 5}+ hours)', '₹${studioData['packageWeekendRate'] ?? 800}/hour'),
            ],
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(String title, List<Widget> items, Color color) {
    return Card(
      color: const Color(0xFF1B1B1B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildPricingItem(String label, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStudioRulesSection(Map<String, dynamic> studioData) {
    final rules = List<String>.from(studioData['rules'] ?? []);
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Studio Rules & Policies',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF1B1B1B),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...rules.map((rule) => _buildRuleItem('• $rule')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String rule) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(rule, style: const TextStyle(color: Colors.white70)),
    );
  }

  Widget _buildEquipmentSection(Map<String, dynamic> studioData) {
    final equipment = List<String>.from(studioData['equipment'] ?? []);
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Studio Equipment',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...equipment.map((item) => _buildEquipmentCard(item, 'Professional equipment', _getEquipmentIcon(item))),
        ],
      ),
    );
  }

  IconData _getEquipmentIcon(String equipment) {
    switch (equipment.toLowerCase()) {
      case 'sound system':
        return Icons.speaker;
      case 'professional lights':
        return Icons.lightbulb;
      case 'air conditioning':
        return Icons.ac_unit;
      case 'full-length mirrors':
        return Icons.visibility;
      case 'dance floor':
        return Icons.directions_run;
      case 'storage space':
        return Icons.storage;
      default:
        return Icons.build;
    }
  }

  Widget _buildEquipmentCard(String title, String description, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFF1B1B1B),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4F46E5), size: 32),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(description, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact Studio',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF1B1B1B),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('app_config')
                    .doc('contact_info')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'Error loading contact info',
                      style: TextStyle(color: Colors.red),
                    );
                  }
                  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  
                  final data = snapshot.data?.data() ?? {};
                  final phone = data['phone'] ?? '+91 98765 43210';
                  final whatsapp = data['whatsapp'] ?? '919999999999';
                  final email = data['email'] ?? 'info@dancerang.com';
                  
                  return Column(
                    children: [
                      _buildContactItem(Icons.phone, 'Call Studio Manager', phone),
                      _buildContactItem(Icons.message, 'WhatsApp Booking', whatsapp),
                      _buildContactItem(Icons.email, 'Email Support', email),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF262626)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white70)),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String contactInfo) {
    return InkWell(
      onTap: () => _handleContact(icon, contactInfo),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF4F46E5)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white)),
                  Text(
                    contactInfo,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  // Action Methods
  void _showAvailabilityCalendar() {
    showDialog(
      context: context,
      builder: (context) => StudioAvailabilityCalendar(),
    );
  }
  // Check for booking conflicts
  Future<Map<String, dynamic>> _checkBookingConflicts(DateTime date, TimeOfDay time, int duration) async {
    try {
      final startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      final endTime = startTime.add(Duration(hours: duration));
      
      // Get all bookings for the selected date
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('studioBookings')
          .where('date', isEqualTo: Timestamp.fromDate(date))
          .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
          .get();

      for (final doc in bookingsSnapshot.docs) {
        final bookingData = doc.data();
        final bookingTime = bookingData['time'] as String;
        final bookingDuration = bookingData['duration'] as int;
        
        // Parse booking time
        final timeParts = bookingTime.split(':');
        final bookingStart = DateTime(
          date.year, 
          date.month, 
          date.day, 
          int.parse(timeParts[0]), 
          int.parse(timeParts[1])
        );
        final bookingEnd = bookingStart.add(Duration(hours: bookingDuration));
        
        // Check for time overlap
        if (startTime.isBefore(bookingEnd) && endTime.isAfter(bookingStart)) {
          return {
            'hasConflict': true,
            'message': 'Time slot overlaps with existing booking from ${bookingTime} to ${bookingEnd.hour.toString().padLeft(2, '0')}:${bookingEnd.minute.toString().padLeft(2, '0')}',
          };
        }
      }
      
      return {'hasConflict': false, 'message': ''};
    } catch (e) {
      return {'hasConflict': true, 'message': 'Error checking conflicts: $e'};
    }
  }
  void _showBookingHistory() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to view bookings')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF1B1B1B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('My Studio Bookings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('studioBookings')
                      .where('userId', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white70));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('No bookings yet', style: TextStyle(color: Colors.white70)),
                      );
                    }
                    final docs = [...snapshot.data!.docs];
                    // Client-side sort by createdAt desc to avoid index requirement
                    docs.sort((a, b) {
                      final ta = a.data()['createdAt'];
                      final tb = b.data()['createdAt'];
                      final da = ta is Timestamp ? ta.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                      final db = tb is Timestamp ? tb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                      return db.compareTo(da);
                    });
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final d = docs[index].data();
                        final status = (d['status'] as String? ?? 'pending');
                        final date = (d['date'] is Timestamp) ? (d['date'] as Timestamp).toDate() : null;
                        final time = (d['time'] as String? ?? '');
                        final duration = (d['duration'] as int? ?? 1);
                        final amount = (d['advanceAmount'] as int? ?? 0);
                        return GestureDetector(
                          onTap: () => _showBookingDetails(docs[index].id, d),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        date != null ? 'Date: ${date.day}/${date.month}/${date.year}  •  $time' : 'Date: —  •  $time',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Duration: ${duration}h', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      const SizedBox(height: 8),
                                      _statusBadge(status),
                                    ],
                                  ),
                                ),
                                Text('₹$amount', style: const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'confirmed':
        color = const Color(0xFF10B981);
        break;
      case 'in_progress':
        color = const Color(0xFFFF9800);
        break;
      case 'completed':
        color = const Color(0xFF4F46E5);
        break;
      default:
        color = const Color(0xFFE53935); // pending/cancelled
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showBookingDetails(String bookingId, Map<String, dynamic> booking) {
    final date = (booking['date'] is Timestamp) ? (booking['date'] as Timestamp).toDate() : null;
    final time = (booking['time'] as String? ?? '');
    final duration = (booking['duration'] as int? ?? 1);
    final name = (booking['name'] as String? ?? '—');
    final branch = (booking['branch'] as String? ?? '—');
    final totalAmount = (booking['totalAmount'] as int? ?? 0);
    final advanceAmount = (booking['advanceAmount'] as int? ?? 0);
    final finalAmount = (booking['finalAmount'] as int? ?? 0);
    final pendingAmount = finalAmount > 0 ? finalAmount : (totalAmount - advanceAmount);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Booking Details', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $name', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              date != null ? 'Date: ${date.day}/${date.month}/${date.year}' : 'Date: —',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text('Time: $time', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Duration: ${duration}h', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Branch: $branch', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Text('Total Amount: ₹$totalAmount', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 4),
            Text('Paid Amount: ₹$advanceAmount', style: const TextStyle(color: Colors.greenAccent)),
            const SizedBox(height: 4),
            Text('Pending Amount: ₹${pendingAmount < 0 ? 0 : pendingAmount}', style: const TextStyle(color: Colors.orangeAccent)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (pendingAmount > 0)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _payPendingAmount(bookingId, booking, pendingAmount);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
              ),
              child: const Text('Pay Pending'),
            ),
        ],
      ),
    );
  }

  Future<void> _payPendingAmount(String bookingId, Map<String, dynamic> booking, int pendingAmount) async {
    final choice = await PaymentOptionDialog.show(context);
    if (choice == null) return;
    final dateIso = (booking['date'] is Timestamp)
        ? (booking['date'] as Timestamp).toDate().toIso8601String()
        : '';
    if (choice == PaymentChoice.cash) {
      final paymentId = PaymentService.generatePaymentId();
      final res = await PaymentService.requestCashPayment(
        paymentId: paymentId,
        amount: pendingAmount,
        description: 'Studio Booking Pending: ${booking['duration'] ?? 1}h',
        paymentType: 'studio_booking',
        itemId: bookingId,
        metadata: {
          'booking_id': bookingId,
          'name': booking['name'] ?? '',
          'phone': booking['phone'] ?? '',
          'purpose': booking['purpose'] ?? '',
          'date': dateIso,
          'time': booking['time'] ?? '',
          'duration': booking['duration'] ?? 1,
          'total_amount': booking['totalAmount'] ?? pendingAmount,
          'advance_amount': booking['advanceAmount'] ?? 0,
          'final_amount': pendingAmount,
          'payment_stage': 'pending',
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
        amount: pendingAmount,
        description: 'Studio Booking Pending: ${booking['duration'] ?? 1}h',
        paymentType: 'studio_booking',
        itemId: bookingId,
        metadata: {
          'booking_id': bookingId,
          'name': booking['name'] ?? '',
          'phone': booking['phone'] ?? '',
          'purpose': booking['purpose'] ?? '',
          'date': dateIso,
          'time': booking['time'] ?? '',
          'duration': booking['duration'] ?? 1,
          'total_amount': booking['totalAmount'] ?? pendingAmount,
          'advance_amount': booking['advanceAmount'] ?? 0,
          'final_amount': pendingAmount,
          'payment_stage': 'pending',
        },
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Redirecting to payment...'), backgroundColor: Colors.orange),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${result['error'] ?? 'Unknown error'}'), backgroundColor: Colors.red),
        );
      }
    }
  }


  void _selectDate() {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
  }

  void _selectTime() {
    showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
  }

  void _selectDuration() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Select Duration', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(8, (index) {
            final hours = index + 1;
            return ListTile(
              title: Text('$hours hour${hours > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Selected $hours hour${hours > 1 ? 's' : ''}')),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  void _showBookingForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingFormDialog(studioData: _studioData),
    );
  }

  void _showBookingConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Confirm Booking', style: TextStyle(color: Colors.white)),
        content: const Text('Proceed with payment?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Booking confirmed! WhatsApp notification sent.'),
                  backgroundColor: Color(0xFF4F46E5),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            child: const Text('Pay & Book'),
          ),
        ],
      ),
    );
  }

  void _handleContact(IconData icon, String contactInfo) async {
    try {
      if (icon == Icons.phone) {
        // Make phone call
        final phoneNumber = contactInfo.replaceAll(RegExp(r'[^\d+]'), '');
        final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);
        } else {
          _showErrorSnackBar('Cannot make phone call to $contactInfo');
        }
      } else if (icon == Icons.message) {
        // Open WhatsApp
        final phoneNumber = contactInfo.replaceAll(RegExp(r'[^\d]'), '');
        final Uri whatsappUri = Uri.parse('https://wa.me/$phoneNumber');
        if (await canLaunchUrl(whatsappUri)) {
          await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        } else {
          _showErrorSnackBar('Cannot open WhatsApp with $contactInfo');
        }
      } else if (icon == Icons.email) {
        // Open email client
        final Uri emailUri = Uri(
          scheme: 'mailto',
          path: contactInfo,
          query: 'subject=Studio Booking Inquiry&body=Hello, I would like to inquire about studio booking.',
        );
        if (await canLaunchUrl(emailUri)) {
          await launchUrl(emailUri);
        } else {
          _showErrorSnackBar('Cannot open email client for $contactInfo');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Booking Form Dialog
class _BookingFormDialog extends StatefulWidget {
  final Map<String, dynamic> studioData;
  
  const _BookingFormDialog({required this.studioData});

  @override
  _BookingFormDialogState createState() => _BookingFormDialogState();
}
class _BookingFormDialogState extends State<_BookingFormDialog> {
  static const List<String> _fallbackBranches = ['Balewadi', 'Wakad'];
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _selectedDuration = 1;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  List<String> _branches = [];
  String _selectedBranch = '';
  Map<String, Map<String, List<String>>> _availabilityOverrides = {};
  List<Map<String, String>> _weeklyBlockedRanges = [];

  @override
  void initState() {
    super.initState();
    _loadAvailabilitySettings();
    _loadBranches();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      await BranchesService.initializeDefaultBranches();
      final branches = await BranchesService.getAllBranches();
      final seen = <String>{};
      _branches = branches
          .map((branch) => branch.name.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e[0].toUpperCase() + e.substring(1))
          .where((e) => seen.add(e.toLowerCase()))
          .toList();
      if (_branches.isEmpty) {
        _branches = List<String>.from(_fallbackBranches);
      }
      _branches.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (_selectedBranch.isEmpty && _branches.isNotEmpty) {
        _selectedBranch = _branches.first;
      }
      if (mounted) setState(() {});
    } catch (e) {
      _branches = List<String>.from(_fallbackBranches);
      if (_selectedBranch.isEmpty && _branches.isNotEmpty) {
        _selectedBranch = _branches.first;
      }
      if (mounted) setState(() {});
    }
  }
  Future<void> _loadAvailabilitySettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('studioAvailability')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _availabilityOverrides = Map<String, Map<String, List<String>>>.from(
            (data['overrides'] ?? {}).map<String, Map<String, List<String>>>((k, v) => MapEntry(
                  k as String,
                  {
                    'availableTimes': List<String>.from((v['availableTimes'] ?? []) as List),
                    'blockedTimes': List<String>.from((v['blockedTimes'] ?? []) as List),
                  },
                )),
          );
          _weeklyBlockedRanges = List<Map<String, String>>.from(
            (data['weeklyRule']?['blockedRanges'] ?? []).map<Map<String, String>>((r) => {
                  'start': r['start'] as String,
                  'end': r['end'] as String,
                }),
          );
        });
      } else {
      }
    } catch (e) {
    }
  }

  String _formatDateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isBlockedByWeeklyRule(String time) {
    // time: HH:00
    final hour = int.parse(time.split(':')[0]);
    for (final range in _weeklyBlockedRanges) {
      final startHour = int.parse(range['start']!.split(':')[0]);
      final endHour = int.parse(range['end']!.split(':')[0]);
      if (hour >= startHour && hour < endHour) return true;
    }
    return false;
  }

  bool _isAvailableForDate(DateTime date, String time) {
    final key = _formatDateKey(date);
    final override = _availabilityOverrides[key];
    if (override != null) {
      if (override['blockedTimes']!.contains(time)) {
        return false;
      }
      if (override['availableTimes']!.contains(time)) {
        return true;
      }
    }
    // Default: available unless weekly rule blocks it
    final isBlockedByWeekly = _isBlockedByWeeklyRule(time);
    if (isBlockedByWeekly) {
    }
    return !isBlockedByWeekly;
  }

  // Check for booking conflicts
  Future<Map<String, dynamic>> _checkBookingConflicts(DateTime date, TimeOfDay time, int duration) async {
    try {
      final startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      final endTime = startTime.add(Duration(hours: duration));
      
      // Check if admin has blocked any part of this time slot
      for (int hour = time.hour; hour < time.hour + duration; hour++) {
        final timeSlot = '${hour.toString().padLeft(2, '0')}:00';
        if (!_isAvailableForDate(date, timeSlot)) {
          return {
            'hasConflict': true,
            'message': 'This time slot is blocked by admin availability settings',
          };
        }
      }
      
      // Get all bookings for the selected date
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('studioBookings')
          .where('date', isEqualTo: Timestamp.fromDate(date))
          .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
          .get();

      for (final doc in bookingsSnapshot.docs) {
        final bookingData = doc.data();
        final bookingTime = bookingData['time'] as String;
        final bookingDuration = bookingData['duration'] as int;
        
        // Parse booking time
        final timeParts = bookingTime.split(':');
        final bookingStart = DateTime(
          date.year, 
          date.month, 
          date.day, 
          int.parse(timeParts[0]), 
          int.parse(timeParts[1])
        );
        final bookingEnd = bookingStart.add(Duration(hours: bookingDuration));
        
        // Check for time overlap
        if (startTime.isBefore(bookingEnd) && endTime.isAfter(bookingStart)) {
          return {
            'hasConflict': true,
            'message': 'Time slot overlaps with existing booking from ${bookingTime} to ${bookingEnd.hour.toString().padLeft(2, '0')}:${bookingEnd.minute.toString().padLeft(2, '0')}',
          };
        }
      }
      
      return {'hasConflict': false, 'message': ''};
    } catch (e) {
      return {'hasConflict': true, 'message': 'Error checking conflicts: $e'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Book Studio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          
          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Booking Details Section
                  _buildSectionTitle('Booking Details'),
                  const SizedBox(height: 16),
                  
                  _buildFormField(
                    'Select Date',
                    _selectedDate != null 
                        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                        : 'Choose date',
                    Icons.calendar_today,
                    () => _selectDate(),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildFormField(
                    'Select Time',
                    _selectedTime != null 
                        ? _selectedTime!.format(context)
                        : 'Choose time',
                    Icons.access_time,
                    () => _selectTime(),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildFormField(
                    'Duration',
                    '$_selectedDuration hour${_selectedDuration > 1 ? 's' : ''}',
                    Icons.timer,
                    () => _selectDuration(),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  if (_branches.isNotEmpty)
                    _buildBranchDropdown(),
                  
                  const SizedBox(height: 24),
                  
                  // Personal Details Section
                  _buildSectionTitle('Personal Details'),
                  const SizedBox(height: 16),
                  
                  _buildTextField('Full Name', _nameController, Icons.person),
                  const SizedBox(height: 12),
                  _buildTextField('Phone Number', _phoneController, Icons.phone),
                  const SizedBox(height: 12),
                  _buildTextField('Purpose of Booking', _purposeController, Icons.description),
                  
                  const SizedBox(height: 24),
                  
                  // Pricing Summary
                  _buildPricingSummary(),
                  
                  const SizedBox(height: 24),
                  
                  // Payment Options
                  _buildPaymentOptions(),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildBranchDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Branch', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF262626),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF404040)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _branches.contains(_selectedBranch)
                  ? _selectedBranch
                  : (_branches.isNotEmpty ? _branches.first : null),
              isExpanded: true,
              dropdownColor: const Color(0xFF1B1B1B),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE53935)),
              items: _branches
                  .map((branch) => DropdownMenuItem(value: branch, child: Text(branch)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedBranch = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormField(String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF404040)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFE53935)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: const Color(0xFFE53935)),
        filled: true,
        fillColor: const Color(0xFF262626),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF404040)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF404040)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
        ),
      ),
    );
  }

  Widget _buildPricingSummary() {
    final isWeekend = _selectedDate?.weekday == DateTime.saturday || _selectedDate?.weekday == DateTime.sunday;
    final isPackage = _selectedDuration >= (widget.studioData['packageMinHours'] ?? 5);
    
    int rate;
    if (isPackage) {
      rate = isWeekend 
          ? (widget.studioData['packageWeekendRate'] ?? 800)
          : (widget.studioData['packageWeekdayRate'] ?? 700);
    } else {
      rate = isWeekend 
          ? (widget.studioData['weekendRate'] ?? 1200)
          : (widget.studioData['weekdayRate'] ?? 1000);
    }
    
    final totalAmount = rate * _selectedDuration;
    final advanceAmount = (totalAmount * 0.5).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pricing Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Rate per hour:', style: TextStyle(color: Colors.white70)),
              Text('₹$rate/hour', style: const TextStyle(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Duration:', style: TextStyle(color: Colors.white70)),
              Text('$_selectedDuration hour${_selectedDuration > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount:', style: TextStyle(color: Colors.white70)),
              Text('₹$totalAmount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(color: Color(0xFF404040)),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Advance Payment (50%):', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
              Text('₹$advanceAmount', style: const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Options',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Pay 50% Now Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _processBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Pay 50% Now & Book',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Pay Full Amount Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _processFullPayment,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE53935)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Pay Full Amount',
              style: TextStyle(color: Color(0xFFE53935), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
      
      // Show available times for the selected date
      _showAvailableTimesForDate(date);
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }
  // Show available times for selected date
  void _showAvailableTimesForDate(DateTime date) async {
    try {
      // Get all bookings for the selected date
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('studioBookings')
          .where('date', isEqualTo: Timestamp.fromDate(date))
          .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
          .get();

      final bookedTimes = <Map<String, dynamic>>[];
      for (final doc in bookingsSnapshot.docs) {
        final bookingData = doc.data();
        final bookingTime = bookingData['time'] as String;
        final duration = bookingData['duration'] as int;
        final name = bookingData['name'] as String;
        final status = bookingData['status'] as String;
        
        // Calculate end time
        final timeParts = bookingTime.split(':');
        final startHour = int.parse(timeParts[0]);
        final startMinute = int.parse(timeParts[1]);
        final endHour = startHour + duration;
        final endTime = '${endHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
        
        bookedTimes.add({
          'startTime': bookingTime,
          'endTime': endTime,
          'duration': duration,
          'name': name,
          'status': status,
        });
      }

      // Generate available time slots (9 AM to 10 PM, 1-hour slots)
      final availableSlots = <String>[];
      for (int hour = 9; hour <= 22; hour++) {
        final timeSlot = '${hour.toString().padLeft(2, '0')}:00';
        
        // Check if admin has blocked this time slot
        if (!_isAvailableForDate(date, timeSlot)) {
          continue; // Skip this time slot - admin has blocked it
        }
        
        // Check if this time slot conflicts with any existing booking
        bool hasConflict = false;
        for (final booking in bookedTimes) {
          final bookingStart = booking['startTime'] as String;
          final bookingEnd = booking['endTime'] as String;
          
          // Parse booking times
          final startParts = bookingStart.split(':');
          final endParts = bookingEnd.split(':');
          final bookingStartHour = int.parse(startParts[0]);
          final bookingEndHour = int.parse(endParts[0]);
          
          // Check if our time slot overlaps with the booking
          if (hour >= bookingStartHour && hour < bookingEndHour) {
            hasConflict = true;
            break;
          }
        }
        
        if (!hasConflict) {
          availableSlots.add(timeSlot);
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1B1B1B),
            title: Text(
              'Available Times - ${date.day}/${date.month}/${date.year}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bookedTimes.isNotEmpty) ...[
                    const Text(
                      'Booked Times:',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...bookedTimes.map((booking) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: booking['status'] == 'confirmed' 
                                  ? Colors.green 
                                  : booking['status'] == 'in_progress'
                                      ? Colors.blue
                                      : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${booking['startTime']} - ${booking['endTime']} (${booking['name']} - ${booking['duration']}h)',
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),
                  ],
                  
                  const Text(
                    'Available Times:',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  if (availableSlots.isEmpty)
                    const Text(
                      'No available time slots for this date',
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableSlots.map((time) => GestureDetector(
                        onTap: () {
                          final timeParts = time.split(':');
                          final selectedTime = TimeOfDay(
                            hour: int.parse(timeParts[0]),
                            minute: int.parse(timeParts[1]),
                          );
                          setState(() {
                            _selectedTime = selectedTime;
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Time selected: $time'),
                              backgroundColor: const Color(0xFFE53935),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            time,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      )).toList(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
    }
  }

  void _selectDuration() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Select Duration', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(8, (index) {
            final hours = index + 1;
            return ListTile(
              title: Text('$hours hour${hours > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white)),
              onTap: () {
                setState(() {
                  _selectedDuration = hours;
                });
                Navigator.pop(context);
              },
            );
          }),
        ),
      ),
    );
  }
  void _processBooking() async {
    if (_selectedDate == null || _selectedTime == null || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    if (_selectedBranch.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a branch')),
      );
      return;
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to book studio time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check for booking conflicts first
    final conflictCheck = await _checkBookingConflicts(_selectedDate!, _selectedTime!, _selectedDuration);
    if (conflictCheck['hasConflict']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Time slot conflict: ${conflictCheck['message']}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Calculate amount (50% advance)
    final totalAmount = _calculateTotalAmount();
    final advanceAmount = (totalAmount * 0.5).round();

    // Create studio booking first
    final bookingRef = FirebaseFirestore.instance.collection('studioBookings').doc();
    final bookingId = bookingRef.id;

    final bookingData = {
      'bookingId': bookingId,
      'userId': user.uid,
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'purpose': _purposeController.text.trim(),
      'branch': _selectedBranch,
      'date': Timestamp.fromDate(_selectedDate!),
      'time': '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
      'duration': _selectedDuration,
      'status': 'pending',
      'totalAmount': totalAmount,
      'advanceAmount': advanceAmount,
      'finalAmount': totalAmount - advanceAmount,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await bookingRef.set(bookingData);
      
      // Choose payment method for advance amount
      final choice = await PaymentOptionDialog.show(context);
      if (choice == PaymentChoice.cash) {
        final paymentId = PaymentService.generatePaymentId();
        final res = await PaymentService.requestCashPayment(
          paymentId: paymentId,
          amount: advanceAmount,
          description: 'Studio Booking Advance: ${_selectedDuration}h on ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
          paymentType: 'studio_booking',
          itemId: bookingId,
          metadata: {
            'booking_id': bookingId,
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'purpose': _purposeController.text.trim(),
            'branch': _selectedBranch,
            'date': _selectedDate!.toIso8601String(),
            'time': '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
            'duration': _selectedDuration,
            'total_amount': totalAmount,
            'advance_amount': advanceAmount,
            'final_amount': totalAmount - advanceAmount,
          },
        );
        Navigator.pop(context);
        if (res['success'] == true) {
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
          amount: advanceAmount,
          description: 'Studio Booking Advance: ${_selectedDuration}h on ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
          paymentType: 'studio_booking',
          itemId: bookingId,
          metadata: {
            'booking_id': bookingId,
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'purpose': _purposeController.text.trim(),
            'branch': _selectedBranch,
            'date': _selectedDate!.toIso8601String(),
            'time': '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
            'duration': _selectedDuration,
            'total_amount': totalAmount,
            'advance_amount': advanceAmount,
            'final_amount': totalAmount - advanceAmount,
          },
        );

        Navigator.pop(context);
        
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Redirecting to payment...'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: ${result['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _processFullPayment() async {
    if (_selectedDate == null || _selectedTime == null || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    if (_selectedBranch.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a branch')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to book studio time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final conflictCheck = await _checkBookingConflicts(_selectedDate!, _selectedTime!, _selectedDuration);
    if (conflictCheck['hasConflict']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Time slot conflict: ${conflictCheck['message']}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final totalAmount = _calculateTotalAmount();
    final bookingRef = FirebaseFirestore.instance.collection('studioBookings').doc();
    final bookingId = bookingRef.id;
    final bookingData = {
      'bookingId': bookingId,
      'userId': user.uid,
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'purpose': _purposeController.text.trim(),
      'branch': _selectedBranch,
      'date': Timestamp.fromDate(_selectedDate!),
      'time': '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
      'duration': _selectedDuration,
      'status': 'pending',
      'totalAmount': totalAmount,
      'advanceAmount': totalAmount,
      'finalAmount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await bookingRef.set(bookingData);
      final choice = await PaymentOptionDialog.show(context);
      if (choice == PaymentChoice.cash) {
        final paymentId = PaymentService.generatePaymentId();
        final res = await PaymentService.requestCashPayment(
          paymentId: paymentId,
          amount: totalAmount,
          description: 'Studio Booking Full: ${_selectedDuration}h on ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
          paymentType: 'studio_booking',
          itemId: bookingId,
          metadata: {
            'booking_id': bookingId,
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'purpose': _purposeController.text.trim(),
            'branch': _selectedBranch,
            'date': _selectedDate!.toIso8601String(),
            'time': '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
            'duration': _selectedDuration,
            'total_amount': totalAmount,
            'advance_amount': totalAmount,
            'final_amount': 0,
            'payment_stage': 'full',
          },
        );
        Navigator.pop(context);
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
          amount: totalAmount,
          description: 'Studio Booking Full: ${_selectedDuration}h on ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
          paymentType: 'studio_booking',
          itemId: bookingId,
          metadata: {
            'booking_id': bookingId,
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'purpose': _purposeController.text.trim(),
            'branch': _selectedBranch,
            'date': _selectedDate!.toIso8601String(),
            'time': '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
            'duration': _selectedDuration,
            'total_amount': totalAmount,
            'advance_amount': totalAmount,
            'final_amount': 0,
            'payment_stage': 'full',
          },
        );
        Navigator.pop(context);
        if (!mounted) return;
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Redirecting to payment...'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: ${result['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _calculateTotalAmount() {
    // Get rates from studio data
    final weekdayRate = widget.studioData['weekdayRate'] ?? 1000;
    final weekendRate = widget.studioData['weekendRate'] ?? 1200;
    
    // Check if selected date is weekend (Saturday = 6, Sunday = 7)
    final isWeekend = _selectedDate?.weekday == 6 || _selectedDate?.weekday == 7;
    final hourlyRate = isWeekend ? weekendRate : weekdayRate;
    
    return hourlyRate * _selectedDuration;
  }
}

// Online Tab
class OnlineTab extends StatefulWidget {
  const OnlineTab({super.key});

  @override
  State<OnlineTab> createState() => _OnlineTabState();
}
class _OnlineTabState extends State<OnlineTab> {
  @override
  void initState() {
    super.initState();
    // If the user already purchased on Play but activation failed earlier,
    // restore purchases to trigger server verification again.
    IapService.instance.syncPurchases();
  }

  void _showSubscriptionPlans() {
    showDialog(
      context: context,
      builder: (context) => const _SubscriptionPlansDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stylesCollection = 'onlineStyles';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'Online Classes',
        leading: IconButton(
          icon: const Icon(Icons.live_tv, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LiveStreamingScreen()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VideoSearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OfflineDownloadsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroBanner(),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection(stylesCollection)
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Color(0xFFE53935)),
                  );
                }
                
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading styles: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                final styles = snapshot.data?.docs ?? [];
                
                if (styles.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No dance styles available',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                
                styles.sort((a, b) {
                  final aData = a.data();
                  final bData = b.data();
                  final aPriority = (aData['priority'] ?? 0) as int;
                  final bPriority = (bData['priority'] ?? 0) as int;
                  if (aPriority != bPriority) {
                    return aPriority.compareTo(bPriority);
                  }
                  final aName = (aData['name'] ?? '').toString().toLowerCase();
                  final bName = (bData['name'] ?? '').toString().toLowerCase();
                  return aName.compareTo(bName);
                });

                return Column(
                  children: [
                    ...styles.map((doc) {
                      final data = doc.data();
                      final style = DanceStyle(
                        id: doc.id,
                        name: data['name'] ?? '',
                        description: data['description'] ?? '',
                        icon: data['icon'] ?? 'directions_run',
                        color: data['color'] ?? '#E53935',
                        isActive: data['isActive'] ?? true,
                        priority: data['priority'] ?? 0,
                        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      );
                      return _buildDynamicStyleSection(style);
                    }).toList(),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Card(
      elevation: 8,
      shadowColor: const Color(0xFFE53935).withOpacity(0.2),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFFE53935).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      margin: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFE53935).withOpacity(0.12),
              const Color(0xFF4F46E5).withOpacity(0.10),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.video_library_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Master Dance Styles',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Learn from the best instructors with premium video content',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C3A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF3A3A4A).withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Welcome to DanceRang Online Learning',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyleSection(String styleName, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                styleName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StyleVideoScreen(styleName: styleName, styleColor: color),
                    ),
                  );
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: _VideoSectionBuilder(
            styleName: styleName,
            icon: icon,
            color: color,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDynamicStyleSection(DanceStyle style) {
    final icon = DanceStylesService.getIconData(style.icon);
    final color = DanceStylesService.getColorFromHex(style.color);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
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
                      style.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (style.description.isNotEmpty)
                      Text(
                        style.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StyleVideoScreen(
                        styleName: style.name, 
                        styleColor: color,
                      ),
                    ),
                  );
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: _VideoSectionBuilder(
            styleName: style.name,
            icon: icon,
            color: color,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionContent(String section) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: section == 'All' 
          ? FirebaseFirestore.instance
              .collection('onlineVideos')
              .where('status', isEqualTo: 'published')
              .orderBy('createdAt', descending: true)
              .snapshots()
          : FirebaseFirestore.instance
              .collection('onlineVideos')
              .where('section', isEqualTo: section)
              .where('status', isEqualTo: 'published')
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
        }
        
        final docs = snapshot.data?.docs ?? [];
        
        // Debug logging
        for (var doc in docs) {
          final data = doc.data();
        }
        
        if (docs.isEmpty) {
          return _buildEmptyState(section);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final d = docs[index].data();
            final title = (d['title'] ?? '').toString();
            final desc = (d['description'] ?? '').toString();
            final thumb = (d['thumbnail'] ?? '').toString();
            final isLive = d['isLive'] == true;
            final isPaidContent = d['isPaidContent'] == true;
            final videoSection = (d['section'] ?? '').toString();
            final videoUrl = (d['videoUrl'] ?? d['url'] ?? '').toString();
            final views = (d['views'] ?? 0) as int;
            final likes = (d['likes'] ?? 0) as int;
            final videoId = docs[index].id;
            
            return _OnlineVideoCard(
              videoId: videoId,
              title: title, 
              description: desc, 
              thumbnail: thumb, 
              videoUrl: videoUrl,
              isLive: isLive,
              isPaidContent: isPaidContent,
              section: videoSection,
              views: views,
              likes: likes,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String section) {
    final sectionIcons = {
      'All': Icons.video_library,
      'Tutorials': Icons.school,
      'Choreography': Icons.directions_run,
      'Practice': Icons.fitness_center,
      'Live Recordings': Icons.live_tv,
      'Announcements': Icons.campaign,
    };

    final sectionDescriptions = {
      'All': 'No videos available yet',
      'Tutorials': 'No tutorial videos yet',
      'Choreography': 'No choreography videos yet', 
      'Practice': 'No practice videos yet',
      'Live Recordings': 'No live recordings yet',
      'Announcements': 'No announcements yet',
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            sectionIcons[section] ?? Icons.video_library,
            size: 64,
            color: const Color(0xFF6B7280),
          ),
          const SizedBox(height: 16),
          Text(
            sectionDescriptions[section] ?? 'No videos available',
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new content',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
class _OnlineVideoCard extends StatelessWidget {
  final String videoId;
  final String title;
  final String description;
  final String thumbnail;
  final String videoUrl;
  final bool isLive;
  final bool isPaidContent;
  final String section;
  final int views;
  final int likes;
  const _OnlineVideoCard({
    required this.videoId,
    required this.title, 
    required this.description, 
    required this.thumbnail, 
    required this.videoUrl,
    required this.isLive,
    required this.isPaidContent,
    required this.section,
    required this.views,
    required this.likes,
  });

  Future<bool> _getSubscriptionStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return false;
      }

      // Use a more efficient query with timeout
      final subscriptionSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .where('endDate', isGreaterThan: Timestamp.now())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 3));

      return subscriptionSnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use cached subscription status instead of StreamBuilder for each card
    return FutureBuilder<bool>(
      future: _getSubscriptionStatus(),
      builder: (context, subscriptionSnapshot) {
        final hasActiveSubscription = subscriptionSnapshot.hasData && 
            subscriptionSnapshot.data == true;
        
        // Lock only paid videos if subscription is missing
        final isLocked = isPaidContent && !hasActiveSubscription;

        return Card(
          elevation: 6,
          shadowColor: const Color(0xFF4F46E5).withOpacity( 0.15),
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isLocked 
                ? const Color(0xFFE53935).withOpacity(0.3)
                : const Color(0xFF4F46E5).withOpacity(0.22)
            ),
          ),
          child: InkWell(
            onTap: () {
              if (!isLocked) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      videoId: videoId,
                      title: title,
                      description: description,
                      videoUrl: videoUrl,
                      thumbnail: thumbnail,
                      isLive: isLive,
                      isPaidContent: isPaidContent,
                      section: section,
                      views: views,
                      likes: likes,
                    ),
                  ),
                );
              }
            },
            child: Stack(
              children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 120,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF262626),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: thumbnail.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                thumbnail, 
                                fit: BoxFit.cover,
                                color: isLocked ? Colors.grey : null,
                                colorBlendMode: isLocked ? BlendMode.saturation : null,
                              ),
                            )
                          : Icon(
                              Icons.play_circle_fill, 
                              color: isLocked ? Colors.grey : const Color(0xFFE53935), 
                              size: 32
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title.isEmpty ? 'Untitled' : title,
                                  style: TextStyle(
                                    color: isLocked ? Colors.grey : Colors.white, 
                                    fontWeight: FontWeight.w600
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isLive && !isLocked)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935).withOpacity( 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE53935).withOpacity( 0.5)),
                                  ),
                                  child: const Text('LIVE', style: TextStyle(color: Color(0xFFE53935), fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (section.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLocked 
                                  ? Colors.grey.withOpacity(0.2)
                                  : const Color(0xFF4F46E5).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                section,
                                style: TextStyle(
                                  color: isLocked ? Colors.grey : const Color(0xFF4F46E5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            description, 
                            style: TextStyle(
                              color: isLocked ? Colors.grey : Colors.white70, 
                              fontSize: 12
                            ), 
                            maxLines: 2, 
                            overflow: TextOverflow.ellipsis
                          ),
                          if (isLocked) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.lock,
                                  color: Colors.grey,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Subscribe to unlock',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
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
              ),
              if (isLocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.lock,
                            color: Color(0xFFE53935),
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Premium Content',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Subscribe to access all videos',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => const _SubscriptionPlansDialog(),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Subscribe Now',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
class _VideoSectionBuilder extends StatelessWidget {
  final String styleName;
  final IconData icon;
  final Color color;

  const _VideoSectionBuilder({
    required this.styleName,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null && !DemoSession.isActive) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              'Please login to view videos',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('onlineVideos')
          .where('section', isEqualTo: styleName)
          .where('status', isEqualTo: 'published')
          .snapshots(),
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading videos: ${snapshot.error}',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // Client-side sorting and limiting while index builds
        final sortedDocs = docs
          ..sort((a, b) {
            final aTime = a.data()['createdAt'] as Timestamp?;
            final bTime = b.data()['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // Descending order
          });
        
        final limitedDocs = sortedDocs.take(10).toList();

        if (limitedDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: color.withOpacity(0.5)),
                const SizedBox(height: 8),
                Text(
                  'No videos yet',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          key: ValueKey('videos_$styleName'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: limitedDocs.length,
          itemBuilder: (context, index) {
            final d = limitedDocs[index].data();
            final title = (d['title'] ?? '').toString();
            final desc = (d['description'] ?? '').toString();
            final thumb = (d['thumbnail'] ?? '').toString();
            final isLive = d['isLive'] == true;
            final isPaidContent = d['isPaidContent'] == true;
            final videoUrl = (d['videoUrl'] ?? d['url'] ?? '').toString();
            final views = (d['views'] ?? 0) as int;
            final likes = (d['likes'] ?? 0) as int;
            final videoId = limitedDocs[index].id;
            
            return Container(
              width: 180,
              height: 200,
              margin: const EdgeInsets.only(right: 12),
              child: _StyleVideoCard(
                videoId: videoId,
                title: title,
                description: desc,
                thumbnail: thumb,
                videoUrl: videoUrl,
                isLive: isLive,
                isPaidContent: isPaidContent,
                views: views,
                likes: likes,
                styleColor: color,
              ),
            );
          },
        );
      },
    );
  }
}

class _StyleVideoCard extends StatelessWidget {
  final String videoId;
  final String title;
  final String description;
  final String thumbnail;
  final String videoUrl;
  final bool isLive;
  final bool isPaidContent;
  final int views;
  final int likes;
  final Color styleColor;

  const _StyleVideoCard({
    required this.videoId,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.videoUrl,
    required this.isLive,
    required this.isPaidContent,
    required this.views,
    required this.likes,
    required this.styleColor,
  });

  Future<bool> _getSubscriptionStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return false;
      }

      // Use a more efficient query with timeout
      final subscriptionSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .where('endDate', isGreaterThan: Timestamp.now())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 3));

      return subscriptionSnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _getSubscriptionStatus(),
      builder: (context, subscriptionSnapshot) {
        final hasActiveSubscription = subscriptionSnapshot.hasData && 
            subscriptionSnapshot.data == true;
        
        // Lock only paid videos if subscription is missing
        final isLocked = isPaidContent && !hasActiveSubscription;

        return Card(
          elevation: 4,
          shadowColor: isLocked 
            ? const Color(0xFFE53935).withOpacity(0.15)
            : styleColor.withOpacity(0.15),
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isLocked 
                ? const Color(0xFFE53935).withOpacity(0.3)
                : styleColor.withOpacity(0.22)
            ),
          ),
          child: InkWell(
            onTap: () {
              if (!isLocked) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      videoId: videoId,
                      title: title,
                      description: description,
                      videoUrl: videoUrl,
                      thumbnail: thumbnail,
                      isLive: isLive,
                      isPaidContent: isPaidContent,
                      section: 'Style',
                      views: views,
                      likes: likes,
                    ),
                  ),
                );
              }
            },
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF262626),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: thumbnail.isNotEmpty
                            ? ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                child: Image.network(
                                  thumbnail, 
                                  fit: BoxFit.cover, 
                                  width: double.infinity,
                                  color: isLocked ? Colors.grey : null,
                                  colorBlendMode: isLocked ? BlendMode.saturation : null,
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.play_circle_fill, 
                                  color: isLocked ? Colors.grey : styleColor, 
                                  size: 32
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title.isEmpty ? 'Untitled' : title,
                              style: TextStyle(
                                color: isLocked ? Colors.grey : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isLocked) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.lock,
                                    color: Colors.grey,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Subscribe',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (isLive && !isLocked)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (isLocked)
                  Positioned.fill(
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => const _SubscriptionPlansDialog(),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock,
                                color: const Color(0xFFE53935),
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Subscribe',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Profile Tab
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
          );
        }

        final userData = snapshot.data?.data();
        final userRole = userData?['role'] ?? 'Student';

        // Pass the real-time role to ProfileScreen
        return ProfileScreen(role: userRole.toLowerCase());
      },
    );
  }
}

class _EnrolButton extends StatefulWidget {
  final String danceClassId;
  final String danceClassName;
  final bool isFull;
  final VoidCallback onBook;
  const _EnrolButton({required this.danceClassId, required this.danceClassName, required this.isFull, required this.onBook});

  @override
  State<_EnrolButton> createState() => _EnrolButtonState();
}
class _EnrolButtonState extends State<_EnrolButton> {

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/login');
        },
        icon: const Icon(Icons.login, size: 16),
        label: const Text('Login to Book'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
        ),
      );
    }
    
    // Check enrollment in user subcollection (primary) and global collection (fallback)
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('enrollments')
          .doc(widget.danceClassId)
          .snapshots(),
      builder: (context, userEnrollmentSnap) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
              .collection('enrollments')
          .where('userId', isEqualTo: user.uid)
          .where('itemId', isEqualTo: widget.danceClassId)
              .where('status', whereIn: ['enrolled', 'completed'])
              .limit(1)
          .snapshots(),
          builder: (context, globalEnrollmentSnap) {
            final userStatus = (userEnrollmentSnap.hasData && userEnrollmentSnap.data!.exists)
                ? (userEnrollmentSnap.data!.data()?['status'] as String?)
                : null;
            final userEnrolled = userStatus == 'enrolled' || userStatus == 'completed';
            final globalEnrolled = globalEnrollmentSnap.hasData && 
                globalEnrollmentSnap.data!.docs.isNotEmpty;
            final enrolled = userEnrolled || globalEnrolled;
            final isCompleted = userStatus == 'completed' || 
                (globalEnrollmentSnap.hasData && 
                 globalEnrollmentSnap.data!.docs.any((doc) => doc.data()['status'] == 'completed'));
        
        // Debug: Log enrollment status
            if (userEnrollmentSnap.hasData) {
              final userData = userEnrollmentSnap.data!.data();
            }
            if (globalEnrollmentSnap.hasData) {
              for (var doc in globalEnrollmentSnap.data!.docs) {
          }
        }
        if (enrolled) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: null,
                      icon: Icon(isCompleted ? Icons.check_circle_outline : Icons.check_circle, size: 14),
                      label: Text(isCompleted ? 'Completed' : 'Enrolled', style: const TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCompleted ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  if (!isCompleted) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: () => _showExitClassDialog(widget.danceClassId, widget.danceClassName),
                      icon: const Icon(Icons.exit_to_app, size: 14),
                      label: const Text('Exit Class', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  ],
                ],
              ),
            ],
          );
        }
        return ElevatedButton.icon(
          onPressed: widget.isFull ? null : widget.onBook,
          icon: const Icon(Icons.book_online, size: 16),
          label: Text(widget.isFull ? 'Full' : 'Join Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
          },
        );
      },
    );
  }

  void _showExitClassDialog(String classId, String className) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1B1B),
          title: const Text(
            'Exit Class',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to exit "$className"?\n\nThis action cannot be undone and you will lose access to this class.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _exitFromClass(classId, className);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Exit Class'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exitFromClass(String classId, String className) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFE53935),
          ),
        ),
      );

      // Find enrollment in global enrolments collection
      final enrollmentQuery = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('userId', isEqualTo: user.uid)
          .where('itemId', isEqualTo: classId)
          .where('status', whereIn: ['enrolled', 'completed'])
          .limit(1)
          .get();

      if (enrollmentQuery.docs.isEmpty) {
        Navigator.of(context).pop(); // Close loading
        _showErrorSnackBar('Enrollment not found');
        return;
      }

      final enrollmentDoc = enrollmentQuery.docs.first;
      final enrollmentData = enrollmentDoc.data();
      
      // Debug: Check if userId matches
      
      // Verify userId matches
      if (enrollmentData['userId'] != user.uid) {
        Navigator.of(context).pop(); // Close loading
        _showErrorSnackBar('User ID mismatch in enrollment record');
        return;
      }

      // Update enrollment status to 'unenrolled' using direct reference
      try {
        // First, ensure userId is set correctly
        await enrollmentDoc.reference.update({
          'userId': user.uid, // Ensure userId is set
          'status': 'unenrolled',
          'unenrolledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        Navigator.of(context).pop(); // Close loading
        _showErrorSnackBar('Error updating enrollment: $e');
        return;
      }

      // Also update user's subcollection if it exists
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('enrollments')
            .doc(classId)
            .update({
          'status': 'unenrolled',
          'unenrolledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // User subcollection might not exist, that's okay
      }

      // Also update legacy class_enrollments so admin/faculty list updates
      try {
        final classEnrollments = FirebaseFirestore.instance
            .collection('class_enrollments');
        final directQuery = await classEnrollments
            .where('classId', isEqualTo: classId)
            .where('user_id', isEqualTo: user.uid)
            .where('status', isEqualTo: 'active')
            .get();
        for (final doc in directQuery.docs) {
          await doc.reference.update({
            'status': 'unenrolled',
            'unenrolledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        final directQueryAlt = await classEnrollments
            .where('classId', isEqualTo: classId)
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'active')
            .get();
        for (final doc in directQueryAlt.docs) {
          await doc.reference.update({
            'status': 'unenrolled',
            'unenrolledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        final legacyQuery = await classEnrollments
            .where('class_id', isEqualTo: classId)
            .where('user_id', isEqualTo: user.uid)
            .where('status', isEqualTo: 'active')
            .get();
        for (final doc in legacyQuery.docs) {
          await doc.reference.update({
            'status': 'unenrolled',
            'unenrolledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        final legacyQueryAlt = await classEnrollments
            .where('class_id', isEqualTo: classId)
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'active')
            .get();
        for (final doc in legacyQueryAlt.docs) {
          await doc.reference.update({
            'status': 'unenrolled',
            'unenrolledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        // Ignore legacy enrollment update errors
      }

      // Decrement class enrollment count
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .update({
        'enrolledCount': FieldValue.increment(-1),
        'lastEnrollmentUpdate': FieldValue.serverTimestamp(),
      });

      // Trigger home stats update
      await _triggerHomeStatsUpdate(user.uid);
      
      // Emit class exit event for real-time updates
      EventController().emitEnrollmentRemoved(classId, user.uid);

      // Notification sending disabled

      // Close loading
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully exited $className'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      // Close loading
      Navigator.of(context).pop();
      _showErrorSnackBar('Error exiting class: $e');
    }
  }

  Future<void> _triggerHomeStatsUpdate(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('user_stats_triggers')
          .doc(userId)
          .set({
        'lastAttendanceUpdate': FieldValue.serverTimestamp(),
        'lastPaymentUpdate': FieldValue.serverTimestamp(),
        'userId': userId,
      }, SetOptions(merge: true));
    } catch (e) {
    }
  }

  /// Clean up invalid enrollments with non-existent class IDs
  Future<void> _cleanupInvalidEnrollments(String userId) async {
    try {
      final enrollmentsSnapshot = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'enrolled')
          .get();

      for (final enrollment in enrollmentsSnapshot.docs) {
        final data = enrollment.data();
        final itemId = data['itemId'];
        
        if (itemId != null && itemId.isNotEmpty && itemId != 'monthly') {
          try {
            final classDoc = await FirebaseFirestore.instance
                .collection('classes')
                .doc(itemId)
                .get();
            
            if (!classDoc.exists) {
              await enrollment.reference.update({
                'status': 'invalid',
                'invalidReason': 'Class not found',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (e) {
          }
        }
      }
    } catch (e) {
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Payment Status Card Widget with Session Tracking
/* Removed student Payment Status Card */
class _PaymentStatusCard extends StatefulWidget {
  final String? userId;

  const _PaymentStatusCard({
    this.userId,
  });

  @override
  State<_PaymentStatusCard> createState() => _PaymentStatusCardState();
}
class _PaymentStatusCardState extends State<_PaymentStatusCard> {
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;
  StreamSubscription<ClassEvent>? _classEventSubscription;
  final EventController _eventController = EventController();

  @override
  void initState() {
    super.initState();
    // Listen to payment success events for real-time updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (mounted && (event['type'] == 'payment_success' || event['type'] == 'enrollment_updated')) {
        setState(() {
          // Force rebuild when payment succeeds or enrollment updates
        });
      }
    });
    
    // Listen to class events for real-time updates (class exit, enrollment changes)
    _classEventSubscription = _eventController.eventStream.listen((event) {
      if (mounted && (event.type == ClassEventType.classDeleted || 
                     event.type == ClassEventType.enrollmentRemoved)) {
        setState(() {
          // Force rebuild when class is exited or enrollment is removed
        });
      }
    });
    
    // Clean up invalid enrollments on initialization
    if (widget.userId != null) {
      _cleanupInvalidEnrollmentsForUser(widget.userId!);
    }
  }

  @override
  void dispose() {
    _paymentRefreshSubscription?.cancel();
    _classEventSubscription?.cancel();
    super.dispose();
  }

  /// Clean up invalid enrollments with non-existent class IDs for this user
  Future<void> _cleanupInvalidEnrollmentsForUser(String userId) async {
    try {
      final enrollmentsSnapshot = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'enrolled')
          .get();

      for (final enrollment in enrollmentsSnapshot.docs) {
        final data = enrollment.data();
        final itemId = data['itemId'];
        
        if (itemId != null && itemId.isNotEmpty && itemId != 'monthly') {
          try {
            final classDoc = await FirebaseFirestore.instance
                .collection('classes')
                .doc(itemId)
                .get();
            
            if (!classDoc.exists) {
              await enrollment.reference.update({
                'status': 'invalid',
                'invalidReason': 'Class not found',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (e) {
          }
        }
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.userId != null
          ? FirebaseFirestore.instance
              .collection('enrollments')
              .where('userId', isEqualTo: widget.userId)
              .where('status', isEqualTo: 'enrolled')
              .orderBy('enrolledAt', descending: true)
              .snapshots()
          : null,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (snapshot.hasError) {
          return _buildErrorCard('Error loading enrollment data');
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          
          // Try multiple alternative queries
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('enrollments')
                .where('userId', isEqualTo: widget.userId)
                .where('status', isEqualTo: 'enrolled')
                .orderBy('enrolledAt', descending: true)
                .snapshots(),
            builder: (context, altSnapshot) {
              if (altSnapshot.hasData && altSnapshot.data!.docs.isNotEmpty) {
                final enrollment = altSnapshot.data!.docs.first;
                final enrollmentData = enrollment.data();
                
                
                final className = enrollmentData['className'] ?? 'Class';
                final totalSessions = enrollmentData['totalSessions'] ?? 8;
                final completedSessions = enrollmentData['completedSessions'] ?? 0;
                final remainingSessions = enrollmentData['remainingSessions'] ?? (totalSessions - completedSessions);
                final packagePrice = enrollmentData['packagePrice'] ?? 0.0;
                final paymentStatus = enrollmentData['paymentStatus'] ?? 'paid';
                final endDate = (enrollmentData['endDate'] as Timestamp?)?.toDate();
                final lastAttendanceDate = (enrollmentData['lastAttendanceDate'] as Timestamp?)?.toDate();
                
                
                return _buildPaymentCard(
                  context,
                  className: className,
                  completedSessions: completedSessions,
                  totalSessions: totalSessions,
                  remainingSessions: remainingSessions,
                  packagePrice: packagePrice,
                  paymentStatus: paymentStatus,
                  endDate: endDate,
                  lastAttendanceDate: lastAttendanceDate,
                  enrollmentId: enrollment.id,
                );
              }
              
              // Try class_enrollments collection as final fallback
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('class_enrollments')
                    .where('userId', isEqualTo: widget.userId)
                    .where('status', isEqualTo: 'active')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, classEnrollmentSnapshot) {
                  if (classEnrollmentSnapshot.hasData && classEnrollmentSnapshot.data!.docs.isNotEmpty) {
                    final enrollment = classEnrollmentSnapshot.data!.docs.first;
                    final enrollmentData = enrollment.data();
                    
                    final className = enrollmentData['className'] ?? 'Class';
                    final totalSessions = enrollmentData['totalSessions'] ?? 8;
                    final completedSessions = enrollmentData['completedSessions'] ?? 0;
                    final remainingSessions = enrollmentData['remainingSessions'] ?? (totalSessions - completedSessions);
                    final packagePrice = enrollmentData['packagePrice'] ?? 0.0;
                    final paymentStatus = enrollmentData['paymentStatus'] ?? 'paid';
                    final endDate = (enrollmentData['endDate'] as Timestamp?)?.toDate();
                    final lastAttendanceDate = (enrollmentData['lastAttendanceDate'] as Timestamp?)?.toDate();
                    
                    return _buildPaymentCard(
                      context,
                      className: className,
                      completedSessions: completedSessions,
                      totalSessions: totalSessions,
                      remainingSessions: remainingSessions,
                      packagePrice: packagePrice,
                      paymentStatus: paymentStatus,
                      endDate: endDate,
                      lastAttendanceDate: lastAttendanceDate,
                      enrollmentId: enrollment.id,
                    );
                  }
                  
                  return _buildNoClassesCard();
                },
              );
            },
          );
        }

        // Get the most recent active enrollment (already sorted by orderBy)
        final enrollments = snapshot.data!.docs;
        if (enrollments.isEmpty) {
          return _buildNoClassesCard();
        }

        // Filter out monthly packages and invalid enrollments
        final validEnrollments = enrollments.where((enrollment) {
          final data = enrollment.data();
          final itemId = data['itemId'];
          final itemType = data['itemType'];
          final status = data['status'];
          
          // Skip monthly packages and invalid enrollments
          if (itemId == 'monthly' || itemId == null) {
            return false;
          }
          
          // Only include actual class enrollments with 'enrolled' status (exclude invalid)
          final isValid = itemType == 'class' && 
                         itemId != null && 
                         itemId.isNotEmpty && 
                         status == 'enrolled' &&
                         status != 'invalid';
          
          if (!isValid) {
          }
          
          return isValid;
        }).toList();
        
        // Note: Invalid enrollment cleanup is handled in _cleanupInvalidEnrollmentsForUser()

        if (validEnrollments.isEmpty) {
          return _buildNoClassesCard();
        }

        final enrollment = validEnrollments.first;
        final enrollmentData = enrollment.data();


                // Extract enrollment data directly from enrolments collection
                final className = enrollmentData['itemType'] == 'class' 
                    ? (enrollmentData['className'] ?? enrollmentData['title'] ?? 'Class')
                    : (enrollmentData['title'] ?? enrollmentData['className'] ?? 'Class');
                
                // If className is still "Unknown Class", try to get actual class name
                String actualClassName = className;
                if (className == 'Unknown Class' || className == 'Class') {
                  // Try to get class name from actual class document
                  final itemId = enrollmentData['itemId'];
                  if (itemId != null && itemId != 'monthly') {
                    // This is a real class ID, fetch the actual class name
                    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance
                          .collection('classes')
                          .doc(itemId)
                          .get(),
                      builder: (context, classSnapshot) {
                        
                        if (classSnapshot.hasData && classSnapshot.data!.exists) {
                          final classData = classSnapshot.data!.data()!;
                          final realClassName = classData['name'] ?? classData['title'] ?? 'Class';
                          
                          return _buildPaymentCard(
                            context,
                            className: realClassName,
                            completedSessions: enrollmentData['completedSessions'] ?? 0,
                            totalSessions: enrollmentData['totalSessions'] ?? 8,
                            remainingSessions: (enrollmentData['totalSessions'] ?? 8) - (enrollmentData['completedSessions'] ?? 0),
                            packagePrice: (enrollmentData['amount'] ?? 0).toDouble(),
                            paymentStatus: enrollmentData['paymentStatus'] ?? 'paid',
                            endDate: (enrollmentData['endDate'] as Timestamp?)?.toDate(),
                            lastAttendanceDate: (enrollmentData['lastSessionAt'] as Timestamp?)?.toDate(),
                            enrollmentId: enrollment.id,
                          );
                        } else {
                          // Class document not found - show fallback
                          
                          // Try to find correct class ID from available classes
                          return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            future: FirebaseFirestore.instance
                                .collection('classes')
                                .where('isAvailable', isEqualTo: true)
                                .limit(1)
                                .get(),
                            builder: (context, classesSnapshot) {
                              if (classesSnapshot.hasData && classesSnapshot.data!.docs.isNotEmpty) {
                                final classDoc = classesSnapshot.data!.docs.first;
                                final classData = classDoc.data();
                                final correctClassName = classData['name'] ?? 'Class';
                                
                                return _buildPaymentCard(
                                  context,
                                  className: correctClassName,
                                  completedSessions: enrollmentData['completedSessions'] ?? 0,
                                  totalSessions: enrollmentData['totalSessions'] ?? 8,
                                  remainingSessions: (enrollmentData['totalSessions'] ?? 8) - (enrollmentData['completedSessions'] ?? 0),
                                  packagePrice: (enrollmentData['amount'] ?? 0).toDouble(),
                                  paymentStatus: enrollmentData['paymentStatus'] ?? 'paid',
                                  endDate: (enrollmentData['endDate'] as Timestamp?)?.toDate(),
                                  lastAttendanceDate: (enrollmentData['lastSessionAt'] as Timestamp?)?.toDate(),
                                  enrollmentId: enrollment.id,
                                );
                              }
                              
                              return _buildPaymentCard(
                                context,
                                className: 'Enrolled Class',
                                completedSessions: enrollmentData['completedSessions'] ?? 0,
                                totalSessions: enrollmentData['totalSessions'] ?? 8,
                                remainingSessions: (enrollmentData['totalSessions'] ?? 8) - (enrollmentData['completedSessions'] ?? 0),
                                packagePrice: (enrollmentData['amount'] ?? 0).toDouble(),
                                paymentStatus: enrollmentData['paymentStatus'] ?? 'paid',
                                endDate: (enrollmentData['endDate'] as Timestamp?)?.toDate(),
                                lastAttendanceDate: (enrollmentData['lastSessionAt'] as Timestamp?)?.toDate(),
                                enrollmentId: enrollment.id,
                              );
                            },
                          );
                          
                          // Try to find class by name or use fallback
                          return _buildPaymentCard(
                            context,
                            className: 'Enrolled Class',
                            completedSessions: enrollmentData['completedSessions'] ?? 0,
                            totalSessions: enrollmentData['totalSessions'] ?? 8,
                            remainingSessions: (enrollmentData['totalSessions'] ?? 8) - (enrollmentData['completedSessions'] ?? 0),
                            packagePrice: (enrollmentData['amount'] ?? 0).toDouble(),
                            paymentStatus: enrollmentData['paymentStatus'] ?? 'paid',
                            endDate: (enrollmentData['endDate'] as Timestamp?)?.toDate(),
                            lastAttendanceDate: (enrollmentData['lastSessionAt'] as Timestamp?)?.toDate(),
                            enrollmentId: enrollment.id,
                          );
                        }
                      },
                    );
                  } else {
                    actualClassName = 'Package Enrollment'; // For monthly packages
                  }
                }
                final totalSessions = enrollmentData['totalSessions'] ?? 8;
                final completedSessions = enrollmentData['completedSessions'] ?? 0;
                final remainingSessions = totalSessions - completedSessions;
                final packagePrice = (enrollmentData['amount'] ?? 0).toDouble();
                final paymentStatus = enrollmentData['paymentStatus'] ?? 'paid';
                final endDate = (enrollmentData['endDate'] as Timestamp?)?.toDate();
                final lastAttendanceDate = (enrollmentData['lastSessionAt'] as Timestamp?)?.toDate();
        
        return _buildPaymentCard(
          context,
          className: actualClassName,
          completedSessions: completedSessions,
          totalSessions: totalSessions,
          remainingSessions: remainingSessions,
          packagePrice: packagePrice,
          paymentStatus: paymentStatus,
          endDate: endDate,
          lastAttendanceDate: lastAttendanceDate,
          enrollmentId: enrollment.id,
        );
      },
    );
  }


  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(width: 16),
          Text(
            'Loading payment status...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoClassesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B7280), Color(0xFF9CA3AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.school_outlined, color: Colors.white, size: 24),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'No active enrollments',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(
    BuildContext context, {
    required String className,
    required int completedSessions,
    required int totalSessions,
    required int remainingSessions,
    required double packagePrice,
    required String paymentStatus,
    DateTime? endDate,
    DateTime? lastAttendanceDate,
    required String enrollmentId,
  }) {
    final progress = totalSessions > 0 ? completedSessions / totalSessions : 0.0;
    final isPaymentDue = remainingSessions <= 1 || (endDate != null && DateTime.now().isAfter(endDate));
    final isExpired = endDate != null && DateTime.now().isAfter(endDate);
    final needsPayment = paymentStatus == 'pending' || paymentStatus == 'failed';

    return Card(
      color: context != null ? Theme.of(context!).cardColor : const Color(0xFF1F2937),
      elevation: 8,
      shadowColor: (isPaymentDue ? const Color(0xFFDC2626) : const Color(0xFF374151)).withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: (isPaymentDue ? const Color(0xFFDC2626) : const Color(0xFF374151)).withValues(alpha: 0.4),
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
              context != null ? Theme.of(context!).cardColor : const Color(0xFF1F2937),
              context != null ? Theme.of(context!).cardColor.withValues(alpha: 0.8) : const Color(0xFF374151),
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
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPaymentDue ? Icons.warning_rounded : Icons.school_rounded,
                      color: isPaymentDue ? const Color(0xFFDC2626) : const Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isPaymentDue ? 'Payment Due!' : 'Payment Status',
                    style: const TextStyle(
                      color: Color(0xFFF9FAFB),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                className,
                style: const TextStyle(
                  color: Color(0xFFF9FAFB),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$completedSessions/$totalSessions sessions completed',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: (isPaymentDue ? const Color(0xFFDC2626) : const Color(0xFF3B82F6)).withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isPaymentDue ? const Color(0xFFDC2626) : const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPaymentDue 
                              ? 'Payment due: ₹${packagePrice.toInt()}'
                              : '$remainingSessions sessions left',
                          style: const TextStyle(
                            color: Color(0xFFF9FAFB),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (endDate != null)
                          Text(
                            isExpired 
                                ? 'Expired: ${_formatDate(endDate)}'
                                : 'Valid until: ${_formatDate(endDate)}',
                            style: TextStyle(
                              color: isExpired ? const Color(0xFFDC2626) : const Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                        if (lastAttendanceDate != null)
                          Text(
                            'Last attended: ${_formatDate(lastAttendanceDate)}',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isPaymentDue && context != null)
                    ElevatedButton(
                      onPressed: () => _handlePayment(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Pay Now',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference < 7) return 'In $difference days';
    if (difference < 30) return 'In ${(difference / 7).round()} weeks';
    return 'In ${(difference / 30).round()} months';
  }

  void _handlePayment(BuildContext context) async {
    // Navigate to payment screen or show payment dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Redirecting to payment...'),
        backgroundColor: Colors.orange,
      ),
    );
    
    // TODO: Navigate to payment screen with enrollment details
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (context) => PaymentScreen(enrollmentId: enrollmentId),
    // ));
  }
}

// Admin Stats Card Widget
class _AdminStatsCard extends StatefulWidget {
  final String? userId;

  const _AdminStatsCard({
    this.userId,
  });

  @override
  State<_AdminStatsCard> createState() => _AdminStatsCardState();
}

class _AdminStatsCardState extends State<_AdminStatsCard> {
  final EventController _eventController = EventController();
  StreamSubscription<ClassEvent>? _eventSubscription;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    // Listen to class events and refresh stats card
    _eventSubscription = _eventController.eventStream.listen((event) {
      if (mounted) {
        setState(() {
          _refreshKey++;
        });
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: ValueKey(_refreshKey),
      stream: widget.userId != null
          ? FirebaseFirestore.instance
              .collection('users')
              .snapshots()
          : null,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (!snapshot.hasData) {
          return _buildNoDataCard();
        }

        if (snapshot.hasError) {
          return _buildNoDataCard();
        }

        final users = snapshot.data!.docs;
        final totalStudents = users.where((doc) {
          final role = (doc.data()['role'] ?? '').toString().toLowerCase();
          return role == 'student';
        }).length;
        final totalFaculty = users.where((doc) {
          final role = (doc.data()['role'] ?? '').toString().toLowerCase();
          return role == 'faculty';
        }).length;
        
        // Get real active classes count
        return FutureBuilder<int>(
          future: _getActiveClassesCount(),
          builder: (context, classesSnapshot) {
            final activeClasses = classesSnapshot.data ?? 0;
            
            // Get real pending tasks count
            return FutureBuilder<int>(
              future: _getPendingTasksCount(),
              builder: (context, tasksSnapshot) {
                final pendingTasks = tasksSnapshot.data ?? 0;
                
                return _buildAdminCard(
                  context,
                  totalStudents: totalStudents,
                  totalFaculty: totalFaculty,
                  activeClasses: activeClasses,
                  pendingTasks: pendingTasks,
                );
              },
            );
          },
        );
      },
    );
  }


  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF374151), width: 1.5),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      ),
    );
  }

  Widget _buildNoDataCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF374151), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            color: const Color(0xFF8B5CF6),
            size: 24,
          ),
          const SizedBox(height: 8),
          const Text(
            'No Data Available',
            style: TextStyle(
              color: Color(0xFFF9FAFB),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Data will appear once users are added',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<int> _getActiveClassesCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('isAvailable', isEqualTo: true)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getPendingTasksCount() async {
    try {
      // Count pending attendance approvals
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('status', isEqualTo: 'pending')
          .get();
      
      // Count pending workshop approvals
      final workshopSnapshot = await FirebaseFirestore.instance
          .collection('workshops')
          .where('status', isEqualTo: 'pending')
          .get();
      
  // Count pending banner approvals
      final bannerSnapshot = await FirebaseFirestore.instance
          .collection('banners')
          .where('status', isEqualTo: 'pending')
          .get();
  
  // Count pending cash payments
  int cashCount = 0;
  try {
    final cashSnapshot = await FirebaseFirestore.instance
        .collection('approvals')
        .where('status', isEqualTo: 'pending')
        .where('type', isEqualTo: 'cash_payment')
        .get();
    cashCount = cashSnapshot.docs.length;
  } catch (e) {
  }
      
      return attendanceSnapshot.docs.length + 
             workshopSnapshot.docs.length + 
             bannerSnapshot.docs.length +
             cashCount;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildAdminCard(
    BuildContext? context, {
    required int totalStudents,
    required int totalFaculty,
    required int activeClasses,
    required int pendingTasks,
  }) {
    return Card(
      color: context != null ? Theme.of(context!).cardColor : const Color(0xFF1F2937),
      elevation: 8,
      shadowColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
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
              context != null ? Theme.of(context!).cardColor : const Color(0xFF1F2937),
              context != null ? Theme.of(context!).cardColor.withValues(alpha: 0.8) : const Color(0xFF374151),
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
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      color: Color(0xFFF9FAFB),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Students: $totalStudents',
                          style: const TextStyle(
                            color: Color(0xFFF9FAFB),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Faculty: $totalFaculty',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Classes: $activeClasses',
                          style: const TextStyle(
                            color: Color(0xFFF9FAFB),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pending: $pendingTasks',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (totalStudents + totalFaculty) / 200, // Assuming max 200 total users
                backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Compact Icon Grid Widget
Widget _buildCompactIconGrid(BuildContext context, String role) {
  // For student role: align Attendance with Workshops (left), Payment with Updates (right)
  // For faculty role: align Attendance with Workshops (left), Students with Updates (right)
  // For admin: move icons slightly to the right
  if (role == 'student') {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Attendance icon aligned with Workshops card (left column) - moved more left
        Expanded(
            child: Transform.translate(
              offset: const Offset(-8, 0), // Move Attendance icon to the left
          child: _buildCompactAttendanceIcon(
            context: context,
            userId: FirebaseAuth.instance.currentUser?.uid,
          ),
        ),
          ),
          const SizedBox(width: 12), // Match grid crossAxisSpacing
          // Payment icon aligned with Updates card (right column) - moved a bit right
        Expanded(
            child: Transform.translate(
              offset: const Offset(8, 0), // Move Payment icon to the right
          child: _buildCompactIconItem(
            context: context,
            title: 'Payment',
            icon: Icons.payment_rounded,
            color: const Color(0xFFF59E0B),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PaymentHistoryScreen(),
              ),
            ),
          ),
        ),
          ),
        ],
      ),
    );
  } else if (role == 'faculty') {
    // For faculty: align Attendance with Workshops (left), Students with Updates (right)
    // Build items directly without Expanded wrapper to avoid nesting
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Attendance icon aligned with Workshops card (left column) - moved more left
        Expanded(
            child: Transform.translate(
              offset: const Offset(-8, 0), // Move Attendance icon to the left
          child: _buildCompactIconItem(
            context: context,
            title: 'Attendance',
            icon: Icons.qr_code_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QRScannerScreen(),
              ),
            ),
          ),
        ),
          ),
          const SizedBox(width: 12), // Match grid crossAxisSpacing
          // Students icon aligned with Updates card (right column) - moved a bit right
        Expanded(
            child: Transform.translate(
              offset: const Offset(8, 0), // Move Students icon to the right
          child: _buildCompactIconItem(
            context: context,
            title: 'Students',
            icon: Icons.people_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentManagementScreen(),
              ),
            ),
          ),
        ),
          ),
        ],
      ),
    );
  } else {
    // For admin: move icons slightly to the right
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.only(left: 20), // Shift right
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: _getCompactIconItems(context, role),
      ),
    );
  }
}
List<Widget> _getCompactIconItems(BuildContext context, String role) {
  switch (role) {
    case 'student':
      return [
        Expanded(
          child: _buildCompactAttendanceIcon(
            context: context,
            userId: FirebaseAuth.instance.currentUser?.uid,
          ),
        ),
        Expanded(
          child: _buildCompactIconItem(
            context: context,
            title: 'Payment',
            icon: Icons.payment_rounded,
            color: const Color(0xFFF59E0B),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PaymentHistoryScreen(),
              ),
            ),
          ),
        ),
      ];
    case 'faculty':
      return [
        Expanded(
          child: _buildCompactIconItem(
            context: context,
            title: 'Attendance',
            icon: Icons.qr_code_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QRScannerScreen(),
              ),
            ),
          ),
        ),
        Expanded(
          child: _buildCompactIconItem(
            context: context,
            title: 'Students',
            icon: Icons.people_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentManagementScreen(),
              ),
            ),
          ),
        ),
      ];
    case 'admin':
      return [
        Expanded(
          child: _buildCompactIconItem(
            context: context,
            title: 'Attendance',
            icon: Icons.qr_code_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttendanceScreen(role: 'admin'),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildCompactIconItem(
            context: context,
            title: 'Students',
            icon: Icons.people_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentManagementScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildCompactIconItem(
            context: context,
            title: 'Reports',
            icon: Icons.analytics_rounded,
            color: const Color(0xFFF59E0B),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminLiveDashboard(),
              ),
            ),
          ),
        ),
      ];
    default:
      return [];
  }
}

// Real-time attendance icon with session tracking
Widget _buildCompactAttendanceIcon({
  required BuildContext context,
  required String? userId,
}) {
  if (userId == null) {
    return _buildCompactIconItem(
      context: context,
      title: 'Attendance',
      icon: Icons.qr_code_rounded,
      color: const Color(0xFF3B82F6),
      onTap: () {},
    );
  }

  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('enrollments')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'enrolled')
        .orderBy('enrolledAt', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      int totalSessions = 0;
      int completedSessions = 0;
      bool hasActiveEnrollment = false;

      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
        hasActiveEnrollment = true;
        for (final doc in snapshot.data!.docs) {
          final data = doc.data();
          totalSessions += (data['totalSessions'] ?? 0) as int;
          completedSessions += (data['completedSessions'] ?? 0) as int;
        }
      } else {
        // Try alternative query with userId field
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('enrollments')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'enrolled')
              .orderBy('enrolledAt', descending: true)
              .snapshots(),
          builder: (context, altSnapshot) {
            int altTotalSessions = 0;
            int altCompletedSessions = 0;
            bool altHasActiveEnrollment = false;

            if (altSnapshot.hasData && altSnapshot.data!.docs.isNotEmpty) {
              altHasActiveEnrollment = true;
              for (final doc in altSnapshot.data!.docs) {
                final data = doc.data();
                altTotalSessions += (data['totalSessions'] ?? 0) as int;
                altCompletedSessions += (data['completedSessions'] ?? 0) as int;
              }
            }

            final altProgress = altTotalSessions > 0 ? (altCompletedSessions / altTotalSessions) : 0.0;
            final altRemainingSessions = altTotalSessions - altCompletedSessions;

            return _buildCompactIconItem(
              context: context,
              title: altHasActiveEnrollment ? 'Attendance\n$altCompletedSessions/$altTotalSessions' : 'Attendance',
              icon: Icons.qr_code_rounded,
              color: altHasActiveEnrollment 
                  ? (altRemainingSessions <= 2 ? const Color(0xFFEF4444) : const Color(0xFF3B82F6))
                  : const Color(0xFF6B7280),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QRDisplayScreen(role: 'student'),
                ),
              ),
              badge: altHasActiveEnrollment && altRemainingSessions <= 2 ? altRemainingSessions.toString() : null,
            );
          },
        );
      }

      final progress = totalSessions > 0 ? (completedSessions / totalSessions) : 0.0;
      final remainingSessions = totalSessions - completedSessions;

      return _buildCompactIconItem(
        context: context,
        title: hasActiveEnrollment ? 'Attendance\n$completedSessions/$totalSessions' : 'Attendance',
        icon: Icons.qr_code_rounded,
        color: hasActiveEnrollment 
            ? (remainingSessions <= 2 ? const Color(0xFFEF4444) : const Color(0xFF3B82F6))
            : const Color(0xFF6B7280),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QRDisplayScreen(role: 'student'),
          ),
        ),
        badge: hasActiveEnrollment && remainingSessions <= 2 ? remainingSessions.toString() : null,
      );
    },
  );
}

Widget _buildCompactIconItem({
  required BuildContext context,
  required String title,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
  String? badge,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Stack(
      children: [
        Container(
          height: 64, // Fixed height for consistent sizing
          width: double.infinity, // Take full width of Expanded parent
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                title,
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (badge != null)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              constraints: const BoxConstraints(
                minWidth: 14,
                minHeight: 14,
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    ),
  );
}

// Style Management Modal
class _StyleManagementModal extends StatefulWidget {
  final List<String> categories;
  final VoidCallback onCategoriesUpdated;

  const _StyleManagementModal({
    required this.categories,
    required this.onCategoriesUpdated,
  });

  @override
  State<_StyleManagementModal> createState() => _StyleManagementModalState();
}

class _StyleManagementModalState extends State<_StyleManagementModal> {
  final TextEditingController _newStyleController = TextEditingController();
  final TextEditingController _editStyleController = TextEditingController();
  String? _editingStyle;
  bool _isLoading = false;

  @override
  void dispose() {
    _newStyleController.dispose();
    _editStyleController.dispose();
    super.dispose();
  }

  Future<void> _addNewStyle() async {
    final styleName = _newStyleController.text.trim();
    if (styleName.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final newStyle = DanceStyle(
        id: '', // Will be set by Firestore
        name: styleName,
        description: '',
        icon: 'directions_run',
        color: '#E53935',
        isActive: true,
        priority: 0,
        createdAt: now,
        updatedAt: now,
      );
      
      await ClassStylesService.addStyle(newStyle);
      _newStyleController.clear();
      widget.onCategoriesUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Style added successfully!'),
            backgroundColor: Color(0xFFE53935),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding style: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editStyle(String oldName, String newName) async {
    if (newName.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Find the style by name and update it
      final styles = await ClassStylesService.getAllStylesForAdmin();
      final styleToUpdate = styles.firstWhere(
        (style) => style.name == oldName,
        orElse: () => throw Exception('Style not found'),
      );
      
      final updatedStyle = DanceStyle(
        id: styleToUpdate.id,
        name: newName,
        description: styleToUpdate.description,
        icon: styleToUpdate.icon,
        color: styleToUpdate.color,
        isActive: styleToUpdate.isActive,
        priority: styleToUpdate.priority,
        createdAt: styleToUpdate.createdAt,
        updatedAt: DateTime.now(),
      );
      
      await ClassStylesService.updateStyle(styleToUpdate.id, updatedStyle);
      
      _editStyleController.clear();
      setState(() {
        _editingStyle = null;
      });
      widget.onCategoriesUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Style updated successfully!'),
            backgroundColor: Color(0xFFE53935),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating style: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteStyle(String styleName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text(
          'Delete Style',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "$styleName"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await ClassStylesService.deleteStyle(styleName);
        widget.onCategoriesUpdated();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Style deleted successfully!'),
              backgroundColor: Color(0xFFE53935),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting style: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

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
              color: Colors.white.withOpacity(0.3),
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
                    'Manage Dance Styles',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
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
          // Add new style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newStyleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Add new dance style...',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE53935)),
                      ),
                    ),
                    onSubmitted: (_) => _addNewStyle(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _addNewStyle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.add),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Styles list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.categories.length,
              itemBuilder: (context, index) {
                final style = widget.categories[index];
                final isEditing = _editingStyle == style;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: const Color(0xFF2A2A2A),
                  child: ListTile(
                    title: isEditing
                        ? TextField(
                            controller: _editStyleController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white30),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFE53935)),
                              ),
                            ),
                            onSubmitted: (value) => _editStyle(style, value),
                          )
                        : Text(
                            style,
                            style: const TextStyle(color: Colors.white),
                          ),
                    trailing: isEditing
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _editStyle(style, _editStyleController.text),
                                icon: const Icon(Icons.check, color: Colors.green),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _editingStyle = null;
                                    _editStyleController.clear();
                                  });
                                },
                                icon: const Icon(Icons.close, color: Colors.red),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _editingStyle = style;
                                    _editStyleController.text = style;
                                  });
                                },
                                icon: const Icon(Icons.edit, color: Color(0xFFE53935)),
                              ),
                              IconButton(
                                onPressed: () => _deleteStyle(style),
                                icon: const Icon(Icons.delete, color: Colors.red),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Subscription Plans Bottom Sheet
class _SubscriptionPlansBottomSheet extends StatefulWidget {
  const _SubscriptionPlansBottomSheet();

  @override
  State<_SubscriptionPlansBottomSheet> createState() => _SubscriptionPlansBottomSheetState();
}
class _SubscriptionPlansBottomSheetState extends State<_SubscriptionPlansBottomSheet> {
  bool _isLoading = false;

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
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.subscriptions, color: Color(0xFFE53935), size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Choose Your Plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),
          // Plans list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('subscription_plans')
                  .where('active', isEqualTo: true)
                  .orderBy('priority')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
                }

                final plans = snapshot.data?.docs ?? [];
                if (plans.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.subscriptions, size: 64, color: Color(0xFF6B7280)),
                        SizedBox(height: 16),
                        Text(
                          'No subscription plans available',
                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final plan = plans[index].data();
                    final planId = plans[index].id;
                    return _SubscriptionPlanCard(
                      planId: planId,
                      name: plan['name'] ?? 'Plan',
                      price: plan['price'] ?? 0,
                      billingCycle: plan['billingCycle'] ?? 'monthly',
                      description: plan['description'] ?? '',
                      priority: plan['priority'] ?? 0,
                      trialDays: plan['trialDays'] ?? 0,
                      onSubscribe: () => _handleSubscribe(planId, plan),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubscribe(String planId, Map<String, dynamic> plan) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Please login to subscribe');
        return;
      }

      final amount = (plan['price'] as num).toInt();
      final name = plan['name'] ?? 'Subscription Plan';
      final billingCycle = plan['billingCycle'] ?? 'monthly';
      final explicitProductId = (plan['storeProductId'] ??
              plan['productId'] ??
              plan['playProductId'] ??
              plan['appStoreProductId'])
          ?.toString();
      final productId = IapService.resolveProductId(
        billingCycle: billingCycle.toString(),
        explicitId: explicitProductId,
        planId: planId,
      );

      if (productId.isEmpty) {
        _showError('Subscription product is not configured yet.');
        return;
      }

      final result = await IapService.instance.purchaseSubscription(
        productId: productId,
        metadata: {
          'planId': planId,
          'planName': name,
          'billingCycle': billingCycle,
          'amount': amount,
        },
      );

      if (result['success'] == true) {
        _showSuccess('Complete the purchase to activate your subscription.');
        Navigator.pop(context);
        // Force refresh of the online screen
        if (mounted) {
          setState(() {
            // This will trigger a rebuild of the online screen
          });
        }
      } else {
        _showError(result['message'] ?? 'Payment failed');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SubscriptionPlanCard extends StatelessWidget {
  final String planId;
  final String name;
  final int price;
  final String billingCycle;
  final String description;
  final int priority;
  final int trialDays;
  final VoidCallback onSubscribe;

  const _SubscriptionPlanCard({
    required this.planId,
    required this.name,
    required this.price,
    required this.billingCycle,
    required this.description,
    required this.priority,
    required this.trialDays,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final isPopular = priority == 1;
    final cycleText = billingCycle == 'annual' ? 'year' : 
                     billingCycle == 'quarterly' ? 'quarter' : 'month';

    return Card(
      elevation: isPopular ? 8 : 4,
      shadowColor: isPopular ? const Color(0xFFE53935).withOpacity(0.3) : const Color(0xFF4F46E5).withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPopular ? const Color(0xFFE53935).withOpacity(0.5) : const Color(0xFF4F46E5).withOpacity(0.22),
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Container(
        decoration: isPopular ? BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFE53935).withOpacity(0.1),
              const Color(0xFF4F46E5).withOpacity(0.05),
            ],
          ),
        ) : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isPopular)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'POPULAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '₹$price',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/$cycleText',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              if (trialDays > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '$trialDays days free trial',
                  style: TextStyle(
                    color: const Color(0xFF10B981),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular ? const Color(0xFFE53935) : const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Subscribe Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
}

// Subscription Plans Dialog
class _SubscriptionPlansDialog extends StatefulWidget {
  const _SubscriptionPlansDialog();

  @override
  State<_SubscriptionPlansDialog> createState() => _SubscriptionPlansDialogState();
}

class _SubscriptionPlansDialogState extends State<_SubscriptionPlansDialog> {
  bool _isMonthlyLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.subscriptions,
                    color: Color(0xFFE53935),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Choose Your Plan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
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
              const SizedBox(height: 6),
              const Text(
                'Unlock all online dance videos',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              
              // Monthly Plan (single plan)
              _PlanCard(
                name: 'Monthly Plan',
                price: 900,
                cycle: 'month',
                description: 'Access all videos for 1 month',
                isPopular: true,
                onSubscribe: _handleSubscribe,
                isLoading: _isMonthlyLoading,
              ),
              
              const SizedBox(height: 16),
              
              // Features
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 8),
                        Text('Unlimited video access', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 8),
                        Text('HD quality videos', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 8),
                        Text('Offline downloads', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 8),
                        Text('Auto-renewal', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
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
  }

  Future<void> _handleSubscribe() async {
    if (_isMonthlyLoading) return;
    setState(() {
      _isMonthlyLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Please login to subscribe');
        return;
      }
      final result = await OnlineSubscriptionService.purchaseMonthly();

      if (result['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Subscription activated successfully.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        _showError(result['message'] ?? 'Subscription failed. Please try again.');
      }
    } catch (e) {
      _showError('Payment failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isMonthlyLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
      ),
    );
  }
}

// Individual Plan Card
class _PlanCard extends StatelessWidget {
  final String name;
  final int price;
  final String cycle;
  final String description;
  final bool isPopular;
  final VoidCallback onSubscribe;
  final bool isLoading;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.cycle,
    required this.description,
    required this.isPopular,
    required this.onSubscribe,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isPopular ? const Color(0xFFE53935).withOpacity(0.1) : const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? const Color(0xFFE53935).withOpacity(0.5) : const Color(0xFF4F46E5).withOpacity(0.3),
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'BEST VALUE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '₹$price',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/$cycle',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSubscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPopular ? const Color(0xFFE53935) : const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Subscribe for ₹$price',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
/* Removed Today's Stats Card for Students */
class _TodayStatsCard extends StatelessWidget {
  final String? userId;

  const _TodayStatsCard({this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 6,
      shadowColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
      color: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.today_rounded,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Today\'s Overview',
                  style: TextStyle(
                    color: Color(0xFFF9FAFB),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('enrollments')
                  .where('userId', isEqualTo: userId)
                  .where('status', isEqualTo: 'enrolled')
                  .snapshots(),
              builder: (context, enrollmentSnapshot) {
                if (enrollmentSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF3B82F6),
                      strokeWidth: 2,
                    ),
                  );
                }

                if (!enrollmentSnapshot.hasData || enrollmentSnapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No enrolled classes today',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                final enrollments = enrollmentSnapshot.data!.docs;
                // Filter for class enrollments only (client-side filtering)
                final classEnrollments = enrollments
                    .where((doc) => doc.data()['itemType'] == 'class')
                    .toList();
                final classIds = classEnrollments.map((doc) => doc.data()['itemId'] as String).toList();

                // Handle empty classIds to avoid whereIn error
                if (classIds.isEmpty) {
                  return const Center(
                    child: Text(
                      'No enrolled classes today',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('classes')
                      .where(FieldPath.documentId, whereIn: classIds)
                      .where('isAvailable', isEqualTo: true)
                      .snapshots(),
                  builder: (context, classesSnapshot) {
                    if (classesSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF3B82F6),
                          strokeWidth: 2,
                        ),
                      );
                    }

                    final classes = classesSnapshot.data?.docs ?? [];
                    final today = DateTime.now();
                    final todayClasses = classes.where((classDoc) {
                      final data = classDoc.data();
                      final dateTime = data['dateTime'] as Timestamp?;
                      if (dateTime != null) {
                        final classDate = dateTime.toDate();
                        return classDate.year == today.year &&
                               classDate.month == today.month &&
                               classDate.day == today.day;
                      }
                      return false;
                    }).toList();

                    final todayClassIds = todayClasses.map((doc) => doc.id).toList();

                    // Handle empty todayClassIds to avoid whereIn error
                    if (todayClassIds.isEmpty) {
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enrolled Today',
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '0',
                                  style: const TextStyle(
                                    color: Color(0xFFF9FAFB),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attended Today',
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '0',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('attendance')
                          .where('userId', isEqualTo: userId)
                          .where('classId', whereIn: todayClassIds)
                          .where('markedAt', isGreaterThan: Timestamp.fromDate(
                            DateTime(today.year, today.month, today.day),
                          ))
                          .snapshots(),
                      builder: (context, attendanceSnapshot) {
                        final attendedToday = attendanceSnapshot.data?.docs.length ?? 0;
                        final enrolledToday = todayClasses.length;

                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enrolled Today',
                                    style: const TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$enrolledToday',
                                    style: const TextStyle(
                                      color: Color(0xFFF9FAFB),
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Attended Today',
                                    style: const TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$attendedToday',
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}