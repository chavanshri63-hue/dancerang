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
import '../utils/error_handler.dart';
import '../services/branches_service.dart';
import '../models/banner_model.dart';
import '../services/event_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_config_service.dart';
import '../config/demo_session.dart';
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
import 'live_streaming_screen.dart';
import 'ai_recommendations_screen.dart';
import 'offline_downloads_screen.dart';
import 'single_class_booking_screen.dart';
import 'package_booking_screen.dart';
import '../models/class_enrollment_model.dart';
import '../services/live_notification_service.dart';
import '../services/class_enrollment_service.dart';

part 'tabs/home_tab.dart';
part 'tabs/classes_tab.dart';
part 'tabs/studio_tab.dart';
part 'tabs/online_tab.dart';
part 'tabs/profile_tab.dart';

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


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void switchToTab(int index) {
    if (index >= 0 && index < 5) {
      setState(() {
        _currentIndex = index;
      });
    }
  }
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
