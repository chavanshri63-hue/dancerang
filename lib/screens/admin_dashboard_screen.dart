import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/app_config_service.dart';
import 'admin_background_management_screen.dart';
import 'notifications_screen.dart';
import 'student_management_screen.dart';
import 'faculty_management_screen.dart';
import 'my_workshops_screen.dart';
import 'gallery_screen.dart';
import 'updates_screen.dart';
import 'admin_classes_management_screen.dart';
import 'event_choreography_screen.dart';
import 'admin_about_management_screen.dart';
import '../services/live_metrics_service.dart';
import 'admin_bookings_screen.dart';
import 'admin_feed_screen.dart';
import 'admin_finance_collections_screen.dart';
import 'admin_online_management_screen.dart';
import '../models/banner_model.dart';
import '../services/admin_service.dart';
import '../services/branches_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AppConfigService _config = AppConfigService();
  final TextEditingController _waController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _waController.text = _config.studioWhatsAppNumber;
  }

  @override
  void dispose() {
    _waController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: const GlassmorphismAppBar(title: 'Admin Dashboard'),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: uid == null
            ? const Stream.empty()
            : FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          final role = (snapshot.data?.data()?['role'] ?? '').toString();
          final isAdmin = role.toLowerCase() == 'admin';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _summaryRow(),
              const SizedBox(height: 16),
              if (isAdmin) _liveAnalyticsSection(),
              if (isAdmin) const SizedBox(height: 16),
              if (isAdmin) _controlsCard(),
              if (!isAdmin)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Limited access: admin-only tools are hidden for your role.',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _liveAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.analytics, color: Color(0xFFE53935)),
            const SizedBox(width: 8),
            const Text(
              'Live Analytics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Cash revenue metrics
        Card(
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<Map<String, dynamic>>(
              stream: LiveMetricsService.getLiveRevenueMetrics(),
              builder: (context, snapshot) {
                final metrics = snapshot.data ?? const {
                  'cashToday': 0,
                  'cashWeek': 0,
                  'cashMonth': 0,
                  'cashTotal': 0,
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.payments_outlined, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text('Cash Revenue', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _metricTile('Today', '₹${metrics['cashToday']}', const Color(0xFF42A5F5))),
                        const SizedBox(width: 12),
                        Expanded(child: _metricTile('Week', '₹${metrics['cashWeek']}', const Color(0xFF10B981))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _metricTile('Month', '₹${metrics['cashMonth']}', const Color(0xFFFFB300))),
                        const SizedBox(width: 12),
                        Expanded(child: _metricTile('Total', '₹${metrics['cashTotal']}', const Color(0xFF4F46E5))),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Online revenue metrics
        Card(
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<Map<String, dynamic>>(
              stream: LiveMetricsService.getLiveRevenueMetrics(),
              builder: (context, snapshot) {
                final m = snapshot.data ?? const {
                  'onlineTotal': 0,
                  'onlineToday': 0,
                  'onlineWeek': 0,
                  'onlineMonth': 0,
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.currency_rupee, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text('Online Revenue', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _metricTile('Today', '₹${m['onlineToday']}', const Color(0xFF10B981))),
                        const SizedBox(width: 12),
                        Expanded(child: _metricTile('Week', '₹${m['onlineWeek']}', const Color(0xFF42A5F5))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _metricTile('Month', '₹${m['onlineMonth']}', const Color(0xFFFFB300))),
                        const SizedBox(width: 12),
                        Expanded(child: _metricTile('Total', '₹${m['onlineTotal']}', const Color(0xFFE53935))),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        // User activity metrics
        Card(
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<Map<String, dynamic>>(
              stream: LiveMetricsService.getLiveUserActivity(),
              builder: (context, snapshot) {
                final a = snapshot.data ?? const {
                  'totalUsers': 0,
                  'activeUsers': 0,
                  'newUsersToday': 0,
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.people_alt, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text('User Activity', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _metricTile('Total Users', '${a['totalUsers']}', const Color(0xFF42A5F5))),
                        const SizedBox(width: 12),
                        Expanded(child: _metricTile('Active (7d)', '${a['activeUsers']}', const Color(0xFF10B981))),
                        const SizedBox(width: 12),
                        Expanded(child: _metricTile('New Today', '${a['newUsersToday']}', const Color(0xFFFFB300))),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
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
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow() {
    return Column(
      children: [
        Row(
          children: [
            // Total Students (live)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'Student')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.size ?? 0;
                  return _statCard('Total Students', '$count', Icons.people, const Color(0xFF42A5F5));
                },
              ),
            ),
            const SizedBox(width: 12),
            // Active Classes (live today)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('classes')
                    .where('isAvailable', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  final total = snapshot.data?.docs.length ?? 0;
                  return _statCard('Active Classes', '$total', Icons.school, const Color(0xFFFF9800));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Total Collections (live)
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('payments')
              .where('status', whereIn: ['success', 'paid'])
              .snapshots(),
          builder: (context, snapshot) {
            int total = 0;
            for (final d in snapshot.data?.docs ?? []) {
              final data = d.data() as Map<String, dynamic>;
              total += (data['amount'] ?? 0) is num ? (data['amount'] as num).toInt() : 0;
            }
            return _statCard('Total Collections', '₹$total', Icons.payments, const Color(0xFF10B981));
          },
        ),
        const SizedBox(height: 12),
        // Total Enrollments (live) - canonical first with legacy fallback
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('enrollments')
              .where('status', isEqualTo: 'enrolled')
              .snapshots(),
          builder: (context, snapshot) {
            final primaryCount = snapshot.data?.size ?? 0;
            if (primaryCount > 0 || snapshot.connectionState == ConnectionState.waiting) {
              final count = primaryCount;
              return _statCard('Total Enrollments', '$count', Icons.school_outlined, const Color(0xFF9C27B0));
            }
            // Fallback to class enrollments if primary is empty
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('class_enrollments')
                  .where('status', isEqualTo: 'active')
                  .snapshots(),
              builder: (context, legacy) {
                final count = legacy.data?.size ?? 0;
                return _statCard('Total Enrollments', '$count', Icons.school_outlined, const Color(0xFF9C27B0));
              },
            );
          },
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color accent) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value, 
              style: TextStyle(
                color: accent, 
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title, 
              style: const TextStyle(
                color: Colors.white70, 
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlsCard() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin Controls', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildControlGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlGrid() {
    final controls = [
      _ControlItem('Manage Backgrounds', Icons.photo_library, const Color(0xFF10B981), () => _navigateToBackgrounds()),
      _ControlItem('Manage Notifications', Icons.notifications, const Color(0xFFFF9800), () => _navigateToNotifications()),
      _ControlItem('Student Management', Icons.people, const Color(0xFF9C27B0), () => _navigateToStudents()),
      _ControlItem('Faculty Management', Icons.person_outline, const Color(0xFF3F51B5), () => _navigateToFaculty()),
      _ControlItem('Classes Management', Icons.school, const Color(0xFFFFC107), () => _navigateToClasses()),
      _ControlItem('Online Classes Management', Icons.video_library, const Color(0xFF2196F3), () => _navigateToOnlineManagement()),
      _ControlItem('Workshop Management', Icons.event, const Color(0xFFE53935), () => _navigateToWorkshops()),
      _ControlItem('Gallery Management', Icons.photo_camera, const Color(0xFF00BCD4), () => _navigateToGallery()),
      _ControlItem('Updates Management', Icons.update, const Color(0xFF795548), () => _navigateToUpdates()),
      _ControlItem('Event Choreography', Icons.event, const Color(0xFFFF5722), () => _navigateToEvents()),
      _ControlItem('Bookings', Icons.calendar_month, const Color(0xFF00C853), () => _navigateToBookings()),
      _ControlItem('Feed', Icons.photo_library_outlined, const Color(0xFF8E24AA), () => _navigateToFeed()),
      _ControlItem('About Us Management', Icons.info, const Color(0xFF3F51B5), () => _navigateToAboutUs()),
      _ControlItem('Studio Management', Icons.business, const Color(0xFFE91E63), () => _navigateToStudioManagement()),
      _ControlItem('Finance & Collections', Icons.account_balance_wallet, const Color(0xFF607D8B), () => _navigateToFinance()),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: controls.length,
      itemBuilder: (context, index) {
        final control = controls[index];
        return _buildControlItem(control);
      },
    );
  }

  Widget _buildControlItem(_ControlItem control) {
    return InkWell(
      onTap: control.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: control.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: control.color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(control.icon, color: control.color, size: 28),
            const SizedBox(height: 8),
            Text(
              control.title,
              style: TextStyle(
                color: control.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Navigation methods
  // Removed Manage Banners navigation per request

  void _navigateToBackgrounds() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminBackgroundManagementScreen()),
    );
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
  }

  void _navigateToStudents() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StudentManagementScreen()),
    );
  }

  void _navigateToFaculty() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FacultyManagementScreen()),
    );
  }

  void _navigateToWorkshops() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyWorkshopsScreen(role: 'admin')),
    );
  }

  void _navigateToGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GalleryScreen(role: 'admin')),
    );
  }

  void _navigateToUpdates() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UpdatesScreen(role: 'admin')),
    );
  }

  void _navigateToClasses() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminClassesManagementScreen()),
    );
  }

  void _navigateToOnlineManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminOnlineManagementScreen()),
    );
  }

  void _navigateToEvents() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EventChoreographyScreen(role: 'admin')),
    );
  }

  void _navigateToBookings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminBookingsScreen()),
    );
  }

  void _navigateToFeed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminFeedScreen()),
    );
  }

  void _navigateToAboutUs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminAboutManagementScreen()),
    );
  }

  void _navigateToStudioManagement() {
    showDialog(
      context: context,
      builder: (context) => _StudioManagementDialog(),
    );
  }

  // Studio Management Section
  Widget _buildStudioManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.business, color: Color(0xFFE91E63), size: 20),
            const SizedBox(width: 8),
            const Text('Studio Management', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        
        // Studio Pricing Controls
        _buildStudioControl(
          'Pricing',
          'Weekdays: ₹1000/hr, Weekends: ₹1200/hr',
          Icons.currency_rupee,
          () => _editStudioPricing(),
        ),
        
        _buildStudioControl(
          'Package Deals',
          '5+ hours: Weekdays ₹700/hr, Weekends ₹800/hr',
          Icons.local_offer,
          () => _editPackageDeals(),
        ),
        
        _buildStudioControl(
          'Equipment',
          'Sound system, Lights, AC, Mirrors',
          Icons.build,
          () => _editEquipment(),
        ),
        
        _buildStudioControl(
          'Studio Rules',
          '15 min grace, Noise policy, Cleanup rules',
          Icons.rule,
          () => _editStudioRules(),
        ),
        
        _buildStudioControl(
          'Studio Banners',
          'Manage top banners for Studio tab',
          Icons.campaign_rounded,
          () => _editStudioBanners(),
        ),
        
        _buildStudioControl(
          'Studio Capacity',
          '30-40 people max capacity',
          Icons.people,
          () => _editStudioCapacity(),
        ),
        
        _buildStudioControl(
          'Grace Period',
          '15 min grace period for setup',
          Icons.access_time,
          () => _editGracePeriod(),
        ),
        
        _buildStudioControl(
          'Booking Settings',
          'Booking rules and policies',
          Icons.settings,
          () => _editBookingSettings(),
        ),
        
        _buildStudioControl(
          'Contact Info',
          'Phone, WhatsApp, Email',
          Icons.contact_phone,
          () => _editContactInfo(),
        ),
        
        _buildStudioControl(
          'Studio Status',
          'Open/Closed status management',
          Icons.toggle_on,
          () => _editStudioStatus(),
        ),
      ],
    );
  }

  Widget _buildStudioControl(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFE91E63), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.edit, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  // Studio Management Methods
  void _editStudioPricing() {
    showDialog(
      context: context,
      builder: (context) => _StudioPricingDialog(),
    );
  }

  void _editPackageDeals() {
    showDialog(
      context: context,
      builder: (context) => _PackageDealsDialog(),
    );
  }

  void _editEquipment() {
    showDialog(
      context: context,
      builder: (context) => _EquipmentDialog(),
    );
  }

  void _editStudioRules() {
    showDialog(
      context: context,
      builder: (context) => _StudioRulesDialog(),
    );
  }

  void _editStudioGallery() {
    showDialog(
      context: context,
      builder: (context) => _StudioGalleryDialog(),
    );
  }

  void _editStudioBanners() {
    showDialog(
      context: context,
      builder: (context) => _StudioBannersDialog(),
    );
  }

  void _editStudioCapacity() {
    showDialog(
      context: context,
      builder: (context) => _StudioCapacityDialog(),
    );
  }

  void _editGracePeriod() {
    showDialog(
      context: context,
      builder: (context) => _GracePeriodDialog(),
    );
  }

  void _editBookingSettings() {
    showDialog(
      context: context,
      builder: (context) => _BookingSettingsDialog(),
    );
  }

  void _editContactInfo() {
    showDialog(
      context: context,
      builder: (context) => _ContactInfoDialog(),
    );
  }

  void _editStudioStatus() {
    showDialog(
      context: context,
      builder: (context) => _StudioStatusDialog(),
    );
  }

  void _navigateToFinance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminFinanceCollectionsScreen(),
      ),
    );
  }
}

// Studio Management Dialog
class _StudioManagementDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Studio Management', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            _buildStudioControl(
              context,
              'Pricing',
              'Weekdays: ₹1000/hr, Weekends: ₹1200/hr',
              Icons.currency_rupee,
              () => _editStudioPricing(context),
            ),
            
            _buildStudioControl(
              context,
              'Package Deals',
              '5+ hours: Weekdays ₹700/hr, Weekends ₹800/hr',
              Icons.local_offer,
              () => _editPackageDeals(context),
            ),
            
            _buildStudioControl(
              context,
              'Equipment',
              'Sound system, Lights, AC, Mirrors',
              Icons.build,
              () => _editEquipment(context),
            ),
            
            _buildStudioControl(
              context,
              'Studio Rules',
              '15 min grace, Noise policy, Cleanup rules',
              Icons.rule,
              () => _editStudioRules(context),
            ),
            
            _buildStudioControl(
              context,
              'Studio Banners',
              'Manage top banners for Studio tab',
              Icons.campaign_rounded,
              () => _editStudioBannersWithContext(context),
            ),
            
            _buildStudioControl(
              context,
              'Studio Capacity',
              '30-40 people max capacity',
              Icons.people,
              () => _editStudioCapacity(context),
            ),
            
            _buildStudioControl(
              context,
              'Grace Period',
              '15 min grace period for setup',
              Icons.access_time,
              () => _editGracePeriod(context),
            ),
            
            _buildStudioControl(
              context,
              'Booking Settings',
              'Booking rules and policies',
              Icons.settings,
              () => _editBookingSettings(context),
            ),
            
            _buildStudioControl(
              context,
              'Studio Branches',
              'Add or manage studio branches',
              Icons.location_on,
              () => _editStudioBranches(context),
            ),
            
            _buildStudioControl(
              context,
              'Contact Info',
              'Phone, WhatsApp, Email',
              Icons.contact_phone,
              () => _editContactInfo(context),
            ),
            
            _buildStudioControl(
              context,
              'Studio Status',
              'Open/Closed status management',
              Icons.toggle_on,
              () => _editStudioStatus(context),
            ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  Widget _buildStudioControl(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF404040)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFE91E63), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.edit, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  // Studio Management Methods
  void _editStudioPricing(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => _StudioPricingDialog(),
    );
  }

  void _editPackageDeals(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => _PackageDealsDialog(),
    );
  }

  void _editEquipment(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => _EquipmentDialog(),
    );
  }

  void _editStudioRules(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => _StudioRulesDialog(),
    );
  }

  void _editStudioGallery(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => _StudioGalleryDialog(),
    );
  }

  void _editStudioBannersWithContext(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => _StudioBannersDialog(),
    );
  }

  void _editStudioCapacity(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => _StudioCapacityDialog(),
    );
  }

  void _editGracePeriod(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => _GracePeriodDialog(),
    );
  }

  void _editBookingSettings(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => _BookingSettingsDialog(),
    );
  }

  void _editStudioBranches(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => const _StudioBranchesDialog(),
    );
  }

  void _editContactInfo(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => _ContactInfoDialog(),
    );
  }

  void _editStudioStatus(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => _StudioStatusDialog(),
    );
  }
}

class _ControlItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ControlItem(this.title, this.icon, this.color, this.onTap);
}

// Studio Management Dialogs
class _StudioBranchesDialog extends StatefulWidget {
  const _StudioBranchesDialog();

  @override
  State<_StudioBranchesDialog> createState() => _StudioBranchesDialogState();
}

class _StudioBranchesDialogState extends State<_StudioBranchesDialog> {
  final TextEditingController _branchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Ensure default branches exist
    // ignore: discarded_futures
    BranchesService.initializeDefaultBranches();
  }

  @override
  void dispose() {
    _branchController.dispose();
    super.dispose();
  }

  Future<void> _addBranch() async {
    final name = _branchController.text.trim();
    if (name.isEmpty) return;
    try {
      final now = DateTime.now();
      await BranchesService.addBranch(
        Branch(
          id: '',
          name: name,
          isActive: true,
          priority: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
      _branchController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Branch "$name" added'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add branch: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Studio Branches', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _branchController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'New Branch Name',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addBranch,
                icon: const Icon(Icons.add),
                label: const Text('Add Branch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('branches')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white70));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No branches yet', style: TextStyle(color: Colors.white70)));
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(color: Color(0xFF333333)),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final name = (data['name'] ?? '').toString();
                      return ListTile(
                        title: Text(name, style: const TextStyle(color: Colors.white)),
                      );
                    },
                  );
                },
              ),
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
    );
  }
}

class _StudioPricingDialog extends StatefulWidget {
  @override
  _StudioPricingDialogState createState() => _StudioPricingDialogState();
}

class _StudioPricingDialogState extends State<_StudioPricingDialog> {
  final TextEditingController _weekdayController = TextEditingController(text: '1000');
  final TextEditingController _weekendController = TextEditingController(text: '1200');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Edit Studio Pricing', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _weekdayController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Weekday Rate (₹/hour)',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weekendController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Weekend Rate (₹/hour)',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection('appSettings')
                  .doc('studioSettings')
                  .set({
                    'weekdayRate': int.parse(_weekdayController.text),
                    'weekendRate': int.parse(_weekendController.text),
                  }, SetOptions(merge: true));
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pricing updated successfully!')),
              );
              Navigator.pop(context);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update pricing. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}


class _PackageDealsDialog extends StatefulWidget {
  @override
  _PackageDealsDialogState createState() => _PackageDealsDialogState();
}

class _PackageDealsDialogState extends State<_PackageDealsDialog> {
  final TextEditingController _weekdayPackageController = TextEditingController(text: '700');
  final TextEditingController _weekendPackageController = TextEditingController(text: '800');
  final TextEditingController _minHoursController = TextEditingController(text: '5');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Edit Package Deals', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _minHoursController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minimum Hours for Package',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weekdayPackageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Weekday Package Rate (₹/hour)',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weekendPackageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Weekend Package Rate (₹/hour)',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection('appSettings')
                  .doc('studioSettings')
                  .set({
                    'packageWeekdayRate': int.parse(_weekdayPackageController.text),
                    'packageWeekendRate': int.parse(_weekendPackageController.text),
                    'packageMinHours': int.parse(_minHoursController.text),
                  }, SetOptions(merge: true));
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Package deals updated successfully!')),
              );
              Navigator.pop(context);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update pricing. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}


class _EquipmentDialog extends StatefulWidget {
  @override
  _EquipmentDialogState createState() => _EquipmentDialogState();
}

class _EquipmentDialogState extends State<_EquipmentDialog> {
  final List<String> _equipment = [
    'Sound System',
    'Professional Lights',
    'Air Conditioning',
    'Full-length Mirrors',
    'Dance Floor',
    'Storage Space',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Edit Equipment', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _equipment.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(_equipment[index], style: const TextStyle(color: Colors.white)),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _equipment.removeAt(index);
                  });
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection('appSettings')
                  .doc('studioSettings')
                  .set({
                    'equipment': _equipment,
                  }, SetOptions(merge: true));
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Equipment list updated successfully!')),
              );
              Navigator.pop(context);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update pricing. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}


class _StudioRulesDialog extends StatefulWidget {
  @override
  _StudioRulesDialogState createState() => _StudioRulesDialogState();
}

class _StudioRulesDialogState extends State<_StudioRulesDialog> {
  final List<String> _rules = [
    '15 minutes grace period for setup',
    'Noise levels must be maintained',
    'Equipment must be handled carefully',
    'No food or drinks in studio',
    'Clean up after use',
    'Booking cancellation 2 hours prior',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Edit Studio Rules', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _rules.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(_rules[index], style: const TextStyle(color: Colors.white)),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _rules.removeAt(index);
                  });
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection('appSettings')
                  .doc('studioSettings')
                  .set({
                    'rules': _rules,
                  }, SetOptions(merge: true));
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Studio rules updated successfully!')),
              );
              Navigator.pop(context);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update pricing. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}


class _StudioGalleryDialog extends StatefulWidget {
  @override
  _StudioGalleryDialogState createState() => _StudioGalleryDialogState();
}

class _StudioGalleryDialogState extends State<_StudioGalleryDialog> {
  List<String> _galleryImages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGalleryData();
  }

  Future<void> _loadGalleryData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('studioSettings')
          .get();

      if (doc.exists) {
        setState(() {
          _galleryImages = List<String>.from(doc.data()?['galleryImages'] ?? []);
        });
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Studio Gallery Management', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Add Image Section
                    _buildAddSection('Upload Studio Images', Icons.add_photo_alternate, () => _addImage()),
                    
                    // Images List
                    if (_galleryImages.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Studio Images:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._galleryImages.asMap().entries.map((entry) => 
                        _buildMediaItem(entry.value, 'Image ${entry.key + 1}', Icons.image, () => _removeImage(entry.key))
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _saveGallery,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
          child: const Text('Save Gallery'),
        ),
      ],
    );
  }

  Widget _buildAddSection(String title, IconData icon, VoidCallback onTap) {
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
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaItem(String url, String title, IconData icon, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE91E63), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                Text(
                  url.length > 50 ? '${url.substring(0, 50)}...' : url,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          ),
        ],
      ),
    );
  }

  void _addImage() {
    _pickImageFromDevice();
  }


  Future<void> _pickImageFromDevice() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        // Upload to Firebase Storage
        final String downloadUrl = await _uploadFileToStorage(image.path, 'images');
        setState(() {
          _galleryImages.add(downloadUrl);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
  }


  Future<String> _uploadFileToStorage(String filePath, String folder) async {
    final File file = File(filePath);
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final Reference ref = FirebaseStorage.instance.ref().child('studio_gallery/$folder/$fileName');
    
    final UploadTask uploadTask = ref.putFile(file);
    final TaskSnapshot snapshot = await uploadTask;
    final String downloadUrl = await snapshot.ref.getDownloadURL();
    
    return downloadUrl;
  }

  void _removeImage(int index) {
    setState(() {
      _galleryImages.removeAt(index);
    });
  }



  Future<void> _saveGallery() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('studioSettings')
          .set({
            'galleryImages': _galleryImages,
          }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gallery updated successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save gallery. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class _StudioBannersDialog extends StatefulWidget {
  @override
  _StudioBannersDialogState createState() => _StudioBannersDialogState();
}

class _StudioBannersDialogState extends State<_StudioBannersDialog> {
  List<AppBanner> _banners = [];
  bool _loadingBanners = true;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    setState(() => _loadingBanners = true);
    final jsonList = await AdminService.readStudioBannersJson();
    final items = jsonList.map((e) => AppBanner.fromMap(e)).toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));
    setState(() {
      _banners = items;
      _loadingBanners = false;
    });
  }

  Future<void> _saveBanners() async {
    final ok = await AdminService.writeStudioBannersJson(_banners.map((e) => e.toMap()).toList());
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Studio banners saved successfully!'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save studio banners'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _addBanner() async {
    final controllers = _BannerControllers();
    String? imageUrl;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1B1B),
          title: const Text('Add Studio Banner', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: controllers.title,
                  decoration: const InputDecoration(hintText: 'Title', hintStyle: TextStyle(color: Colors.white70)),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controllers.ctaText,
                  decoration: const InputDecoration(hintText: 'CTA Text (optional)', hintStyle: TextStyle(color: Colors.white70)),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controllers.ctaLink,
                  decoration: const InputDecoration(hintText: 'CTA Link (optional)', hintStyle: TextStyle(color: Colors.white70)),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final x = await AdminService.pickImage();
                    if (x != null) {
                      final url = await AdminService.uploadBannerImage(x);
                      if (url != null) {
                        imageUrl = url;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Image selected')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Upload Image'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                if ((controllers.title.text).trim().isEmpty || imageUrl == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title and image are required'), backgroundColor: Colors.red),
                  );
                  return;
                }
                _banners.add(AppBanner(
                  title: controllers.title.text.trim(),
                  imageUrl: imageUrl!,
                  ctaText: controllers.ctaText.text.trim().isEmpty ? null : controllers.ctaText.text.trim(),
                  ctaLink: controllers.ctaLink.text.trim().isEmpty ? null : controllers.ctaLink.text.trim(),
                  isActive: true,
                  sort: _banners.length,
                ));
                Navigator.pop(context);
                _saveBanners();
                setState(() {});
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editBanner(int index) async {
    final b = _banners[index];
    final controllers = _BannerControllers.from(b);
    String imageUrl = b.imageUrl;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1B1B),
          title: const Text('Edit Studio Banner', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(children: [
              TextField(
                controller: controllers.title,
                decoration: const InputDecoration(hintText: 'Title', hintStyle: TextStyle(color: Colors.white70)),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controllers.ctaText,
                decoration: const InputDecoration(hintText: 'CTA Text (optional)', hintStyle: TextStyle(color: Colors.white70)),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controllers.ctaLink,
                decoration: const InputDecoration(hintText: 'CTA Link (optional)', hintStyle: TextStyle(color: Colors.white70)),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final x = await AdminService.pickImage();
                  if (x != null) {
                    final url = await AdminService.uploadBannerImage(x);
                    if (url != null) {
                      imageUrl = url;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Image updated')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.file_upload),
                label: const Text('Replace Image'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                _banners[index] = AppBanner(
                  title: controllers.title.text.trim(),
                  imageUrl: imageUrl,
                  ctaText: controllers.ctaText.text.trim().isEmpty ? null : controllers.ctaText.text.trim(),
                  ctaLink: controllers.ctaLink.text.trim().isEmpty ? null : controllers.ctaLink.text.trim(),
                  isActive: true,
                  sort: index,
                );
                Navigator.pop(context);
                _saveBanners();
                setState(() {});
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteBanner(int index) async {
    _banners.removeAt(index);
    for (int i = 0; i < _banners.length; i++) {
      _banners[i] = AppBanner(
        title: _banners[i].title,
        imageUrl: _banners[i].imageUrl,
        ctaText: _banners[i].ctaText,
        ctaLink: _banners[i].ctaLink,
        isActive: _banners[i].isActive,
        sort: i,
      );
    }
    await _saveBanners();
    setState(() {});
  }

  void _moveBanner(int index, int delta) async {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _banners.length) return;
    final item = _banners.removeAt(index);
    _banners.insert(newIndex, item);
    for (int i = 0; i < _banners.length; i++) {
      _banners[i] = AppBanner(
        title: _banners[i].title,
        imageUrl: _banners[i].imageUrl,
        ctaText: _banners[i].ctaText,
        ctaLink: _banners[i].ctaLink,
        isActive: _banners[i].isActive,
        sort: i,
      );
    }
    await _saveBanners();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Studio Banners Management', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: _loadingBanners
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
            : Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: const Text(
                          'Add, edit and reorder studio banners',
                          style: TextStyle(color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _addBanner,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Banner'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _banners.isEmpty
                        ? const Center(
                            child: Text('No banners yet. Add your first banner!', style: TextStyle(color: Colors.white70)),
                          )
                        : ListView.builder(
                            itemCount: _banners.length,
                            itemBuilder: (context, index) {
                              final banner = _banners[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF262626),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF404040)),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.arrow_upward, color: Colors.white70, size: 20),
                                      onPressed: index > 0 ? () => _moveBanner(index, -1) : null,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.arrow_downward, color: Colors.white70, size: 20),
                                      onPressed: index < _banners.length - 1 ? () => _moveBanner(index, 1) : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(banner.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                          if (banner.ctaText != null)
                                            Text('CTA: ${banner.ctaText}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Color(0xFFE53935), size: 20),
                                      onPressed: () => _editBanner(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () => _deleteBanner(index),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
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
    );
  }
}

class _BannerControllers {
  final TextEditingController title = TextEditingController();
  final TextEditingController ctaText = TextEditingController();
  final TextEditingController ctaLink = TextEditingController();

  _BannerControllers();

  factory _BannerControllers.from(AppBanner banner) {
    final c = _BannerControllers();
    c.title.text = banner.title;
    c.ctaText.text = banner.ctaText ?? '';
    c.ctaLink.text = banner.ctaLink ?? '';
    return c;
  }

  void dispose() {
    title.dispose();
    ctaText.dispose();
    ctaLink.dispose();
  }
}

class _StudioCapacityDialog extends StatefulWidget {
  @override
  _StudioCapacityDialogState createState() => _StudioCapacityDialogState();
}

class _StudioCapacityDialogState extends State<_StudioCapacityDialog> {
  final TextEditingController _capacityController = TextEditingController(text: '30-40 people max');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Edit Studio Capacity', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _capacityController,
            decoration: const InputDecoration(
              labelText: 'Studio Capacity',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection('appSettings')
                  .doc('studioSettings')
                  .set({
                    'capacity': _capacityController.text.trim(),
                  }, SetOptions(merge: true));
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Studio capacity updated successfully!')),
              );
              Navigator.pop(context);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update pricing. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}


class _GracePeriodDialog extends StatefulWidget {
  @override
  _GracePeriodDialogState createState() => _GracePeriodDialogState();
}

class _GracePeriodDialogState extends State<_GracePeriodDialog> {
  final TextEditingController _gracePeriodController = TextEditingController(text: '15 min grace period');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Edit Grace Period', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _gracePeriodController,
            decoration: const InputDecoration(
              labelText: 'Grace Period',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection('appSettings')
                  .doc('studioSettings')
                  .set({
                    'gracePeriod': _gracePeriodController.text.trim(),
                  }, SetOptions(merge: true));
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Grace period updated successfully!')),
              );
              Navigator.pop(context);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update pricing. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}


class _BookingSettingsDialog extends StatefulWidget {
  @override
  _BookingSettingsDialogState createState() => _BookingSettingsDialogState();
}

class _BookingSettingsDialogState extends State<_BookingSettingsDialog> {
  final TextEditingController _advanceBookingController = TextEditingController(text: '2');
  final TextEditingController _cancellationController = TextEditingController(text: '2');
  bool _requireAdvancePayment = true;
  bool _allowOnlineBooking = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Edit Booking Settings', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _advanceBookingController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Advance Booking (days)',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cancellationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cancellation Notice (hours)',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Require Advance Payment', style: TextStyle(color: Colors.white)),
              value: _requireAdvancePayment,
              onChanged: (value) => setState(() => _requireAdvancePayment = value),
              thumbColor: const WidgetStatePropertyAll(Color(0xFFE53935)),
            ),
            SwitchListTile(
              title: const Text('Allow Online Booking', style: TextStyle(color: Colors.white)),
              value: _allowOnlineBooking,
              onChanged: (value) => setState(() => _allowOnlineBooking = value),
              thumbColor: const WidgetStatePropertyAll(Color(0xFFE53935)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection('appSettings')
                  .doc('studioSettings')
                  .set({
                    'advanceBookingDays': int.parse(_advanceBookingController.text),
                    'cancellationNoticeHours': int.parse(_cancellationController.text),
                    'requireAdvancePayment': _requireAdvancePayment,
                    'allowOnlineBooking': _allowOnlineBooking,
                  }, SetOptions(merge: true));
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Booking settings updated successfully!')),
              );
              Navigator.pop(context);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update pricing. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}


class _ContactInfoDialog extends StatefulWidget {
  @override
  _ContactInfoDialogState createState() => _ContactInfoDialogState();
}

class _ContactInfoDialogState extends State<_ContactInfoDialog> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContactInfo();
  }

  Future<void> _loadContactInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('contact_info')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _phoneController.text = data['phone'] ?? '+91 98765 43210';
          _whatsappController.text = data['whatsapp'] ?? '919999999999';
          _emailController.text = data['email'] ?? 'info@dancerang.com';
          _isLoading = false;
        });
      } else {
        setState(() {
          _phoneController.text = '+91 98765 43210';
          _whatsappController.text = '919999999999';
          _emailController.text = 'info@dancerang.com';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contact info: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Edit Contact Info', style: TextStyle(color: Colors.white)),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintText: '+91 98765 43210',
                      prefixIcon: Icon(Icons.phone, color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _whatsappController,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp Number',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintText: '919999999999',
                      prefixIcon: Icon(Icons.message, color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintText: 'info@dancerang.com',
                      prefixIcon: Icon(Icons.email, color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveContactInfo,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveContactInfo() async {
    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('contact_info')
          .set({
            'phone': _phoneController.text.trim(),
            'whatsapp': _whatsappController.text.trim(),
            'email': _emailController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact info updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving contact info: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _StudioStatusDialog extends StatefulWidget {
  @override
  _StudioStatusDialogState createState() => _StudioStatusDialogState();
}

class _StudioStatusDialogState extends State<_StudioStatusDialog> {
  bool _isStudioOpen = true;
  String _statusMessage = 'Studio is currently open for bookings';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Edit Studio Status', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Studio Open', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              _isStudioOpen ? 'Accepting bookings' : 'Not accepting bookings',
              style: const TextStyle(color: Colors.white70),
            ),
            value: _isStudioOpen,
            onChanged: (value) => setState(() => _isStudioOpen = value),
            thumbColor: const WidgetStatePropertyAll(Color(0xFFE53935)),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (value) => _statusMessage = value,
            decoration: const InputDecoration(
              labelText: 'Status Message',
              labelStyle: TextStyle(color: Colors.white70),
              hintText: 'Enter status message for users',
            ),
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection('appSettings')
                  .doc('studioSettings')
                  .set({
                    'isStudioOpen': _isStudioOpen,
                    'statusMessage': _statusMessage,
                  }, SetOptions(merge: true));
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Studio status updated: ${_isStudioOpen ? 'Open' : 'Closed'}')),
              );
              Navigator.pop(context);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update pricing. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}



